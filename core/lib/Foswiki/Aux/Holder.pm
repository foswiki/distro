# See bottom of file for license and copyright information

=begin TML

---++ Class Foswiki::Aux::Holder

Auxiliary class. 

=cut

package Foswiki::Aux::Holder;
use v5.14;

require Foswiki::Object;

use Moo;
use namespace::clean;

has object => (
    is           => 'rw',
    requiredlazy => 1,
    weak_ref     => 1,                           # Not sure we need it here.
    isa          => Foswiki::Object::isaCLASS(
        'object', 'Foswiki::Object',
        does    => 'Foswiki::Aux::Localize',
        noUndef => 1,
    ),
);

sub DEMOLISH {
    my $this = shift;
    $this->object->restore;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2016 Foswiki Contributors. Foswiki Contributors
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
