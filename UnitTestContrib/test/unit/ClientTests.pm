use strict;

package ClientTests;

# This is woefully incomplete, but it does at least check that
# LoginManager.pm compiles okay.

use base qw(FoswikiFnTestCase);

use Unit::Request;
use Error qw( :try );

use Foswiki;
use Foswiki::LoginManager;
use Foswiki::UI::View;
use Foswiki::UI::Edit;

my $agent = $Foswiki::cfg{Register}{RegistrationAgentWikiName};
my $userLogin;
my $userWikiName;
my $user_id;

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();
    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $this->{test_web},
        $this->{test_topic}, <<CONSTRAINT);
   * Set ALLOWTOPICCHANGE = AdminGroup
CONSTRAINT
}

sub TemplateLoginManager {
    $Foswiki::cfg{LoginManager} = 'Foswiki::LoginManager::TemplateLogin';
}

sub ApacheLoginManager {
    $Foswiki::cfg{LoginManager} = 'Foswiki::LoginManager::ApacheLogin';
}

sub NoLoginManager {
    $Foswiki::cfg{LoginManager} = 'none';
}

sub BaseUserMapping {
    my $this = shift;
    $Foswiki::cfg{UserMappingManager} = 'Foswiki::Users::BaseUserMapping';
    $this->set_up_for_verify();
}

sub TopicUserMapping {
    my $this = shift;
    $Foswiki::cfg{UserMappingManager} = 'Foswiki::Users::TopicUserMapping';
    $this->set_up_for_verify();
}

# See the pod doc in Unit::TestCase for details of how to use this
sub fixture_groups {
    return (
        [ 'TemplateLoginManager', 'ApacheLoginManager', 'NoLoginManager' ],
        [ 'TopicUserMapping', 'BaseUserMapping' ] );
}

sub set_up_for_verify {
    #print STDERR "\n------------- set_up -----------------\n";
    my $this = shift;

    $this->{twiki}->finish() if $this->{twiki};
    $this->{twiki} = new Foswiki(undef, new Unit::Request());
    $this->assert($Foswiki::cfg{TempfileDir} && -d $Foswiki::cfg{TempfileDir});
    $Foswiki::cfg{UseClientSessions} = 1;
    $Foswiki::cfg{PasswordManager} = "Foswiki::Users::HtPasswdUser";
    $Foswiki::cfg{Htpasswd}{FileName} = "$Foswiki::cfg{TempfileDir}/htpasswd";
    $Foswiki::cfg{AuthScripts} = "edit";
    $Foswiki::cfg{Register}{EnableNewUserRegistration} = 1;
    $Foswiki::cfg{UsersWebName} = $this->{users_web};
}

sub set_up_user {
    my $this = shift;
    if ($this->{twiki}->{users}->supportsRegistration()) {
        $userLogin = 'joe';
        $userWikiName = 'JoeDoe';
	    $user_id = $this->{twiki}->{users}->addUser( $userLogin, $userWikiName, 'secrect_password', 'email@home.org.au');
	    $this->annotate("create $userLogin user - cUID = $user_id\n");
    } else {
        $userLogin = $Foswiki::cfg{AdminUserLogin};
        $user_id = $this->{twiki}->{users}->getCanonicalUserID($userLogin);
        $userWikiName = $this->{twiki}->{users}->getWikiName($user_id);
	    $this->annotate("no registration support (using admin)\n");
    }
#print STDERR "\n------------- set_up_user (login: $userLogin) (cUID:$user_id) -----------------\n";
}

sub capture {
    my $this = shift;
    my( $proc, $twiki ) = @_;
    $twiki->{users}->{loginManager}->checkAccess();
    $this->SUPER::capture( @_ );
}

sub verify_edit {
#print STDERR "\n------------- verify_edit -----------------\n";

    my $this = shift;
    my ( $query, $text );

    #close this Foswiki session - its using the wrong mapper and login
    $this->{twiki}->finish();

    $query = new Unit::Request();
    $query->path_info( "/$this->{test_web}/$this->{test_topic}" );
    $this->{twiki} = new Foswiki( undef, $query );

    $this->set_up_user();
    try {
        $text = $this->capture( \&Foswiki::UI::View::view, $this->{twiki} );
    } catch Foswiki::OopsException with {
        $this->assert(0,shift->stringify());
    } catch Error::Simple with {
        $this->assert(0,shift->stringify());
    };

    $query = new Unit::Request();
    $query->path_info( "/$this->{test_web}/$this->{test_topic}?breaklock=1" );
    $this->{twiki}->finish();

    $this->{twiki} = new Foswiki( undef, $query );

    try {
        $text = $this->capture( \&Foswiki::UI::Edit::edit, $this->{twiki} );
    } catch Foswiki::AccessControlException with {
    } catch Error::Simple with {
        $this->assert(0,shift->stringify());
    } otherwise {
        unless( $Foswiki::cfg{LoginManager} eq 'none' ) {
            $this->assert(0, "expected an access control exception: ".
                            $Foswiki::cfg{LoginManager}."\n$text");
        }
    };

    $query = new Unit::Request();
    $query->path_info( "/$this->{test_web}/$this->{test_topic}" );
    $this->{twiki}->finish();

    $this->annotate("new session using $userLogin\n");

    $this->{twiki} = new Foswiki( $userLogin, $query );

    #clear the lease - one of the previous tests may have different usermapper & thus different user
    Foswiki::Func::setTopicEditLock($this->{test_web}, $this->{test_topic}, 0);
}

sub verify_sudo_login {
    my $this = shift;

    unless ($this->{twiki}->{users}->{loginManager}->can("login")) {
        return;
    }
    $this->{twiki}->finish();
    my $secret = "a big mole on my left buttock";
    my $crypted = crypt($secret, "12");
    $Foswiki::cfg{Password} = $crypted;

    my $query = new Unit::Request({
        username => [ $Foswiki::cfg{AdminUserLogin} ],
        password => [ $secret ],
        Logon => [ 1 ],
        skin => [ 'none' ],
    });
    $query->path_info( "/$this->{test_web}/$this->{test_topic}" );

    $this->{twiki} = new Foswiki(undef, $query);
    my ($text, $result) = $this->capture(
        sub {
            my $session = shift;
            $session->{users}->{loginManager}->login(
                $query, $session);
        }, $this->{twiki});
    $this->assert($text =~ /Status: 302/, $text);
}

1;
