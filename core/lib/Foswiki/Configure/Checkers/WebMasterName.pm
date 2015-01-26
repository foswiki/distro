# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::WebMasterName;

use strict;
use warnings;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

sub check_current_value {
    my ( $this, $reporter ) = @_;

    if ( $Foswiki::cfg{Email}{EnableSMIME}
        && !$Foswiki::cfg{Email}{SmimeCertificateFile} )
    {
        my $certfile = '$Foswiki::cfg{DataDir}' . "/SmimeCertificate.pem";
        Foswiki::Configure::Load::expandValue($certfile);
        my $keyfile = '$Foswiki::cfg{DataDir}' . "/SmimePrivateKey.pem";
        Foswiki::Configure::Load::expandValue($keyfile);
        if ( !( -r $certfile && -r $keyfile ) ) {

            # SMELL: shell command
            my $openSSLOk = eval {
                my $tmp = qx/openssl version 2>&1/;
                !$?;
            };

            if ($openSSLOk) {
                $reporter->ERROR(
"S/MIME signing with self-signed certificate requested, but files are not present.  Please generate a certificate with the action button or install a certificate under the Secure Email tab."
                );
            }
            else {
                $reporter->ERROR(
"S/MIME signing requested, but files are not present.  Please a certificate and install it under the Secure Email tab.  To use the Foswiki action buttons to generate a certificate or certificate request, you must install OpenSSL."
                );
            }
        }
    }

    $reporter->ERROR(
"Please specify the name to appear on Foswiki-generated e-mails.  It can be generic."
    ) unless ( $Foswiki::cfg{WebMasterName} );
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2014 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
