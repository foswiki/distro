# See bottom of file for copyright and pod
package Foswiki::Plugins::EditRowPlugin::Table;

use strict;
use Assert;
use Foswiki::Attrs;

use Foswiki::Func;
use Foswiki::Plugins::EditRowPlugin::TableRow;

use vars
  qw($ADD_ROW $DELETE_ROW $QUIET_SAVE $NOISY_SAVE $EDIT_ROW $CANCEL_ROW $UP_ROW $DOWN_ROW);
$ADD_ROW    = 'Add new row after this row / at the end';
$DELETE_ROW = 'Delete this row / last row';
$QUIET_SAVE = 'Quiet Save';
$NOISY_SAVE = 'Save';
$EDIT_ROW   = 'Edit';
$CANCEL_ROW = 'Cancel';
$UP_ROW     = 'Move this row up';
$DOWN_ROW   = 'Move this row down';

sub new {
    my ( $class, $tno, $editable, $spec, $attrs, $web, $topic ) = @_;

    my $this = bless(
        {
            editable => $editable,
            id       => $class->getMacro() . "_$tno",
            spec     => $spec,
            rows     => [],
            topic    => $topic,
            web      => $web,
        },
        $class
    );
    if ( $attrs->{format} ) {
        $this->{colTypes} = $this->parseFormat( $attrs->{format} );
    }
    else {
        $this->{colTypes} = [];
    }

    # if headerislabel true but no headerrows, set headerrows = 1
    if ( $attrs->{headerislabel} && !defined( $attrs->{headerrows} ) ) {
        $attrs->{headerrows} =
          Foswiki::Func::isTrue( $attrs->{headerislabel} ) ? 1 : 0;
    }

    $attrs->{headerrows} ||= 0;
    $attrs->{footerrows} ||= 0;
    my $disable =
      defined( $attrs->{disable} )
      ? $attrs->{disable}
      : Foswiki::Func::getPreferencesValue('EDITROWPLUGIN_DISABLE');
    $attrs->{disable} = $disable || '';
    my $changerows =
      defined( $attrs->{changerows} )
      ? $attrs->{changerows}
      : Foswiki::Func::getPreferencesValue('CHANGEROWS');
    $attrs->{changerows} = Foswiki::Func::isTrue($changerows);
    my $q =
      defined( $attrs->{quietsave} )
      ? $attrs->{quietsave}
      : Foswiki::Func::getPreferencesValue('QUIETSAVE');
    $attrs->{quietsave} = Foswiki::Func::isTrue($q);

    $this->{attrs} = $attrs;

    return $this;
}

# Static method that returns the macro name for this table class
sub getMacro {
    return $Foswiki::cfg{Plugins}{EditRowPlugin}{Macro}
      || 'EDITTABLE';
}

# Create a new row of the type appropriate to this table. The new row is
# *not* added.
sub newRow {
    my $this = shift;
    return new Foswiki::Plugins::EditRowPlugin::TableRow( $this, @_ );
}

# break cycles to ensure we release back to garbage
sub finish {
    my $this = shift;
    foreach my $row ( @{ $this->{rows} } ) {
        $row->finish();
    }
    undef( $this->{rows} );
    undef( $this->{colTypes} );
}

sub stringify {
    my $this = shift;

    my $s = '';
    if ( $this->{editable} ) {
        $s .= "$this->{spec}\n";
    }
    foreach my $row ( @{ $this->{rows} } ) {
        $s .= $row->stringify() . "\n";
    }
    return $s;
}

sub getHeaderRows {
    my $this = shift;
    return $this->{attrs}->{headerrows} || 0;
}

sub getFooterRows {
    my $this = shift;
    return $this->{attrs}->{footerrows} || 0;
}

sub getWeb {
    my $this = shift;
    return $this->{web};
}

sub getTopic {
    my $this = shift;
    return $this->{topic};
}

sub getID {
    my $this = shift;
    return $this->{id};
}

sub isEditable {
    my $this = shift;
    return $this->{editable};
}

sub getFirstLiveRow {
    my $this = shift;

    return $this->{attrs}->{headerrows} + 1;
}

sub getLastLiveRow {
    my $this = shift;

    return scalar( @{ $this->{rows} } ) - $this->{attrs}->{footerrows};
}

