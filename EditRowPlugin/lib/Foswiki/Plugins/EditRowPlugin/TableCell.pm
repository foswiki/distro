# See bottom of file for copyright and license information
package Foswiki::Plugins::EditRowPlugin::TableCell;

use strict;
use Assert;

use Foswiki::Func;
use JSON;
# Default editor, used if another editor can't be loaded
use Foswiki::Plugins::EditRowPlugin::Editor;

# Default format if no other format is defined for a cell
my $defCol ||= { type => 'text', size => 20, values => [] };

# Map of type name to editor object. This is dynamically populated on demand with
# editor instances.
our %editors = ( _default => Foswiki::Plugins::EditRowPlugin::Editor->new() );

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
    
    my $editor = $editors{$colDef->{type}};
    unless ($editor) {
	my $class = "Foswiki::Plugins::EditRowPlugin::Editor::$colDef->{type}";
	eval("require $class");
	ASSERT(!$@, $@) if DEBUG;
	if ($@) {
	    Foswiki::Func::writeWarning(
		"EditRowPlugin could not load cell type $class: $@" );
	    $editor = $editors{_default};
	} else {
	    $editor = $class->new();
	}
	$editors{$colDef->{type}} = $editor;
    }

    if ($opts->{for_edit} && !$opts->{require_js}) {
	$text = $editor->htmlEditor($this, $colDef, $opts->{in_row}, defined $text ? $text : '');
	$text = Foswiki::Plugins::EditRowPlugin::defend($text);
    } else {
	$text = '-' unless defined($text);

	unless ( $this->{isHeader} || $this->{isFooter} ) {
	    if ( $colDef->{type} eq 'row' ) {
		$text = $this->rowIndex($colDef);
	    }
	    else {
		$text =~ s/%EDITCELL{(.*?)}%\s*$//;
	    }
	}
	if ( $this->{isHeader} ) {
	    $text = CGI::span(
		{
		    # head and foot sizes passed in metadata
		    class   => 'editRowPluginSort {headrows: '.
			$this->{row}->{table}->getHeaderRows()
			. ',footrows:'
			. $this->{row}->{table}->getFooterRows() . '}',
		},
		$text);
	} else {
	    my $sopts = {};
	    if ($this->can_edit()) {
		my $data = $editor->jQueryMetadata($this, $colDef, $text);
		my $saveURL = $this->getSaveURL();
		# Carve off the URL params and push to meta-data; they are wanted
		# for ajax.
		if ($saveURL =~ s/\?(.*)$//) {
		    $data->{erp_data} = {};
		    for my $tup (split(/[;&]/, $1)) {
			$tup =~ /(.*?)=(.*)$/;
			$data->{erp_data}->{$1} = $2;
		    }
		}
		$data->{url} = $saveURL;
		$sopts->{class} = 'editRowPluginCell '
		    . Foswiki::Plugins::EditRowPlugin::defend(JSON::to_json($data), 1);
	    }
	    $text = CGI::span( $sopts, " $text ");
	}
    }
    return $this->{precruft} . $text . $this->{postcruft};
}

sub can_edit {
    my $this = shift;
    return $this->{row}->can_edit();
}

sub getSaveURL {
    my ($this, %more) = @_;
    return $this->{row}->getSaveURL(
	noredirect => 1,
	erp_active_col => $this->{number}, %more);
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
