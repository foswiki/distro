package Foswiki::Configure::Wizards::ShowActiveCertificate;

=begin TML

---++ package Foswiki::Configure::Wizards::ShowActiveCertificate

Wizard to show active SSL Certificate.

=cut

use strict;
use warnings;

use Foswiki::Configure::Wizard ();
our @ISA = ('Foswiki::Configure::Wizard');

sub execute {
    my ( $this, $reporter ) = @_;

    my $certfile = '$Foswiki::cfg{DataDir}' . "/SmimeCertificate.pem";
    Foswiki::Configure::Load::expandValue($certfile);

    unless ( -r $certfile ) {
        return $this->ERROR("No Certificate is installed");
    }

    # Can have multiple certs (chain); openssl only displays first
    # So append the cert data manually.

    my $output = "===== Certificate Details =====\n";

    {
        no warnings 'exec';

        $output .= `openssl x509 -in $certfile -text -noout 2>&1`;
    }
    if ($?) {
        return $this->ERROR( "Operation failed on $certfile"
              . ( $? == -1 ? " (No openssl: $!)" : '' ) );
    }

    if ( open( my $f, '<', $certfile ) ) {
        local $/;
        $output .= "===== File Contents =====\n" . <$f>;
        close $f;
        $this->param( 'certificate', $output );
    }
    else {
        return $this->ERROR("Unable to read $certfile: $1");
    }

    $reporter->WARN("S/MIME signing is not enabled.")
      unless $Foswiki::cfg{Email}{EnableSMIME};

    return $this->NOTE( "Certificate data from $certfile",
        '<verbatim>', $output, '</verbatim>' );
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
