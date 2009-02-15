# See bottom of file for copyright and pod
package Foswiki::Plugins::EditRowPlugin::Table;

use strict;
use Assert;
use Foswiki::Attrs;

use Foswiki::Func;
use Foswiki::Plugins::EditRowPlugin::TableRow;
use Foswiki::Plugins::EditRowPlugin::TableCell;

use vars qw($ADD_ROW $DELETE_ROW $QUIET_SAVE $NOISY_SAVE $EDIT_ROW $CANCEL_ROW $UP_ROW $DOWN_ROW);
$ADD_ROW    = 'Add new row after this row / at the end';
$DELETE_ROW = 'Delete this row / last row';
$QUIET_SAVE = 'Quiet Save';
$NOISY_SAVE = 'Save';
$EDIT_ROW   = 'Edit';
$CANCEL_ROW = 'Cancel';
$UP_ROW     = 'Move this row up';
$DOWN_ROW   = 'Move this row down';

# Static method that parses tables out of a block of text
# Returns an array of lines, with those lines that represent editable
# tables plucked out and replaced with references to table objects
sub parseTables {
    my ($text, $web, $topic, $meta, $urps) = @_;
    my $active_table = undef;
    my $hasRows = 0;
    my @tables;
    my $nTables = 0;
    my $disable = 0;
    my $openRow = undef;
    my @comments;

    $text =~ s/(<!--.*?-->)/
      push(@comments, $1); "\001-".scalar(@comments)."-\001"/seg;

    foreach my $line (split(/\r?\n/, $text)) {
        if ($line =~ /<(verbatim|literal)>/) {
            $disable++;
        }
        if ($line =~ m#</(verbatim|literal)>#) {
            $disable-- if $disable;
        }
        # Remove the marks that highlight included tables, and omit
        # them from processing
        if ($line =~ s/^<!-- STARTINCLUDE .* -->$//) {
            $disable++;
            next;
        }
        if ($line =~ s/^<!-- STOPINCLUDE .* -->$//) {
            $disable-- if $disable;
            next;
        }
        if (defined $openRow) {
            $line = "$openRow$line";
            $openRow = undef;
        }

        # Process an EDITTABLE. The tag will be associated with the
        # next table encountered in the topic.
        if (!$disable && $line =~ s/(%EDITTABLE{(.*)}%)// ) {
            my $spec = $1;
            my $attrs = new Foswiki::Attrs(
                Foswiki::Func::expandCommonVariables($2, $web, $topic));
            push(@tables, $line) if $line =~ /\S/;
            # Editable table
            $nTables++;
            my %read = ( "$web.$topic" => 1 );
            while ($attrs->{include}) {
                my ($iw, $it) = Foswiki::Func::normalizeWebTopicName(
                    $web, $attrs->{include});
                # This check is missing from EditTablePlugin
                unless (Foswiki::Func::topicExists($iw, $it)) {
                    $line = CGI::span(
                        { class=>'foswikiAlert' },
                        "Could not find format topic $attrs->{include}");
                }
                if ($read{"$iw.$it"}) {
                    $line = CGI::span(
                        { class=>'foswikiAlert' },
                        "Recursive include of $attrs->{include}");
                }
                $read{"$iw.$it"} = 1;
                my ($meta, $text) = Foswiki::Func::readTopic($iw, $it);
                my $params = '';
                if ($text =~ m/%EDITTABLE{([^\n]*)}%/s) {
                    $params = $1;
                }
                if ($params) {
                    $params = Foswiki::Func::expandCommonVariables(
                        $params, $iw, $it);
                }
                $attrs = new Foswiki::Attrs($params);
            }
            # is there a format in the query? if there is,
            # override the format we just parsed
            if ($urps) {
                my $format = $urps->{"erp_${nTables}_format"};
                if (defined($format)) {
                    # undo the encoding
                    $format =~ s/-([a-z\d][a-z\d])/chr(hex($1))/gie;
                    $attrs->{format} = $format;
                }
                if (defined($urps->{"erp_${nTables}_headerrows"})) {
                    $attrs->{headerrows} =
                      $urps->{"erp_${nTables}_headerrows"};
                }
                if (defined($urps->{"erp_${nTables}_footerrows"})) {
                    $attrs->{footerrows} =
                      $urps->{"erp_${nTables}_footerrows"};
                }
            }
            $active_table =
              new Foswiki::Plugins::EditRowPlugin::Table(
                  $nTables, 1, $spec, $attrs, $web, $topic);
            push(@tables, $active_table);
            $hasRows = 0;
            next;
        }

        elsif (!$disable && $line =~ /^\s*\|/ && $active_table) {
            if ($line =~ s/\\$//) {
                # Continuation
                $openRow = $line;
                next;
            }
            my $precruft = '';
            $precruft = $1 if $line =~ s/^(\s*\|)//;
            my $postcruft = '';
            $postcruft = $1 if $line =~ s/(\|\s*)$//;
            if (!$active_table) {
                # Uneditable table
                $nTables++;
                my $attrs => new Foswiki::Attrs('');
                $active_table =
                  new Foswiki::Plugins::EditRowPlugin::Table(
                      $nTables, 0, $line, $attrs, $web, $topic);
                push(@tables, $active_table);
            }
            # Note use of LIMIT=-1 on the split so we don't lose empty columns
            my @cols;
            if (length($line)) {
                @cols = split(/\|/, $line, -1);
            } else {
                # Splitting an EXPR that evaluates to the empty string always
                # returns the empty list, regardless of the LIMIT specified.
                push(@cols, '');
            }
            my $row = new Foswiki::Plugins::EditRowPlugin::TableRow(
                $active_table, scalar(@{$active_table->{rows}}) + 1,
                $precruft, $postcruft,
                \@cols);
            push(@{$active_table->{rows}}, $row);
            $hasRows = 1;
            next;
        }

        elsif (!$disable && $hasRows) {
            # associated table has been terminated
            $active_table = undef;
        }

        push(@tables, $line);
    }

    my @result;
    foreach my $t (@tables) {
        if (UNIVERSAL::isa($t, 'Foswiki::Plugins::EditRowPlugin::Table')) {
            if (!scalar(@{$t->{rows}}) &&
                  defined($t->{attrs}->{header})) {
                # Legacy: add a header if the header param is defined and
                # the table has no rows.
                my $line = $t->{attrs}->{header};
                my $precruft = '';
                $precruft = $1 if $line =~ s/^(\s*\|)//;
                my $postcruft = '';
                $postcruft = $1 if $line =~ s/(\|\s*)$//;
                my @cols = split(/\|/, $line, -1);
                my $row = new Foswiki::Plugins::EditRowPlugin::TableRow(
                    $t, 1, $precruft, $postcruft, \@cols);
                push(@{$t->{rows}}, $row);
            }
        } else {
            # Expand comments again
            $t =~ s/\001-(\d+)-\001/$comments[$1 - 1]/ges;
        }
        push(@result, $t);
    }

    return \@result;
}

