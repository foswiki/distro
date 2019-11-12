# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# UpdatesPlugin is Copyright (C) 2011-2019 Foswiki Contributors
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html

package Foswiki::Plugins::UpdatesPlugin;

use strict;
use warnings;

use Foswiki::Func ();

our $VERSION           = '2.00';
our $RELEASE           = '12 Nov 2019';
our $SHORTDESCRIPTION  = 'Checks Foswiki.org for updates';
our $NO_PREFS_IN_TOPIC = 1;
our $core;

sub initPlugin {

    # only check for admins viewing a page
    if ( Foswiki::Func::isAnAdmin() && Foswiki::Func::getContext()->{view} ) {
        getCore()->check();
    }

    return 1;
}

sub finishPlugin {
    undef $core;
}

sub getCore {

    unless ($core) {
        require Foswiki::Plugins::UpdatesPlugin::Core;
        $core = Foswiki::Plugins::UpdatesPlugin::Core->new();
    }

    return $core;
}

1;
