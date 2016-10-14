# See bottom of file for license and copyright information

=begin

---+ package Foswiki::Iterator::ProcessIterator

Iterator that filters another iterator by calling an external process on each
element in the iteration.

=cut

package Foswiki::Iterator::ProcessIterator;
use v5.14;

use Assert;

use Foswiki::Class;
extends qw(Foswiki::Object);
with qw(Foswiki::Iterator);

has iterator => (
    is       => 'rw',
    weak_ref => 1,
    required => 1,
    isa      => Foswiki::Object::isaCLASS(
        'iterator', 'Foswiki::Object', does => 'Foswiki::Iterator',
    ),
);
has '+process' => ( is => 'rw', clearer => 1, required => 1, );
has data => ( is => 'rw', required => 1, );

=begin TML

---++ ClassMethod new( iterator => $iter, process => $sub, data => $data )
Construct a new iterator that will filter $iter by calling
$sub. on each element. $sub should return the filtered value
for the element.

=cut

sub BUILD {
    my $this = shift;
    ASSERT( ref( $this->process ) eq 'CODE' ) if DEBUG;
}

# See Foswiki::Iterator for a description of the general iterator contract
sub next {
    my $this = shift;
    return &{ $this->process }( $this->iterator->next(), $this->data );
}

# See Foswiki::Iterator for a description of the general iterator contract
sub reset {
    my ($this) = @_;

    #TODO: need to carefully consider what side effects this has

    return;
}

sub hasNext {
    my $this = shift;
    return $this->iterator->hasNext(@_);
}

sub all {
    my $this = shift;
    my @results;
    while ( $this->hasNext() ) {
        push( @results, $this->next() );
    }
    return @results;
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
