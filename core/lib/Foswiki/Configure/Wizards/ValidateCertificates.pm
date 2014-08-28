# See bottom of file for license and copyright information
package Foswiki::Configure::Wizards::ValidateCertificates;

=begin TML

---++ package Foswiki::Configure::Wizards::ValidateCertificates

Wizard to check SSL certificates.

=cut

use strict;
use warnings;

use Foswiki::Configure::Wizard ();
our @ISA = ('Foswiki::Configure::Wizard');

# WIZARD
sub validate {
    my ( $this, $reporter ) = @_;

    my $path = $Foswiki::cfg{Email}{SSLCaPath};

    unless ($path) {
        return $reporter->ERROR(
            '{Email}{SSLCaPath} is not set; nothing to validate');
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

        my @type = fileType( $filepath, \%seen );
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
}

# Identify file type
# Note that a file can contain both certs and crls

sub fileType {
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
