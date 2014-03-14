# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::LoginManager::ApacheLogin

This is login manager that you can specify in the security setup section of
[[%SCRIPTURL{"configure"}%][configure]]. It instructs Foswiki to
cooperate with your web server (typically Apache) to require authentication
information (username & password) from users. It requires that you configure
your web server to demand authentication for scripts named "login" and anything
ending in "auth". The latter should be symlinks to existing scripts; e.g.,
=viewauth -> view=, =editauth -> edit=, and so on.

See also UserAuthentication.

Subclass of Foswiki::LoginManager; see that class for documentation of the
methods of this class.

=cut

package Foswiki::LoginManager::ApacheLogin;

use strict;
use warnings;
use Assert;

use Foswiki::LoginManager ();
our @ISA = ('Foswiki::LoginManager');

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

=begin TML

---++ ClassMethod new ($session)

Construct the ApacheLogin object

=cut

sub new {
    my ( $class, $session ) = @_;
    my $this = $class->SUPER::new($session);

    $session->enterContext('can_login');

    # Can't logout, though
    Foswiki::registerTagHandler( 'LOGOUT', sub { return '' } );
    return $this;
}

=begin TML

---++ ObjectMethod forceAuthentication () -> boolean

method called when authentication is required - redirects to (...|view)auth
Triggered on auth fail

=cut

sub forceAuthentication {
    my $this    = shift;
    my $session = $this->{session};
    my $query   = $session->{request};

    # See if there is an 'auth' version
    # of this script, may be a result of not being logged in.
    my $newAction = $query->action() . 'auth';

    if ( !$query->remote_user()
        && exists $Foswiki::cfg{SwitchBoard}{$newAction} )
    {

        # Assemble the new URL using the host, the changed script name,
        # and the path info.
        my $url = $session->getScriptUrl( 1, $newAction );
        if ( $query->path_info() ) {
            $url .= '/'
              unless $url =~ m#/$# || $query->path_info() =~ m#^/#;
            $url .= $query->path_info();
        }

        # Redirect with passthrough so we don't lose the original query params
        $session->redirect( $url, 1 );
        return 1;
    }
    return 0;
}

=begin TML

---++ ObjectMethod loginUrl () -> $loginUrl

TODO: why is this not used internally? When is it called, and why
Content of a login link

=cut

sub loginUrl {
    my $this    = shift;
    my $session = $this->{session};
    my $topic   = $session->{topicName};
    my $web     = $session->{webName};
    return $session->getScriptUrl( 0, 'logon', $web, $topic, @_ );
}

=begin TML

---++ ObjectMethod login( $query, $session )

this allows the login and logon cgi-scripts to use the same code. 
all a logon does, is re-direct to viewauth, and apache then figures out 
if it needs to challenge the user

=cut

sub login {
    my ( $this, $query, $session ) = @_;

    my $url =
      $session->getScriptUrl( 0, 'viewauth', $session->{webName},
        $session->{topicName}, t => time() );

    $url .= ( ';' . $query->query_string() ) if $query->query_string();

    $session->redirect( $url, 1 );    # with passthrough
}

=begin TML

---++ ObjectMethod getUser () -> $authUser

returns the userLogin if stored in the apache CGI query (ie session)

=cut

sub getUser {
    my $this = shift;

    my $query = $this->{session}->{request};
    my $authUser;

    # Ignore remote user if we got here via an error
    # Only useful with CGI engine & Apache webserver
    unless ( ( $ENV{REDIRECT_STATUS} || 0 ) >= 400 ) {
        $authUser = $query->remote_user() if $query;
        Foswiki::LoginManager::_trace( $this,
            "apache getUser says " . ( $authUser || 'undef' ) );
    }
    return $authUser;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2005-2006 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root
of this distribution. NOTE: Please extend that file, not this notice.
Copyright (C) 2005 Greg Abbas, twiki@abbas.org

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
