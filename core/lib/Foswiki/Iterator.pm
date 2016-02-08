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
use v5.14;

use Assert;

use Moo::Role;

#debug Iterators
use constant MONITOR => 0;

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

has list => (
    is        => 'rw',
    lazy      => 1,
    clearer   => 1,
    predicate => 1,
    default   => sub { [] },
    isa       => Foswiki::Object::isaARRAY('list'),
);
has index => (
    is      => 'rw',
    lazy    => 1,
    clearer => 1,
    default => 0,
);
has process => ( is => 'rw', clearer => 1, );
has filter  => ( is => 'rw', clearer => 1, );
has _next   => ( is => 'rw', clearer => 1, );

requires qw(hasNext next reset);

=begin TML

---++ hasNext() -> $boolean

Returns true if the iterator has more items, or false when the iterator
is exhausted.

=cut

=begin TML

---++ reset() -> $boolean

resets the iterator to the begining - returns false if it can't

=cut

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
