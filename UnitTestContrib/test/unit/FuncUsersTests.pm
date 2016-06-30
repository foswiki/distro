package FuncUsersTests;
use v5.14;

# These tests should pass for all usermappers written.
# Some basic tests for adding/removing users in the Foswiki users topic,
# and finding them again.

use Foswiki();
use Foswiki::Func();
use Foswiki::UI::Register();
use Foswiki::Configure::Dependency ();
use Data::Dumper;
use Try::Tiny;

use Moo;
use namespace::clean;
extends qw( FoswikiFnTestCase );

my %loginname;
has post11 => ( is => 'rw', );

around BUILDARGS => sub {
    my $orig = shift;
    return $orig->( @_, testSuite => 'FuncUsers' );
};

sub BUILD {
    my $this = shift;

    my $dep = Foswiki::Configure::Dependency->new(
        type    => "perl",
        module  => "Foswiki",
        version => ">=1.2"
    );
    $this->post11( ( $dep->checkDependency )[0] );
}

around loadExtraConfig => sub {
    my $orig = shift;
    my $this = shift;
    my ( $context, @args ) = @_;

    $orig->( $this, @_ );

    if ( $this->post11 ) {

#turn on the MongoDBPlugin so that the saved data goes into mongoDB
#This is temoprary until Crawford and I cna find a way to push dependencies into unit tests
        if (   ( $this->app->cfg->data->{Store}{SearchAlgorithm} =~ m/MongoDB/ )
            or ( $this->app->cfg->data->{Store}{QueryAlgorithm} =~ m/MongoDB/ )
            or ( $context =~ m/MongoDB/ ) )
        {
            $this->app->cfg->data->{Plugins}{MongoDBPlugin}{Module} =
              'Foswiki::Plugins::MongoDBPlugin';
            $this->app->cfg->data->{Plugins}{MongoDBPlugin}{Enabled} = 1;
            $this->app->cfg->data->{Plugins}{MongoDBPlugin}{EnableOnSaveUpdates}
              = 1;

#push(@{$this->app->cfg->data->{Store}{Listeners}}, 'Foswiki::Plugins::MongoDBPlugin::Listener');
            $this->app->cfg->data->{Store}{Listeners}
              {'Foswiki::Plugins::MongoDBPlugin::Listener'} = 1;
            require Foswiki::Plugins::MongoDBPlugin;
            Foswiki::Plugins::MongoDBPlugin::getMongoDB()
              ->remove( $this->test_web, 'current',
                { '_web' => $this->test_web } );
        }
    }

    return;
};

sub AllowLoginName {
    my $this = shift;
    $this->app->cfg->data->{Register}{AllowLoginName} = 1;
    $loginname{UserA}                                 = 'usera';
    $loginname{UserA86}                               = 'usera86';
    $loginname{User86A}                               = 'user86a';
    $loginname{UserB}                                 = 'userb';
    $loginname{UserC}                                 = 'userc';
    $loginname{UserE}                                 = 'usere';
    $loginname{NonExistantuser}                       = 'nonexistantuser';
    $loginname{ScumBag}                               = 'scum';
    $loginname{UserZ}                                 = 'userz';

    $loginname{DotLogin}   = 'dot.login';
    $loginname{EmailLogin} = 'email@example.com';

    return;
}

