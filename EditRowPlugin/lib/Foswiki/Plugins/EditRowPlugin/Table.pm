# See bottom of file for copyright and pod
package Foswiki::Plugins::EditRowPlugin::Table;

use strict;
use Assert;

use Foswiki::Tables::Table ();
our @ISA = ('Foswiki::Tables::Table');

use Foswiki::Attrs                            ();
use Foswiki::Func                             ();
use Foswiki::Plugins::EditRowPlugin           ();
use Foswiki::Plugins::EditRowPlugin::TableRow ();
use Foswiki::Plugins::EditRowPlugin::Editor   ();
use Foswiki::Tables::Table                    ();

use constant TRACE => 0;

use constant {

    # Row-only buttons
    ADD_ROW    => 'Add new row after this row / at the end',
    DELETE_ROW => 'Delete this row / last row',
    DOWN_ROW   => 'Move this row down',
    EDIT_ROW   => 'Edit',
    UP_ROW     => 'Move this row up',

    # Row and whole table buttons
    CANCEL     => 'Cancel',
    NOISY_SAVE => 'Save',
    QUIET_SAVE => 'Quiet Save',
};

# Map of type name to editor object. This is dynamically populated
# on demand with editors loaded from
# Foswiki/Plugins/EditRowPlugin/Editor/*.pm
our %editors = ( _default => Foswiki::Plugins::EditRowPlugin::Editor->new() );

# Parameters are defined in Foswiki::Table
# See EditRowPlugin.txt for a description of the attributes supported,
# plus the following undocumented attributes:
#    =require_js= - compatibility, true maps to =js='assumed'=,
#                   false to =js='preferred'=

sub new {
    my ( $class, $specs ) = @_;

    my $this =
      $class->SUPER::new( $specs,
        $Foswiki::cfg{Plugins}{EditRowPlugin}{Macro} || 'EDITTABLE' );

    my $attrs = $this->{attrs};
    $this->{editable} = $attrs->{isEditable};

    # EditTablePlugin compatibility; headerrows trumps headerislabel
    $attrs->{headerrows} = 1
      if !defined $attrs->{headerrows} && $attrs->{headerislabel};

    my $disable =
      defined( $attrs->{disable} )
      ? $attrs->{disable}
      : Foswiki::Func::getPreferencesValue('EDITROWPLUGIN_DISABLE');
    $attrs->{disable} = $disable || '';

    my $changerows = $attrs->{changerows};
    if ( !defined($changerows) ) {
        $changerows = Foswiki::Func::getPreferencesValue('CHANGEROWS');
        $changerows = 'on' if ( !defined($changerows) || $changerows eq '' );
    }
    $attrs->{changerows} = $changerows;

    my $q =
      defined( $attrs->{quietsave} )
      ? $attrs->{quietsave}
      : Foswiki::Func::getPreferencesValue('QUIETSAVE');
    $attrs->{quietsave} = Foswiki::Func::isTrue($q);

    $attrs->{js} ||= Foswiki::Func::getPreferencesValue('EDITROWPLUGIN_JS');
    if ( !defined $attrs->{js} ) {
        $attrs->{require_js} ||=
          Foswiki::Func::getPreferencesValue('EDITROWPLUGIN_REQUIRE_JS')
          || 0;
        if ( defined $attrs->{require_js} ) {
            $attrs->{js} =
              Foswiki::Func::isTrue( $attrs->{require_js} )
              ? 'assumed'
              : 'preferred';
        }
    }
    $attrs->{js} ||= 'preferred';

    $attrs->{buttons} ||= "right";

    $this->{attrs} = $attrs;

    return $this;
}

sub addSpecs {
    my ( $this, $spec ) = @_;

}

# Override Foswiki::Tables::Table
sub row_class {
    return 'Foswiki::Plugins::EditRowPlugin::TableRow';
}

