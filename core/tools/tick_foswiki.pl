#! /usr/bin/env perl
# See bottom of file for license and copyright information
#
# The Foswiki 'bin' directory must be on your include path when you run
# this script. This is so it can pick up the right environment
# from setlib.cfg.
# You can add a directory to your include path using the -I option
# to the perl command e.g. perl -I /usr/local/foswiki/bin tick_foswiki.pl
#
# It executes a number of non-essential regular administration
# tasks that will help keep your Foswiki healthy and happy.
#
# It is intended to be run as a cron job (remember it has to be run
# by a user who can write files created by the webserver user!)
# For example,
#
# 0 0 * * 0 cd /usr/foswiki/bin && perl ../tools/tick_foswiki.pl
#
use strict;
use warnings;

BEGIN {
    if ( -e './setlib.cfg' ) {
        unshift @INC, '.';
    }
    elsif ( -e '../bin/setlib.cfg' ) {
        unshift @INC, '../bin';
    }    # otherwise rely on the user-set path
    require 'setlib.cfg';
}

use Foswiki ();

# This will expire sessions that have not been used for
# |{Sessions}{ExpireAfter}| seconds i.e. if you set {Sessions}{ExpireAfter}
# to -36000 or 36000 it will expire sessions that have not been used for
# more than 10 hours,

use Foswiki::LoginManager ();
Foswiki::LoginManager::expireDeadSessions();

# This will expire pending registrations that have not been used for
# |{Register}{ExpireAfter}| seconds i.e. if you set {Register}{ExpireAfter}
# to -36000 or 36000 it will expire registrations that have not been verified for
# more than 10 hours,

use Foswiki::UI::Register ();
Foswiki::UI::Register::expirePendingRegistrations();

# This will expire the caches that are used to store query parameters through
# a validation confirmation process. By default these are expired if they
# are older than 5 minutes, or you can pass a different timeout (in seconds).
use Foswiki::Request::Cache ();
Foswiki::Request::Cache::cleanup();

# This will remove topic leases that have expired. Topic leases may also be
# left behind when a user edits a topic and then navigates away without
# cancelling the edit.
use Foswiki::Meta ();
my $root = new Foswiki::Meta( new Foswiki() );
$root->onTick( time() );

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2009-2013 Foswiki Contributors. Foswiki Contributors
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
