# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Iterator

This class cannot be instantiated on its own - it is an interface
specification for iterators. See http://en.wikipedia.org/wiki/Iterator_Pattern
for more information on the iterator pattern.

The interface only supports forward iteration. Subclasses should use this
as their base class (so that =$it->isa("Foswiki::Iterator")= returns true),
and must implement =hasNext= and =next= per the specification below.

See Foswiki::ListIterator for an example implementation.

=cut

package Foswiki::Iterator;

use strict;
use warnings;
use Assert;

#debug Iterators
use constant MONITOR => 0;

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

=begin TML

---++ hasNext() -> $boolean

Returns true if the iterator has more items, or false when the iterator
is exhausted.

=cut

sub hasNext { ASSERT('Pure virtual function called') if DEBUG; }

=begin TML

---++ next() -> $data

Return the next data in the iteration.

The data may be any type.

The iterator object can be customised to pre- and post-process entries from
the list before returning them. This is done by setting two fields in the
iterator object:

   * ={filter}= can be defined to be a sub that filters each entry. The entry
     will be ignored (next() will not return it) if the filter returns false.
   * ={process}= can be defined to be a sub to process each entry before it
     is returned by next. The value returned from next is the value returned
     by the process function.

=cut

sub next { ASSERT('Pure virtual function called') if DEBUG; }

=begin TML

---++ reset() -> $boolean

resets the iterator to the begining - returns false if it can't

=cut

sub reset { ASSERT('Pure virtual function called') if DEBUG; }

=begin TML

---++ ObjectMethod all() -> @list

Exhaust the iterator. Return all remaining elements in the iteration
as a list. The returned list should be considered to be immutable.

The default implementation simply runs the iterator to its end.

=cut

sub all {
    my ($this) = @_;
    my @remains;
    while ( $this->hasNext() ) {
        push( @remains, $this->next() );
    }
    return @remains;
}

1;
__END__
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
