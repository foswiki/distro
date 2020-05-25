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

# Base mapping ID's can't change passwords. (AdminUser is handled separately)
my @notsupported = (
    'ProjectContributor',
    'UnknownUser',
    $Foswiki::cfg{DefaultUserLogin},
    $Foswiki::cfg{DefaultUserWikiName},
    $Foswiki::cfg{Register}{RegistrationAgentWikiName},
    'BaseUserMapping_333',
);

=begin TML

---++ StaticMethod _RESTresetPassword($session)

Generates a reset token. Mails it to the user and asks them to set their password.

=cut

sub _RESTresetPassword {

    #   my ( $session, $subject, $verb, $response ) = @_;

    my $session = shift;
    my $query   = $session->{request};
    my $users   = $session->{users};

    unless ( $Foswiki::cfg{EnableEmail} ) {
        throw Foswiki::OopsException(
            'password',
            topic => $Foswiki::cfg{HomeTopicName},
            def   => 'email_disabled',
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

    if ( $userName =~ $Foswiki::regex{emailAddrRegex} ) {
        if ( $Foswiki::cfg{TemplateLogin}{AllowLoginUsingEmailAddress} ) {

            # try email addresses if it is one
            my $cuidList = $users->findUserByEmail($userName);

            if ( scalar @$cuidList > 1 ) {
                throw Foswiki::OopsException( 'password',
                    def => 'non_unique_email', );
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
    }

    my $user = Foswiki::Func::getCanonicalUserID($userName);

    if ( $users->isInUserList( $user, \@notsupported ) ) {
        throw Foswiki::OopsException(
            'password',
            status => 200,
            topic  => $Foswiki::cfg{HomeTOpicName},
            def    => 'no_change_base',
            params => [$user],
        );
    }

    unless ( $user && $session->{users}->userExists($user) ) {
        throw Foswiki::OopsException(
            'password',
            status => 200,
            topic  => $Foswiki::cfg{HomeTopicName},
            def    => 'not_a_user',
            params => [$userName],
        );
    }

    my @em = $users->getEmails($user);
    if ( !scalar(@em) ) {
        throw Foswiki::OopsException(
            'password',
            status => 200,
            topic  => $Foswiki::cfg{HomeTopicName},
            def    => 'bad_email',
            params => [$userName],
        );
    }

    # lifetime 0 - uses configured default
    my ( $sent, $errors ) = _generateResetEmail( $session, $user, 0, \@em, '' );

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
            params => [
                $Foswiki::cfg{Login}{TokenLifetime} || 15,
                ($errors) ? '1' : '0'
            ]
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

---++ StaticMethod _RESTbulkResetPassword($session)

Generates a reset token. Mails it to multiple users and asks them to set their password.

This version is restricted to Admin users, and allows multile users in the request.

This version only accepts User Names. It cannot be used with email addresses.

=cut

sub _RESTbulkResetPassword {

    #   my ( $session, $subject, $verb, $response ) = @_;

    my $session = shift;
    my $query   = $session->{request};
    my $users   = $session->{users};

    unless ( $users->isAdmin( $session->{user} ) ) {
        throw Foswiki::OopsException(
            'password',
            topic => $Foswiki::cfg{HomeTopicName},
            def   => 'bulk_not_admin',
        );
    }

    unless ( $Foswiki::cfg{EnableEmail} ) {
        throw Foswiki::OopsException(
            'password',
            topic => $Foswiki::cfg{HomeTopicName},
            def   => 'email_disabled',
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

    my @userNames = $query->multi_param('resetUsers');

    unless ( scalar @userNames ) {
        throw Foswiki::OopsException( 'password', def => 'no_users_to_reset' );
    }

    my $validFor     = $query->param('validFor')     || 0;
    my $Introduction = $query->param('Introduction') || '';

    my ( $sent, $errors );

    foreach my $userName (@userNames) {

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

        my @em = $users->getEmails($user);
        if ( !scalar(@em) ) {
            throw Foswiki::OopsException(
                'password',
                status => 200,
                topic  => $Foswiki::cfg{HomeTopicName},
                def    => 'bad_email',
                params => [$userName],
            );
        }

        ( $sent, $errors ) =
          _generateResetEmail( $session, $user, $validFor, \@em,
            $Introduction );

        # Now that we have successfully reset the password we log the event
        $session->logger->log(
            {
                level  => 'info',
                action => 'resetpasswd',
                extra  => $user,
            }
        );
    }

    if ($sent) {

        # Redirect to a page that tells what happened
        throw Foswiki::OopsException(
            'password',
            status => 200,
            topic  => $Foswiki::cfg{HomeTopicName},
            def    => 'reset_ok',
            params => [
                $validFor || $Foswiki::cfg{Login}{TokenLifetime} || 15,
                ($errors) ? '1' : '0'
            ]
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

---++ StaticMethod _generateResetEmail ( $session, $user, $validFor, $emails )

Utility method. Passed a user name and list of emails, generate the reset token
and email it to the email addresses for that user.  This is intended for sending
to a *single* user with one or more registered email addresses.

The reset token sets two session variables when it is used during login:
   * FOSWIKI_TOPICRESTRICTION = System.ChangePassword
   * FOSWIKI_PASSWORDRESET => 1
The first limits the login to access only a single topic - the ChangePassword topic.
and the PASSWORDRESET variable allows password change without entering the old password.

This sends one email per address.  If multiple email addresses are listed, some
agents can fail the entire email.

=cut

sub _generateResetEmail {

    my ( $session, $user, $validFor, $emails, $message ) = @_;

    my $users = $session->{users};

    #  TOPICRESTRICTION - locks session down to a single topic
    #  PASSWORDRESET    - Bypasses checking of old password.
    my $token = Foswiki::LoginManager::generateLoginToken(
        $user,
        $validFor,
        {
            FOSWIKI_TOPICRESTRICTION =>
              "$Foswiki::cfg{SystemWebName}.ChangePassword",
            FOSWIKI_PASSWORDRESET => 1.
        }
    );

    my $sent   = 0;
    my $errors = '';

    # absolute URL context for email generation
    $session->enterContext('absolute_urls');

    my $ln = $users->getLoginName($user);
    my $wn = $users->getWikiName($user);

    # SMELL: Some email agents die if any email in the To: list is bad.
    # eg. ssmtp.  So we cannot flatten the list of emails, and need to
    # send them one at a time.
    #my $email = join( ', ', @$emails);

    foreach my $email (@$emails) {
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
                Introduction  => $message,
            }
        );

        if ($err) {
            $errors .= $err;
        }
        else {
            $sent++;
        }
        $session->leaveContext('absolute_urls');
    }
    return ( $sent, $errors );
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
    my $users = $session->{users};    # Get the Foswiki::Users object

    my $oldpassword = $query->param('oldpassword');
    my $login       = $query->param('username');
    my $passwordA   = $query->param('password');
    my $passwordB   = $query->param('passwordA') || '';

    if ( !$session->inContext('passwords_modifyable') ) {
        throw Foswiki::OopsException(
            'password',
            web   => $session->{webName},
            topic => $session->{topicName},
            def   => 'passwords_disabled'
        );
    }

    if ( defined $login && !$users->isAdmin($requestUser) ) {
        throw Foswiki::OopsException(
            'password',
            status => 200,
            topic  => $Foswiki::cfg{HomeTOpicName},
            def    => 'change_not_admin',
            params => [$login],
        );
    }
    elsif ( !defined $login || !length($login) ) {
        $login = $requestUser;
    }

    if (   $login eq $Foswiki::cfg{AdminUserLogin}
        || $login eq $Foswiki::cfg{AdminUserWikiName}
        || $login eq 'BaseUserMapping_333' )
    {
        throw Foswiki::OopsException(
            'password',
            web   => $webName,
            topic => $topic,
            def   => 'no_change_admin',
        );
    }

    my $user = Foswiki::Func::getCanonicalUserID($login);

    if ( $users->isInUserList( $user, \@notsupported ) ) {
        throw Foswiki::OopsException(
            'password',
            status => 200,
            topic  => $Foswiki::cfg{HomeTOpicName},
            def    => 'no_change_base',
            params => [$login],
        );
    }

    unless ( $user && $session->{users}->userExists($user) ) {
        throw Foswiki::OopsException(
            'password',
            status => 200,
            topic  => $Foswiki::cfg{HomeTOpicName},
            def    => 'not_a_user',
            params => [$login],
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
        $oldpassword = undef;    # Allow password change without oldpassword.
    }
    elsif ( $users->isAdmin($requestUser)
        && !length($oldpassword) )
    {
        $oldpassword = undef;    # Allow an admin to omit the oldpassword
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
            my $error = $users->passwordError($login) || '';
            throw Foswiki::OopsException(
                'password',
                web    => $webName,
                topic  => $topic,
                def    => 'wrong_password',
                params => [$error],
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
    my $ok;
    my $result;

    try {
        $ok = $users->setPassword( $user, $passwordA, $oldpassword );
    }
    catch Error::Simple with {
        my $error = shift;
        Foswiki::Func::writeWarning( "Error in setPassword: ",
            ( split /\n/, $error->{-text} )[0] );
        $result = "Internal error";
    };

    unless ($ok) {
        $result ||= $users->passwordError($user) || '';
    }

    if ( !$ok ) {
        throw Foswiki::OopsException(
            'password',
            web    => $webName,
            topic  => $topic,
            def    => 'password_not_changed',
            params => [$result]
        );
    }

    $session->logger->log(
        {
            level  => 'info',
            action => 'changepasswd',
            extra  => $login
        }
    );

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

=begin TML

---++ StaticMethod _RESTchangeEmail( $session )

Change the user's email. Details of the user and password
are passed in CGI parameters.

=cut

sub _RESTchangeEmail {
    my $session = shift;

    my $topic       = $session->{topicName};
    my $webName     = $session->{webName};
    my $query       = $session->{request};
    my $requestUser = $session->{user};

    my $login    = $query->param('username');
    my $password = $query->param('password');
    my $email    = $query->param('email');

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
        throw Foswiki::OopsException(
            'password',
            status => 200,
            topic  => $Foswiki::cfg{HomeTopicName},
            def    => 'not_a_user',
            params => [$login],
        );
    }

    if ( $users->isInUserList( $user, \@notsupported ) ) {
        throw Foswiki::OopsException(
            'password',
            status => 200,
            topic  => $Foswiki::cfg{HomeTOpicName},
            def    => 'no_change_base',
            params => [$login],
        );
    }

    unless ( defined $password || $users->isAdmin($requestUser) ) {
        throw Foswiki::OopsException(
            'password',
            web    => $webName,
            topic  => $topic,
            def    => 'missing_fields',
            params => ['password']
        );
    }

    unless ( $users->isAdmin($requestUser)
        && !length($password) )
    {
        unless ( $users->checkPassword( $login, $password ) ) {
            throw Foswiki::OopsException(
                'password',
                web    => $webName,
                topic  => $topic,
                def    => 'wrong_password',
                params => [ $users->passwordError($login) || '' ],
            );
        }
    }

    my $cUID = $users->getCanonicalUserID($login);

    # Determine that the cUID exists.
    unless ( defined $cUID ) {
        throw Foswiki::OopsException(
            'password',
            web    => $webName,
            topic  => $topic,
            def    => 'not_a_user',
            params => [$login]
        );
    }

    # check valid email addresses - space between each
    if ( defined $email
        && $email !~ /($Foswiki::regex{emailAddrRegex}\s*)+/ )
    {
        throw Foswiki::OopsException(
            'password',
            web    => $webName,
            topic  => $topic,
            def    => 'bad_email',
            params => [$email]
        );
    }

    # Optional check if email address is already registered
    if ( $Foswiki::cfg{Register}{UniqueEmail} ) {
        my @existingNames = Foswiki::Func::emailToWikiNames($email);
        if ( scalar(@existingNames) ) {
            $session->logger->log( 'warning',
                "Email change rejected: $email already registered by: "
                  . join( ', ', @existingNames ) );
            throw Foswiki::OopsException(
                'password',
                web    => $webName,
                topic  => $topic,
                def    => 'dup_email',
                params => [$email]
            );
        }
    }

    my $emailFilter;
    $emailFilter = qr/$Foswiki::cfg{Register}{EmailFilter}/ix
      if ( length( $Foswiki::cfg{Register}{EmailFilter} ) );
    if ( defined $emailFilter
        && $email =~ $emailFilter )
    {
        $session->logger->log( 'warning',
"Email change rejected: $email rejected by the {Register}{EmailFilter}."
        );
        throw Foswiki::OopsException(
            'password',
            def    => 'rej_email',
            web    => $webName,
            topic  => $topic,
            params => [$email]
        );
    }

    if ( defined $email ) {

        my $oldEmails = join( ', ', $users->getEmails($cUID) );
        my $return = $users->setEmails( $cUID, split( /\s+/, $email ) );
        $session->logger->log(
            {
                level    => 'info',
                action   => 'changepasswd',
                webTopic => $webName . '.' . $topic,
                extra    => "from $oldEmails to $email for $login",
            }
        );
    }

    # must be just email
    throw Foswiki::OopsException(
        'password',
        status => 200,
        web    => $webName,
        topic  => $topic,
        def    => 'email_changed',
        params => [ $email, Foswiki::Func::getWikiUserName($login) ]
    );
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
