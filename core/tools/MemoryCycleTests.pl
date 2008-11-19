#!/usr/bin/perl -w
#
# Foswiki - The Free Open Source Wiki, http://foswiki.org/
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
    use File::Spec;

    unshift @INC, split(/:/, $ENV{TWIKI_LIBS} || '../lib' );

    # designed to be run within a SVN checkout area
    my @path = split( /\/+/, File::Spec->rel2abs($0) );
    pop(@path); # the script name

    while (scalar(@path) > 0) {
        last if -d join( '/', @path).'/twikiplugins/BuildContrib';
        pop( @path );
    }

    if(scalar(@path)) {
        unshift @INC, join( '/', @path ).'/lib';
        unshift @INC, join( '/', @path ).'/twikiplugins/BuildContrib/lib';
    }
}

use Foswiki;
use Foswiki::UI::View;

{
    my $twiki = new Foswiki();
    $Foswiki::Plugins::SESSION = $twiki;
    monitor('TWiki' => \$Foswiki::Plugins::SESSION );

    Foswiki::UI::run( \&Foswiki::UI::View::view );
    
    #NOTE that Foswiki::finish() is hiding many circular references by foricbly clearing
    #them with the %$this = (); its worth commenting out this line once in a while to 
    #see if its gettign worse (56 are found as of Jun2006)
    
    print_circular_ref(\$Foswiki::Plugins::SESSION );
}

1;
