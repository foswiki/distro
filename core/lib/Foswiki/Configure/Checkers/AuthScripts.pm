# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::AuthScripts;

use strict;
use warnings;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

sub check {
    my $this = shift;
    my $msg  = '';

    if ( $Foswiki::cfg{AuthScripts} ) {
        if ( $Foswiki::cfg{LoginManager} eq 'none' ) {
            return $this->ERROR(
                <<'EOF'
You've asked that some scripts require authentication, but haven't
specified a way for users to log in. Please pick a LoginManager
other than 'none' or clear this setting.
EOF
            );
        }

        if ( $Foswiki::cfg{LoginManager} ne
            'Foswiki::LoginManager::TemplateLogin' )
        {
            $msg .= $this->WARN(
                <<"EOF"
You've specified an alternative login manager.  It is critical that this list
of scripts be consistent with the scripts protected by the Web Server.  Verify that this setting
is consistent with the Apache <code>FilesMatch</code> or <code>LocationMatch</code> or other
configuration used by $Foswiki::cfg{LoginManager}.
EOF
            );
        }

        unless ( $Foswiki::cfg{AuthScripts} =~ m/statistics/ ) {
            $msg .= $this->WARN(
                <<'EOF'
The statistics script is not protected as a script requiring authorization.
This is not a security issue, but this script can create a significant workload
on the server. It is recommended that this script require authentication.
EOF
            );
        }
    }
    my $e2 = _listOpenScripts( $this, $this->getCfg("{ScriptDir}") );
    $msg .= $this->NOTE(
'<b>Note:</b>The Following scripts are open to unauthenticated users:<br /> <code>'
          . $e2
          . '</code>' )
      if $e2;
    return $msg;
}

sub _listOpenScripts {
    my ( $this, $dir ) = @_;
    my $unauth = '';
    unless ( opendir( D, $dir ) ) {
        return $this->ERROR(<<HERE);
Cannot open '$dir' for read ($!) - check it exists, and that permissions are correct.
HERE
    }
    foreach
      my $script ( sort grep { -f "$dir/$_" && /^\w+(\.\w+)?$/ } readdir D )
    {

        #  Verify that scripts are executable
        if (   $script !~ /\.cfg$/
            && $script !~ /^configure/
            && $Foswiki::cfg{AuthScripts} !~ m/\b$script\b/ )
        {
            $unauth .= $script . ' ';
        }
    }
    closedir(D);
    return $unauth;
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
