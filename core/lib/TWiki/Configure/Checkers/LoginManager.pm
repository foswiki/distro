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
package TWiki::Configure::Checkers::LoginManager;

use strict;

use TWiki::Configure::Checker;

use base 'TWiki::Configure::Checker';

sub check {
    my $this = shift;
    my $e    = '';

    # Rename from old "Client" to new "LoginManager" - see Bugs:Item3375
    $TWiki::cfg{LoginManager} =~ s/::Client::/::LoginManager::/;
    if ( $TWiki::cfg{LoginManager} =~ /ApacheLogin$/
        && !$TWiki::cfg{UseClientSessions} )
    {
        $e .= $this->WARN(<<'HERE');
ApacheLogin uses the standard <code>REMOTE_USER</code>
environment variable to identify a previously logged in user. This
variable is only set if the script is authed by Apache. Thus if you
visit a page view using a script that is <i>not</i> authed (such as
<code>view</code>) then you will <i>appear</i> not to be logged in.
However you are, really, and as soon as you use a script that <i>is</i>
authed, your old identity will pop up again.
So you really need {UseClientSessions} enabled for a login to "stick".
HERE
    }
    if ( $TWiki::cfg{LoginManager} =~ /TemplateLogin$/
        && !$TWiki::cfg{UseClientSessions} )
    {
        $e .= $this->WARN(<<'HERE');
TemplateLogin needs some way to remember who you are, otherwise you
will have to log in every time you access an authenticated page. To avoid
this, you are recommended to turn {UseClientSessions} on.
HERE
    }
    return $e;
}

1;
