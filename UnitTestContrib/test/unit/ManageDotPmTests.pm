#TODO: permission tests
#TODO: non-existant user test
package ManageDotPmTests;
use v5.14;

# SMELL diagnostics produces extra output from clean up code attempting to call
# finish() methods. Better keep it out untils the cleanup code is retouched.
#use diagnostics;
use Foswiki();
use Foswiki::UI::Manage();
use Foswiki::UI::Save();
use FileHandle();
use Try::Tiny;

use Moo;
use namespace::clean;
extends qw( FoswikiFnTestCase );

has trash_web         => ( is => 'rw', );
has stderr            => ( is => 'rw', );
has new_user_login    => ( is => 'rw', );
has new_user_wikiname => ( is => 'rw', );

my $REG_TMPL;

my $session_id;    # Capture session ID immediately after registering a new user

# Set up the test fixture
around set_up => sub {
    my $orig = shift;
    my $this = shift;

    $this->app->cfg->data->{DisableAllPlugins} = 1;
    $orig->( $this, @_ );

    $REG_TMPL =
      ( $this->check_dependency('Foswiki,<,1.2') ) ? 'attention' : 'register';

    $this->trash_web('Testtrashweb1234');
    my $webObject = $this->populateNewWeb( $this->trash_web );
    undef $webObject;
    $this->app->cfg->data->{TrashWebName} = $this->trash_web;

    @FoswikiFnTestCase::mails = ();

    return;
};

around tear_down => sub {
    my $orig = shift;
    my $this = shift;

    my $store = $this->app->store;

    $this->removeWebFixture( $this->trash_web )
      if ( $store->webExists( $this->trash_web ) );
    $this->removeWebFixture( $this->test_web . "NewExtra" )
      if ( $store->webExists( $this->test_web . "NewExtra" ) );
    $this->removeWebFixture( $this->test_web . "EmptyNewExtra" )
      if ( $store->webExists( $this->test_web . "EmptyNewExtra" ) );

    $orig->($this);
    $| = 0;

    return;
};

# Foswiki::App handleRequestException callback function.
sub _cbHRE {
    my $obj  = shift;
    my %args = @_;
    $args{params}{exception}->rethrow;
}

###################################
#verify tests

sub AllowLoginName {
    my $this = shift;
    $this->app->cfg->data->{Register}{AllowLoginName} = 1;

    return;
}

sub DontAllowLoginName {
    my $this = shift;
    $this->app->cfg->data->{Register}{AllowLoginName} = 0;
    $this->new_user_login( $this->new_user_wikiname );

    #$this->test_user_login( $this->test_user_wikiname );

    return;
}

sub TemplateLoginManager {
    my $this = shift;
    $this->app->cfg->data->{LoginManager} =
      'Foswiki::LoginManager::TemplateLogin';

    return;
}

sub ApacheLoginManager {
    my $this = shift;
    $this->app->cfg->data->{LoginManager} =
      'Foswiki::LoginManager::ApacheLogin';

    return;
}

sub NoLoginManager {
    my $this = shift;
    $this->app->cfg->data->{LoginManager} = 'Foswiki::LoginManager';

    return;
}

sub HtPasswdManager {
    my $this = shift;
    $this->app->cfg->data->{PasswordManager} = 'Foswiki::Users::HtPasswdUser';

    return;
}

sub NonePasswdManager {
    my $this = shift;
    $this->app->cfg->data->{PasswordManager} = 'none';

    return;
}

sub BaseUserMapping {
    my $this = shift;
    $this->app->cfg->data->{UserMappingManager} =
      'Foswiki::Users::BaseUserMapping';
    $this->set_up_for_verify();

    return;
}

sub TopicUserMapping {
    my $this = shift;
    $this->app->cfg->data->{UserMappingManager} =
      'Foswiki::Users::TopicUserMapping';
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

    $this->createNewFoswikiApp;

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

    my $params = {
        'TopicName'        => ['UserRegistration'],
        "${pfx}1Email"     => [$email],
        "${pfx}1WikiName"  => ["$forename$surname"],
        "${pfx}1Name"      => ["$forename $surname"],
        "${pfx}0Comment"   => [''],
        "${pfx}1FirstName" => [$forename],
        "${pfx}1LastName"  => [$surname],
        'action'           => ['register']
    };

    if ( $this->app->cfg->data->{Register}{AllowLoginName} ) {
        $params->{"${pfx}1LoginName"} = $loginname;
    }
    $this->createNewFoswikiApp(
        requestParams => { initializer => $params },
        engineParams  => {
            initialAttributes => {
                path_info => "/" . $this->users_web . "/UserRegistration",
                action    => 'register',
            },
        },
    );
    $this->app->net->setMailHandler( \&FoswikiFnTestCase::sentMail );
    my $exception;
    try {
        $this->captureWithKey(
            register => sub {
                return $this->app->handleRequest;
            },
        );
    }
    catch {
        my $exception = Foswiki::Exception::Fatal->transmute( $_, 0 );
        if ( $exception->isa('Foswiki::OopsException') ) {
            if (   ( $REG_TMPL eq $exception->template )
                && ( "thanks" eq $exception->def ) )
            {
                $exception = undef;    #the only correct answer
            }
        }
    };

# Capture the session id for the user we just registered.  This is used to confirm
# that the deleteUser removes the correct cgisess_ file.
    $session_id = Foswiki::Func::getSessionValue('_SESSION_ID');

    # Reload caches
    $this->createNewFoswikiApp;
    $this->app->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    return $exception;
}

sub addUserToGroup {
    my ( $this, $params ) = @_;

    $this->createNewFoswikiApp(
        requestParams => { initializer => $params, },
        engineParams  => {
            initialAttributes => {
                path_info => "/" . $this->users_web . "/WikiGroups",
                action    => 'manage',
            },
        },

        # Skip handleRequest exception processing by the app.
        callbacks => { handleRequestException => \&_cbHRE, },
    );

    my ( $responseText, $result, $stdout, $stderr );

    my $exception;
    try {
        ( $responseText, $result, $stdout, $stderr ) = $this->captureWithKey(
            manage => sub { return $this->app->handleRequest; } );
    }
    catch {
        $exception = Foswiki::Exception::Fatal->transmute( $_, 0 );
        if ( $exception->isa('Foswiki::OopsException') ) {
            if (   ( $REG_TMPL eq $exception->template )
                && ( "added_users_to_group" eq $exception->def ) )
            {

            #TODO: confirm that that only the expected group and user is created
                undef $exception;    #the only correct answer
            }
        }

    };
    print STDERR $responseText || '';
    return $exception;
}