# Override Foswiki::Tables::Table
sub getMacros {
    my $this = shift;
    my @list = $this->SUPER::getMacros();
    push( @list, $Foswiki::cfg{Plugins}{EditRowPlugin}{Macro} || 'EDITTABLE' );
    return @list;
}

sub getWeb {
    my $this = shift;
    return $this->{meta}->web();
}

sub getTopic {
    my $this = shift;
    return $this->{meta}->topic();
}

sub getTopicObject {
    my $this = shift;
    return $this->{meta};
}

# Calculate row labels
sub _assignLabels {
    my $this  = shift;
    my $heads = $this->getHeaderRows();

    while ( $heads-- > 0 ) {
        if ( $heads < $this->totalRows() ) {
            $this->{rows}->[$heads]->isHeader(1);
        }
    }
    my $tails = $this->getFooterRows();
    while ( $tails > 0 ) {
        if ( $tails < $this->totalRows() ) {
            $this->{rows}->[ -$tails ]->isFooter(1);
        }
        $tails--;
    }

    # Assign row index numbers to body cells
    my $index = 1;
    foreach my $row ( @{ $this->{rows} } ) {
        if ( $row->isHeader || $row->isFooter ) {
            $row->{index} = '';
        }
        else {
            $row->{index} = $index++;
        }
    }
}

