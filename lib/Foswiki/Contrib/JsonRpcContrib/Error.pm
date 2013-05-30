# JSON-RPC for Foswiki
#
# Copyright (C) 2011-2013 Michael Daum http://michaeldaumconsulting.com
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

use strict;
use warnings;

use Error ();
our @ISA = ('Error');    # base class

sub new {
    my ( $class, $code, $message ) = @_;

    return $class->SUPER::new(
        code    => $code,
        message => $message,
    );
}

sub stringify {
    my $this = shift;
    return "Error($this->{code}): $this->{message}";
}

1;

