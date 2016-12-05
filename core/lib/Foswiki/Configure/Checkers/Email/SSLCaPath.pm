# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::Email::SSLCaPath;

use strict;
use warnings;

require Foswiki::Configure::Checker;
our @ISA = qw/Foswiki::Configure::Checker/;

sub check_current_value {
    my ( $this, $reporter ) = @_;

    return ''
      unless ( $Foswiki::cfg{Email}{MailMethod} =~ m/^Net::SMTP/
        && $Foswiki::cfg{Email}{SSLVerifyServer} );

    my $file = $Foswiki::cfg{Email}{SSLCaFile};
    Foswiki::Configure::Load::expandValue($file);

    if ( $file && !-r $file ) {
        $reporter->ERROR("Unable to read $file");
    }
    my $path = $this->checkExpandedValue($reporter);
    if ($path) {
        if ( !( -d $path && -r _ ) ) {
            $reporter->ERROR(
                -d _ ? "$path is not readable" : "$path is not a directory" );
        }
        if ( ( ( stat _ )[2] || 0 ) & 02 ) {
            $reporter->ERROR("$path is world-writable");
        }
    }
    if ( !( $file || $path ) ) {
        $reporter->ERROR(
"Either or both {Email}{SSLCaFile} and {Email}{SSLCaPath} must be set for server verification.  The CPAN module Mozilla::CA provides a convenient way to get a default file, but you should ensure that that it satisfies your site's security policies and that the sever that you use has a certificate issued by a Certificate Authority in the trust list.  Alternatively, your OS distribution may also provide a file or directory."
        );
    }

    if ( $file && $path ) {
        my @mods = (
            {
                name => 'IO::Socket::SSL',
                usage =>
'Required if both ={Email}{SSLCaFile}= and ={Email}{SSLCaPath}= are set. Clear one or the other.',
                minimumVersion => 1.973
            }
        );
        Foswiki::Configure::Dependency::checkPerlModules(@mods);
        foreach my $mod (@mods) {
            if ( !$mod->{ok} ) {
                $reporter->ERROR( $mod->{check_result} );
            }
        }
    }

    my $cfile = $Foswiki::cfg{Email}{SSLCrlFile};
    Foswiki::Configure::Load::expandValue($cfile);
    if ( $Foswiki::cfg{Email}{SSLCheckCRL}
        && !( $path || $cfile ) )
    {
        $reporter->ERROR(
"Either or both {Email}{SSLCrlFile} and {Email}{SSLCrlPath} must be set for CRL verification."
        );
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
