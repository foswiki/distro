package PasswordManagementResetTests;
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

    $this->createNewFoswikiSession();
    ($topicObject) =
      Foswiki::Func::readTopic( $this->{users_web}, "ReservoirDogsGroup" );
    $topicObject->text(<<"THIS");
   * Set GROUP = MrWhite, $this->{users_web}.MrBlue
   * Set ALLOWTOPICVIEW = $this->{users_web}.ReservoirDogsGroup
THIS
    $topicObject->save();
    $topicObject->finish();

    return;
}

sub loadExtraConfig {
    my ( $this, $context, @args ) = @_;
    $this->SUPER::loadExtraConfig( $context, @args );
    $Foswiki::cfg{EnableEmail} = 1;
    $Foswiki::cfg{WebMasterEmail} = 'dummyaddr@foswiki.org';

    return;
}


################################################################################
################################ RESET PASSWORD TESTS ##########################

sub test_resetPasswordOkay {
    my $this = shift;

    ## Need to create an account (else oopsnotwikiuser)
    ### with a known email address (else oopsregemail)

    $this->assert( $this->{session}->{users}->userExists($MrWhite),
        " $MrWhite does not exist?" );

    my @emails = $this->{session}->{users}->getEmails($MrWhite);
    $this->assert_str_equals( $MrWhiteEmail, $emails[0] );

    @FoswikiFnTestCase::mails = ();

    my $query = Unit::Request->new(
        {
            'LoginName' => [$MrWhite],
            'TopicName' => ['ResetPassword'],
        }
    );

    $query->path_info( '/' . $this->{users_web} . '/UserRegistration' );
    $this->createNewFoswikiSession( $Foswiki::cfg{DefaultUserLogin}, $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        Foswiki::Plugins::PasswordManagementPlugin::Core::_RESTresetPassword(
            $this->{session} );
    }
    catch Foswiki::AccessControlException with {
        my $e = shift;
        $this->assert( 0, $e->stringify );
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( 'password', $e->{template}, $e->stringify() );
        $this->assert_str_equals( "reset_ok", $e->{def},      $e->stringify() );
    }
    catch Error::Simple with {
        $this->assert( 0, shift->stringify() );
    }
    otherwise {
        $this->assert( 0, "expected an oops redirect" );
    };
    $this->assert_equals( 1, scalar(@FoswikiFnTestCase::mails) );
    my $mess = $FoswikiFnTestCase::mails[0];
    $this->assert_matches(
        qr/"?$Foswiki::cfg{WebMasterName}"? <$Foswiki::cfg{WebMasterEmail}>/,
        $mess->header('From') );
    $this->assert_matches( qr/.*\bwhite\@example.com/, $mess->header('To') );

    $mess->body() =~ m/ChangePassword\?authtoken=([a-z0-9]{32}).*/ms;
    my $authToken = $1;
    $this->assert($authToken);
    $this->assert( ( -f "$Foswiki::cfg{WorkingDir}/tmp/tokenauth_$1" ) );

    $query = Unit::Request->new(
        {
            'authtoken' => [$1],
            'TopicName' => ['ChangePassword'],
            'password'  => ['yesimin!'],
            'passwordA' => ['yesimin!'],
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

sub test_resetPasswordByEmail {
    my $this = shift;

    my $cUID = $MrWhite;
    $this->assert( $this->{session}->{users}->userExists($cUID),
        " $cUID does not exist?" );

    my @emails = $this->{session}->{users}->getEmails($cUID);
    $this->assert_str_equals( $MrWhiteEmail, $emails[0] );

    @FoswikiFnTestCase::mails = ();

    my $query = Unit::Request->new(
        {
            'LoginName' => [$MrWhiteEmail],
            'TopicName' => ['ResetPassword'],
        }
    );

    $query->path_info( '/' . $this->{users_web} . '/UserRegistration' );
    $this->createNewFoswikiSession( $Foswiki::cfg{DefaultUserLogin}, $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    $Foswiki::cfg{TemplateLogin}{AllowLoginUsingEmailAddress} = 0;

    try {
        Foswiki::Plugins::PasswordManagementPlugin::Core::_RESTresetPassword(
            $this->{session} );
    }
    catch Foswiki::AccessControlException with {
        my $e = shift;
        $this->assert( 0, $e->stringify );
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( 'password', $e->{template}, $e->stringify() );
        $this->assert_str_equals( "email_not_supported", $e->{def},
            $e->stringify() );
    }
    catch Error::Simple with {
        $this->assert( 0, shift->stringify() );
    }
    otherwise {
        $this->assert( 0, "expected an oops redirect" );
    };
    $this->assert_equals( 0, scalar(@FoswikiFnTestCase::mails) );

    $Foswiki::cfg{TemplateLogin}{AllowLoginUsingEmailAddress} = 1;

    try {
        Foswiki::Plugins::PasswordManagementPlugin::Core::_RESTresetPassword(
            $this->{session} );
    }
    catch Foswiki::AccessControlException with {
        my $e = shift;
        $this->assert( 0, $e->stringify );
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( 'password', $e->{template}, $e->stringify() );
        $this->assert_str_equals( "reset_ok", $e->{def},      $e->stringify() );
    }
    catch Error::Simple with {
        $this->assert( 0, shift->stringify() );
    }
    otherwise {
        $this->assert( 0, "expected an oops redirect" );
    };
    $this->assert_equals( 1, scalar(@FoswikiFnTestCase::mails) );

    my $mess = $FoswikiFnTestCase::mails[0];
    $this->assert_matches(
        qr/"?$Foswiki::cfg{WebMasterName}"? <$Foswiki::cfg{WebMasterEmail}>/,
        $mess->header('From') );
    $this->assert_matches( qr/.*\bwhite\@example.com/, $mess->header('To') );

    $mess->body() =~ m/ChangePassword\?authtoken=([a-z0-9]{32}).*/ms;
    my $authToken = $1;
    $this->assert($authToken);
    $this->assert( ( -f "$Foswiki::cfg{WorkingDir}/tmp/tokenauth_$1" ) );

    return;
}

sub test_resetPasswordNoSuchUser {
    my $this = shift;

    # This time we don't set up the testWikiName, so it should fail.

    my $query = Unit::Request->new(
        {
            'LoginName' => ['NotAUser'],
            'TopicName' => ['ResetPassword'],
        }
    );

    @FoswikiFnTestCase::mails = ();

    $query->path_info( '/.' . $Foswiki::cfg{SystemWebName} . '/ResetPassword' );
    $this->createNewFoswikiSession( $Foswiki::cfg{DefaultUserLogin}, $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        Foswiki::Plugins::PasswordManagementPlugin::Core::_RESTresetPassword(
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

sub test_resetPasswordUserNotEntered {
    my $this = shift;

    # This time we don't set up the testWikiName, so it should fail.

    my $query = Unit::Request->new(
        {
            'LoginName' => [''],
            'TopicName' => ['ResetPassword'],
        }
    );

    @FoswikiFnTestCase::mails = ();

    $query->path_info( '/.' . $Foswiki::cfg{SystemWebName} . '/ResetPassword' );
    $this->createNewFoswikiSession( $Foswiki::cfg{DefaultUserLogin}, $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        Foswiki::Plugins::PasswordManagementPlugin::Core::_RESTresetPassword(
            $this->{session} );
    }
    catch Foswiki::AccessControlException with {
        my $e = shift;
        $this->assert( 0, $e->stringify );

    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( 'password', $e->{template}, $e->stringify() );
        $this->assert_str_equals( "no_users_to_reset", $e->{def},
            $e->stringify() );

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

sub test_resetPasswordMultipleUsers {
    my $this = shift;

    # This time we don't set up the testWikiName, so it should fail.

    my $query = Unit::Request->new(
        {
            'LoginName' => [ $MrWhite, $MrGreen ],
            'TopicName' => ['ResetPassword'],
        }
    );

    @FoswikiFnTestCase::mails = ();

    $query->path_info( '/.' . $Foswiki::cfg{SystemWebName} . '/ResetPassword' );
    $this->createNewFoswikiSession( $Foswiki::cfg{DefaultUserLogin}, $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        Foswiki::Plugins::PasswordManagementPlugin::Core::_RESTresetPassword(
            $this->{session} );
    }
    catch Foswiki::AccessControlException with {
        my $e = shift;
        $this->assert( 0, $e->stringify );

    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( 'password', $e->{template}, $e->stringify() );
        $this->assert_str_equals( "reset_ok", $e->{def},      $e->stringify() );

    }
    catch Error::Simple with {
        $this->assert( 0, shift->stringify() );
    }
    otherwise {
        $this->assert( 0, "expected an oops redirect" );
    };

    # Only the first user is reset.
    $this->assert_equals( 1, scalar(@FoswikiFnTestCase::mails) );

    my $mess = $FoswikiFnTestCase::mails[0];
    $this->assert_matches(
        qr/"?$Foswiki::cfg{WebMasterName}"? <$Foswiki::cfg{WebMasterEmail}>/,
        $mess->header('From') );
    $this->assert_matches( qr/.*\bwhite\@example.com/, $mess->header('To') );

    $mess->body() =~ m/ChangePassword\?authtoken=([a-z0-9]{32}).*/ms;
    my $authToken = $1;
    $this->assert($authToken);
    $this->assert( ( -f "$Foswiki::cfg{WorkingDir}/tmp/tokenauth_$1" ) );

    @FoswikiFnTestCase::mails = ();
    try {
        Foswiki::Plugins::PasswordManagementPlugin::Core::_RESTbulkResetPassword(
            $this->{session} );
    }
    catch Foswiki::AccessControlException with {
        my $e = shift;
        $this->assert( 0, $e->stringify );

    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( 'password', $e->{template}, $e->stringify() );
        $this->assert_str_equals( 'bulk_not_admin', $e->{def},
            $e->stringify() );

    }
    catch Error::Simple with {
        $this->assert( 0, shift->stringify() );
    }
    otherwise {
        $this->assert( 0, "expected an oops redirect" );
    };

    # Only the first user is reset.
    $this->assert_equals( 0, scalar(@FoswikiFnTestCase::mails) );

    $query = Unit::Request->new(
        {
            'resetUsers' => [ $MrWhite, $MrGreen ],
            'TopicName'  => ['ResetPassword'],
        }
    );

    $query->path_info( '/' . $this->{users_web} . '/UserRegistration' );
    $this->createNewFoswikiSession( $Foswiki::cfg{AdminUserLogin}, $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        Foswiki::Plugins::PasswordManagementPlugin::Core::_RESTbulkResetPassword(
            $this->{session} );
    }
    catch Foswiki::AccessControlException with {
        my $e = shift;
        $this->assert( 0, $e->stringify );

    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( 'password', $e->{template}, $e->stringify() );
        $this->assert_str_equals( 'reset_ok', $e->{def},      $e->stringify() );

    }
    catch Error::Simple with {
        $this->assert( 0, shift->stringify() );
    }
    otherwise {
        $this->assert( 0, "expected an oops redirect" );
    };

    # Only the first user is reset.
    $this->assert_equals( 2, scalar(@FoswikiFnTestCase::mails) );

    return;
}

# This test make sure that the system can't reset passwords
# for a user currently absent from .htpasswd
sub test_resetPasswordNoPassword {
    my $this = shift;

    # This time we don't set up the testWikiName, so it should fail.

    my $query = Unit::Request->new(
        {
            'LoginName' => ['NotAUser'],
            'TopicName' => ['ResetPassword'],
        }
    );

    my $fh;
    open( $fh, ">:encoding(utf-8)", $Foswiki::cfg{Htpasswd}{FileName} )
      || die $!;
    close($fh) || die $!;

    @FoswikiFnTestCase::mails = ();

    $query->path_info( '/.' . $Foswiki::cfg{SystemWebName} . '/ResetPassword' );
    $this->createNewFoswikiSession( $Foswiki::cfg{DefaultUserLogin}, $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        Foswiki::Plugins::PasswordManagementPlugin::Core::_RESTresetPassword(
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

#test for TWikibug:Item3400
sub test_resetPasswordNoWikiUsersEntry {
    my $this = shift;

    my $query = Unit::Request->new(
        {
            'LoginName' => [$MrWhite],
            'TopicName' => ['ResetPassword'],
        }
    );

    #Remove the WikiUsers entry - by deleting it :)
    my ($from) = Foswiki::Func::readTopic( $Foswiki::cfg{UsersWebName},
        $Foswiki::cfg{UsersTopicName} );
    my ($to) = Foswiki::Func::readTopic( $Foswiki::cfg{UsersWebName},
        $Foswiki::cfg{UsersTopicName} . 'DELETED' );
    $from->move($to);
    $from->finish();
    $to->finish();

    @FoswikiFnTestCase::mails = ();

    $query->path_info( '/.' . $Foswiki::cfg{SystemWebName} . '/ResetPassword' );
    $this->createNewFoswikiSession( $Foswiki::cfg{DefaultUserLogin}, $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    $this->assert( $this->{session}->{users}->userExists($MrWhite),
        " $MrWhite does not exist?" );

    try {
        Foswiki::Plugins::PasswordManagementPlugin::Core::_RESTresetPassword(
            $this->{session} );
    }
    catch Foswiki::AccessControlException with {
        my $e = shift;
        $this->assert( 0, $e->stringify );

    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( 'password', $e->{template}, $e->stringify() );
        $this->assert_str_equals( "reset_ok", $e->{def},      $e->stringify() );

    }
    catch Error::Simple with {
        $this->assert( 0, shift->stringify() );
    }
    otherwise {
        $this->assert( 0, "expected an oops redirect" );
    };

    $this->assert_equals( 1, scalar(@FoswikiFnTestCase::mails) );

    return;
}

1;
