# See bottom of file for copyright and license information
package Foswiki::Plugins::EditRowPlugin::TableCell;

use strict;
use Assert;

use Foswiki::Func ();
use JSON ();
use Foswiki::Plugins::EditRowPlugin::Editor ();

# Default format if no other format is defined for a cell
my $defCol ||= { type => 'text', size => 20, values => [] };

sub new {
    my ( $class, $row, $text, $number ) = @_;
    my $this = bless( {}, $class );
    $this->{row}    = $row;
    $this->{number} = $number; # index of the column in the *raw* table
    if ( $text =~ /\S/ ) {
        $text =~ s/^(\s*)//;
        $this->{precruft} = defined $1 ? $1 : '';
        $text =~ s/(\s*)$//;
        $this->{postcruft} = defined $1 ? $1 : '';
    }
    else {

        # Cell just has spaces. Item5596.
        $text              = '';
        $this->{precruft}  = ' ';
        $this->{postcruft} = ' ';
    }
    if ( $text =~ s/^\*(.*)\*$/$1/ ) {
        $this->{precruft} .= '*';
        $this->{postcruft} = '*' . $this->{postcruft};
        $this->{isHeader}  = 1;
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
    $text =~ s# *[\r\n]+ *# <br \/> #g;
    # Remove tactical spaces
    $text =~ s/^\s+(.*)\s*$/$1/s;
    return $this->{precruft} . $text . $this->{postcruft};
}

# Row index offset by size in the columnn definition
sub rowIndex {
    my ( $this, $colDef ) = @_;
    if ( $this->{row}->{index} ) {
        my $i = $this->{row}->{index} || 0;
        $i += $colDef->{size} - 1 if ( $colDef->{size} =~ /^\d+$/ );
        $this->{text} = $i;
    }
    else {
        $this->{text} = '';
    }
}

sub getCellName {
    my $this = shift;
    return
        'erp_cell_'
      . $this->{row}->{table}->getID() . '_'
      . $this->{row}->{number} . '_'
      . $this->{number};
}

sub render {
    my ( $this, $opts ) = @_;

    my $colDef = $opts->{col_defs}->[ $this->{number} - 1 ] || $defCol;
    my $text = $this->{text};
    if ( $text =~ s/%EDITCELL{(.*?)}%// ) {
	my %p = Foswiki::Func::extractParameters($1);
	my $cd = $this->{row}->{table}->parseFormat($p{_DEFAULT});
	$colDef = $cd->[0];
    }
    
    my $editor = Foswiki::Plugins::EditRowPlugin::Table::getEditor($colDef);

    if ($opts->{for_edit} && $opts->{js} ne 'assumed') {
	# JS is ignored or preferred, need manual edit controls
	$text = $editor->htmlEditor($this, $colDef, $opts->{in_row}, defined $text ? $text : '');
	$text = Foswiki::Plugins::EditRowPlugin::defend($text);
    } else {
	# Not for edit or JS is assumed
	$text = '-' unless defined($text);

	unless ( $this->{isHeader} || $this->{isFooter} ) {
	    if ( $colDef->{type} eq 'row' ) {
		# Special case for our "row" type - text is always the row number
		$text = $this->rowIndex($colDef);
	    }
	    else {
		# Chop out meta-text
		$text =~ s/%EDITCELL{(.*?)}%\s*$//;
	    }
	}
	if ( $this->{isHeader} ) {
	    my $attrs = {};
	    unless ($opts->{js} eq 'ignored') {
		# head and foot sizes passed in metadata
		$attrs->{class} =
		    'erpJS_sort {headrows: '
		    . $this->{row}->{table}->getHeaderRows()
		    . ',footrows:'
		    . $this->{row}->{table}->getFooterRows() . '}';
	    }
	    $text = CGI::span($attrs, $text);
	} else {
	    my $sopts = {};
	    my $trigger = '';
	    if ($this->can_edit()) {
		my $data = $editor->jQueryMetadata($this, $colDef, $text);
		# Editors can set "uneditable" if the cell is not to have an editor
		unless ($data->{uneditable}) {
		    #if ($opts->{js} ne 'ignored') {
		    # add any edit-specific HTML here
		    #}
		    my @css_classes = ('erpJS_cell');
		    # Because we generate a TML table, we have no way to attach table meta-data
		    # and row meta-data. So we attach it to the first cell in the table/row, and
		    # move it to the right place when JS loads.
		    if ($opts->{first_col}) {
			$data->{trdata} = $this->{row}->getURLParams();
			push( @css_classes, 'erpJS_trdata' );
			if ($opts->{first_row}) {
			    my $tabledata = $this->{row}->{table}->getURLParams();
			    $data->{tabledata} = $tabledata;
			    push( @css_classes, 'erpJS_tabledata' );
			}
		    }
		    # Add the cell data
		    $data = $this->getURLParams(%$data);
		    # Note: Any table row that has a cell with erpJS_cell will be made draggable
		    if ($opts->{js} ne 'ignored') {
			$sopts->{class} = join(' ', @css_classes) . ' ' . JSON::to_json($data);
		    }
		}
	    }
	    #my $a = {};
	    #$a->{class} = 'erpJS_container' unless $opts->{js} eq 'ignored';
	    #$text = CGI::div($a, CGI::span( $sopts, " $text "));
	    $text = CGI::span( $sopts, " $text ");
	}
    }
    return $this->{precruft} . $text . $this->{postcruft};
}

sub can_edit {
    my $this = shift;
    return $this->{row}->can_edit();
}

sub getURLParams {
    my ($this, %more) = @_;
    return {
	%more,
	noredirect => 1,
	erp_active_col => $this->{number} };
}

1;
__END__

Author: Crawford Currie http://c-dot.co.uk

Copyright (c) 2009-2011 Foswiki Contributors
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

=cut
