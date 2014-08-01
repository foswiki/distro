# See bottom of file for license and copyright information

package Foswiki::Configure::CGI;

use strict;
use warnings;

# This provides Configure's interface functions to CGI that aren't contained
# in CGI::.  Please keep it small & light, so the temptation to pull routines
# into other modules (the downfall of Configure::Util) is avoided.

use CGI;

use Exporter;
our @ISA    = qw/Exporter/;
our @EXPORT = qw/getScriptName/;

# This code's "fix" for Item 3511 (XP) creates the following problem:
# by returning just the script name: a web-browser will treat it as
# a relative path.  This can result in /bin/configure/configure/configure/...
# which is hardly a reasonable path_info.
#
# The original bug report seems to confuse SCRIPT_FILENAME with SCRIPT_NAME;
# there should not be a d:\ in SCRIPT_NAME on any OS.
#
# Applying File::Spec to a URI is also problematic.
#
# In addition, there have been several ad-hoc methods of obtaining the SCRIPT_NAME
# scattered thru configure.  Please use only this routine so any future issues
# can be addressed in ONE place.

sub getScriptName {

    #    my @script = File::Spec->splitdir( $ENV{SCRIPT_NAME} || 'THISSCRIPT' );
    #    my $scriptName = pop(@script);
    #    $scriptName =~ s/.*[\/\\]//;    # Fix for Item3511, on Win XP

    my $scriptName = CGI->script_name() || '/THISSCRIPT';

    return $scriptName;
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
