# See bottom of file for license and copyright information
package Foswiki::Configure::Wizards::SSLCertificates;

=begin TML

---++ package Foswiki::Configure::Wizards::SSLCertificates

Wizard to check SSL certificates.

=cut

use strict;
use warnings;

use Foswiki::Configure::Checker ();

use Foswiki::Configure::Wizard ();
our @ISA = ('Foswiki::Configure::Wizard');

=begin TML

---++ WIZARD guess_locations

Guess the locations of SSL Certificate files.

=cut

sub guess_locations {
    my ( $this, $reporter ) = @_;

    # See if we can use LWP or Crypt::SSLEay's defaults

    my ( $file, $path ) = @ENV{qw/PERL_LWP_SSL_CA_FILE PERL_LWP_SSL_CA_PATH/};
    my $guessed = 0;
    if ( $file || $path ) {
        $reporter->NOTE("Guessed from LWP settings");
        $guessed = 1;
    }
    else {
        ( $file, $path ) = @ENV{qw/HTTPS_CA_FILE HTTPS_CA_DIR/};
        if ( $file || $path ) {
            $reporter->NOTE("Guessed from Crypt::SSLEay's settings");
            $guessed = 1;
        }
        else {
            if ( eval 'require Mozilla::CA;' ) {
                $file = Mozilla::CA::SSL_ca_file();
                if ($file) {
                    $reporter->NOTE("Obtained from Mozilla::CA");
                    $guessed = 1;
                }
                else {
                    $reporter->ERROR(
                        "Mozilla::CA is installed but has no file");
                }
            }
        }
    }
    if ($guessed) {
        $reporter->WARN(Foswiki::Configure::Checker::GUESSED_MESSAGE);
        $Foswiki::cfg{Email}{SSLCaFile} = $file || '';
        $reporter->CHANGED('{Email}{SSLCaFile}');
        $Foswiki::cfg{Email}{SSLCaPath} = $path || '';
        $reporter->CHANGED('{Email}{SSLCaPath}');
    }
    return undef;
}

=begin TML

---++ WIZARD validate

Validate SSL certificates

=cut

sub validate {
    my ( $this, $reporter ) = @_;

    my $path = $Foswiki::cfg{Email}{SSLCaPath};

    unless ($path) {
        $reporter->ERROR('{Email}{SSLCaPath} is not set; nothing to validate');
        return undef;
    }

    $path =~ m,^([\w_./]+)$,
      or return $this->ERROR("Invalid characters in $path");
    $path = $1;

    # One or both consumers require path

    my $creq = !$Foswiki::cfg{Email}{SSLCaFile};
    my $rreq = $Foswiki::cfg{Email}{SSLCheckCRL}
      && !$Foswiki::cfg{Email}{SSLCrlFile};

    my ( $certs, $crls, $chashes, $rhashes, $errs ) = (0) x 4;

    eval "require File::Spec;" or die "$@\n";

    my $dh;
    unless ( opendir( $dh, $path ) ) {
        return $this->ERROR("Unable to read $path: $!");
    }
    my %seen;
    while ( defined( my $file = readdir($dh) ) ) {
        next if ( $file =~ /^\./ );
        $file =~ /^([\w_.-]+)$/ or next;
        $file = $1;
        my $filepath = File::Spec->catfile( $path, $file );
        unless ( -r $filepath ) {
            $errs++;
            next;
        }

        my @type = _fileType( $filepath, \%seen );
        unless (@type) {
            $errs++;
            next;
        }
        $certs++ if ( $type[0] );
        $crls++  if ( $type[1] );

        if ( $file =~ /^([\da-f]{8})\.(r?)(\d+)$/ ) {
            if ($2) {
                $rhashes++;
            }
            else {
                $chashes++;
            }
        }
    }
    closedir($dh);

    if ($errs) {
        $reporter->ERROR(
"Errors checking files: $errs.  Check permissions and that openssl is installed."
        );
    }

    if ($certs) {
        my $m = "Found $certs unique certificate";
        $m .= 's' if ( $m != 1 );
        if ( $certs eq $chashes ) {
            $m .=
", all of which seem to have a hash. (The hash values were not computed.)";
            $reporter->NOTE($m);
        }
        else {
            $reporter->ERROR(
                ", but only $chashes hash" . ( $chashes = 1 ? '' : 'es' ) );
        }
    }
    elsif ($creq) {
        $reporter->ERROR(
            "No certificates found in path and no {Email}{SSLCaFile} specified"
        );
    }
    else {
        $reporter->NOTE("No certificates found");
    }

    if ($crls) {
        my $m = "Found $crls unique CRL";
        $m .= 's' if ( $m != 1 );
        if ( $crls eq $rhashes ) {
            $m .=
", all of which seem to have a hash. (The hash values were not computed.)";
            $reporter->NOTE($m);
        }
        else {
            $reporter->ERROR(
                ", but only $rhashes hash" . ( $rhashes = 1 ? '' : 'es' ) );
        }
    }
    elsif ($rreq) {
        $reporter->ERROR(
"No CRLs found in path, but {Email}{SSLCheckCRL} is enabled and there is no {Email}{SSLCrlFile}."
        );
    }
    else {
        $reporter->NOTE("No CRLs found");
    }
    return undef;
}

