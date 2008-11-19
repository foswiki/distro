#
# Foswiki - The Free Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2000-2006 Foswiki Contributors.
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
package Foswiki::Configure::Checkers::DefaultUrlHost;

use strict;

use Foswiki::Configure::Checker;

use base 'Foswiki::Configure::Checker';

sub check {
    my ( $this, $keys ) = @_;

    if (   $Foswiki::cfg{DefaultUrlHost}
        && $Foswiki::cfg{DefaultUrlHost} ne 'NOT SET' )
    {
        my $host = $ENV{HTTP_HOST};
        if ( $host && $Foswiki::cfg{DefaultUrlHost} !~ /$host/i ) {
            return $this->WARN( 'Current setting does not match HTTP_HOST ',
                $ENV{HTTP_HOST} );
        }
    }
    else {
        my $protocol = $Foswiki::query->url() || 'http://' . $ENV{HTTP_HOST};
        $protocol =~ s(^(.*?://.*?)/.*$)($1);
        $Foswiki::cfg{DefaultUrlHost} = $protocol;
        return $this->guessed(0);
    }
    return '';
}

1;
