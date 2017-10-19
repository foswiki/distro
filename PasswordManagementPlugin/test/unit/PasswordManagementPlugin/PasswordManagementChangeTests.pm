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

################################################################################
################################ CHANGE PASSWORD TESTS ##########################

sub test_changePasswordOK {
    my $this = shift;

    $this->assert( $this->{session}->{users}->userExists($MrWhite),
        " $MrWhite does not exist?" );

    my @emails = $this->{session}->{users}->getEmails($MrWhite);
    $this->assert_str_equals( $MrWhiteEmail, $emails[0] );

    @FoswikiFnTestCase::mails = ();

    my $query = Unit::Request->new(
        {
            'TopicName' => ['ChangePassword'],
            'username'  => [$MrWhite],
            'password'  => ['foobar12'],
            'passwordA' => ['foobar12'],

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

    $query = Unit::Request->new(
        {
            'TopicName'   => ['ChangePassword'],
            'oldpassword' => ['foobar12'],

            #'username' => [ $MrWhite ],
            'password'  => ['32skidoo'],
            'passwordA' => ['32skidoo'],

        }
    );

    $query->path_info( '/' . $Foswiki::cfg{SystemWebName} . '/ChangePassword' );
    $this->createNewFoswikiSession( $MrWhite, $query );
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

sub test_changePasswordNoSuchUser {
    my $this = shift;

    # This time we don't set up the testWikiName, so it should fail.

    my $query = Unit::Request->new(
        {
            'username'    => ['NotAUser'],
            'TopicName'   => ['ChangePassword'],
            'oldpassword' => ['whoknows'],
            'password'    => ['gotchanow'],
            'passwordA'   => ['gotchanow'],
        }
    );

    @FoswikiFnTestCase::mails = ();

    $query->path_info( '/.' . $Foswiki::cfg{SystemWebName} . '/ResetPassword' );
    $this->createNewFoswikiSession( $Foswiki::cfg{DefaultUserLogin}, $query );
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
        $this->assert_str_equals( "change_not_admin", $e->{def},
            $e->stringify() );

    }
    catch Error::Simple with {
        $this->assert( 0, shift->stringify() );
    }
    otherwise {
        $this->assert( 0, "expected an oops redirect" );
    };

    $this->createNewFoswikiSession( $Foswiki::cfg{AdminUserLogin}, $query );

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
        $this->assert_str_equals( "not_a_user", $e->{def}, $e->stringify() );

    }
    catch Error::Simple with {
        $this->assert( 0, shift->stringify() );
    }
    otherwise {
        $this->assert( 0, "expected an oops redirect" );
    };
    $this->assert_equals( 0, scalar(@FoswikiFnTestCase::mails) );

    return;
}

sub test_changePasswordInvalidUser {
    my $this = shift;

    # This time we don't set up the testWikiName, so it should fail.

    my $query = Unit::Request->new(
        {
            'username'    => ['AdminUser'],
            'TopicName'   => ['ChangePassword'],
            'oldpassword' => ['whoknows'],
            'password'    => ['gotchanow'],
            'passwordA'   => ['gotchanow'],
        }
    );

    $query->path_info(
        '/.' . $Foswiki::cfg{SystemWebName} . '/ChangePassword' );
    $this->createNewFoswikiSession( $Foswiki::cfg{AdminUserLogin}, $query );

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
        $this->assert_str_equals( "no_change_admin", $e->{def},
            $e->stringify() );

    }
    catch Error::Simple with {
        $this->assert( 0, shift->stringify() );
    }
    otherwise {
        $this->assert( 0, "expected an oops redirect" );
    };

    $query = Unit::Request->new(
        {
            'username'    => ['WikiGuest'],
            'TopicName'   => ['ChangePassword'],
            'oldpassword' => ['whoknows'],
            'password'    => ['gotchanow'],
            'passwordA'   => ['gotchanow'],
        }
    );
    $query->path_info(
        '/.' . $Foswiki::cfg{SystemWebName} . '/ChangePassword' );
    $this->createNewFoswikiSession( $Foswiki::cfg{AdminUserLogin}, $query );

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
        $this->assert_str_equals( "no_change_base", $e->{def},
            $e->stringify() );

    }
    catch Error::Simple with {
        $this->assert( 0, shift->stringify() );
    }
    otherwise {
        $this->assert( 0, "expected an oops redirect" );
    };

    $query = Unit::Request->new(
        {
            'username'    => ['NotAUserHere1234'],
            'TopicName'   => ['ChangePassword'],
            'oldpassword' => ['whoknows'],
            'password'    => ['gotchanow'],
            'passwordA'   => ['gotchanow'],
        }
    );
    $query->path_info(
        '/.' . $Foswiki::cfg{SystemWebName} . '/ChangePassword' );
    $this->createNewFoswikiSession( $Foswiki::cfg{AdminUserLogin}, $query );

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
        $this->assert_str_equals( "not_a_user", $e->{def}, $e->stringify() );

    }
    catch Error::Simple with {
        $this->assert( 0, shift->stringify() );
    }
    otherwise {
        $this->assert( 0, "expected an oops redirect" );
    };
    return;
}

1;
