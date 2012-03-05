#TODO: permission tests
#TODO: non-existant user test
package ManageDotPmTests;

use strict;
use warnings;
use diagnostics;

use FoswikiFnTestCase();
our @ISA = qw( FoswikiFnTestCase );
use Foswiki();
use Foswiki::UI::Manage();
use Foswiki::UI::Save();
use FileHandle();
use Error qw(:try);

#$Error::Debug = 1;

my $REG_UI_FN;
my $MAN_UI_FN;

# Set up the test fixture
sub set_up {
    my $this = shift;
    $this->SUPER::set_up();

    $REG_UI_FN ||= $this->getUIFn('register');
    $MAN_UI_FN ||= $this->getUIFn('manage');

    @FoswikiFnTestCase::mails = ();

    return;
}

sub tear_down {
    my $this = shift;

    $this->removeWebFixture( $this->{session}, "$this->{test_web}NewExtra" )
      if ( $this->{session}->webExists("$this->{test_web}NewExtra") );
    $this->removeWebFixture( $this->{session},
        "$this->{test_web}EmptyNewExtra" )
      if ( $this->{session}->webExists("$this->{test_web}EmptyNewExtra") );

    $this->SUPER::tear_down();

    return;
}

###################################
#verify tests

sub AllowLoginName {
    my $this = shift;
    $Foswiki::cfg{Register}{AllowLoginName} = 1;

    return;
}

sub DontAllowLoginName {
    my $this = shift;
    $Foswiki::cfg{Register}{AllowLoginName} = 0;
    $this->{new_user_login} = $this->{new_user_wikiname};

    #$this->{test_user_login} = $this->{test_user_wikiname};

    return;
}

sub TemplateLoginManager {
    $Foswiki::cfg{LoginManager} = 'Foswiki::LoginManager::TemplateLogin';

    return;
}

sub ApacheLoginManager {
    $Foswiki::cfg{LoginManager} = 'Foswiki::LoginManager::ApacheLogin';

    return;
}

sub NoLoginManager {
    $Foswiki::cfg{LoginManager} = 'Foswiki::LoginManager';

    return;
}

sub HtPasswdManager {
    $Foswiki::cfg{PasswordManager} = 'Foswiki::Users::HtPasswdUser';

    return;
}

sub NonePasswdManager {
    $Foswiki::cfg{PasswordManager} = 'none';

    return;
}

sub BaseUserMapping {
    my $this = shift;
    $Foswiki::cfg{UserMappingManager} = 'Foswiki::Users::BaseUserMapping';
    $this->set_up_for_verify();

    return;
}

sub TopicUserMapping {
    my $this = shift;
    $Foswiki::cfg{UserMappingManager} = 'Foswiki::Users::TopicUserMapping';
    $this->set_up_for_verify();

    return;
}

# See the pod doc in Unit::TestCase for details of how to use this
sub fixture_groups {
    return (

   #        [ 'TemplateLoginManager', 'ApacheLoginManager', 'NoLoginManager', ],
        [ 'AllowLoginName', 'DontAllowLoginName', ],
        [
            'HtPasswdManager',

            #'NonePasswdManager',
        ],
        [
            'TopicUserMapping',

            #'BaseUserMapping',
        ]
    );
}

#delay the calling of set_up til after the cfg's are set by above closure
sub set_up_for_verify {
    my $this = shift;

    $this->createNewFoswikiSession();

    @FoswikiFntestCase::mails = ();

    return;
}

# Register a user using Fwk prefix in the forms
sub registerUserExceptionFwk {
    my ( $this, @args ) = @_;
    $this->_registerUserException( 'Fwk', @args );

    return;
}

# Register a user using Twk prefix in the forms
sub registerUserExceptionTwk {
    my ( $this, @args ) = @_;
    $this->_registerUserException( 'Twk', @args );

    return;
}

#to simplify registration
#SMELL: why are we not re-using code like this
#SMELL: or the verify code... this would benefit from reusing the mixing of mappers and other settings.
sub _registerUserException {
    my ( $this, $pfx, $loginname, $forename, $surname, $email ) = @_;

    my $query = Unit::Request->new(
        {
            'TopicName'        => ['UserRegistration'],
            "${pfx}1Email"     => [$email],
            "${pfx}1WikiName"  => ["$forename$surname"],
            "${pfx}1Name"      => ["$forename $surname"],
            "${pfx}0Comment"   => [''],
            "${pfx}1LoginName" => [$loginname],
            "${pfx}1FirstName" => [$forename],
            "${pfx}1LastName"  => [$surname],
            'action'           => ['register']
        }
    );

    $query->path_info("/$this->{users_web}/UserRegistration");
    $this->createNewFoswikiSession( undef, $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );
    my $exception;
    try {
        $this->captureWithKey( register => $REG_UI_FN, $this->{session} );
    }
    catch Foswiki::OopsException with {
        $exception = shift;
        if (   ( "attention" eq $exception->{template} )
            && ( "thanks" eq $exception->{def} ) )
        {

            print STDERR "---------" . $exception->stringify() . "\n"
              if ($Error::Debug);
            $exception = undef;    #the only correct answer
        }
    }
    catch Foswiki::AccessControlException with {
        $exception = shift;
    }
    catch Error::Simple with {
        $exception = shift;
    }
    otherwise {
        $exception = Error::Simple->new();
    };

    # Reload caches
    my $q = $this->{request};
    $this->createNewFoswikiSession( undef, $q );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    return $exception;
}

sub addUserToGroup {
    my ( $this, @args ) = @_;

    #my $queryHash = shift;

    my $query = Unit::Request->new(@args);

    $query->path_info("/$this->{users_web}/WikiGroups");
    $this->createNewFoswikiSession( undef, $query );

    my ( $responseText, $result, $stdout, $stderr );

    my $exception;
    try {
        no strict 'refs';
        ( $responseText, $result, $stdout, $stderr ) = $this->captureWithKey(
            manage => $this->getUIFn('manage'),
            $this->{session}
        );
        no strict 'refs';
    }
    catch Foswiki::OopsException with {
        $exception = shift;
        print STDERR "---------" . $exception->stringify() . "\n"
          if ($Error::Debug);
        if (   ( "attention" eq $exception->{template} )
            && ( "added_users_to_group" eq $exception->{def} ) )
        {

            #TODO: confirm that that onle the expected group and user is created
            undef $exception;    #the only correct answer
        }
    }
    catch Foswiki::AccessControlException with {
        $exception = shift;
        print STDERR "---------2 " . $exception->stringify() . "\n"
          if ($Error::Debug);
    }
    catch Error::Simple with {
        $exception = shift;
        print STDERR "---------3 " . $exception->stringify() . "\n"
          if ($Error::Debug);
    }
    otherwise {
        print STDERR "--------- otherwise\n" if ($Error::Debug);
        $exception = Error::Simple->new();
    };
    print STDERR $responseText || '';
    return $exception;
}

