# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Search::ResultSet

This class implements the ResultSet API - its basically a Sorted Aggregate Iterator for foswiki 1.1
   * NOTE: does not implement the unique function - by its nature, the data is unique, and it would be a non-trivial drain on memory in this context

(due to the partially completed InfoCache removeal)

in future it will probably become more clever.

=cut

package Foswiki::Search::ResultSet;
use strict;

use Foswiki::Iterator ();
our @ISA = ('Foswiki::Iterator');

use Foswiki::Search::InfoCache;

=begin TML

---++ new(\@list)

Create a new iterator over the given list of iterators. The list is
not damaged in any way.

=cut

sub new {
    my ( $class, $list ) = @_;
    my $this = bless(
        {
            Itr_list    => $list,
            Itr_index   => 0,
            index       => 0,
            process     => undef,
            filter      => undef,
            next        => undef,
        },
        $class
    );
    return $this;
}

=begin TML

---++ hasNext() -> $boolean

Returns false when the iterator is exhausted.

=cut

sub hasNext {
    my ($this) = @_;
    return 1 if $this->{next};
    my $n;
    do {
        unless ( $this->{list} ) {
            if ( $this->{Itr_index} < scalar( @{ $this->{Itr_list} } ) ) {
                $this->{list} = $this->{Itr_list}->[ $this->{Itr_index}++ ];
            }
            else {
                return 0;    #no more iterators in list
            }
        }
        if ( $this->{list}->hasNext() ) {
            $n = $this->{list}->next();
        }
        else {
            $this->{list} = undef;    #goto next iterator
        }
      } while ( !$this->{list}
        || ( $this->{filter} && !&{ $this->{filter} }($n) )
         );
    $this->{next} = $n;
    return 1;
}

=begin TML

---++ next() -> $data

Return the next entry in the list.

The iterator object can be customised to pre- and post-process entries from
the list before returning them. This is done by setting two fields in the
iterator object:

   * ={filter}= can be defined to be a sub that filters each entry. The entry
     will be ignored (next() will not return it) if the filter returns false.
   * ={process}= can be defined to be a sub to process each entry before it
     is returned by next. The value returned from next is the value returned
     by the process function.

=cut

sub next {
    my $this = shift;
    $this->hasNext();
    my $n = $this->{next};
    $this->{next} = undef;
    $n = &{ $this->{process} }($n) if $this->{process};

    return $n;
}

=begin TML
---++ sortResults

the implementation of %SORT{"" limit="" order="" reverse="" date=""}%

it should be possible for the search engine to pre-sort, making this a nop, or to
delay evaluated, partially evaluated, or even delegated to the DB/SQL 

=cut

sub sortResults {
    my ( $this, $params ) = @_;

    foreach my $infocache (@{ $this->{Itr_list} }) {
        $infocache->sortResults($params);
    }
}

1;
__DATA__
# Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008-2010 Foswiki Contributors. All Rights Reserved.
# Foswiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
#
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.
#
# author: Sven Dowideit