# Run after all rows have been added to set header and footer rows
sub _finalise {
    my $this  = shift;
    my $heads = $this->{attrs}->{headerrows};

    while ( $heads-- > 0 ) {
        if ( $heads < scalar( @{ $this->{rows} } ) ) {
            $this->{rows}->[$heads]->{isHeader} = 1;
        }
    }
    my $tails = $this->{attrs}->{footerrows};
    while ( $tails > 0 ) {
        if ( $tails < scalar( @{ $this->{rows} } ) ) {
            $this->{rows}->[ -$tails ]->{isFooter} = 1;
        }
        $tails--;
    }

    # Assign row index numbers to body cells
    my $index = 1;
    foreach my $row ( @{ $this->{rows} } ) {
        if ( $row->{isHeader} || $row->{isFooter} ) {
            $row->{index} = '';
        }
        else {
            $row->{index} = $index++;
        }
    }
}

sub getLabelRow() {
    my $this = shift;

    my $labelRow;
    foreach my $row ( @{ $this->{rows} } ) {
        if ( $row->isHeader() ) {
            $labelRow = $row;
        } else {

            # the last header row is always taken as the label row
            last;
        }
    }
    return $labelRow;
}

# $real_table can be a Table that contains cells for editing, as against
# display. This is used when the contents of the table have already been
# processed by other plugins, but we want to get back to basics for the
# edit.
sub renderForEdit {
    my ( $this, $activeRow, $real_table ) = @_;

    if ( !$this->{editable} ) {
        return $this->renderForDisplay(0);
    }

    $this->_finalise();

    my $wholeTable  = ( $activeRow <= 0 );
    my @out         = ("<a name='erp_$this->{id}'></a>");
    my $orientation = $this->{attrs}->{orientrowedit} || 'horizontal';

    # Disallow vertical display for whole table edits
    $orientation = 'horizontal' if $wholeTable;

    # no special treatment for the first row unless requested
    my $attrs = $this->{attrs};

    my $format = $attrs->{format} || '';

    # SMELL: Have to double-encode the format param to defend it
    # against the rest of Foswiki. We use the escape char '-' as it
    # isn't used by Foswiki.
    $format =~ s/([][@\s%!:-])/sprintf('-%02x',ord($1))/ge;

    # it will get encoded again as a URL param
    push( @out, CGI::hidden( "erp_$this->{id}_format", $format ) );
    if ( $attrs->{headerrows} ) {
        push( @out,
            CGI::hidden( "erp_$this->{id}_headerrows", $attrs->{headerrows} ) );
    }
    if ( $attrs->{footerrows} ) {
        push( @out,
            CGI::hidden( "erp_$this->{id}_footerrows", $attrs->{footerrows} ) );
    }

    my $rowControls = !($wholeTable);
    my $n           = 0;                # displayed row index
    my $r           = 0;                # real row index
    foreach my $row ( @{ $this->{rows} } ) {
        $n++ unless ( $row->{isHeader} || $row->{isFooter} );
        if ( ++$r == $activeRow
            || $wholeTable && !$row->{isHeader} && !$row->{isFooter} )
        {

            # Get the row from the real_table, read raw from the topic
            my $real_row = $real_table ?
              $real_table->{rows}->[ $r - 1 ] : $row;
            next unless $real_row;
            push(
                @out,
                $real_row->renderForEdit(
                    $this->{colTypes}, $rowControls, $orientation
                )
            );
        }
        else {
            push( @out,
                $row->renderForDisplay( $this->{colTypes}, $rowControls ) );
        }
    }
    if ($wholeTable) {
        push( @out, $this->generateEditButtons( 0, 0 ) );
        my $help = $this->generateHelp();
        push( @out, $help ) if $help;
    }
    return join( "\n", @out ) . "\n";
}

