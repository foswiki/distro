# See bottom of file for copyright and license information
package Foswiki::Tables::Row;
use v5.14;

=begin TML

---+ package Foswiki::Tables::Row

Abstract model of a table row, suitable for use with the tables parser.

=cut

use Assert;
use Foswiki::Func           ();
use Foswiki::Tables::Parser ();

use Foswiki::Class;
extends qw(Foswiki::Object);

has table => (
    is       => 'rw',
    weak_ref => 1,
    isa      => Foswiki::Object::isaCLASS(
        'table', 'Foswiki::Tables::Table', noUndef => 1
    ),
    required => 1,
);
has _isHeader => ( is => 'rw', );
has isFooter  => ( is => 'rw', );
has precruft  => ( is => 'rw', default => '', required => 1, );
has postcruft => ( is => 'rw', default => '', required => 1, );
has cols      => ( is => 'rw', lazy => 1, default => sub { [] }, );

# 0-based index of the row in the *raw* table isHeader and isFooter are
# calculated based on the headerrows and footerrow options, if set, when the
# table is constructed. If they are not set, the number of rows that qualify as
# "header rows" is used to guess the header rows. A row qualifies as a header
# row if all cells in the row are marked as header cells.
has number => ( is => 'rw', );

=begin TML

---++ ClassMethod new(table => $table, precruft => $precruft, postcruft => $postcruft [, columns => \@cols]) -> $row
Construct a new table row, associated with the given table.
   * =$table= - the table the row is associated with
   * =$precruft= - text found before the opening | at the start of the row
   * =$postcruft= - text found after the closing | at the end of the row
   * =$cols= - optional array ref of values used to populate the row.

Note that =$postcruft= and =$precruft= should *not* include the |.

=cut

sub BUILD {
    my $this = shift;
    my ($params) = @_;

    # pad out the cols to the width of the format
    my $ncols = scalar( @{ $this->table->colTypes } );
    while ( defined $params->{columns}
        && scalar( @{ $params->{columns} } ) < $ncols )
    {
        push( @{ $params->{columns} }, '  ' );
    }
    $this->setRow( $params->{columns} ) if $params->{columns};
}

=begin TML

---++ ClassMethod cell_class() -> $classname
Perl class used for table cells (default Foswiki::Tables::Cell)

=cut

sub cell_class {
    Foswiki::load_package('Foswiki::Tables::Cell');
    ASSERT( !$@, $@ ) if DEBUG;
    return 'Foswiki::Tables::Cell';
}

# PACKAGE PRIVATE ObjectMethod pushCell($cellObject) -> $index
# Add a cell to the end of the row.
sub pushCell {
    my ( $this, $cell ) = @_;

    $cell->number( push( @{ $this->cols }, $cell ) - 1 );
    ASSERT( defined $cell->number );
    return $cell->number;
}

=begin TML

---++ ObjectMethod getID() -> $id
Generate a unique string ID that uniquely identifies this row within a topic.

=cut

sub getID {
    my $this = shift;
    return $this->table->getID() . '_'
      . ( defined $this->number ? $this->number : '' );
}

=begin TML

---++ ObjectMethod isHeader() -> $boolean
Determine if this row meets the criteria for a header row (or set it as a header row)

=cut

sub isHeader {
    my ( $this, $set ) = @_;
    if ( defined $set ) {
        $this->_isHeader($set);
    }
    elsif ( !defined $this->_isHeader ) {
        $this->_isHeader(0);
        foreach my $cell ( @{ $this->cols } ) {
            if ( $cell->isHeader ) {
                $this->_isHeader(1);
            }
            else {
                $this->_isHeader(0);
                last;
            }
        }
    }
    return $this->_isHeader || 0;
}

=begin TML

---++ ObjectAttribute isFooter([$boolean]) -> $boolean
Determine if this row meets the criteria for a footer row (or set it as a footer row)

=cut

=begin TML

---++ ObjectAttribute number([$set]) -> $number

Setter/getter for the row number. The row number uniquely identifies the row
within the context of a table. The row number is undef until it is set by
some external agency (e.g. the table)

=cut

=begin

---++ ObjectMethod setRow(\@colData)
Set the columns in an existing row. Adapts to widen or narrow the row as required.
Handles restoration of %EDITCELL if it was there previously but has been removed.
Intended for setting row data after an edit.
   * =\@colData= - array of data for the columns in this row

=cut

sub setRow {
    my ( $this, $cols ) = @_;

    while ( scalar( @{ $this->cols } ) > scalar(@$cols) ) {
        pop( @{ $this->cols } );
    }
    my $n = 0;
    foreach my $val (@$cols) {
        if ( $n < scalar( @{ $this->cols } ) ) {

            # Restore the EDITCELL from the old value, if present
            if (   $val !~ /%EDITCELL\{.*?\}%/
                && $this->cols->[$n]->text =~ m/(%EDITCELL\{.*?\}%)/ )
            {
                $val .= $1;
            }
            $this->cols->[$n]->text($val);
        }
        else {
            if ( !ref($val) ) {
                Foswiki::load_package('Foswiki::Tables::Parser');
                my @cell = Foswiki::Tables::Parser::split_cell($val);
                $val = \@cell;
            }
            my $c = $this->cell_class->new( row => $this, @$val );
            $this->pushCell($c);
        }
        $n++;
    }
}

=begin TML

---++ ObjectMethod stringify()
Generate a TML representation of the row

=cut

sub stringify {
    my $this = shift;
    my $cols = join( '|', map { $_->stringify() } @{ $this->cols } );
    return $this->precruft . "|$cols|" . $this->postcruft;
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