sub new {
    my ($class, $tno, $editable, $spec, $attrs, $web, $topic) = @_;

    my $this = bless({}, $class);
    $this->{editable} = $editable;
    $this->{number} = $tno;
    $this->{spec} = $spec;
    $this->{rows} = [];
    $this->{topic} = $topic;
    $this->{web} = $web;

    if ($attrs->{format}) {
        $this->{colTypes} = $this->parseFormat($attrs->{format});
    } else {
        $this->{colTypes} = [];
    }

    # if headerislabel true but no headerrows, set headerrows = 1
    if ($attrs->{headerislabel} && !defined($attrs->{headerrows})) {
        $attrs->{headerrows} = Foswiki::Func::isTrue($attrs->{headerislabel}) ? 1 : 0;
    }

    $attrs->{headerrows} ||= 0;
    $attrs->{footerrows} ||= 0;
    my $disable = defined($attrs->{disable}) ?
      $attrs->{disable} :
        Foswiki::Func::getPreferencesValue('EDITROWPLUGIN_DISABLE');
    $attrs->{disable} = $disable || '';
    my $changerows = defined($attrs->{changerows}) ?
      $attrs->{changerows} :
        Foswiki::Func::getPreferencesValue('CHANGEROWS');
    $attrs->{changerows} = Foswiki::Func::isTrue($changerows);
    my $q = defined($attrs->{quietsave}) ?
      $attrs->{quietsave} :
        Foswiki::Func::getPreferencesValue('QUIETSAVE');
    $attrs->{quietsave} = Foswiki::Func::isTrue($q);

    $this->{attrs} = $attrs;

    return $this;
}