sub removeUserFromGroup {
    my ( $this, $params ) = @_;

    #my $queryHash = shift;

    $this->createNewFoswikiApp(
        requestParams => { initializer => $params, },
        engineParams  => {
            initialAttributes => {
                path_info => "/" . $this->users_web . "/WikiGroups",
                action    => 'manage',
            },
        },
        callbacks => { handleRequestException => \&_cbHRE, },
    );

    my $exception;
    try {
        $this->captureWithKey(
            manage => sub { return $this->app->handleRequest }, );
    }
    catch {
        $exception = Foswiki::Exception::Fatal->transmute( $_, 0 );
        if ( $exception->isa('Foswiki::OopsException') ) {
            if (   ( $REG_TMPL eq $exception->template )
                && ( "removed_users_from_group" eq $exception->def ) )
            {

            #TODO: confirm that that onle the expected group and user is created
                undef $exception;    #the only correct answer
            }
        }
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

    $this->assert( Foswiki::Func::topicExists( $this->users_web, "NewGroup" ) );
    $this->assert( Foswiki::Func::isGroupMember( "NewGroup", "AsdfPoiu" ) );

    #need to reload to force Foswiki to reparse Groups :(
    $this->reCreateFoswikiApp;

    $this->assert( Foswiki::Func::topicExists( $this->users_web, "NewGroup" ) );

#SMELL: (maybe) yes, at the moment, the currently logged in user _is_ also added to the group - this ensures that they are able to complete the operation - as we're saving once per user
    $this->assert(
        Foswiki::Func::isGroupMember( "NewGroup", $this->app->user ) );
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

    $this->assert( Foswiki::Func::topicExists( $this->users_web, "NewGroup" ) );
    $this->assert( Foswiki::Func::isGroupMember( "NewGroup", "AsdfPoiu" ) );
    $this->assert( Foswiki::Func::isGroupMember( "NewGroup", "QwerPoiu" ) );
    $this->assert( !Foswiki::Func::isGroupMember( "NewGroup", "ZxcvPoiu" ) );

    #need to reload to force Foswiki to reparse Groups :(
    $this->reCreateFoswikiApp;

    $this->assert( Foswiki::Func::topicExists( $this->users_web, "NewGroup" ) );

#SMELL: (maybe) yes, at the moment, the currently logged in user _is_ also added to the group - this ensures that they are able to complete the operation - as we're saving once per user
    $this->assert(
        Foswiki::Func::isGroupMember( "NewGroup", $this->app->user ) );
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
            'username'  => [ $this->app->user ],
            'groupname' => ['NewGroup'],
            'create'    => [1],
            'action'    => ['addUserToGroup']
        }
    );
    $this->assert_null( $ret, "add myself" );

    $this->assert( Foswiki::Func::topicExists( $this->users_web, "NewGroup" ) );
    $this->assert( !Foswiki::Func::isGroupMember( "NewGroup", "AsdfPoiu" ) );
    $this->assert( !Foswiki::Func::isGroupMember( "NewGroup", "QwerPoiu" ) );
    $this->assert( !Foswiki::Func::isGroupMember( "NewGroup", "ZxcvPoiu" ) );

    #need to reload to force Foswiki to reparse Groups :(
    $this->reCreateFoswikiApp;

    $this->assert( Foswiki::Func::topicExists( $this->users_web, "NewGroup" ) );

#SMELL: (maybe) yes, at the moment, the currently logged in user _is_ also added to the group - this ensures that they are able to complete the operation - as we're saving once per user
    $this->assert(
        Foswiki::Func::isGroupMember( "NewGroup", $this->app->user ) );
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

    $this->assert( Foswiki::Func::topicExists( $this->users_web, "NewGroup" ) );
    $this->assert( Foswiki::Func::isGroupMember( "NewGroup", "AsdfPoiu" ) );
    $this->assert( !Foswiki::Func::isGroupMember( "NewGroup", "QwerPoiu" ) );
    $this->assert( !Foswiki::Func::isGroupMember( "NewGroup", "ZxcvPoiu" ) );

    #need to reload to force Foswiki to reparse Groups :(
    $this->reCreateFoswikiApp;

    $this->assert( Foswiki::Func::topicExists( $this->users_web, "NewGroup" ) );

#SMELL: (maybe) yes, at the moment, the currently logged in user _is_ also added to the group - this ensures that they are able to complete the operation - as we're saving once per user
    $this->assert(
        Foswiki::Func::isGroupMember( "NewGroup", $this->app->user ) );
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

    $this->assert( Foswiki::Func::topicExists( $this->users_web, "NewGroup" ) );
    $this->assert( Foswiki::Func::isGroupMember( "NewGroup", "AsdfPoiu" ) );
    $this->assert( Foswiki::Func::isGroupMember( "NewGroup", "QwerPoiu" ) );
    $this->assert( Foswiki::Func::isGroupMember( "NewGroup", "ZxcvPoiu" ) );

    #need to reload to force Foswiki to reparse Groups :(
    $this->reCreateFoswikiApp;

    $this->assert( Foswiki::Func::topicExists( $this->users_web, "NewGroup" ) );

#SMELL: (maybe) yes, at the moment, the currently logged in user _is_ also added to the group - this ensures that they are able to complete the operation - as we're saving once per user
    $this->assert(
        Foswiki::Func::isGroupMember( "NewGroup", $this->app->user ) );
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
    $this->reCreateFoswikiApp;
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
    $this->reCreateFoswikiApp;
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
        !Foswiki::Func::topicExists( $this->users_web, "AnotherNewGroup" ) );
    $this->assert( !Foswiki::Func::isGroupMember( "NewGroup", "AsdfPoiu" ) );

    #need to reload to force Foswiki to reparse Groups :(
    $this->reCreateFoswikiApp;

    $this->assert(
        !Foswiki::Func::topicExists( $this->users_web, "AnotherNewGroup" ) );
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
    $this->assert( Foswiki::Func::topicExists( $this->users_web, "NewGroup" ) );

    #need to reload to force Foswiki to reparse Groups :(
    $this->reCreateFoswikiApp;

    $this->assert( Foswiki::Func::topicExists( $this->users_web, "NewGroup" ) );

    # If not running as admin, current user is automatically added to the group.
    $this->assert(
        Foswiki::Func::isGroupMember( "NewGroup", $this->app->user ) );

    return;
}

