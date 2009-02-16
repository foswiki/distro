
# See bottom of file for copyright
package Foswiki::Plugins::EditRowPlugin::TableRow;

use strict;
use Assert;

use Foswiki::Func;
use Foswiki::Plugins::EditRowPlugin::TableCell;

sub new {
    my ($class, $table, $number, $precruft, $postcruft, $cols) = @_;
    my $this = bless({}, $class);
    $this->{table} = $table;
    $this->{number} = $number;
    $this->{isHeader} = 0;
    $this->{isFooter} = 0;
    $this->{precruft} = $precruft;
    $this->{postcruft} = $postcruft;

    # pad out the cols to the width of the format
    my $ncols = scalar(@{$table->{colTypes}});
    while (scalar(@$cols) < $ncols) {
        push(@$cols, '');
    }
    $this->{cols} = [];
    $this->set($cols);
    return $this;
}

sub getID {
    my $this = shift;
    return $this->{table}->getID().'_'.$this->{number};
}

sub getAnchor {
    my $this = shift;
    return 'erp_'.$this->getID();
}

sub getEditAnchor {
    my $this = shift;
    return 'erp_edit_'.$this->getID();
}

# Find a row anchor within range of the row being edited that gives a
# reasonable amount of context (3 rows) above the edited row
sub getRowAnchor {
    my $this = shift;
    my $row_anchor = 1;
    if ($this->{number} > 3) {
        $row_anchor = $this->{number} - 1;
    }
    return 'erp_'.$this->{table}->getID().'_'.$row_anchor;
}

# break cycles to ensure we release back to garbage
sub finish {
    my $this = shift;
    $this->{table} = undef;
    foreach my $cell (@{$this->{cols}}) {
        $cell->finish();
    }
    undef($this->{cols});
}

# Set the columns in the row. Adapts to widen or narrow the row as required.
sub set {
    my ($this, $cols) = @_;
    while (scalar(@{$this->{cols}}) > scalar(@$cols)) {
        pop(@{$this->{cols}})->finish();
    }
    my $n = 0;
    foreach my $val (@$cols) {
        if ($n < scalar(@{$this->{cols}})) {
            # Restore the EDITCELL from the old value, if present
            my $old = $this->{cols}->[$n]->{text};
            if ($val !~ /%EDITCELL{.*?}%/
                  && $this->{cols}->[$n]->{text} =~ /(%EDITCELL{.*?}%)/) {
                $val .= $1;
            }
            $this->{cols}->[$n]->{text} = $val;
        } else {
            push(@{$this->{cols}},
                 new Foswiki::Plugins::EditRowPlugin::TableCell(
                     $this, $val, $n + 1));
        }
        $n++;
    }
}

sub stringify {
    my $this = shift;

    return '|'.join('|', map { $_->stringify() } @{$this->{cols}}).'|';
}

sub renderForEdit {
    my ($this, $colDefs, $showControls, $orient) = @_;

    my $id = $this->getID();
    my $anchor = CGI::a({ name => $this->getAnchor() }).' ';
    my @rows;
    my $empties = '|' x (scalar(@{$this->{cols}}) - 1);
    my $help = '';

    if ($orient eq 'vertical') {
        # Each column is presented as a row
        # Number of empty columns at end of each row
        my $hdrs = $this->{table}->getLabelRow();
        my $col = 0;
        foreach my $cell (@{$this->{cols}}) {
            # get the column label
            my $hdr = $hdrs->{cols}->[$col];
            $hdr = $hdr->{text} if $hdr;
            $hdr ||= '';
            my $text = $cell->renderForEdit($colDefs, $this->{isHeader});
            push(@rows, "| $hdr|$text$anchor|$empties");
            $anchor = '';
            $col++;
        }
        if ($showControls) {
            my $buttons = $this->{table}->generateEditButtons(
                $this->{number}, 0);
            push(@rows, "| $buttons ||$empties");
        }
    } else {
        # Generate the editors for each cell in the row
        my @cols = ();
        foreach my $cell (@{$this->{cols}}) {
            my $text = $cell->renderForEdit($colDefs, $this->{isHeader});
            push(@cols, $text);
        }

        my $help = '';
        if ($showControls) {
            my $buttons = $this->{table}->generateEditButtons(
                $this->{number}, 1);
            unshift(@cols, $buttons);
        }

        push(@rows, $this->{precruft}.$anchor.join('|', @cols).
               $this->{postcruft});
    }
    if ($showControls) {
        $help = $this->{table}->generateHelp();
        push(@rows, "| $help ||$empties") if $help;
    }
    return @rows;
}