sub renderForDisplay {
    my ( $this, $showControls ) = @_;
    my @out;

    $showControls = 0 unless $this->{editable};

    $this->_finalise();

    my $attrs = $this->{attrs};

    my $n = 0;
    my $rowControls = ( $showControls && $this->{attrs}->{disable} !~ /row/ );
    foreach my $row ( @{ $this->{rows} } ) {
        $n++ unless ( $row->{isHeader} || $row->{isFooter} );
        push( @out, $row->renderForDisplay( $this->{colTypes}, $rowControls ) );
    }

    # Generate the buttons at the bottom of the table
    my $script = 'view';
    if ( $showControls && !Foswiki::Func::getContext()->{authenticated} ) {

        # A  bit of a hack. If the user isn't logged in, then show the
        # table edit button anyway, but redirect them to viewauth to force
        # login.
        $script       = 'viewauth';
        $showControls = $this->{editable};
    }

    my $active_topic = "$this->{web}.$this->{topic}";

    if ($showControls) {
        if ( $this->{attrs}->{disable} !~ /full/ ) {

            # Full table editing is not disabled
            my $title  = "Edit full table";
            my $button = CGI::img(
                {
                    -name   => "erp_edit_$this->{id}",
                    -border => 0,
                    -src =>
                      '%PUBURLPATH%/%SYSTEMWEB%/EditRowPlugin/edittable.gif',
                    -title => $title,
                }
            );
            my $url = Foswiki::Func::getScriptUrl(
                $this->{web}, $this->{topic}, $script,
                erp_active_topic => $active_topic,
                erp_active_table => $this->{id},
                erp_active_row   => -1,
                '#'              => 'erp_' . $this->{id}
            );

            push( @out,
                    "<a name='erp_$this->{id}'></a>"
                  . "<a href='$url' title='$title'>"
                  . $button
                  . '</a><br />' );
        }
        elsif ($this->{attrs}->{changerows}
            && $this->{attrs}->{disable} !~ /row/ )
        {
            my $title  = "Add row to end of table";
            my $button = CGI::img(
                {
                    -name   => "erp_edit_$this->{id}",
                    -border => 0,
                    -src => '%PUBURLPATH%/%SYSTEMWEB%/EditRowPlugin/addrow.gif',
                    -title => $title,
                },
                ''
            );
            my $url;

            # erp_unchanged=1 prevents addRow from trying to
            # save changes in the table. erp_active_row is set to -2
            # so that addRow enters single row editing mode (see sub addRow)
            $url = Foswiki::Func::getScriptUrl(
                'EditRowPlugin', 'save', 'rest',
                erp_active_topic => $active_topic,
                erp_active_table => $this->{id},
                erp_active_row   => -2,
                erp_unchanged    => 1,
                'erp_addRow.x'   => 1,
                '#'              => 'erp_' . $this->{id}
            );

            # Full table disabled, but not row
            push( @out, "<a href='$url' title='$title'>$button</a><br />" );
        }
    }

    return join( "\n", @out );
}

# Get the cols for the given row, padding out with empty cols if
# the row is shorter than the type def for the table.
sub _getCols {
    my ( $this, $urps, $row ) = @_;
    my $attrs    = $this->{attrs};
    my $headRows = $attrs->{headerrows};
    my $count    = scalar( @{ $this->{rows}->[ $row - 1 ]->{cols} } );
    my $defs     = scalar( @{ $this->{colTypes} } );
    $count = $defs if $defs > $count;
    my @cols;
    for ( my $i = 0 ; $i < $count ; $i++ ) {
        my $colDef = $this->{colTypes}->[$i];
        my $cellName =
          'erp_cell_' . $this->{id} . '_' . $row . '_' . ( $i + 1 );
        my $cell = $this->{rows}->[ $row - 1 ]->{cols}->[$i];

        # Check current value for format-overriding EDITCELL
        if ( $cell->{text} =~ /%EDITCELL{(.*?)}%/ ) {
            my $cd = $this->parseFormat($1);
            $colDef = $cd->[0];
        }
        if ( defined $colDef->{type} ) {
            if ( $colDef->{type} eq 'row' ) {

                # Force numbering if this is an auto-numbered column
                $urps->{$cellName} = $row - $headRows + $colDef->{size};
            }
            elsif ( $colDef->{type} eq 'label' ) {

                # Label cells are uneditable, so we have to keep any existing
                # value for them. If there is no value in the cell, restore
                # the initial value.
                $urps->{$cellName} =
                  ($cell->{text} || $colDef->{initial_value} );
            }
        }
        $urps->{$cellName} = '' unless defined $urps->{$cellName};
        push( @cols, $urps->{$cellName} );
    }
    return \@cols;
}

# Action on row saved
sub change {
    my ( $this, $urps ) = @_;
    my $row = $urps->{erp_active_row};
    if ( $row > 0 ) {

        # Single row
        $this->{rows}->[ $row - 1 ]->set( $this->_getCols( $urps, $row ) );
    }
    else {

        # Whole table (sans header and footer rows)
        my $end = scalar( @{ $this->{rows} } ) - $this->{attrs}->{footerrows};
        for ( my $i = $this->{attrs}->{headerrows} ; $i < $end ; $i++ ) {
            $this->{rows}->[$i]->set( $this->_getCols( $urps, $i + 1 ) );
        }
    }
}

# Action on move up; save and shift row
sub moveUp {
    my ( $this, $urps ) = @_;
    change( $this, $urps );
    my $row = $urps->{erp_active_row};
    my $tmp = $this->{rows}->[ $row - 1 ];
    $this->{rows}->[ $row - 1 ] = $this->{rows}->[ $row - 2 ];
    $this->{rows}->[ $row - 2 ] = $tmp;
    $urps->{erp_active_row}--;
}