sub test_InvalidUserAddToNewGroupCreate {
    my $this = shift;
    my $ret;

    $ret = $this->addUserToGroup(
        {
            'username'  => ['Bad<script>User'],
            'groupname' => ['NewGroup'],
            'create'    => [1],
            'action'    => ['addUserToGroup']
        }
    );

    $this->assert_equals( $ret->{status}, 500 );
    $this->assert_equals( $ret->{def},    'problem_adding_to_group' );
    $this->assert_matches( qr/Invalid username/, $ret->{params}[0] );

    #SMELL: TopicUserMapping specific - we don't refresh Groups cache :(
    $this->assert( Foswiki::Func::topicExists( $this->users_web, "NewGroup" ) );

    #need to reload to force Foswiki to reparse Groups :(
    $this->reCreateFoswikiApp;

    $this->assert( Foswiki::Func::topicExists( $this->users_web, "NewGroup" ) );

    $ret = $this->addUserToGroup(
        {
            'username'  => ['Us_aaUser'],
            'groupname' => ['NewGroup'],
            'create'    => [1],
            'action'    => ['addUserToGroup']
        }
    );

    #need to reload to force Foswiki to reparse Groups :(
    $this->reCreateFoswikiApp;

    $this->assert( Foswiki::Func::isGroupMember( "NewGroup", 'Us_aaUser' ) );

    return;
}

sub test_NoUserAddToNewGroupCreateAsAdmin {
    my $this = shift;
    my $ret;

    $this->reCreateFoswikiApp(
        engineParams => {
            initialAttributes =>
              { user => $this->app->cfg->data->{AdminUserWikiName}, },
        },
    );

    $ret = $this->addUserToGroup(
        {
            'username'  => [],
            'groupname' => ['NewGroup'],
            'create'    => [1],
            'action'    => ['addUserToGroup']
        }
    );

    #SMELL: TopicUserMapping specific - we don't refresh Groups cache :(
    $this->assert( Foswiki::Func::topicExists( $this->users_web, "NewGroup" ) );

    #need to reload to force Foswiki to reparse Groups :(
    $this->reCreateFoswikiApp;

    $this->assert( Foswiki::Func::topicExists( $this->users_web, "NewGroup" ) );

    # If running as admin, no user is automatically added to the group.
    $this->assert(
        !Foswiki::Func::isGroupMember(
            "NewGroup", $this->app->cfg->data->{AdminUserWikiName}
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
    $this->assert_equals( $ret->{template}, $REG_TMPL );
    $this->assert_equals( $ret->{def},      "problem_removing_from_group" );

    #SMELL: TopicUserMapping specific - we don't refresh Groups cache :(
    $this->assert(
        !Foswiki::Func::topicExists( $this->users_web, "AnotherNewGroup" ) );
    $this->assert( !Foswiki::Func::isGroupMember( "NewGroup", "AsdfPoiu" ) );

    #need to reload to force Foswiki to reparse Groups :(
    $this->reCreateFoswikiApp;

    $this->assert(
        !Foswiki::Func::topicExists( $this->users_web, "AnotherNewGroup" ) );
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
    $this->assert_equals( $ret->{template}, $REG_TMPL );
    $this->assert_equals( $ret->{def},      "no_users_to_remove_from_group" );

    #SMELL: TopicUserMapping specific - we don't refresh Groups cache :(
    $this->assert(
        !Foswiki::Func::topicExists( $this->users_web, "AnotherNewGroup" ) );
    $this->assert( !Foswiki::Func::isGroupMember( "NewGroup", "AsdfPoiu" ) );

    #need to reload to force Foswiki to reparse Groups :(
    $this->reCreateFoswikiApp;

    $this->assert(
        !Foswiki::Func::topicExists( $this->users_web, "AnotherNewGroup" ) );
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

    my $uname =
      ( $this->app->cfg->data->{Register}{AllowLoginName} )
      ? 'brian'
      : 'BrianGriffin';
    my $cUID = $this->app->users->getCanonicalUserID($uname);
    $this->assert( $this->app->users->userExists($cUID), "new user created" );
    my $newPassU = '12345';
    my $oldPassU = 1;         #force set
    $this->assert(
        $this->app->users->setPassword( $cUID, $newPassU, $oldPassU ) );
    my $newEmail = 'brian@family.guy';

    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                'LoginName'   => [$uname],
                'TopicName'   => ['ChangeEmailAddress'],
                'username'    => [$uname],
                'oldpassword' => ['12345'],
                'email'       => [$newEmail],
                'action'      => ['changePassword']
            },
        },
        engineParams => {
            initialAttributes => {
                path_info => '/' . $this->users_web . '/WebHome',
                action    => 'manage',
                user      => $uname,
            },
        },
        callbacks => { handleRequestException => \&_cbHRE, },
    );

    $this->app->net->setMailHandler( \&FoswikiFnTestCase::sentMail );
    try {
        $this->captureWithKey(
            manage => sub {
                return $this->app->handleRequest;
            },
        );
    }
    catch {
        my $e = Foswiki::Exception::Fatal->transmute( $_, 0 );
        if ( $e->isa('Foswiki::OopsException') ) {
            $this->assert_str_equals( $REG_TMPL, $e->template,
                $e->stringify() );
            $this->assert_str_equals( "email_changed", $e->def,
                $e->stringify() );
            $this->assert_str_equals(
                $newEmail,
                ${ $e->params }[0],
                ${ $e->params }[0]
            );
        }
        else {
            $e->_set_text( "expected an oops redirect but got: " . $e->text );
            $e->rethrow;
        }
    };

    my @emails = $this->app->users->getEmails($cUID);
    $this->assert_str_equals( $newEmail, $emails[0] );

    return;
}

