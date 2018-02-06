package PasswordManagementChangeTests;
use strict;
use warnings;

use FoswikiFnTestCase();
our @ISA = qw( FoswikiFnTestCase );

use Foswiki();
use Unit::Request();
use Error qw( :try );

use Foswiki::Plugins::PasswordManagementPlugin::Core;

my $RP_UI_FN;     #NOT TO BE USED - Prevent complie errors
my $MAN_UI_FN;    #NOT TO BE USED - Prevent complie errors

my ( $MrWhite, $MrBlue, $MrOrange, $MrGreen, $MrYellow );
my ( $MrWhiteEmail, $MrBlueEmail, $MrOrangeEmail, $MrGreenEmail,
    $MrYellowEmail );

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();

    my ($topicObject) = Foswiki::Func::readTopic( $Foswiki::cfg{UsersWebName},
        $Foswiki::cfg{DefaultUserWikiName} );
    $topicObject->text('');
    $topicObject->save();
    $topicObject->finish();
    $MrWhiteEmail = 'white@example.com';
    $this->registerUser( 'white', 'Mr', "White", $MrWhiteEmail );
    $MrWhite = $this->{session}->{users}->getCanonicalUserID('white');
    $this->registerUser( 'blue', 'Mr', "Blue", 'blue@example.com' );
    $MrBlue = $this->{session}->{users}->getCanonicalUserID('blue');
    $this->registerUser( 'orange', 'Mr', "Orange", 'orange@example.com' );
    $MrOrange = $this->{session}->{users}->getCanonicalUserID('orange');
    $this->registerUser( 'green', 'Mr', "Green", 'green@example.com' );
    $MrGreen = $this->{session}->{users}->getCanonicalUserID('green');
    $this->registerUser( 'yellow', 'Mr', "Yellow", 'yellow@example.com' );
    $MrYellow = $this->{session}->{users}->getCanonicalUserID('yellow');

    return;
}

sub setUserPass {
    my $this     = shift;
    my $username = shift;
    my $password = shift;

    my $query = Unit::Request->new(
        {
            'TopicName' => ['ChangePassword'],
            'username'  => [$username],
            'password'  => [$password],
            'passwordA' => [$password],

        }
    );

    $query->path_info( '/' . $Foswiki::cfg{SystemWebName} . '/ChangePassword' );
    $this->createNewFoswikiSession( $Foswiki::cfg{AdminUserLogin}, $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        Foswiki::Plugins::PasswordManagementPlugin::Core::_RESTchangePassword(
            $this->{session} );
    }
    catch Foswiki::AccessControlException with {
        my $e = shift;
        $this->assert( 0, $e->stringify );
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( 'password', $e->{template}, $e->stringify() );
        $this->assert_str_equals( "password_changed", $e->{def},
            $e->stringify() );
    }
    catch Error::Simple with {
        $this->assert( 0, shift->stringify() );
    }
    otherwise {
        $this->assert( 0, "expected an oops redirect" );
    };

    return;
}

################################################################################
################################ CHANGE PASSWORD TESTS ##########################
sub _tryChangePassword {
    my $this = shift;
    my ( $user, $oldpass, $pass, $pass2, $chguser, $expected ) = @_;

    my $query = Unit::Request->new(
        {
            'TopicName'   => ['ChangePassword'],
            'username'    => [$user],
            'oldpassword' => [$oldpass],
            'password'    => [$pass],
            'passwordA'   => [$pass2],

        }
    );
    $this->createNewFoswikiSession( $chguser, $query );

    $query->path_info( '/' . $Foswiki::cfg{SystemWebName} . '/ChangePassword' );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        Foswiki::Plugins::PasswordManagementPlugin::Core::_RESTchangePassword(
            $this->{session} );
    }
    catch Foswiki::AccessControlException with {
        my $e = shift;
        $this->assert( 0, $e->stringify );
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( 'password', $e->{template}, $e->stringify() );
        $this->assert_str_equals( $expected,  $e->{def},      $e->stringify() );
    }
    catch Error::Simple with {
        $this->assert( 0, shift->stringify() );
    }
    otherwise {
        $this->assert( 0, "expected an oops redirect" );
    };

    return;
}

