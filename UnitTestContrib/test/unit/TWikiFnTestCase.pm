use strict;

# Base class for tests for TWikiFns
# This base class layers some extra protections on TWikiTestCase to try and make life
# for TWikiFn testers even easier.
# 1. Do not be afraid to modify TWiki::cfg. You cannot break other tests that way.
# 2. Never, ever write to any webs except the {test_web} and {users_web}, or any other
#    test webs you create and remove (following the pattern shown below)
# 3. The password manager is set to HtPasswdUser, and you can create users as shown
#    below in the creation of {test_user}
# 4. A single user has been pre-registered, wikinamed 'ScumBag'

package TWikiFnTestCase;
use base 'TWikiTestCase';

use TWiki;
use Unit::Request;
use Unit::Response;
use TWiki::UI::Register;
use Error qw( :try );

use vars qw( @mails );

sub new {
    my $class = shift;
    my $var = shift;
    my $this = $class->SUPER::new(@_);

    $this->{var} = $var;
    $this->{test_web} = 'Temporary'.$var.'TestWeb'.$var;
    $this->{test_topic} = 'TestTopic'.$var;
    $this->{users_web} = 'Temporary'.$var.'UsersWeb';
    $this->{twiki} = undef;
    return $this;
}

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();

    $TWiki::cfg{StoreImpl} = "RcsLite";
    $TWiki::cfg{AutoAttachPubFiles} = 0;
    $TWiki::cfg{Register}{AllowLoginName} = 1;
    $TWiki::cfg{Htpasswd}{FileName} = "$TWiki::cfg{WorkingDir}/htpasswd";
    $TWiki::cfg{PasswordManager} = 'TWiki::Users::HtPasswdUser';
    $TWiki::cfg{UserMappingManager} = 'TWiki::Users::TopicUserMapping';
    $TWiki::cfg{LoginManager} = 'TWiki::LoginManager::TemplateLogin';
    $TWiki::cfg{Register}{EnableNewUserRegistration} = 1;
    $TWiki::cfg{RenderLoggedInButUnknownUsers} = 0;

    $TWiki::cfg{Register}{NeedVerification} = 0;
    $TWiki::cfg{MinPasswordLength} = 0;
    $TWiki::cfg{UsersWebName} = $this->{users_web};
    my $query = new Unit::Request("");
    $query->path_info("/$this->{test_web}/$this->{test_topic}");

    $this->{twiki}    = new TWiki( undef, $query );
    $this->{request}  = $query;
    $this->{response} = new Unit::Response();
    $TWiki::Plugins::SESSION = $this->{twiki};
    @mails = ();
    $this->{twiki}->net->setMailHandler(\&TWikiFnTestCase::sentMail);
    $this->{twiki}->{store}->createWeb( $this->{twiki}->{user}, $this->{test_web} );
    $this->{twiki}->{store}->createWeb( $this->{twiki}->{user}, $this->{users_web} );
    $this->{test_user_forename} = 'Scum';
    $this->{test_user_surname} = 'Bag';
    $this->{test_user_wikiname} = $this->{test_user_forename}.$this->{test_user_surname};
    $this->{test_user_login} = 'scum';
    $this->{test_user_email} = 'scumbag@example.com';
    $this->registerUser($this->{test_user_login},
                        $this->{test_user_forename},
                        $this->{test_user_surname},
                        $this->{test_user_email});
    $this->{test_user_cuid} =
      $this->{twiki}->{users}->getCanonicalUserID($this->{test_user_login});
    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $this->{test_web},
        $this->{test_topic}, "BLEEGLE\n");
}

sub tear_down {
    my $this = shift;

    $this->removeWebFixture( $this->{twiki}, $this->{test_web} );
    $this->removeWebFixture( $this->{twiki}, $TWiki::cfg{UsersWebName} );
    unlink($TWiki::cfg{Htpasswd}{FileName});
    $this->SUPER::tear_down();

}

# callback used by Net.pm
sub sentMail {
    my($net, $mess ) = @_;
    push( @mails, $mess );
    return undef;
}

# Used by subclasses to register test users
sub registerUser {
    my ($this, $loginname, $forename, $surname, $email) = @_;

    my $query = new Unit::Request ({
                          'TopicName' => [ 'UserRegistration'  ],
                          'Twk1Email' => [ $email ],
                          'Twk1WikiName' => [ "$forename$surname" ],
                          'Twk1Name' => [ "$forename $surname" ],
                          'Twk0Comment' => [ '' ],
                          'Twk1LoginName' => [ $loginname ],
                          'Twk1FirstName' => [ $forename ],
                          'Twk1LastName' => [ $surname ],
                          'action' => [ 'register' ]
                         });

    $query->path_info( "/$this->{users_web}/UserRegistration" );

    my $twiki = new TWiki(undef, $query);
    $twiki->net->setMailHandler(\&TWikiFnTestCase::sentMail);
    try {
        TWiki::UI::Register::register_cgi($twiki);
    } catch TWiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals("attention", $e->{template},$e->stringify());
        $this->assert_str_equals(
            "thanks", $e->{def}, $e->stringify());
    } catch TWiki::AccessControlException with {
        my $e = shift;
        $this->assert(0, $e->stringify);
    } catch Error::Simple with {
        $this->assert(0, shift->stringify());
    } otherwise {
        $this->assert(0, "expected an oops redirect");
    };
    $twiki->finish();
    # Reload caches
    my $q = $this->{request};
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki(undef, $q);
    $this->{twiki}->net->setMailHandler(\&TWikiFnTestCase::sentMail);
}

1;
