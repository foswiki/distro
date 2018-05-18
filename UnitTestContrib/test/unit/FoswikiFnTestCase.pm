# See bottom of file for license and copyright

package FoswikiFnTestCase;

=begin TML

---+ package FoswikiFnTestCase

This base class layers some extra stuff on FoswikiTestCase to
try and make life for Foswiki testers even easier at higher levels.
Normally this will be the base class for tests that require an almost
complete user environment. However it does quite a lot of relatively
slow setup, so should not be used for simpler tests (such as those
targeting single classes).

   1. Do not be afraid to modify Foswiki::cfg. You cannot break other
      tests that way.
   2. Never, ever write to any webs except the test_web and
      users_web, or any other test webs you create and remove
      (following the pattern shown below)
   3. The password manager is set to HtPasswdUser, and you can create
      users as shown in the creation of {test_user}
   4. A single user has been pre-registered, wikinamed 'ScumBag'

=cut

use Foswiki();

#use Unit::Response();
use Foswiki::UI::Register();
use Try::Tiny;
use Carp qw(cluck);

use Foswiki::Class -types;
extends qw(FoswikiTestCase);

has test_user_forename => ( is => 'rw', );
has test_user_surname  => ( is => 'rw', );
has test_user_wikiname => ( is => 'rw', );
has test_user_login    => ( is => 'rw', );
has test_user_email    => ( is => 'rw', );
has test_user_cuid     => ( is => 'rw', );
has response           => (
    is        => 'rw',
    clearer   => 1,
    lazy      => 1,
    predicate => 1,
    isa       => InstanceOf ['Foswiki::Response'],
    default   => sub { return $_[0]->app->response; },
);

=begin TML

---++ ObjectMethod loadExtraConfig()
This method can be overridden (overrides should call up to the base class)
to add extra stuff to Foswiki::cfg.

=cut

around loadExtraConfig => sub {
    my $orig = shift;
    my $this = shift;

    $orig->( $this, @_ );

    my $cfgData = $this->app->cfg->data;

    #$cfgData->{Store}{Implementation}   = "Foswiki::Store::RcsLite";
    $cfgData->{Store}{Implementation}   = "Foswiki::Store::PlainFile";
    $cfgData->{RCS}{AutoAttachPubFiles} = 0;

    $this->setupUserRegistration;
};

around set_up => sub {
    my $orig = shift;
    my $this = shift;

    $orig->( $this, @_ );

    $this->createNewFoswikiApp(
        requestParams => { initializer => "" },
        engineParams  => {
            initialAttributes =>
              { path_info => "/" . $this->test_web . "/" . $this->test_topic },
        },
    );

    my $webObject = $this->populateNewWeb( $this->test_web );
    undef $webObject;
    $this->clear_test_topicObject;
    $this->test_topicObject(
        Foswiki::Func::readTopic( $this->test_web, $this->test_topic ) );
    $this->test_topicObject->text("BLEEGLE\n");
    $this->test_topicObject->save( forcedate => ( time() + 60 ) );

    $webObject = $this->populateNewWeb( $this->users_web );
    undef $webObject;

    $this->test_user_forename('Scum');
    $this->test_user_surname('Bag');
    $this->test_user_wikiname(
        $this->test_user_forename . $this->test_user_surname );
    $this->test_user_login('scum');
    $this->test_user_email('scumbag@example.com');
    $this->registerUser(
        $this->test_user_login,   $this->test_user_forename,
        $this->test_user_surname, $this->test_user_email
    );
    $this->test_user_cuid(
        $this->app->users->getCanonicalUserID( $this->test_user_login ) );
};

around tear_down => sub {
    my $orig = shift;
    my $this = shift;

    my $app = $this->app;
    my $cfg = $app->cfg;

    $this->removeWebFixture( $this->test_web );
    $this->assert_str_not_equals( $cfg->data->{UsersWebName},
        'Main', "UsersWebName equals to 'Main'" );
    $this->removeWebFixture( $cfg->data->{UsersWebName} );
    unlink( $Foswiki::cfg{Htpasswd}{FileName} );

    $orig->( $this, @_ );
};

=begin TML

---++ ObjectMethod removeWeb($web)

Remove a temporary web fixture (data and pub)

=cut

sub removeWeb {
    my ( $this, $web ) = @_;
    $this->removeWebFixture($web);
}

1;
