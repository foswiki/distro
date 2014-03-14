# See bottom of file for license and copyright information

=begin TML

---+!! package Foswiki::Engine::Legacy

This engine supports legacy bin scripts that don't use
$Foswiki::cfg{SwitchBoard} yet.

It redefines Foswiki::Request::new and Foswiki::Response::new, so request and
response objects are singletons, making it possible to the engine finalization
phase invoked from the END block happens.

=cut

package Foswiki::Engine::Legacy;

use strict;
use warnings;

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

our @ISA;
my ( $request, $response );

BEGIN {
    if ( $ENV{GATEWAY_INTERFACE} ) {
        require Foswiki::Engine::CGI;
        @ISA = qw(Foswiki::Engine::CGI);
    }
    else {
        require Foswiki::Engine::CLI;
        @ISA = qw(Foswiki::Engine::CLI);
    }
    no warnings 'redefine';
    require Foswiki::Request;
    my $req_new = \&Foswiki::Request::new;
    *Foswiki::Request::new = sub {
        if ( defined $request ) {
            return $request;
        }
        else {
            return $request = $req_new->(@_);
        }
    };
    require Foswiki::Response;
    my $res_new = \&Foswiki::Response::new;
    *Foswiki::Response::new = sub {
        if ( defined $response ) {
            return $response;
        }
        else {
            return $response = $res_new->(@_);
        }
    };
    require Foswiki::EngineException;
}

sub new {
    my $this = shift;
    $this = $this->SUPER::new(@_);
    $this->prepare();
    return $this;
}

END {
    $Foswiki::engine->finalize( $response, $request )
      if ref($response) && $response->isa('Foswiki::Response');
    ( $request, $response ) = ();
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 1999-2007 Peter Thoeny, peter@thoeny.org
and TWiki Contributors. All Rights Reserved. TWiki Contributors
are listed in the AUTHORS file in the root of this distribution.

This module is based/inspired on Catalyst framework. Refer to
http://search.cpan.org/~mramberg/Catalyst-Runtime-5.7010/lib/Catalyst.pm
for credits and license details.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
