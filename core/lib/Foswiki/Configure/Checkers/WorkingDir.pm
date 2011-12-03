# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::WorkingDir;

use strict;
use warnings;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

sub untaint {
    $_[0] =~ m/^(.*)$/;
    return $1;
}

sub check {
    my $this = shift;

    my $d = $this->getCfg("{WorkingDir}");
    my $mess = $this->guessMajorDir( 'WorkingDir', 'working', 1 );
    $Foswiki::cfg{WorkingDir} =~ s#[/\\]+$##;
    $d =~ s#[/\\]+$##;

    # SMELL:   In a suexec environment, umask is forced to 077, blocking
    # group and world access.  This is probably not bad for the working
    # directories.  But noting smell if mismatched permissions are questioned.

    #my $saveumask = umask();
    #umask ( oct(000));

    if ($mess) {
        $mess .= $this->NOTE(
'This directory will be created after the guessed settings are saved'
        ) unless ( -d $d );
        return $mess;    # guess will return message if a guess is made.
    }

    $mess .= $this->showExpandedValue( $Foswiki::cfg{WorkingDir} );

    unless ( -d $d ) {
        mkdir( untaint($d), oct(755) )
          || return $mess
          . $this->ERROR( "$d does not exist, and I can't create it: $!" );
        $mess .= $this->NOTE("Created $d");
    }

    unless ( -d "$d/tmp" ) {
        if ( -e "$d/tmp" ) {
            $mess .=
              $this->ERROR( "$d/tmp already exists, but is not a directory" );
        }
        elsif ( !mkdir( untaint("$d/tmp"), oct(1777) ) ) {
            $mess .= $this->ERROR("Could not create $d/tmp");
        }
        else {
            $mess .= $this->NOTE("Created $d/tmp");
        }
    }

    unless ( -d "$d/work_areas" ) {
        if ( -e "$d/work_areas" ) {
            $mess .= $this->ERROR(
                "$d/work_areas already exists, but is not a directory" );
        }
        elsif ( !mkdir( untaint("$d/work_areas"), oct(755) ) ) {
            $mess .= $this->ERROR("Could not create $d/work_areas");
        }
        else {
            $mess .= $this->NOTE("Created $d/work_areas");
        }
    }

    # Automatic upgrade of work_areas
    my $existing = $Foswiki::cfg{RCS}{WorkAreaDir} || '';
    $existing =~ s/\$Foswiki::cfg({\w+})+/eval "$Foswiki::cfg$1"/ge;
    if ( $existing && -d $existing ) {

        # Try and move the contents of the old workarea
        my $e = $this->copytree( untaint($existing), untaint("$d/work_areas") );
        if ($e) {
            $mess .= $this->ERROR($e);
        }
        else {
            $mess .= $this->WARN( "
You have an existing {RCS}{WorkAreaDir} ($Foswiki::cfg{RCS}{WorkAreaDir}),
so I have copied the contents of that directory into the new
$d/work_areas. You should delete the old
$Foswiki::cfg{RCS}{WorkAreaDir} when you are happy with
the upgrade." );
            delete( $Foswiki::cfg{RCS}{WorkAreaDir} );
        }
    }

    unless ( -d "$d/registration_approvals" ) {
        if ( -e "$d/registration_approvals" ) {
            $mess .= $this->ERROR(
"$d/registration_approvals already exists, but is not a directory"
            );
        }
        elsif ( !mkdir( untaint("$d/registration_approvals"), oct(755) ) ) {
            $mess .=
              $this->ERROR( "Could not create $d/registration_approvals" );
        }
    }

    #umask($saveumask);
    my $e = $this->checkTreePerms( $d, 'rw', qr/configure\/backup\/|README/ );
    $mess .= $this->ERROR($e) if $e;

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