# $opts - options
#   with_controls controls display of controls
#   for_edit = 1 enables editing
#   active_row and real_table are for editing
#      only. If active_row is <= 0, this requires whole-table editing.
#   real_table can be a Table that contains cells for editing, as against
#      display. This is used when the contents of the table have already been
#      processed by other plugins, but we want to get back to basics for the
#      edit.
sub render {
    my ( $this, $opts ) = @_;
    my @out;
    my $attrs = $this->{attrs};

    $this->_assignLabels();

    my $editing    = ( $opts->{for_edit}           && $this->can_edit() );
    my $wholeTable = ( defined $opts->{active_row} && $opts->{active_row} < 0 );

    my $id = $this->getID();
    push( @out, Foswiki::Render::html( 'a', { name => "erp_${id}" } ) )
      unless $this->{attrs}->{js} eq 'assumed';

    my $orientation = $this->{attrs}->{orientrowedit} || 'horizontal';

    # Disallow vertical display for whole table edits
    $orientation = 'horizontal' if $wholeTable;
    if ( $editing && $this->{attrs}->{js} ne 'assumed' ) {
        my $format = $attrs->{format} || '';

        # Save the _format, _headerrows and _footerrows in hidden params;
        # if they are modified client-side, they will be re-loaded when
        # the table parser loads the relevant table.
        #
        # SMELL: Have to double-encode the format param to defend it
        # against the rest of Foswiki. We use the escape char '-' as it
        # isn't used by Foswiki.
        $format =~ s/([][@\s%!:-])/sprintf('-%02x',ord($1))/ge;
        push(
            @out,
            Foswiki::Render::html(
                "input",
                {
                    type  => "hidden",
                    name  => "erp_${id}_format",
                    value => $format
                }
            )
        );
        if ( $attrs->{headerrows} ) {
            push(
                @out,
                Foswiki::Render::html(
                    "input",
                    {
                        type  => "hidden",
                        name  => "erp_${id}_headerrows",
                        value => $attrs->{headerrows}
                    }
                )
            );
        }
        if ( $attrs->{footerrows} ) {
            push(
                @out,
                Foswiki::Render::html(
                    "input",
                    {
                        type  => "hidden",
                        name  => "erp_${id}_footerrows",
                        value => $attrs->{footerrows}
                    }
                )
            );
        }
    }

    my $n = 0;    # displayed row index
    my $r = 0;    # real row index

    my %row_opts = (
        col_defs      => $this->{colTypes},
        js            => $this->{attrs}->{js},
        with_controls => $this->can_edit()
          && (
            ( $editing && !$wholeTable )
            || (  !$editing
                && $opts->{with_controls}
                && $this->{attrs}->{disable} !~ /row/ )
          )
    );

    my %render_opts = ( need_tabledata => 1 );

    my $fake_row = 0;
    if ( $editing && $this->totalRows() == 0 ) {

        # Editing a zero-row table causes automatic creation of a single
        # row. This is to support the creation of a new table in the
        # presence of an EDITTABLE macro with no data.
        $this->addRow(-1);

        # A row added this way will be used for an edit, so needs assigned
        # cell numbers. These normally come from the raw table, but there
        # isn't one when the table is being created.
        my $n = 0;
        foreach my $cell ( @{ $this->{rows}->[0]->{cols} } ) {
            $cell->number( $n++ );
        }
        $fake_row   = 1;
        $wholeTable = 1;    # it should be already; just make sure
                            # we need to make sure controls are added....
    }
    foreach my $row ( @{ $this->{rows} } ) {
        my $isLard = ( $row->isHeader || $row->isFooter );
        $n++ unless $isLard;

        my $rowtext;
        if ( $editing
            && ( $r == $opts->{active_row} || $wholeTable && !$isLard ) )
        {

            # Render an editable row
            # Get the row from the real_table, read raw from the topic
            # (or use the fake_row if one was required)
            my $real_row =
              $opts->{real_table} ? $opts->{real_table}->{rows}->[$r] : $row;
            $real_row = $row if $fake_row;
            if ($real_row) {
                push(
                    @out,
                    $real_row->render(
                        {
                            %row_opts,
                            for_edit => 1,
                            orient   => $orientation
                        },
                        \%render_opts
                    )
                );
            }
        }
        else {
            my $r = $row->render( \%row_opts, \%render_opts );
            push( @out, $r );
        }
        $r++;
    }

    if ($editing) {
        if ( $wholeTable && $this->{attrs}->{js} ne 'assumed' ) {

            # JS is ignored or preferred, need manual edit controls
            push( @out, $this->generateEditButtons( 0, 0, 1 ) );
            my $help = $this->generateHelp();
            push( @out, $help ) if $help;
        }
    }
    elsif ($opts->{with_controls}
        && $this->can_edit()
        && $this->{attrs}->{js} ne 'assumed'
        && $this->{attrs}->{js} ne 'rowmoved' )
    {

        # Generate the buttons at the bottom of the table

        # A  bit of a hack. If the user isn't logged in, then show the
        # table edit button anyway, but redirect them to viewauth to force
        # login.
        my $script = (
            Foswiki::Func::getContext()->{authenticated}
            ? 'view'
            : 'viewauth'
        );

        # Show full-table-edit control
        my $active_topic = $this->getWeb . '.' . $this->getTopic;
        if ( $this->{attrs}->{disable} !~ /full/ ) {

            # Full table editing is not disabled
            my $title = "Edit full table";
            my $url   = Foswiki::Func::getScriptUrl(
                $this->getWeb(), $this->getTopic(), 'view',
                erp_topic => $active_topic,
                erp_table => $id,
                erp_row   => -1,
                '#'       => 'erp_' . $id
            );
            push(
                @out,
                Foswiki::Render::html( 'a', { name => "erp_${id}" } )
                  . Foswiki::Render::html(
                    'a',
                    {
                        href  => $url,
                        name  => "erp_edit_${id}",
                        class => 'erp-edittable foswikiButton',
                        title => $title
                    },
                    ''
                  )
                  . '<br />'
            );
        }
        elsif ( Foswiki::Func::isTrue( $this->{attrs}->{changerows} )
            && $this->{attrs}->{disable} !~ /row/ )
        {

            # We are going into single row editing mode
            my $title  = "Add row to end of table";
            my $button = Foswiki::Render::html(
                'button',
                {
                    name  => "erp_edit_${id}",
                    class => 'erp-addrow',
                    title => $title
                }
            );
            my $url;

            # erp_unchanged=1 prevents addRowCmd from trying to
            # save changes in the table. erp_row is set to -2
            # so that addRowCmd enters single row editing mode
            $url = Foswiki::Func::getScriptUrl(
                'EditRowPlugin',
                'save', 'rest',
                $this->getParams('erp_'),
                erp_row       => -2,
                erp_unchanged => 1,
                erp_action    => 'addRowCmd',
                '#'           => "erp_${id}"
            );

            push(
                @out,
                Foswiki::Render::html( 'a', { name => "erp_${id}" } )
                  . Foswiki::Render::html( 'a',
                    { href => $url, title => $title }, $button )
                  . '<br />'
            );
        }
        elsif ( Foswiki::Func::isTrue( $this->{attrs}->{changerows} )
            && $this->{attrs}->{disable} !~ /row/ )
        {

            # We are going into single row editing mode
            my $title  = "Add row to end of table";
            my $button = Foswiki::Render::html(
                'button',
                {
                    type  => 'button',
                    name  => "erp_edit_${id}",
                    class => 'erp-addrow',
                    title => $title
                }
            );
            my $url;

            # erp_unchanged=1 prevents addRow from trying to
            # save changes in the table. erp_active_row is set to -2
            # so that addRow enters single row editing mode (see sub addRow)
            $url = Foswiki::Func::getScriptUrl(
                'EditRowPlugin',
                'save', 'rest',
                $this->getParams('erp_'),
                erp_active_row => -2,
                erp_unchanged  => 1,
                erp_action     => 'addRow',
                '#'            => "erp_${id}"
            );

            # Full table disabled, but not row
            push(
                @out,
                Foswiki::Render::html(
                    'a',
                    {
                        href  => $url,
                        title => $title
                    },
                    $button
                  )
                  . '<br />'
            );
        }
    }
    return join( "\n", @out ) . "\n";
}

