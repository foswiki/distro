# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::PROXY::UseForwardedHeaders;

use strict;
use warnings;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

sub check_current_value {
    my ( $this, $reporter ) = @_;

    if ( defined $Foswiki::cfg{Engine}
        && substr( $Foswiki::cfg{Engine}, -3 ) eq 'CLI' )
    {
        my ( $client, $protocol, $host, $port, $proxy ) =
          Foswiki::Engine::_getConnectionData(1);

        if ($proxy) {

            $reporter->NOTE(
"Proxy server detected. Proxy URL is $protocol://$host:$port. Local server name is $ENV{HTTP_HOST}"
            );

            if ( $Foswiki::cfg{PROXY}{UseForwardedHeaders} ) {
                $reporter->WARN(
"Note that =ForceDefaultUrlHost= is a more secure setting for supporting a reverse proxy. "
                );
            }
            else {
                $reporter->NOTE(
'This setting should be enabled if there are multiple proxy servers or there is a mix of proxied and non-proxied clients.'
                );
            }
        }
        else {
            if ( $Foswiki::cfg{PROXY}{UseForwardedHeaders} ) {
                $reporter->WARN(
'You have enabled this setting, but no proxy is detected. Be sure this is what you want to do.'
                );
            }
        }

        if (   $Foswiki::cfg{ForceDefaultUrlHost}
            && $Foswiki::cfg{PROXY}{UseForwardedHeaders} )
        {
            $reporter->ERROR(
'Both ={ForceDefaultUrlHost}= and ={PROXY}{UseForwardedHeaders}= are enabled.  ={PROXY}{UseForwardedHeaders}= will be ignored.'
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
of this distribution. NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
