# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::LoginManager;

use strict;
use warnings;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

sub check_current_value {
    my ( $this, $reporter ) = @_;

    # Rename from old "Client" to new "LoginManager" - see Bugs:Item3375
    $Foswiki::cfg{LoginManager} =~ s/::Client::/::LoginManager::/;
    if ( $Foswiki::cfg{LoginManager} =~ m/ApacheLogin$/
        && !$Foswiki::cfg{UseClientSessions} )
    {
        $reporter->WARN(<<'HERE');
ApacheLogin uses the standard =REMOTE_USER=
environment variable to identify a previously logged in user. This
variable is only set if the script is authed by Apache. Thus if you
visit a page view using a script that is _not_ authed (such as
=view=) then you will <i>appear</i> not to be logged in.
However you are, really, and as soon as you use a script that <i>is</i>
authed, your old identity will pop up again.
So you really need {UseClientSessions} enabled for a login to "stick".
HERE
    }
    if ( $Foswiki::cfg{LoginManager} =~ m/TemplateLogin$/
        && !$Foswiki::cfg{UseClientSessions} )
    {
        $reporter->WARN(<<'HERE');
TemplateLogin needs some way to remember who you are, otherwise you
will have to log in every time you access an authenticated page. To avoid
this, you are recommended to turn {UseClientSessions} on.
HERE
    }
    if ( $Foswiki::cfg{LoginManager} =~ m/ApacheLogin$/
        && ( $Foswiki::cfg{Htpasswd}{Encoding} eq 'md5' ) )
    {
        $reporter->WARN(<<'HERE');
Combining ApacheLogin and md5 password encoding requires the foswiki 
Authentication settings in the web server setup to be set to use Digest mode.
This also requires the AuthName setting in the webserver 
configuration to be the same as the foswiki AuthRealm setting.
HERE
    }

    if ( $Foswiki::cfg{LoginManager} eq 'none' ) {
        $reporter->WARN(<<'HERE');
With LoginManager set to 'none', this wiki is completely unprotected.
Anyone can edit any topic, and anyone will be able to access the configure tool.
This option should be enabled only on personal wikis with restricted access.
HERE
    }
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
