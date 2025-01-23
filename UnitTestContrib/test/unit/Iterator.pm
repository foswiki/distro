# tests for the Foswiki Iterators

package Iterator;

use strict;
use warnings;

use FoswikiTestCase;
our @ISA = qw( FoswikiTestCase );

use Foswiki::ListIterator;
use Foswiki::AggregateIterator;
use Foswiki::Iterator::NumberRangeIterator;

use Error qw( :try );

sub new {
    my $class = shift;
    my $this  = $class->SUPER::new(@_);
    return $this;
}

#use the eg in the code.
sub test_ListIterator {
    my $this = shift;

    my @list = ( 1, 2, 3 );

    my $it = new Foswiki::ListIterator( \@list );
    $this->assert( $it->isa('Foswiki::Iterator') );
    $it->{filter}  = sub { return $_[0] != 2 };
    $it->{process} = sub { return $_[0] + 1 };
    my $b = '';
    while ( $it->hasNext() ) {
        my $x = $it->next();
        $b .= "$x, ";
    }

    $this->assert_str_equals( '2, 4, ', $b );
}

sub test_ListIteratorSimple {
    my $this = shift;

    my @list = ( 1, 2, 3 );

    my $it = new Foswiki::ListIterator( \@list );
    my $b  = '';
    while ( $it->hasNext() ) {
        my $x = $it->next();
        $b .= "$x, ";
    }

    $this->assert_str_equals( '1, 2, 3, ', $b );
}

sub test_ListIteratorWithUndef {
    my $this = shift;

    my @list = ( 1, 2, undef, 3 );

    my $it = new Foswiki::ListIterator( \@list );
    my $b  = '';
    while ( $it->hasNext() ) {
        my $x = $it->next();
        $b .= "$x, ";
    }

    $this->assert_str_equals( '1, 2, 3, ', $b );
}

sub test_ListIterator_nothing_hasNext {
    my $this = shift;

    my $it = new Foswiki::ListIterator();
    my $b  = '';
    while ( $it->hasNext() ) {
        my $x = $it->next();
        $b .= "$x, ";
    }

    $this->assert_str_equals( '', $b );
}

sub test_ListIterator_nothing_all {
    my $this = shift;

    my $it   = new Foswiki::ListIterator();
    my @list = $it->all;

    $this->assert_equals( 0, scalar(@list) );
}

sub test_ListIterator_nothing_skip {
    my $this = shift;

    my $it    = new Foswiki::ListIterator();
    my $count = $it->skip;

    $this->assert_equals( 0, $count );
}

sub test_AggregateIterator {
    my $this = shift;

    my @list1 = ( 1, 2, 3 );
    my $it1 = new Foswiki::ListIterator( \@list1 );
    $it1->{filter}  = sub { return $_[0] != 2 };
    $it1->{process} = sub { return $_[0] + 1 };

    my @list2 = ( 1, 2, 3 );
    my $it2 = new Foswiki::ListIterator( \@list2 );
    $it2->{filter}  = sub { return $_[0] != 2 };
    $it2->{process} = sub { return $_[0] + 1 };

    my @itrList = ( $it1, $it2 );
    my $it = new Foswiki::AggregateIterator( \@itrList );
    $this->assert( $it->isa('Foswiki::Iterator') );

    my $b = '';
    while ( $it->hasNext() ) {
        my $x = $it->next();
        $b .= "$x, ";
    }

    $this->assert_str_equals( '2, 4, 2, 4, ', $b );

    $it->reset();
    $this->assert_str_equals( '2, 4, 2, 4', join( ", ", $it->all() ) );
}

