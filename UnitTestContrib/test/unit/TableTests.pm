# Tests for the Table, Row and Cell classes of Foswiki::Tables
package TableTests;

use strict;
use FoswikiTestCase;
use Foswiki::Attrs;
use Foswiki::Tables::Table;

our @ISA = qw( FoswikiTestCase );

my $spec =
'headerrows="2" footerrows="1" format="|text,5,init |label,20,$dollar()init|textarea,10x8|radio,,a,b,c|"';

sub test_construct_table {
    my $this = shift;

    my $attrs = Foswiki::Attrs->new($spec);
    my $table = Foswiki::Tables::Table->new( 'SPEC', $attrs );
    $this->assert_num_equals( 0, $table->totalRows() );
    $this->assert_num_equals( 2, $table->{headerrows} );
    $this->assert_num_equals( 2, $table->getHeaderRows() );
    $this->assert_num_equals( 1, $table->getFooterRows() );

    $this->assert_equals( 'text',  $table->{colTypes}->[0]->{type} );
    $this->assert_equals( '5',     $table->{colTypes}->[0]->{size} );
    $this->assert_equals( 'init ', $table->{colTypes}->[0]->{initial_value} );

    $this->assert_equals( 'label', $table->{colTypes}->[1]->{type} );
    $this->assert_equals( '20',    $table->{colTypes}->[1]->{size} );
    $this->assert_equals( '$init', $table->{colTypes}->[1]->{initial_value} );

    $this->assert_equals( 'textarea', $table->{colTypes}->[2]->{type} );
    $this->assert_equals( '10x8',     $table->{colTypes}->[2]->{size} );
    $this->assert_equals( '', $table->{colTypes}->[2]->{initial_value} );

    $this->assert_equals( 'radio', $table->{colTypes}->[3]->{type} );
    $this->assert_equals( '1',     $table->{colTypes}->[3]->{size} );
    $this->assert_equals( 'a',     $table->{colTypes}->[3]->{values}->[0] );
    $this->assert_equals( 'b',     $table->{colTypes}->[3]->{values}->[1] );
    $this->assert_equals( 'c',     $table->{colTypes}->[3]->{values}->[2] );
    $this->assert_equals( 'a',     $table->{colTypes}->[3]->{initial_value} );

    $this->assert_num_equals( 4, scalar( @{ $table->{colTypes} } ) );
    $this->assert_equals( "SPEC\n", $table->stringify() );

    $table->makeConsistent();
    $this->assert_num_equals( 3, $table->totalRows() );

    $attrs = Foswiki::Attrs->new('');
    $table = Foswiki::Tables::Table->new( 'SPEC', $attrs );
    $this->assert_null( $table->{headerrows} );
    $this->assert_num_equals( 0, $table->getHeaderRows() );
    $this->assert_null( $table->{footerrows} );
    $this->assert_num_equals( 0, $table->getFooterRows() );
    $this->assert_num_equals( 0, $table->getFirstBodyRow() );
    $this->assert_num_equals( 0, $table->getLastBodyRow() );
}

# Chedck column 0 for expected row
sub _check_rows {
    my ( $this, $table, @data ) = @_;

    $this->assert_num_equals( scalar(@data), $table->totalRows() );
    my $i = 0;
    while ( my $d = shift @data ) {
        $this->assert_equals(
            $d,
            $table->{rows}->[ $i++ ]->{cols}->[0]->{text},
            "$d in "
              . join( ',',
                map { $_->{cols}->[0]->{text} || 'undef' } @{ $table->{rows} } )
        );
    }
}

# tests on an empty table with no spec
sub test_basic_table_operations {
    my $this  = shift;
    my $attrs = Foswiki::Attrs->new('');
    my $table = Foswiki::Tables::Table->new( 'SPEC', $attrs );
    $this->assert( !$table->deleteRow(0) );
    my $row = $table->addRow(1);
    $this->assert_num_equals( 1, $table->totalRows() );
    $this->assert_num_equals( 0, $row->number() );
    $this->assert( !$table->deleteRow(1) );
    $this->assert( $table->deleteRow(0) );

    $this->assert_num_equals( 0, $table->totalRows() );
    $this->assert( $row = $table->addRow(1) );
    $row->{cols}->[0]->{text} = "first";
    $this->_check_rows( $table, "first" );

    $this->assert( $row = $table->addRow(0) );    # should add after row 0
    $row->{cols}->[0]->{text} = "second";
    $this->_check_rows( $table, "first", "second" );

    $this->assert( $row = $table->addRow(-1) );    # should add at the start
    $row->{cols}->[0]->{text} = "third";
    $this->_check_rows( $table, "third", "first", "second" );

    $this->assert( $row = $table->addRow(100) );    # should add at the end
    $row->{cols}->[0]->{text} = "fourth";
    $this->_check_rows( $table, "third", "first", "second", "fourth" );

    # Clean up a touch
    $this->assert( $table->deleteRow(2) );
    $this->_check_rows( $table, "third", "first", "fourth" );

    $this->assert( $row = $table->addRow(1) );      # should add in the middle
    $row->{cols}->[0]->{text} = "fifth";
    $this->_check_rows( $table, "third", "first", "fifth", "fourth" );

    # impose a header row and try a low-end add again
    $table->{headerrows} = 1;
    $this->assert( $row = $table->addRow(-1) );     # should add after row 0
    $row->{cols}->[0]->{text} = "sixth";
    $this->_check_rows( $table, "third", "sixth", "first", "fifth", "fourth" );
    $this->assert( !$table->deleteRow(0) );
    $this->assert( $table->deleteRow(1) );

    # impose a footer row and try a high-end add again
    $table->{footerrows} = 2;
    $this->assert( $row = $table->addRow(-1) );     # should add after row 0
    $row->{cols}->[0]->{text} = "seventh";
    $this->_check_rows( $table, "third", "seventh", "first", "fifth",
        "fourth" );
    $this->assert( !$table->deleteRow(4) );
    $this->assert( !$table->deleteRow(3) );
    $this->assert( $table->deleteRow(2) );

    $this->assert( !$table->moveRow( 0, 1 ) );
    $this->assert( !$table->moveRow( 3, 4 ) );

    # Muddy-boots a row move
    $this->assert( $table->moveRow( 2, 0, 1 ) );
    $this->_check_rows( $table, "fifth", "third", "seventh", "fourth" );

    # Muddy-boots a delete
    $this->assert( $table->deleteRow( 0, 1 ) );
    $this->_check_rows( $table, "third", "seventh", "fourth" );

    # This muddy-boots delete will make the table inconsistent
    $this->assert( $table->deleteRow( 2, 1 ) );
    $this->_check_rows( $table, "third", "seventh" );
    $table->makeConsistent();    # should add the missing footer row
    $this->_check_rows( $table, "third", "seventh", undef );
    $this->assert( $table->deleteRow( 2, 1 ) );
    $this->_check_rows( $table, "third", "seventh" );

    # Muddy-boots addRow
    $this->assert( $row = $table->addRow( 100, undef, 1 ) ); # should add at end
    $row->{cols}->[0]->{text} = "eighth";
    $this->_check_rows( $table, "third", "seventh", "eighth" );

    $this->assert( $table->downRow( 0, 1 ) );
    $this->_check_rows( $table, "seventh", "third", "eighth" );

    $this->assert( $table->upRow( 2, 1 ) );
    $this->_check_rows( $table, "seventh", "eighth", "third" );

    $this->assert( !$table->downRow(0) );
    $this->assert( !$table->upRow(2) );
    $this->_check_rows( $table, "seventh", "eighth", "third" );
}

1;
