# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::AuthRealm;

use strict;
use warnings;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

sub check {
    my $this = shift;

    if ( !$Foswiki::cfg{AuthRealm} ) {
        return $this->ERROR(
'Please make sure you enter an Authentication Realm. This is required for registration to work.'
        );
    }

    if (
        ( $Foswiki::cfg{AuthRealm} =~ /\:/ )
        and

 #        ($Foswiki::cfg{AuthRealm} eq 'Foswiki::LoginManager::ApacheLogin') and
        ( $Foswiki::cfg{Htpasswd}{Encoding} eq 'md5' )
      )
    {
        return $this->ERROR(
"Digest auth (md5) password files store the AuthRealm in the password file, which uses ':' (colons) as the data separator. Please remove the colon from the Setting."
        );
    }
    return '';
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
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
