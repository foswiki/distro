# See bottom of file for license and copyright information

package Foswiki::Contrib::JsonRpcContrib;
use v5.14;

use Foswiki::Request                         ();
use Foswiki::Contrib::JsonRpcContrib::Server ();

use Moo;
use namespace::clean;
extends qw(Foswiki::UI);

#BEGIN {
#    # Backwards compatibility for Foswiki 1.1.x
#    unless ( Foswiki::Request->can('multi_param') ) {
#        no warnings 'redefine';
#        *Foswiki::Request::multi_param = \&Foswiki::Request::param;
#        use warnings 'redefine';
#    }
#}

=begin TML

---+ package JsonRpcContrib

=cut

our $VERSION           = '2.25';
our $RELEASE           = '4 Jan 2016';
our $SHORTDESCRIPTION  = 'JSON-RPC interface for Foswiki';
our $NO_PREFS_IN_TOPIC = 1;
our $SERVER;

has server => (
    is      => 'rw',
    lazy    => 1,
    default => sub {
        return $_[0]->create('Foswiki::Contrib::JsonRpcContrib::Server');
    },
    isa => Foswiki::Object::isaCLASS(
        'SERVER',
        'Foswiki::Contrib::JsonRpcContrib::Server',
        noUndef => 1,
    ),
);

sub BUILD {
    my $this = shift;

    $SERVER = $this->server;
}

sub registerMethod {
    $Foswiki::app->create(__PACKAGE__) unless $SERVER;
    $SERVER->registerMethod(@_);
}

sub dispatch {
    $_[0]->server->dispatch(@_);
}

1;
__END__
# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# JsonRpcContrib is Copyright (C) 2011-2016 Michael Daum http://michaeldaumconsulting.com
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
