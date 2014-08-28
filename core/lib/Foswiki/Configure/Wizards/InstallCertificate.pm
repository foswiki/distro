package Foswiki::Configure::Wizards::InstallCertificate;

=begin TML

---++ package Foswiki::Configure::Wizards::InstallCertificate

Wizard to install SSL Certificate files.

=cut

use strict;
use warnings;

use Foswiki::Configure::Wizard ();
our @ISA = ('Foswiki::Configure::Wizard');

# Accepts the query parameters:
#   * certificate - which must contain the text of a certificate
#                   to be installed.
#   * password - which must contain the password to be used with the certificate
sub execute {
    my ( $this, $reporter ) = @_;

    my $certfile = '$Foswiki::cfg{DataDir}' . "/SmimeCertificate.pem";
    Foswiki::Configure::Load::expandValue($certfile);
    my $keyfile = '$Foswiki::cfg{DataDir}' . "/SmimePrivateKey.pem";
    Foswiki::Configure::Load::expandValue($keyfile);

    return $reporter->ERROR("No pending Certificate request")
      unless ( -r "$certfile.csr" && -r "$keyfile.csr" );

    my $data = $this->param("certificate") || '';

    $data = join(
        "\n",
        map {
            /^-----BEGIN CERTIFICATE-----/ ... /^-----END CERTIFICATE-----/
              ? ($_)
              : ()
        } ( split( /\r?\n/, $data ), '-----END CERTIFICATE-----' )
    );

    $data =~ tr,A-Za-z0-9+=/\r\n \t-,,cd;
    $data =~ m/\A(.*)\z/ms;
    $data = $1;

    return $reporter->ERROR("No certificate present")
      unless ( defined $data
        && $data =~ /^-----BEGIN CERTIFICATE-----/m
        && $data =~ /^-----END CERTIFICATE-----/m );

    my $output;
    {
        no warnings 'exec';

        $output = `openssl x509 -text 2>&1 <<~~~EOF---
$data
~~~EOF---
`;
    }
    if ($?) {
        return $reporter->ERROR(
            "Operation failed" . ( $? == -1 ? " (No openssl: $!)" : '' ) );
    }

    if ( $Foswiki::cfg{Email}{SmimeCertificateFile} ) {
        return $reporter->ERROR(
"This appears to be a valid certificate, but a certificate file has been specified, so loading this certificate isn't useful.  Remove the specification in {Email}{SmimeCertificateFile} if you want to load this certificate, or point it to the correct file."
        );
    }

    my $f;
    unless ( open( $f, '>', $certfile ) ) {
        return $reporter->ERROR("Unable to open $certfile: $!");
    }
    print $f $data;
    close $f or return $reporter->ERROR("Failed to write $certfile: $!");

    $reporter->NOTE("$certfile written.");

    unlink($keyfile);
    rename( "$keyfile.csr", "$keyfile" )
      or return $reporter->ERROR("Unable to install private key: $!");
    $reporter - . NOTE("$keyfile updated.");

    $Foswiki::cfg{Email}{SmimeKeyPassword} = $this->param('password');
    $reporter->CHANGED('{Email}{SmimeKeyPassword}');

    unlink("$certfile.csr")
      or $reporter->ERROR("Can't delete $certfile.csr: $!");

    return 1;
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
