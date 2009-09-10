#!/usr/bin/perl -w
#
# Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2005-2007 Foswiki Contributors.
# All Rights Reserved. Foswiki Contributors are listed in
# the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# For licensing info read license.txt file in the Foswiki root.
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at 
# http://www.gnu.org/copyleft/gpl.html
#
# The Foswiki 'bin' directory must be on your include path when you run
# this script. This is so it can pick up the right Foswiki environment
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
BEGIN {
    unshift @INC, '.';
    require 'setlib.cfg';
}

# This will expire sessions that have not been used for
# |{Sessions}{ExpireAfter}| seconds i.e. if you set {Sessions}{ExpireAfter}
# to -36000 or 36000 it will expire sessions that have not been used for
# more than 100 hours,

use Foswiki::LoginManager;
Foswiki::LoginManager::expireDeadSessions();

# This will remove topic leases that have expired. Topic leases may be
# left behind when users edit a topic and then navigate away without
# cancelling the edit.

use Foswiki;
my $foswiki = new Foswiki();
my $store = $foswiki->{store};
my $now = time();
foreach my $web ( $store->getListOfWebs()) {
    $store->removeSpuriousLeases($web);
    foreach my $topic ( $store->getTopicNames( $web )) {
        my $lease = $store->getLease( $web, $topic );
        if( $lease && $lease->{expires} < $now) {
            $store->clearLease( $web, $topic );
        }
    }
}