sub removeUserFromGroup {
    my ( $this, @args ) = @_;

    #my $queryHash = shift;

    my $query = Unit::Request->new(@args);

    $query->path_info("/$this->{users_web}/WikiGroups");
    $this->createNewFoswikiSession( undef, $query );

    my $exception;
    try {
        no strict 'refs';
        $this->captureWithKey(
            manage => $this->getUIFn('manage'),
            $this->{session}
        );
        no strict 'refs';
    }
    catch Foswiki::OopsException with {
        $exception = shift;
        print STDERR "---------" . $exception->stringify() . "\n"
          if ($Error::Debug);
        if (   ( "attention" eq $exception->{template} )
            && ( "removed_users_from_group" eq $exception->{def} ) )
        {

            #TODO: confirm that that onle the expected group and user is created
            undef $exception;    #the only correct answer
        }
    }
    catch Foswiki::AccessControlException with {
        $exception = shift;
        print STDERR "---------2 " . $exception->stringify() . "\n"
          if ($Error::Debug);
    }
    catch Error::Simple with {
        $exception = shift;
        print STDERR "---------3 " . $exception->stringify() . "\n"
          if ($Error::Debug);
    }
    otherwise {
        print STDERR "--------- otherwise\n" if ($Error::Debug);
        $exception = Error::Simple->new();
    };
    return $exception;
}

sub test_SingleAddToNewGroupCreate {
    my $this = shift;
    my $ret;

    $ret = $this->registerUserExceptionTwk( 'asdf', 'Asdf', 'Poiu',
        'asdf@example.com' );
    $this->assert_null( $ret, "Simple rego should work" );

    $ret = $this->addUserToGroup(
        {
            'username'  => ['AsdfPoiu'],
            'groupname' => ['NewGroup'],
            'create'    => [1],
            'action'    => ['addUserToGroup']
        }
    );
    $this->assert_null( $ret, "Simple add to new group" );

    $this->assert(
        Foswiki::Func::topicExists( $this->{users_web}, "NewGroup" ) );
    $this->assert( Foswiki::Func::isGroupMember( "NewGroup", "AsdfPoiu" ) );

    #need to reload to force Foswiki to reparse Groups :(
    my $q = $this->{request};
    $this->createNewFoswikiSession( undef, $q );

    $this->assert(
        Foswiki::Func::topicExists( $this->{users_web}, "NewGroup" ) );

#SMELL: (maybe) yes, at the moment, the currently logged in user _is_ also added to the group - this ensures that they are able to complete the operation - as we're saving once per user
    $this->assert(
        Foswiki::Func::isGroupMember( "NewGroup", $this->{session}->{user} ) );
    $this->assert( Foswiki::Func::isGroupMember( "NewGroup", "AsdfPoiu" ) );

    return;
}

sub test_DoubleAddToNewGroupCreate {
    my $this = shift;
    my $ret;

    $ret = $this->registerUserExceptionTwk( 'asdf', 'Asdf', 'Poiu',
        'asdf@example.com' );
    $this->assert_null( $ret, "Simple rego should work" );
    $ret = $this->registerUserExceptionFwk( 'qwer', 'Qwer', 'Poiu',
        'qwer@example.com' );
    $this->assert_null( $ret, "Simple rego should work" );
    $ret = $this->registerUserExceptionTwk( 'zxcv', 'Zxcv', 'Poiu',
        'zxcv@example.com' );
    $this->assert_null( $ret, "Simple rego should work" );

    $ret = $this->addUserToGroup(
        {
            'username'  => [ 'AsdfPoiu', 'QwerPoiu' ],
            'groupname' => ['NewGroup'],
            'create'    => [1],
            'action'    => ['addUserToGroup']
        }
    );
    $this->assert_null( $ret, "Simple add to new group" );

    $this->assert(
        Foswiki::Func::topicExists( $this->{users_web}, "NewGroup" ) );
    $this->assert( Foswiki::Func::isGroupMember( "NewGroup", "AsdfPoiu" ) );
    $this->assert( Foswiki::Func::isGroupMember( "NewGroup", "QwerPoiu" ) );
    $this->assert( !Foswiki::Func::isGroupMember( "NewGroup", "ZxcvPoiu" ) );

    #need to reload to force Foswiki to reparse Groups :(
    my $q = $this->{request};
    $this->createNewFoswikiSession( undef, $q );

    $this->assert(
        Foswiki::Func::topicExists( $this->{users_web}, "NewGroup" ) );

#SMELL: (maybe) yes, at the moment, the currently logged in user _is_ also added to the group - this ensures that they are able to complete the operation - as we're saving once per user
    $this->assert(
        Foswiki::Func::isGroupMember( "NewGroup", $this->{session}->{user} ) );
    $this->assert( Foswiki::Func::isGroupMember( "NewGroup", "AsdfPoiu" ) );
    $this->assert( Foswiki::Func::isGroupMember( "NewGroup", "QwerPoiu" ) );
    $this->assert( !Foswiki::Func::isGroupMember( "NewGroup", "ZxcvPoiu" ) );

    return;
}

