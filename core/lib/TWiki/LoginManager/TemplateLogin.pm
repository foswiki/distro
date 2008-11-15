# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2005-2006 TWiki Contributors.
# All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
# Copyright (C) 2005 Greg Abbas, twiki@abbas.org
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

=pod

---+ package TWiki::LoginManager::TemplateLogin

This is a login manager that you can specify in the security setup section of
[[%SCRIPTURL{"configure"}%][configure]]. It provides users with a
template-based form to enter usernames and passwords, and works with the
PasswordManager that you specify to verify those passwords.

Subclass of TWiki::LoginManager; see that class for documentation of the
methods of this class.

=cut

package TWiki::LoginManager::TemplateLogin;
use base 'TWiki::LoginManager';

use strict;
use Assert;

=pod

---++ ClassMethod new ($session, $impl)

Construct the TemplateLogin object

=cut

sub new {
    my ( $class, $session ) = @_;
    my $this = $class->SUPER::new($session);
    $session->enterContext('can_login');
    if ( $TWiki::cfg{Sessions}{ExpireCookiesAfter} ) {
        $session->enterContext('can_remember_login');
    }
    if ( $TWiki::cfg{TemplateLogin}{PreventBrowserRememberingPassword} ) {
        $session->enterContext('no_auto_complete_login');
    }
    return $this;
}

=pod

---++ ObjectMethod forceAuthentication () -> boolean

method called when authentication is required - redirects to (...|view)auth
Triggered on auth fail

=cut

sub forceAuthentication {
    my $this  = shift;
    my $twiki = $this->{twiki};

    unless ( $twiki->inContext('authenticated') ) {
        my $query = $twiki->{request};

        # Redirect with passthrough so we don't lose the original query params
        my $twiki = $this->{twiki};
        my $topic = $twiki->{topicName};
        my $web   = $twiki->{webName};
        my $url   = $twiki->getScriptUrl( 0, 'login', $web, $topic );
        $query->param( -name => 'origurl', -value => $twiki->{request}->uri );
        $twiki->redirect( $url, 1 );
        return 1;
    }
    return undef;
}

=pod

---++ ObjectMethod loginUrl () -> $loginUrl

TODO: why is this not used internally? When is it called, and why
Content of a login link

=cut

sub loginUrl {
    my $this  = shift;
    my $twiki = $this->{twiki};
    my $topic = $twiki->{topicName};
    my $web   = $twiki->{webName};
    return $twiki->getScriptUrl( 0, 'login', $web, $topic,
        origurl => $twiki->{request}->uri );
}

=pod

---++ ObjectMethod login( $query, $twiki )

If a login name and password have been passed in the query, it
validates these and if authentic, redirects to the original
script. If there is no username in the query or the username/password is
invalid (validate returns non-zero) then it prompts again.

If a flag to remember the login has been passed in the query, then the
corresponding session variable will be set. This will result in the
login cookie being preserved across browser sessions.

The password handler is expected to return a perl true value if the password
is valid. This return value is stored in a session variable called
VALIDATION. This is so that password handlers can return extra information
about the user, such as a list of Wiki groups stored in a separate
database, that can then be displayed by referring to
%<nop>SESSION_VARIABLE{"VALIDATION"}%

=cut

sub login {
    my ( $this, $query, $twikiSession ) = @_;
    my $twiki = $this->{twiki};
    my $users = $twiki->{users};

    my $origurl   = $query->param('origurl');
    my $loginName = $query->param('username');
    my $loginPass = $query->param('password');
    my $remember  = $query->param('remember');

    # Eat these so there's no risk of accidental passthrough
    $query->delete( 'origurl', 'username', 'password' );

    # UserMappings can over-ride where the login template is defined
    my $loginTemplate = $users->loginTemplateName();    #defaults to login.tmpl
    my $tmpl =
      $twiki->templates->readTemplate( $loginTemplate, $twiki->getSkin() );

    my $banner = $twiki->templates->expandTemplate('LOG_IN_BANNER');
    my $note   = '';
    my $topic  = $twiki->{topicName};
    my $web    = $twiki->{webName};

    my $cgisession = $this->{_cgisession};

    $cgisession->param( 'REMEMBER', $remember ) if $cgisession;
    if (   $cgisession
        && $cgisession->param('AUTHUSER')
        && $loginName
        && $loginName ne $cgisession->param('AUTHUSER') )
    {
        $banner = $twiki->templates->expandTemplate('LOGGED_IN_BANNER');
        $note   = $twiki->templates->expandTemplate('NEW_USER_NOTE');
    }

    my $error = '';

    if ($loginName) {
        my $validation = $users->checkPassword( $loginName, $loginPass );
        $error = $users->passwordError();

        if ($validation) {
            $this->userLoggedIn($loginName);
            $cgisession->param( 'VALIDATION', $validation ) if $cgisession;
            if ( !$origurl || $origurl eq $query->url() ) {
                $origurl = $twiki->getScriptUrl( 0, 'view', $web, $topic );
            }

            #SUCCESS our user is authenticated..
            $query->delete('sudo')
              ; #remove the sudo param - its only to tell TemplateLogin that we're using BaseMapper..
                # Redirect with passthrough
            $twikiSession->redirect( $origurl, 1 );
            return;
        }
        else {
            $banner = $twiki->templates->expandTemplate('UNRECOGNISED_USER');
        }
    }

    # TODO: add JavaScript password encryption in the template
    # to use a template)
    $origurl ||= '';
    $twiki->{prefs}->pushPreferenceValues(
        'SESSION',
        {
            ORIGURL => $origurl,
            BANNER  => $banner,
            NOTE    => $note,
            ERROR   => $error
        }
    );

    $tmpl = $twiki->handleCommonTags( $tmpl, $web, $topic );
    $tmpl = $twiki->renderer->getRenderedVersion( $tmpl, '' );
    $tmpl =~ s/<nop>//g;
    $twiki->writeCompletePage($tmpl);
}

1;
