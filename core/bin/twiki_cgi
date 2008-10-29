#!/usr/bin/perl -wT
#
# TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2007 Peter Thoeny, peter@thoeny.org
# and TWiki Contributors.
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
use warnings;

BEGIN {
    if ( defined $ENV{GATEWAY_INTERFACE} ) {
        $TWiki::cfg{Engine} = 'TWiki::Engine::CGI';
        use CGI::Carp qw(fatalsToBrowser);
        $SIG{__DIE__} = \&CGI::Carp::confess;
    }
    else {
        print STDERR "This script should not be called from command line.\n";
        exit(1);
    }
    delete $ENV{TWIKI_ACTION} if exists $ENV{TWIKI_ACTION};
    @INC = ('.', grep { $_ ne '.' } @INC);
    require 'setlib.cfg';
}

use TWiki;
use TWiki::UI;
$TWiki::engine->run();
