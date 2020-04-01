# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::PROXY::UseForwardedForHeader;

use strict;
use warnings;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

sub check_current_value {
    my ( $this, $reporter ) = @_;

    if ( $ENV{HTTP_X_FORWARDED_FOR} ) {

        if ( $Foswiki::cfg{PROXY}{UseForwardedForHeader} ) {
            $reporter->NOTE("Real client IP is =$ENV{HTTP_X_FORWARDED_FOR}=.");
        }
        else {
            $reporter->WARN(
"Proxy detected, Enable this switch if Foswiki should use the =HTTP_X_FORWARDED_FOR= header to obtain the real client IP address."
            );
            $reporter->NOTE(
"Remote Address is $ENV{REMOTE_ADDR}, Real client IP is =$ENV{HTTP_X_FORWARDED_FOR}=."
            );
        }
    }

}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2017 Foswiki Contributors. Foswiki Contributors
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
