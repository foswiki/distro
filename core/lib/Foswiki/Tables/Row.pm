# See bottom of file for copyright and license information
package Foswiki::Tables::Row;

=begin TML

---+ package Foswiki::Tables::Row

Abstract model of a table row, suitable for use with the tables parser.

=cut

use strict;
use Assert;

use Foswiki::Func ();

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

=begin TML

---++ ClassMethod new($table, $precruft, $postcruft [, \@cols]) -> $row
Construct a new table row, associated with the given table.
   * =$table= - the table the row is associated with
   * =$precruft= - text found before the opening | at the start of the row
   * =$postcruft= - text found after the closing | at the end of the row
   * =$cols= - optional array ref of values used to populate the row.

Note that =$postcruft= and =$precruft= should *not* include the |.

=cut

sub new {
    my ( $class, $table, $precruft, $postcruft, $cols ) = @_;
    my $this = bless( {}, $class );

    $this->{table} = $table;
    ASSERT( $table->isa('Foswiki::Tables::Table'), $table ) if DEBUG;
    $this->{number} = undef;    # 0-based index of the row in the *raw* table
        # isHeader and isFooter are calculated based on the headerrows
        # and footerrow options, if set, when the table is constructed. If they
        # are not set, the number of rows that qualify as "header rows" is used
        # to guess the header rows. A row qualifies as a header row if all cells
        # in the row are marked as header cells.
    $this->{isHeader}  = undef;
    $this->{isFooter}  = undef;
    $this->{precruft}  = defined $precruft ? $precruft : '';
    $this->{postcruft} = defined $postcruft ? $postcruft : '';

    # pad out the cols to the width of the format
    my $ncols = scalar( @{ $table->{colTypes} } );
    while ( defined $cols && scalar(@$cols) < $ncols ) {
        push( @$cols, '' );
    }
    $this->{cols} = [];
    $this->setRow($cols) if $cols;
    return $this;
}

=begin TML

---++ ClassMethod cell_class() -> $classname
Perl class used for table cells (default Foswiki::Tables::Cell)

=cut

sub cell_class {
    require Foswiki::Tables::Cell;
    ASSERT( !$@, $@ ) if DEBUG;
    return 'Foswiki::Tables::Cell';
}

# PACKAGE PRIVATE ObjectMethod pushCell($cellObject) -> $index
# Add a cell to the end of the row.
sub pushCell {
    my ( $this, $cell ) = @_;

    $cell->number( push( @{ $this->{cols} }, $cell ) - 1 );
    ASSERT( defined $cell->{number} );
    return $cell->number;
}

=begin TML

---++ ObjectMethod getID() -> $id
Generate a unique string ID that uniquely identifies this row within a topic.

=cut

sub getID {
    my $this = shift;
    return $this->{table}->getID() . '_'
      . ( defined $this->{number} ? $this->{number} : '' );
}

=begin TML

---++ ObjectMethod isHeader() -> $boolean
Determine if this row meets the criteria for a header row (or set it as a header row)

=cut

sub isHeader {
    my ( $this, $set ) = @_;
    if ( defined $set ) {
        $this->{isHeader} = $set;
    }
    elsif ( !defined $this->{isHeader} ) {
        $this->{isHeader} = 0;
        foreach my $cell ( @{ $this->{cols} } ) {
            if ( $cell->{isHeader} ) {
                $this->{isHeader} = 1;
            }
            else {
                $this->{isHeader} = 0;
                last;
            }
        }
    }
    return $this->{isHeader} || 0;
}

=begin TML

---++ ObjectMethod isFooter([$boolean]) -> $boolean
Determine if this row meets the criteria for a footer row (or set it as a footer row)

=cut

sub isFooter {
    my ( $this, $set ) = @_;
    if ($set) {
        $this->{isFooter} = $set;
    }
    return $this->{isFooter} || 0;
}

=begin TML

---++ ObjectMethod finish()
Clean up for disposal

=cut

sub finish {
    my $this = shift;
    undef $this->{table};
    foreach my $cell ( @{ $this->{cols} } ) {
        $cell->finish();
    }
    undef( $this->{cols} );
    undef $this->{precruft};
    undef $this->{postcruft};
}

=begin TML

---++ ObjectMethod number([$set]) -> $number

Setter/getter for the row number. The row number uniquely identifies the row
within the context of a table. The row number is undef until it is set by
some external agency (e.g. the table)

=cut

sub number {
    my ( $this, $number ) = @_;

    $this->{number} = $number if defined $number;
    return $this->{number};
}

=begin

---++ ObjectMethod setRow(\@colData)
Set the columns in an existing row. Adapts to widen or narrow the row as required.
Handles restoration of %EDITCELL if it was there previously but has been removed.
Intended for setting row data after an edit.
   * =\@colData= - array of data for the columns in this row

=cut

sub setRow {
    my ( $this, $cols ) = @_;

    while ( scalar( @{ $this->{cols} } ) > scalar(@$cols) ) {
        pop( @{ $this->{cols} } )->finish();
    }
    my $n = 0;
    foreach my $val (@$cols) {
        if ( $n < scalar( @{ $this->{cols} } ) ) {

            # Restore the EDITCELL from the old value, if present
            if (   $val !~ /%EDITCELL\{.*?\}%/
                && $this->{cols}->[$n]->{text} =~ m/(%EDITCELL\{.*?\}%)/ )
            {
                $val .= $1;
            }
            $this->{cols}->[$n]->{text} = $val;
        }
        else {
            if ( !ref($val) ) {
                require Foswiki::Tables::Parser;
                my @cell = Foswiki::Tables::Parser::split_cell($val);
                $val = \@cell;
            }
            my $c = $this->cell_class->new( $this, @$val );
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
    my $cols = join( '|', map { $_->stringify() } @{ $this->{cols} } );
    return "$this->{precruft}|$cols|$this->{postcruft}";
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
