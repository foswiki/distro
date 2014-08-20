# See bottom of file for license and copyright information

package Foswiki::Configure::Checkers::Email::EnableSMIME;

use strict;
use warnings;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

use Foswiki::Configure::Load;
use Foswiki::Configure::Dependency ();

our @mods = (
    {
        name => 'Crypt::SMIME',
        usage => 'Required for S/MIME',
        minimumVersion => 0.09
    },
    {
        name => 'Crypt::X509',
        usage => 'Required for validation',
        minimumVersion => 0.51
    },
    {
        name => 'Convert::PEM',
        usage => 'Required for encrypted private key files',
        minimumVersion => 0.08
    }
);

sub check_current_value {
    my ($this, $reporter) = @_;

    return unless $Foswiki::cfg{Email}{EnableSMIME};

    Foswiki::Configure::Dependency::checkPerlModules(@mods);
    foreach my $mod (@mods) {
        if (!$mod->{ok}) {
            $reporter->ERROR($mod->{check_result});
        } else {
            $reporter->NOTE($mod->{check_result});
        }
    }

    my $selfCert = "\$Foswiki::cfg{DataDir}/SmimeCertificate.pem";
    Foswiki::Configure::Load::expandValue($selfCert);
    my $selfKey = "\$Foswiki::cfg{DataDir}/SmimePrivateKey.pem";
    Foswiki::Configure::Load::expandValue($selfKey);

    unless (
           $Foswiki::cfg{Email}{SmimeCertificateFile}
        && $Foswiki::cfg{Email}{SmimeKeyFile}
        || (   !$Foswiki::cfg{Email}{SmimeCertificateFile}
            && !$Foswiki::cfg{Email}{SmimeKeyFile}
            && -r $selfCert
            && -r $selfKey )
        ) {
        $reporter->ERROR(<<OMG);
Either Certificate and Key files must be provided for S/MIME email, or a
self-signed certificate can be generated.  To generate a self-signed
certificate or generate a signing request, use the respective WebmasterName
action button.
OMG
    }
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

