# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Search::ResultSet

This class implements the ResultSet API - its basically a Sorted Aggregate Iterator for foswiki 1.1
   * NOTE: does not implement the unique function - by its nature, the data is unique, and it would be a non-trivial drain on memory in this context

(due to the partially completed InfoCache removeal)

in future it will probably become more clever.

=cut

package Foswiki::Search::ResultSet;
use v5.14;

use Foswiki::Search::InfoCache;
use Assert;

use Moo;
use namespace::clean;
extends qw(Foswiki::Object);
with qw(Foswiki::Iterator);

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

has Itr_list => (
    is       => 'rw',
    required => 1,
    init_arg => 'iterators',
);
has Itr_index => (
    is      => 'rw',
    default => 0,
);
has Itr_next => ( is => 'rw', default => sub { [] }, );
has partition => (
    is     => 'ro',
    coerce => sub { $_[0] // 'web' },
);
has sortby => (
    is     => 'ro',
    coerce => sub { $_[0] // 'topic' },
);
has revsort => (
    is     => 'ro',
    coerce => sub { $_[0] // 0 },
);
has count => ( is => 'rw', );
has _iterator => (
    is        => 'rw',
    lazy      => 1,
    clearer   => 1,
    predicate => 1,
    isa       => Foswiki::Object::isaCLASS(
        'list', 'Foswiki::Object', does => 'Foswiki::Iterator',
    ),
);

=begin TML

---++ new( iterators => \@list, [partition => $groupby, sortby => $order, revsort => $revSort])

Create a new iterator over the given list of iterators. The list is
not damaged in any way.

=cut

#    new( $list, $partition, $sortby, $revSort ) = @_;

sub BUILD {
    my $this = shift;
    ASSERT( $this->partition, "partition attr cannot be empty" );
}

sub numberOfTopics {
    my $this = shift;

    return $this->count if ( defined( $this->count ) );

    my $count = 0;
    foreach my $infocache ( @{ $this->Itr_list } ) {
        $count += $infocache->numberOfTopics();
    }
    $this->count($count);

    return $count;
}

=begin TML

---++ hasNext() -> $boolean

Returns false when the iterator is exhausted.

=cut

sub hasNext {
    my ($this) = @_;
    return 1 if $this->_next;

#this is the 'normal' legacy way to iterate over the list of results (one web at a time)
    if (
        ( $this->partition eq 'web' )
        or (
            scalar( @{ $this->Itr_list } ) <= 0
        ) #no reason to got through the more complex case if there's only one itr
      )
    {
        my $n;
        do {
            unless ( $this->_iterator ) {
                if ( $this->Itr_index < scalar( @{ $this->Itr_list } ) ) {
                    $this->_iterator( $this->Itr_list->[ $this->Itr_index ] );
                    $this->Itr_index( $this->Itr_index + 1 );
                }
                else {
                    return 0;    #no more iterators in list
                }
            }
            if ( $this->_iterator->hasNext() ) {
                $n = $this->_iterator->next();
            }
            else {
                $this->_clear_iterator;    #goto next iterator
            }
        } while ( !$this->_iterator );
        $this->_next($n);
    }
    else {

#yes, this is innefficient, for now I'm looking only to get a functioning result.
        my $next = -1;
        for ( my $idx = 0 ; $idx < scalar( @{ $this->Itr_list } ) ; $idx++ ) {

            #load the next element from each of the iterators
            if ( !defined( $this->Itr_next->[$idx] )
                and $this->Itr_list->[$idx]->hasNext() )
            {
                $this->Itr_next->[$idx] = $this->Itr_list->[$idx]->next();
            }
            if ( defined( $this->Itr_next->[$idx] ) ) {

    #find the first one of them (works because each iterator is already sorted..
                if ( $next == -1 ) {
                    $next = $idx;
                    next;
                }

             #print STDERR "------ trying ($idx) ".$this->Itr_next->[$idx]."\n";
             #compare $next's elem with $idx's and rotate if needed
                my @two = ( $this->Itr_next->[$next], $this->Itr_next->[$idx] );
                Foswiki::Search::InfoCache::sortTopics( \@two, $this->sortby,
                    !$this->revsort );
                if ( $two[0] ne $this->Itr_next->[$next] ) {
                    $next = $idx;
                }
            }
        }

        #print STDERR "---getting result from $next\n";
        if ( $next == -1 ) {
            return 0;
        }
        else {
            $this->_next( $this->Itr_next->[$next] );
            $this->Itr_next->[$next] = undef;
        }

    }
    return 1;
}

=begin TML

---++ skip(count) -> $countremaining

skip X elements (returns 0 if successful, or number of elements remaining to skip if there are not enough elements to skip)
skip must set up next as though hasNext was called.

=cut

sub skip {
    my $this  = shift;
    my $count = shift;

    return 0 if ( $count <= 0 );
    print STDERR
      "--------------------------------------------ResultSet::skip($count)\n"
      if Foswiki::Iterator::MONITOR;

    #ask CAN skip() for faster path
    if (
        (
               ( $this->partition eq 'web' )
            or ( scalar( @{ $this->Itr_list } ) == 0 )
        )
        and #no reason to got through the more complex case if there's only one itr
        ( $this->Itr_list->[0]->can('skip')
        ) #nasty assumption that all the itr's are a similar type (that happens to be true)
      )
    {
        if ( not defined( $this->_iterator ) ) {
            $this->_iterator( $this->Itr_list->[ $this->Itr_index++ ] );
        }
        while ( $count > 0 ) {
            return $count if ( not defined( $this->_iterator ) );
            $count = $this->_iterator->skip($count);
            $this->_next( $this->_iterator->_next );
            if ( $count > 0 ) {
                $this->_iterator = $this->Itr_list->[ $this->Itr_index ];
                $this->Itr_index( $this->Itr_index + 1 );
                $this->_clear_next;
            }
        }
    }
    else {

        #brute force -
        while (
            ( $count > 0
            ) #must come first - don't want to advance the inner itr if count ==0
            and $this->hasNext()
          )
        {
            $count--;
            $this->next();    #drain next, so hasNext goes to next element
        }
    }

    if ( $count >= 0 ) {

        #skipped past the end of the set
        $this->_clear_next;
    }
    print STDERR
"--------------------------------------------ResultSet::skip() => $count\n"
      if Foswiki::Iterator::MONITOR;
    return $count;
}

=begin TML

---++ next() -> $data

Return the next entry in the list.

=cut

sub next {
    my $this = shift;
    $this->hasNext();
    my $n = $this->_next;
    $this->_clear_next;

    return $n;
}

sub reset {

    # Stub method for role compliance
}

=begin TML

---++ nextWeb() -> $data

switch tot he next Web (only works on partition==web, and if we've already started iterating.
=cut

sub nextWeb {
    my $this = shift;

    ASSERT( $this->partition eq 'web' ) if DEBUG;
    ASSERT( $this->_iterator ) if DEBUG;

    $this->_clear_iterator;
    $this->hasNext();
}

=begin TML
---++ sortResults

the implementation of %SORT{"" limit="" order="" reverse="" date=""}%

it should be possible for the search engine to pre-sort, making this a nop, or to
delay evaluated, partially evaluated, or even delegated to the DB/SQL 

=cut

sub sortResults {
    my ( $this, $params ) = @_;

    foreach my $infocache ( @{ $this->Itr_list } ) {
        $infocache->sortResults($params);
    }
}

sub filterByDate {
    my ( $this, $date ) = @_;

    foreach my $infocache ( @{ $this->Itr_list } ) {
        $infocache->filterByDate($date);
    }
}

1;
__END__
Author: Sven Dowideit - http://fosiki.com

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
