#!/usr/bin/perl -w
#
# Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2006 SvenDowideit@wikiring.com
# and Foswiki Contributors.
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

use strict;
use Devel::Leak::Object qw{ GLOBAL_bless };


BEGIN {
    if ( defined $ENV{GATEWAY_INTERFACE} ) {
        $Foswiki::cfg{Engine} = 'Foswiki::Engine::CGI';
        use CGI::Carp qw(fatalsToBrowser);
        $SIG{__DIE__} = \&CGI::Carp::confess;
    }
    else {
        $Foswiki::cfg{Engine} = 'Foswiki::Engine::CLI';
        require Carp;
        $SIG{__DIE__} = \&Carp::confess;
    }
    $ENV{FOSWIKI_ACTION} = 'view';
    @INC = ('../bin', grep { $_ ne '.' } @INC);
    require 'setlib.cfg';
}

use Foswiki;
use Foswiki::UI::View;

{
##    $Foswiki::Plugins::SESSION = new Foswiki();
#    Foswiki::UI::run( \&Foswiki::UI::View::view );
#    $Foswiki::Plugins::SESSION->finish();
#    undef $Foswiki::Plugins::SESSION;
$Foswiki::engine->run();
}

1;
