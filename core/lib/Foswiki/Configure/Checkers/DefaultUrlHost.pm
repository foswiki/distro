# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::DefaultUrlHost;

use strict;
use warnings;

use Foswiki::Configure::Checkers::URL ();
our @ISA = ('Foswiki::Configure::Checkers::URL');

sub check_current_value {
    my ( $this, $reporter ) = @_;

    my $d = $this->{item}->getExpandedValue();
    if ($d) {
        $this->SUPER::check_current_value($reporter);

        my $host = $ENV{HTTP_HOST};
        if ( $host && $Foswiki::cfg{DefaultUrlHost} !~ m,^https?://$host,i ) {
            $reporter->WARN( 'Current setting does not match HTTP_HOST ',
                $host );
            $reporter->NOTE(
                    'If the URL hostname is correct, set this to =http://'
                  . $host
                  . '= or if using SSL, =https://'
                  . $host . '= '
                  . 'If this setting and the URL are both correct, you could also add the URL to the \'expert setting\' =PermittedRedirectHostUrls=.'
            );
        }
    }
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2014 Foswiki Contributors. Foswiki Contributors
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