sub test_AggregateIteratorUnique {
    my $this = shift;

    my @list1 = ( 1, 2, 3 );
    my $it1 = new Foswiki::ListIterator( \@list1 );
    $it1->{filter}  = sub { return $_[0] != 2 };
    $it1->{process} = sub { return $_[0] + 1 };

    my @list2 = ( 1, 2, 3 );
    my $it2 = new Foswiki::ListIterator( \@list2 );
    $it2->{filter}  = sub { return $_[0] != 2 };
    $it2->{process} = sub { return $_[0] + 1 };

    my @itrList = ( $it1, $it2 );
    my $it = new Foswiki::AggregateIterator( \@itrList, 1 );

    my $b = '';
    while ( $it->hasNext() ) {
        my $x = $it->next();
        $b .= "$x, ";
    }

    $this->assert_str_equals( '2, 4, ', $b );
}

sub test_AggregateIteratorOwnFilter {
    my $this = shift;

    my @list1 = ( 1, 2, 3 );
    my $it1 = new Foswiki::ListIterator( \@list1 );

    my @list2 = ( 1, 2, 3 );
    my $it2 = new Foswiki::ListIterator( \@list2 );

    my @itrList = ( $it1, $it2 );
    my $it = new Foswiki::AggregateIterator( \@itrList );
    $it->{filter}  = sub { return $_[0] != 2 };
    $it->{process} = sub { return $_[0] + 1 };

    my $b = '';
    while ( $it->hasNext() ) {
        my $x = $it->next();
        $b .= "$x, ";
    }

    $this->assert_str_equals( '2, 4, 2, 4, ', $b );
}

sub test_AggregateIteratorOrder {
    my $this = shift;

    my @list1 = ( 1, 2, 3 );
    my $it1 = new Foswiki::ListIterator( \@list1 );

    my @list2 = qw/a b c d/;
    my $it2   = new Foswiki::ListIterator( \@list2 );

    my @itrList = ( $it1, $it2 );
    my $it = new Foswiki::AggregateIterator( \@itrList );

    my $b = '';
    while ( $it->hasNext() ) {
        my $x = $it->next();
        $b .= "$x, ";
    }

    $this->assert_str_equals( '1, 2, 3, a, b, c, d, ', $b );
}

sub test_AggregateIteratorBad {
    my $this = shift;

    my @list1 = ( 1, 2, 3 );
    my $it1 = new Foswiki::ListIterator( \@list1 );

    my @list2 = qw/a b c d/;
    my $it2   = new Foswiki::ListIterator( \@list2 );

    my $it3 = new Foswiki::ListIterator();

    my @itrList = ( $it1, $it2, $it3 );
    my $it = new Foswiki::AggregateIterator( \@itrList );

    my $b = '';
    while ( $it->hasNext() ) {
        my $x = $it->next();
        $b .= "$x, ";
    }

    $this->assert_str_equals( '1, 2, 3, a, b, c, d, ', $b );
}

sub test_AggregateIteratorNestedUnique {
    my $this = shift;

    my @list1 = ( 1, 2, 3 );
    my $it1 = new Foswiki::ListIterator( \@list1 );

    my @list2 = qw/a b c d/;
    my $it2   = new Foswiki::ListIterator( \@list2 );

    my @listA         = qw/p l k/;
    my $itA           = new Foswiki::ListIterator( \@listA );
    my @listB         = qw/y 2 b l/;
    my $itB           = new Foswiki::ListIterator( \@listB );
    my @NestedItrList = ( $itA, $itB );
    my $it3           = new Foswiki::AggregateIterator( \@NestedItrList, 1 );

    my @itrList = ( $it1, $it2, $it3 );
    my $it = new Foswiki::AggregateIterator( \@itrList, 1 );

    my $b = '';
    while ( $it->hasNext() ) {
        my $x = $it->next();
        $b .= "$x, ";
    }

    $this->assert_str_equals( '1, 2, 3, a, b, c, d, p, l, k, y, ', $b );
}

