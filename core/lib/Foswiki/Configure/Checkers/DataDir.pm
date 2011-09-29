# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::DataDir;

use strict;
use warnings;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

sub check {
    my $this = shift;

    $this->{filecount}  = 0;
    $this->{fileErrors} = 0;
    $this->{excessPerms} = 0;
    $this->{missingFile} = 0;

    my $e = $this->guessMajorDir( 'DataDir', 'data' );
    
    # Don't check directories against {RCS} permissions on Windows
    my $dirchk =
      ( $Foswiki::cfg{OS} eq 'WINDOWS' )
      ? ''
      : 'd';

    # Check r-readable, w-writable and d-directories match {RCS}{dirPermissions} and p-WebPreferences topic exists.
    my $d = $this->getCfg('{DataDir}');
    my $e2 =
      $this->checkTreePerms( $d, 'rwp' . $dirchk, qr/,v$/ );
    $e .= $this->warnAboutWindowsBackSlashes( $Foswiki::cfg{DataDir} );
    $e .=
      ( $this->{filecount} >= $Foswiki::cfg{PathCheckLimit} )
      ? $this->NOTE(
"File checking limit $Foswiki::cfg{PathCheckLimit} reached, checking stopped - see expert options"
      )
      : $this->NOTE("File count: $this->{filecount} ");

    # Also check that all rcs files are readable
    $e2 .= $this->checkTreePerms( $d, "r", qr/\.txt$/ );

    my $dperm = sprintf( '%04o', $Foswiki::cfg{RCS}{dirPermission} );
    my $fperm = sprintf( '%04o', $Foswiki::cfg{RCS}{filePermission} );

    if ( $this->{fileErrors} ) {
        my $singularOrPlural = $this->{fileErrors} == 1 ? "$this->{fileErrors} directory or file has insufficient permissions." : "$this->{fileErrors} directories or files have insufficient permissions.";
        $e .= $this->ERROR(<<ERRMSG)
$singularOrPlural Insufficient permissions
could prevent Foswiki or the web server from accessing or updating the files.
Verify that the Store expert settings of {RCS}{filePermission} ($fperm) and {RCS}{dirPermission} ($dperm)
are set correctly for your environment and correct the file permissions listed below.
ERRMSG
    }

    if ( $this->{missingFile} ) {
    my $singularOrPlural = $this->{missingFile} == 1 ? "$this->{missingFile} file is missing." : "$this->{missingFile} files are missing.";
        $e .= $this->WARN(<<PREFS)
This warning can be safely ignored in many cases.  The web directories have been checked for a $Foswiki::cfg{WebPrefsTopicName} topic and $singularOrPlural
If this file is missing, Foswiki will not recognize the directory as a Web and the contents will not be 
accessible to Foswiki.  This is expected with some extensions and might not be a problem. <br /><br />Verify whether or not each directory listed as missing $Foswiki::cfg{WebPrefsTopicName} is
intended to be a web.  If Foswiki web access is desired, copy in a $Foswiki::cfg{WebPrefsTopicName} topic.
PREFS
    }

    if ( $this->{excessPerms}) {
        $e .= $this->WARN(<<PERMS);
$this->{excessPerms} or more directories appear to have more access permission than requested in the Store configuration.
Excess permissions might allow other users on the web server to have undesired access to the files.
Verify that the Store expert settings of {RCS}{filePermission} ($fperm} and {RCS}{dirPermission}) ($dperm})
are set correctly for your environment and correct the file permissions listed below. (Files are not checked
for excessive permissions in this release).
PERMS
    }

    $e .= $this->NOTE('<b>First 10 detected errors of inconsistent permissions, and all instances of missing files.</b> <br/> ' . $e2 ) if $e2;

    $this->{filecount}  = 0;
    $this->{fileErrors} = 0;
    $this->{missingFile} = 0;
    $this->{excessPerms} = 0;

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
