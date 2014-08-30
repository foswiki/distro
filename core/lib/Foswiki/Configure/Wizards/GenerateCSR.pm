# See bottom of file for license and copyright information
package Foswiki::Configure::Wizards::GenerateCSR;

=begin TML

---++ package Foswiki::Configure::Wizards::GenerateCSR

Wizard to generate a SMIME certificate signing request (CSR).

=cut

use strict;
use warnings;

use Foswiki::Configure::Wizard ();
our @ISA = ('Foswiki::Configure::Wizard');

use Foswiki::Configure::Wizards::GenerateSMIMECertificate ();

# WIZARD
sub request_cert {
    my ( $this, $reporter ) = @_;
    return Foswiki::Configure::Wizards::GenerateSMIMECertificate::generate(
        $reporter,
        {
            C  => [ $Foswiki::cfg{Email}{SmimeCertC} ],
            ST => [ $Foswiki::cfg{Email}{SmimeCertST} ],
            L  => [ $Foswiki::cfg{Email}{SmimeCertL} ],
            O  => [ $Foswiki::cfg{Email}{SmimeCertO} ],
            U  => [ $Foswiki::cfg{Email}{SmimeCertOU} ],
        }
    );
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