sub DontAllowLoginName {
    my $this = shift;
    $this->app->cfg->data->{Register}{AllowLoginName} = 0;
    $loginname{UserA}                                 = 'UserA';
    $loginname{UserA86}                               = 'UserA86';
    $loginname{User86A}                               = 'User86A';
    $loginname{UserB}                                 = 'UserB';
    $loginname{UserC}                                 = 'UserC';
    $loginname{UserE}                                 = 'UserE';
    $loginname{NonExistantuser}                       = 'NonExistantuser';
    $loginname{ScumBag}                               = 'scum';

    #the scum user was registered _before_ these options in the base class
    $loginname{UserZ} = 'UserZ';

    $loginname{DotLogin}   = 'DotLogin';
    $loginname{EmailLogin} = 'EmailLogin';

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

sub BaseUserMapping {
    my $this = shift;
    $this->app->cfg->data->{UserMappingManager} =
      'Foswiki::Users::BaseUserMapping';

    return;
}

sub TopicUserMapping {
    my $this = shift;
    $this->app->cfg->data->{UserMappingManager} =
      'Foswiki::Users::TopicUserMapping';
    $this->set_up_for_verify();

    return;
}

sub NonePasswordManager {
    my $this = shift;
    $this->app->cfg->data->{PasswordManager} = 'none';

    return;
}

sub HtPasswordPasswordManager {
    my $this = shift;
    $this->app->cfg->data->{PasswordManager} = 'Foswiki::Users::HtPasswdUser';

    return;
}

# See the pod doc in Unit::TestCase for details of how to use this
sub fixture_groups {
    return (
        [ 'NoLoginManager', 'ApacheLoginManager', 'TemplateLoginManager' ],
        [ 'AllowLoginName', 'DontAllowLoginName' ],
        [ 'NonePasswordManager', 'HtPasswordPasswordManager' ],
        ['TopicUserMapping']
    );    #TODO: 'BaseUserMapping'
}

#if we can't register, then thngs like GetCanonicalId(UserA) will fail, returning '' or undef
#TODO: These unit tests were not written to support the $this->app->cfg->data->{PasswordManager} eq 'none' case
#need to analyse each test here and work out how they should work (ie, there is no spec either.)
sub noUsersRegistered {
    my $this = shift;
    return (
        ( $this->app->cfg->data->{PasswordManager} eq 'none' )
          &&

        #            ($this->app->cfg->data->{Register}{AllowLoginName} == 0) &&
          (
            $this->app->cfg->data->{UserMappingManager} eq
            'Foswiki::Users::TopicUserMapping'
          )

#           &&  ($this->app->cfg->data->{LoginManager} eq 'Foswiki::LoginManager::TemplateLogin')
    );
}

#delay the calling of set_up til after the cfg's are set by above closure
sub set_up_for_verify {
    my $this = shift;

    $this->createNewFoswikiApp(
        engineParams => {
            initialAttributes =>
              { user => $this->app->cfg->data->{AdminUserLogin}, },
        },
    );

    try {
        $this->registerUser( $loginname{UserA}, 'User', 'A',
            'user@example.com' );

        $this->registerUser( $loginname{UserA86}, 'User', 'A86',
            'user86@example.com' );
        $this->registerUser( $loginname{User86A}, 'User86', 'A',
            'user86a@example.com' );

        #TODO:
        #this should fail... as its the same as the one above
        #$this->registerUser('user862a', 'User', '86A', 'user862a@example.com');
        #this one does fail..
        #$this->registerUser('86usera', '86User', 'A', 'user86a@example.com');
        $this->registerUser( $loginname{UserB}, 'User', 'B',
            'user@example.com' );
        $this->registerUser( $loginname{UserC}, 'User', 'C',
            'userc@example.com;userd@example.com' );

        $this->registerUser( $loginname{UserE}, 'User', 'E',
            'usere@example.com' );

        $this->registerUser( $loginname{UserZ}, 'User', 'Z',
            'userZ@example.com' );

        $this->registerUser( $loginname{DotLogin}, 'Dot', 'Login',
            'dot@example.com' );

 #$this->app->cfg->data->{NameFilter} = qr/[\s\*?~^\$@%`"'&;|<>\[\]#\x00-\x1f]/;

#            $this->registerUser($loginname{EmailLogin}, 'Email', 'Login', 'email@example.com');

        my ($topicObject) =
          Foswiki::Func::readTopic( $this->users_web, 'AandBGroup' );
        $topicObject->text( "   * Set GROUP = UserA, UserB, "
              . $this->app->cfg->data->{AdminUserWikiName} );
        $topicObject->save();
        undef $topicObject;
        ($topicObject) =
          Foswiki::Func::readTopic( $this->users_web, 'AandCGroup' );
        $topicObject->text("   * Set GROUP = UserA, UserC");
        $topicObject->save();
        undef $topicObject;
        ($topicObject) =
          Foswiki::Func::readTopic( $this->users_web, 'BandCGroup' );
        $topicObject->text("   * Set GROUP = UserC, UserB");
        $topicObject->save();
        undef $topicObject;
        ($topicObject) =
          Foswiki::Func::readTopic( $this->users_web, 'NestingGroup' );
        $topicObject->text("   * Set GROUP = UserE, AandCGroup, BandCGroup");
        $topicObject->save();
        undef $topicObject;
        ($topicObject) =
          Foswiki::Func::readTopic( $this->users_web, 'ScumGroup' );
        $topicObject->text( "   * Set GROUP = UserA, "
              . $this->app->cfg->data->{DefaultUserWikiName}
              . ", $loginname{UserZ}" );
        $topicObject->save();
        undef $topicObject;
        ($topicObject) =
          Foswiki::Func::readTopic( $this->users_web,
            $this->app->cfg->data->{SuperAdminGroup} );
        $topicObject->text( "   * Set GROUP = UserA, "
              . $this->app->cfg->data->{AdminUserWikiName} );
        $topicObject->save();
    }
    catch {
        my $e = $_;
        Foswiki::Exception::Fatal->rethrow($e) unless ref($e);

        # SMELL Can't we just join both condition branches into one?
        $this->assert( 0, Foswiki::Exception::errorStr($e) );
    };

    # Force a re-read

    $this->createNewFoswikiApp;

    @FoswikiFntestCase::mails = ();

    return;
}

sub verify_emailToWikiNames {
    my $this = shift;

    return if ( $this->noUsersRegistered() );

    my @users = Foswiki::Func::emailToWikiNames( 'userc@example.com', 1 );
    $this->assert_str_equals( "UserC", join( ',', @users ) );
    @users = Foswiki::Func::emailToWikiNames( 'userd@example.com', 0 );
    $this->assert_str_equals( $this->users_web . ".UserC",
        join( ',', @users ) );
    @users = Foswiki::Func::emailToWikiNames( 'user@example.com', 1 );
    $this->assert_str_equals( "UserA,UserB", join( ',', sort @users ) );

    return;
}

sub verify_wikiNameToEmails {
    my $this = shift;

    return if ( $this->noUsersRegistered() );

    my @emails = Foswiki::Func::wikinameToEmails('UserA');
    $this->assert_str_equals( "user\@example.com", join( ',', @emails ) );
    @emails = Foswiki::Func::wikinameToEmails('UserB');
    $this->assert_str_equals( "user\@example.com", join( ',', @emails ) );
    @emails = Foswiki::Func::wikinameToEmails('UserC');
    $this->assert_str_equals(
        "userd\@example.com,userc\@example.com",
        join( ',', reverse sort @emails )
    );
    @emails = Foswiki::Func::wikinameToEmails('AandCGroup');
    $this->assert_str_equals(
        "userd\@example.com,userc\@example.com,user\@example.com",
        join( ',', reverse sort @emails ) );

    return;
}

sub verify_eachUser {
    my $this = shift;
    @FoswikiFntestCase::mails = ();

    my @list;
    my $ite = Foswiki::Func::eachUser();
    while ( $ite->hasNext() ) {
        my $u = $ite->next();
        push( @list, $u );
    }
    my $ulist = join( ',', sort @list );

    my @correctList;
    if ( $this->app->cfg->data->{UserMappingManager} eq
        'Foswiki::Users::BaseUserMapping' )
    {
        @correctList =
          qw/ProjectContributor RegistrationAgent UnknownUser WikiGuest/;
    }
    else {
        @correctList =
          qw/ProjectContributor RegistrationAgent UnknownUser User86A UserA UserA86 UserB UserC UserE UserZ WikiGuest DotLogin/;
        if ( $this->app->cfg->data->{Register}{AllowLoginName} == 1 ) {
            push @correctList, 'ScumBag'
              ; # this user is created in the base class with the assumption of AllowLoginName
        }
        else {
            push @correctList, 'scum';    #
        }
    }
    push @correctList, $this->app->cfg->data->{AdminUserWikiName};
    my $correct = join( ',', sort @correctList );
    $this->assert_str_equals( $correct, $ulist );

    return;
}

sub verify_eachGroupTraditional {
    my $this = shift;
    my @list;

    $this->app->cfg->data->{SuperAdminGroup} = 'AdminGroup';

    # Force a re-read

    $this->createNewFoswikiApp;

    @FoswikiFntestCase::mails = ();

    my $ite = Foswiki::Func::eachGroup();
    while ( $ite->hasNext() ) {
        my $u = $ite->next();
        push( @list, $u );
    }
    my $ulist = join( ',', sort @list );
    my @correctList;
    if ( $this->app->cfg->data->{UserMappingManager} eq
        'Foswiki::Users::BaseUserMapping' )
    {
        @correctList = qw/AdminGroup BaseGroup/;
    }
    else {
        @correctList =
          qw/AandBGroup AandCGroup BandCGroup NestingGroup ScumGroup AdminGroup BaseGroup/;
    }
    my $correct = join( ',', sort @correctList );
    $this->assert_str_equals( $correct, $ulist );

    return;
}

sub verify_eachGroupCustomAdmin {
    my $this = shift;
    my @list;

    $this->app->cfg->data->{SuperAdminGroup} = 'Super Admin';

    # Force a re-read

    $this->createNewFoswikiApp;

    @FoswikiFntestCase::mails = ();

    my $ite = Foswiki::Func::eachGroup();
    while ( $ite->hasNext() ) {
        my $u = $ite->next();
        push( @list, $u );
    }
    my $ulist = join( ',', sort @list );
    my @correctList;
    if ( $this->app->cfg->data->{UserMappingManager} eq
        'Foswiki::Users::BaseUserMapping' )
    {
        @correctList = qw/BaseGroup/;
    }
    else {
        @correctList =
          qw/AdminGroup AandBGroup AandCGroup BandCGroup NestingGroup ScumGroup BaseGroup/;
    }
    push @correctList, $this->app->cfg->data->{SuperAdminGroup};
    my $correct = join( ',', sort @correctList );
    $this->assert_str_equals( $correct, $ulist );

    return;
}

# SMELL: nothing tests if we are an admin!
sub verify_isAnAdmin {
    my $this     = shift;
    my $iterator = Foswiki::Func::eachUser();
    while ( $iterator->hasNext() ) {
        my $u = $iterator->next();
        $u =~ m/.*\.(.*)/;
        $this->app->user($u);
        my $sadmin = Foswiki::Func::isAnAdmin($u);

        next if ( $this->noUsersRegistered() && ( $u eq 'UserA' ) );

        if (
            $u eq $this->app->cfg->data->{AdminUserWikiName}

#having rego agent an admin pretty much defeats the purpose of not making WikiGuest admin
#            || $u eq $this->app->cfg->data->{Register}{RegistrationAgentWikiName}
            || $u eq 'UserA'
          )
        {
            $this->assert( $sadmin, $u );
        }
        else {
            $this->assert( !$sadmin, $u );
        }
    }

    return;
}

sub verify_isGroupMember {
    my $this = shift;

    return if ( $this->noUsersRegistered() );

    $this->app->user(
        $this->app->users->getCanonicalUserID( $loginname{UserA} ) );
    $this->assert( $this->app->user );
    $this->assert( Foswiki::Func::isGroupMember('AandBGroup') );
    $this->assert( Foswiki::Func::isGroupMember('AandCGroup') );
    $this->assert( !Foswiki::Func::isGroupMember('BandCGroup') );
    $this->assert( Foswiki::Func::isGroupMember( 'BandCGroup', 'UserB' ) );
    $this->assert( Foswiki::Func::isGroupMember( 'BandCGroup', 'UserC' ) );
    $this->assert(
        Foswiki::Func::isGroupMember(
            'ScumGroup', $this->app->cfg->data->{DefaultUserWikiName}
        )
    );

    $this->assert( Foswiki::Func::isGroupMember( 'ScumGroup', 'UserZ' ) );
    $this->assert(
        Foswiki::Func::isGroupMember( 'ScumGroup', $loginname{UserZ} ) );

    return;
}

sub verify_eachMembership {
    my $this = shift;

    return if ( $this->noUsersRegistered() );

    my @list;
    my $it = Foswiki::Func::eachMembership('UserA');
    while ( $it->hasNext() ) {
        my $g = $it->next();
        push( @list, $g );
    }
    $this->assert_str_equals(
        'AandBGroup,AandCGroup,AdminGroup,NestingGroup,ScumGroup',
        join( ',', sort @list ) );
    $it   = Foswiki::Func::eachMembership('UserB');
    @list = ();
    while ( $it->hasNext() ) {
        my $g = $it->next();
        push( @list, $g );
    }
    $this->assert_str_equals( 'AandBGroup,BandCGroup,NestingGroup',
        join( ',', sort @list ) );

    $it   = Foswiki::Func::eachMembership('UserC');
    @list = ();
    while ( $it->hasNext() ) {
        my $g = $it->next();
        push( @list, $g );
    }
    $this->assert_str_equals( 'AandCGroup,BandCGroup,NestingGroup',
        sort join( ',', @list ) );

    $it   = Foswiki::Func::eachMembership('UserE');
    @list = ();
    while ( $it->hasNext() ) {
        my $g = $it->next();
        push( @list, $g );
    }
    $this->assert_str_equals( 'NestingGroup', sort join( ',', @list ) );

    $it   = Foswiki::Func::eachMembership('WikiGuest');
    @list = ();
    while ( $it->hasNext() ) {
        my $g = $it->next();
        push( @list, $g );
    }
    $this->assert_str_equals( 'BaseGroup,ScumGroup', sort join( ',', @list ) );

    $it   = Foswiki::Func::eachMembership( $loginname{UserZ} );
    @list = ();
    while ( $it->hasNext() ) {
        my $g = $it->next();
        push( @list, $g );
    }
    $this->assert_str_equals( 'ScumGroup', sort join( ',', @list ) );

    $it   = Foswiki::Func::eachMembership('UserZ');
    @list = ();
    while ( $it->hasNext() ) {
        my $g = $it->next();
        push( @list, $g );
    }
    $this->assert_str_equals( 'ScumGroup', sort join( ',', @list ) );

    return;
}

sub verify_eachMembershipDefault {
    my $this = shift;

    return if ( $this->noUsersRegistered() );

    my $it   = Foswiki::Func::eachMembership();
    my @list = ();
    while ( $it->hasNext() ) {
        my $g = $it->next();
        push( @list, $g );
    }
    $this->annotate( $this->app->user . " is member of...\n" );
    $this->assert_str_equals( 'BaseGroup,ScumGroup', sort join( ',', @list ) );

    return;
}

sub verify_eachGroupMember {
    my $this = shift;

    return if ( $this->noUsersRegistered() );

    my $it = Foswiki::Func::eachGroupMember('AandBGroup');
    my @list;
    while ( $it->hasNext() ) {
        my $g = $it->next();
        push( @list, $g );
    }
    $this->assert_str_equals(
        "UserA,UserB," . $this->app->cfg->data->{AdminUserWikiName},
        sort join( ',', @list ) );

    $it   = Foswiki::Func::eachGroupMember('ScumGroup');
    @list = ();
    while ( $it->hasNext() ) {
        my $g = $it->next();
        push( @list, $g );
    }
    $this->assert_str_equals(
        "UserA," . $this->app->cfg->data->{DefaultUserWikiName} . ",UserZ",
        sort join( ',', @list ) );

    $it =
      Foswiki::Func::eachGroupMember( 'NestingGroup', { expand => "true" } );
    @list = ();
    while ( $it->hasNext() ) {
        my $g = $it->next();
        push( @list, $g );
    }
    $this->assert_str_equals( "UserE,UserA,UserC,UserB",
        sort join( ',', @list ) );

    $it = Foswiki::Func::eachGroupMember( 'NestingGroup', { expand => 'off' } );
    @list = ();
    while ( $it->hasNext() ) {
        my $g = $it->next();
        push( @list, $g );
    }
    $this->assert_str_equals( "UserE,AandCGroup,BandCGroup",
        sort join( ',', @list ) );

    return;
}

sub verify_isGroup {
    my $this = shift;

    $this->assert( !Foswiki::Func::isGroup('UserA') );

    $this->assert(
        Foswiki::Func::isGroup( $this->app->cfg->data->{SuperAdminGroup} ) );
    $this->assert( Foswiki::Func::isGroup('BaseGroup') );

    #Item5540
    $this->assert( !Foswiki::Func::isGroup('S') );
    $this->assert( !Foswiki::Func::isGroup('1') );
    $this->assert( !Foswiki::Func::isGroup('AS') );
    $this->assert( !Foswiki::Func::isGroup('') );
    $this->assert( !Foswiki::Func::isGroup('#') );

    return if ( $this->noUsersRegistered() );

    $this->assert( Foswiki::Func::isGroup('AandBGroup') );

    return;
}

sub verify_getCanonicalUserID_extended {
    my $this = shift;
    my $guest_cUID =
      $this->app->users->getCanonicalUserID(
        $this->app->cfg->data->{DefaultUserLogin} );

    $this->assert_str_equals( $guest_cUID,
        Foswiki::Func::getCanonicalUserID() );

    $this->assert_str_equals(
        $guest_cUID,
        Foswiki::Func::getCanonicalUserID(
            $this->app->cfg->data->{DefaultUserLogin}
        )
    );
    $this->assert_str_equals( $guest_cUID,
        Foswiki::Func::getCanonicalUserID($guest_cUID) );
    $this->assert_str_equals(
        $guest_cUID,
        Foswiki::Func::getCanonicalUserID(
            $this->app->cfg->data->{DefaultUserWikiName}
        )
    );
    $this->assert_str_equals(
        $guest_cUID,
        Foswiki::Func::getCanonicalUserID(
                $this->app->cfg->data->{UsersWebName} . '.'
              . $this->app->cfg->data->{DefaultUserWikiName}
        )
    );

    my $admin_cUID =
      $this->app->users->getCanonicalUserID(
        $this->app->cfg->data->{AdminUserLogin} );
    $this->assert_str_equals( $admin_cUID,
        Foswiki::Func::getCanonicalUserID($admin_cUID) );
    $this->assert_str_equals(
        $admin_cUID,
        Foswiki::Func::getCanonicalUserID(
            $this->app->cfg->data->{AdminUserLogin}
        )
    );
    $this->assert_str_equals(
        $admin_cUID,
        Foswiki::Func::getCanonicalUserID(
            $this->app->cfg->data->{AdminUserWikiName}
        )
    );
    $this->assert_str_equals(
        $admin_cUID,
        Foswiki::Func::getCanonicalUserID(
                $this->app->cfg->data->{UsersWebName} . '.'
              . $this->app->cfg->data->{AdminUserWikiName}
        )
    );

    #TODO: consider how to render unkown user's
    $this->assert_null(
        $this->app->users->getCanonicalUserID( $loginname{NonExistantuser} ) );
    my $cUID = Foswiki::Func::getCanonicalUserID( $loginname{NonExistantuser} );
    $this->assert_null( $cUID, $cUID );
    $this->assert_null( Foswiki::Func::getCanonicalUserID('NonExistantUser') );
    $this->assert_null(
        Foswiki::Func::getCanonicalUserID(
            $this->app->cfg->data->{UsersWebName} . '.' . 'NonExistantUser'
        )
    );
    $this->assert_null(
        Foswiki::Func::getCanonicalUserID(
            $this->app->cfg->data->{UsersWebName} . '.' . 'NonExistantUser86'
        )
    );

    return if ( $this->noUsersRegistered() );

    my $usera_cUID = $this->app->users->getCanonicalUserID( $loginname{UserA} );
    $this->assert_str_equals( $usera_cUID,
        Foswiki::Func::getCanonicalUserID($usera_cUID) );
    $this->assert_str_equals( $usera_cUID,
        Foswiki::Func::getCanonicalUserID( $loginname{UserA} ) );
    $this->assert_str_equals( $usera_cUID,
        Foswiki::Func::getCanonicalUserID('UserA') );
    $this->assert_str_equals(
        $usera_cUID,
        Foswiki::Func::getCanonicalUserID(
            $this->app->cfg->data->{UsersWebName} . '.' . 'UserA'
        )
    );

#            $this->registerUser($loginname{UserA86}, 'User', 'A86', 'user86@example.com');
    my $usera86_cUID =
      $this->app->users->getCanonicalUserID( $loginname{UserA86} );
    $this->assert_str_equals( $usera86_cUID,
        Foswiki::Func::getCanonicalUserID($usera86_cUID) );
    $this->assert_str_equals( $usera86_cUID,
        Foswiki::Func::getCanonicalUserID( $loginname{UserA86} ) );
    $this->assert_str_equals( $usera86_cUID,
        Foswiki::Func::getCanonicalUserID('UserA86') );
    $this->assert_str_equals(
        $usera86_cUID,
        Foswiki::Func::getCanonicalUserID(
            $this->app->cfg->data->{UsersWebName} . '.' . 'UserA86'
        )
    );

#            $this->registerUser($loginname{User86A}, 'User86', 'A', 'user86a@example.com');
    my $user86a_cUID =
      $this->app->users->getCanonicalUserID( $loginname{User86A} );
    $this->assert_str_equals( $user86a_cUID,
        Foswiki::Func::getCanonicalUserID($user86a_cUID) );
    $this->assert_str_equals( $user86a_cUID,
        Foswiki::Func::getCanonicalUserID( $loginname{User86A} ) );
    $this->assert_str_equals( $user86a_cUID,
        Foswiki::Func::getCanonicalUserID('User86A') );
    $this->assert_str_equals(
        $user86a_cUID,
        Foswiki::Func::getCanonicalUserID(
            $this->app->cfg->data->{UsersWebName} . '.' . 'User86A'
        )
    );

#            $this->registerUser('user862a', 'User', '86A', 'user862a@example.com');
#            $this->registerUser('86usera', '86User', 'A', 'user86a@example.com');

#TODO: consider what to return for GROUPs
#    $this->assert_null($this->app->users->getCanonicalUserID('AandBGroup'));
#    $this->assert_null(Foswiki::Func::getCanonicalUserID('AandBGroup'));
#    $this->assert_null(Foswiki::Func::getCanonicalUserID($this->app->cfg->data->{UsersWebName}.'.'.'AandBGroup'));

#TODO: consider what to return for GROUPs
#    $this->assert_null($this->app->users->getCanonicalUserID($this->app->cfg->data->{SuperAdminGroup}));
#    $this->assert_null(Foswiki::Func::getCanonicalUserID($this->app->cfg->data->{SuperAdminGroup}));
#    $this->assert_null(Foswiki::Func::getCanonicalUserID($this->app->cfg->data->{UsersWebName}.'.'.$this->app->cfg->data->{SuperAdminGroup}));

    return;
}

sub verify_getWikiName_extended {
    my $this = shift;

    $this->assert_str_equals( $this->app->cfg->data->{DefaultUserWikiName},
        Foswiki::Func::getWikiName() );

    my $guest_cUID =
      $this->app->users->getCanonicalUserID(
        $this->app->cfg->data->{DefaultUserLogin} );
    $this->assert_str_equals( $this->app->cfg->data->{DefaultUserWikiName},
        Foswiki::Func::getWikiName( $this->app->cfg->data->{DefaultUserLogin} )
    );
    $this->assert_str_equals(
        $this->app->cfg->data->{DefaultUserWikiName},
        Foswiki::Func::getWikiName($guest_cUID)
    );
    $this->assert_str_equals(
        $this->app->cfg->data->{DefaultUserWikiName},
        Foswiki::Func::getWikiName(
            $this->app->cfg->data->{DefaultUserWikiName}
        )
    );
    $this->assert_str_equals(
        $this->app->cfg->data->{DefaultUserWikiName},
        Foswiki::Func::getWikiName(
                $this->app->cfg->data->{UsersWebName} . '.'
              . $this->app->cfg->data->{DefaultUserWikiName}
        )
    );

    my $admin_cUID =
      $this->app->users->getCanonicalUserID(
        $this->app->cfg->data->{AdminUserLogin} );
    $this->annotate( $admin_cUID . ' => '
          . $this->app->cfg->data->{AdminUserLogin} . ' => '
          . $this->app->cfg->data->{AdminUserWikiName} );
    $this->assert_str_equals(
        $this->app->cfg->data->{AdminUserWikiName},
        Foswiki::Func::getWikiName($admin_cUID)
    );
    $this->assert_str_equals( $this->app->cfg->data->{AdminUserWikiName},
        Foswiki::Func::getWikiName( $this->app->cfg->data->{AdminUserLogin} ) );
    $this->assert_str_equals(
        $this->app->cfg->data->{AdminUserWikiName},
        Foswiki::Func::getWikiName(
            $this->app->cfg->data->{AdminUserWikiName}
        )
    );
    $this->assert_str_equals(
        $this->app->cfg->data->{AdminUserWikiName},
        Foswiki::Func::getWikiName(
                $this->app->cfg->data->{UsersWebName} . '.'
              . $this->app->cfg->data->{AdminUserWikiName}
        )
    );

  #TODO: consider how to render unkown user's
  #$this->app->cfg->data->{RenderLoggedInButUnknownUsers} is false, or undefined

    $this->assert_str_equals( 'TopicUserMapping_NonExistantUser',
        Foswiki::Func::getWikiName('TopicUserMapping_NonExistantUser') );
    my $nonexistantuser_cUID =
      $this->app->users->getCanonicalUserID( $loginname{NonExistantuser} );
    $this->annotate($nonexistantuser_cUID);    #returns guest
    $this->assert_str_equals(
        $this->app->cfg->data->{DefaultUserWikiName},
        Foswiki::Func::getWikiName($nonexistantuser_cUID)
    );
    $this->assert_str_equals( $loginname{NonExistantuser},
        Foswiki::Func::getWikiName( $loginname{NonExistantuser} ) );
    $this->assert_str_equals( 'NonExistantUser',
        Foswiki::Func::getWikiName('NonExistantUser') );
    $this->assert_str_equals(
        'NonExistantUser',
        Foswiki::Func::getWikiName(
            $this->app->cfg->data->{UsersWebName} . '.NonExistantUser'
        )
    );
    $this->assert_str_equals(
        'NonExistantUser86',
        Foswiki::Func::getWikiName(
            $this->app->cfg->data->{UsersWebName} . '.NonExistantUser86'
        )
    );

    return if ( $this->noUsersRegistered() );

    my $usera_cUID = $this->app->users->getCanonicalUserID( $loginname{UserA} );
    $this->assert_str_equals( 'UserA',
        Foswiki::Func::getWikiName($usera_cUID) );
    $this->assert_str_equals( 'UserA',
        Foswiki::Func::getWikiName( $loginname{UserA} ) );
    $this->assert_str_equals( 'UserA', Foswiki::Func::getWikiName('UserA') );
    $this->assert_str_equals(
        'UserA',
        Foswiki::Func::getWikiName(
            $this->app->cfg->data->{UsersWebName} . '.UserA'
        )
    );

#            $this->registerUser($loginname{UserA86}, 'User', 'A86', 'user86@example.com');
    my $usera86_cUID =
      $this->app->users->getCanonicalUserID( $loginname{UserA86} );
    $this->assert_str_equals( 'UserA86',
        Foswiki::Func::getWikiName($usera86_cUID) );
    $this->assert_str_equals( 'UserA86',
        Foswiki::Func::getWikiName( $loginname{UserA86} ) );
    $this->assert_str_equals( 'UserA86',
        Foswiki::Func::getWikiName('UserA86') );
    $this->assert_str_equals(
        'UserA86',
        Foswiki::Func::getWikiName(
            $this->app->cfg->data->{UsersWebName} . '.UserA86'
        )
    );

#            $this->registerUser($loginname{User86A}, 'User86', 'A', 'user86a@example.com');
    my $user86a_cUID =
      $this->app->users->getCanonicalUserID( $loginname{User86A} );
    $this->assert_str_equals( 'User86A',
        Foswiki::Func::getWikiName($user86a_cUID) );
    $this->assert_str_equals( 'User86A',
        Foswiki::Func::getWikiName( $loginname{User86A} ) );
    $this->assert_str_equals( 'User86A',
        Foswiki::Func::getWikiName('User86A') );
    $this->assert_str_equals(
        'User86A',
        Foswiki::Func::getWikiName(
            $this->app->cfg->data->{UsersWebName} . '.User86A'
        )
    );

#            $this->registerUser('user862a', 'User', '86A', 'user862a@example.com');
#            $this->registerUser('86usera', '86User', 'A', 'user86a@example.com');

#TODO: consider how to render unkown user's
#my $AandBGroup_cUID = $this->app->users->getCanonicalUserID('AandBGroup');
#$this->annotate($AandBGroup_cUID);
#$this->assert_str_equals('AandBGroup', Foswiki::Func::getWikiName($AandBGroup_cUID));
#$this->assert_str_equals('AandBGroup', Foswiki::Func::getWikiName('AandBGroup'));
#$this->assert_str_equals('AandBGroup', Foswiki::Func::getWikiName('AandBGroup'));
#$this->assert_str_equals('AandBGroup', Foswiki::Func::getWikiName($this->app->cfg->data->{UsersWebName}.'.'.'AandBGroup'));

    return;
}

sub verify_getWikiUserName_extended {
    my $this = shift;

    $this->assert_str_equals(
        $this->app->cfg->data->{UsersWebName} . '.'
          . $this->app->cfg->data->{DefaultUserWikiName},
        Foswiki::Func::getWikiUserName()
    );

    my $guest_cUID =
      $this->app->users->getCanonicalUserID(
        $this->app->cfg->data->{DefaultUserLogin} );
    $this->assert_str_equals(
        $this->app->cfg->data->{UsersWebName} . '.'
          . $this->app->cfg->data->{DefaultUserWikiName},
        Foswiki::Func::getWikiUserName(
            $this->app->cfg->data->{DefaultUserLogin}
        )
    );
    $this->assert_str_equals(
        $this->app->cfg->data->{UsersWebName} . '.'
          . $this->app->cfg->data->{DefaultUserWikiName},
        Foswiki::Func::getWikiUserName($guest_cUID)
    );
    $this->assert_str_equals(
        $this->app->cfg->data->{UsersWebName} . '.'
          . $this->app->cfg->data->{DefaultUserWikiName},
        Foswiki::Func::getWikiUserName(
            $this->app->cfg->data->{DefaultUserWikiName}
        )
    );
    $this->assert_str_equals(
        $this->app->cfg->data->{UsersWebName} . '.'
          . $this->app->cfg->data->{DefaultUserWikiName},
        Foswiki::Func::getWikiUserName(
                $this->app->cfg->data->{UsersWebName} . '.'
              . $this->app->cfg->data->{DefaultUserWikiName}
        )
    );

    my $admin_cUID =
      $this->app->users->getCanonicalUserID(
        $this->app->cfg->data->{AdminUserLogin} );
    $this->assert_str_equals(
        $this->app->cfg->data->{UsersWebName} . '.'
          . $this->app->cfg->data->{AdminUserWikiName},
        Foswiki::Func::getWikiUserName($admin_cUID)
    );
    $this->assert_str_equals(
        $this->app->cfg->data->{UsersWebName} . '.'
          . $this->app->cfg->data->{AdminUserWikiName},
        Foswiki::Func::getWikiUserName(
            $this->app->cfg->data->{AdminUserLogin}
        )
    );
    $this->assert_str_equals(
        $this->app->cfg->data->{UsersWebName} . '.'
          . $this->app->cfg->data->{AdminUserWikiName},
        Foswiki::Func::getWikiUserName(
            $this->app->cfg->data->{AdminUserWikiName}
        )
    );
    $this->assert_str_equals(
        $this->app->cfg->data->{UsersWebName} . '.'
          . $this->app->cfg->data->{AdminUserWikiName},
        Foswiki::Func::getWikiUserName(
                $this->app->cfg->data->{UsersWebName} . '.'
              . $this->app->cfg->data->{AdminUserWikiName}
        )
    );

    #TODO: consider how to render unkown user's
    $this->assert_str_equals(
        $this->app->cfg->data->{UsersWebName} . '.' . 'NonExistantUserAsdf',
        Foswiki::Func::getWikiUserName('NonExistantUserAsdf')
    );
    my $nonexistantuser_cUID =
      $this->app->users->getCanonicalUserID('nonexistantuserasdf');
    $this->annotate($nonexistantuser_cUID);    #returns guest
    $this->assert_str_equals(
        $this->app->cfg->data->{UsersWebName} . '.'
          . $this->app->cfg->data->{DefaultUserWikiName},
        Foswiki::Func::getWikiUserName($nonexistantuser_cUID)
    );
    $this->assert_str_equals(
        $this->app->cfg->data->{UsersWebName} . '.' . 'nonexistantuserasdf',
        Foswiki::Func::getWikiUserName('nonexistantuserasdf')
    );
    $this->assert_str_equals(
        $this->app->cfg->data->{UsersWebName} . '.' . 'nonexistantuserasdfqwer',
        Foswiki::Func::getWikiUserName('nonexistantuserasdfqwer')
    );
    $this->assert_str_equals(
        $this->app->cfg->data->{UsersWebName} . '.' . 'NonExistantUserAsdf',
        Foswiki::Func::getWikiUserName('NonExistantUserAsdf')
    );
    $this->assert_str_equals(
        $this->app->cfg->data->{UsersWebName} . '.' . 'NonExistantUserAsdf',
        Foswiki::Func::getWikiUserName(
            $this->app->cfg->data->{UsersWebName} . '.' . 'NonExistantUserAsdf'
        )
    );
    $this->assert_str_equals(
        $this->app->cfg->data->{UsersWebName} . '.' . 'NonExistantUserAsdf86',
        Foswiki::Func::getWikiUserName(
            $this->app->cfg->data->{UsersWebName} . '.'
              . 'NonExistantUserAsdf86'
        )
    );

    return if ( $this->noUsersRegistered() );

    my $usera_cUID = $this->app->users->getCanonicalUserID( $loginname{UserA} );
    $this->assert_str_equals(
        $this->app->cfg->data->{UsersWebName} . '.' . 'UserA',
        Foswiki::Func::getWikiUserName($usera_cUID)
    );
    $this->assert_str_equals(
        $this->app->cfg->data->{UsersWebName} . '.' . 'UserA',
        Foswiki::Func::getWikiUserName( $loginname{UserA} )
    );
    $this->assert_str_equals(
        $this->app->cfg->data->{UsersWebName} . '.' . 'UserA',
        Foswiki::Func::getWikiUserName('UserA') );
    $this->assert_str_equals(
        $this->app->cfg->data->{UsersWebName} . '.' . 'UserA',
        Foswiki::Func::getWikiUserName(
            $this->app->cfg->data->{UsersWebName} . '.' . 'UserA'
        )
    );

#            $this->registerUser($loginname{UserA86}, 'User', 'A86', 'user86@example.com');
    my $usera86_cUID =
      $this->app->users->getCanonicalUserID( $loginname{UserA86} );
    $this->assert_str_equals(
        $this->app->cfg->data->{UsersWebName} . '.' . 'UserA86',
        Foswiki::Func::getWikiUserName($usera86_cUID)
    );
    $this->assert_str_equals(
        $this->app->cfg->data->{UsersWebName} . '.' . 'UserA86',
        Foswiki::Func::getWikiUserName( $loginname{UserA86} )
    );
    $this->assert_str_equals(
        $this->app->cfg->data->{UsersWebName} . '.' . 'UserA86',
        Foswiki::Func::getWikiUserName('UserA86') );
    $this->assert_str_equals(
        $this->app->cfg->data->{UsersWebName} . '.' . 'UserA86',
        Foswiki::Func::getWikiUserName(
            $this->app->cfg->data->{UsersWebName} . '.' . 'UserA86'
        )
    );

#            $this->registerUser($loginname{User86A}, 'User86', 'A', 'user86a@example.com');
    my $user86a_cUID =
      $this->app->users->getCanonicalUserID( $loginname{User86A} );
    $this->assert_str_equals(
        $this->app->cfg->data->{UsersWebName} . '.' . 'User86A',
        Foswiki::Func::getWikiUserName($user86a_cUID)
    );
    $this->assert_str_equals(
        $this->app->cfg->data->{UsersWebName} . '.' . 'User86A',
        Foswiki::Func::getWikiUserName( $loginname{User86A} )
    );
    $this->assert_str_equals(
        $this->app->cfg->data->{UsersWebName} . '.' . 'User86A',
        Foswiki::Func::getWikiUserName('User86A') );
    $this->assert_str_equals(
        $this->app->cfg->data->{UsersWebName} . '.' . 'User86A',
        Foswiki::Func::getWikiUserName(
            $this->app->cfg->data->{UsersWebName} . '.' . 'User86A'
        )
    );

#            $this->registerUser('user862a', 'User', '86A', 'user862a@example.com');
#            $this->registerUser('86usera', '86User', 'A', 'user86a@example.com');

#TODO: consider how to render unknown users
#my $AandBGroup_cUID = $this->app->users->getCanonicalUserID('AandBGroup');
#$this->annotate($AandBGroup_cUID);
#$this->assert_str_equals($this->app->cfg->data->{UsersWebName}.'.'.'AandBGroup', Foswiki::Func::getWikiUserName($AandBGroup_cUID));
#$this->assert_str_equals($this->app->cfg->data->{UsersWebName}.'.'.'AandBGroup', Foswiki::Func::getWikiUserName('AandBGroup'));
#$this->assert_str_equals($this->app->cfg->data->{UsersWebName}.'.'.'AandBGroup', Foswiki::Func::getWikiUserName('AandBGroup'));
#$this->assert_str_equals($this->app->cfg->data->{UsersWebName}.'.'.'AandBGroup', Foswiki::Func::getWikiUserName($this->app->cfg->data->{UsersWebName}.'.'.'AandBGroup'));

    return;
}

sub verify_wikiToUserName_extended {
    my $this = shift;

    #TODO: not sure that this method needs to be able to convert _any_ to login
    my $guest_cUID =
      $this->app->users->getCanonicalUserID(
        $this->app->cfg->data->{DefaultUserLogin} );
    $this->assert_str_equals(
        $this->app->cfg->data->{DefaultUserLogin},
        Foswiki::Func::wikiToUserName($guest_cUID)
    );
    $this->assert_str_equals(
        $this->app->cfg->data->{DefaultUserLogin},
        Foswiki::Func::wikiToUserName(
            $this->app->cfg->data->{DefaultUserLogin}
        )
    );
    $this->assert_str_equals(
        $this->app->cfg->data->{DefaultUserLogin},
        Foswiki::Func::wikiToUserName(
            $this->app->cfg->data->{DefaultUserWikiName}
        )
    );
    $this->assert_str_equals(
        $this->app->cfg->data->{DefaultUserLogin},
        Foswiki::Func::wikiToUserName(
                $this->app->cfg->data->{UsersWebName} . '.'
              . $this->app->cfg->data->{DefaultUserWikiName}
        )
    );

    my $admin_cUID =
      $this->app->users->getCanonicalUserID(
        $this->app->cfg->data->{AdminUserLogin} );
    $this->assert_str_equals(
        $this->app->cfg->data->{AdminUserLogin},
        Foswiki::Func::wikiToUserName($admin_cUID)
    );
    $this->assert_str_equals(
        $this->app->cfg->data->{AdminUserLogin},
        Foswiki::Func::wikiToUserName(
            $this->app->cfg->data->{AdminUserLogin}
        )
    );
    $this->assert_str_equals(
        $this->app->cfg->data->{AdminUserLogin},
        Foswiki::Func::wikiToUserName(
            $this->app->cfg->data->{AdminUserWikiName}
        )
    );
    $this->assert_str_equals(
        $this->app->cfg->data->{AdminUserLogin},
        Foswiki::Func::wikiToUserName(
                $this->app->cfg->data->{UsersWebName} . '.'
              . $this->app->cfg->data->{AdminUserWikiName}
        )
    );

    #TODO: consider how to render unkown user's
    $this->assert_null(
        Foswiki::Func::wikiToUserName('TopicUserMapping_NonExistantUser') );
    $this->assert_null(
        Foswiki::Func::wikiToUserName( $loginname{NonExistantuser} ) );
    $this->assert_null( Foswiki::Func::wikiToUserName('NonExistantUser') );
    $this->assert_null(
        Foswiki::Func::wikiToUserName(
            $this->app->cfg->data->{UsersWebName} . '.' . 'NonExistantUser'
        )
    );
    $this->assert_null(
        Foswiki::Func::wikiToUserName(
            $this->app->cfg->data->{UsersWebName} . '.' . 'NonExistantUser86'
        )
    );

    return if ( $this->noUsersRegistered() );
    my $usera_cUID = $this->app->users->getCanonicalUserID( $loginname{UserA} );
    $this->assert_str_equals( $loginname{UserA},
        Foswiki::Func::wikiToUserName($usera_cUID) );
    $this->assert_str_equals( $loginname{UserA},
        Foswiki::Func::wikiToUserName( $loginname{UserA} ) );
    $this->assert_str_equals( $loginname{UserA},
        Foswiki::Func::wikiToUserName('UserA') );
    $this->assert_str_equals(
        $loginname{UserA},
        Foswiki::Func::wikiToUserName(
            $this->app->cfg->data->{UsersWebName} . '.' . 'UserA'
        )
    );

#            $this->registerUser($loginname{UserA86}, 'User', 'A86', 'user86@example.com');
    my $usera86_cUID =
      $this->app->users->getCanonicalUserID( $loginname{UserA86} );
    $this->assert_str_equals( $loginname{UserA86},
        Foswiki::Func::wikiToUserName($usera86_cUID) );
    $this->assert_str_equals( $loginname{UserA86},
        Foswiki::Func::wikiToUserName( $loginname{UserA86} ) );
    $this->assert_str_equals( $loginname{UserA86},
        Foswiki::Func::wikiToUserName('UserA86') );
    $this->assert_str_equals(
        $loginname{UserA86},
        Foswiki::Func::wikiToUserName(
            $this->app->cfg->data->{UsersWebName} . '.' . 'UserA86'
        )
    );

#            $this->registerUser($loginname{User86A}, 'User86', 'A', 'user86a@example.com');
    my $user86a_cUID =
      $this->app->users->getCanonicalUserID( $loginname{User86A} );
    $this->assert_str_equals( $loginname{User86A},
        Foswiki::Func::wikiToUserName($user86a_cUID) );
    $this->assert_str_equals( $loginname{User86A},
        Foswiki::Func::wikiToUserName( $loginname{User86A} ) );
    $this->assert_str_equals( $loginname{User86A},
        Foswiki::Func::wikiToUserName('User86A') );
    $this->assert_str_equals(
        $loginname{User86A},
        Foswiki::Func::wikiToUserName(
            $this->app->cfg->data->{UsersWebName} . '.' . 'User86A'
        )
    );

#            $this->registerUser('user862a', 'User', '86A', 'user862a@example.com');
#            $this->registerUser('86usera', '86User', 'A', 'user86a@example.com');

#TODO: consider how to render unkown user's
#my $AandBGroup_cUID = $this->app->users->getCanonicalUserID('AandBGroup');
#$this->annotate($AandBGroup_cUID);
#$this->assert_str_equals('AandBGroup', Foswiki::Func::wikiToUserName($AandBGroup_cUID));
#$this->assert_str_equals('AandBGroup', Foswiki::Func::wikiToUserName('AandBGroup'));
#$this->assert_str_equals('AandBGroup', Foswiki::Func::wikiToUserName('AandBGroup'));
#$this->assert_str_equals('AandBGroup', Foswiki::Func::wikiToUserName($this->app->cfg->data->{UsersWebName}.'.'.'AandBGroup'));

    return;
}

sub verify_isAnAdmin_extended {
    my $this = shift;

    #TODO: not sure that this method needs to be able to convert _any_ to login
    my $guest_cUID =
      $this->app->users->getCanonicalUserID(
        $this->app->cfg->data->{DefaultUserLogin} );
    $this->assert(
        !Foswiki::Func::isAnAdmin( $this->app->cfg->data->{DefaultUserLogin} )
    );
    $this->assert( !Foswiki::Func::isAnAdmin($guest_cUID) );
    $this->assert(
        !Foswiki::Func::isAnAdmin(
            $this->app->cfg->data->{DefaultUserWikiName}
        )
    );
    $this->assert(
        !Foswiki::Func::isAnAdmin(
                $this->app->cfg->data->{UsersWebName} . '.'
              . $this->app->cfg->data->{DefaultUserWikiName}
        )
    );

    my $admin_cUID =
      $this->app->users->getCanonicalUserID(
        $this->app->cfg->data->{AdminUserLogin} );
    $this->assert( Foswiki::Func::isAnAdmin($admin_cUID) );
    $this->assert(
        Foswiki::Func::isAnAdmin( $this->app->cfg->data->{AdminUserLogin} ) );
    $this->assert(
        Foswiki::Func::isAnAdmin( $this->app->cfg->data->{AdminUserWikiName} )
    );
    $this->assert(
        Foswiki::Func::isAnAdmin(
                $this->app->cfg->data->{UsersWebName} . '.'
              . $this->app->cfg->data->{AdminUserWikiName}
        )
    );

    return if ( $this->noUsersRegistered() );

    #TODO: consider how to render unkown user's
    $this->assert(
        !Foswiki::Func::isAnAdmin('TopicUserMapping_NonExistantUser') );
    my $nonexistantuser_cUID =
      $this->app->users->getCanonicalUserID( $loginname{NonExistantuser} );
    $this->annotate($nonexistantuser_cUID);
    $this->assert( !Foswiki::Func::isAnAdmin($nonexistantuser_cUID) );
    $this->assert( !Foswiki::Func::isAnAdmin( $loginname{NonExistantuser} ) );
    $this->assert( !Foswiki::Func::isAnAdmin('NonExistantUser') );
    $this->assert(
        !Foswiki::Func::isAnAdmin(
            $this->app->cfg->data->{UsersWebName} . '.' . 'NonExistantUser'
        )
    );

    my $usera_cUID = $this->app->users->getCanonicalUserID( $loginname{UserA} );
    $this->assert( Foswiki::Func::isAnAdmin($usera_cUID) );
    $this->assert( Foswiki::Func::isAnAdmin( $loginname{UserA} ) );
    $this->assert( Foswiki::Func::isAnAdmin('UserA') );
    $this->assert(
        Foswiki::Func::isAnAdmin(
            $this->app->cfg->data->{UsersWebName} . '.' . 'UserA'
        )
    );

    $this->assert(
        !Foswiki::Func::isAnAdmin(
            $this->app->cfg->data->{UsersWebName} . '.' . 'UserB'
        )
    );
    my $userb_cUID = $this->app->users->getCanonicalUserID( $loginname{UserB} );
    $this->assert( !Foswiki::Func::isAnAdmin($userb_cUID) );
    $this->assert( !Foswiki::Func::isAnAdmin( $loginname{UserB} ) );
    $this->assert( !Foswiki::Func::isAnAdmin('UserB') );

#TODO: consider how to render unkown user's
#my $AandBGroup_cUID = $this->app->users->getCanonicalUserID('AandBGroup');
#$this->annotate($AandBGroup_cUID);
#$this->assert(!Foswiki::Func::isAnAdmin($AandBGroup_cUID));
#$this->assert(!Foswiki::Func::isAnAdmin('AandBGroup'));
#$this->assert(!Foswiki::Func::isAnAdmin('AandBGroup'));
#$this->assert(!Foswiki::Func::isAnAdmin($this->app->cfg->data->{UsersWebName}.'.'.'AandBGroup'));

    return;
}

sub verify_isGroupMember_extended {
    my $this = shift;

    my $guest_cUID =
      $this->app->users->getCanonicalUserID(
        $this->app->cfg->data->{DefaultUserLogin} );
    my $admin_cUID =
      $this->app->users->getCanonicalUserID(
        $this->app->cfg->data->{AdminUserLogin} );

    $this->assert(
        !Foswiki::Func::isGroupMember(
            $this->app->cfg->data->{SuperAdminGroup},
            $this->app->cfg->data->{DefaultUserLogin}
        )
    );
    $this->assert(
        !Foswiki::Func::isGroupMember(
            $this->app->cfg->data->{SuperAdminGroup}, $guest_cUID
        )
    );
    $this->assert(
        !Foswiki::Func::isGroupMember(
            $this->app->cfg->data->{SuperAdminGroup},
            $this->app->cfg->data->{DefaultUserWikiName}
        )
    );
    $this->assert(
        !Foswiki::Func::isGroupMember(
            $this->app->cfg->data->{SuperAdminGroup},
            $this->app->cfg->data->{UsersWebName} . '.'
              . $this->app->cfg->data->{DefaultUserWikiName}
        )
    );

    $this->assert(
        Foswiki::Func::isGroupMember(
            $this->app->cfg->data->{SuperAdminGroup}, $admin_cUID
        )
    );
    $this->assert(
        Foswiki::Func::isGroupMember(
            $this->app->cfg->data->{SuperAdminGroup},
            $this->app->cfg->data->{AdminUserLogin}
        )
    );
    $this->assert(
        Foswiki::Func::isGroupMember(
            $this->app->cfg->data->{SuperAdminGroup},
            $this->app->cfg->data->{AdminUserWikiName}
        )
    );
    $this->assert(
        Foswiki::Func::isGroupMember(
            $this->app->cfg->data->{SuperAdminGroup},
            $this->app->cfg->data->{UsersWebName} . '.'
              . $this->app->cfg->data->{AdminUserWikiName}
        )
    );

    return if ( $this->noUsersRegistered() );

    #TODO: not sure that this method needs to be able to convert _any_ to login
    $this->assert(
        !Foswiki::Func::isGroupMember(
            'AandBGroup', $this->app->cfg->data->{DefaultUserLogin}
        )
    );
    $this->assert( !Foswiki::Func::isGroupMember( 'AandBGroup', $guest_cUID ) );
    $this->assert(
        !Foswiki::Func::isGroupMember(
            'AandBGroup', $this->app->cfg->data->{DefaultUserWikiName}
        )
    );
    $this->assert(
        !Foswiki::Func::isGroupMember(
            'AandBGroup',
            $this->app->cfg->data->{UsersWebName} . '.'
              . $this->app->cfg->data->{DefaultUserWikiName}
        )
    );

    $this->assert( Foswiki::Func::isGroupMember( 'AandBGroup', $admin_cUID ) );
    $this->assert(
        Foswiki::Func::isGroupMember(
            'AandBGroup', $this->app->cfg->data->{AdminUserLogin}
        )
    );
    $this->assert(
        Foswiki::Func::isGroupMember(
            'AandBGroup', $this->app->cfg->data->{AdminUserWikiName}
        )
    );
    $this->assert(
        Foswiki::Func::isGroupMember(
            'AandBGroup',
            $this->app->cfg->data->{UsersWebName} . '.'
              . $this->app->cfg->data->{AdminUserWikiName}
        )
    );

    $this->assert( !Foswiki::Func::isGroupMember( 'AandCGroup', $admin_cUID ) );
    $this->assert(
        !Foswiki::Func::isGroupMember(
            'AandCGroup', $this->app->cfg->data->{AdminUserLogin}
        )
    );
    $this->assert(
        !Foswiki::Func::isGroupMember(
            'AandCGroup', $this->app->cfg->data->{AdminUserWikiName}
        )
    );
    $this->assert(
        !Foswiki::Func::isGroupMember(
            'AandCGroup',
            $this->app->cfg->data->{UsersWebName} . '.'
              . $this->app->cfg->data->{AdminUserWikiName}
        )
    );

    my $usera_cUID = $this->app->users->getCanonicalUserID( $loginname{UserA} );
    $this->assert( Foswiki::Func::isGroupMember( 'AandBGroup', $usera_cUID ) );
    $this->assert(
        Foswiki::Func::isGroupMember( 'AandBGroup', $loginname{UserA} ) );
    $this->assert( Foswiki::Func::isGroupMember( 'AandBGroup', 'UserA' ) );
    $this->assert(
        Foswiki::Func::isGroupMember(
            'AandBGroup', $this->app->cfg->data->{UsersWebName} . '.' . 'UserA'
        )
    );

    #TODO: consider how to render unkown user's
    my $nonexistantuser_cUID =
      $this->app->users->getCanonicalUserID( $loginname{NonExistantuser} );
    $this->annotate($nonexistantuser_cUID);
    $this->assert(
        !Foswiki::Func::isGroupMember( 'AandBGroup', $nonexistantuser_cUID ) );
    $this->assert(
        !Foswiki::Func::isGroupMember(
            'AandBGroup', $loginname{NonExistantuser}
        )
    );
    $this->assert(
        !Foswiki::Func::isGroupMember( 'AandBGroup', 'NonExistantUser' ) );
    $this->assert(
        !Foswiki::Func::isGroupMember(
            'AandBGroup',
            $this->app->cfg->data->{UsersWebName} . '.' . 'NonExistantUser'
        )
    );

#TODO: consider how to render unkown user's
#my $AandBGroup_cUID = $this->app->users->getCanonicalUserID('AandBGroup');
#$this->annotate($AandBGroup_cUID);
#$this->assert(!Foswiki::Func::isGroupMember('AandBGroup', $AandBGroup_cUID));
#$this->assert(!Foswiki::Func::isGroupMember('AandBGroup', 'AandBGroup'));
#$this->assert(!Foswiki::Func::isGroupMember('AandBGroup', 'AandBGroup'));
#$this->assert(!Foswiki::Func::isGroupMember('AandBGroup', $this->app->cfg->data->{UsersWebName}.'.'.'AandBGroup'));

    #baseusermapping group
    $this->assert(
        Foswiki::Func::isGroupMember(
            $this->app->cfg->data->{SuperAdminGroup}, $usera_cUID
        )
    );
    $this->assert(
        Foswiki::Func::isGroupMember(
            $this->app->cfg->data->{SuperAdminGroup},
            $loginname{UserA}
        )
    );
    $this->assert(
        Foswiki::Func::isGroupMember(
            $this->app->cfg->data->{SuperAdminGroup}, 'UserA'
        )
    );
    $this->assert(
        Foswiki::Func::isGroupMember(
            $this->app->cfg->data->{SuperAdminGroup},
            $this->app->cfg->data->{UsersWebName} . '.' . 'UserA'
        )
    );

    $this->assert(
        !Foswiki::Func::isGroupMember(
            $this->app->cfg->data->{SuperAdminGroup},
            $loginname{UserB}
        )
    );
    my $userb_cUID = $this->app->users->getCanonicalUserID( $loginname{UserB} );
    $this->assert(
        !Foswiki::Func::isGroupMember(
            $this->app->cfg->data->{SuperAdminGroup}, $userb_cUID
        )
    );
    $this->assert(
        !Foswiki::Func::isGroupMember(
            $this->app->cfg->data->{SuperAdminGroup}, 'UserB'
        )
    );
    $this->assert(
        !Foswiki::Func::isGroupMember(
            $this->app->cfg->data->{SuperAdminGroup},
            $this->app->cfg->data->{UsersWebName} . '.' . 'UserB'
        )
    );

    return;
}

#http://foswiki.org/Tasks/Item6000
# Done here rather than in Fn_META to leverage the test fixture
sub verify_topic_meta_usermapping {
    my $this = shift;

    return if ( $this->app->cfg->data->{Register}{AllowLoginName} == 0 );

    $this->app->cfg->data->{RenderLoggedInButUnknownUsers} = 1;

    my $web   = $this->test_web;
    my $topic = "TestStoreTopic";

    $this->assert(
        open(
            my $FILE, '>',
            $this->app->cfg->data->{TempfileDir} . "/testfile.gif"
        )
    );
    print $FILE "one two three";
    $this->assert( close($FILE) );

    my $oldCfg = $this->app->cfg->data->{LoginNameFilterIn};
    $this->app->cfg->data->{LoginNameFilterIn} =
      qr/^[^\s\*?~^\$%`"'&;|<>\x00-\x1f]+$/;

    my $login = 'asdf2@example.com';
    $this->registerUser( $login, 'Asdf3', 'Poiu', 'asdf2@example.com' );
    my $cUID = Foswiki::Func::getCanonicalUserID($login);
    $this->app->user($cUID);    # OUCH!

    my $text = "This is some test text\n   * some list\n   * content\n :) :)";
    my ($topicObject) = Foswiki::Func::readTopic( $web, $topic );
    $topicObject->text($text);
    $topicObject->save();
    undef $topicObject;

    $this->assert( $this->app->store->topicExists( $web, $topic ) );
    my ($readMeta) = Foswiki::Func::readTopic( $web, $topic );
    my $info = $readMeta->getRevisionInfo();
    $this->assert_equals( $info->{author}, $cUID, "$info->{author}=$cUID" );
    my $revinfo =
      Foswiki::Func::expandCommonVariables( '%REVINFO{format="$wikiname"}%',
        $topic, $web, $readMeta );

    #Task:Item6000
    $this->assert_equals( $revinfo, 'Asdf3Poiu', 'Asdf3Poiu' );

    $readMeta->attach(
        name    => "testfile.gif",
        file    => $this->app->cfg->data->{TempfileDir} . "/testfile.gif",
        comment => "a comment",
        filedate => 1262347200,    # 01 Jan 2010 12:00
    );
    undef $topicObject;
    ($readMeta) = Foswiki::Func::readTopic( $web, $topic );

    my @attachments = $readMeta->find('FILEATTACHMENT');
    $this->assert_equals( 1, scalar @attachments );
    foreach my $a (@attachments) {

        #Task:Item6000
        $this->assert_str_equals( $cUID, $a->{user} );
    }

    #META
    my $metainfo = $readMeta->expandMacros('%META{"attachments"}%');
    undef $topicObject;

    #Task:Item6000
    $metainfo =~ s/^.*?(\|.*\|).*?$/$1/s;
    my $size          = $this->post11 ? '1 byte' : '0.1&nbsp;K';
    my $pubUrlPath    = $this->app->cfg->data->{PubUrlPath};
    my $scriptUrlPath = $this->app->cfg->data->{ScriptUrlPath};
    my $scriptSuffix  = $this->app->cfg->data->{ScriptSuffix};
    $this->assert_html_equals( <<"HERE", $metainfo );
| *I* | *Attachment* | *Action* | *Size* | *Date* | *Who* | *Comment* |
| <span class=foswikiIcon><img width="16" alt="testfile.gif" src="$pubUrlPath/System/DocumentGraphics/gif.png" height="16" /></span><span class="foswikiHidden">gif</span> | <a href="$pubUrlPath/TemporaryFuncUsersTestWebFuncUsers/TestStoreTopic/testfile.gif"><noautolink>testfile.gif</noautolink></a> | <a href="$scriptUrlPath/attach$scriptSuffix/TemporaryFuncUsersTestWebFuncUsers/TestStoreTopic?filename=testfile.gif;revInfo=1" title="change, update, previous revisions, move, delete..." rel="nofollow">manage</a> |  $size|<span class="foswikiNoBreak">01 Jan 2010 - 12:00</span> |TemporaryFuncUsersUsersWeb.Asdf3Poiu  |a comment  |
HERE

    return;
}

sub verify_addToGroup {
    my $this = shift;

    return if ( $this->noUsersRegistered() );

    my $Zcuid = $this->app->users->getCanonicalUserID( $loginname{UserZ} );
    $this->assert( $this->app->user );

    $this->assert( !Foswiki::Func::isGroupMember( 'ZeeGroup', 'UserZ' ) );
    $this->assert( !Foswiki::Func::addUserToGroup( 'UserZ', 'ZeeGroup' ) );

    # Force a re-read

    $this->createNewFoswikiApp;

    $this->assert( !Foswiki::Func::isGroupMember( 'ZeeGroup', 'UserZ' ) );

    #TODO: need to test who the topic was saved by

    $this->assert( Foswiki::Func::addUserToGroup( 'UserZ', 'ZeeGroup', 1 ) );

    # Force a re-read

    $this->createNewFoswikiApp(
        engineParams => {
            initialAttributes =>
              { user => $this->app->cfg->data->{AdminUserLogin}, },
        },
    );

    $this->assert( Foswiki::Func::isGroupMember( 'ZeeGroup', 'UserZ' ) );

    $this->assert( !Foswiki::Func::isGroupMember( 'ZeeGroup', 'UserA' ) );
    $this->assert( Foswiki::Func::addUserToGroup( 'UserA86', 'ZeeGroup' ) );

    # Force a re-read

    $this->createNewFoswikiApp(
        engineParams => {
            initialAttributes =>
              { user => $this->app->cfg->data->{AdminUserLogin}, },
        },
    );

    $this->assert( Foswiki::Func::isGroupMember( 'ZeeGroup', 'UserA86' ) );
    $this->assert( !Foswiki::Func::isGroupMember( 'ZeeGroup', 'UserA' ) );

    $this->assert( Foswiki::Func::addUserToGroup( 'UserA', 'ZeeGroup' ) );

    # Force a re-read

    $this->createNewFoswikiApp(
        engineParams => {
            initialAttributes =>
              { user => $this->app->cfg->data->{AdminUserLogin}, },
        },
    );

    $this->assert( Foswiki::Func::isGroupMember( 'ZeeGroup', 'UserA86' ) );
    $this->assert( Foswiki::Func::isGroupMember( 'ZeeGroup', 'UserA' ) );

    $this->assert(
        !Foswiki::Func::isGroupMember(
            'ZeeGroup', $this->app->cfg->data->{DefaultUserLogin}
        )
    );
    $this->assert(
        Foswiki::Func::addUserToGroup(
            $this->app->cfg->data->{DefaultUserLogin}, 'ZeeGroup'
        )
    );

    # Force a re-read

    $this->createNewFoswikiApp;

    $this->assert(
        Foswiki::Func::isGroupMember(
            'ZeeGroup', $this->app->cfg->data->{DefaultUserLogin}
        )
    );

    $this->assert(
        !Foswiki::Func::isGroupMember( 'ZeeGroup', 'WiseGuyDoesntExist' ) );

    # Note that people that do not exist must still successfully be added to
    # group per Item Item9848
    $this->assert(
        Foswiki::Func::addUserToGroup( 'WiseGuyDoesntExist', 'ZeeGroup' ) );

    # Force a re-read

    $this->createNewFoswikiApp;

    # Func::isGroupMember must return success if the user is in the group
    # Being a member of a group requires that you are listed in the group
    # topic and you do not need to be known by the user mapper (Item9848)
    $this->assert(
        Foswiki::Func::isGroupMember( 'ZeeGroup', 'WiseGuyDoesntExist' ) );

    return;
}

sub verify_NestedGroups {
    my $this = shift;

    #   NestingGroup =   * Set GROUP = UserE, AandCGroup, BandCGroup" );
    return if ( $this->noUsersRegistered() );

    # Force a re-read

    $this->createNewFoswikiApp(
        engineParams => {
            initialAttributes =>
              { user => $this->app->cfg->data->{AdminUserLogin}, },
        },
    );

    #test nested groups
    $this->assert( Foswiki::Func::addUserToGroup( 'UserZ', 'TeeGroup', 1 ) );
    $this->assert(
        Foswiki::Func::addUserToGroup( 'NestingGroup', 'TeeGroup', 1 ) );

    # Force a re-read

    $this->createNewFoswikiApp(
        engineParams => { initialAttributes => { user => 'UserZ', }, }, );

    my $it = Foswiki::Func::eachGroupMember('TeeGroup');
    my @list;
    while ( $it->hasNext() ) {
        my $g = $it->next();
        push( @list, $g );
    }
    $this->assert_str_equals( "UserZ,UserE,UserA,UserC,UserB",
        sort join( ',', @list ) );

    @list = ();
    $it = Foswiki::Func::eachGroupMember( 'TeeGroup', { expand => 'False' } );
    while ( $it->hasNext() ) {
        my $g = $it->next();
        push( @list, $g );
    }
    $this->assert_str_equals( "UserZ,NestingGroup", sort join( ',', @list ) );

   #$this->assert( !Foswiki::Func::removeUserFromGroup( 'UserE', 'TeeGroup' ) );
   #$this->assert( Foswiki::Func::removeUserFromGroup( 'UserZ', 'TeeGroup' ) );
    $this->assert(
        Foswiki::Func::removeUserFromGroup( 'NestingGroup', 'TeeGroup' ) );

    # Force a re-read

    $this->createNewFoswikiApp;

    @list = ();
    $it = Foswiki::Func::eachGroupMember( 'TeeGroup', { expand => 0 } );
    while ( $it->hasNext() ) {
        my $g = $it->next();
        push( @list, $g );
    }
    $this->assert_str_equals( "UserZ", sort join( ',', @list ) );

    $this->assert(
        !Foswiki::Func::isGroupMember( 'TeeGroup', 'NestingGroup' ) );

    #$this->assert( !Foswiki::Func::isGroupMember( 'TeeGroup', 'UserA' ) );
    #$this->assert( !Foswiki::Func::isGroupMember( 'TeeGroup', 'UserB' ) );
    $this->assert( !Foswiki::Func::isGroupMember( 'TeeGroup', 'UserC' ) );
    $this->assert( !Foswiki::Func::isGroupMember( 'TeeGroup', 'UserE' ) );
    $this->assert( Foswiki::Func::isGroupMember( 'TeeGroup',     'UserZ' ) );
    $this->assert( Foswiki::Func::isGroupMember( 'NestingGroup', 'UserE' ) );

    return;
}

sub verify_removeFromGroup {
    my $this = shift;

    return if ( $this->noUsersRegistered() );

    $this->assert( !Foswiki::Func::topicExists( undef, 'ZeeGroup' ) );

    $this->assert( !Foswiki::Func::isGroupMember( 'ZeeGroup', 'UserZ' ) );
    $this->assert( !Foswiki::Func::isGroupMember( 'ZeeGroup', 'UserA' ) );
    $this->assert( !Foswiki::Func::isGroupMember( 'ZeeGroup', 'UserB' ) );
    $this->assert(
        !Foswiki::Func::isGroupMember( 'WiseGuyDoesntExist', 'ZeeGroup' ) );

    $this->assert(
        Foswiki::Func::addUserToGroup( $this->app->user, 'ZeeGroup', 1 ) );

    $this->assert( Foswiki::Func::topicExists( undef, 'ZeeGroup' ) );
    my ( $date, $user, $rev, $comment );
    ( $date, $user, $rev, $comment ) =
      Foswiki::Func::getRevisionInfo( undef, 'ZeeGroup' );
    $this->assert( $rev == 1 );
    $this->assert( Foswiki::Func::isGroupMember( 'ZeeGroup', 'guest' ) );

    $this->assert( Foswiki::Func::addUserToGroup( 'UserZ', 'ZeeGroup', 1 ) );
    ( $date, $user, $rev, $comment ) =
      Foswiki::Func::getRevisionInfo( undef, 'ZeeGroup' );
    $this->assert( $rev == 1 );
    $this->assert( Foswiki::Func::isGroupMember( 'ZeeGroup', 'UserZ' ) );

    $this->assert( Foswiki::Func::addUserToGroup( 'UserA', 'ZeeGroup', 1 ) );
    ( $date, $user, $rev, $comment ) =
      Foswiki::Func::getRevisionInfo( undef, 'ZeeGroup' );
    $this->assert( $rev == 1 );
    $this->assert( Foswiki::Func::isGroupMember( 'ZeeGroup', 'UserA' ) );

    $this->assert(
        Foswiki::Func::addUserToGroup( 'WiseGuyDoesntExist', 'ZeeGroup', 1 ) );
    ( $date, $user, $rev, $comment ) =
      Foswiki::Func::getRevisionInfo( undef, 'ZeeGroup' );
    $this->assert( $rev == 1 );
    $this->assert(
        Foswiki::Func::isGroupMember( 'ZeeGroup', 'WiseGuyDoesntExist' ) );

    # Force a re-read

    $this->createNewFoswikiApp;

    $this->assert( Foswiki::Func::isGroupMember( 'ZeeGroup', 'UserZ' ) );
    $this->assert( Foswiki::Func::isGroupMember( 'ZeeGroup', 'UserA' ) );

    # We verify that the user WiseGuyDoesntExist is not a member of the group
    $this->assert( !Foswiki::Func::isGroupMember( 'UserB', 'ZeeGroup' ) );

    # Removing a user that is a member of the group should work no matter
    # if he is known by user mapper or password manager
    $this->assert( Foswiki::Func::removeUserFromGroup( 'UserA', 'ZeeGroup' ) );
    $this->assert(
        Foswiki::Func::removeUserFromGroup( 'WiseGuyDoesntExist', 'ZeeGroup' )
    );

    # Removing a user that is not member of the group should fail
    try {
        Foswiki::Func::removeUserFromGroup( 'UserB', 'ZeeGroup' );
        $this->assert('Remove User should not work');
    }
    catch {
        my $e = $_;
        Foswiki::Exception::Fatal->rethrow($e) unless ref($e);
        $this->assert_matches( qr{User .* not in group, cannot be removed},
            $e->stringify );
    };

    try {
        Foswiki::Func::removeUserFromGroup( 'SillyGuyDoesntExist', 'ZeeGroup' );
        $this->assert('Remove User should not work');
    }
    catch {
        my $e = $_;
        Foswiki::Exception::Fatal->rethrow($e) unless ref($e);
        $this->assert_matches( qr{User .* not in group, cannot be removed},
            $e->stringify );
    };

    # Force a re-read

    $this->createNewFoswikiApp;

    $this->assert( Foswiki::Func::isGroupMember( 'ZeeGroup', 'UserZ' ) );
    $this->assert( !Foswiki::Func::isGroupMember( 'ZeeGroup', 'UserA' ) );
    $this->assert(
        !Foswiki::Func::isGroupMember( 'ZeeGroup', 'WiseGuyDoesntExist' ) );

    return;
}

sub DISABLEDverify_removeFromGroup {
    my $this = shift;

    return if ( $this->noUsersRegistered() );

    #test nested groups
    $this->assert( Foswiki::Func::addUserToGroup( 'UserB',    'TeeGroup', 1 ) );
    $this->assert( Foswiki::Func::addUserToGroup( 'UserC',    'TeeGroup', 1 ) );
    $this->assert( Foswiki::Func::addUserToGroup( 'ZeeGroup', 'TeeGroup', 1 ) );

    # Force a re-read

    $this->createNewFoswikiApp;

    $this->assert( Foswiki::Func::isGroupMember( 'TeeGroup', 'UserB' ) );
    $this->assert( Foswiki::Func::isGroupMember( 'TeeGroup', 'UserA' ) );

    $this->assert( !Foswiki::Func::removeUserFromGroup( 'UserA', 'TeeGroup' ) )
      ;    #can't remove user as they come from a subgroup..
    $this->assert( Foswiki::Func::removeUserFromGroup( 'UserB', 'TeeGroup' ) );

    # Force a re-read

    $this->createNewFoswikiApp;

    $this->assert( !Foswiki::Func::isGroupMember( 'TeeGroup', 'UserB' ) );
    $this->assert( Foswiki::Func::isGroupMember( 'TeeGroup', 'UserA' ) );
    $this->assert( Foswiki::Func::isGroupMember( 'TeeGroup', 'UserC' ) );

    $this->assert(
        Foswiki::Func::removeUserFromGroup( 'ZeeGroup', 'TeeGroup' ) );

    # Force a re-read

    $this->createNewFoswikiApp;

    $this->assert( !Foswiki::Func::isGroupMember( 'TeeGroup', 'UserB' ) );
    $this->assert( !Foswiki::Func::isGroupMember( 'TeeGroup', 'UserA' ) );
    $this->assert( Foswiki::Func::isGroupMember( 'TeeGroup', 'UserC' ) );

    #TODO: test what happens if there are no users left in the group

    return;
}

#http://foswiki.org/Tasks/Item1936
sub verify_topic_meta_usermapping_Item1936 {
    my $this = shift;

    my $users = $this->app->users;

    #this sort of issue is what this setting was supposed to make more obvious
    #$this->app->cfg->data->{RenderLoggedInButUnknownUsers} = 1;

    $this->assert_null( Foswiki::Func::getCanonicalUserID('NonExistantUser') );
    $users->getWikiName('NonExistantUser');
    $this->assert_null( Foswiki::Func::getCanonicalUserID('NonExistantUser') );

    return;
}

#http://foswiki.org/Tasks/Item12262
sub verify_getWikiNameOfWikiName {
    my $this = shift;

    my $users = $this->app->users;

    use Data::Dumper;

    #_dumpUserCache($users);

    #  This will populate the caches.  But this test is for a corrupted cache
    if (0) {
        my @list;
        my $ite = Foswiki::Func::eachUser();
        while ( $ite->hasNext() ) {
            my $u = $ite->next();
            push( @list, $u );
        }
    }

    # Dump the caches,  shoudl be empty except for the guest user
    #print STDERR "=======  CACHE Before tests ============\n";
    #_dumpUserCache($users);

    # Calling getWikiName for a WikiName corrupts the caches
    $this->assert_equals( Foswiki::Func::getWikiName('UserA'),
        'UserA', 'getWikiName failed to return expected WikiName' );

    # Dump the caches, should contain the mappings for UserA
    #print STDERR "=======  CACHE After corruption ============\n";
    #_dumpUserCache($users);

    $this->assert_equals( Foswiki::Func::wikiToUserName('UserA'),
        $loginname{UserA},
        'wikiToUserName failed to return expected login name' );

    $this->assert_equals( Foswiki::Func::userToWikiName( $loginname{UserA}, 1 ),
        "UserA", 'userToWikiName failed to return expected Users WikiName' );

    $this->assert_equals(
        Foswiki::Func::userToWikiName( $loginname{UserA} ),
        $this->app->cfg->data->{UsersWebName} . ".UserA",
        'userToWikiName failed to return expected Users topic name'
    );

# Verify all 3 flavors of retrieving the CanonicalUserID.  Login, Wiki or Web.Wiki
    $this->assert_equals(
        Foswiki::Func::getCanonicalUserID( $loginname{UserA} ),
        $loginname{UserA},
        'getCanonicalUserID failed when called with login name' );
    $this->assert_equals( Foswiki::Func::getCanonicalUserID('UserA'),
        $loginname{UserA},
        'getCanonicalUserID failed when called with WikiName' );
    $this->assert_equals(
        Foswiki::Func::getCanonicalUserID(
            $this->app->cfg->data->{UsersWebName} . ".UserA"
        ),
        $loginname{UserA},
        'getCanonicalUserID failed when called with Web.WikiName'
    );

    # Verify that all of the cache entries are valid
    $this->assert_equals(
        $loginname{UserA},
        $users->_getMapping( $loginname{UserA} )->L2U->{ $loginname{UserA} },
        'L2U is incorrect'
    ) if defined $users->_getMapping( $loginname{UserA} )->L2U;
    $this->assert_equals(
        $loginname{UserA},
        $users->_getMapping( $loginname{UserA} )->W2U->{UserA},
        'W2U is incorrect'
    ) if defined $users->_getMapping( $loginname{UserA} )->W2U;
    $this->assert_equals(
        'UserA',
        $users->_getMapping( $loginname{UserA} )->U2W->{ $loginname{UserA} },
        'U2W is incorrect'
    ) if defined $users->_getMapping( $loginname{UserA} )->U2W;

    #print STDERR "=======  CACHE At End ============\n";
    #_dumpUserCache($users);

    return;
}

sub _dumpUserCache {
    my $users = shift;
    print STDERR 'WikiName2CUID: '
      . Data::Dumper::Dumper( \$users->wikiName2cUID );
    print STDERR 'cUID2WkikName: '
      . Data::Dumper::Dumper( \$users->cUID2WikiName );
    print STDERR 'cUID2Login: ' . Data::Dumper::Dumper( \$users->cUID2Login );
    print STDERR 'login2cUID: ' . Data::Dumper::Dumper( \$users->login2cUID );
    print STDERR 'L2U'
      . Data::Dumper::Dumper(
        \$users->_getMapping( $loginname{'UserA'} )->L2U );
    print STDERR 'W2U'
      . Data::Dumper::Dumper(
        \$users->_getMapping( $loginname{'UserA'} )->W2U );
    print STDERR 'U2W'
      . Data::Dumper::Dumper(
        \$users->_getMapping( $loginname{'UserA'} )->U2W );
}

#http://foswiki.org/Tasks/
sub verify_unregisteredUser_display {
    my $this = shift;

    my $users = $this->app->users;

    #this sort of issue is what this setting was supposed to make more obvious
    #$this->app->cfg->data->{RenderLoggedInButUnknownUsers} = 1;

    $this->assert_equals( $users->getWikiName('NonExistantUser'),
        'NonExistantUser', 'wikiword wikiname' );
    $this->assert_equals( $users->getLoginName('NonExistantUser'),
        undef, 'wikiword wikiname' );
    $this->assert_equals( $users->getCanonicalUserID('NonExistantUser'),
        undef, 'wikiword wikiname' );

    $this->assert_equals( $users->getWikiName('user_name'),
        'user_name', 'wikiword wikiname' );
    $this->assert_equals( $users->getLoginName('user_name'),
        undef, 'wikiword wikiname' );
    $this->assert_equals( $users->getCanonicalUserID('user_name'),
        undef, 'wikiword wikiname' );

    return;
}

# Introduced on store2 branch, Item11135. Not passing on svn trunk yet
sub DISABLEDverify_denyNonAdminReadOfAdminGroupTopic {
    my $this = shift;

    return if ( $this->noUsersRegistered() );

    # Force a re-read

    $this->createNewFoswikiApp(
        engineParams => {
            initialAttributes =>
              { user => $this->app->cfg->data->{AdminUserLogin}, },
        },
    );

    $this->assert( Foswiki::Func::addUserToGroup( 'UserB', 'AdminGroup', 1 ) );

    my ($topicObject) =
      Foswiki::Func::readTopic( $this->users_web, 'AdminGroup' );
    $topicObject->text(
        $topicObject . "\n\n   * Set ALLOWTOPICVIEW = AdminGroup\n\n" );
    $topicObject->save();
    undef $topicObject;

    {

        $this->createNewFoswikiApp(
            engineParams => {
                initialAttributes =>
                  { user => $this->app->cfg->data->{AdminUserLogin}, },
            },
        );

        my $it = Foswiki::Func::eachGroupMember('AdminGroup');
        my @list;
        while ( $it->hasNext() ) {
            my $g = $it->next();
            push( @list, $g );
        }

    #as the baseusermapper is always admin, they should always see the full list
        $this->assert_str_equals( "AdminUser,UserA,UserB",
            sort join( ',', @list ) );
        $this->assert( $this->app->users->isAdmin() );
    }

    {

        # Force a re-read

        $this->createNewFoswikiApp(
            engineParams => { initialAttributes => { user => 'UserB', }, }, );

        my $it = Foswiki::Func::eachGroupMember('AdminGroup');
        my @list;
        while ( $it->hasNext() ) {
            my $g = $it->next();
            push( @list, $g );
        }
        $this->assert_str_equals( "AdminUser,UserA,UserB",
            sort join( ',', @list ) );
        $this->assert( $this->app->isAdmin() )
    }

    {

        # Force a re-read

        $this->createNewFoswikiApp(
            engineParams => { initialAttributes => { user => 'UserZ', }, }, );

        my $it = Foswiki::Func::eachGroupMember('AdminGroup');
        my @list;
        while ( $it->hasNext() ) {
            my $g = $it->next();
            push( @list, $g );
        }
        $this->assert_str_equals( "AdminUser,UserA,UserB",
            sort join( ',', @list ) );
        $this->assert( not $this->app->isAdmin() )
    }

    return;
}

1;