# Action on move down; save and shift row
sub moveDown {
    my ( $this, $urps ) = @_;
    change( $this, $urps );
    my $row = $urps->{erp_active_row};
    my $tmp = $this->{rows}->[ $row - 1 ];
    $this->{rows}->[ $row - 1 ] = $this->{rows}->[$row];
    $this->{rows}->[$row] = $tmp;
    $urps->{erp_active_row}++;
}

# Action on row added
sub addRow {
    my ( $this, $urps ) = @_;
    my @cols;
    my $row = $urps->{erp_active_row};

    unless ( $urps->{erp_unchanged} ) {
        $this->change($urps);    # in case data has changed
    }

    if ( $row < 0 ) {

        # Full table edit
        $row = $this->getLastLiveRow();
    }

    my @vals = map { $_->{initial_value} } @{ $this->{colTypes} };

    # widen up to the width of the previous row
    my $count;
    if ( scalar( @{ $this->{rows} } ) ) {
        my $count = scalar( @{ $this->{rows}->[ $row - 1 ]->{cols} } );
        while ( scalar(@vals) < $count ) {
            push( @vals, '' );
        }
    }
    my $newRow = $this->newRow( $row, '|', '|', \@vals );
    splice( @{ $this->{rows} }, $row, 0, $newRow );

    # renumber lower rows
    for ( my $i = $row + 1 ; $i < scalar( @{ $this->{rows} } ) ; $i++ ) {
        $this->{rows}->[$i]->{number}++;
    }

    # -1 means full table edit; -2 means a row is being added to
    # a table not currently being edited
    if ( $urps->{erp_active_row} != -1 ) {
        $urps->{erp_active_row} = $row + 1;
    }
}

# Action on row deleted
sub deleteRow {
    my ( $this, $urps ) = @_;

    $this->change($urps);    # in case data hase changed

    my $row = $urps->{erp_active_row};
    if ( $row < $this->getFirstLiveRow() ) {
        $row = $this->getLastLiveRow();
    }
    return unless $row >= $this->getFirstLiveRow();
    my @dead = splice( @{ $this->{rows} }, $row - 1, 1 );
    map { $_->finish() } @dead;
    return if $urps->{erp_active_row} < 0;    # full table edit?
    $urps->{erp_active_row} = $row;

    # Make sure that the active row is a non-header, non-footer row
    if ( $urps->{erp_active_row} < $this->getFirstLiveRow() ) {
        $urps->{erp_active_row} = $this->getFirstLiveRow();
    }
    if ( $urps->{erp_active_row} > $this->getLastLiveRow() ) {
        $urps->{erp_active_row} = $this->getLastLiveRow();
        if ( $urps->{erp_active_row} < $this->getFirstLiveRow() ) {

            # No active rows left
            $urps->{erp_active_row} = -1;
        }
    }
}

# Action on edit cancelled
sub cancel {
}