sub test_TwiceAddToNewGroupCreate {
    my $this = shift;
    my $ret;

    $ret = $this->registerUserExceptionTwk( 'asdf', 'Asdf', 'Poiu',
        'asdf@example.com' );
    $this->assert_null( $ret, "Simple rego should work" );
    $ret = $this->registerUserExceptionFwk( 'qwer', 'Qwer', 'Poiu',
        'qwer@example.com' );
    $this->assert_null( $ret, "Simple rego should work" );
    $ret = $this->registerUserExceptionTwk( 'zxcv', 'Zxcv', 'Poiu',
        'zxcv@example.com' );
    $this->assert_null( $ret, "Simple rego should work" );
    $ret = $this->registerUserExceptionFwk( 'zxcv2', 'Zxcv', 'Poiu2',
        'zxcv@2example.com' );
    $this->assert_null( $ret, "Simple rego should work" );
    $ret = $this->registerUserExceptionTwk( 'zxcv3', 'Zxcv', 'Poiu3',
        'zxcv3@example.com' );
    $this->assert_null( $ret, "Simple rego should work" );
    $ret = $this->registerUserExceptionFwk( 'zxcv4', 'Zxcv', 'Poiu4',
        'zxcv4@example.com' );
    $this->assert_null( $ret, "Simple rego should work" );

    $ret = $this->addUserToGroup(
        {
            'username'  => [ $this->{session}->{user} ],
            'groupname' => ['NewGroup'],
            'create'    => [1],
            'action'    => ['addUserToGroup']
        }
    );
    $this->assert_null( $ret, "add myself" );

    $this->assert(
        Foswiki::Func::topicExists( $this->{users_web}, "NewGroup" ) );
    $this->assert( !Foswiki::Func::isGroupMember( "NewGroup", "AsdfPoiu" ) );
    $this->assert( !Foswiki::Func::isGroupMember( "NewGroup", "QwerPoiu" ) );
    $this->assert( !Foswiki::Func::isGroupMember( "NewGroup", "ZxcvPoiu" ) );

    #need to reload to force Foswiki to reparse Groups :(
    my $q = $this->{request};
    $this->createNewFoswikiSession( undef, $q );

    $this->assert(
        Foswiki::Func::topicExists( $this->{users_web}, "NewGroup" ) );

#SMELL: (maybe) yes, at the moment, the currently logged in user _is_ also added to the group - this ensures that they are able to complete the operation - as we're saving once per user
    $this->assert(
        Foswiki::Func::isGroupMember( "NewGroup", $this->{session}->{user} ) );
    $this->assert( !Foswiki::Func::isGroupMember( "NewGroup", "AsdfPoiu" ) );
    $this->assert( !Foswiki::Func::isGroupMember( "NewGroup", "QwerPoiu" ) );
    $this->assert( !Foswiki::Func::isGroupMember( "NewGroup", "ZxcvPoiu" ) );

    $ret = $this->addUserToGroup(
        {
            'username'  => ["AsdfPoiu"],
            'groupname' => ['NewGroup'],
            'create'    => [],
            'action'    => ['addUserToGroup']
        }
    );
    $this->assert_null( $ret, "second add user" );

    $this->assert(
        Foswiki::Func::topicExists( $this->{users_web}, "NewGroup" ) );
    $this->assert( Foswiki::Func::isGroupMember( "NewGroup", "AsdfPoiu" ) );
    $this->assert( !Foswiki::Func::isGroupMember( "NewGroup", "QwerPoiu" ) );
    $this->assert( !Foswiki::Func::isGroupMember( "NewGroup", "ZxcvPoiu" ) );

    #need to reload to force Foswiki to reparse Groups :(
    $q = $this->{request};
    $this->createNewFoswikiSession( undef, $q );

    $this->assert(
        Foswiki::Func::topicExists( $this->{users_web}, "NewGroup" ) );

#SMELL: (maybe) yes, at the moment, the currently logged in user _is_ also added to the group - this ensures that they are able to complete the operation - as we're saving once per user
    $this->assert(
        Foswiki::Func::isGroupMember( "NewGroup", $this->{session}->{user} ) );
    $this->assert( Foswiki::Func::isGroupMember( "NewGroup", "AsdfPoiu" ) );
    $this->assert( !Foswiki::Func::isGroupMember( "NewGroup", "QwerPoiu" ) );
    $this->assert( !Foswiki::Func::isGroupMember( "NewGroup", "ZxcvPoiu" ) );

    $ret = $this->addUserToGroup(
        {
            'username' =>
              [ "QwerPoiu", "ZxcvPoiu", "ZxcvPoiu2", "ZxcvPoiu3", "ZxcvPoiu4" ],
            'groupname' => ['NewGroup'],
            'create'    => [],
            'action'    => ['addUserToGroup']
        }
    );
    $this->assert_null( $ret, "third add user" );

    $this->assert(
        Foswiki::Func::topicExists( $this->{users_web}, "NewGroup" ) );
    $this->assert( Foswiki::Func::isGroupMember( "NewGroup", "AsdfPoiu" ) );
    $this->assert( Foswiki::Func::isGroupMember( "NewGroup", "QwerPoiu" ) );
    $this->assert( Foswiki::Func::isGroupMember( "NewGroup", "ZxcvPoiu" ) );

    #need to reload to force Foswiki to reparse Groups :(
    $q = $this->{request};
    $this->createNewFoswikiSession( undef, $q );

    $this->assert(
        Foswiki::Func::topicExists( $this->{users_web}, "NewGroup" ) );

#SMELL: (maybe) yes, at the moment, the currently logged in user _is_ also added to the group - this ensures that they are able to complete the operation - as we're saving once per user
    $this->assert(
        Foswiki::Func::isGroupMember( "NewGroup", $this->{session}->{user} ) );
    $this->assert( Foswiki::Func::isGroupMember( "NewGroup", "AsdfPoiu" ) );
    $this->assert( Foswiki::Func::isGroupMember( "NewGroup", "QwerPoiu" ) );
    $this->assert( Foswiki::Func::isGroupMember( "NewGroup", "ZxcvPoiu" ) );
    $this->assert( Foswiki::Func::isGroupMember( "NewGroup", "ZxcvPoiu2" ) );
    $this->assert( Foswiki::Func::isGroupMember( "NewGroup", "ZxcvPoiu3" ) );
    $this->assert( Foswiki::Func::isGroupMember( "NewGroup", "ZxcvPoiu4" ) );

    $ret = $this->removeUserFromGroup(
        {
            'username'  => ["ZxcvPoiu4"],
            'groupname' => ['NewGroup'],
            'action'    => ['removeUserFromGroup']
        }
    );
    $this->assert_null( $ret, "remove one user" );
    $this->assert( !Foswiki::Func::isGroupMember( "NewGroup", "ZxcvPoiu4" ) );

    #need to reload to force Foswiki to reparse Groups :(
    $q = $this->{request};
    $this->createNewFoswikiSession( undef, $q );
    $this->assert( Foswiki::Func::isGroupMember( "NewGroup", "ZxcvPoiu2" ) );
    $this->assert( Foswiki::Func::isGroupMember( "NewGroup", "ZxcvPoiu3" ) );
    $this->assert( !Foswiki::Func::isGroupMember( "NewGroup", "ZxcvPoiu4" ) );

    $ret = $this->removeUserFromGroup(
        {
            'username'  => [ "ZxcvPoiu", "ZxcvPoiu2" ],
            'groupname' => ['NewGroup'],
            'action'    => ['removeUserFromGroup']
        }
    );
    $this->assert_null( $ret, "remove two user" );
    $this->assert( !Foswiki::Func::isGroupMember( "NewGroup", "ZxcvPoiu" ) );
    $this->assert( !Foswiki::Func::isGroupMember( "NewGroup", "ZxcvPoiu2" ) );

    #need to reload to force Foswiki to reparse Groups :(
    $q = $this->{request};
    $this->createNewFoswikiSession( undef, $q );
    $this->assert( !Foswiki::Func::isGroupMember( "NewGroup", "ZxcvPoiu" ) );
    $this->assert( !Foswiki::Func::isGroupMember( "NewGroup", "ZxcvPoiu2" ) );
    $this->assert( Foswiki::Func::isGroupMember( "NewGroup", "ZxcvPoiu3" ) );
    $this->assert( !Foswiki::Func::isGroupMember( "NewGroup", "ZxcvPoiu4" ) );

    return;
}

