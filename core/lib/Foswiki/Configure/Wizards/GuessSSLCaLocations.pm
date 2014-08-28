# See bottom of file for license and copyright information
package Foswiki::Configure::Wizards::GuessSSLCaLocations;

=begin TML

---++ package Foswiki::Configure::Wizards::GuessSSLCaLocations

Wizard to guess the locations of SSL Certificate files.

=cut

use strict;
use warnings;

use Foswiki::Configure::Wizard ();
our @ISA = ('Foswiki::Configure::Wizard');

# WIZARD
sub guess {
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
        return 1;
    }
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
