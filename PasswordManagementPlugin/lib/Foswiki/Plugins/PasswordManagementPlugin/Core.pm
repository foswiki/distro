# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Plugins::PasswordManagementPlugin::Core
REST methods for password management.
Messages templates are found in oopspassword.tmpl and passwordmessages.tmpl.

=cut

package Foswiki::Plugins::PasswordManagementPlugin::Core;

use strict;
use warnings;
use Assert;
use Error qw( :try );

use Foswiki                ();
use Foswiki::OopsException ();
use Foswiki::Sandbox       ();

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

=begin TML

---++ StaticMethod resetPassword($session)

Generates a password. Mails it to them and asks them to change it. Entry
point intended to be called from UI::run

=cut

sub _RESTresetPassword {

    #   my ( $session, $subject, $verb, $response ) = @_;

    my $session = shift;
    my $query   = $session->{request};
    my $users   = $session->{users};

    unless ( $Foswiki::cfg{EnableEmail} ) {
        throw Foswiki::OopsException(
            'password',
            topic  => $Foswiki::cfg{HomeTopicName},
            def    => 'email_disabled',
        );
    }

    if ( !$session->inContext('passwords_modifyable') ) {
        throw Foswiki::OopsException(
            'password',
            web   => $session->{webName},
            topic => $session->{topicName},
            def   => 'passwords_disabled'
        );
    }

    my $userName = $query->param('LoginName');

    unless ($userName) {
        throw Foswiki::OopsException( 'password', def => 'no_users_to_reset' );
    }

    if ( $Foswiki::cfg{TemplateLogin}{AllowLoginUsingEmailAddress}
        && ( $userName =~ $Foswiki::regex{emailAddrRegex} ) )
    {

        # try email addresses if it is one
        my $cuidList = $users->findUserByEmail($userName);

        if ( scalar @$cuidList > 1 ) {
            throw Foswiki::OopsException(
                'password',
                def   => 'non_unique_email',
            );
        }
        else {
            $userName = @$cuidList[0];
        }
    }
    else {
        throw Foswiki::OopsException(
            'password',
            status => 200,
            def    => 'email_not_supported',
        );
    }

    my $user = Foswiki::Func::getCanonicalUserID($userName);
    unless ( $user && $session->{users}->userExists($user) ) {
        throw Foswiki::OopsException(
            'password',
            status => 200,
            topic  => $Foswiki::cfg{HomeTopicName},
            def    => 'not_a_user',
            params => [$userName],
        );
    }

    #  TOPICRESTRICTION - locks session down to a single topic
    #  PASSWORDRESET    - Bypasses checking of old password.
    my $token = Foswiki::LoginManager::generateLoginToken(
        $user,
        {
            FOSWIKI_TOPICRESTRICTION =>
              "$Foswiki::cfg{SystemWebName}.ChangePassword",
            FOSWIKI_PASSWORDRESET => 1.
        }
    );

    my @em     = $users->getEmails($user);
    my $sent   = 0;
    my $errors = '';
    if ( !scalar(@em) ) {
        throw Foswiki::OopsException(
            'password',
            status => 200,
            topic  => $Foswiki::cfg{HomeTopicName},
            def    => 'bad_email',
            params => [$userName],
        );
    }
    else {
        # absolute URL context for email generation
        $session->enterContext('absolute_urls');

        my $ln = $users->getLoginName($user);
        my $wn = $users->getWikiName($user);
        foreach my $email (@em) {
            my $err;
            $err = _sendEmail(
                $session,
                'passwordresetmail',
                {
                    webName       => $Foswiki::cfg{UsersWebName},
                    LoginName     => $ln,
                    FirstLastName => Foswiki::spaceOutWikiWord($wn),
                    WikiName      => $wn,
                    EmailAddress  => $email,
                    TokenLife     => $Foswiki::cfg{Login}{TokenLifetime} || 900,
                    AuthToken     => $token,
                }
            );

            if ($err) {
                $errors .= $err;
            }
            else {
                $sent++;
            }
        }
        $session->leaveContext('absolute_urls');
    }

    # Now that we have successfully reset the password we log the event
    $session->logger->log(
        {
            level  => 'info',
            action => 'resetpasswd',
            extra  => $user,
        }
    );

    if ($sent) {

        # Redirect to a page that tells what happened
        throw Foswiki::OopsException(
            'password',
            status => 200,
            topic  => $Foswiki::cfg{HomeTopicName},
            def    => 'reset_ok',
            params => [ $Foswiki::cfg{Login}{TokenLifetime} || 900, $errors ]
        );
    }
    else {
        throw Foswiki::OopsException(
            'password',
            topic  => $Foswiki::cfg{HomeTopicName},
            def    => 'reset_bad',
            params => [$errors]
        );
    }
}

=begin TML

---++ StaticMethod RESTchangePassword

Change the user's password. Details of the user and password
are passed in CGI parameters.

=cut

