# JSON-RPC for Foswiki
#
# Copyright (C) 2011-2015 Michael Daum http://michaeldaumconsulting.com
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

package Foswiki::Contrib::JsonRpcContrib::Error;
use v5.14;

use Moo;
use namespace::clean;
extends qw(Foswiki::Exception);

has code => ( is => 'rw', );

around BUILDARGS => sub {
    my $orig   = shift;
    my $class  = shift;
    my %params = @_;

    $params{text} //= $params{message} if $params{message};

    return $orig->( $class, %params );
};

sub stringify {
    my $this = shift;
    return "Error(" . $this->code . "): " . $this->text;
}

# Temporary method to keep compatibility with the old syntax.
sub message {
    return $_[0]->text;
}

1;