sub renderForDisplay {
    my ($this, $colDefs, $withControls) = @_;
    my @out;
    my $id = $this->getID();
    my $addAnchor = $this->{table}->isEditable();
    my $anchor = '<a name="'.$this->getAnchor().'"></a>';

    foreach my $cell (@{$this->{cols}}) {
        # Add the row anchor for editing. It's added to the first non-empty
        # cell or, failing that, the first cell. This is to minimise the
        # risk of breaking up implied colspans.
        my $text = $cell->renderForDisplay($colDefs, $this->{isHeader});
        if ($addAnchor && $text =~ /\S/) {
            # If the cell has *'s, it is seen by TablePlugin as a header.
            # We have to respect that.
            if ($text =~ /^(\s*.*)(\*\s*)$/) {
                $text = $1.$anchor.$2;
            } else {
                $text .= $anchor;
            }
            $addAnchor = 0;
        }
        push(@out, $text);
    }

    if ($withControls) {
        my $active_topic = $this->{table}->getWeb().'.'
          .$this->{table}->getTopic();

        if ($this->{isHeader} || $this->{isFooter}) {
            # The ** fools TablePlugin into thinking this is a header.
            # Otherwise it disables sorting :-(
            my $text = '';
            if ($addAnchor) {
                $text .= $anchor;
                $addAnchor = 0;
            }
            unshift(@out, " *$text* ");
        } else {
            my $script = 'view';
            if (!Foswiki::Func::getContext()->{authenticated}) {
                $script = 'viewauth';
            }
            my $url = Foswiki::Func::getScriptUrl(
                $this->{table}->getWeb(),
                $this->{table}->getTopic(),
                $script,
                erp_active_topic => $active_topic,
                erp_active_table => $this->{table}->getID(),
                erp_active_row => $this->{number},
                '#' => $this->getRowAnchor());

            my $button =
              "<a href='$url' class='EditRowPluginDiscardAction'>" . CGI::img({
                  -name => $this->getEditAnchor(),
                  -border => 0,
                  -src => '%PUBURLPATH%/%SYSTEMWEB%/EditRowPlugin/edittopic.gif'
                 }) . "</a>";
            if ($addAnchor) {
                $button .= $anchor;
                $addAnchor = 0;
            }
            unshift(@out, $button);
        }
    }

    if ($addAnchor) {
        # All cells were empty; we have to shoehorn the anchor into the
        # final cell.
        my $cell = $this->{cols}->[-1];
        pop(@out);
        $cell->{text} .= $anchor;
        push(@out, $cell->renderForDisplay($colDefs, $this->{isHeader}));
    }
    my $row = $this->{precruft}.join('|', @out).$this->{postcruft};
    #$row =~ s/</&lt;/g; # DEBUG
    #$row =~ s/\*/STAR/g; #DEBUG
    #$row = '<br>'.$row; # DEBUG
    return $row;
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

This is an object that represents a single row in a table.

=pod

---++ new(\$table, $rno)
Constructor
   * \$table - pointer to the table
   * $rno - what row number this is (start at 1)

---++ finish()
Must be called to dispose of the object. This method disconnects internal pointers that would
otherwise make a Table and its rows and cells self-referential.

---++ stringify()
Generate a TML representation of the row

---++ renderForEdit() -> $text
Render the row for editing. Standard TML is used to construct the table.

---++ renderForDisplay() -> $text
Render the row for display. Standard TML is used to construct the table.

=cut
