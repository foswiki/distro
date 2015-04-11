# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::UI::Passwords
UI methods for password management.
Shares a message template with Register.pm (registermessages.tmpl)

=cut

package Foswiki::UI::Passwords;

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

sub resetPassword {
    my $session = shift;
    my $query   = $session->{request};
    my $topic   = $session->{topicName};
    my $web     = $session->{webName};
    my $user    = $session->{user};

    unless ( $Foswiki::cfg{EnableEmail} ) {
        my $err = $session->i18n->maketext(
            'Email has been disabled for this Foswiki installation');
        throw Foswiki::OopsException(
            'register',
            topic  => $Foswiki::cfg{HomeTopicName},
            def    => 'reset_bad',
            params => [$err]
        );
    }

    my @userNames = $query->multi_param('LoginName');
    unless (@userNames) {
        throw Foswiki::OopsException( 'register', def => 'no_users_to_reset' );
    }
    my $introduction = $query->param('Introduction') || '';

    # need admin priv if resetting bulk, or resetting another user
    my $isBulk = ( scalar(@userNames) > 1 );

    if ($isBulk) {

        # Only admin is able to reset more than one password or
        # another user's password.
        unless ( $session->{users}->isAdmin($user) ) {
            throw Foswiki::OopsException(
                'accessdenied',
                status => 403,
                def    => 'only_group',
                web    => $web,
                topic  => $topic,
                params => [ $Foswiki::cfg{SuperAdminGroup} ]
            );
        }
    }
    else {

        # Anyone can reset a single password - important because by definition
        # the user cannot authenticate
        # Note that the passwd script must NOT authenticate!
    }

    # Parameters have been checked, check the validation key
    Foswiki::UI::checkValidationKey($session);

    # Collect all messages into one string
    my $message = '';
    my $good    = 1;
    foreach my $userName (@userNames) {
        $good = $good
          && _resetUsersPassword( $session, $userName, $introduction,
            \$message );
    }

    my $action = '';

    # Redirect to a page that tells what happened
    if ($good) {
        unless ($isBulk) {

            # one user; refine the change password link to include their
            # username (can't use logged in user - by definition this won't
            # be them!)
            $action = '?username=' . $userNames[0];
        }

        throw Foswiki::OopsException(
            'register',
            status => 200,
            topic  => $Foswiki::cfg{HomeTopicName},
            def    => 'reset_ok',
            params => [$message]
        );
    }
    else {
        throw Foswiki::OopsException(
            'register',
            topic  => $Foswiki::cfg{HomeTopicName},
            def    => 'reset_bad',
            params => [$message]
        );
    }
}

# return status
sub _resetUsersPassword {
    my ( $session, $login, $introduction, $pMess ) = @_;

    my $users = $session->{users};

    unless ($login) {
        $$pMess .= $session->inlineAlert( 'alertsnohtml', 'bad_user', '' );
        return 0;
    }

    my $user    = $users->getCanonicalUserID($login);
    my $message = '';
    unless ( $user && $users->userExists($user) ) {

        # Not an error.
        $$pMess .=
          $session->inlineAlert( 'alertsnohtml', 'missing_user', $login );
        return 0;
    }

    require Foswiki::Users;
    my $password = Foswiki::Users::randomPassword();

    unless ( $users->setPassword( $user, $password, 1 ) ) {
        $$pMess .= $session->inlineAlert( 'alertsnohtml', 'reset_bad', $user );
        return 0;
    }

    # Now that we have successfully reset the password we log the event
    $session->logger->log(
        {
            level  => 'info',
            action => 'resetpasswd',
            extra  => $login,
        }
    );

    # absolute URL context for email generation
    $session->enterContext('absolute_urls');

    my @em   = $users->getEmails($user);
    my $sent = 0;
    if ( !scalar(@em) ) {
        $$pMess .=
          $session->inlineAlert( 'alertsnohtml', 'no_email_for', $user );
    }
    else {
        my $ln = $users->getLoginName($user);
        my $wn = $users->getWikiName($user);
        foreach my $email (@em) {
            require Foswiki::UI::Register;
            my $err = _sendEmail(
                $session,
                webName       => $Foswiki::cfg{UsersWebName},
                LoginName     => $ln,
                FirstLastName => Foswiki::spaceOutWikiWord($wn),
                WikiName      => $wn,
                EmailAddress  => $email,
                Password      => $password,
                Introduction  => $introduction,
            );

            if ($err) {
                $$pMess .=
                  $session->inlineAlert( 'alertsnohtml', 'generic', $err );
            }
            else {
                $sent = 1;
            }
        }
    }

    $session->leaveContext('absolute_urls');

    if ($sent) {
        $$pMess .= $session->inlineAlert(
            'alertsnohtml', 'new_sys_pass',
            $users->getLoginName($user),
            $users->getWikiName($user)
        );
    }

    return $sent;
}