sub verify_bulkRegister {
    my $this = shift;

    my $cfgData = $this->app->cfg->data;
    $cfgData->{MinPasswordLength} = 2;

    my ($topicObject) =
      Foswiki::Func::readTopic( $this->users_web, 'NewUserTemplate' );
    $topicObject->text(<<'EOF');
%NOP{Ignore this}%
Default user template
%SPLIT%
\t* Set %KEY% = %VALUE%
%SPLIT%
%WIKIUSERNAME%
%WIKINAME%
%USERNAME%
AFTER
EOF
    $topicObject->save();

    Foswiki::Func::saveTopic( $this->users_web, 'AltUserTemplate', undef,
        <<'EOF2' );
%NOP{Ignore this}%
Alternate user template
%SPLIT%
\t* Set %KEY% = %VALUE%
%SPLIT%
%WIKIUSERNAME%
%WIKINAME%
%USERNAME%
AFTER
EOF2

    my $testReg = <<'EOM';
| FirstName | LastName | Email | WikiName | LoginName | Password | CustomFieldThis | SomeOtherRandomField | WhateverYouLike | templatetopic |
| Test | User1  | Martin.Cleaver@BCS.org.uk | TestBulkUser1 | tbu1 | Secret | A | B | Works with allowLogin | AltUserTemplate |
| Test | User2 | Martin.Cleaver@BCS.org.uk | TestBulkUser2 | | Secret | A | B | Works with dont allowLogin | AltUserTemplate |
| Test | User3 | Martin.Cleaver@BCS.org.uk | TestBulkUser3 | tbu3 | Secret | A | B | Works with allowLogin | |
| Test | User3 | Martin.Cleaver@BCS.org.uk | TestBulkUser3 | tbu3 | Secret | A | B | Dup user with allowLogin | |
| Test | User4 | Martin.Cleaver@BCS.org.uk | TestBulkUser4 | | Secret | A | B | Works with dont allow | |
| Test | User4 | Martin.Cleaver@BCS.org.uk | TestBulkUser4 | | Secret | A | B | Dup user with dontAllow | NewUserTemplate |
| Test | Badpass | Martin.Cleaver@BCS.org.uk | TestBadpass | | S | A | B | Bad password with dont allow | NewUserTemplate |
| Test | Badpass | Martin.Cleaver@BCS.org.uk | TestBadpass | tbp | S | A | B | Bad password with allow | NewUserTemplate |
EOM

    my $regTopic = 'UnprocessedRegistrations2';

    my $logTopic = 'UnprocessedRegistrations2Log';
    my $file =
      $cfgData->{DataDir} . '/' . $this->test_web . '/' . $regTopic . '.txt';
    my $fh = FileHandle->new();

    die "Can't write $file" unless ( $fh->open(">$file") );
    print $fh $testReg;
    $fh->close;

    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                'LogTopic'              => [$logTopic],
                'EmailUsersWithDetails' => ['0'],
                'OverwriteHomeTopics'   => ['1'],
                'action'                => ['bulkRegister'],
            },
        },
        engineParams => {
            initialAttributes => {
                path_info => "/" . $this->test_web . "/$regTopic",
                action    => 'manage',
                user      => $cfgData->{AdminUserWikiName},
            },
        },
        callbacks => { handleRequestException => \&_cbHRE, },
    );

    $this->app->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    # SMELL We've set path_info, web and topic must be set from it.
    #$req->topic($regTopic);
    #$req->web( $this->test_web );

    my ( $responseText, $result, $stdout, $stderr );

    try {
        ( $responseText, $result, $stdout, $stderr ) =
          $this->captureWithKey(
            manage => sub { return $this->app->handleRequest; }, );
        print STDERR "=========== $stderr ===========\n";
    }
    catch {
        my $e = Foswiki::Exception::Fatal->transmute( $_, 0 );
        if ( $e->isa('Foswiki::OopsException') ) {
            print STDERR $e->stringify();
            print STDERR "======= $stderr======\n";
            Foswiki::Exception->throw(
                text => $e->stringify() . " UNEXPECTED" );
        }
        else {
            print STDERR "======= $stderr ======\n";
            $e->_set_text( "expected an oops redirect but got: " . $e->text );
            $e->rethrow;
        }
    };
    $this->assert_equals( 0, scalar(@FoswikiFnTestCase::mails) );

    #use Data::Dumper;
    #print STDERR Data::Dumper::Dumper( \$responseText );
    #print STDERR Data::Dumper::Dumper( \$result );
    #print STDERR Data::Dumper::Dumper( \$stdout );
    #print STDERR Data::Dumper::Dumper( \$stderr );

    $this->assert( Foswiki::Func::topicExists( $this->test_web, $regTopic ) );

# SMELL:  The registration log is created in UsersWeb, and not in the web containing the
# list of users to be registered.   Needs some thought.
    $this->assert(
        Foswiki::Func::topicExists(
            $this->app->cfg->data->{UsersWebName}, $logTopic
        )
    );

    my $readMeta =
      Foswiki::Meta->load( $this->app, $this->app->cfg->data->{UsersWebName},
        $logTopic );
    my $topicText = $readMeta->text();

    #print STDERR Data::Dumper::Dumper( \$topicText );

    my @expected;

    if ( $this->app->cfg->data->{Register}{AllowLoginName} ) {
        push @expected, qw(TestBulkUser1 TestBulkUser3);
        $this->assert_matches(
qr/\QThe [[System.UserName][login username]]\E is a required parameter. Registration rejected./,
            $topicText
        );
        $this->assert_matches(
qr/You cannot register twice, the name 'tbu3' is already registered\./,
            $topicText
        );
    }
    else {
        push @expected, qw(TestBulkUser2 TestBulkUser4);
        $this->assert_matches(
qr/\QThe [[System.UserName][login username]] (tbu3)\E is not allowed for this installation./,
            $topicText
        );
        $this->assert_matches(
qr/You cannot register twice, the name 'TestBulkUser4' is already registered\./,
            $topicText
        );
    }

    foreach my $wikiname (@expected) {
        print STDERR "TESTING $wikiname\n";
        $this->assert(
            Foswiki::Func::topicExists(
                $this->app->cfg->data->{UsersWebName}, $wikiname
            ),
            "Missing $wikiname"
        );
        my $utext =
          Foswiki::Func::readTopicText( $this->app->cfg->data->{UsersWebName},
            $wikiname );
        $this->assert_matches( qr/Alternate user template/, $utext )
          if ( $wikiname =~ m/[12]$/ );
        $this->assert_matches( qr/Default user template/, $utext )
          unless ( $wikiname =~ m/[12]$/ );
    }

    $this->assert_matches(
qr/---\+\+ Registering TestBadpass.*---\+\+\+ Bad password.*This site requires at least 2 character passwords/ms,
        $topicText
    );

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
        $this->app->cfg->data->{DataDir} . '/'
      . $this->test_web . '/'
      . $regTopic . '.txt';
    my $fh = FileHandle->new();

    die "Can't write $file" unless ( $fh->open(">$file") );
    print $fh $testReg;
    $fh->close;

    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                'LogTopic'              => [$logTopic],
                'EmailUsersWithDetails' => ['0'],
                'OverwriteHomeTopics'   => ['1'],
                'action'                => ['bulkRegister'],
            },
        },
        engineParams => {
            initialAttributes => {
                path_info => "/" . $this->test_web . "/$regTopic",
                action    => 'manage',
                user      => $this->app->cfg->data->{AdminUserWikiName},
            },
        },
        callbacks => { handleRequestException => \&_cbHRE, },
    );

    $this->app->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        my ($text) = $this->captureWithKey(
            manage => sub { return $this->app->handleRequest; }, );

