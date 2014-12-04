# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::PATH;

# Default checker for PATH items
#
# CHECK options in spec file
#  CHECK="option option:val option:val,val,val"
#
#    perms:code - validate tree permissions using code (default is no check)
#                 See Foswiki::Configure::FileUtil::checkTreePerms (current codes: rwxdfp)
#                 Checked here:
#                  F - Must exist and be a file (not a directory)
#                  D - Must exist and be a directory (not a file)
#
#    accept:regex* - Files to include.
#    filter:regex* - Files to exclude.
#
# Use this checker if possible; otherwise subclass the item-specific checker from it.

use strict;
use warnings;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

use Foswiki::Configure::FileUtil ();

sub check_current_value {
    my ( $this, $reporter ) = @_;

    $this->showExpandedValue($reporter);

    my $path = $this->{item}->getExpandedValue();
    if ( !defined $path ) {
        my $check = $this->{item}->{CHECK}->[0];
        unless ( $check && $check->{nullok}[0] ) {
            $reporter->ERROR("A value must be given (may not be undefined)");
        }
        return;
    }

    foreach my $check ( @{ $this->{item}->{CHECK} } ) {
        my $perms = $check->{perms};

        next unless ($perms);
        $perms = $perms->[0];

        if ( $perms =~ /F/ && !-f $path ) {
            if ( -d $path ) {
                $reporter->ERROR(
                    "Value must be an existing file (not a directory)");
            }
            elsif ( -e $path ) {
                $reporter->ERROR("$path is not a file");
            }
            else {
                $reporter->ERROR("$path does not exist");
            }
        }

        if ( $perms =~ /D/ && !-d $path ) {
            if ( -f $path ) {
                $reporter->ERROR(
                    "Value must be an existing directory (not a file)");
            }
            elsif ( -e $path ) {
                $reporter->ERROR("$path is not a directory");
            }
            else {
                $reporter->ERROR("$path does not exist");
            }
        }
    }

    if ( $path =~ /\\/ ) {
        $reporter->WARN('You should use c:/path style slashes, not c:\path');
    }
}

sub validate_permissions {
    my ( $this, $reporter ) = @_;

    my $path = eval "\$Foswiki::cfg$this->{item}->{keys}";

    my $fileCount   = 0;
    my $fileErrors  = 0;
    my $excessPerms = 0;
    my $missingFile = 0;
    my @messages;

    foreach my $check ( @{ $this->{item}->{CHECK} } ) {
        my $perms  = $check->{perms};
        my $filter = $check->{filter}[0];

        if ($perms) {
            my $checkPerms = $perms->[0];
            $checkPerms =~ s/d//g if ( $Foswiki::cfg{OS} eq 'WINDOWS' );

            if ( $checkPerms =~ /F/ && !-f $path ) {
                return $reporter->ERROR("$path is not a plain file");
            }
            if ( $checkPerms =~ /D/ && !-d $path ) {
                return $reporter->ERROR("$path is not a directory");
            }

            my $report =
              Foswiki::Configure::FileUtil::checkTreePerms( $path, $checkPerms,
                filter => $filter );
            $fileCount   += $report->{fileCount};
            $fileErrors  += $report->{fileErrors};
            $excessPerms += $report->{excessPerms};
            $missingFile += $report->{missingFile};
            push( @messages, @{ $report->{messages} } );
        }
    }

    my $dperm = sprintf( '%04o', $Foswiki::cfg{Store}{dirPermission} );
    my $fperm = sprintf( '%04o', $Foswiki::cfg{Store}{filePermission} );

    if ($fileErrors) {
        my $insufficientMsg =
          $fileErrors == 1
          ? "a directory or file has insufficient permissions."
          : "$fileErrors directories or files have insufficient permissions.";

        $reporter->ERROR( <<ERRMSG, @messages )
$insufficientMsg Insufficient permissions could prevent Foswiki or the web server from accessing or updating the files. Verify that the Store expert settings of {Store}{filePermission} ($fperm) and {Store}{dirPermission} ($dperm) are correct for your environment, and correct the file permissions listed below.
ERRMSG
    }

    if ( $this->{missingFile} ) {
        my $missingMsg =
          $this->{missingFile} == 1
          ? "a file is missing."
          : "$this->{missingFile} files are missing.";
        $reporter->WARN( <<PREFS, @messages )
This warning can be safely ignored in many cases. The web directories have been checked for a $Foswiki::cfg{WebPrefsTopicName} topic and $missingMsg If this file is missing, Foswiki will not recognize the directory as a Web and the contents will not be accessible to Foswiki.  This is expected with some extensions and might not be a problem. Verify whether or not each directory listed as missing $Foswiki::cfg{WebPrefsTopicName} is intended to be a web.  If Foswiki web access is desired, copy in a $Foswiki::cfg{WebPrefsTopicName} topic.
PREFS
    }

    if ($excessPerms) {
        $reporter->WARN( << "PERMS", @messages );
$excessPerms or more directories appear to have more access permission than requested in the Store configuration. Excess permissions might allow other users on the web server to have undesired access to the files. Verify that the Store expert settings of {Store}{filePermission} ($fperm} and {Store}{dirPermission}) ($dperm}) are set correctly for your environment and correct the file permissions listed below.  (Files were not checked for excessive permissions.)
PERMS
    }
    $reporter->NOTE("Finished checking $fileCount files");
    return;
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
