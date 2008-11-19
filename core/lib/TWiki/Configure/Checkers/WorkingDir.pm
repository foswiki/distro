#
# Foswiki - The Free Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2000-2006 TWiki Contributors.
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
package TWiki::Configure::Checkers::WorkingDir;
use base 'TWiki::Configure::Checker';

use strict;

sub check {
    my $this = shift;

    my $mess = $this->guessMajorDir( 'WorkingDir', 'working', 1 );
    $TWiki::cfg{WorkingDir} =~ s#[/\\]+$##;

    unless ( -d "$TWiki::cfg{WorkingDir}" ) {
        mkdir("$TWiki::cfg{WorkingDir}")
          || return $this->ERROR(
            "$TWiki::cfg{WorkingDir} does not exist, and I can't create it: $!"
          );
        $mess .= $this->NOTE("Created $TWiki::cfg{WorkingDir}");
    }

    unless ( -d "$TWiki::cfg{WorkingDir}/tmp" ) {
        if ( -e "$TWiki::cfg{WorkingDir}/tmp" ) {
            $mess .= $this->ERROR(
"$TWiki::cfg{WorkingDir}/tmp already exists, but is not a directory"
            );
        }
        elsif ( !mkdir( "$TWiki::cfg{WorkingDir}/tmp", '1777' ) ) {
            $mess .=
              $this->ERROR("Could not create $TWiki::cfg{WorkingDir}/tmp");
        }
        else {
            $mess .= $this->NOTE("Created $TWiki::cfg{WorkingDir}/tmp");
        }
    }

    unless ( -d "$TWiki::cfg{WorkingDir}/work_areas" ) {
        if ( -e "$TWiki::cfg{WorkingDir}/work_areas" ) {
            $mess .= $this->ERROR(
"$TWiki::cfg{WorkingDir}/work_areas already exists, but is not a directory"
            );
        }
        elsif ( !mkdir("$TWiki::cfg{WorkingDir}/work_areas") ) {
            $mess .= $this->ERROR(
                "Could not create $TWiki::cfg{WorkingDir}/work_areas");
        }
        else {
            $mess .= $this->NOTE("Created $TWiki::cfg{WorkingDir}/work_areas");
        }
    }

    # Automatic upgrade of work_areas
    my $existing = $TWiki::cfg{RCS}{WorkAreaDir} || '';
    $existing =~ s/\$TWiki::cfg({\w+})+/eval "$TWiki::cfg$1"/ge;
    if ( $existing && -d $existing ) {

        # Try and move the contents of the old workarea
        my $e =
          $this->copytree( $existing, "$TWiki::cfg{WorkingDir}/work_areas" );
        if ($e) {
            $mess .= $this->ERROR($e);
        }
        else {
            $mess .= $this->WARN( "
You have an existing {RCS}{WorkAreaDir} ($TWiki::cfg{RCS}{WorkAreaDir}),
so I have copied the contents of that directory into the new
$TWiki::cfg{WorkingDir}/work_areas. You should delete the old
$TWiki::cfg{RCS}{WorkAreaDir} when you are happy with
the upgrade." );
            delete( $TWiki::cfg{RCS}{WorkAreaDir} );
        }
    }

    unless ( -d "$TWiki::cfg{WorkingDir}/registration_approvals" ) {
        if ( -e "$TWiki::cfg{WorkingDir}/registration_approvals" ) {
            $mess .= $this->ERROR(
"$TWiki::cfg{WorkingDir}/registration_approvals already exists, but is not a directory"
            );
        }
        elsif ( !mkdir("$TWiki::cfg{WorkingDir}/registration_approvals") ) {
            $mess .= $this->ERROR(
"Could not create $TWiki::cfg{WorkingDir}/registration_approvals"
            );
        }
    }

    my $e = $this->checkTreePerms( $TWiki::cfg{WorkingDir}, 'rw' );
    $mess .= $this->ERROR($e) if $e;

    return $mess;
}

1;