#TODO: um, really need to test what the output was, and
#TODO: test if a user was registered..
#$this->assert( '', $text);
#my $readMeta = Foswiki::Meta->load( $this->app, $this->test_web, 'TemporaryRegistrationTestWebRegistration/UnprocessedRegistrations2Log' );
#$this->assert( '', $readMeta->text());
    }
    catch {
        my $e = Foswiki::Exception::Fatal->transmute( $_, 0 );
        if ( $e->isa('Foswiki::OopseException') ) {
            Foswiki::Exception::Fatal->throw(
                text => $e->stringify . " UNEXPECTED" );
        }
        else {
            $e->_set_text( "expected an oops redirect but got: " . $e->text );
            $e->rethrow;
        }
    };
    $this->assert_equals( 0, scalar(@FoswikiFnTestCase::mails) );

    return;
}

sub verify_deleteUser {
    my $this = shift;
    my $ret  = $this->registerUserExceptionTwk( 'eric', 'Eric', 'Cartman',
        'eric@example.com' );
    $this->assert_null( $ret, "Respect mah authoritah" );

    my $uname =
      ( $this->app->cfg->data->{Register}{AllowLoginName} )
      ? 'eric'
      : 'EricCartman';
    my $cUID     = $this->app->users->getCanonicalUserID($uname);
    my $newPassU = '12345';
    my $oldPassU = 1;                                               #force set
    $this->assert(
        $this->app->users->setPassword( $cUID, $newPassU, $oldPassU ) );

    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                'password' => ['12345'],
                'action'   => ['deleteUserAccount'],
                'user'     => [$cUID],
            },
        },
        engineParams => {
            initialAttributes => {
                path_info => "/" . $this->test_web . "/Arbitrary",
                action    => 'manage',
                user      => $uname,
            },
        },
        callbacks => { handleRequestException => \&_cbHRE, },
    );

    $this->app->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        $this->captureWithKey(
            manage => sub { return $this->app->handleRequest; }, );
    }
    catch {
        my $e = Foswiki::Exception::Fatal->transmute( $_, 0 );
        if ( $e->isa('Foswiki::OopsException') ) {
            $this->assert_str_equals( $REG_TMPL, $e->template,
                $e->stringify() );
            $this->assert_str_equals( "remove_user_done", $e->def,
                $e->stringify() );
            $this->assert_str_equals(
                'EricCartman',
                ${ $e->params }[0],
                ${ $e->params }[0]
            );
        }
        else {
            $e->_set_text( "expected an oops redirect but got: " . $e->text );
            $e->rethrow;
        }
    }

    return;
}

sub verify_deleteUserAsAdmin {
    my $this = shift;

    my $ret = $this->registerUserExceptionTwk( 'eric', 'Eric', 'Cartman',
        'eric@example.com' );
    $this->assert_null( $ret, "Respect mah authoritah" );
    $this->new_user_wikiname('EricCartman');
    $this->new_user_login('eric');

    $this->assert(
        -e $this->app->cfg->data->{WorkingDir} . "/tmp/cgisess_$session_id" );

    $this->assert(
        Foswiki::Func::addUserToGroup(
            $this->new_user_wikiname, $this->new_user_wikiname . 'Group', 1
        )
    );

    my $uname =
      ( $this->app->cfg->data->{Register}{AllowLoginName} )
      ? 'eric'
      : 'EricCartman';

    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                'user'      => $this->new_user_wikiname,
                action      => 'deleteUserAccount',
                removeTopic => '1',
            },
        },
        engineParams => {
            initialAttributes => {
                method    => 'POST',
                action    => 'manage',
                path_info => "/System/ManagingUsers",
                user      => 'AdminUser',
            },
        },
        callbacks => { handleRequestException => \&_cbHRE, },
    );

    my $resp   = '';
    my $out    = '';
    my $result = '';
    my $err    = '';
    try {
        ( $resp, $result, $out, $err ) =
          $this->captureWithKey(
            manage => sub { return $this->app->handleRequest; }, );
    }
    catch {
        my $e = Foswiki::Exception::Fatal->transmute( $_, 0 );
        if ( $e->isa('Foswiki::OopsException') ) {
            $this->assert_str_equals( $REG_TMPL, $e->template,
                $e->stringify() );
            $this->assert_str_equals( "remove_user_done", $e->def,
                $e->stringify() );
            $this->assert_str_equals(
                'EricCartman',
                ${ $e->params }[0],
                ${ $e->params }[0]
            );
            my $trash_web = $this->trash_web;
            $this->assert_matches(
qr/user removed from Mapping Manager.*removed cgisess_${session_id}.*user removed from EricCartmanGroup.*user topic moved to $trash_web\.DeletedUserEricCartman[0-9]{10,10}/s,
                ${ $e->params }[1]
            );
        }
        else {
            $e->_set_text( "expected an oops redirect but got: " . $e->text );
            $e->rethrow;
        }
    };

    $this->assert(
        !-e $this->app->cfg->data->{WorkingDir} . "/tmp/cgisess_$session_id" );

    $this->assert(
        !Foswiki::Func::isGroupMember(
            $this->new_user_wikiname, $this->new_user_wikiname . 'Group'
        )
    );

    # User should be gone from the passwords DB
    # OK to use filenames; FoswikiFnTestCase forces password manager to
    # HtPasswdUser
    my ( $new_user_login, $new_user_wikiname ) =
      ( $this->new_user_login, $this->new_user_wikiname );
    my $htpasswdFile = $this->app->cfg->data->{Htpasswd}{FileName};
    $this->assert_null(`grep $new_user_login $htpasswdFile`)
      if $this->app->cfg->data->{Register}{AllowLoginName};
    $this->assert_null(`grep $new_user_wikiname $htpasswdFile`);

    my ( $crap, $wu ) = Foswiki::Func::readTopic(
        $this->app->cfg->data->{UsersWebName},
        $this->app->cfg->data->{UsersTopicName}
    );
    $this->assert( $wu !~ /$new_user_wikiname/s );
    $this->assert( $wu !~ /$new_user_login/s );

    $this->assert(
        !Foswiki::Func::topicExists(
            $this->app->cfg->data->{UsersWebName},
            $this->new_user_wikiname
        )
    );
}

