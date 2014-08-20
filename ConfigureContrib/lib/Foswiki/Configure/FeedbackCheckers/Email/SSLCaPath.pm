# See bottom of file for license and copyright information

package Foswiki::Configure::FeedbackCheckers::Email::SSLCaPath;

use strict;
use warnings;

require Foswiki::Configure::Checker;
our @ISA = qw/Foswiki::Configure::Checker/;

sub provideFeedback {
    my ( $this, $button, $label ) = @_;

    return ''
      unless ( $Foswiki::cfg{Email}{MailMethod} =~ /^Net::SMTP/
        && $Foswiki::cfg{Email}{SSLVerifyServer} );

    my $e = '';
    my $keys = $this->{item}->{keys};

    if ( $button == 2 ) {
        $e .= $this->_checkDir()
          unless ( $e =~ /Error:/ );
    }

    if ( $e =~ /I guessed/ ) {
        $e .= $this->FB_VALUE( $keys, $this->getItemCurrentValue )
          . $this->FB_VALUE( '{Email}{SSLCaFile}',
            $this->getItemCurrentValue('{Email}{SSLCaFile}') );
    }

    return wantarray ? ( $e, 0 ) : $e;
}

sub _checkDir {
    my $this = shift;

    my $e = '';

    my $path = $this->getCfg;

    # If path needed, check() reported it missing

    return $e unless ($path);

    $path =~ m,^([\w_./]+)$,
      or return $e . $this->ERROR("Invalid characters in $path");
    $path = $1;

    # One or both consumers require path

    my $creq = !$this->getCfg('{Email}{SSLCaFile}');
    my $rreq = $Foswiki::cfg{Email}{SSLCheckCRL}
      && !$this->getCfg('{Email}{SSLCrlFile}');

    my ( $certs, $crls, $chashes, $rhashes, $errs ) = (0) x 4;

    eval "require File::Spec;" or die "$@\n";

    my $dh;
    unless ( opendir( $dh, $path ) ) {
        return $e . $this->ERROR("Unable to read $path: $!");
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
        $e .= $this->ERROR(
"Errors checking files: $errs.  Check permissions and that openssl is installed."
        );
    }

    if ($certs) {
        my $m = "Found $certs unique certificate";
        $m .= 's' if ( $m != 1 );
        if ( $certs eq $chashes ) {
            $m .=
", all of which seem to have a hash. (The hash values were not computed.)";
            $e .= $this->NOTE($m);
        }
        else {
            $e .= $this->ERROR(
                ", but only $chashes hash" . ( $chashes = 1 ? '' : 'es' ) );
        }
    }
    elsif ($creq) {
        $e .= $this->ERROR(
            "No certificates found in path and no {Email}{SSLCaFile} specified"
        );
    }
    else {
        $e .= $this->NOTE("No certificates found");
    }

    if ($crls) {
        my $m = "Found $crls unique CRL";
        $m .= 's' if ( $m != 1 );
        if ( $crls eq $rhashes ) {
            $m .=
", all of which seem to have a hash. (The hash values were not computed.)";
            $e .= $this->NOTE($m);
        }
        else {
            $e .= $this->ERROR(
                ", but only $rhashes hash" . ( $rhashes = 1 ? '' : 'es' ) );
        }
    }
    elsif ($rreq) {
        $e .= $this->ERROR(
"No CRLs found in path, but {Email}{SSLCheckCRL} is enabled and there is no {Email}{SSLCrlFile}."
        );
    }
    else {
        $e .= $this->NOTE("No CRLs found");
    }
    return $e;
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
