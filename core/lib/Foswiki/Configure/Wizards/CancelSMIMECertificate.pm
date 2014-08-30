# See bottom of file for license and copyright information
package Foswiki::Configure::Wizards::CancelSMIMECertificate;

=begin TML

---++ package Foswiki::Configure::Wizards::CancelSMIMECertificate

Wizard to generate a self-signed SMIME certificate.

=cut

use strict;
use warnings;

use Foswiki::Configure::Wizard ();
our @ISA = ('Foswiki::Configure::Wizard');

use MIME::Base64;

# WIZARD
sub cancel_cert {
    my ( $this, $reporter ) = @_;
    my $ok = 1;

    my $certfile = '$Foswiki::cfg{DataDir}' . "/SmimeCertificate.pem";
    Foswiki::Configure::Load::expandValue($certfile);
    my $keyfile = '$Foswiki::cfg{DataDir}' . "/SmimePrivateKey.pem";
    Foswiki::Configure::Load::expandValue($keyfile);

    if ( -f "$certfile.csr" || -f "$keyfile.csr" ) {
        if ( -f "$certfile.csr" && !unlink("$certfile.csr") ) {
            $ok = 0;
            $reporter->ERROR("Can't delete $certfile.csr: $!");
        }
        if ( -f "$keyfile.csr" && !unlink("$keyfile.csr") ) {
            $ok = 0;
            $reporter->ERROR("Can't delete $keyfile.csr: $!");
        }
        if ($ok) {
            $reporter->NOTE("Request cancelled");
        }
        else {
            $reporter->ERROR("Cancel failed.");
        }
    }
    else {
        $reporter->NOTE("No request pending");
    }
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
