# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::WorkingDir;

use strict;
use warnings;

use Foswiki::Configure::Checkers::PATH ();
our @ISA = ('Foswiki::Configure::Checkers::PATH');

use Foswiki::Configure::FileUtil ();

sub check_current_value {
    my ( $this, $reporter ) = @_;

    my $d = $this->checkExpandedValue($reporter);
    return unless defined $d;

    if ( -d $d ) {
        my $path   = $d . '/' . time;
        my $report = Foswiki::Configure::FileUtil::checkCanCreateFile($path);
        if ($report) {
            $reporter->ERROR("Cannot write to this directory");
        }
    }
    elsif ( -e $d ) {
        $reporter->ERROR("Exists, but is not a directory");
    }
    else {
        $reporter->ERROR("Does not exist");
    }
}

sub commit_new_value {
    my ( $this, $reporter ) = @_;

    my $d = $this->{item}->getExpandedValue();

    # SMELL:   In a suexec environment, umask is forced to 077, blocking
    # group and world access.  This is probably not bad for the working
    # directories.  But noting smell if mismatched permissions are questioned.
    # ... Enabled the umask override.  Foswiki now writes a password file to
    # the working directory, and Apache cannot read it on suexec systems.

    my $saveumask = umask();
    umask( oct(000) );

    unless ( -d $d ) {
        mkdir( $d, oct(755) )
          || return $reporter->ERROR(
            "$d does not exist, and I can't create it: $!");
        $reporter->NOTE("Created $d");
    }

    unless ( -d "$d/tmp" ) {
        if ( -e "$d/tmp" ) {
            $reporter->ERROR("$d/tmp already exists, but is not a directory");
        }
        elsif ( !mkdir( "$d/tmp", oct(1777) ) ) {
            $reporter->ERROR("Could not create $d/tmp");
        }
        else {
            $reporter->NOTE("Created $d/tmp");
        }
    }

    unless ( -d "$d/work_areas" ) {
        if ( -e "$d/work_areas" ) {
            $reporter->ERROR(
                "$d/work_areas already exists, but is not a directory");
        }
        elsif ( !mkdir( "$d/work_areas", oct(755) ) ) {
            $reporter->ERROR("Could not create $d/work_areas");
        }
        else {
            $reporter->NOTE("Created $d/work_areas");
        }
    }

    # Automatic upgrade of work_areas
    my $existing = $Foswiki::cfg{Store}{WorkAreaDir} || '';
    $existing =~ s/\$Foswiki::cfg({\w+})+/eval( "$Foswiki::cfg$1")/ge;
    if ( $existing && -d $existing ) {

        # Try and move the contents of the old workarea
        my @report =
          Foswiki::Configure::FileUtil::copytree( $existing, "$d/work_areas" );
        if (@report) {
            $reporter->ERROR(@report);
        }
        else {
            $reporter->WARN( "
You have an existing {Store}{WorkAreaDir} ($Foswiki::cfg{Store}{WorkAreaDir}),
so I have copied the contents of that directory into the new
$d/work_areas. You should delete the old
$Foswiki::cfg{Store}{WorkAreaDir} when you are happy with
the upgrade." );
            delete( $Foswiki::cfg{Store}{WorkAreaDir} );
        }
    }

    unless ( -d "$d/registration_approvals" ) {
        if ( -e "$d/registration_approvals" ) {
            $reporter->ERROR(
"$d/registration_approvals already exists, but is not a directory"
            );
        }
        elsif ( !mkdir( "$d/registration_approvals", oct(755) ) ) {
            $reporter->ERROR("Could not create $d/registration_approvals");
        }
    }

    umask($saveumask);

    my $report = Foswiki::Configure::FileUtil::checkTreePerms( $d, 'rw',
        filter => qr/configure\/backup\/|README/ );
    $reporter->ERROR( @{ $report->{messages} } );
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2014 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
