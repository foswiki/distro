package ClientTests;
use strict;
use warnings;

# This is woefully incomplete, but it does at least check that
# LoginManager.pm compiles okay.

use FoswikiFnTestCase();
our @ISA = qw( FoswikiFnTestCase );

use Foswiki();
use Foswiki::LoginManager();
use Unit::Request();
use Error qw( :try );

my $agent = $Foswiki::cfg{Register}{RegistrationAgentWikiName};
my $userLogin;
my $userWikiName;
my $user_id;
our $EDIT_UI_FN;
our $VIEW_UI_FN;

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();
    $EDIT_UI_FN ||= $this->getUIFn('edit');
    $VIEW_UI_FN ||= $this->getUIFn('view');
    my $topicObject = Foswiki::Meta->new(
        $this->{session},    $this->{test_web},
        $this->{test_topic}, <<'CONSTRAINT');
   * Set ALLOWTOPICCHANGE = AdminGroup
CONSTRAINT
    $topicObject->save();

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

    $this->createNewFoswikiSession( undef, Unit::Request->new() );
    $this->assert( $Foswiki::cfg{TempfileDir}
          && -d $Foswiki::cfg{TempfileDir} );
    $Foswiki::cfg{UseClientSessions}  = 1;
    $Foswiki::cfg{PasswordManager}    = "Foswiki::Users::HtPasswdUser";
    $Foswiki::cfg{Htpasswd}{FileName} = "$Foswiki::cfg{TempfileDir}/htpasswd";
    $Foswiki::cfg{AuthScripts}        = "edit";
    $Foswiki::cfg{Register}{EnableNewUserRegistration} = 1;
    $Foswiki::cfg{UsersWebName} = $this->{users_web};

    return;
}

sub set_up_user {
    my $this = shift;
    if ( $this->{session}->{users}->supportsRegistration() ) {
        $userLogin    = 'joe';
        $userWikiName = 'JoeDoe';
        $user_id =
          $this->{session}->{users}
          ->addUser( $userLogin, $userWikiName, 'secrect_password',
            'email@home.org.au' );
        $this->annotate("create $userLogin user - cUID = $user_id\n");
    }
    else {
        $userLogin = $Foswiki::cfg{AdminUserLogin};
        $user_id   = $this->{session}->{users}->getCanonicalUserID($userLogin);
        $userWikiName = $this->{session}->{users}->getWikiName($user_id);
        $this->annotate("no registration support (using admin)\n");
    }

#print STDERR "\n------------- set_up_user (login: $userLogin) (cUID:$user_id) -----------------\n";

    return;
}

sub capture {
    my ( $this, $proc, $session, @args ) = @_;
    $session->getLoginManager()->checkAccess();
    $this->SUPER::capture( $proc, $session, @args );

    return;
}

sub verify_edit {

    #print STDERR "\n------------- verify_edit -----------------\n";

    my $this = shift;
    my ( $query, $text );

    #close this Foswiki session - its using the wrong mapper and login

    $query = Unit::Request->new();
    $query->path_info("/$this->{test_web}/$this->{test_topic}");
    $this->createNewFoswikiSession( undef, $query );

    $this->set_up_user();
    try {
        ($text) = $this->capture( $VIEW_UI_FN, $this->{session} );
    }
    catch Foswiki::OopsException with {
        $this->assert( 0, shift->stringify() );
    }
    catch Error::Simple with {
        $this->assert( 0, shift->stringify() );
    };

    $query = Unit::Request->new();
    $query->path_info("/$this->{test_web}/$this->{test_topic}?breaklock=1");

    $this->createNewFoswikiSession( undef, $query );

    try {
        ($text) = $this->capture( $EDIT_UI_FN, $this->{session} );
    }
    catch Foswiki::AccessControlException with {} catch Error::Simple with {
        $this->assert( 0, shift->stringify() );
    }
    otherwise {
        unless ( $Foswiki::cfg{LoginManager} eq 'none' ) {
            $this->assert( 0,
                    "expected an access control exception: "
                  . $Foswiki::cfg{LoginManager}
                  . "\n$text" );
        }
    };

    $query = Unit::Request->new();
    $query->path_info("/$this->{test_web}/$this->{test_topic}");

    $this->annotate("new session using $userLogin\n");

    $this->createNewFoswikiSession( $userLogin, $query );

#clear the lease - one of the previous tests may have different usermapper & thus different user
    Foswiki::Func::setTopicEditLock( $this->{test_web}, $this->{test_topic},
        0 );

    return;
}

sub verify_sudo_login {
    my $this = shift;

    unless ( $this->{session}->getLoginManager()->can("login") ) {
        return;
    }
    my $secret = "a big mole on my left buttock";
    my $crypted = crypt( $secret, "12" );
    $Foswiki::cfg{Password} = $crypted;

    my $query = Unit::Request->new(
        {
            username => [ $Foswiki::cfg{AdminUserLogin} ],
            password => [$secret],
            Logon    => [1],
            skin     => ['none'],
        }
    );
    $query->path_info("/$this->{test_web}/$this->{test_topic}");

    $this->createNewFoswikiSession( undef, $query );
    $this->{session}->getLoginManager()->login( $query, $this->{session} );
    my $script = $Foswiki::cfg{LoginManager} =~ /Apache/ ? 'viewauth' : 'view';
    my $surly =
      $this->{session}
      ->getScriptUrl( 0, $script, $this->{test_web}, $this->{test_topic} );
    $this->assert_matches( qr/^302/, $this->{session}->{response}->status() );
    $this->assert_matches( qr/^$surly/,
        $this->{session}->{response}->headers()->{Location} );

    return;
}

1;