sub test_AggregateIteratorNestedUnique2 {
    my $this = shift;

    my @list1 = ( 1, 2, 3 );
    my $it1 = new Foswiki::ListIterator( \@list1 );

    my @list2 = qw/a b c d/;
    my $it2   = new Foswiki::ListIterator( \@list2 );

    my @listA         = qw/p l k/;
    my $itA           = new Foswiki::ListIterator( \@listA );
    my @listB         = qw/y 2 b l/;
    my $itB           = new Foswiki::ListIterator( \@listB );
    my @NestedItrList = ( $itA, $itB );
    my $it3           = new Foswiki::AggregateIterator( \@NestedItrList );

    my @itrList = ( $it1, $it2, $it3 );
    my $it = new Foswiki::AggregateIterator( \@itrList, 1 );

    my $b = '';
    while ( $it->hasNext() ) {
        my $x = $it->next();
        $b .= "$x, ";
    }

    $this->assert_str_equals( '1, 2, 3, a, b, c, d, p, l, k, y, ', $b );
}

sub test_AggregateIteratorNested {
    my $this = shift;

    my @list1 = ( 1, 2, 3 );
    my $it1 = new Foswiki::ListIterator( \@list1 );

    my @list2 = qw/a b c d/;
    my $it2   = new Foswiki::ListIterator( \@list2 );

    my @listA         = qw/p l k/;
    my $itA           = new Foswiki::ListIterator( \@listA );
    my @listB         = qw/y 2 b l/;
    my $itB           = new Foswiki::ListIterator( \@listB );
    my @NestedItrList = ( $itA, $itB );
    my $it3           = new Foswiki::AggregateIterator( \@NestedItrList );

    my @itrList = ( $it1, $it2, $it3 );
    my $it = new Foswiki::AggregateIterator( \@itrList );

    my $b = '';
    while ( $it->hasNext() ) {
        my $x = $it->next();
        $b .= "$x, ";
    }

    $this->assert_str_equals( '1, 2, 3, a, b, c, d, p, l, k, y, 2, b, l, ',
        $b );
}