sub can_edit {
    my $this = shift;
    return $this->{editable};
}

sub getParams {
    my ( $this, $prefix ) = @_;

    $prefix ||= '';

    my $meta = $this->getTopicObject();
    my $info = $meta->getRevisionInfo();

    return (
        "${prefix}topic"   => $this->getWeb . '.' . $this->getTopic,
        "${prefix}version" => "$info->{version}_$info->{date}",
        "${prefix}table"   => $this->getID()
    );
}

# Get the "type object" for this column definition (one of the Editor classes)
sub getEditor {
    my $colDef = shift;
    my $editor = $editors{ $colDef->{type} };
    unless ($editor) {
        if ( $colDef->{type} =~ /^(\w+)$/ ) {
            $colDef->{type} = $1;
            my $class =
              "Foswiki::Plugins::EditRowPlugin::Editor::$colDef->{type}";
            eval("require $class");
            if ($@) {
                Foswiki::Func::writeWarning(
                    "EditRowPlugin could not load cell type $class: $@");
                $editor = $editors{_default};
            }
            else {
                $editor = $class->new();
            }
            $editors{ $colDef->{type} } = $editor;
        }
        else {
            # default to _default
            $editor = $editors{_default};
        }
    }
    return $editor;
}

# Get the cols for the given row, padding out with empty cols if
# the row is shorter than the type def for the table.
sub _getColsFromURPs {
    my ( $this, $urps, $row ) = @_;
    my $attrs    = $this->{attrs};
    my $headRows = $attrs->{headerrows} || 0;
    my $count    = scalar( @{ $this->{rows}->[$row]->{cols} } );
    my $defs     = scalar( @{ $this->{colTypes} } );
    $count = $defs if $defs > $count;
    my @cols;

    for ( my $i = 0 ; $i < $count ; $i++ ) {
        my $colDef   = $this->{colTypes}->[$i];
        my $cellName = 'erp_cell_' . $this->getID() . "_${row}_$i";
        my $cell     = $this->{rows}->[$row]->{cols}->[$i];
        my $val      = $urps->{$cellName};

        # Check current value for format-overriding EDITCELL
        if ( $cell->{text} && $cell->{text} =~ /%EDITCELL\{(.*?)\}%/ ) {
            my %p  = Foswiki::Func::extractParameters($1);
            my $cd = $this->parseFormat( $p{_DEFAULT} );
            $colDef = $cd->[0];
        }

        if ( $colDef && defined $colDef->{type} ) {
            my $editor = getEditor($colDef);
            if ( $editor && $editor->can('forceValue') ) {
                $val = $editor->forceValue( $colDef, $cell, $row - $headRows );
            }
        }

        # Keep existing value if $val is undef
        $cols[$i] = defined $val ? $val : $cell->{text};
    }
    return \@cols;
}

