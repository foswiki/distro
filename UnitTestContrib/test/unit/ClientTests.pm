package ClientTests;
use v5.14;

# This is woefully incomplete, but it does at least check that
# LoginManager.pm compiles okay.

use Foswiki();
use Foswiki::LoginManager();
use Try::Tiny;
use Digest::MD5 qw(md5_hex);
use Scalar::Util qw(blessed);

use Moo;
use namespace::clean;
extends qw( FoswikiFnTestCase );

my $agent = $Foswiki::cfg{Register}{RegistrationAgentWikiName};
my $userLogin;
my $userWikiName;
my $user_id;
our $EDIT_UI_FN;
our $VIEW_UI_FN;

around set_up => sub {
    my $orig = shift;
    my $this = shift;
    $orig->( $this, @_ );
    my ($topicObject) =
      Foswiki::Func::readTopic( $this->test_web, $this->test_topic );
    $topicObject->text(<<'CONSTRAINT');
   * Set ALLOWTOPICCHANGE = AdminGroup
CONSTRAINT
    $topicObject->save();

    $this->app->cfg->data->{DisableAllPlugins} = 1;

    return;
};

sub TemplateLoginManager {
    $Foswiki::cfg{LoginManager} = 'Foswiki::LoginManager::TemplateLogin';

    return;
}

sub ApacheLoginManager {
    $Foswiki::cfg{LoginManager} = 'Foswiki::LoginManager::ApacheLogin';

    return;
}

sub NoLoginManager {
    $Foswiki::cfg{LoginManager} = 'none';

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
    return ( [ 'TemplateLoginManager', 'ApacheLoginManager', 'NoLoginManager' ],
        [ 'TopicUserMapping', 'BaseUserMapping' ] );
}

sub set_up_for_verify {

    #print STDERR "\n------------- set_up -----------------\n";
    my $this = shift;

    $this->createNewFoswikiApp;
    $this->assert( $Foswiki::cfg{TempfileDir}
          && -d $Foswiki::cfg{TempfileDir} );
    $Foswiki::cfg{UseClientSessions}  = 1;
    $Foswiki::cfg{PasswordManager}    = "Foswiki::Users::HtPasswdUser";
    $Foswiki::cfg{Htpasswd}{FileName} = "$Foswiki::cfg{TempfileDir}/htpasswd";
    $Foswiki::cfg{AuthScripts}        = "edit";
    $Foswiki::cfg{Register}{EnableNewUserRegistration} = 1;
    $Foswiki::cfg{UsersWebName} = $this->users_web;

    return;
}

sub set_up_user {
    my $this  = shift;
    my $app   = $this->app;
    my $users = $app->users;
    if ( $users->supportsRegistration() ) {
        $userLogin    = 'joe';
        $userWikiName = 'JoeDoe';
        $user_id =
          $users->addUser( $userLogin, $userWikiName,
            'secrect_password', 'email@home.org.au' );
        $this->annotate("create $userLogin user - cUID = $user_id\n");
    }
    else {
        $userLogin    = $Foswiki::cfg{AdminUserLogin};
        $user_id      = $users->getCanonicalUserID($userLogin);
        $userWikiName = $users->getWikiName($user_id);
        $this->annotate("no registration support (using admin)\n");
    }

#print STDERR "\n------------- set_up_user (login: $userLogin) (cUID:$user_id) -----------------\n";

    return;
}

around capture => sub {
    my $orig = shift;
    my $this = shift;
    $this->app->users->getLoginManager()->checkAccess();
    return $orig->( $this, @_ );
};