###########################################################################
#totoal failure type tests..
sub test_SingleAddToNewGroupNoCreate {
    my $this = shift;
    my $ret;

    $ret = $this->registerUserExceptionTwk( 'asdf', 'Asdf', 'Poiu',
        'asdf@example.com' );
    $this->assert_null( $ret, "Simple rego should work" );

    $ret = $this->addUserToGroup(
        {
            'username'  => ['AsdfPoiu'],
            'groupname' => ['AnotherNewGroup'],
            'create'    => [0],
            'action'    => ['addUserToGroup']
        }
    );
    $this->assert_not_null( $ret,
        "can't add to new group without setting create" );

    #SMELL: TopicUserMapping specific - we don't refresh Groups cache :(
    $this->assert(
        !Foswiki::Func::topicExists( $this->{users_web}, "AnotherNewGroup" ) );
    $this->assert( !Foswiki::Func::isGroupMember( "NewGroup", "AsdfPoiu" ) );

    #need to reload to force Foswiki to reparse Groups :(
    my $q = $this->{request};
    $this->createNewFoswikiSession( undef, $q );

    $this->assert(
        !Foswiki::Func::topicExists( $this->{users_web}, "AnotherNewGroup" ) );
    $this->assert( !Foswiki::Func::isGroupMember( "NewGroup", "AsdfPoiu" ) );

    return;
}

sub test_NoUserAddToNewGroupCreate {
    my $this = shift;
    my $ret;

    $ret = $this->addUserToGroup(
        {
            'username'  => [],
            'groupname' => ['NewGroup'],
            'create'    => [1],
            'action'    => ['addUserToGroup']
        }
    );

    #SMELL: TopicUserMapping specific - we don't refresh Groups cache :(
    $this->assert(
        Foswiki::Func::topicExists( $this->{users_web}, "NewGroup" ) );

    #need to reload to force Foswiki to reparse Groups :(
    my $q = $this->{request};
    $this->createNewFoswikiSession( undef, $q );

    $this->assert(
        Foswiki::Func::topicExists( $this->{users_web}, "NewGroup" ) );

    # If not running as admin, current user is automatically added to the group.
    $this->assert(
        Foswiki::Func::isGroupMember( "NewGroup", $this->{session}->{user} ) );

    return;
}

sub test_NoUserAddToNewGroupCreateAsAdmin {
    my $this = shift;
    my $ret;

    my $query = $this->{request};
    $this->createNewFoswikiSession( $Foswiki::cfg{AdminUserWikiName}, $query );

    $ret = $this->addUserToGroup(
        {
            'username'  => [],
            'groupname' => ['NewGroup'],
            'create'    => [1],
            'action'    => ['addUserToGroup']
        }
    );

    #SMELL: TopicUserMapping specific - we don't refresh Groups cache :(
    $this->assert(
        Foswiki::Func::topicExists( $this->{users_web}, "NewGroup" ) );

    #need to reload to force Foswiki to reparse Groups :(
    $this->createNewFoswikiSession( undef, $query );

    $this->assert(
        Foswiki::Func::topicExists( $this->{users_web}, "NewGroup" ) );

    # If running as admin, no user is automatically added to the group.
    $this->assert(
        !Foswiki::Func::isGroupMember(
            "NewGroup", $Foswiki::cfg{AdminUserWikiName}
        )
    );

    return;
}

sub test_RemoveFromNonExistantGroup {
    my $this = shift;
    my $ret;

    $ret = $this->registerUserExceptionTwk( 'asdf', 'Asdf', 'Poiu',
        'asdf@example.com' );
    $this->assert_null( $ret, "Simple rego should work" );

    $ret = $this->removeUserFromGroup(
        {
            'username'  => ['AsdfPoiu'],
            'groupname' => ['AnotherNewGroup'],
            'action'    => ['removeUserFromGroup']
        }
    );
    $this->assert_not_null( $ret, "there ain't any such group" );
    $this->assert_equals( $ret->{template}, "attention" );
    $this->assert_equals( $ret->{def},      "problem_removing_from_group" );

    #SMELL: TopicUserMapping specific - we don't refresh Groups cache :(
    $this->assert(
        !Foswiki::Func::topicExists( $this->{users_web}, "AnotherNewGroup" ) );
    $this->assert( !Foswiki::Func::isGroupMember( "NewGroup", "AsdfPoiu" ) );

    #need to reload to force Foswiki to reparse Groups :(
    my $q = $this->{request};
    $this->createNewFoswikiSession( undef, $q );

    $this->assert(
        !Foswiki::Func::topicExists( $this->{users_web}, "AnotherNewGroup" ) );
    $this->assert( !Foswiki::Func::isGroupMember( "NewGroup", "AsdfPoiu" ) );

    return;
}

sub test_RemoveNoUserFromExistantGroup {
    my $this = shift;
    my $ret;

    $ret = $this->registerUserExceptionFwk( 'asdf', 'Asdf', 'Poiu',
        'asdf@example.com' );
    $this->assert_null( $ret, "Simple rego should work" );

    $ret = $this->removeUserFromGroup(
        {
            'username'  => [],
            'groupname' => ['AnotherNewGroup'],
            'action'    => ['removeUserFromGroup']
        }
    );
    $this->assert_not_null( $ret, "no user.." );
    $this->assert_equals( $ret->{template}, "attention" );
    $this->assert_equals( $ret->{def},      "no_users_to_remove_from_group" );

    #SMELL: TopicUserMapping specific - we don't refresh Groups cache :(
    $this->assert(
        !Foswiki::Func::topicExists( $this->{users_web}, "AnotherNewGroup" ) );
    $this->assert( !Foswiki::Func::isGroupMember( "NewGroup", "AsdfPoiu" ) );

    #need to reload to force Foswiki to reparse Groups :(
    my $q = $this->{request};
    $this->createNewFoswikiSession( undef, $q );

    $this->assert(
        !Foswiki::Func::topicExists( $this->{users_web}, "AnotherNewGroup" ) );
    $this->assert( !Foswiki::Func::isGroupMember( "NewGroup", "AsdfPoiu" ) );

    return;
}

