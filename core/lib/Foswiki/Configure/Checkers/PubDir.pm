# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::PubDir;

use strict;
use warnings;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

sub check {
    my $this = shift;

    $this->{filecount}  = 0;
    $this->{fileErrors} = 0;
    $this->{excessPerms} = 0;
    my $e = $this->guessMajorDir( 'PubDir', 'pub' );

    $e .= $this->NOTE(<<MISSING
If PubDir is missing, your ScriptDir is probably not located in the Foswiki
installation directory.  All directory locations are guessed relative to the
ScriptDir location. (<code>$Foswiki::cfg{ScriptDir}</code>)  Carefully review all of the Directory settings, especially
the WorkingDir, which will be created in the guessed location after the settings are saved.
MISSING
) if ($e =~ m/Error/);

    $e .= $this->showExpandedValue($Foswiki::cfg{PubDir});

    my $d = $this->getCfg('{PubDir}');
    $e .= $this->warnAboutWindowsBackSlashes( $d );

    # Don't check directories against {RCS} permissions on Windows
    my $dirchk =
      ( $Foswiki::cfg{OS} eq 'WINDOWS' )
      ? ''
      : 'd';

    # rwd - Readable,  Writable, and directory must match {RCS}{dirPermission}
    my $e2 =
      $this->checkTreePerms( $d, 'rw' . $dirchk, qr/,v$/ );

    $e .=
      ( $this->{filecount} >= $Foswiki::cfg{PathCheckLimit} )
      ? $this->NOTE(
"File checking limit $Foswiki::cfg{PathCheckLimit} reached, checking stopped - see expert options"
      )
      : $this->NOTE("File count: $this->{filecount} ");

    my $dperm = sprintf( '%04o', $Foswiki::cfg{RCS}{dirPermission} );
    my $fperm = sprintf( '%04o', $Foswiki::cfg{RCS}{filePermission} );

    my $singularOrPlural = $this->{fileErrors} == 1 ? "$this->{fileErrors} directory or file has insufficient permissions." : "$this->{fileErrors} directories or files have insufficient permissions.";
    
    if ( $this->{fileErrors} ) {
        $e .= $this->ERROR(<<ERRMSG)
$singularOrPlural Insufficient permissions
could prevent Foswiki or the web server from accessing or updating the files.
Verify that the Store expert settings of {RCS}{filePermission} ($fperm) and {RCS}{dirPermission} ($dperm)
are set correctly for your environment and correct the file permissions listed below.
ERRMSG
    }

    if ( $this->{excessPerms}) {
        $e .= $this->WARN(<<PERMS);
$this->{excessPerms} or more directories appear to have more access permission than requested in the Store configuration.
Excess permissions might allow other users on the web server to have undesired access to the files.
Verify that the Store expert settings of {RCS}{filePermission} ($fperm} and {RCS}{dirPermission}) ($dperm})
are set correctly for your environment and correct the file permissions listed below.  (Files are not checked for
excessive permissions in this release).
PERMS
    }

    $e .= $this->NOTE('<b>First 10 detected errors of inconsistent permissions</b> <br/> ' . $e2 ) if $e2;

    $this->{filecount}  = 0;
    $this->{fileErrors} = 0;

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
