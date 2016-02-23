# See bottom of file for license and copyright information

# LWP::UserAgent subclass used to pass in username and password,
# and use the Foswiki proxy setup

package Foswiki::Net::UserCredAgent;
use v5.14;

use LWP::UserAgent ();

#our @ISA = ('LWP::UserAgent');

use Moo;
use namespace::clean;
extends qw(Foswiki::Object);

has userAgent => (
    is      => 'ro',
    lazy    => 1,
    default => sub { return LWP::UserAgent->new; },
    handles => [

        # Import all public methods from LWP::UserAgent into our namespace.
        # SMELL Note that /^_/ also reject _agent method which is documented for
        # LWP::UserAgent but doesn't seem to be used neither by Foswiki nor by
        # common plugins in the distro repository. So, it generally should be
        # safe. If somebody would ever need it (actually, what for?) it might be
        # accessed directly through the userAgent attribute.
        grep {
                 defined( *{ $LWP::UserAgent::{$_} }{CODE} )
              && !/^_/
              && !__PACKAGE__->can($_)
          }
          keys %LWP::UserAgent::
    ],
);
has user => (
    is       => 'rw',
    required => 1,
);
has pass => (
    is       => 'rw',
    required => 1,
    init_arg => 'password',
);

# new(user => $user, password => $pass);

sub get_basic_credentials {
    my ( $this, $realm, $uri ) = @_;
    return ( $this->user, $this->pass );
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2007 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root
of this distribution. NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