# Action on whole table saved
# URL params:
#    * erp_cell_<tableid>_<rowno>_<colno>
sub saveTableCmd {
    my ( $this, $urps ) = @_;

    # Whole table (sans header and footer rows)
    my $end = $this->totalRows() - $this->getFooterRows();
    if ( $end <= 0 ) {
        Foswiki::Func::writeDebug("Fabricate new table") if TRACE;

        # Fabricating a new table. Sniff the URL params to determine
        # the number of new rows
        $end = 0;
        my $count = scalar( @{ $this->{colTypes} } );
        my $rowSeen;
        do {
            $rowSeen = 0;
            for ( my $i = 0 ; $i < $count ; $i++ ) {
                my $cellName = 'erp_cell_' . $this->getID() . "_${end}_$i";
                if ( defined $urps->{$cellName} ) {
                    $rowSeen = 1;
                    $this->addRow($end);
                    $end++;
                    last;
                }
            }
        } while ($rowSeen);

        # Fall through to commit the content
    }

    # Change / set the table content
    for ( my $i = $this->getHeaderRows() ; $i < $end ; $i++ ) {
        my $cols = $this->_getColsFromURPs( $urps, $i );
        $this->{rows}->[$i]->setRow($cols);
    }
}

# Action on row saved
# URL params:
#    * erp_row
#    * erp_cell_<tableid>_<rowno>_<colno>
sub saveRowCmd {
    my ( $this, $urps ) = @_;
    my $row = $urps->{erp_row};
    if ( $row >= 0 ) {
        my $cols = $this->_getColsFromURPs( $urps, $row );
        $this->{rows}->[$row]->setRow($cols);
    }
}

# Action on single cell saved (JEditable)
# Uses URL params:
#    * erp_row
#    * erp_col
#    * CELLDATA - Save uses this as the name of the parameter that
#      contains the new value of the cell.
sub saveCellCmd {
    my ( $this, $urps ) = @_;

    my $row = $urps->{erp_row};
    my $col = $urps->{erp_col};
    my $ot  = $this->{rows}->[$row]->{cols}->[$col]->{text};

    my $nt = $urps->{CELLDATA};
    if ( $ot =~ /(%EDITCELL\{.*?\}%)/ ) {

        # Restore the %EDITCELL
        $nt = $1 . $nt;
    }

    # Remove padding spaces added to allow cells to expand TML
    $nt =~ s/^ (.*) $/$1/s;
    $this->{rows}->[$row]->{cols}->[$col]->{text} = $nt;
    return $urps->{CELLDATA};
}

# Get cell, row, column or entire table, depending on URL params:
#    * erp_row
#    * erp_col
sub getCell {
    my ( $this, $urps ) = @_;
    my $row = $urps->{erp_row};
    my $col = $urps->{erp_col};

    # whole-table or whole-column requests
    undef $row if defined $row && $row < 0;
    undef $col if defined $col && $col < 0;
    return $this->getCellData( $row, $col );
}

# Save row (or table) depending on the value of URL params:
#    * erp_row - if set, save a single row, otherwise the entire table
#    * erp_cell_<tableid>_<rowno>_<colno>
sub saveData {
    my ( $this, $urps ) = @_;
    if ( $urps->{erp_row} < 0 ) {
        $this->saveTableCmd($urps);
    }
    else {
        $this->saveRowCmd($urps);
    }
}