# Identify file type
# Note that a file can contain both certs and crls

sub _fileType {
    my $name = shift;
    my $seen = shift;

    my ( $cert, $crl, $fp );
    open( my $fh, '<', $name ) or return;
    while (<$fh>) {
        if (/^-----BEGIN (.*)-----/) {
            my $hdr = $1;
            if ( $hdr =~ /^(X509 |TRUSTED |)CERTIFICATE$/ ) {
                $cert = 1;
                last if ($crl);
            }
            elsif ( $hdr eq "X509 CRL" ) {
                $crl = 1;
                last if ($cert);
            }
        }
    }
    close($fh);
    return ( 0, 0 ) unless ( $cert || $crl );

    # We aren't re-hashing, and some filesystems will
    # have copied files instead of symlinks, or symlinked
    # files.  We only want a gross sanity check, so we
    # pitch duplicates based on the (sha1) fingerprint, but
    # don't bother to work out hashes,

    $name =~ s/"/\\"/g;

    if ($cert) {
        $fp = `openssl  x509 -fingerprint -noout -in "$name"`;
        return if ($?);
        chomp $fp;
        $fp =~ s/^.*=//;
        $fp =~ tr/://d;
        $cert = 0 if ( $seen->{"c.$fp"} );
        $seen->{"c.$fp"} = 1;
    }

    if ($crl) {
        $fp = `openssl  crl -fingerprint -noout -in "$name"`;
        return if ($?);
        chomp $fp;
        $fp =~ s/^.*=//;
        $fp =~ tr/://d;
        $crl = 0 if ( $seen->{"r.$fp"} );
        $seen->{"r.$fp"} = 1;
    }

    return ( $cert, $crl );
}

=begin TML

---++ WIZARD show_active

Show active SSL certificates

=cut

sub show_active {
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

    $this->NOTE( "Certificate data from $certfile",
        '<verbatim>', $output, '</verbatim>' );

    return undef;
}

=begin TML

---++ WIZARD install_cert

Install SSL Certificate

   * certificate - which must contain the text of a certificate
                   to be installed.
   * password - which must contain the password to be used with the certificate

=cut

sub install_cert {
    my ( $this, $reporter ) = @_;

    my $certfile = '$Foswiki::cfg{DataDir}' . "/SmimeCertificate.pem";
    Foswiki::Configure::Load::expandValue($certfile);
    my $keyfile = '$Foswiki::cfg{DataDir}' . "/SmimePrivateKey.pem";
    Foswiki::Configure::Load::expandValue($keyfile);

    unless ( -r "$certfile.csr" && -r "$keyfile.csr" ) {
        $reporter->ERROR("No pending Certificate request");
        return;
    }

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

    unless ( defined $data
        && $data =~ /^-----BEGIN CERTIFICATE-----/m
        && $data =~ /^-----END CERTIFICATE-----/m )
    {
        $reporter->ERROR("No certificate present");
        return;
    }

    my $output;
    {
        no warnings 'exec';

        $output = `openssl x509 -text 2>&1 <<~~~EOF---
$data
~~~EOF---
`;
    }
    if ($?) {
        $reporter->ERROR(
            "Operation failed" . ( $? == -1 ? " (No openssl: $!)" : '' ) );
        return undef;
    }

    if ( $Foswiki::cfg{Email}{SmimeCertificateFile} ) {
        $reporter->ERROR(
"This appears to be a valid certificate, but a certificate file has been specified, so loading this certificate isn't useful.  Remove the specification in {Email}{SmimeCertificateFile} if you want to load this certificate, or point it to the correct file."
        );
        return;
    }

    my $f;
    unless ( open( $f, '>', $certfile ) ) {
        $reporter->ERROR("Unable to open $certfile: $!");
        return;
    }
    print $f $data;
    unless ( close $f ) {
        $reporter->ERROR("Failed to write $certfile: $!");
        return;
    }

    $reporter->NOTE("$certfile written.");

    unlink($keyfile);
    unless ( rename( "$keyfile.csr", "$keyfile" ) ) {
        $reporter->ERROR("Unable to install private key: $!");
        return;
    }
    $reporter->NOTE("$keyfile updated.");

    $Foswiki::cfg{Email}{SmimeKeyPassword} = $this->param('password');
    $reporter->CHANGED('{Email}{SmimeKeyPassword}');

    unlink("$certfile.csr")
      or $reporter->ERROR("Can't delete $certfile.csr: $!");

    return undef;
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
