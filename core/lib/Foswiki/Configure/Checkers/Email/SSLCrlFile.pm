# See bottom of file for license and copyright information

package Foswiki::Configure::Checkers::Email::SSLCrlFile;

use strict;
use warnings;

require Foswiki::Configure::Checker;
our @ISA = qw/Foswiki::Configure::Checker/;

sub check {
    my $this = shift;
    my ($valobj) = @_;

    return '' unless ( $Foswiki::cfg{Email}{SSLCheckCRL} );

    my $value = $this->getCfg;

    my $e = '';
    my $n = '';

    unless ( $value || $Foswiki::cfg{Email}{SSLCaPath} ) {

        # See if we can use LWP or Crypt::SSLEay's defaults

        my ( $file, $path ) = @ENV{ undef, qw/PERL_LWP_SSL_CA_PATH/ };
        if ( $file || $path ) {
            $n .= $this->NOTE("Guessed from LWP settings");
        }
        else {
            $path = $ENV{HTTPS_CA_DIR};
            if ( $file || $path ) {
                $n .= $this->NOTE("Guessed from Crypt::SSLEay's settings");
            }
            elsif ( $this->getCfg( $Foswiki::cfg{Email}{SSLCaFile} ) ) {
                $n .= $this->NOTE(
                    "Guessed {Email}{SSLCaFile} may also contain CRLs");
                $file = '$Foswiki::cfg{Email}{SSLCaFile}';
            }
        }
        if ($n) {
            $n    = $this->guessed(0) . $n;
            $file = '' unless ( defined $file );
            $path = '' unless ( defined $path );
            $this->setItemValue($file);
            $this->setItemValue( $path, '{Email}{SSLCaPath}' )
              if ($path);
        }
    }

    my $file = $this->getCfg;
    $n = $this->showExpandedValue( $this->getItemCurrentValue ) . $n;

    if ( $file && !-r $file ) {
        $e .= $this->ERROR("Unable to read $file");
    }
    elsif ($file) {
        $n .= $this->NOTE(
            "File was last modified " . ( scalar localtime( ( stat _ )[9] ) ) );
    }
    if ( $file && ( stat _ )[2] & 02 ) {
        $e .= $this->ERROR("$file is world-writable");
    }
    my $path = $this->getCfg('{Email}{SSLCaPath}');
    if ( $path && !( -d $path && -r $path ) ) {
        $e .= $this->ERROR(
            -d $path ? "$path is not readable" : "$path is not a directory" );
    }

    if ( $e || !( $file || $path ) ) {
        $e .= $this->ERROR(
"Either or both {Email}{SSLCrlFile} and {Email}{SSLCaPath} must be set for server verification.  CRLs are more dynamic than CA root certificates, and must be updated frequently to be useful.  Be sure that any method you choose satisfies your site's security policies.  Alternatively, your OS distribution may also provide a file or directory."
        );
    }
    return $n . $e;
}

sub provideFeedback {
    my $this = shift;
    my ( $valobj, $button, $label ) = @_;

    $this->{FeedbackProvided} = 1;

    # Normally, we call check first, but not if called by check.

    my $e = $button ? $this->check($valobj) : '';

    my $keys = $valobj->getKeys();

    delete $this->{FeedbackProvided};

    if ( $button == 2 ) {
        $e .= $this->checkCRLFile($valobj)
          unless ( $e =~ /Error:/ );
    }

    if ( $e =~ /I guessed/ ) {
        $e .= $this->FB_VALUE( $keys, $this->getItemCurrentValue )
          . $this->FB_VALUE( '{Email}{SSLCaPath}',
            $this->getItemCurrentValue('{Email}{SSLCaPath}') );
    }

    return wantarray ? ( $e, 0 ) : $e;
}

sub checkCRLFile {
    my $this = shift;
    my ($valobj) = @_;

    my $e = '';

    my $path = $this->getCfg;

    # If path needed, check() reported it missing

    return $e unless ($path);

    $path =~ m,^([\w_./]+)$,
      or return $e . $this->ERROR("Invalid characters in $path");
    $path = $1;

    my $certs = 0;
    my $crls  = 0;

    open( my $fh, '<', $path )
      or return $e . $this->ERROR("Unable to open $path: $!");
    while (<$fh>) {
        if (/^-----BEGIN (.*)-----/) {
            my $hdr = $1;
            if ( $hdr =~ /^(X509 |TRUSTED |)CERTIFICATE$/ ) {
                $certs++;
            }
            elsif ( $hdr eq 'X509 CRL' ) {
                $crls++;
            }
        }
    }
    close($fh);
    my $m;
    if ($crls) {
        $m = "File contains $crls CRL";
        $m .= 's' if ( $crls != 1 );
        $e .= $this->NOTE($m);
    }
    elsif ( $Foswiki::cfg{Email}{SSLCaPath} ) {
        $e .= $this->NOTE("File contains no CRLs, but {Email}{SSLCaPath} may.");
    }
    else {
        $e .= $this->ERROR("File contains no CRLs");
    }
    if ($certs) {
        $m = "File ";
        $m .= 'also ' if ($crls);
        $m .= "contains $certs certificate";
        $m .= 's'     if ( $certs != 1 );
        $e .= $this->NOTE($m);
    }
    return $e;
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
