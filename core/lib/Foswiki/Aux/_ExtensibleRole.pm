# See bottom of file for license and copyright information

package Foswiki::Aux::_ExtensibleRole;
use v5.14;

use Moo::Role;

# This role is not to be applied manually but by Foswiki::Class only!

# Though this attribute is seemingly duplicating Foswiki::AppObject app
# attribute but it's purpose to be optional and apply cleanly to classes which
# are not Foswiki::App-dependant.
has __appObj => (
    is        => 'rw',
    lazy      => 1,
    predicate => 1,
    isa       => Foswiki::Object::isaCLASS( '__appObj', 'Foswiki::App' ),
    weak_ref  => 1,
);

around BUILD => sub {
    my $orig     = shift;
    my $this     = shift;
    my ($params) = @_;

    #$this->_traceMsg("Storing app for extensible objet");

    if ( defined $params->{app} && $params->{app}->isa('Foswiki::App') ) {
        $this->__appObj( $params->{app} );
    }

    return $orig->( $this, @_ );
};

# Foswiki::Object::clone support.
# Avoid full app cloning.
sub _clone__appObj {
    return $_[0]->__appObj;
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