sub verify_deleteUserWithPrefix {
    my $this = shift;

    my $ret = $this->registerUserExceptionTwk( 'eric', 'Eric', 'Cartman',
        'eric@example.com' );
    $this->assert_null( $ret, "Respect mah authoritah" );
    $this->new_user_wikiname('EricCartman');
    $this->new_user_login('eric');

    $this->assert(
        Foswiki::Func::addUserToGroup(
            $this->new_user_wikiname, $this->new_user_wikiname . 'Group', 1
        )
    );

    # Test with an invalid prefix

    my $uname =
      ( $this->app->cfg->data->{Register}{AllowLoginName} )
      ? 'eric'
      : 'EricCartman';

    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                'user'      => $this->new_user_wikiname,
                action      => 'deleteUserAccount',
                removeTopic => '1',
                topicPrefix => 'foo@#$',
            },
        },
        engineParams => {
            initialAttributes => {
                path_info => "/System/ManagingUsers",
                method    => 'POST',
                action    => 'manage',
                user      => 'AdminUser',
            },
        },
        callbacks => { handleRequestException => \&_cbHRE, },
    );

    my $resp   = '';
    my $out    = '';
    my $result = '';
    my $err    = '';
    try {
        ( $resp, $result, $out, $err ) =
          $this->captureWithKey(
            manage => sub { return $this->app->handleRequest; }, );
    }
    catch {
        my $e = Foswiki::Exception::Fatal->transmute( $_, 0 );
        if ( $e->isa('Foswiki::OopsException') ) {
            $this->assert_str_equals( $REG_TMPL, $e->template,
                $e->stringify() );
            $this->assert_str_equals( '500', $e->status, $e->stringify() );
            $this->assert_str_equals( 'bad_prefix', $e->def, $e->stringify() );
        }
        else {
            $e->_set_text( "expected an oops redirect but got: " . $e->text );
            $e->rethrow;
        }
    };

    # Test again, with a valid prefix

    $uname =
      ( $this->app->cfg->data->{Register}{AllowLoginName} )
      ? 'eric'
      : 'EricCartman';

    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                'user'      => $this->new_user_wikiname,
                action      => 'deleteUserAccount',
                removeTopic => '1',
                topicPrefix => 'KilledKenny',
            },
        },
        engineParams => {
            initialAttributes => {
                path_info => "/System/ManagingUsers",
                method    => 'POST',
                action    => 'manage',
                user      => 'AdminUser',
            },
        },
        callbacks => { handleRequestException => \&_cbHRE, },
    );
    $resp   = '';
    $out    = '';
    $result = '';
    $err    = '';
    try {
        ( $resp, $result, $out, $err ) =
          $this->captureWithKey(
            manage => sub { return $this->app->handleRequest; }, );
    }
    catch {
        my $e = Foswiki::Exception::Fatal->transmute( $_, 0 );
        if ( $e->isa('Foswiki::OopsException') ) {
            $this->assert_str_equals( $REG_TMPL, $e->template,
                $e->stringify() );
            $this->assert_str_equals( "remove_user_done", $e->def,
                $e->stringify() );
            $this->assert_str_equals(
                'EricCartman',
                ${ $e->params }[0],
                ${ $e->params }[0]
            );
            my $trash_web = $this->trash_web;
            $this->assert_matches(
qr/user removed from Mapping Manager.*removed cgisess_${session_id}.*user removed from EricCartmanGroup.*user topic moved to $trash_web\.KilledKennyEricCartman[0-9]{10,10}/s,
                ${ $e->params }[1]
            );
        }
        else {
            $e->_set_text( "expected an oops redirect but got: " . $e->text );
            $e->rethrow;
        }
    };

    $this->assert(
        !Foswiki::Func::isGroupMember(
            $this->new_user_wikiname, $this->new_user_wikiname . 'Group'
        )
    );

    # User should be gone from the passwords DB
    # OK to use filenames; FoswikiFnTestCase forces password manager to
    # HtPasswdUser
    my ( $new_user_wikiname, $new_user_login ) =
      ( $this->new_user_wikiname, $this->new_user_login );
    my $sh_out;
    my $htpasswdFile = $this->app->cfg->data->{Htpasswd}{FileName};
    $this->assert_null(`grep $new_user_login $htpasswdFile`)
      if $this->app->cfg->data->{Register}{AllowLoginName};
    $this->assert_null(`grep $new_user_wikiname $htpasswdFile`);

    my ( $crap, $wu ) = Foswiki::Func::readTopic(
        $this->app->cfg->data->{UsersWebName},
        $this->app->cfg->data->{UsersTopicName}
    );
    $this->assert( $wu !~ /$new_user_wikiname/s );
    $this->assert( $wu !~ /$new_user_login/s );

    $this->assert(
        !Foswiki::Func::topicExists(
            $this->app->cfg->data->{UsersWebName},
            $this->new_user_wikiname
        )
    );
}

sub test_createDefaultWeb {
    my $this   = shift;
    my $newWeb = $this->test_web . 'NewExtra';    #no, this is not nested

    # SMELL: Test fails unless the "user" is the AdminGroup.
    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                'action'  => ['createweb'],
                'baseweb' => ['_default'],

            #            'newtopic' => ['qwer'],            #TODO: er, what the?
                'newweb'      => [$newWeb],
                'nosearchall' => ['on'],
                'webbgcolor'  => ['fuchsia'],
                'websummary'  => ['twinkle twinkle little star'],
            },
        },
        engineParams => {
            initialAttributes => {
                path_info => "/" . $this->test_web . "/Arbitrary",
                action    => 'manage',
                user      => $this->app->cfg->data->{SuperAdminGroup},
            },
        },
        callbacks => { handleRequestException => \&_cbHRE, },
    );

    $this->app->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        my ( $stdout, $stderr, $result ) =
          $this->captureWithKey(
            manage => sub { return $this->app->handleRequest; }, );
    }
    catch {
        my $e = Foswiki::Exception::Fatal->transmute( $_, 0 );
        if ( $e->isa('Foswiki::OopsException') ) {
            $this->assert_str_equals( 'attention', $e->template,
                $e->stringify() );
            $this->assert_str_equals( "created_web", $e->def, $e->stringify() );
            print STDERR "captured STDERR: " . $this->stderr . "\n"
              if ( defined( $this->stderr ) );
        }
        else {
            $e->_set_text( "expected an oops redirect but got: " . $e->text );
            $e->rethrow;
        }
    };

    #check that the settings we created with happened.
    $this->assert( $this->app->store->webExists($newWeb) );
    my $webObject = $this->getWebObject($newWeb);
    $this->assert_equals( 'fuchsia', $webObject->getPreference('WEBBGCOLOR') );
    $this->assert_equals( 'on',      $webObject->getPreference('SITEMAPLIST') );
    undef $webObject;