sub verify_resetEmailOkay {
    my $this = shift;

    ## Need to create an account (else oopsnotwikiuser)
    ### with a known email address (else oopsregemail)
    ### need to know the password too
    my $ret = $this->registerUserExceptionTwk( 'brian', 'Brian', 'Griffin',
        'brian@example.com' );
    $this->assert_null( $ret, "Simple rego should work" );

    my $cUID = $this->{session}->{users}->getCanonicalUserID('brian');
    $this->assert( $this->{session}->{users}->userExists($cUID),
        "new user created" );
    my $newPassU = '12345';
    my $oldPassU = 1;         #force set
    $this->assert(
        $this->{session}->{users}->setPassword( $cUID, $newPassU, $oldPassU ) );
    my $newEmail = 'brian@family.guy';

    my $query = Unit::Request->new(
        {
            'LoginName'   => ['brian'],
            'TopicName'   => ['ChangeEmailAddress'],
            'username'    => ['brian'],
            'oldpassword' => ['12345'],
            'email'       => [$newEmail],
            'action'      => ['changePassword']
        }
    );

    $query->path_info( '/' . $this->{users_web} . '/WebHome' );
    $this->createNewFoswikiSession( 'brian', $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );
    try {
        $this->captureWithKey( manage => $MAN_UI_FN, $this->{session} );
    }
    catch Foswiki::AccessControlException with {
        my $e = shift;
        $this->assert( 0, $e->stringify );
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( "attention", $e->{template},
            $e->stringify() );
        $this->assert_str_equals( "email_changed", $e->{def}, $e->stringify() );
        $this->assert_str_equals(
            $newEmail,
            ${ $e->{params} }[0],
            ${ $e->{params} }[0]
        );
    }
    catch Error::Simple with {
        $this->assert( 0, shift->stringify() );
    }
    otherwise {
        $this->assert( 0, "expected an oops redirect" );
    };

    my @emails = $this->{session}->{users}->getEmails($cUID);
    $this->assert_str_equals( $newEmail, $emails[0] );

    return;
}

sub verify_bulkRegister {
    my $this = shift;

    my $testReg = <<'EOM';
| FirstName | LastName | Email | WikiName | LoginName | CustomFieldThis | SomeOtherRandomField | WhateverYouLike |
| Test | User | Martin.Cleaver@BCS.org.uk |  TestBulkUser1 | a | A | B | C |
| Test | User2 | Martin.Cleaver@BCS.org.uk | TestBulkUser2 | b | A | B | C |
| Test | User3 | Martin.Cleaver@BCS.org.uk | TestBulkUser3 | c | A | B | C |
EOM

    my $regTopic = 'UnprocessedRegistrations2';

    my $logTopic = 'UnprocessedRegistrations2Log';
    my $file =
        $Foswiki::cfg{DataDir} . '/'
      . $this->{test_web} . '/'
      . $regTopic . '.txt';
    my $fh = FileHandle->new();

    die "Can't write $file" unless ( $fh->open(">$file") );
    print $fh $testReg;
    $fh->close;

    my $query = Unit::Request->new(
        {
            'LogTopic'              => [$logTopic],
            'EmailUsersWithDetails' => ['0'],
            'OverwriteHomeTopics'   => ['1'],
            'action'                => ['bulkRegister'],
        }
    );

    $query->path_info("/$this->{test_web}/$regTopic");
    $this->createNewFoswikiSession( $Foswiki::cfg{AdminUserWikiName}, $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );
    $this->{session}->{topicName} = $regTopic;
    $this->{session}->{webName}   = $this->{test_web};
    try {
        $this->captureWithKey( manage => $MAN_UI_FN, $this->{session} );
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert( 0, $e->stringify() . " UNEXPECTED" );

    }
    catch Error::Simple with {
        my $e = shift;
        $this->assert( 0, $e->stringify );

    }
    catch Foswiki::AccessControlException with {
        my $e = shift;
        $this->assert( 0, $e->stringify );

    }
    otherwise {
        $this->assert( 0, "expected an oops redirect" );
    };
    $this->assert_equals( 0, scalar(@FoswikiFnTestCase::mails) );

    return;
}

#in which a user correctly points out that the error checking is a bit minimal
sub verify_bulkRegister_Item2191 {
    my $this = shift;

    my $testReg = <<'EOM';
| Vorname  |	 Nachname  |	 Mailadresse  | WikiName | LoginName | CustomFieldThis | SomeOtherRandomField | WhateverYouLike |
| Test | User | Martin.Cleaver@BCS.org.uk |  TestBulkUser1 | a | A | B | C |
| Test | User2 | Martin.Cleaver@BCS.org.uk | TestBulkUser2 | b | A | B | C |
| Test | User3 | Martin.Cleaver@BCS.org.uk | TestBulkUser3 | c | A | B | C |
EOM

    my $regTopic = 'UnprocessedRegistrations2';

    my $logTopic = 'UnprocessedRegistrations2Log';
    my $file =
        $Foswiki::cfg{DataDir} . '/'
      . $this->{test_web} . '/'
      . $regTopic . '.txt';
    my $fh = FileHandle->new();

    die "Can't write $file" unless ( $fh->open(">$file") );
    print $fh $testReg;
    $fh->close;

    my $query = Unit::Request->new(
        {
            'LogTopic'              => [$logTopic],
            'EmailUsersWithDetails' => ['0'],
            'OverwriteHomeTopics'   => ['1'],
            'action'                => ['bulkRegister'],
        }
    );

    $query->path_info("/$this->{test_web}/$regTopic");
    $this->createNewFoswikiSession( $Foswiki::cfg{AdminUserWikiName}, $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );
    $this->{session}->{topicName} = $regTopic;
    $this->{session}->{webName}   = $this->{test_web};
    try {
        my ($text) = $this->captureWithKey(
            manage => $MAN_UI_FN,
            $this->{session}
        );

#TODO: um, really need to test what the output was, and
#TODO: test if a user was registered..
#$this->assert( '', $text);
#my $readMeta = Foswiki::Meta->load( $this->{session}, $this->{test_web}, 'TemporaryRegistrationTestWebRegistration/UnprocessedRegistrations2Log' );
#$this->assert( '', $readMeta->text());
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert( 0, $e->stringify() . " UNEXPECTED" );

    }
    catch Error::Simple with {
        my $e = shift;
        $this->assert( 0, $e->stringify );

    }
    catch Foswiki::AccessControlException with {
        my $e = shift;
        $this->assert( 0, $e->stringify );

    }
    otherwise {
        $this->assert( 0, "expected an oops redirect" );
    };
    $this->assert_equals( 0, scalar(@FoswikiFnTestCase::mails) );

    return;
}

