# See bottom of file for copyright
package Foswiki::Plugins::EditRowPlugin::TableCell;

use strict;
use Assert;

use Foswiki::Func;

# Default format if no other format is defined for a cell
my $defCol ||= { type => 'text', size => 20, values => [] };

sub new {
    my ($class, $row, $text, $number) = @_;
    my $this = bless({}, $class);
    $this->{row} = $row;
    $this->{number} = $number;
    if ($text =~ /\S/) {
        $text =~ s/^(\s*)//;
        $this->{precruft} = $1 || '';
        $text =~ s/(\s*)$//;
        $this->{postcruft} = $1 || '';
    } else {
        # Cell just has spaces. Item5596.
        $text = '';
        $this->{precruft} = ' ';
        $this->{postcruft} = ' ';
    }
    if ($text =~ s/^\*(.*)\*$/$1/) {
        $this->{precruft} .= '*';
        $this->{postcruft} = '*'.$this->{postcruft};
        $this->{isHeader} = 1;
    }
    $this->{text} = $text;
    return $this;
}

sub finish {
    my $this = shift;
    $this->{row} = undef;
}

sub stringify {
    my $this = shift;

    # Jeff Crawford, Item5043:
    # replace linefeeds with breaks to support multiline textareas
    my $text = $this->{text};
    $text =~ s#[\r\n]+#<br \/>#g;

    return $this->{precruft}.$text.$this->{postcruft};
}

# Row index offset by size in the columnn definition
sub rowIndex {
    my ($this, $colDef) = @_;
    if ($this->{row}->{index}) {
        my $i = $this->{row}->{index} || 0;
        $i += $colDef->{size} - 1 if ($colDef->{size} =~ /^\d+$/);
        $this->{text} = $i;
    } else {
        $this->{text} = '';
    }
}

sub getCellName {
    my $this = shift;
    return 'erp_cell_'.$this->{row}->{table}->getID().'_'.
      $this->{row}->{number}.'_'.$this->{number};
}

sub renderForDisplay {
    my ($this, $colDefs, $isHeader) = @_;
    my $colDef = $colDefs->[$this->{number} - 1] || $defCol;
    my $text = $this->{text};
    $text = '-' unless defined($text);

    if (!$this->{isHeader} && !$this->{isFooter}) {
        if ($colDef->{type} eq 'row') {
            $text = $this->rowIndex( $colDef );
        } else {
            $text =~ s/%EDITCELL{(.*?)}%\s*$//;
        }
    }
    if ($this->{isHeader}) {
        $text = CGI::span(
            {
                class => 'erpSort',
                onclick => 'javascript: return sortTable(this, false, '.
                  $this->{row}->{table}->getHeaderRows().','.
                    $this->{row}->{table}->getFooterRows().')',
            }, $text);
    }
    return $this->{precruft}.$text.$this->{postcruft};
}

