# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::ConfigureGUI::SMIME::InstallCert;

use strict;
use warnings;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

use Foswiki::Configure(qw/:cgi/);

sub provideFeedback {
    my $this = shift;
    my ( $valobj, $button, $label ) = @_;

    $this->{FeedbackProvided} = 1;

    # Normally, we call check first, but not if called by check.

    #    my $e = $button ? $this->check($valobj) : '';
    my $e = '';

    my $keys = $valobj->{keys};

    delete $this->{FeedbackProvided};

    my $certfile = '$Foswiki::cfg{DataDir}' . "/SmimeCertificate.pem";
    Foswiki::Configure::Load::expandValue($certfile);
    my $keyfile = '$Foswiki::cfg{DataDir}' . "/SmimePrivateKey.pem";
    Foswiki::Configure::Load::expandValue($keyfile);

    if ( $button == 1 ) {
        $e .= $this->showCSR("$certfile.csr");
    }
    elsif ( $button == 2 ) {
        $e .= $this->installCert( $certfile, $keyfile );
        return
          wantarray
          ? ( $e,
            [qw/{Email}{SmimeCertificateFile} {Email}{SmimeKeyPassword}/] )
          : $e;
    }
    elsif ( $button == 3 ) {
        my $file = $Foswiki::cfg{Email}{SmimeCertificateFile};
        Foswiki::Configure::Load::expandValue($file) if ($file);
        $file ||= $certfile;
        $e .= $this->showCert($file);
    }
    return wantarray ? ( $e, 0 ) : $e;
}

sub showCSR {
    my $this = shift;
    my ($csrfile) = @_;

    unless ( -r $csrfile ) {
        return $this->ERROR("No CSR pending");
    }

    my $output;
    {
        no warnings 'exec';

        $output = `openssl req -in $csrfile -batch -subject -text 2>&1`;
    }
    if ($?) {
        return $this->ERROR(
            "Operation failed" . ( $? == -1 ? " (No openssl: $!)" : '' ) )
          . $this->FB_VALUE( '{ConfigureGUI}{SMIME}{InstallCert}', $output );
    }

    return $this->FB_VALUE( '{ConfigureGUI}{SMIME}{InstallCert}', $output );
}

sub installCert {
    my $this = shift;
    my ( $certfile, $keyfile ) = @_;

    my $e = '';

    return $this->ERROR("No pending Certificate request")
      unless ( -r "$certfile.csr" && -r "$keyfile.csr" );

    my $data = $query->param('{ConfigureGUI}{SMIME}{InstallCert}') || '';

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

    return $this->ERROR("No certificate present; please paste into text box")
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
        return $this->ERROR(
            "Operation failed" . ( $? == -1 ? " (No openssl: $!)" : '' ) )
          . $this->FB_VALUE( '{ConfigureGUI}{SMIME}{InstallCert}', $output );
    }

    if ( $Foswiki::cfg{Email}{SmimeCertificateFile} ) {
        return $this->ERROR(
"This appears to be a valid certificate, but a certificate file has been specified, so loading this certificate isn't useful.  Remove the specification in {Email}{SmimeCertificateFile} if you want to load this certificate, or point it to the correct file."
        ) . $this->FB_VALUE( '{ConfigureGUI}{SMIME}{InstallCert}', $output );
    }

    my $f;
    unless ( open( $f, '>', $certfile ) ) {
        return $this->ERROR("Unable to open $certfile: $!");
    }
    print $f $data;
    close $f or return $this->ERROR("Failed to write $certfile: $!");

    $e .= "$certfile written.<br />";

    unlink($keyfile);
    rename( "$keyfile.csr", "$keyfile" )
      or return $this->ERROR("Unable to install private key: $!");
    $e .= "$keyfile updated.<br />";

    $Foswiki::cfg{Email}{SmimeKeyPassword} =
      $Foswiki::cfg{Email}{SmimePendingKeyPassword};
    $Foswiki::cfg{Email}{SmimePendingKeyPassword} = '';

    unlink("$certfile.csr")
      or $e .= $this->ERROR("Can't delete $certfile.csr: $!");

    return join(
        '',
        $this->NOTE($e),
        $this->FB_VALUE(
            '{Email}{SmimeKeyPassword}', $Foswiki::cfg{Email}{SmimeKeyPassword}
        ),
        $this->FB_VALUE( '{Email}{SmimePendingKeyPassword}',   '' ),
        $this->FB_VALUE( '{ConfigureGUI}{SMIME}{InstallCert}', $output )
    );
}

sub showCert {
    my $this = shift;
    my ($certfile) = @_;

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
              . ( $? == -1 ? " (No openssl: $!)" : '' ) )
          . $this->FB_VALUE( '{ConfigureGUI}{SMIME}{InstallCert}', $output );
    }

    if ( open( my $f, '<', $certfile ) ) {
        local $/;
        $output .= "===== File Contents =====\n" . <$f>;
        close $f;
    }
    else {
        return $this->ERROR("Unable to read $certfile: $1");
    }

    return $this->NOTE("Certificate data from $certfile")
      . (
        $Foswiki::cfg{Email}{EnableSMIME}
        ? ''
        : $this->WARN("S/MIME signing is not enabled.")
      ) . $this->FB_VALUE( '{ConfigureGUI}{SMIME}{InstallCert}', $output );
}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2012 Foswiki Contributors. Foswiki Contributors
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