# Construct and add a row _after_ the given row. URL params:
#    * erp_row - 0-based index of the row to add _after_._
#      If =erp_row= < 0, then adds the row to the end of
#      the *live* rows (i.e. rows *before* the footer).
#    * erp_unchanged - if false, will force a save of the entire
#      table before the row is added. If erp_unchanged is false, then:
#       * erp_row - if set, save a single row, otherwise the entire table
#       * erp_cell_<tableid>_<rowno>_<colno>
sub addRowCmd {
    my ( $this, $urps ) = @_;
    my @cols;

    unless ( $urps->{erp_unchanged} ) {
        $this->saveData($urps);    # in case data has changed
    }

    # -1 means full table edit; -2 means a row is being added to
    # a table not currently being edited
    if ( $urps->{erp_row} >= 0 ) {

        $this->addRow( $urps->{erp_row} + 1 );

        # Make the current row the one we just added
        $urps->{erp_row}++;
    }
    else {
        # Add before footer
        $this->addRow( $this->totalRows() );
    }
}

# Action on row deleted
#    * erp_row - row to delete
#    * erp_cell_<tableid>_<rowno>_<colno>
# SMELL: detect and use erp_unchanged?
sub deleteRowCmd {
    my ( $this, $urps ) = @_;

    $this->saveData($urps);    # in case data has changed

    my $row =
        $urps->{erp_row} >= 0
      ? $urps->{erp_row}
      : $this->totalRows() + $urps->{erp_row};
    return unless $this->deleteRow($row);

    return if $urps->{erp_row} < 0;    # full table edit?

    # Make sure that the active row is a non-header, non-footer row
    if ( $urps->{erp_row} < $this->getFirstBodyRow() ) {
        $urps->{erp_row} = $this->getFirstBodyRow();
    }
    if ( $urps->{erp_row} > $this->getLastBodyRow() ) {
        $urps->{erp_row} = $this->getLastBodyRow();
        if ( $urps->{erp_row} < $this->getFirstBodyRow() ) {

            # No active rows left
            $urps->{erp_row} = -1;
        }
    }
}

# URL params:
#    * old_pos
#    * new_pos
# SMELL: does no saveData; dangerous?
sub moveRowCmd {
    my ( $this, $urps ) = @_;
    if (   $urps->{old_pos} >= $this->getFirstBodyRow()
        && $urps->{old_pos} <= $this->getLastBodyRow() )
    {
        if ( $urps->{new_pos} < $this->getFirstBodyRow() ) {
            $urps->{new_pos} = $this->getFirstBodyRow();
        }
        elsif ( $urps->{new_pos} > $this->getLastBodyRow() ) {
            $urps->{new_pos} = $this->getLastBodyRow() + 1;
        }
        my $moved = $this->moveRow( $urps->{old_pos}, $urps->{new_pos} );
        ASSERT($moved) if DEBUG;
        $this->{attrs}->{js} = 'rowmoved';
    }
    return $this->render( { with_controls => 1 }, {} );
}

# Action on move up; save and shift row
# URL params:
#    * erp_row
sub upRowCmd {
    my ( $this, $urps ) = @_;
    $this->saveData($urps);
    if ( $urps->{erp_row} > $this->getFirstBodyRow() ) {
        $this->upRow( $urps->{erp_row} );
        $urps->{erp_row}--;
    }
}

# Action on move down; save and shift row
# URL params:
#    * erp_row
sub downRowCmd {
    my ( $this, $urps ) = @_;
    $this->saveData($urps);
    if ( $urps->{erp_row} < $this->getLastBodyRow() ) {
        $this->downRow( $urps->{erp_row} );
        $urps->{erp_row}++;
    }
}

# Action on edit cancelled
sub cancelCmd {
}

