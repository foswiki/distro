# See bottom of file for license and copyright information

package Foswiki::Contrib::JsonRpcContrib;

use strict;
use warnings;
use Foswiki::Request ();

BEGIN {
    # Backwards compatibility for Foswiki 1.1.x
    unless ( Foswiki::Request->can('multi_param') ) {
        no warnings 'redefine';    ## no critic
        *Foswiki::Request::multi_param = \&Foswiki::Request::param;
        use warnings 'redefine';
    }
}

=begin TML

---+ package JsonRpcContrib

=cut

our $VERSION           = '3.01';
our $RELEASE           = '%$RELEASE%';
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
__END__
# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# JsonRpcContrib is Copyright (C) 2011-2023 Michael Daum http://michaeldaumconsulting.com
# and Foswiki Contributors.
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