sub _RESTchangePassword {
    my $session = shift;

    my $topic        = $session->{topicName};
    my $webName      = $session->{webName};
    my $query        = $session->{request};
    my $requestUser  = $session->{user};
    my $loginManager = $session->getLoginManager();

    my $oldpassword = $query->param('oldpassword');
    my $login       = $query->param('username') || $requestUser;
    my $passwordA   = $query->param('password');
    my $passwordB   = $query->param('passwordA');

    if (   $login eq $Foswiki::cfg{AdminUserLogin}
        || $login eq $Foswiki::cfg{AdminUserWikiName} )
    {
        throw Foswiki::OopsException(
            'password',
            web   => $webName,
            topic => $topic,
            def   => 'not_admin',
        );
    }

    if ( !$session->inContext('passwords_modifyable') ) {
        throw Foswiki::OopsException(
            'password',
            web   => $session->{webName},
            topic => $session->{topicName},
            def   => 'passwords_disabled'
        );
    }

    my $users = $session->{users};    # Get the Foswiki::Users object

    my $user = Foswiki::Func::getCanonicalUserID($login);
    unless ( $user && $session->{users}->userExists($user) ) {
        throw Foswiki::OopEexception(
            'password',
            status => 200,
            topic  => $Foswiki::cfg{hometopicname},
            def    => 'not_a_user',
            params => [$user],
        );
    }

    unless ( defined $passwordA ) {
        throw Foswiki::OopsException(
            'password',
            web    => $webName,
            topic  => $topic,
            def    => 'missing_fields',
            params => ['password']
        );
    }

    # check if passwords are identical
    if ( $passwordA ne $passwordB ) {
        throw Foswiki::OopsException(
            'password',
            web   => $webName,
            topic => $topic,
            def   => 'password_mismatch'
        );
    }

    my $resetActive = $loginManager->getSessionValue('FOSWIKI_PASSWORDRESET');

    if ($resetActive) {
        $oldpassword = 1;    # Allow password change without oldpassword.
    }
    elsif ( $users->isAdmin($requestUser)
        && !length($oldpassword) )
    {
        $oldpassword = 1;    # Allow an admin to omit the oldpassword
    }
    else {
        # check if required fields are filled in
        unless ( defined $oldpassword ) {
            throw Foswiki::OopsException(
                'password',
                web    => $webName,
                topic  => $topic,
                def    => 'missing_fields',
                params => ['oldpassword']
            );
        }

        unless ( $users->checkPassword( $login, $oldpassword ) ) {
            throw Foswiki::OopsException(
                'password',
                web   => $webName,
                topic => $topic,
                def   => 'wrong_password'
            );
        }
    }

    if ( length($passwordA) < $Foswiki::cfg{MinPasswordLength} ) {
        throw Foswiki::OopsException(
            'password',
            web    => $webName,
            topic  => $topic,
            def    => 'bad_password',
            params => [ $Foswiki::cfg{MinPasswordLength} ]
        );
    }

    # OK - password may be changed
    unless ( $users->setPassword( $user, $passwordA, $oldpassword ) ) {
        throw Foswiki::OopsException(
            'password',
            web   => $webName,
            topic => $topic,
            def   => 'password_not_changed'
        );
    }
    else {
        $session->logger->log(
            {
                level  => 'info',
                action => 'changepasswd',
                extra  => $login
            }
        );
    }

    $loginManager->clearSessionValue('FOSWIKI_PASSWORDRESET');
    $loginManager->clearSessionValue('FOSWIKI_TOPICRESTRICTION');

    # OK - password changed
    throw Foswiki::OopsException(
        'password',
        status => 200,
        web    => $webName,
        topic  => $topic,
        def    => 'password_changed'
    );
}

# sends $p->{template} to $p->{Email} with substitutions from $data
sub _sendEmail {
    my ( $session, $template, $data ) = @_;

    my $text = $session->templates->readTemplate($template);
    $data->{Name} ||= $data->{WikiName};
    my @unexpanded;
    foreach my $field ( keys %$data ) {
        my $f = uc($field);
        $text =~ s/\%$f\%/$data->{$field}/g;
    }

    my $topicObject = Foswiki::Meta->new( $session, $Foswiki::cfg{UsersWebName},
        $data->{WikiName} );
    $text = $topicObject->expandMacros($text);

    # SMELL: For some reason Net::sendEmail issues a "die" if the email address
    # is bad.  But only in a REST handler.  Send  to the exact same email from
    # UI::Password,  and it returns an error without the "die".
    # The eval{} avoids the issue.

    my $results;
    eval { $results = $session->net->sendEmail($text); };

    return $results;
}

1;

__END__

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2017 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:
(c) 1999-2007 TWiki Contributors
(c) 1999-2007 Peter Thoeny, peter@thoeny.com
(c) 2001 Kevin Atkinson, kevin twiki at atkinson dhs org
(c) 2003-2008 SvenDowideit, SvenDowideit@home.org.au
(c) 2003 Graeme Pyle graeme@raspberry dot co dot za
(c) 2004 Martin Cleaver, Martin.Cleaver@BCS.org.uk
(c) 2004 Gilles-Eric Descamps twiki at descamps.org
(c) 2004-2007 Crawford Currie c-dot.co.uk

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
