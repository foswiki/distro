# See bottom of file for license and copyright information

package Foswiki::Configure::Checkers::Email::SSLCaFile;

use strict;
use warnings;

require Foswiki::Configure::Checker;
our @ISA = qw/Foswiki::Configure::Checker/;

sub check_current_value {
    my ($this, $reporter) = @_;

    return
      unless ( $Foswiki::cfg{Email}{MailMethod} =~ /^Net::SMTP/
        && $Foswiki::cfg{Email}{SSLVerifyServer} );

    my $value = $this->getCfg;

    unless ( $value || $Foswiki::cfg{Email}{SSLCaPath} ) {

        # See if we can use LWP or Crypt::SSLEay's defaults

        my ( $file, $path ) =
          @ENV{qw/PERL_LWP_SSL_CA_FILE PERL_LWP_SSL_CA_PATH/};
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
            $file = '' unless ( defined $file );
            $path = '' unless ( defined $path );
            $this->setItemValue($file);
            $this->setItemValue( $path, '{Email}{SSLCaPath}' );
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

    if (!( $file || $path ) ) {
        $reporter->ERROR(
"Either or both {Email}{SSLCaFile} and {Email}{SSLCaPath} must be set for server verification.  The CPAN module Mozilla::CA provides a convenient way to get a default file, but you should ensure that that it satisfies your site's security policies and that the sever that you use has a certificate issued by a Certificate Authority in the trust list.  Alternatively, your OS distribution may also provide a file or directory."
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
