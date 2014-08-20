# See bottom of file for license and copyright information

package Foswiki::Configure::Checkers::Email::SSLCrlFile;

use strict;
use warnings;

require Foswiki::Configure::Checker;
our @ISA = qw/Foswiki::Configure::Checker/;

sub check_current_value {
    my ($this, $reporter) = @_;

    return '' unless ( $Foswiki::cfg{Email}{SSLCheckCRL} );

    my $value = $this->getCfg;

    unless ( $value || $Foswiki::cfg{Email}{SSLCaPath} ) {

        # See if we can use LWP or Crypt::SSLEay's defaults

        my ( $file, $path ) = @ENV{ undef, qw/PERL_LWP_SSL_CA_PATH/ };
        my $guessed = 0;
        if ( $file || $path ) {
            $reporter->NOTE("Guessed from LWP settings");
            $guessed = 1;
        }
        else {
            $path = $ENV{HTTPS_CA_DIR};
            if ( $file || $path ) {
                $reporter->NOTE("Guessed from Crypt::SSLEay's settings");
                $guessed = 1;
            }
            elsif ( $this->getCfg( $Foswiki::cfg{Email}{SSLCaFile} ) ) {
                $reporter->NOTE(
                    "Guessed {Email}{SSLCaFile} may also contain CRLs");
                $file = '$Foswiki::cfg{Email}{SSLCaFile}';
                $guessed = 1;
            }
        }
        if ($guessed) {
            $reporter->WARN(Foswiki::Configure::Checker::GUESSED_MESSAGE);
            $file = '' unless ( defined $file );
            $path = '' unless ( defined $path );
            $this->setItemValue($file);
            $this->setItemValue( $path, '{Email}{SSLCaPath}' )
              if ($path);
        }
    }

    my $file = $this->getCfg;

    if ($file) {
        if ( -r $file ) {
            $reporter->NOTE( "File was last modified "
                  . ( scalar localtime( ( stat _ )[9] ) ) );
        }
        else {
            $reporter->ERROR("Unable to read $file");
        }
        if ( ( ( stat _ )[2] || 0 ) & 02 ) {
            $reporter->ERROR("$file is world-writable");
        }
    }
    my $path = $this->getCfg('{Email}{SSLCaPath}');
    if ( $path && !( -d $path && -r $path ) ) {
        $reporter->ERROR(
            -d $path ? "$path is not readable" : "$path is not a directory" );
    }
    
    if ( !( $file || $path ) ) {
        $reporter->ERROR(
"Either or both {Email}{SSLCrlFile} and {Email}{SSLCaPath} must be set for server verification.  CRLs are more dynamic than CA root certificates, and must be updated frequently to be useful.  Be sure that any method you choose satisfies your site's security policies.  Alternatively, your OS distribution may also provide a file or directory."
        );
    }
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