# sends $p->{template} with substitutions from $data
sub _sendEmail {
    my ( $session, %data ) = @_;

    my $text = $session->templates->readTemplate('mailresetpassword');
    foreach my $field ( keys %data ) {
        my $f = uc($field);
        $text =~ s/\%$f\%/$data{$field}/g;
    }

    my $topicObject = Foswiki::Meta->new( $session, $Foswiki::cfg{UsersWebName},
        $data{WikiName} );
    $text = $topicObject->expandMacros($text);

    return $session->net->sendEmail($text);
}

=begin TML

---++ StaticMethod changePasswordAndOrEmail( $session )

Change the user's password and/or email. Details of the user and password
are passed in CGI parameters.

=cut

sub changePasswordAndOrEmail {
    my $session = shift;

    my $topic       = $session->{topicName};
    my $webName     = $session->{webName};
    my $query       = $session->{request};
    my $requestUser = $session->{user};

    my $oldpassword = $query->param('oldpassword');
    my $login       = $query->param('username');
    my $passwordA   = $query->param('password');
    my $passwordB   = $query->param('passwordA');
    my $email       = $query->param('email');
    my $topicName   = $query->param('TopicName');

    # check if required fields are filled in
    unless ($login) {
        throw Foswiki::OopsException(
            'attention',
            web    => $webName,
            topic  => $topic,
            def    => 'missing_fields',
            params => ['username']
        );
    }

    my $users = $session->{users};

    unless ($login) {
        throw Foswiki::OopsException(
            'register',
            web    => $webName,
            topic  => $topic,
            def    => 'not_a_user',
            params => [$login]
        );
    }

    my $changePass = 0;
    if ( defined $passwordA || defined $passwordB ) {
        unless ( defined $passwordA ) {
            throw Foswiki::OopsException(
                'attention',
                web    => $webName,
                topic  => $topic,
                def    => 'missing_fields',
                params => ['password']
            );
        }

        # check if passwords are identical
        if ( $passwordA ne $passwordB ) {
            throw Foswiki::OopsException(
                'register',
                web   => $webName,
                topic => $topic,
                def   => 'password_mismatch'
            );
        }
        $changePass = 1;
    }

    # check if required fields are filled in
    unless ( defined $oldpassword || $users->isAdmin($requestUser) ) {
        throw Foswiki::OopsException(
            'attention',
            web    => $webName,
            topic  => $topic,
            def    => 'missing_fields',
            params => ['oldpassword']
        );
    }

    unless ( $users->isAdmin($requestUser)
        || $users->checkPassword( $login, $oldpassword ) )
    {
        throw Foswiki::OopsException(
            'register',
            web   => $webName,
            topic => $topic,
            def   => 'wrong_password'
        );
    }

    my $cUID = $users->getCanonicalUserID($login);

    # Determine that the cUID exists.
    unless ( defined $cUID ) {
        throw Foswiki::OopsException(
            'register',
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
            'register',
            web    => $webName,
            topic  => $topic,
            def    => 'bad_email',
            params => [$email]
        );
    }

    if ( $changePass
        && length($passwordA) < $Foswiki::cfg{MinPasswordLength} )
    {
        throw Foswiki::OopsException(
            'register',
            web    => $webName,
            topic  => $topic,
            def    => 'bad_password',
            params => [ $Foswiki::cfg{MinPasswordLength} ]
        );
    }

    # Parameters have been checked, check the validation key
    Foswiki::UI::checkValidationKey($session);

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

    # OK - password may be changed
    if ($changePass) {

        unless ( $users->setPassword( $cUID, $passwordA, $oldpassword ) ) {
            throw Foswiki::OopsException(
                'register',
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

        # OK - password changed
        throw Foswiki::OopsException(
            'register',
            status => 200,
            web    => $webName,
            topic  => $topic,
            def    => 'password_changed'
        );
    }

    # must be just email
    throw Foswiki::OopsException(
        'register',
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

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
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
