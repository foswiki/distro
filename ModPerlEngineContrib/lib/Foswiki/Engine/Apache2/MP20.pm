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

---+!! package Foswiki::Engine::Apache2::MP20

Class to complement Foswiki::Engine::Apache2.

Refer to Foswiki::Engine documentation for explanation about methos below.

=cut

package Foswiki::Engine::Apache2::MP20;

use strict;
use Foswiki::Engine::Apache2;
our @ISA = qw( Foswiki::Engine::Apache2 );

use Apache2::Connection ();
use Apache2::Const -compile => qw(OK);
use Apache2::RequestIO   ();
use Apache2::RequestRec  ();
use Apache2::RequestUtil ();
use Apache2::Response    ();
use Apache2::URI         ();
use APR::Table           ();

BEGIN {
    eval qq{require Apache2::Request; require Apache2::Upload;};
    *queryClass = $@ ? sub { 'CGI' } : sub { 'Apache2::Request' };
}

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $this  = {};
    return bless $this, $class;
}

sub OK { Apache2::Const::OK }

1;
