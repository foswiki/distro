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
    my $e = $this->guessMajorDir( 'PubDir', 'pub' );
    $e .= $this->warnAboutWindowsBackSlashes( $Foswiki::cfg{PubDir} );

    # Don't check directories against {RCS} permissions on Windows
    my $dirchk =
      ( $Foswiki::cfg{OS} eq 'WINDOWS' )
      ? ''
      : 'd';

    # rwd - Readable,  Writable, and directory must match {RCS}{dirPermission}
    my $e2 =
      $this->checkTreePerms( $Foswiki::cfg{PubDir}, 'rw' . $dirchk, qr/,v$/ );
    $e .= $this->WARN($e2) if $e2;

    if ( $this->{fileErrors} > 10 ) {
        $e .= $this->ERROR(<<ERRMSG)
File/Directory permission mismatch reporting stopped at 10 warnings. 
$this->{fileErrors} directories or files have mismatched permissions. 
Verify that the Store expert settings of {RCS}{filePermission} and {RCS}{dirPermission}
are set correctly for your environment and correct file system permissions if necessary.
ERRMSG
    }

    $e .=
      ( $this->{filecount} >= $Foswiki::cfg{PathCheckLimit} )
      ? $this->NOTE(
"File checking limit $Foswiki::cfg{PathCheckLimit} reached, checking stopped - see expert options"
      )
      : $this->NOTE("File count - $this->{filecount} ");

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
