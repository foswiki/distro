# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::DefaultUrlHost;

use strict;
use warnings;

use Foswiki::Configure::Checkers::URL ();
our @ISA = ('Foswiki::Configure::Checkers::URL');

sub check_current_value {
    my ( $this, $reporter ) = @_;

    my $d = $this->checkExpandedValue($reporter);
    return unless $d;
    $this->SUPER::check_current_value($reporter);

    if (   $Foswiki::cfg{DefaultUrlHost} =~ m/^\s+/
        || $Foswiki::cfg{DefaultUrlHost} =~ m/\s+$/ )
    {
        $reporter->ERROR(
'Current setting appears to contain leading or trailing spaces. They should be removed.'
        );
    }

    if ( defined $Foswiki::cfg{Engine}
        && substr( $Foswiki::cfg{Engine}, -3 ) eq 'CLI' )
    {

        # Probe the connection in bootstrap mode:
        my ( $client, $protocol, $host, $port, $proxy ) =
          Foswiki::Engine::_getConnectionData(1);
        $port = ( $port && $port != 80 && $port != 443 ) ? ":$port" : '';

        my $detected = $protocol . '://' . $host . $port;

        if (   $Foswiki::cfg{DefaultUrlHost} !~ m#\Q$detected\E#i
            && $Foswiki::cfg{PermittedRedirectHostUrls} !~ m#\Q$detected\E#i )
        {
            $reporter->WARN(
"Current setting does not match URL =$protocol://$host$port=, and it is not listed in ={PermittedRedirectHostUrls}="
            );
            $reporter->NOTE(
"If the URL hostname is correct, set this to =$protocol//$host$port= "
                  . 'If this setting and the URL are both correct, you could also add the URL to the \'expert setting\' =PermittedRedirectHostUrls=.'
            );
        }
    }
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2018 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2000-2006 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root
of this distribution.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
