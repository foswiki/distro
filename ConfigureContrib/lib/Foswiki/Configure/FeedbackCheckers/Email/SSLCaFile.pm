# See bottom of file for license and copyright information

package Foswiki::Configure::FeedbackCheckers::Email::SSLCaFile;

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
        $e .= $this->_checkCAFile()
          unless ( $e =~ /Error:/ );
    }

    if ( $e =~ /I guessed/ ) {
        $e .= $this->FB_VALUE( $keys, $this->getItemCurrentValue )
          . $this->FB_VALUE( '{Email}{SSLCaPath}',
            $this->getItemCurrentValue('{Email}{SSLCaPath}') );
    }

    return wantarray ? ( $e, 0 ) : $e;
}

sub _checkCAFile {
    my $this = shift;

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
    if ($certs) {
        $m = "File contains $certs certificate";
        $m .= 's' if ( $certs != 1 );
        $e .= $this->NOTE($m);
    }
    elsif ( $Foswiki::cfg{Email}{SSLCaPath} ) {
        $e .= $this->NOTE(
            "File contains no certificates, but {Email}{SSLCaPath} may.");
    }
    else {
        $e .= $this->ERROR("File contains no certificates");
    }
    if ($crls) {
        $m = "File ";
        $m .= 'also ' if ($certs);
        $m .= "contains $crls CRL";
        $m .= 's'     if ( $crls != 1 );
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
