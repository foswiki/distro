# mod_perl Runtime Engine of Foswiki - The Free and Open Source Wiki,
# http://foswiki.org/
#
# Copyright (C) 2009 Gilmar Santos Jr, jgasjr@gmail.com and Foswiki
# contributors. Foswiki contributors are listed in the AUTHORS file in the root
# of Foswiki distribution.
#
# This module is based/inspired on Catalyst framework. Refer to
#
# http://search.cpan.org/perldoc?Catalyst
#
# for credits and liscence details.
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

=begin TML

---+!! package Foswiki::Engine::Apache2

Base class that implements mod_perl2 execution mode.

Refer to the Foswiki::Engine documentation for further information.

=cut

package Foswiki::Engine::Apache2;

use strict;
use Foswiki::Engine::Apache;
our @ISA = qw( Foswiki::Engine::Apache );

sub finalizeHeaders {
    my ( $this, @p ) = @_;

    $this->SUPER::finalizeHeaders(@p);

    # This handles the case where Apache2 will remove the Content-Length
    # header on a HEAD request.
    # http://perl.apache.org/docs/2.0/user/handlers/http.html
    if ( $this->{r}->header_only ) {
        $this->{r}->rflush;
    }
}

1;