sub verify_deleteUser {
    my $this = shift;
    my $ret  = $this->registerUserExceptionTwk( 'eric', 'Eric', 'Cartman',
        'eric@example.com' );
    $this->assert_null( $ret, "Respect mah authoritah" );

    my $cUID     = $this->{session}->{users}->getCanonicalUserID('eric');
    my $newPassU = '12345';
    my $oldPassU = 1;    #force set
    $this->assert(
        $this->{session}->{users}->setPassword( $cUID, $newPassU, $oldPassU ) );

    my $query = Unit::Request->new(
        {
            'password' => ['12345'],
            'action'   => ['deleteUserAccount'],
        }
    );
    $query->path_info("/$this->{test_web}/Arbitrary");
    $this->createNewFoswikiSession( 'eric', $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );
    $this->{session}->{topicName} = 'Arbitrary';
    $this->{session}->{webName}   = $this->{test_web};

    try {
        $this->captureWithKey( manage => $MAN_UI_FN, $this->{session} );
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( "attention", $e->{template},
            $e->stringify() );
        $this->assert_str_equals( "remove_user_done", $e->{def},
            $e->stringify() );
        my $johndoe = 'eric';
        if ( $Foswiki::cfg{Register}{AllowLoginName} ) {
            $johndoe = 'EricCartman';
        }
        $this->assert_str_equals(
            $johndoe,
            ${ $e->{params} }[0],
            ${ $e->{params} }[0]
        );
    }
    catch Error::Simple with {
        my $e = shift;
        $this->assert( 0, $e->stringify );

    }
    catch Foswiki::AccessControlException with {
        my $e = shift;
        $this->assert( 0, $e->stringify );

    }
    otherwise {
        $this->assert( 0, "expected an oops redirect" );
    };

    return;
}

sub test_createDefaultWeb {
    my $this   = shift;
    my $newWeb = $this->{test_web} . 'NewExtra';    #no, this is not nested
    my $query  = Unit::Request->new(
        {
            'action'  => ['createweb'],
            'baseweb' => ['_default'],

            #            'newtopic' => ['qwer'],            #TODO: er, what the?
            'newweb'      => [$newWeb],
            'nosearchall' => ['on'],
            'webbgcolor'  => ['fuchsia'],
            'websummary'  => ['twinkle twinkle little star'],
        }
    );
    $query->path_info("/$this->{test_web}/Arbitrary");

    # SMELL: Test fails unless the "user" is the AdminGroup.
    $this->createNewFoswikiSession( $Foswiki::cfg{SuperAdminGroup}, $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );
    $this->{session}->{topicName} = 'Arbitrary';
    $this->{session}->{webName}   = $this->{test_web};

    try {
        my ( $stdout, $stderr, $result ) =
          $this->captureWithKey( manage => $MAN_UI_FN, $this->{session} );
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( "attention", $e->{template},
            $e->stringify() );
        $this->assert_str_equals( "created_web", $e->{def}, $e->stringify() );
        print STDERR "captured STDERR: " . $this->{stderr} . "\n"
          if ( defined( $this->{stderr} ) );
    }
    catch Error::Simple with {
        my $e = shift;
        $this->assert( 0, $e->stringify );

    }
    catch Foswiki::AccessControlException with {
        my $e = shift;
        $this->assert( 0, $e->stringify );

    }
    otherwise {
        $this->assert( 0, "expected an oops redirect" );
    };

    #check that the settings we created with happened.
    $this->assert( $this->{session}->webExists($newWeb) );
    my $webObject = $this->getWebObject($newWeb);
    $this->assert_equals( 'fuchsia', $webObject->getPreference('WEBBGCOLOR') );
    $this->assert_equals( 'on',      $webObject->getPreference('SITEMAPLIST') );
    $webObject->finish();

#check that the topics from _default web are actually in the new web, and make sure they are expectently similar
    my @expectedTopicsItr = Foswiki::Func::getTopicList('_default');
    foreach my $expectedTopic (@expectedTopicsItr) {
        $this->assert( Foswiki::Func::topicExists( $newWeb, $expectedTopic ) );
        my ( $eMeta, $eText ) =
          Foswiki::Func::readTopic( '_default', $expectedTopic );
        $eMeta->finish();
        my ( $nMeta, $nText ) =
          Foswiki::Func::readTopic( $newWeb, $expectedTopic );
        $nMeta->finish();

   #change the params set above to what they were in the template WebPreferences
        $nText =~
          s/($Foswiki::regex{setRegex}WEBBGCOLOR\s*=).fuchsia$/$1 #DDDDDD/m;
        $this->assert( defined($1) );
        $nText =~
s/($Foswiki::regex{setRegex}WEBSUMMARY\s*=).twinkle twinkle little star$/$1 /m;
        $this->assert( defined($1) );
        $nText =~ s/($Foswiki::regex{setRegex}NOSEARCHALL\s*=).on$/$1 /m;
        $this->assert( defined($1) );

        $this->assert_html_equals( $eText, $nText )
          ;    #.($Foswiki::RELEASE =~ /1\.1\.0/?"\n":''));
    }

    return;
}