# Package private method that parses a column type specification
sub parseFormat {
    my ( $this, $format ) = @_;
    my @cols;

    $format =~ s/^\s*\|//;
    $format =~ s/\|\s*$//;

    $format =
      Foswiki::Func::expandCommonVariables( $format, $this->{topic},
        $this->{web} );
    $format =~ s/\$nop(\(\))?//gs;
    $format =~ s/\$quot(\(\))?/\"/gs;
    $format =~ s/\$percnt(\(\))?/\%/gs;
    $format =~ s/\$dollar(\(\))?/\$/gs;
    $format =~ s/<nop>//gos;

    foreach my $column ( split( /\|/, $format ) ) {
        my ( $type, $size, @values ) = split( /,/, $column );

        $type ||= 'text';
        $type = lc $type;
        $type =~ s/^\s*//;
        $type =~ s/\s*$//;

        $size ||= 0;
        $size =~ s/[^\w.]//g;

        unless ($size) {
            if ( $type eq 'text' ) {
                $size = 20;
            }
            elsif ( $type eq 'textarea' ) {
                $size = '40x5';
            }
            else {
                $size = 1;
            }
        }

        my $initial = '';
        if ( $type =~ /^(text|label)/ ) {
            $initial = join( ',', @values );
        }

        @values = map { s/^\s*//; s/\s*$//; $_ } @values;
        push(
            @cols,
            {
                type          => $type,
                size          => $size,
                values        => \@values,
                initial_value => $initial,
            }
        );
    }

    return \@cols;
}

sub generateHelp {
    my ($this) = @_;
    my $attrs = $this->{attrs};
    my $help;
    if ( $attrs->{helptopic} ) {
        my ( $web, $topic ) =
          Foswiki::Func::normalizeWebTopicName( $this->{web},
            $attrs->{helptopic} );
        my ( $meta, $text ) = Foswiki::Func::readTopic( $web, $topic );
        $text =~ s/.*?%STARTINCLUDE%//s;
        $text =~ s/%STOPINCLUDE%.*//s;
        $text =~ s/^\s*//s;
        $text =~ s/\s*$//s;
        $help = Foswiki::Func::renderText($text);
        $help =~ s/\n/ /g;
    }
    return $help;
}

sub generateEditButtons {
    my ( $this, $id, $multirow ) = @_;
    my $attrs     = $this->{attrs};
    my $topRow    = ( $id == $attrs->{headerrows} + 1 );
    my $sz        = scalar( @{ $this->{rows} } );
    my $bottomRow = ( $id == $sz - $attrs->{footerrows} );
    $id = "_$id" if $id;

    my $buttons = CGI::hidden(-name => 'erp_action', -value => '');
    $buttons .= CGI::a(
        {
            href  => 'erp_save',
            title => $NOISY_SAVE,
	    class => 'erp_submit ui-icon ui-icon-disk'
        },
	$NOISY_SAVE
    );

    if ( $attrs->{quietsave} ) {
        $buttons .= CGI::image_button(
            {
                href  => 'erp_quietSave',
                title => $QUIET_SAVE,
                src   => '%PUBURLPATH%/%SYSTEMWEB%/EditRowPlugin/quiet.gif'
            },
            $QUIET_SAVE
        );
    }
    $buttons .= CGI::a(
        {
            href  => 'erp_cancel',
            title => $CANCEL_ROW,
	    class => 'erp_submit ui-icon ui-icon-cancel'
        },
        $CANCEL_ROW
    );

    if ( $this->{attrs}->{changerows} ) {
        $buttons .= '<br />' if $multirow;
        if ($id) {
            if ( !$topRow ) {
                $buttons .= CGI::a(
                    {
                        href  => 'erp_upRow',
                        title => $UP_ROW,
			class => 'erp_submit ui-icon ui-icon-arrow-1-n'
                    },
		    $UP_ROW
                );
            }
            if ( !$bottomRow ) {
                $buttons .= CGI::a(
                    {
                        href  => 'erp_downRow',
                        title => $DOWN_ROW,
 			class => 'erp_submit ui-icon ui-icon-arrow-1-s'
                    },
		    $DOWN_ROW
                );
            }
        }
        $buttons .= CGI::a(
            {
                href  => 'erp_addRow',
                title => $ADD_ROW,
                class => 'erp_submit ui-icon ui-icon-plusthick'
            },
	    $ADD_ROW
        );

        $buttons .= CGI::a(
            {
                href  => 'erp_deleteRow',
                class => 'editRowPlugin_willDiscard erp_submit ui-icon ui-icon-minusthick',
                title => $DELETE_ROW
            },
	    $DELETE_ROW
        );
    }
    return $buttons;
}

1;
__END__

Author: Crawford Currie http://c-dot.co.uk

Copyright (c) 2009 Foswiki Contributors
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

This is an object that represents a table.

=pod

---+ package Foswiki::Plugins::EditRowPlugin::Table
Representation of an editable table

=cut

=begin TML

---++ new($tno, $attrs, $web, $topic)
Constructor
   * $tno = table number (sequence in data, usually) (start at 1)
   * $attrs - Foswiki::Attrs of the relevant %EDITTABLE
   * $web - the web
   * $topic - the topic

---++ finish()
Must be called to dispose of a Table object. This method disconnects internal pointers that would
otherwise make a Table and its rows and cells self-referential.

---++ stringify()
Generate a TML representation of the table

---++ renderForEdit($activeRow) -> $text
Render the table for editing. Standard TML is used to construct the table.
   $activeRow - the number of the row being edited

---++ renderForDisplay() -> $text
Render the table for display. Standard TML is used to construct the table.

---++ changeRow(\%urps)
Commit changes from the query into the table.
   * $urps - url parameters

---++ addRow(\%urps)
Add a row after the active row containing the data from the query
   * $urps - hash of parameters
      * =active_row= - the row to add after
      * 

---++ deleteRow(\%urps)
Delete the current row, as defined by active_row in $urps
   * $urps - url parameters

=cut