sub test_changePasswordOK {
    my $this = shift;

    $this->assert( $this->{session}->{users}->userExists($MrWhite),
        " $MrWhite does not exist?" );

    my @emails = $this->{session}->{users}->getEmails($MrWhite);
    $this->assert_str_equals( $MrWhiteEmail, $emails[0] );

    @FoswikiFnTestCase::mails = ();

    # Admin can change password
    $this->_tryChangePassword( $MrWhite, undef, 'foobar12', 'foobar12',
        $Foswiki::cfg{AdminUserLogin},
        'password_changed' );

    # But not their own

    $this->_tryChangePassword( undef, undef, '32skidoo', '32skidoo', $MrWhite,
        'missing_fields' );
    $this->_tryChangePassword( undef, 'foobar12', '32skidoo', '23skidoo',
        $MrWhite, 'password_mismatch' );
    $this->_tryChangePassword( undef, 'foobar12', '32skidoo', '32skidoo',
        $MrWhite, 'password_changed' );

    # Password too short
    $Foswiki::cfg{MinPasswordLength} = 7;
    $this->_tryChangePassword( undef, '32skidoo', '32s', '32s', $MrWhite,
        'bad_password' );

    # Must not provide username if not an admin
    $this->_tryChangePassword( $MrWhite, 'foobar12', '32skidoo', '23skidoo',
        $MrWhite, 'change_not_admin' );

    return;
}

sub test_changePasswordNoSuchUser {
    my $this = shift;

    # This time we don't set up the testWikiName, so it should fail.

    $this->_tryChangePassword( 'CutTheCrap', 'foobar12', '32skidoo',
        '23skidoo', $Foswiki::cfg{DefaultUserLogin},
        'change_not_admin' );
    $this->_tryChangePassword( 'CutTheCrap', 'foobar12', '32skidoo',
        '23skidoo', $Foswiki::cfg{AdminUserLogin}, 'not_a_user' );

    return;
}

sub test_changePasswordInvalidUser {
    my $this = shift;

    # This time we don't set up the testWikiName, so it should fail.

    $this->_tryChangePassword( undef, undef, 'foobar12', 'foobar12',
        $Foswiki::cfg{AdminUserLogin},
        'no_change_admin' );

    # And not base users
    $this->_tryChangePassword( 'WikiGuest', undef, 'foobar12', 'foobar12',
        $Foswiki::cfg{AdminUserLogin},
        'no_change_base' );
    $this->_tryChangePassword( 'guest', undef, 'foobar12', 'foobar12',
        $Foswiki::cfg{AdminUserLogin},
        'no_change_base' );

    return;
}

################################################################################
################################ CHANGE EMAIL TESTS ##########################

sub _tryChangeEmail {
    my $this = shift;
    my ( $user, $pass, $chguser, $email, $expected ) = @_;

    my $query = Unit::Request->new(
        {
            'TopicName' => ['ChangeEmail'],
            'username'  => [$user],
            'password'  => [$pass],
            'email'     => [$email],

        }
    );
    $this->createNewFoswikiSession( $chguser, $query );

    $query->path_info( '/' . $Foswiki::cfg{SystemWebName} . '/ChangeEmail' );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        Foswiki::Plugins::PasswordManagementPlugin::Core::_RESTchangeEmail(
            $this->{session} );
    }
    catch Foswiki::AccessControlException with {
        my $e = shift;
        $this->assert( 0, $e->stringify );
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( 'password', $e->{template}, $e->stringify() );
        $this->assert_str_equals( $expected,  $e->{def},      $e->stringify() );
    }
    catch Error::Simple with {
        $this->assert( 0, shift->stringify() );
    }
    otherwise {
        $this->assert( 0, "expected an oops redirect" );
    };

    return;
}

