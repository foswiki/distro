# See bottom of file for copyright and pod

=begin TML

---+ package Foswiki::Tables::Table

Abstract model of a table in a topic, suitable for use with the tables parser.

=cut

package Foswiki::Tables::Table;

use strict;
use Assert;

use Foswiki::Tables::Row ();

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

=begin TML

---++ new($tno, $row_class, $topicObject, $tno, $spec, $attrs)
Constructor
   * =$row_class= - perl class to be used as a factory for table rows (default Foswiki::Tables::Row)
   * =$tno= = table number (sequence in data, usually) (start at 1)
   * =$attrs= - Foswiki::Attrs of any controlling tag, if the parser found one.
   * =$topicObject= - the topic; optional, if undef will still work
The following entries in attrs are supported:
   * =format= - The format of the cells in a row of the table. The format is
     defined like a table row, where the cell data specify the type for each
     cell. For example, =format="| text,16 | label |"=. Cells can be any of
     the following types:
      * =text, &lt;size&gt;, &lt;initial value&gt;= Simple text field. Initial value is optional.
      * =textarea, &lt;rows&gt;x&lt;columns&gt;, &lt;initial value&gt;=
        Multirow text box. Initial value is optional.
      * =select, &lt;size&gt;, &lt;option 1&gt;, &lt;option 2&gt;, etc=
        Select one from a list of choices.
      * =radio, &lt;size&gt;, &lt;option 1&gt;, &lt;option 2&gt;,= etc.
        Radio buttons. =size= indicates the number of buttons per line in edit mode.
      * =checkbox, &lt;size&gt;, &lt;option 1&gt;, &lt;option 2&gt;, etc=
        Checkboxes. =size= indicates the number of buttons per line in edit mode.
      * =label, 0, &lt;label text&gt;= Fixed label.
      * =row= The row number, automatically worked out.
      * =date, &lt;size&gt;, &lt;initial value&gt;, &lt;DHTML date format&gt;=
        Date. Initial value and date format are both optional.
   * =headerrows= - integer number of rows in the thead
   * =footerrows= - integer number of rows in the tfoot

=cut

sub new {
    my ( $class, $spec, $attrs ) = @_;

    my $this = bless(
        {
            spec   => $spec,
            rows   => [],
            number => undef
        },
        $class
    );
    if ( $attrs->{format} ) {
        $this->{colTypes} = $this->parseFormat( $attrs->{format} );
    }
    else {
        $this->{colTypes} = [];
    }

    $this->{headerrows} = $attrs->{headerrows} || 0;
    $this->{footerrows} = $attrs->{footerrows} || 0;

    return $this;
}

=begin TML

---++ ClassMethod row_class() -> $classname
Perl class used for table rows (default Foswiki::Tables::Row)

=cut

sub row_class {
    return 'Foswiki::Tables::Row';
}

# Private - renumber the rows in the table after a row is moved
sub _renumber {
    my ( $this, $start ) = @_;
    $start ||= 0;
    for ( my $i = $start ; $i < scalar( @{ $this->{rows} } ) ; $i++ ) {
        $this->{rows}->[$i]->number($i);
    }
}

=begin TML

---++ ClassMethod getMacro() -> $macroname
The macro name for additional attributes for this table class e.g
'EDITTABLE'.

=cut

sub getMacro {
    return 'TABLE';
}

=begin TML

---++ ObjectMethod finish()
Clean up for disposal

=cut

sub finish {
    my $this = shift;
    foreach my $row ( @{ $this->{rows} } ) {
        $row->finish();
    }
    undef( $this->{rows} );
    undef( $this->{colTypes} );
}

=begin TML

---++ ObjectMethod number([$set]) -> $number

Setter/getter for the table number. The table number uniquely identifies
the table within the context of a topic. The table number is undef until
it is set by some external agency.

=cut

sub number {
    my ( $this, $number ) = @_;

    $this->{number} = $number if defined $number;
    return $this->{number};
}

=begin TML

---++ ObjectMethod stringify()
Generate a TML representation of the table

=cut

sub stringify {
    my $this = shift;

    my $s = '';
    if ( $this->{spec} ) {
        $s .= "$this->{spec}\n";
    }
    foreach my $row ( @{ $this->{rows} } ) {
        $s .= $row->stringify() . "\n";
    }
    return $s;
}

=begin TML

---++ ObjectMethod getHeaderRows() -> $integer
Get the number of header rows on the table.

=cut

sub getHeaderRows {
    my $this = shift;
    return $this->{headerrows} || 0;
}

=begin TML

---++ ObjectMethod getFooterRows() -> $integer
Get the number of footer rows on the table.

=cut

sub getFooterRows {
    my $this = shift;
    return $this->{footerrows} || 0;
}

=begin TML

---++ ObjectMethod getID() -> $id
Generate a unique string ID that uniquely identifies this table within a topic.

=cut

sub getID {
    my $this = shift;
    return $this->getMacro() . '_' . $this->number;
}

=begin TML

---++ ObjectMethod getFirstBodyRow() -> $integer
Get the 0-based row index of the first row after the header.

=cut

sub getFirstBodyRow {
    my $this = shift;

    return $this->{headerrows};
}

=begin TML

---++ ObjectMethod getLastBodyRow() -> $integer
Get the 0-based row index of the last row before the footer.

=cut

sub getLastBodyRow {
    my $this = shift;

    return $#{ $this->{rows} } - $this->{footerrows};
}

=begin TML

---++ ObjectMethod getCellData([$row [, $col]]) -> $data

