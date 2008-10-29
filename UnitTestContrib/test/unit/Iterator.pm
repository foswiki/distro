use strict;

# tests for the TWiki Iterators

package Iterator;

use base qw( TWikiTestCase );

use TWiki::ListIterator;
use TWiki::AggregateIterator;
use Error qw( :try );

sub new {
    my $class = shift;
    my $this = $class->SUPER::new(@_);
    return $this;
}

#use the eg in the code.
sub test_ListIterator {
    my $this = shift;

	my @list = ( 1, 2, 3 );
	
	my $it = new TWiki::ListIterator(\@list);
	$it->{filter} = sub { return $_[0] != 2 };
	$it->{process} = sub { return $_[0] + 1 };
	my $b = '';
	while ($it->hasNext()) {
		my $x = $it->next();
		$b .= "$x, ";
	}

    $this->assert_str_equals('2, 4, ',$b);
}

sub test_ListIteratorSimple {
    my $this = shift;

	my @list = ( 1, 2, 3 );
	
	my $it = new TWiki::ListIterator(\@list);
	my $b = '';
	while ($it->hasNext()) {
		my $x = $it->next();
		$b .= "$x, ";
	}

    $this->assert_str_equals('1, 2, 3, ',$b);
}

sub test_ListIteratorWithUndef {
    my $this = shift;

	my @list = ( 1, 2, undef, 3 );
	
	my $it = new TWiki::ListIterator(\@list);
	my $b = '';
	while ($it->hasNext()) {
		my $x = $it->next();
		$b .= "$x, ";
	}

    $this->assert_str_equals('1, 2, 3, ',$b);
}

sub test_ListIterator_nothing {
    my $this = shift;

	my $it = new TWiki::ListIterator();
	my $b = '';
	while ($it->hasNext()) {
		my $x = $it->next();
		$b .= "$x, ";
	}

    $this->assert_str_equals('',$b);
}

sub test_AggregateIterator {
    my $this = shift;

	my @list1 = ( 1, 2, 3 );
	my $it1 = new TWiki::ListIterator(\@list1);
	$it1->{filter} = sub { return $_[0] != 2 };
	$it1->{process} = sub { return $_[0] + 1 };

	my @list2 = ( 1, 2, 3 );
	my $it2 = new TWiki::ListIterator(\@list2);
	$it2->{filter} = sub { return $_[0] != 2 };
	$it2->{process} = sub { return $_[0] + 1 };

	my @itrList = ($it1, $it2);
	my $it = new TWiki::AggregateIterator(\@itrList);

	my $b = '';
	while ($it->hasNext()) {
		my $x = $it->next();
		$b .= "$x, ";
	}

    $this->assert_str_equals('2, 4, 2, 4, ',$b);
}

sub test_AggregateIteratorUnique {
    my $this = shift;

	my @list1 = ( 1, 2, 3 );
	my $it1 = new TWiki::ListIterator(\@list1);
	$it1->{filter} = sub { return $_[0] != 2 };
	$it1->{process} = sub { return $_[0] + 1 };

	my @list2 = ( 1, 2, 3 );
	my $it2 = new TWiki::ListIterator(\@list2);
	$it2->{filter} = sub { return $_[0] != 2 };
	$it2->{process} = sub { return $_[0] + 1 };

	my @itrList = ($it1, $it2);
	my $it = new TWiki::AggregateIterator(\@itrList, 1 );

	my $b = '';
	while ($it->hasNext()) {
		my $x = $it->next();
		$b .= "$x, ";
	}

    $this->assert_str_equals('2, 4, ',$b);
}

sub test_AggregateIteratorOwnFilter {
    my $this = shift;

	my @list1 = ( 1, 2, 3 );
	my $it1 = new TWiki::ListIterator(\@list1);

	my @list2 = ( 1, 2, 3 );
	my $it2 = new TWiki::ListIterator(\@list2);

	my @itrList = ($it1, $it2);
	my $it = new TWiki::AggregateIterator(\@itrList);
	$it->{filter} = sub { return $_[0] != 2 };
	$it->{process} = sub { return $_[0] + 1 };

	my $b = '';
	while ($it->hasNext()) {
		my $x = $it->next();
		$b .= "$x, ";
	}

    $this->assert_str_equals('2, 4, 2, 4, ',$b);
}