#check that the topics from _default web are actually in the new web, and make sure they are expectently similar
    my @expectedTopicsItr = Foswiki::Func::getTopicList('_default');
    foreach my $expectedTopic (@expectedTopicsItr) {
        $this->assert( Foswiki::Func::topicExists( $newWeb, $expectedTopic ) );
        my ( $eMeta, $eText ) =
          Foswiki::Func::readTopic( '_default', $expectedTopic );
        undef $eMeta;
        my ( $nMeta, $nText ) =
          Foswiki::Func::readTopic( $newWeb, $expectedTopic );
        undef $nMeta;

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
          ;    #.($Foswiki::RELEASE =~ m/1\.1\.0/?"\n":''));
    }

    return;
}

sub test_saveSettings_allowed {
    my $this = shift;

    # Create a test topic
    my ($testTopic) =
      Foswiki::Func::readTopic( $this->test_web, "SaveSettings" );
    $testTopic->text( <<'TEXT');
Philosophers, philosophers, everywhere,
   * Set TEXTSET = text set
   * Local TEXTLOCAL = text local
But never a one who thinks
%META:PREFERENCE{name="METASET" type="Set" value="meta set"}%
%META:PREFERENCE{name="METALOCAL" type="Local" value="meta local"}%
TEXT
    $testTopic->save();
    undef $testTopic;

    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                'action'      => ['saveSettings'],
                'action_save' => ['x'],
                'text' =>
"Ignore this line\n   * Set NEWSET = new set\n   * Local NEWLOCAL = new local\nIgnore that line",
                'originalrev' => 1
            }
        },
        engineParams => {
            initialAttributes => {
                path_info => "/" . $this->test_web . "/SaveSettings",
                action    => 'manage',
                user      => $this->test_user_login,
            },
        },
        callbacks => { handleRequestException => \&_cbHRE, },
    );

    try {
        my ( $stdout, $stderr, $result ) =
          $this->captureWithKey(
            manage => sub { return $this->app->handleRequest; }, );
    }
    catch {
        Foswiki::Exception::Fatal->rethrow($_);
    };

    $this->createNewFoswikiApp(
        requestParams => { intializer => {}, },
        engineParams  => {
            initialAttributes => {
                path_info => "/" . $this->test_web . "/SaveSettings",
                user      => $this->test_user_login,
            },
        },
    );

    my $prefs = $this->app->prefs;
    $this->assert_equals( "text set",   $prefs->getPreference('TEXTSET') );
    $this->assert_equals( "text local", $prefs->getPreference('TEXTLOCAL') );
    $this->assert_null( $prefs->getPreference('METASET') );
    $this->assert_null( $prefs->getPreference('METALOCAL') );
    $this->assert_equals( "new set",   $prefs->getPreference('NEWSET') );
    $this->assert_equals( "new local", $prefs->getPreference('NEWLOCAL') );
    my ( $tdate, $tuser, $trev, $tcomment ) =
      Foswiki::Func::getRevisionInfo( $this->test_web, 'SaveSettings' );
    $this->assert_equals( 2, $trev );

    return;
}

# try and change the access rights on the fly
sub test_saveSettings_denied {
    my $this = shift;

    # Create a test topic
    my ($testTopic) =
      Foswiki::Func::readTopic( $this->test_web, "SaveSettings" );
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
    undef $testTopic;

    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                'action'      => ['saveSettings'],
                'action_save' => ['Save'],
                'text' =>
"Ignore this line\n   * Set NEWSET = new set\n   * Local NEWLOCAL = new local\n   * Set ALLOWTOPICCHANGE = "
                  . $this->test_user_wikiname
                  . "\nIgnore that line",
                'originalrev' => 1
            },
        },
        engineParams => {
            initialAttributes => {
                path_info => "/" . $this->test_web . "/SaveSettings",
                action    => 'manage',
                user      => $this->test_user_login,
            },
        },
        callbacks => { handleRequestException => \&_cbHRE, },
    );

    try {
        my ( $stdout, $stderr, $result ) =
          $this->captureWithKey(
            manage => sub { return $this->app->handleRequest; }, );
    }
    catch {
        if ( !( ref($_) && $_->isa('Foswiki::AccessControlException') ) ) {
            Foswiki::Exception::Fatal->rethrow($_);
        }

    };

    $this->createNewFoswikiApp(
        requestParams => { initializer => {}, },
        engineParams  => {
            initialAttributes => {
                path_info => "/" . $this->test_web . "/SaveSettings",
                user      => $this->test_user_login,
            },
        },
    );

    my $prefs = $this->app->prefs;
    $this->assert_equals( "text set",   $prefs->getPreference('TEXTSET') );
    $this->assert_equals( "text local", $prefs->getPreference('TEXTLOCAL') );
    $this->assert_equals( "meta set",   $prefs->getPreference('METASET') );
    $this->assert_equals( "meta local", $prefs->getPreference('METALOCAL') );
    $this->assert_null( $prefs->getPreference('NEWSET') );
    $this->assert_null( $prefs->getPreference('NEWLOCAL') );
    my ( $tdate, $tuser, $trev, $tcomment ) =
      Foswiki::Func::getRevisionInfo( $this->test_web, 'SaveSettings' );
    $this->assert_equals( 1, $trev );

    return;
}