sub test_saveSettings_allowed {
    my $this = shift;

    # Create a test topic
    my ($testTopic) =
      Foswiki::Func::readTopic( $this->{test_web}, "SaveSettings" );
    $testTopic->text( <<'TEXT');
Philosophers, philosophers, everywhere,
   * Set TEXTSET = text set
   * Local TEXTLOCAL = text local
But never a one who thinks
%META:PREFERENCE{name="METASET" type="Set" value="meta set"}%
%META:PREFERENCE{name="METALOCAL" type="Local" value="meta local"}%
TEXT
    $testTopic->save();
    $testTopic->finish();

    my $query = Unit::Request->new(
        {
            'action'      => ['saveSettings'],
            'action_save' => ['Save'],
            'text' =>
"Ignore this line\n   * Set NEWSET = new set\n   * Local NEWLOCAL = new local\nIgnore that line",
            'originalrev' => 1
        }
    );
    $query->path_info("/$this->{test_web}/SaveSettings");
    $this->createNewFoswikiSession( $this->{test_user_login}, $query );
    try {
        my ( $stdout, $stderr, $result ) =
          $this->captureWithKey( manage => $MAN_UI_FN, $this->{session} );
    }
    catch Error::Simple with {
        my $e = shift;
        $this->assert( 0, $e );
    };

    $query = Unit::Request->new( {} );
    $query->path_info("/$this->{test_web}/SaveSettings");
    $this->createNewFoswikiSession( $this->{test_user_login}, $query );
    $this->assert_equals( "text set",
        $this->{session}->{prefs}->getPreference('TEXTSET') );
    $this->assert_equals( "text local",
        $this->{session}->{prefs}->getPreference('TEXTLOCAL') );
    $this->assert_null( $this->{session}->{prefs}->getPreference('METASET') );
    $this->assert_null( $this->{session}->{prefs}->getPreference('METALOCAL') );
    $this->assert_equals( "new set",
        $this->{session}->{prefs}->getPreference('NEWSET') );
    $this->assert_equals( "new local",
        $this->{session}->{prefs}->getPreference('NEWLOCAL') );
    my ( $tdate, $tuser, $trev, $tcomment ) =
      Foswiki::Func::getRevisionInfo( $this->{test_web}, 'SaveSettings' );
    $this->assert_equals( 2, $trev );

    return;
}

# try and change the access rights on the fly
sub test_saveSettings_denied {
    my $this = shift;

    # Create a test topic
    my ($testTopic) =
      Foswiki::Func::readTopic( $this->{test_web}, "SaveSettings" );
    $testTopic->text(<<'TEXT');
Philosophers, philosophers, everywhere,
   * Set ALLOWTOPICCHANGE = ZeusAndHera
   * Set TEXTSET = text set
   * Local TEXTLOCAL = text local
But never a one who thinks
%META:PREFERENCE{name="METASET" type="Set" value="meta set"}%
%META:PREFERENCE{name="METALOCAL" type="Local" value="meta local"}%
TEXT
    $testTopic->save();
    $testTopic->finish();

    my $query = Unit::Request->new(
        {
            'action'      => ['saveSettings'],
            'action_save' => ['Save'],
            'text' =>
"Ignore this line\n   * Set NEWSET = new set\n   * Local NEWLOCAL = new local\n   * Set ALLOWTOPICCHANGE = $this->{test_user_wikiname}\nIgnore that line",
            'originalrev' => 1
        }
    );
    $query->path_info("/$this->{test_web}/SaveSettings");
    $this->createNewFoswikiSession( $this->{test_user_login}, $query );
    try {
        my ( $stdout, $stderr, $result ) =
          $this->captureWithKey( manage => $MAN_UI_FN, $this->{session} );
    }
    catch Foswiki::AccessControlException with {} otherwise {
        $this->assert(0);
    };

    $query = Unit::Request->new( {} );
    $query->path_info("/$this->{test_web}/SaveSettings");
    $this->createNewFoswikiSession( $this->{test_user_login}, $query );
    $this->assert_equals( "text set",
        $this->{session}->{prefs}->getPreference('TEXTSET') );
    $this->assert_equals( "text local",
        $this->{session}->{prefs}->getPreference('TEXTLOCAL') );
    $this->assert_equals( "meta set",
        $this->{session}->{prefs}->getPreference('METASET') );
    $this->assert_equals( "meta local",
        $this->{session}->{prefs}->getPreference('METALOCAL') );
    $this->assert_null( $this->{session}->{prefs}->getPreference('NEWSET') );
    $this->assert_null( $this->{session}->{prefs}->getPreference('NEWLOCAL') );
    my ( $tdate, $tuser, $trev, $tcomment ) =
      Foswiki::Func::getRevisionInfo( $this->{test_web}, 'SaveSettings' );
    $this->assert_equals( 1, $trev );

    return;
}

sub test_saveSettings_cancel {
    my $this = shift;

    # Create a test topic
    my ($testTopic) =
      Foswiki::Func::readTopic( $this->{test_web}, "SaveSettings" );
    $testTopic->text( <<'TEXT');
Philosophers, philosophers, everywhere,
   * Set TEXTSET = text set
   * Local TEXTLOCAL = text local
But never a one who thinks
%META:PREFERENCE{name="METASET" type="Set" value="meta set"}%
%META:PREFERENCE{name="METALOCAL" type="Local" value="meta local"}%
TEXT
    $testTopic->save();
    $testTopic->finish();

    my $query = Unit::Request->new(
        {
            'action'        => ['saveSettings'],
            'action_cancel' => ['Cancel'],
            'text' =>
"Ignore this line\n   * Set NEWSET = new set\n   * Local NEWLOCAL = new local\nIgnore that line",
            'originalrev' => 1
        }
    );
    $query->path_info("/$this->{test_web}/SaveSettings");
    $this->createNewFoswikiSession( $this->{test_user_login}, $query );
    try {
        my ( $stdout, $stderr, $result ) =
          $this->captureWithKey( manage => $MAN_UI_FN, $this->{session} );
    }
    catch Error::Simple with {
        my $e = shift;
        $this->assert( 0, $e );
    };

    $query = Unit::Request->new( {} );
    $query->path_info("/$this->{test_web}/SaveSettings");
    $this->createNewFoswikiSession( $this->{test_user_login}, $query );
    $this->assert_equals( "text set",
        $this->{session}->{prefs}->getPreference('TEXTSET') );
    $this->assert_equals( "text local",
        $this->{session}->{prefs}->getPreference('TEXTLOCAL') );
    $this->assert_null( $this->{session}->{prefs}->getPreference('NEWSET') );
    $this->assert_null( $this->{session}->{prefs}->getPreference('NEWLOCAL') );
    $this->assert_equals( "meta set",
        $this->{session}->{prefs}->getPreference('METASET') );
    $this->assert_equals( "meta local",
        $this->{session}->{prefs}->getPreference('METALOCAL') );
    my ( $tdate, $tuser, $trev, $tcomment ) =
      Foswiki::Func::getRevisionInfo( $this->{test_web}, 'SaveSettings' );
    $this->assert_equals( 1, $trev );

    return;
}

