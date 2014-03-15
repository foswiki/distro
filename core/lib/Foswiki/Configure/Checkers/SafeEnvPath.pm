# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::SafeEnvPath;

use strict;
use warnings;

use Foswiki::Configure::Checker ();
use Scalar::Util qw( tainted );
our @ISA = ('Foswiki::Configure::Checker');

# Unix or Linux, Windows ActiveState Perl, using PERL5SHELL set to cygwin shell
#   path separator is :
#   ensure diff and shell (Bourne or bash type) are found on
#   path.
# Windows ActiveState Perl, using DOS shell
#   path separator is ;
#   The Windows system directory (e.g. c:\winnt\system32) is required.
#   Use '\' not '/' in pathnames.
# Windows Cygwin Perl
#   path separator is :
#   The Windows system directory (e.g. /cygdrive/c/winnt/system32) is required.
#   Use '/' not '\' in pathnames.
#
sub check {
    my $this = shift;

    my $check = '';
    my $pathSep = ( $Foswiki::cfg{DetailedOS} eq 'MSWin32' ) ? ';' : ':';

    # Make %ENV safer for CGI - Assign a safe default for SafeEnvPath
    if (  !$Foswiki::cfg{SafeEnvPath}
        || $Foswiki::cfg{SafeEnvPath} eq 'NOT SET'
        || $Foswiki::cfg{SafeEnvPath} eq 'undef' )
    {

        # Grab the current path
        if ( defined( $Foswiki::cfg{DETECTED}{originalPath} ) ) {
            $Foswiki::cfg{DETECTED}{originalPath} =~ /(.*)/;
            my $envPath = $1;

            my @safePath;
            foreach my $component ( split( /$pathSep/o, $envPath ) ) {
                next if ( tainted($component) );    # Tainted
                next if ( $component eq '.' );      # current directory insecure
                next if ( $component =~ /^~/ );     # Userdir insecure
                next
                  if ( $component =~ /^\.\.[\\\/]/ );   # relative path insecure
                push @safePath, $component;
            }
            $Foswiki::cfg{SafeEnvPath} = join( $pathSep, @safePath );
        }
        else {

            # Can't guess
            $Foswiki::cfg{SafeEnvPath} = '';
        }
    }

    return $this->WARN(
        "Unable to guess a value. You should set a value for this path.")
      unless ( $Foswiki::cfg{SafeEnvPath} );

    # First, get the proposed path
    my @dirs = ( split( /$pathSep/o, $Foswiki::cfg{SafeEnvPath} ) );

    # Check they exist
    my $found = 0;
    foreach my $dir (@dirs) {
        if ( -d $dir ) {
            $found++;
        }
        else {
            $check .= $this->WARN("$dir could not be found");
        }
    }
    if ( $Foswiki::cfg{DetailedOS} eq 'MSWin32' && !$found ) {
        $check .= $this->ERROR(
"None of the directories on the path could be found. This path will almost certainly not work on Windows. Normally the minimum acceptable {SafeEnvPath} is C:\\WINDOWS\\System32 (or the equivalent on your system)."
        );
    }

    return $check;
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