sub generateHelp {
    my ($this) = @_;
    my $attrs = $this->{attrs};
    my $help;
    if ( $attrs->{helptopic} ) {
        my ( $web, $topic ) =
          Foswiki::Func::normalizeWebTopicName( $this->getWeb,
            $attrs->{helptopic} );
        my ( $meta, $text ) = Foswiki::Func::readTopic( $web, $topic );
        $text =~ s/.*?%STARTINCLUDE%//s;
        $text =~ s/%(?:STOP|END)INCLUDE%.*//s;
        $text =~ s/^\s*//s;
        $text =~ s/\s*$//s;
        $help = Foswiki::Func::renderText($text);
        $help =~ s/\n/ /g;
    }
    return $help;
}

# Make a button for js != "assumed" mode. Buttons all submit a
# POST (even cancel).
sub _makeButton {
    my ( $action, $icon, $title, $attrs ) = @_;
    return Foswiki::Render::html(
        'button',
        {
            type  => "submit",
            name  => 'erp_action',
            value => $action,
            title => $title,
            class => "$icon erp-button"
        }
    );
}

# Generate edit buttons for when JS is ignored or preferred
# If $wholeTable is true we are generating buttons for the entire table.
# otherwise the buttons are just for a single row.
# $multirow is true when the buttons need to be generated vertically
sub generateEditButtons {
    my ( $this, $id, $multirow, $wholeTable ) = @_;
    my $attrs     = $this->{attrs};
    my $topRow    = ( $id == ( $attrs->{headerrows} || 0 ) );
    my $sz        = $this->totalRows();
    my $bottomRow = ( $id == $sz - ( $attrs->{footerrows} || 0 ) );
    $id = "_$id" if $id;

    my $buttons = '';

    $buttons = Foswiki::Render::html(
        "input",
        {
            type  => "hidden",
            name  => 'erp_action',
            value => ''
        }
    ) unless $attrs->{js} eq 'ignored';

    if ($wholeTable) {
        $buttons .= _makeButton( 'saveTableCmd', 'ui-icon ui-icon-disk',
            NOISY_SAVE, $attrs );
        if ( $attrs->{quietsave} ) {
            $buttons .=
              _makeButton( 'quietsaveTableCmd', 'erp-quietsave', QUIET_SAVE,
                $attrs );
        }
    }
    else {
        $buttons .= _makeButton( 'saveRowCmd', 'ui-icon ui-icon-disk',
            NOISY_SAVE, $attrs );
        if ( $attrs->{quietsave} ) {
            $buttons .=
              _makeButton( 'quietsaveRowCmd', 'erp-quietsave', QUIET_SAVE,
                $attrs );
        }
    }
    $buttons .=
      _makeButton( 'cancelCmd', 'ui-icon ui-icon-cancel', CANCEL, $attrs );

    if ( Foswiki::Func::isTrue( $this->{attrs}->{changerows} ) ) {
        $buttons .= '<br />' if $multirow;
        if ( !$wholeTable && $id ) {
            if ( !$topRow ) {
                $buttons .=
                  _makeButton( 'upRowCmd', 'ui-icon ui-icon-arrow-1-n',
                    UP_ROW, $attrs, 0 );
            }
            if ( !$bottomRow ) {
                $buttons .=
                  _makeButton( 'downRowCmd', 'ui-icon ui-icon-arrow-1-s',
                    DOWN_ROW, $attrs, 0 );
            }
        }

        $buttons .= _makeButton( 'addRowCmd', 'ui-icon ui-icon-plusthick',
            ADD_ROW, $attrs, 0 );

        unless ( $this->{attrs}->{changerows} eq 'add' ) {
            $buttons .=
              _makeButton( 'deleteRowCmd', 'ui-icon ui-icon-minusthick',
                DELETE_ROW, $attrs, 0 );
        }
    }

    return $buttons;
}

1;
__END__

Author: Crawford Currie http://c-dot.co.uk

Copyright (c) 2009-2016 Foswiki Contributors
Copyright (C) 2007 WindRiver Inc. and TWiki Contributors.
All Rights Reserved. Foswiki Contributors are listed in the
AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

Do not remove this copyright notice.

