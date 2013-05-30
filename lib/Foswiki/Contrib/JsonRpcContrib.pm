# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# JsonRpcContrib is Copyright (C) 2011-2013 Michael Daum http://michaeldaumconsulting.com
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

package Foswiki::Contrib::JsonRpcContrib;

use strict;
use warnings;

=begin TML

---+ package JsonRpcContrib

=cut

use version; our $VERSION = version->declare("v2.1.0");
our $RELEASE           = '30 May 2013';
our $SHORTDESCRIPTION  = 'JSON-RPC interface for Foswiki';
our $NO_PREFS_IN_TOPIC = 1;
our $SERVER;

sub registerMethod {
    getServer()->registerMethod(@_);
}

sub dispatch {
    getServer()->dispatch(@_);
}

sub getServer {

    unless ( defined $SERVER ) {
        require Foswiki::Contrib::JsonRpcContrib::Server;
        $SERVER = new Foswiki::Contrib::JsonRpcContrib::Server();
    }

    return $SERVER;
}

1;