sub test_saveSettings_invalid {
    my $this = shift;

    # Create a test topic
    my ($testTopic) =
      Foswiki::Func::readTopic( $this->{test_web}, "SaveSettings" );
    $testTopic->text( <<'TEXT');
Philosophers, philosophers, everywhere,
   * Set TEXTSET = text set
   * Local TEXTLOCAL = text local
But never a one who thinks
%META:PREFERENCE{name="METASET" type="Set" value="meta set"}%
%META:PREFERENCE{name="METALOCAL" type="Local" value="meta local"}%
TEXT
    $testTopic->save();
    $testTopic->finish();

    my $query = Unit::Request->new(
        {
            'action'      => ['saveSettings'],
            'action_save' => ['blah'],
            'text' =>
"Ignore this line\n   * Set NEWSET = new set\n   * Local NEWLOCAL = new local\nIgnore that line",
            'originalrev' => 1
        }
    );
    $query->path_info("/$this->{test_web}/SaveSettings");
    $this->createNewFoswikiSession( $this->{test_user_login}, $query );
    try {
        my ( $stdout, $stderr, $result ) =
          $this->captureWithKey( manage => $MAN_UI_FN, $this->{session} );
    }
    catch Error::Simple with {
        my $e = shift;
        $this->assert( 0, $e );
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( "attention", $e->{template},
            $e->stringify() );
        $this->assert_str_equals( "invalid_field", $e->{def}, $e->stringify() );
    };

    $query = Unit::Request->new( {} );
    $query->path_info("/$this->{test_web}/SaveSettings");
    $this->createNewFoswikiSession( $this->{test_user_login}, $query );
    $this->assert_equals( "text set",
        $this->{session}->{prefs}->getPreference('TEXTSET') );
    $this->assert_equals( "text local",
        $this->{session}->{prefs}->getPreference('TEXTLOCAL') );
    $this->assert_null( $this->{session}->{prefs}->getPreference('NEWSET') );
    $this->assert_null( $this->{session}->{prefs}->getPreference('NEWLOCAL') );
    $this->assert_equals( "meta set",
        $this->{session}->{prefs}->getPreference('METASET') );
    $this->assert_equals( "meta local",
        $this->{session}->{prefs}->getPreference('METALOCAL') );
    my ( $tdate, $tuser, $trev, $tcomment ) =
      Foswiki::Func::getRevisionInfo( $this->{test_web}, 'SaveSettings' );
    $this->assert_equals( 1, $trev );

    return;
}

# TODO: need a test for asynchronous merge of an edit save and a settings save

sub test_createEmptyWeb {
    my $this   = shift;
    my $newWeb = $this->{test_web} . 'EmptyNewExtra';    #no, this is not nested
    my $query  = Unit::Request->new(
        {
            'action'  => ['createweb'],
            'baseweb' => ['_empty'],

            #            'newtopic' => ['qwer'],            #TODO: er, what the?
            'newweb'      => [$newWeb],
            'nosearchall' => ['on'],
            'webbgcolor'  => ['fuchsia'],
            'websummary'  => ['somthing there.'],

#TODO: I don't think this is what will get passed through - it should probably deal correctly with ['somenewskin','another']
            'SKIN' => ['somenewskin,another'],
        }
    );
    $query->path_info("/$this->{test_web}/Arbitrary");

    # SMELL: Test fails unless the "user" is the AdminGroup.
    $this->createNewFoswikiSession( $Foswiki::cfg{SuperAdminGroup}, $query );
    $this->{session}->net->setMailHandler( \&FoswikiFnTestCase::sentMail );
    $this->{session}->{topicName} = 'Arbitrary';
    $this->{session}->{webName}   = $this->{test_web};

    try {
        my ( $stdout, $stderr, $result ) =
          $this->captureWithKey( manage => $MAN_UI_FN, $this->{session} );
    }
    catch Foswiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals( "attention", $e->{template},
            $e->stringify() );
        $this->assert_str_equals( "created_web", $e->{def}, $e->stringify() );
        print STDERR "captured STDERR: " . $this->{stderr} . "\n"
          if ( defined( $this->{stderr} ) );
    }
    catch Error::Simple with {
        my $e = shift;
        $this->assert( 0, $e->stringify );

    }
    catch Foswiki::AccessControlException with {
        my $e = shift;
        $this->assert( 0, $e->stringify );

    }
    otherwise {
        $this->assert( 0, "expected an oops redirect" );
    };

    #check that the settings we created with happened.
    $this->assert( $this->{session}->webExists($newWeb) );
    my $webObject = $this->getWebObject($newWeb);
    $this->assert_equals( 'fuchsia', $webObject->getPreference('WEBBGCOLOR') );
    $this->assert_equals( 'somenewskin,another',
        $webObject->getPreference('SKIN') );
    $webObject->finish();

    #nope, SITEMAPLIST isn't required
    #$this->assert_equals('on', $webObject->getPreference('SITEMAPLIST'));

#check that the topics from _default web are actually in the new web, and make sure they are expectently similar
    my @expectedTopicsItr = Foswiki::Func::getTopicList('_empty');
    foreach my $expectedTopic (@expectedTopicsItr) {
        $this->assert( Foswiki::Func::topicExists( $newWeb, $expectedTopic ) );

        next
          if ( $expectedTopic eq 'WebPreferences' )
          ;    # we've modified the topic alot

        my ( $eMeta, $eText ) =
          Foswiki::Func::readTopic( '_empty', $expectedTopic );
        $eMeta->finish();
        my ( $nMeta, $nText ) =
          Foswiki::Func::readTopic( $newWeb, $expectedTopic );
        $nMeta->finish();

   #change the params set above to what they were in the template WebPreferences
        $nText =~
          s/($Foswiki::regex{setRegex}WEBBGCOLOR\s*=).fuchsia$/$1 #DDDDDD/m;
        $this->assert( defined($1) );
        $nText =~
          s/($Foswiki::regex{setRegex}WEBSUMMARY\s*=).something here$/$1 /m;
        $this->assert( defined($1) );
        $nText =~ s/($Foswiki::regex{setRegex}NOSEARCHALL\s*=).on$/$1 /m;
        $this->assert( defined($1) );

        $this->assert_html_equals( $eText, $nText )
          ;    #.($Foswiki::RELEASE =~ /1\.1\.0/?"\n":''));
    }

    return;
}

#TODO: add tests for all the failure conditions - ie, creating a web that exists.

1;