sub renderForEdit {
    my ($this, $colDefs, $isHeader) = @_;
    my $colDef = $colDefs->[$this->{number} - 1] || $defCol;
    my $unexpandedValue = $this->{text} || '';

    if ($unexpandedValue =~ s/%EDITCELL{(.*?)}%\s*$//) {
        my $cd = $this->{row}->{table}->parseFormat($1);
        $colDef = $cd->[0];
    }

    my $expandedValue = Foswiki::Func::expandCommonVariables($unexpandedValue);
    $expandedValue =~ s/^\s*(.*?)\s*$/$1/;

    my $text = '';
    my $cellName = $this->getCellName();

    if( $colDef->{type} eq 'select' ) {

        # Explicit HTML used because CGI gets it wrong
        $text = "<select name='$cellName' size='".$colDef->{size}.
          "' class='EditRowPluginInput'>";
        foreach my $option ( @{$colDef->{values}} ) {
            my $expandedOption =
              Foswiki::Func::expandCommonVariables($option);
            $expandedOption =~ s/^\s*(.*?)\s*$/$1/;
            my %opts;
            if ($expandedOption eq $expandedValue) {
                $opts{selected} = 'selected';
            }
            $text .= CGI::option(\%opts, $option);
        }
        $text .= "</select>";

    } elsif ($colDef->{type} =~ /^(checkbox|radio)/) {

        my %attrs;
        my @defaults;
        my @options;
        $expandedValue = ",$expandedValue,";

        my $i = 0;
        foreach my $option (@{$colDef->{values}}) {
            push(@options, $option);
            my $expandedOption =
              Foswiki::Func::expandCommonVariables($option);
            $expandedOption =~ s/^\s*(.*?)\s*$/$1/;
            $expandedOption =~ s/(\W)/\\$1/g;
            $attrs{$option}{label} = $expandedOption;
            if ($colDef->{type} eq 'checkbox') {
                $attrs{$option}{class} = 'foswikiCheckBox EditRowPluginInput';
            } else {
                $attrs{$option}{class} =
                  'foswikiRadioButton EditRowPluginInput';
            }

            if ($expandedValue =~ /,\s*$expandedOption\s*,/) {
                $attrs{$option}{checked} = 'checked';
                push( @defaults, $option );
            }
        }
        if ($colDef->{type} eq 'checkbox') {
            $text = CGI::checkbox_group(
                -name => $cellName,
                -values => \@options,
                -defaults => \@defaults,
                -columns => $colDef->{size},
                -attributes => \%attrs );

        } else {
            $text = CGI::radio_group(
                -name => $cellName,
                -values => \@options,
                -default => $defaults[0],
                -columns => $colDef->{size},
                -attributes => \%attrs );
        }

    } elsif( $colDef->{type} eq 'row' ) {

        $text = $isHeader ? '' : $this->rowIndex($colDef);

    } elsif( $colDef->{type} eq 'textarea' ) {

        my ($rows, $cols) = split( /x/i, $colDef->{size} );
        $rows =~ s/[^\d]//;
        $cols =~ s/[^\d]//;
        $rows = 3 if $rows < 1;
        $cols = 30 if $cols < 1;

        # Jeff Crawford, Item5043:
        # replace BRs to display multiple lines nicely
        my $tmptext = $unexpandedValue;
        $tmptext =~ s#<br( /)?>#\r\n#gi;
        $tmptext =~ s/%BR%/\r\n/gi;

        $text = CGI::textarea({
            class => 'EditRowPluginInput',
            rows => $rows,
            columns => $cols,
            name => $cellName,
            value => $tmptext});

    } elsif( $colDef->{type} eq 'date' ) {

        eval 'require Foswiki::Contrib::JSCalendarContrib';

        if ($@) {
            # Calendars not available
            $text = CGI::textfield({ name => $cellName, size => 10,
                                     class => 'EditRowPluginInput'});
        } else {
            # NOTE: old versions of JSCalendarContrib won't fire onchange
            $text = Foswiki::Contrib::JSCalendarContrib::renderDateForEdit(
                $cellName, $unexpandedValue, $colDef->{values}->[1],
                { class => 'EditRowPluginInput' });
        }

    } elsif( $colDef->{type} eq 'label' ) {

        # Labels are not editable.
        $text = $unexpandedValue;

    } else { #  if( $colDef->{type} =~ /^text.*$/)

        $text = CGI::textfield({
            class => 'EditRowPluginInput',
            name => $cellName,
            size => $colDef->{size},
            value => $unexpandedValue });

    }
    return $this->{precruft}.Foswiki::Plugins::EditRowPlugin::defend($text)
      .$this->{postcruft};
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

This is an object that represents a single cell in a table.

=pod

---++ new(\$row, $cno)
Constructor
   * \$row - pointer to the row
   * $cno - what cell number this is (start at 1)

---++ finish()
Must be called to dispose of the object. This method disconnects internal pointers that would
otherwise make a Table and its rows and cells self-referential.

---++ stringify()
Generate a TML representation of the cell

---++ renderForEdit() -> $text
Render the cell for editing. Standard TML is used to construct the table.

---++ renderForDisplay() -> $text
Render the cell for display. Standard TML is used to construct the table.

=cut