sub verify_edit {

    #print STDERR "\n------------- verify_edit -----------------\n";

    my $this = shift;
    my ($text);

    #close this Foswiki session - its using the wrong mapper and login

    $this->createNewFoswikiApp(
        engineParams => {
            simulate          => 'cgi',
            initialAttributes => {
                path_info => "/" . $this->test_web . "/" . $this->test_topic,
                action    => 'view',
            },
        },
    );

    $this->set_up_user();
    try {
        ($text) = $this->capture(
            sub {
                return $this->app->handleRequest;
            }
        );
    }
    catch {
        my $e = $_;

        # SMELL Error::Simple and Foswiki::Exception are not really equivalent.
        if ( blessed($e) && $e->isa('Foswiki::OopsException') ) {

            # Fail but stringify Oops into human-readable form.
            $this->assert( 0, $e->stringify() );
        }
        else {
            Foswiki::Exception::Fatal->rethrow($e);
        }
    };

    $this->createNewFoswikiApp(
        engineParams => {
            simulate          => 'cgi',
            initialAttributes => {
                path_info => "/" . $this->test_web . "/" . $this->test_topic,
                action    => 'edit',
            },
        },
    );
    $this->app->request->param( '-breaklock', 1 );

    try {
        ($text) = $this->capture(
            sub {
                return $this->app->handleRequest;
            }
        );
    }
    catch {
        my $e = $_;
        $e = Foswiki::Exception::Fatal->transmute( $e, 0 );
        unless ( $e->isa('Foswiki::AccessControlException') ) {
            if (  !$e->isa('Foswiki::Exception::Fatal')
                && $Foswiki::cfg{LoginManager} ne 'none' )
            {
                $this->assert( 0,
                        "expected an access control exception: "
                      . $Foswiki::cfg{LoginManager}
                      . "\n$text" );
            }
            else {
                $e->rethrow;
            }
        }
    };

    $this->annotate("new session using $userLogin\n");

    $this->createNewFoswikiApp( user => $userLogin, );

#clear the lease - one of the previous tests may have different usermapper & thus different user
    Foswiki::Func::setTopicEditLock( $this->test_web, $this->test_topic, 0 );

    return;
}

sub verify_sudo_login {
    my $this = shift;

    my $users = $this->app->users;
    unless ( $users->getLoginManager()->can("login") ) {
        return;
    }
    my $secret = "a big mole on my left buttock";

    # Test new style MD5 hashed password
    my $crypted = '$1234asdf$' . Digest::MD5::md5_hex( '$1234asdf$' . $secret );
    $Foswiki::cfg{Password} = $crypted;

    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                username => [ $Foswiki::cfg{AdminUserLogin} ],
                password => [$secret],
                Logon    => [1],
                skin     => ['none'],
            },
        },
        engineParams => {
            initialAttributes =>
              { path_info => "/" . $this->test_web . "/" . $this->test_topic, },
        }
    );
    $this->app->users->getLoginManager->login;
    my $script = $Foswiki::cfg{LoginManager} =~ m/Apache/ ? 'viewauth' : 'view';
    my $surly =
      $this->app->cfg->getScriptUrl( 0, $script, $this->test_web,
        $this->test_topic );
    $this->assert_matches( qr/^302/, $this->app->response->status() );
    $this->assert_matches( qr/^$surly/,
        $this->app->response->headers->{Location} );

    # Verify that old crypted password works
    $crypted = crypt( $secret, "12" );
    $Foswiki::cfg{Password} = $crypted;

    # SMELL: 8 character truncated password will match.
    $secret = substr( $secret, 0, 8 );

    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                username => [ $Foswiki::cfg{AdminUserLogin} ],
                password => [$secret],
                Logon    => [1],
                skin     => ['none'],
            },
        },
        engineParams => {
            initialAttributes =>
              { path_info => "/" . $this->test_web . "/" . $this->test_topic, },
        }
    );
    $this->app->users->getLoginManager->login;
    $script = $Foswiki::cfg{LoginManager} =~ m/Apache/ ? 'viewauth' : 'view';
    $surly =
      $this->app->cfg->getScriptUrl( 0, $script, $this->test_web,
        $this->test_topic );
    $this->assert_matches( qr/^302/, $this->app->response->status );
    $this->assert_matches( qr/^$surly/,
        $this->app->response->headers->{Location} );

    return;
}

1;