sub test_changeEmailErrorsOK {
    my $this = shift;

    $this->assert( $this->{session}->{users}->userExists($MrWhite),
        " $MrWhite does not exist?" );

    my @emails = $this->{session}->{users}->getEmails($MrWhite);
    $this->assert_str_equals( $MrWhiteEmail, $emails[0] );

    @FoswikiFnTestCase::mails = ();

    # First set a password so we know it.

    $this->setUserPass( $MrWhite, 'foobar12' );

    # Change the email with an invalid password

    $this->_tryChangeEmail( $MrWhite, 'badpass', $MrWhite, 'foo@bar.com',
        'wrong_password' );
    $this->_tryChangeEmail( $MrWhite, undef, $MrWhite, 'foo@bar.com',
        'missing_fields' );

    # Admin Change the email with an invalid password

    $this->_tryChangeEmail( $MrWhite, 'badpass', $Foswiki::cfg{AdminUserLogin},
        'foo@bar.com', 'wrong_password' );
    $this->_tryChangeEmail( $MrWhite, undef, $Foswiki::cfg{AdminUserLogin},
        'foo@bar.com', 'email_changed' );

    # Change the email with a badly formatted email address.

    $this->_tryChangeEmail( $MrWhite, 'foobar12', $MrWhite, 'foo@barcom',
        'bad_email' );

    # Change the email with a valid email address.  This one should work.
    #
    $this->_tryChangeEmail( $MrWhite, 'foobar12', $MrWhite, 'foo@bar.com',
        'email_changed' );

    return;
}

sub test_changeEmailDuplicate {
    my $this = shift;

    $this->assert( $this->{session}->{users}->userExists($MrWhite),
        " $MrWhite does not exist?" );

    my @emails = $this->{session}->{users}->getEmails($MrWhite);
    $this->assert_str_equals( $MrWhiteEmail, $emails[0] );

    $Foswiki::cfg{Register}{UniqueEmail} = 1;

    @FoswikiFnTestCase::mails = ();

    # First set a password so we know it.
    $this->setUserPass( $MrWhite, 'foobar12' );
    $this->setUserPass( $MrGreen, 'foobar12' );

    $this->_tryChangeEmail( $MrWhite, 'foobar12', $MrWhite, 'foo@bar.com',
        'email_changed' );

    # Now try to set MrGreen to the same email

    $this->_tryChangeEmail( $MrGreen, 'foobar12', $MrGreen, 'foo@bar.com',
        'dup_email' );
    $this->_tryChangeEmail( $MrGreen, 'foobar12', $Foswiki::cfg{AdminUserLogin},
        'foo@bar.com', 'dup_email' );

    $Foswiki::cfg{Register}{UniqueEmail} = 0;

    $this->_tryChangeEmail( $MrGreen, 'foobar12', $MrGreen, 'foo@bar.com',
        'email_changed' );

    return;
}

sub test_changeEmailNoSuchUser {
    my $this = shift;

    # This time we don't set up the testWikiName, so it should fail.

    $this->_tryChangeEmail( 'NotAUser', 'foobar12',
        $Foswiki::cfg{AdminUserLogin},
        'foo@bar.com', 'not_a_user' );

    return;
}

sub test_changeEmailInvalidUser {
    my $this = shift;

    # This time we don't set up the testWikiName, so it should fail.

    $this->_tryChangeEmail( 'AdminUser', 'foobar12',
        $Foswiki::cfg{AdminUserLogin},
        'foo@bar.com', 'not_admin' );
    $this->_tryChangeEmail( 'WikiGuest', 'foobar12',
        $Foswiki::cfg{AdminUserLogin},
        'foo@bar.com', 'no_change_base' );
    $this->_tryChangeEmail( 'guest', 'foobar12', $Foswiki::cfg{AdminUserLogin},
        'foo@bar.com', 'no_change_base' );
    $this->_tryChangeEmail( 'RegistrationAgent', 'foobar12',
        $Foswiki::cfg{AdminUserLogin},
        'foo@bar.com', 'no_change_base' );

    return;
}

1;