# break cycles to ensure we release back to garbage
sub finish {
    my $this = shift;
    foreach my $row (@{$this->{rows}}) {
        $row->finish();
    }
    undef($this->{rows});
    undef($this->{colTypes});
}

sub stringify {
    my $this = shift;

    my $s = '';
    if ($this->{editable}) {
        $s .= "$this->{spec}\n";
    }
    foreach my $row (@{$this->{rows}}) {
        $s .= $row->stringify()."\n";
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

sub getNumber {
    my $this = shift;
    return $this->{number};
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

    return scalar(@{$this->{rows}}) - $this->{attrs}->{footerrows};
}

# Run after all rows have been added to set header and footer rows
sub _finalise {
    my $this = shift;
    my $heads = $this->{attrs}->{headerrows};

    while ($heads-- > 0) {
        if ($heads < scalar(@{$this->{rows}})) {
            $this->{rows}->[$heads]->{isHeader} = 1;
        }
    }
    my $tails = $this->{attrs}->{footerrows};
    while ($tails > 0) {
        if ($tails < scalar(@{$this->{rows}})) {
            $this->{rows}->[-$tails]->{isFooter} = 1;
        }
        $tails--;
    }
    # Assign row index numbers to body cells
    my $index = 1;
    foreach my $row (@{$this->{rows}}) {
        if ($row->{isHeader} || $row->{isFooter}) {
            $row->{index} = '';
        } else {
            $row->{index} = $index++;
        }
    }
}

sub getLabelRow() {
    my $this = shift;

    my $labelRow;
    foreach my $row (@{$this->{rows}}) {
        if ($row->{isHeader}) {
            $labelRow = $row;
        } else {
            # the last header row is always taken as the label row
            last;
        }
    }
    return $labelRow;
}

sub renderForEdit {
    my ($this, $activeRow) = @_;

    if (!$this->{editable}) {
        return $this->renderForDisplay(0);
    }

    $this->_finalise();

    my $wholeTable = ($activeRow <= 0);
    my @out = ( "<a name='erp_$this->{number}'></a>" );
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
    push(@out, CGI::hidden("erp_$this->{number}_format", $format));
    if ($attrs->{headerrows}) {
        push(@out, CGI::hidden("erp_$this->{number}_headerrows",
                               $attrs->{headerrows}));
    }
    if ($attrs->{footerrows}) {
        push(@out, CGI::hidden("erp_$this->{number}_footerrows",
                               $attrs->{footerrows}));
    }

    my $rowControls = !($wholeTable);
    my $n = 0; # displayed row index
    my $r = 0; # real row index
    foreach my $row (@{$this->{rows}}) {
        $n++ unless ($row->{isHeader} || $row->{isFooter});
        if (++$r == $activeRow ||
              $wholeTable && !$row->{isHeader} && !$row->{isFooter}) {
            push(@out, $row->renderForEdit(
                $this->{colTypes}, $rowControls, $orientation));
        } else {
            push(@out, $row->renderForDisplay(
                $this->{colTypes}, $rowControls));
        }
    }
    if ($wholeTable) {
        push(@out, $this->generateEditButtons(0, 0));
        my $help = $this->generateHelp();
        push(@out, $help) if $help;
    }
    return join("\n", @out)."\n";
}

sub renderForDisplay {
    my ($this, $showControls) = @_;
    my @out;

    $showControls = 0 unless $this->{editable};

    $this->_finalise();

    my $attrs = $this->{attrs};

    my $n = 0;
    my $rowControls = ($showControls && $this->{attrs}->{disable} !~ /row/);
    foreach my $row (@{$this->{rows}}) {
        $n++ unless ($row->{isHeader} || $row->{isFooter});
        push(@out, $row->renderForDisplay(
            $this->{colTypes}, $rowControls));
    }

    # Generate the buttons at the bottom of the table
    my $script = 'view';
    if ($showControls && !Foswiki::Func::getContext()->{authenticated}) {
        # A  bit of a hack. If the user isn't logged in, then show the
        # table edit button anyway, but redirect them to viewauth to force
        # login.
        $script = 'viewauth';
        $showControls = $this->{editable};
    }

    my $active_topic = "$this->{web}.$this->{topic}";

    if ($showControls) {
        if ($this->{attrs}->{disable} !~ /full/) {
            # Full table editing is not disabled
            my $title = "Edit full table";
            my $button =
              CGI::img({
                  -name => "erp_edit_$this->{number}",
                  -border => 0,
                  -src => '%PUBURLPATH%/%SYSTEMWEB%/EditRowPlugin/edittable.gif',
                  -title => $title,
              });
            my $url;
            if ($Foswiki::Plugins::VERSION < 1.11) {
                $url = Foswiki::Func::getScriptUrl(
                    $this->{web}, $this->{topic}, $script)
                  .'?erp_active_topic='.$active_topic
                    .';erp_active_table='.$this->{number}
                      .';erp_active_row=-1'
                        .'#erp_'.$this->{number};
            } else {
                $url = Foswiki::Func::getScriptUrl(
                    $this->{web}, $this->{topic}, $script,
                    erp_active_topic => $active_topic,
                    erp_active_table => $this->{number},
                    erp_active_row => -1,
                    '#' => 'erp_'.$this->{number});
            }

            push(@out,
                 "<a name='erp_$this->{number}'></a>".
                   "<a href='$url' title='$title'>" . $button . '</a><br />');
        } elsif ($this->{attrs}->{changerows} &&
                   $this->{attrs}->{disable} !~ /row/) {
            my $title = "Add row to end of table";
            my $button = CGI::img({
                -name => "erp_edit_$this->{number}",
                -border => 0,
                -src => '%PUBURLPATH%/%SYSTEMWEB%/EditRowPlugin/addrow.gif',
                -title => $title,
               }, '');
            my $url;
            # Note: erp_unchanged prevents addRow from trying to
            # save changes in the table
            if ($Foswiki::Plugins::VERSION < 1.11) {
                $url = Foswiki::Func::getScriptUrl(
                    'EditRowPlugin', 'save', 'rest')
                  .'?erp_active_topic='.$active_topic
                    .';erp_active_table='.$this->{number}
                      .';erp_active_row=-1'
                        .';erp_unchanged=-1'
                          .';erp_addRow.x=1'
                            .'#erp_'.$this->{number};
            } else {
                $url = Foswiki::Func::getScriptUrl(
                    'EditRowPlugin', 'save', 'rest',
                    erp_active_topic => $active_topic,
                    erp_active_table => $this->{number},
                    erp_active_row => -1,
                    erp_unchanged => 1,
                    'erp_addRow.x' => 1,
                    '#' => 'erp_'.$this->{number});
            }
            # Full table disabled, but not row
            push(@out, "<a href='$url' title='$title'>$button</a><br />");
        }
    }

    return join("\n", @out);
}

# Get the cols for the given row, padding out with empty cols if
# the row is shorter than the type def for the table.
sub _getCols {
    my ($this, $urps, $row) = @_;
    my $attrs = $this->{attrs};
    my $headRows = $attrs->{headerrows};
    my $count = scalar(@{$this->{rows}->[$row - 1]->{cols}});
    my $defs = scalar(@{$this->{colTypes}});
    $count = $defs if $defs > $count;
    my @cols;
    for (my $i = 0; $i < $count; $i++) {
        my $colDef = $this->{colTypes}->[$i];
        my $cellName = 'erp_cell_'.$this->{number}.'_'.$row.'_'.($i + 1);
        my $cell = $this->{rows}->[$row - 1]->{cols}->[$i];
        # Check current value for format-overriding EDITCELL
        if ($cell->{text} =~/%EDITCELL{(.*?)}%/) {
            my $cd = $this->parseFormat($1);
            $colDef = $cd->[0];
        }
        if ($colDef->{type} && $colDef->{type} eq 'row') {
            # Force numbering if this is an auto-numbered column
            $urps->{$cellName} = $row - $headRows + $colDef->{size};
        } elsif ($colDef->{type} && $colDef->{type} eq 'label') {
            # Label cells are uneditable, so we have to keep any existing
            # value for them.
            $urps->{$cellName} = $cell->{text};
        }
        # CGI returns multi-values separated by \0. Replace with
        # the Foswiki convention, comma
        $urps->{$cellName} ||= '';
        $urps->{$cellName} =~ s/\0/, /g;
        push(@cols, $urps->{$cellName});
    }
    return \@cols;
}

# Action on row saved
sub change {
    my ($this, $urps) = @_;
    my $row = $urps->{erp_active_row};
    if ($row > 0) {
        # Single row
        $this->{rows}->[$row - 1]->set($this->_getCols($urps, $row));
    } else {
        # Whole table (sans header and footer rows)
        my $end = scalar(@{$this->{rows}}) - $this->{attrs}->{footerrows};
        for (my $i = $this->{attrs}->{headerrows}; $i < $end; $i++) {
            $this->{rows}->[$i]->set($this->_getCols($urps, $i + 1));
        }
    }
}

# Action on move up; save and shift row
sub moveUp {
    my ($this, $urps) = @_;
    change($this, $urps);
    my $row = $urps->{erp_active_row};
    my $tmp = $this->{rows}->[$row - 1];
    $this->{rows}->[$row - 1] = $this->{rows}->[$row - 2];
    $this->{rows}->[$row - 2] = $tmp;
    $urps->{erp_active_row}--;
}

# Action on move down; save and shift row
sub moveDown {
    my ($this, $urps) = @_;
    change($this, $urps);
    my $row = $urps->{erp_active_row};
    my $tmp = $this->{rows}->[$row - 1];
    $this->{rows}->[$row - 1] = $this->{rows}->[$row];
    $this->{rows}->[$row] = $tmp;
    $urps->{erp_active_row}++;
}

# Action on row added
sub addRow {
    my ($this, $urps) = @_;
    my @cols;
    my $row = $urps->{erp_active_row};

    unless( $urps->{erp_unchanged} ) {
        $this->change($urps); # in case data has changed
    }

    if ($row < 0) {
        # Full table edit
        $row = $this->getLastLiveRow();
    }

    my @vals = map { $_->{initial_value} } @{$this->{colTypes}};
    # widen up to the width of the previous row
    my $count;
    if (scalar(@{$this->{rows}})) {
        my $count = scalar(@{$this->{rows}->[$row - 1]->{cols}});
        while (scalar(@vals) < $count) {
            push(@vals, '');
        }
    }
    my $newRow = new Foswiki::Plugins::EditRowPlugin::TableRow(
        $this, $row, '|', '|', \@vals);
    splice(@{$this->{rows}}, $row, 0, $newRow);
    # renumber lower rows
    for (my $i = $row + 1; $i < scalar(@{$this->{rows}}); $i++) {
        $this->{rows}->[$i]->{number}++;
    }
    if ($urps->{erp_active_row} >= 0) {
        $urps->{erp_active_row} = $row + 1;
    }
}

# Action on row deleted
sub deleteRow {
    my ($this, $urps) = @_;

    $this->change($urps); # in case data hase changed

    my $row = $urps->{erp_active_row};
    if ($row < $this->getFirstLiveRow()) {
        $row = $this->getLastLiveRow();
    }
    return unless $row >= $this->getFirstLiveRow();
    my @dead = splice(@{$this->{rows}}, $row - 1, 1);
    map { $_->finish() } @dead;
    return if $urps->{erp_active_row} < 0; # full table edit?
    $urps->{erp_active_row} = $row;
    # Make sure that the active row is a non-header, non-footer row
    if ($urps->{erp_active_row} < $this->getFirstLiveRow()) {
        $urps->{erp_active_row} = $this->getFirstLiveRow();
    }
    if ($urps->{erp_active_row} > $this->getLastLiveRow()) {
        $urps->{erp_active_row} = $this->getLastLiveRow();
        if ($urps->{erp_active_row} < $this->getFirstLiveRow()) {
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
    my ($this, $format) = @_;
    my @cols;

    $format =~ s/^\s*\|//;
    $format =~ s/\|\s*$//;

    $format = Foswiki::Func::expandCommonVariables(
        $format, $this->{topic}, $this->{web});
    $format =~ s/\$nop(\(\))?//gs;
    $format =~ s/\$quot(\(\))?/\"/gs;
    $format =~ s/\$percnt(\(\))?/\%/gs;
    $format =~ s/\$dollar(\(\))?/\$/gs;
    $format =~ s/<nop>//gos;

    foreach my $column (split ( /\|/, $format ))  {
        my ($type, $size, @values) = split(/,/, $column);

        $type ||= 'text';
        $type = lc $type;
        $type =~ s/^\s*//;
        $type =~ s/\s*$//;

        $size ||= 0;
        $size =~ s/[^\w.]//g;

        unless( $size ) {
            if( $type eq 'text' ) {
                $size = 20;
            } elsif( $type eq 'textarea' ) {
                $size = '40x5';
            } else {
                $size = 1;
            }
        }

        my $initial = '';
        if ($type =~ /^(text|label)/) {
            $initial = join(',', @values);
        }

        @values = map { s/^\s*//; s/\s*$//; $_ } @values;
        push(@cols,
             {
                 type => $type,
                 size => $size,
                 values => \@values,
                 initial_value => $initial,
             });
    }

    return \@cols;
}

sub generateHelp {
    my ($this) = @_;
    my $attrs = $this->{attrs};
    my $help;
    if ($attrs->{helptopic}) {
        my ($web, $topic) = Foswiki::Func::normalizeWebTopicName(
            $this->{web}, $attrs->{helptopic});
        my ($meta, $text) = Foswiki::Func::readTopic($web, $topic);
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
    my ($this, $id, $multirow) = @_;
    my $attrs = $this->{attrs};
    my $topRow = ($id == $attrs->{headerrows} + 1);
    my $sz = scalar(@{$this->{rows}});
    my $bottomRow = ($id == $sz - $attrs->{footerrows});
    $id = "_$id" if $id;

    my $buttons = '';
    $buttons .=
      CGI::image_button({
          name => 'erp_save',
          value => $NOISY_SAVE,
          title => $NOISY_SAVE,
          src => '%PUBURLPATH%/%SYSTEMWEB%/EditRowPlugin/save.gif'
         }, '');
    if ($attrs->{quietsave}) {
        $buttons .= CGI::image_button({
            name => 'erp_quietSave',
            value => $QUIET_SAVE,
            title => $QUIET_SAVE,
            src => '%PUBURLPATH%/%SYSTEMWEB%/EditRowPlugin/quiet.gif'
           }, '');
    }
    $buttons .= CGI::image_button({
        name => 'erp_cancel',
        value => $CANCEL_ROW,
        title => $CANCEL_ROW,
        src => '%PUBURLPATH%/%SYSTEMWEB%/EditRowPlugin/stop.gif',
    }, '');

    if ($this->{attrs}->{changerows}) {
        $buttons .= '<br />' if $multirow;
        if ($id) {
            if (!$topRow) {
                $buttons .= CGI::image_button({
                    name => 'erp_upRow',
                    value => $UP_ROW,
                    title => $UP_ROW,
                    src => '%PUBURLPATH%/%SYSTEMWEB%/EditRowPlugin/arrowup.gif'
                   }, '');
            }
            if (!$bottomRow) {
                $buttons .= CGI::image_button({
                    name => 'erp_downRow',
                    value => $DOWN_ROW,
                    title => $DOWN_ROW,
                    src => '%PUBURLPATH%/%SYSTEMWEB%/EditRowPlugin/arrowdown.gif'
                   }, '');
            }
        }
        $buttons .= CGI::image_button({
            name => 'erp_addRow',
            value => $ADD_ROW,
            title => $ADD_ROW,
            src => '%PUBURLPATH%/%SYSTEMWEB%/EditRowPlugin/plus.gif'
           }, '');

        $buttons .= CGI::image_button({
            name => 'erp_deleteRow',
            class => 'EditRowPluginDiscardAction',
            value => $DELETE_ROW,
            title => $DELETE_ROW,
            src => '%PUBURLPATH%/%SYSTEMWEB%/EditRowPlugin/minus.gif'
           }, '');
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

=pod

---++ parseTables($text, $topic, $web) -> \@list
Static function to extract a topic into a list of lines and embedded table definitions.
Each table definition is an object of type EditTable, and contains
a set of attrs (read from the %EDITTABLE) and a list of rows. You can spot the tables
in the list by doing:
newif (ref($line) eq 'Foswiki::Plugins::EditRowPlugin::Table') {

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

