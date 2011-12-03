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
use Devel::Monitor qw(:all);

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
    @INC = ( '../bin', grep { $_ ne '.' } @INC );
    require 'setlib.cfg';
}

use Foswiki;
use Foswiki::UI::View;

{
    my $session = new Foswiki();

#NOTE that Foswiki::finish() is hiding many circular references by foricbly clearing
#them with the %$this = (); its worth uncommenting this line once in a while to
#see if its gettign worse (56 are found as of Jun2006)
#*Foswiki::finish = sub {};

    $Foswiki::Plugins::SESSION = $session;
    monitor( 'Foswiki' => \$Foswiki::Plugins::SESSION );

    Foswiki::UI::run( \&Foswiki::UI::View::view );

    print_circular_ref( \$Foswiki::Plugins::SESSION );
}

1;
