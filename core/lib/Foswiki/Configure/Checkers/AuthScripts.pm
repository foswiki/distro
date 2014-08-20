# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::AuthScripts;

use strict;
use warnings;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

sub check_current_value {
    my ($this, $reporter) = @_;
    my $msg  = '';

    if ( $Foswiki::cfg{AuthScripts} ) {
        if ( $Foswiki::cfg{LoginManager} eq 'none' ) {
            return $reporter->ERROR(<<'EOF');
You've asked that some scripts require authentication, but haven't
specified a way for users to log in. Please pick a LoginManager
other than 'none' or clear this setting.
EOF
        }

        if ( $Foswiki::cfg{LoginManager} ne
            'Foswiki::LoginManager::TemplateLogin' )
        {
            $reporter->WARN(<<'EOF');
You have specified an alternative (non-TemplateLogin) login manager.
It is critical that this list of scripts be consistent with the scripts
protected by the Web Server. For example, if you are using Apache then
verify that this setting is consistent with the =FilesMatch= or
=LocationMatch= directive that requires a valid user for the scripts.
EOF
        }

        unless ( $Foswiki::cfg{AuthScripts} =~ m/statistics/ ) {
            $msg .= $reporter->WARN(<<'EOF');
The statistics script is not listed as a script requiring authorization.
This is not a security issue, but this script can create a significant workload
on the server. It is recommended that this script require authentication.
EOF
        }
    }

    my $dir = $Foswiki::cfg{ScriptDir};
    Foswiki::Configure::Load::expandValue($dir);

    my $unauth = '';
    unless ( opendir( D, $dir ) ) {
        return $reporter->ERROR(<<HERE);
Cannot open {ScriptDir} '$dir' for read ($!) - check it exists, and
that permissions are correct.
HERE
    }
    foreach
      my $script ( sort grep { -f "$dir/$_" && /^\w+(\.\w+)?$/ } readdir D )
    {

        #  Verify that scripts are executable
        if (   $script !~ /\.cfg$/
            && $script !~ /^login/
            && $script !~ /^logon/
            && $script !~ /^configure/
            && $Foswiki::cfg{AuthScripts} !~ m/\b$script\b/ )
        {

            #use commas so users can 'just cut and paste'
            $unauth .= ', ' if ( $unauth ne '' );
            $unauth .= $script;
        }
    }
    closedir(D);

    $reporter->NOTE(
"The following scripts can be run by unauthenticated users: =$unauth=" )
      if $unauth;

    if ( $unauth =~ m/auth\b/ ) {
        $reporter->ERROR(
            <<"EOF"
There are one or more *auth scripts found in $Foswiki::cfg{ScriptDir} that are missing
from ={AuthScripts}=.  For best security,
any script ending in "auth" should be included in the list of ={AuthScripts}=.
EOF
        );
    }
}

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
