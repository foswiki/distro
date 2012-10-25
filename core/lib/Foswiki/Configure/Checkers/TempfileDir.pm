# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::TempfileDir;

use strict;
use warnings;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

sub check {
    my $this = shift;
    my $e;

    my $tmpdir = $Foswiki::cfg{TempfileDir} || File::Spec->tmpdir();
    Foswiki::Configure::Load::expandValue($tmpdir);

    $e .= $this->NOTE("Temporary files will be written to: <tt>$tmpdir</tt>");

    my $msg;
    $msg .= "<li>Environment TMPDIR setting:  <tt>$ENV{TMPDIR}</tt></li>"
      if $ENV{TMPDIR};
    $msg .= "<li>Environment TEMP setting:  <tt>$ENV{TEMP}</tt></li>"
      if $ENV{TEMP};
    $msg .= "<li>Environment TMP setting:  <tt>$ENV{TMP}</tt></li>"
      if $ENV{TMP};
    $msg .=
'<li>Alternate Foswiki suggested location: <tt>$Foswiki::cfg{WorkingDir}/requestTmp</tt></li>';
    $msg .=
        "<li>Perl detected temporary file location: <tt>"
      . File::Spec->tmpdir()
      . "</tt></li></ul>";
    $e .= $this->NOTE("Other possible alternatives:<ul>$msg");

    if ( $tmpdir =~ /^[\/\\]$/ ) {
        $e .= $this->ERROR( <<MSG);
Temporary files will be written to system root directory, do you really want this?<br/>
I've updated the setting with a suggested alternative.<br/>
Save your configuration to make this active.
MSG
        $Foswiki::cfg{TempfileDir} = '$Foswiki::cfg{WorkingDir}/requestTmp';
    }

    $e .= $this->_checkTmpDir($tmpdir);

    return $e;
}

sub untaint {
    $_[0] =~ m/^(.*)$/;
    return $1;
}

sub _checkTmpDir {
    my ( $this, $dir ) = @_;
    my $mess = '';

    unless ( -d "$dir" ) {
        if ( -e "$dir" ) {
            print "NOT A DIRECTORY $dir <br/>";
            return $this->ERROR("$dir already exists, but is not a directory");
        }
        elsif ( !mkdir( untaint("$dir"), oct(1777) ) ) {
            print "DIDNT MAKE DIRECTORY $dir <br/>";
            return $this->ERROR("Could not create $dir");
        }
        else {
            print "CREATED DIRECTORY " . untaint("$dir") . " <br/>";
            $mess .= $this->NOTE("Created $dir");
        }
    }

    my $D;
    if ( !opendir( $D, $dir ) ) {
        return $this->ERROR(<<HERE);
Cannot open '$dir' for read ($!) - check that permissions are correct.
HERE
    }
    closedir($D);

    my $tmp = time();
    my $F;
    while ( -e "$dir/$tmp" ) {
        $tmp++;
    }
    $tmp = "$dir/$tmp";
    $tmp =~ /^(.*)$/;
    $tmp = $1;
    if ( !open( $F, '>', $tmp ) ) {
        return $this->ERROR(<<HERE);
Cannot create a file in '$dir' ($!) - check the directory exists, and that permissions are correct, and the filesystem is not full.
HERE
    }
    close($F);
    if ( !unlink($tmp) ) {
        return $this->ERROR(<<HERE);
Cannot unlink '$tmp' ($!) - check that permissions are correct on the directory.
HERE
    }
    return $mess;
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
