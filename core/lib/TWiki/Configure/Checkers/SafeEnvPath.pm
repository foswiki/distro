# TWiki Enterprise Collaboration Platform, http://TWiki.org/
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
package TWiki::Configure::Checkers::SafeEnvPath;
use base 'TWiki::Configure::Checker';

use strict;

use TWiki::Configure::Checker;

# Unix or Linux, Windows ActiveState Perl, using PERL5SHELL set to cygwin shell
#   path separator is :
#   ensure diff and shell (Bourne or bash type) are found on
#   path.
# Windows ActiveState Perl, using DOS shell
#   path separator is ;
#   The Windows system directory (e.g. c:\winnt\system32) is required.
#   Use '\' not '/' in pathnames.
# Windows Cygwin Perl
#   path separator is :
#   The Windows system directory (e.g. /cygdrive/c/winnt/system32) is required.
#   Use '/' not '\' in pathnames.
#
sub check {
    my $this = shift;

    unless( $TWiki::cfg{SafeEnvPath} ) {
        return $this->WARN("You should set a value for this path.");
    }

    my $check = '';

    # First, get the proposed path
    my @dirs;
    if ($TWiki::cfg{DetailedOS} eq 'MSWin32') {
        # Active State perl, probably. Need DOS paths.
        @dirs = split(';', $TWiki::cfg{SafeEnvPath});
    } else {
        @dirs = split(':', $TWiki::cfg{SafeEnvPath});
    }
    # Check they exist
    my $found = 0;
    foreach my $dir (@dirs) {
        if (-d $dir) {
            $found++;
        } else {
            $check .= $this->WARN("$dir could not be found");
        }
    }
    if ($TWiki::cfg{DetailedOS} eq 'MSWin32' && !$found) {
        $check .= $this->ERROR("None of the directories on the path could be found. This path will almost certainly not work on Windows. Normally the minimum acceptable {SafeEnvPath} is C:\\WINDOWS\\System32 (or the equivalent on your system).");
    }

    return $check;
}

1;
