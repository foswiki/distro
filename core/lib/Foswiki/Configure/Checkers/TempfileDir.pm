# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::TempfileDir;

use strict;
use warnings;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

sub check_current_value {
    my ( $this, $reporter ) = @_;
    my $e;

    my $tmpdir = $Foswiki::cfg{TempfileDir};
    Foswiki::Configure::Load::expandValue($tmpdir);

    unless ($tmpdir) {
        File::Spec->tmpdir() =~ m/^(.*)$/;
        $tmpdir = $1;    # untaint

        $reporter->WARN( '{TempfileDir} is not set (or is set to nothing).'
              . " Temporary files will be written to: =$tmpdir=" );

        $reporter->NOTE("Other possible alternatives:");
        $reporter->NOTE("   * Environment TMPDIR setting: =$ENV{TMPDIR}=")
          if $ENV{TMPDIR};
        $reporter->NOTE("   * Environment TEMP setting: =$ENV{TEMP}=\n")
          if $ENV{TEMP};
        $reporter->NOTE("   * Environment TMP setting: =$ENV{TMP}=\n")
          if $ENV{TMP};
        $reporter->NOTE(
"   * Alternate Foswiki suggested location: =$Foswiki::cfg{WorkingDir}/requestTmp=\n"
        );
        $reporter->NOTE( "   * Perl detected temporary file location: ="
              . File::Spec->tmpdir()
              . "=" );
    }

    if ( $tmpdir =~ m/^[\/\\]$/ ) {
        $reporter->ERROR( <<MSG);
Temporary files may not be written to the system root directory.
MSG
    }

    unless ( -d $tmpdir ) {
        if ( -e $tmpdir ) {
            return $reporter->ERROR(
                "$tmpdir already exists, but is not a directory");
        }
        elsif ( !mkdir( $tmpdir, oct(1777) ) ) {
            return $reporter->ERROR("Could not create $tmpdir");
        }
        else {
            $reporter->NOTE("Created $tmpdir");
        }
    }

    my $D;
    if ( !opendir( $D, $tmpdir ) ) {
        $reporter->ERROR(<<HERE);
Cannot open $tmpdir for read ($!) - check that permissions are correct.
HERE
        return;
    }
    closedir($D);

    my $tmp = time();
    while ( -e "$tmpdir/$tmp" ) {
        $tmp++;
    }
    $tmp = "$tmpdir/$tmp";
    $tmp =~ m/^(.*)$/;
    $tmp = $1;

    my $F;
    if ( open( $F, '>', $tmp ) ) {
        close($F);
        if ( !unlink($tmp) ) {
            $reporter->ERROR(<<HERE);
Cannot unlink '$tmp' ($!) - check that permissions are correct on the directory.
HERE
        }
    }
    else {
        $reporter->ERROR(<<HERE);
Cannot create a $tmp file in '$tmpdir' ($!) - check the directory exists, and that permissions are correct, and the filesystem is not full.
HERE
    }
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2014 Foswiki Contributors. Foswiki Contributors
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