Get cell, row, column or entire table, depending on params.
   * If =$row= and =$col= are given, return the scalar stored in that
     cell.
   * If only =$row= is given, then return an array of the data in each
     column.
   * If $row is undef bu $col is given, return an array of the data
     in that col.
   * If neither =$row= nor =$col= is given, return a 2D array of the
     cell data.

=cut

sub getCellData {
    my ( $this, $row, $col ) = @_;

    my $d;
    if ( defined $row ) {
        if ( defined $col ) {
            $d = $this->{rows}->[$row]->{cols}->[$col]->{text};
        }
        else {

            # This entire row
            $d = [];
            foreach my $col ( @{ $this->{rows}->[$row]->{cols} } ) {
                push( @$d, $col->{text} );
            }
        }
    }
    elsif ( defined $col ) {

        # This entire col
        $d = [];
        foreach my $row ( @{ $this->{rows} } ) {
            push( @$d, $row->{cols}->[$col]->{text} );
        }
    }
    else {

        # Entire table (row major)
        $d = [];
        foreach my $row ( @{ $this->{rows} } ) {
            my $c = [];
            foreach my $col ( @{ $row->{cols} } ) {
                push( @$c, $col->{text} );
            }
            push( @$d, $c );
        }
    }
    return $d;
}

sub getLabelRow() {
    my $this = shift;

    my $labelRow;
    foreach my $row ( @{ $this->{rows} } ) {
        if ( $row->isHeader() ) {
            $labelRow = $row;
        }
        else {

            # the last header row is always taken as the label row
            last;
        }
    }
    return $labelRow;
}

=begin TML

---++ ObjectMethod addRow($row) -> $rowObject
Construct and add a row _after_ the given row
    * =$row= - 0-based index of the row to add _after_
If $row is < 0, then adds the row to the end of the *live* rows
(i.e. rows *before* the footer).

To add a row to the end of the table (after the footer), use =pushRow=.

=cut

sub addRow {
    my ( $this, $row ) = @_;
    my @cols;

    if ( $row < 0 ) {

        # row < 0 == add to end of live rows
        $row = $this->getLastBodyRow();
    }

    my @vals = map { $_->{initial_value} } @{ $this->{colTypes} };

    # widen up to the width of the first (hopefully header) row
    my $count;
    if ( scalar( @{ $this->{rows} } ) ) {
        my $count = scalar( @{ $this->{rows}->[0]->{cols} } );
        while ( scalar(@vals) < $count ) {
            push( @vals, '' );
        }
    }
    my $newRow = $this->row_class->new( $this, '', '', \@vals );
    splice( @{ $this->{rows} }, $row, 0, $newRow );

    $this->_renumber($row);

    return $newRow;
}

=begin TML

---++ ObjectMethod pushRow($rowObject) -> $index
Add a row to the end of the table.

=cut

sub pushRow {
    my ( $this, $row ) = @_;

    $row->number( push( @{ $this->{rows} }, $row ) - 1 );
    return $row->number;
}

=begin TML

---++ deleteRow($row)
Delete the given row
    * =$row= - 0-based index of the row to delete

=cut

sub deleteRow {
    my ( $this, $row ) = @_;

    if ( $row < $this->getFirstBodyRow() ) {
        $row = $this->getLastBodyRow();
    }
    return 0 unless $row >= $this->getFirstBodyRow();
    my @dead = splice( @{ $this->{rows} }, $row - 1, 1 );
    map { $_->finish() } @dead;
    $this->_renumber($row);
    return 1;
}

=begin TML

---++ ObjectMethod moveRow($from, $to)
Move a row
   * =$from= 0-based index of the row to move
   * =$to= 0-based index of the target position (before =$from= is removed!)

=cut

sub moveRow {
    my ( $this, $from, $to ) = @_;

    return if $to == $from;

    my @moving = splice( @{ $this->{rows} }, $from, 1 );

    # compensate for row just removed
    my $rto = ( $to > $from ) ? $to - 1 : $to;

    if ( $rto >= scalar( @{ $this->{rows} } ) ) {
        push( @{ $this->{rows} }, @moving );
    }
    else {
        splice( @{ $this->{rows} }, $rto, 0, @moving );
    }
    $this->_renumber();
}

=begin TML

---++ ObjectMethod upRow($row)
Move a row up one position in the table
   * =$row= 0-based index of the row to move

=cut

sub upRow {
    my ( $this, $row ) = @_;
    my $tmp = $this->{rows}->[$row];
    $this->{rows}->[$row] = $this->{rows}->[ $row - 1 ];
    $this->{rows}->[ $row - 1 ] = $tmp;
    $this->_renumber( $row - 1 );
}

=begin TML

---++ ObjectMethod downRow($row)
Move a row down one position in the table
   * =$row= 0-based index of the row to move

=cut

sub downRow {
    my ( $this, $row ) = @_;
    my $tmp = $this->{rows}->[$row];
    $this->{rows}->[$row] = $this->{rows}->[ $row + 1 ];
    $this->{rows}->[ $row + 1 ] = $tmp;
    $this->_renumber($row);
}

# PROTECTED method that parses a column type specification
sub parseFormat {
    my ( $this, $format ) = @_;
    my @cols;

    $format =~ s/^\s*\|//;
    $format =~ s/\|\s*$//;

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
        elsif ( $type eq 'date' ) {
            $initial = shift @values;
        }
        $initial = '' unless defined $initial;

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

1;
__END__

Author: Crawford Currie http://c-dot.co.uk

Copyright (C) 2009-2012 Foswiki Contributors
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


