# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::WorkingDir;
use base 'Foswiki::Configure::Checker';

use strict;

sub check {
    my $this = shift;

    my $mess = $this->guessMajorDir( 'WorkingDir', 'working', 1 );
    $Foswiki::cfg{WorkingDir} =~ s#[/\\]+$##;

    unless ( -d "$Foswiki::cfg{WorkingDir}" ) {
        mkdir("$Foswiki::cfg{WorkingDir}")
          || return $this->ERROR(
            "$Foswiki::cfg{WorkingDir} does not exist, and I can't create it: $!"
          );
        $mess .= $this->NOTE("Created $Foswiki::cfg{WorkingDir}");
    }

    unless ( -d "$Foswiki::cfg{WorkingDir}/tmp" ) {
        if ( -e "$Foswiki::cfg{WorkingDir}/tmp" ) {
            $mess .= $this->ERROR(
"$Foswiki::cfg{WorkingDir}/tmp already exists, but is not a directory"
            );
        }
        elsif ( !mkdir( "$Foswiki::cfg{WorkingDir}/tmp", '1777' ) ) {
            $mess .=
              $this->ERROR("Could not create $Foswiki::cfg{WorkingDir}/tmp");
        }
        else {
            $mess .= $this->NOTE("Created $Foswiki::cfg{WorkingDir}/tmp");
        }
    }

    unless ( -d "$Foswiki::cfg{WorkingDir}/work_areas" ) {
        if ( -e "$Foswiki::cfg{WorkingDir}/work_areas" ) {
            $mess .= $this->ERROR(
"$Foswiki::cfg{WorkingDir}/work_areas already exists, but is not a directory"
            );
        }
        elsif ( !mkdir("$Foswiki::cfg{WorkingDir}/work_areas") ) {
            $mess .= $this->ERROR(
                "Could not create $Foswiki::cfg{WorkingDir}/work_areas");
        }
        else {
            $mess .= $this->NOTE("Created $Foswiki::cfg{WorkingDir}/work_areas");
        }
    }

    # Automatic upgrade of work_areas
    my $existing = $Foswiki::cfg{RCS}{WorkAreaDir} || '';
    $existing =~ s/\$Foswiki::cfg({\w+})+/eval "$Foswiki::cfg$1"/ge;
    if ( $existing && -d $existing ) {

        # Try and move the contents of the old workarea
        my $e =
          $this->copytree( $existing, "$Foswiki::cfg{WorkingDir}/work_areas" );
        if ($e) {
            $mess .= $this->ERROR($e);
        }
        else {
            $mess .= $this->WARN( "
You have an existing {RCS}{WorkAreaDir} ($Foswiki::cfg{RCS}{WorkAreaDir}),
so I have copied the contents of that directory into the new
$Foswiki::cfg{WorkingDir}/work_areas. You should delete the old
$Foswiki::cfg{RCS}{WorkAreaDir} when you are happy with
the upgrade." );
            delete( $Foswiki::cfg{RCS}{WorkAreaDir} );
        }
    }

    unless ( -d "$Foswiki::cfg{WorkingDir}/registration_approvals" ) {
        if ( -e "$Foswiki::cfg{WorkingDir}/registration_approvals" ) {
            $mess .= $this->ERROR(
"$Foswiki::cfg{WorkingDir}/registration_approvals already exists, but is not a directory"
            );
        }
        elsif ( !mkdir("$Foswiki::cfg{WorkingDir}/registration_approvals") ) {
            $mess .= $this->ERROR(
"Could not create $Foswiki::cfg{WorkingDir}/registration_approvals"
            );
        }
    }

    my $e = $this->checkTreePerms( $Foswiki::cfg{WorkingDir}, 'rw' );
    $mess .= $this->ERROR($e) if $e;

    return $mess;
}

1;
__DATA__
#
# Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008 Foswiki Contributors. All Rights Reserved.
# Foswiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
#
# Copyright (C) 2000-2006 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.