sub test_saveSettings_cancel {
    my $this = shift;

    # Create a test topic
    my ($testTopic) =
      Foswiki::Func::readTopic( $this->test_web, "SaveSettings" );
    $testTopic->text( <<'TEXT');
Philosophers, philosophers, everywhere,
   * Set TEXTSET = text set
   * Local TEXTLOCAL = text local
But never a one who thinks
%META:PREFERENCE{name="METASET" type="Set" value="meta set"}%
%META:PREFERENCE{name="METALOCAL" type="Local" value="meta local"}%
TEXT
    $testTopic->save();
    undef $testTopic;

    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                'action'        => ['saveSettings'],
                'action_cancel' => ['Cancel'],
                'text' =>
"Ignore this line\n   * Set NEWSET = new set\n   * Local NEWLOCAL = new local\nIgnore that line",
                'originalrev' => 1
            },
        },
        engineParams => {
            initialAttributes => {
                path_info => "/" . $this->test_web . "/SaveSettings",
                action    => 'manage',
                user      => $this->test_user_login,
            },
        },
        callbacks => { handleRequestException => \&_cbHRE, },
    );

    try {
        my ( $stdout, $stderr, $result ) =
          $this->captureWithKey(
            manage => sub { return $this->app->handleRequest; }, );
    }
    catch {
        Foswiki::Exception::Fatal->rethrow($_);
    };

    $this->createNewFoswikiApp(
        requestParams => { initializer => {}, },
        engineParams  => {
            initialAttributes => {
                path_info => "/" . $this->test_web . "/SaveSettings",
                user      => $this->test_user_login,
            },
        },
    );

    my $prefs = $this->app->prefs;
    $this->assert_equals( "text set",   $prefs->getPreference('TEXTSET') );
    $this->assert_equals( "text local", $prefs->getPreference('TEXTLOCAL') );
    $this->assert_null( $prefs->getPreference('NEWSET') );
    $this->assert_null( $prefs->getPreference('NEWLOCAL') );
    $this->assert_equals( "meta set",   $prefs->getPreference('METASET') );
    $this->assert_equals( "meta local", $prefs->getPreference('METALOCAL') );
    my ( $tdate, $tuser, $trev, $tcomment ) =
      Foswiki::Func::getRevisionInfo( $this->test_web, 'SaveSettings' );
    $this->assert_equals( 1, $trev );

    return;
}

sub test_saveSettings_invalid {
    my $this = shift;

    # Create a test topic
    my ($testTopic) =
      Foswiki::Func::readTopic( $this->test_web, "SaveSettings" );
    $testTopic->text( <<'TEXT');
Philosophers, philosophers, everywhere,
   * Set TEXTSET = text set
   * Local TEXTLOCAL = text local
But never a one who thinks
%META:PREFERENCE{name="METASET" type="Set" value="meta set"}%
%META:PREFERENCE{name="METALOCAL" type="Local" value="meta local"}%
TEXT
    $testTopic->save();
    undef $testTopic;

    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                'action'      => ['saveSettings'],
                'action_save' => [''],
                'text' =>
"Ignore this line\n   * Set NEWSET = new set\n   * Local NEWLOCAL = new local\nIgnore that line",
                'originalrev' => 1
            },
        },
        engineParams => {
            initialAttributes => {
                path_info => "/" . $this->test_web . "/SaveSettings",
                action    => 'manage',
                user      => $this->test_user_login,
            },
        },
        callbacks => { handleRequestException => \&_cbHRE, },
    );

    try {
        my ( $stdout, $stderr, $result ) =
          $this->captureWithKey(
            manage => sub { return $this->app->handleRequest; }, );
    }
    catch {
        my $e = $_;
        if ( ref($e) && $e->isa('Foswiki::OopsException') ) {
            $this->assert_str_equals( 'attention', $e->template,
                $e->stringify() );
            $this->assert_str_equals( "invalid_field", $e->def,
                $e->stringify() );
        }
        else {
            Foswiki::Exception::Fatal->rethrow($e);
        }
    };

    $this->createNewFoswikiApp(
        requestParams => { initializer => {}, },
        engineParams  => {
            initialAttributes => {
                path_info => "/" . $this->test_web . "/SaveSettings",
                user      => $this->test_user_login,
            },
        },
    );

    my $prefs = $this->app->prefs;
    $this->assert_equals( "text set",   $prefs->getPreference('TEXTSET') );
    $this->assert_equals( "text local", $prefs->getPreference('TEXTLOCAL') );
    $this->assert_null( $prefs->getPreference('NEWSET') );
    $this->assert_null( $prefs->getPreference('NEWLOCAL') );
    $this->assert_equals( "meta set",   $prefs->getPreference('METASET') );
    $this->assert_equals( "meta local", $prefs->getPreference('METALOCAL') );
    my ( $tdate, $tuser, $trev, $tcomment ) =
      Foswiki::Func::getRevisionInfo( $this->test_web, 'SaveSettings' );
    $this->assert_equals( 1, $trev );

    return;
}

# TODO: need a test for asynchronous merge of an edit save and a settings save

sub test_createEmptyWeb {
    my $this   = shift;
    my $newWeb = $this->test_web . 'EmptyNewExtra';    #no, this is not nested

    # SMELL: Test fails unless the "user" is the AdminGroup.

    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                'action'  => ['createweb'],
                'baseweb' => ['_empty'],

            #            'newtopic' => ['qwer'],            #TODO: er, what the?
                'newweb'      => [$newWeb],
                'nosearchall' => ['on'],
                'webbgcolor'  => ['fuchsia'],
                'websummary'  => ['somthing there.'],

#TODO: I don't think this is what will get passed through - it should probably deal correctly with ['somenewskin','another']
                'SKIN' => ['somenewskin,another'],
            },
        },
        engineParams => {
            initialAttributes => {
                path_info => "/" . $this->test_web . "/SaveSettings",
                action    => 'manage',
                user      => $this->app->cfg->data->{SuperAdminGroup},
            },
        },
        callbacks => { handleRequestException => \&_cbHRE, },
    );

    $this->app->net->setMailHandler( \&FoswikiFnTestCase::sentMail );

    try {
        my ( $stdout, $stderr, $result ) =
          $this->captureWithKey(
            manage => sub { return $this->app->handleRequest; }, );
    }
    catch {
        my $e = Foswiki::Exception::Fatal->transmute( $_, 0 );
        if ( $e->isa('Foswiki::OopsException') ) {
            $this->assert_str_equals( "attention", $e->template,
                $e->stringify() );
            $this->assert_str_equals( "created_web", $e->def, $e->stringify() );
            print STDERR "captured STDERR: " . $this->stderr . "\n"
              if ( defined( $this->stderr ) );
        }
        else {
            $e->_set_text( "expected an oops redirect but got: " . $e->text );
            $e->rethrow;
        }
    };

    #check that the settings we created with happened.
    $this->assert( $this->app->store->webExists($newWeb) );
    my $webObject = $this->getWebObject($newWeb);
    $this->assert_equals( 'fuchsia', $webObject->getPreference('WEBBGCOLOR') );
    $this->assert_equals( 'somenewskin,another',
        $webObject->getPreference('SKIN') );
    undef $webObject;

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
        undef $eMeta;
        my ( $nMeta, $nText ) =
          Foswiki::Func::readTopic( $newWeb, $expectedTopic );
        undef $nMeta;

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
          ;    #.($Foswiki::RELEASE =~ m/1\.1\.0/?"\n":''));
    }

    return;
}

#TODO: add tests for all the failure conditions - ie, creating a web that exists.

1;
