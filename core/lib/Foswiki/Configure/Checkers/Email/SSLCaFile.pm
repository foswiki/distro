# See bottom of file for license and copyright information

package Foswiki::Configure::Checkers::Email::SSLCaFile;

use strict;
use warnings;

require Foswiki::Configure::Checker;
our @ISA = qw/Foswiki::Configure::Checker/;

sub check_current_value {
    my ( $this, $reporter ) = @_;

    return
      unless ( $Foswiki::cfg{Email}{MailMethod} =~ m/^Net::SMTP/
        && $Foswiki::cfg{Email}{SSLVerifyServer} );

    my $file = $this->checkExpandedValue($reporter);
    if ($file) {

        if ( -r $file ) {
            $reporter->NOTE( "File was last modified "
                  . ( scalar( localtime( ( stat _ )[9] ) ) ) );
            _checkCaFile( $file, $reporter );
        }
        else {
            $reporter->ERROR("Unable to read $file");
        }
        if ( ( ( stat _ )[2] || 0 ) & 02 ) {
            $reporter->ERROR("$file is world-writable");
        }
    }

    my $path = $Foswiki::cfg{Email}{SSLCaPath};
    Foswiki::Configure::Load::expandValue($path);
    if ( $path && !( -d $path && -r $path ) ) {
        $reporter->ERROR(
            -d $path ? "$path is not readable" : "$path is not a directory" );
    }

    if ( !( $file || $path ) ) {
        $reporter->ERROR(
"Either or both {Email}{SSLCaFile} and {Email}{SSLCaPath} must be set for server verification.  The CPAN module Mozilla::CA provides a convenient way to get a default file, but you should ensure that that it satisfies your site's security policies and that the sever that you use has a certificate issued by a Certificate Authority in the trust list.  Alternatively, your OS distribution may also provide a file or directory."
        );
    }
}

sub _checkCaFile {
    my ( $path, $reporter ) = @_;

    my $certs = 0;
    my $crls  = 0;

    open( my $fh, '<', $path )
      or return $reporter->ERROR("Unable to open $path: $!");
    while (<$fh>) {
        if (/^-----BEGIN (.*)-----/) {
            my $hdr = $1;
            if ( $hdr =~ m/^(X509 |TRUSTED |)CERTIFICATE$/ ) {
                $certs++;
            }
            elsif ( $hdr eq 'X509 CRL' ) {
                $crls++;
            }
        }
    }
    close($fh);

    if ($certs) {
        my $m = "File contains $certs certificate";
        $m .= 's' if ( $certs != 1 );
        $reporter->NOTE($m);
    }
    elsif ( $Foswiki::cfg{Email}{SSLCaPath} ) {
        $reporter->NOTE(
            "File contains no certificates, but {Email}{SSLCaPath} may.");
    }
    else {
        $reporter->ERROR("File contains no certificates");
    }
    if ($crls) {
        my $m = "File ";
        $m .= 'also ' if ($certs);
        $m .= "contains $crls CRL";
        $m .= 's'     if ( $crls != 1 );
        $reporter->NOTE($m);
    }
}

1;

__END__

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2016 Foswiki Contributors. Foswiki Contributors
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
