# Please see the bottom of this file for license and copyright information

=begin TML

---+ package Foswiki::Plugins::QueryAcceleratorPlugin

Plugin for an alternative query algorithm using DBCacheContrib

=cut

package Foswiki::Plugins::QueryAcceleratorPlugin;

use strict;

use Assert;

use Foswiki::Contrib::DBCacheContrib ();

our $NO_PREFS_IN_TOPIC = 1;
our $SHORTDESCRIPTION  = 'Accelerate standard queries in large webs';
our $RELEASE           = '5 Jun 2009';
our $VERSION           = '$Rev$';

# Cache of DBs, one per web
our %cache;

sub initPlugin {
    return 1;
}

# Update the cache when a topic is saved
sub afterSaveHandler {
    my ( $text, $topic, $web, $error, $meta ) = @_;

    # force update
    my $db = getDB($web);
    $db->load(1);
}

# Look up the web cache and get the DB for the web, loading from disk
# if necessary
sub getDB {
    my $web = shift;

    unless ( $cache{$web} ) {
        $cache{$web} =
          new Foswiki::Contrib::DBCacheContrib( $web, '_DBCache_standard', 1 );
        $cache{$web}->load();
    }

    return $cache{$web};
}

1;
__DATA__
# Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2009 Foswiki Contributors. All Rights Reserved.
# Foswiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
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
#
# Author: Crawford Currie