sub test_NumberRangeIterator {
    my $this = shift;
    my $i = new Foswiki::Iterator::NumberRangeIterator( 0, 0, 1 );
    $this->assert( $i->hasNext() );
    $this->assert_num_equals( 0, $i->next() );
    $this->assert( !$i->hasNext() );
    $i = new Foswiki::Iterator::NumberRangeIterator( 0, 0, -1 );
    $this->assert( $i->hasNext() );
    $this->assert_num_equals( 0, $i->next() );
    $this->assert( !$i->hasNext() );
    $i = new Foswiki::Iterator::NumberRangeIterator( 0, 0 );
    $this->assert( $i->hasNext() );
    $this->assert_num_equals( 0, $i->next() );
    $this->assert( !$i->hasNext() );

    $i = new Foswiki::Iterator::NumberRangeIterator( 0, 1, 1 );
    $this->assert( $i->hasNext() );
    $this->assert_num_equals( 0, $i->next() );
    $this->assert( $i->hasNext() );
    $this->assert_num_equals( 1, $i->next() );
    $this->assert( !$i->hasNext() );

    $i = new Foswiki::Iterator::NumberRangeIterator( 0, 3, 2 );
    $this->assert( $i->hasNext() );
    $this->assert_num_equals( 0, $i->next() );
    $this->assert( $i->hasNext() );
    $this->assert_num_equals( 2, $i->next() );
    $this->assert( !$i->hasNext() );

    $i = new Foswiki::Iterator::NumberRangeIterator( 0, 4, 2 );
    $this->assert( $i->hasNext() );
    $this->assert_num_equals( 0, $i->next() );
    $this->assert( $i->hasNext() );
    $this->assert_num_equals( 2, $i->next() );
    $this->assert( $i->hasNext() );
    $this->assert_num_equals( 4, $i->next() );
    $this->assert( !$i->hasNext() );

    $i = new Foswiki::Iterator::NumberRangeIterator( 0, 1, -1 );
    $this->assert( $i->hasNext() );
    $this->assert_num_equals( 0, $i->next() );
    $this->assert( $i->hasNext() );
    $this->assert_num_equals( 1, $i->next() );
    $this->assert( !$i->hasNext() );

    $i = new Foswiki::Iterator::NumberRangeIterator( 0, -1, -1 );
    $this->assert( $i->hasNext() );
    $this->assert_num_equals( 0, $i->next() );
    $this->assert( $i->hasNext() );
    $this->assert_num_equals( -1, $i->next() );
    $this->assert( !$i->hasNext() );

    $i = new Foswiki::Iterator::NumberRangeIterator( 0, -1, 1 );
    $this->assert( $i->hasNext() );
    $this->assert_num_equals( 0, $i->next() );
    $this->assert( $i->hasNext() );
    $this->assert_num_equals( -1, $i->next() );
    $this->assert( !$i->hasNext() );

    $i = new Foswiki::Iterator::NumberRangeIterator( 0, -3, -2 );
    $this->assert( $i->hasNext() );
    $this->assert_num_equals( 0, $i->next() );
    $this->assert( $i->hasNext() );
    $this->assert_num_equals( -2, $i->next() );
    $this->assert( !$i->hasNext() );

    $i = new Foswiki::Iterator::NumberRangeIterator( 0, -4, 2 );
    $this->assert( $i->hasNext() );
    $this->assert_num_equals( 0, $i->next() );
    $this->assert( $i->hasNext() );
    $this->assert_num_equals( -2, $i->next() );
    $this->assert( $i->hasNext() );
    $this->assert_num_equals( -4, $i->next() );
    $this->assert( !$i->hasNext() );

    $i = new Foswiki::Iterator::NumberRangeIterator( -1, 1 );
    $this->assert( $i->hasNext() );
    $this->assert_num_equals( -1, $i->next() );
    $this->assert( $i->hasNext() );
    $this->assert_num_equals( 0, $i->next() );
    $this->assert( $i->hasNext() );
    $this->assert_num_equals( 1, $i->next() );
    $this->assert( !$i->hasNext() );

    $i = new Foswiki::Iterator::NumberRangeIterator( 1, -1 );
    $this->assert( $i->hasNext() );
    $this->assert_num_equals( 1, $i->next() );
    $this->assert( $i->hasNext() );
    $this->assert_num_equals( 0, $i->next() );
    $this->assert( $i->hasNext() );
    $this->assert_num_equals( -1, $i->next() );
    $this->assert( !$i->hasNext() );

    $i->reset();
    $this->assert( $i->hasNext() );
    $this->assert_num_equals( 1, $i->next() );
    $this->assert( $i->hasNext() );
    $this->assert_num_equals( 0, $i->next() );
    $this->assert( $i->hasNext() );
    $this->assert_num_equals( -1, $i->next() );
    $this->assert( !$i->hasNext() );
}

#0, '', -1 are valid elements
#SMELL: if an array element == undef it should _also_ be a valid element
sub test_ListIterator_falsies {
    my $this = shift;

    {
        my @list = ( -1, 0, '', 'asd' );

        my $it = new Foswiki::ListIterator( \@list );
        $this->assert( $it->isa('Foswiki::Iterator') );
        my $b = '';
        while ( $it->hasNext() ) {
            my $x = $it->next();
            $b .= "$x, ";
        }

        $this->assert_str_equals( '-1, 0, , asd, ', $b );
    }
    {
        my @list = ( '', '+&', '@:{}', '!!', '' );

        my $it = new Foswiki::ListIterator( \@list );
        $this->assert( $it->isa('Foswiki::Iterator') );
        my $b = '';
        while ( $it->hasNext() ) {
            my $x = $it->next();
            $b .= "$x, ";
        }

        $this->assert_str_equals( ', +&, @:{}, !!, , ', $b );
    }
}

1;