sub test_AggregateIteratorOrder {
    my $this = shift;

	my @list1 = ( 1, 2, 3 );
	my $it1 = new TWiki::ListIterator(\@list1);

	my @list2 = qw/a b c d/;
	my $it2 = new TWiki::ListIterator(\@list2);

	my @itrList = ($it1, $it2);
	my $it = new TWiki::AggregateIterator(\@itrList);

	my $b = '';
	while ($it->hasNext()) {
		my $x = $it->next();
		$b .= "$x, ";
	}

    $this->assert_str_equals('1, 2, 3, a, b, c, d, ',$b);
}

sub test_AggregateIteratorBad {
    my $this = shift;

	my @list1 = ( 1, 2, 3 );
	my $it1 = new TWiki::ListIterator(\@list1);

	my @list2 = qw/a b c d/;
	my $it2 = new TWiki::ListIterator(\@list2);
	
	my $it3 = new TWiki::ListIterator();

	my @itrList = ($it1, $it2, $it3);
	my $it = new TWiki::AggregateIterator(\@itrList);

	my $b = '';
	while ($it->hasNext()) {
		my $x = $it->next();
		$b .= "$x, ";
	}

    $this->assert_str_equals('1, 2, 3, a, b, c, d, ',$b);
}

sub test_AggregateIteratorNestedUnique {
    my $this = shift;

	my @list1 = ( 1, 2, 3 );
	my $it1 = new TWiki::ListIterator(\@list1);

	my @list2 = qw/a b c d/;
	my $it2 = new TWiki::ListIterator(\@list2);
	
	my @listA = qw/p l k/;
	my $itA = new TWiki::ListIterator(\@listA);
	my @listB = qw/y 2 b l/;
	my $itB = new TWiki::ListIterator(\@listB);	
	my @NestedItrList = ($itA , $itB);
	my $it3 = new TWiki::AggregateIterator(\@NestedItrList, 1);

	my @itrList = ($it1, $it2, $it3);
	my $it = new TWiki::AggregateIterator(\@itrList, 1);

	my $b = '';
	while ($it->hasNext()) {
		my $x = $it->next();
		$b .= "$x, ";
	}

    $this->assert_str_equals('1, 2, 3, a, b, c, d, p, l, k, y, ' ,$b);
}

sub test_AggregateIteratorNestedUnique2 {
    my $this = shift;

	my @list1 = ( 1, 2, 3 );
	my $it1 = new TWiki::ListIterator(\@list1);

	my @list2 = qw/a b c d/;
	my $it2 = new TWiki::ListIterator(\@list2);
	
	my @listA = qw/p l k/;
	my $itA = new TWiki::ListIterator(\@listA);
	my @listB = qw/y 2 b l/;
	my $itB = new TWiki::ListIterator(\@listB);	
	my @NestedItrList = ($itA , $itB);
	my $it3 = new TWiki::AggregateIterator(\@NestedItrList);

	my @itrList = ($it1, $it2, $it3);
	my $it = new TWiki::AggregateIterator(\@itrList, 1);

	my $b = '';
	while ($it->hasNext()) {
		my $x = $it->next();
		$b .= "$x, ";
	}

    $this->assert_str_equals('1, 2, 3, a, b, c, d, p, l, k, y, ' ,$b);
}

sub test_AggregateIteratorNested {
    my $this = shift;

	my @list1 = ( 1, 2, 3 );
	my $it1 = new TWiki::ListIterator(\@list1);

	my @list2 = qw/a b c d/;
	my $it2 = new TWiki::ListIterator(\@list2);
	
	my @listA = qw/p l k/;
	my $itA = new TWiki::ListIterator(\@listA);
	my @listB = qw/y 2 b l/;
	my $itB = new TWiki::ListIterator(\@listB);	
	my @NestedItrList = ($itA , $itB);
	my $it3 = new TWiki::AggregateIterator(\@NestedItrList);

	my @itrList = ($it1, $it2, $it3);
	my $it = new TWiki::AggregateIterator(\@itrList);

	my $b = '';
	while ($it->hasNext()) {
		my $x = $it->next();
		$b .= "$x, ";
	}

    $this->assert_str_equals('1, 2, 3, a, b, c, d, p, l, k, y, 2, b, l, ' ,$b);
}

1;
