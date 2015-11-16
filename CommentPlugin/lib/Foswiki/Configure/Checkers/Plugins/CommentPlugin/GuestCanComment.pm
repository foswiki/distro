# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::Plugins::CommentPlugin::GuestCanComment;

use strict;
use warnings;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

sub check {
    my $this = shift;
    my $msg  = '';

    if ( $Foswiki::cfg{Plugins}{CommentPlugin}{GuestCanComment} ) {

        # Enabled,  need to ensure rest is not auth.
        if ( $Foswiki::cfg{AuthScripts} =~ m/\brest\b/ ) {
            $msg .= $this->WARN(
                <<'EOF'
The <tt>rest</tt> script is protected as requiring authorization.  Commenting
by guests will not be possible.
EOF
            );
        }
        if (  !$Foswiki::cfg{Sessions}{EnableGuestSessions}
            && $Foswiki::VERSION > 2.0.0 )
        {
            $msg .= $this->WARN(
                <<'EOF'
Guest sessions should be enabled so that Foswiki validation can be performed.
The StrikeOne key is stored in the session.
EOF
            );
        }
    }
    else {

  # Disabled,  need to ensure restauth is protected, and a login manager is set.
        if ( $Foswiki::cfg{LoginManager} eq 'none' ) {
            return $this->ERROR(
                <<'EOF'
You've asked that some guest be prevented from commenting, but haven't
specified a way for users to log in. Please pick a LoginManager
other than 'none' or clear this setting.
EOF
            );
        }
        unless ( $Foswiki::cfg{AuthScripts} =~ m/\brestauth\b/ ) {
            $msg .= $this->ERROR(
                <<'EOF'
The <tt>restauth</tt> script is not protected.  This could permit commenting
by unauthorized users. Please add <tt>restauth</tt> to the <tt>{AuthScripts}</tt> list!
EOF
            );
        }
    }

    return $msg;
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
