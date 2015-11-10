# See bottom of file for copyright and license information
package Foswiki::Tables::Cell;

=begin TML

---+ package Foswiki::Tables::Cell

Abstract model of a table cell, suitable for use with the tables parser.

=cut

use strict;
use Assert;

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

# Default format if no other format is defined for a cell
my $defCol ||= { type => 'text', size => 20, values => [] };

=begin TML

---++ ClassMethod new($row, $precruft, $text, $postcruft, $isHeader) -> $cell
Construct a new table cell.
   * =$row= - the row the cell belongs to (Foswiki::Tables::Row or subclass)
   * =$precruft= - whatever precedes the text inside the cell (spaces)
   * =$text= - the text stored in the cell
   * =$postcruft= - whatever follows the text inside the cell (spaces)
   * =$isHeader= - true if this is a header cell (content delimited by **)

Note that =$postcruft= and =$precruft= should *not* include the * indicating
a header.

=cut

sub new {
    my ( $class, $row, $precruft, $text, $postcruft, $ish ) = @_;
    my $this = bless( {}, $class );
    ASSERT( $row->isa('Foswiki::Tables::Row'), $row ) if DEBUG;
    $this->{row}       = $row;
    $this->{number}    = undef;        # index of the column in the *raw* table
    $this->{precruft}  = $precruft;
    $this->{postcruft} = $postcruft;
    $this->{isHeader}  = $ish;
    $this->{text}      = $text;

    return $this;
}

=begin TML

---++ ObjectMethod number([$set]) -> $number

Setter/getter for the cell number. The number uniquely identifies the cell
within the context of a row. The cell number is undef until it is set by
some external agency (e.g. the row)

=cut

sub number {
    my ( $this, $number ) = @_;

    $this->{number} = $number if defined $number;
    return $this->{number};
}

=begin TML

---++ ObjectMethod finish()
Clean up for disposal

=cut

sub finish {
    my $this = shift;
    $this->{row} = undef;
}

=begin TML

---++ ObjectMethod stringify()
Generate a TML representation of the row

=cut

sub stringify {
    my $this = shift;

    # Jeff Crawford, Item5043:
    # replace linefeeds with breaks to support multiline textareas
    my $text = $this->{text};
    return '' unless defined $text;
    $text =~ s# *[\r\n]+ *# <br \/> #g;

    # Remove tactical spaces
    $text =~ s/^\s+(.*)\s*$/$1/s;
    my $h = $this->{isHeader} ? '*' : '';
    return "$this->{precruft}$h$text$h$this->{postcruft}";
}

=begin TML

---++ ObjectMethod getID() -> $id
Generate a unique string ID that uniquely identifies this cell within a topic.

=cut

sub getID {
    my $this = shift;
    return $this->{row}->getID() . '_'
      . ( defined $this->{number} ? $this->{number} : '' );
}

1;
__END__

Author: Crawford Currie http://c-dot.co.uk

Copyright (c) 2009-2014 Foswiki Contributors
Portions Copyright (C) 2007 WindRiver Inc. and TWiki Contributors.
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


