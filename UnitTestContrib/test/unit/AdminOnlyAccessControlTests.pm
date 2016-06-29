package AdminOnlyAccessControlTests;

#Sven wishes he could use ISA AccessControlTest, but the unit test system doesn't do inherited test subs

use Foswiki          ();
use Foswiki::Plugins ();
use Foswiki::Configure::Dependency();
use Assert;

# For Anchor test
use Foswiki::UI ();

use Moo;
use namespace::clean;
extends qw(FoswikiFnTestCase);

my $post11 = 0;

sub BUILD {
    my $this = shift;

    my $dep = new Foswiki::Configure::Dependency(
        type    => "perl",
        module  => "Foswiki",
        version => ">=1.2"
    );
    my ( $ok, $message ) = $dep->checkDependency();
    $post11 = $ok;
}

=todo
sub loadExtraConfig {
    my ( $this, $context, @args ) = @_;

    # $this - the Test::Unit::TestCase object

    $this->SUPER::loadExtraConfig( $context, @args );

#can't change to AdminOnlyAccessControl here, as we need to be able to create topics.
#$Foswiki::cfg{AccessControl} = 'Foswiki::Access::AdminOnlyAccess'

    return;
}
=cut

my $MrWhite;
my $MrBlue;
my $MrOrange;
my $MrGreen;
my $MrYellow;

sub skip {
    my ( $this, $test ) = @_;

    return $this->check_dependency('Foswiki,<,1.2')
      ? 'Foswiki 1.1 has no Foswiki::Access'
      : undef;
}

around set_up => sub {
    my $orig = shift;
    my $this = shift;

    $orig->( $this, @_ );

    ASSERT( $this->has_app, "No predefined app" );
    my $app           = $this->app;
    my $users         = $app->users;
    my ($topicObject) = Foswiki::Func::readTopic( $Foswiki::cfg{UsersWebName},
        $Foswiki::cfg{DefaultUserWikiName} );
    $topicObject->text('');
    $topicObject->save();
    undef $topicObject;
    $this->registerUser( 'white', 'Mr', "White", 'white@example.com' );
    $MrWhite = $users->getCanonicalUserID('white');
    $this->registerUser( 'blue', 'Mr', "Blue", 'blue@example.com' );
    $MrBlue = $users->getCanonicalUserID('blue');
    $this->registerUser( 'orange', 'Mr', "Orange", 'orange@example.com' );
    $MrOrange = $users->getCanonicalUserID('orange');
    $this->registerUser( 'green', 'Mr', "Green", 'green@example.com' );
    $MrGreen = $users->getCanonicalUserID('green');
    $this->registerUser( 'yellow', 'Mr', "Yellow", 'yellow@example.com' );
    $MrYellow = $users->getCanonicalUserID('yellow');

    $this->createNewFoswikiApp;
    my $users_web = $this->users_web;
    ($topicObject) =
      Foswiki::Func::readTopic( $users_web, "ReservoirDogsGroup" );
    $topicObject->text(<<"THIS");
   * Set GROUP = MrWhite, $users_web.MrBlue
THIS
    $topicObject->save();
    undef $topicObject;

    $this->app->cfg->data->{DisableAllPlugins} = 1;

    return;
};

sub DENIED {
    my ( $this, $mode, $user, $web, $topic ) = @_;
    $web   ||= $this->test_web;
    $topic ||= $this->test_topic;
    my ($topicObject) = Foswiki::Func::readTopic( $web, $topic );
    $this->assert( !$topicObject->haveAccess( $mode, $user ),
        "$user $mode $web.$topic" );

    if ($post11) {
        $this->assert(
            !$this->app->access->haveAccess( $mode, $user, $topicObject ),
            "$user $mode $web.$topic" );
        $this->assert(
            !$this->app->access->haveAccess(
                $mode, $user, $topicObject->web, $topicObject->topic
            ),
            "$user $mode $web.$topic"
        );
    }

    return;
}

sub PERMITTED {
    my ( $this, $mode, $user, $web, $topic ) = @_;
    $web   ||= $this->test_web;
    $topic ||= $this->test_topic;
    my ($topicObject) = Foswiki::Func::readTopic( $web, $topic );
    $this->assert( $topicObject->haveAccess( $mode, $user ),
        "$user $mode $web.$topic" );

    if ($post11) {
        $this->assert(
            $this->app->access->haveAccess( $mode, $user, $topicObject ),
            "$user $mode $web.$topic" );
        $this->assert(
            $this->app->access->haveAccess(
                $mode, $user, $topicObject->web, $topicObject->topic
            ),
            "$user $mode $web.$topic"
        );
    }

    return;
}

# Note: As we do not initialize with a query, the topic that topic prefs
# are initialized from is WebHome. Thus these tests also test reading a topic
# other than the current topic.

# Test that explicitly defined users are denied topic view
sub test_denytopic {
    my $this = shift;
    my ($topicObject) =
      Foswiki::Func::readTopic( $this->test_web, $this->test_topic );
    my $users_web = $this->users_web;
    $topicObject->text(<<"THIS");
If DENYTOPIC is set to a list of wikinames
    * people in the list will be DENIED.
   * Set DENYTOPICVIEW = MrGreen
   * Set DENYTOPICVIEW = ,,MrYellow,,$users_web.MrOrange,%USERSWEB%.ReservoirDogsGroup,,,
THIS
    $topicObject->save();
    undef $topicObject;

    $Foswiki::cfg{AccessControl} = 'Foswiki::Access::AdminOnlyAccess';
    $this->createNewFoswikiApp;

    $this->DENIED( "VIEW", $MrGreen );
    $this->DENIED( "VIEW", $MrYellow );
    $this->DENIED( "VIEW", $MrOrange );
    $this->DENIED( "VIEW", $MrWhite );
    $this->DENIED( "VIEW", $MrBlue );
    $this->PERMITTED( "VIEW", 'BaseUserMapping_333' );

    return;
}

# Test that an empty DENYTOPIC doesn't deny anyone
sub test_empty_denytopic {
    my $this = shift;
    my ($topicObject) =
      Foswiki::Func::readTopic( $this->test_web, $this->test_topic );
    $topicObject->text(<<'THIS');
If DENYTOPIC is set to empty ( i.e. Set DENYTOPIC = )
    * access is PERMITTED _i.e _ no-one is denied access to this topic
   * Set DENYTOPICVIEW=
THIS
    $topicObject->save();
    undef $topicObject;

    $Foswiki::cfg{AccessControl} = 'Foswiki::Access::AdminOnlyAccess';
    $this->createNewFoswikiApp;
    $this->DENIED( "VIEW", $MrGreen );
    $this->DENIED( "VIEW", $MrYellow );
    $this->DENIED( "VIEW", $MrOrange );
    $this->DENIED( "VIEW", $MrWhite );
    $this->DENIED( "VIEW", $MrBlue );
    $this->PERMITTED( "VIEW", 'BaseUserMapping_333' );

    return;
}

# Test that an empty DENYTOPIC doesn't deny anyone
sub test_whitespace_denytopic {
    my $this = shift;
    my ($topicObject) =
      Foswiki::Func::readTopic( $this->test_web, $this->test_topic );
    $topicObject->text(<<'THIS');
If DENYTOPIC is set to empty ( i.e. Set DENYTOPIC = )
    * access is PERMITTED _i.e _ no-one is denied access to this topic
   * Set DENYTOPICVIEW =   
THIS
    $topicObject->save();
    undef $topicObject;

    $Foswiki::cfg{AccessControl} = 'Foswiki::Access::AdminOnlyAccess';
    $this->createNewFoswikiApp;
    $this->DENIED( "VIEW", $MrGreen );
    $this->DENIED( "VIEW", $MrYellow );
    $this->DENIED( "VIEW", $MrOrange );
    $this->DENIED( "VIEW", $MrWhite );
    $this->DENIED( "VIEW", $MrBlue );
    $this->PERMITTED( "VIEW", 'BaseUserMapping_333' );

    return;
}

# Test that an whitespace at the end of DENYTOPIC is ok
sub test_denytopic_whitespace {
    my $this = shift;
    my ($topicObject) =
      Foswiki::Func::readTopic( $this->test_web, $this->test_topic );
    $topicObject->text(<<'THIS');
If DENYTOPIC is set to empty ( i.e. Set DENYTOPIC = )
    * access is PERMITTED _i.e _ no-one is denied access to this topic
   * Set DENYTOPICVIEW = MrBlue  
THIS
    $topicObject->save();
    undef $topicObject;

    $Foswiki::cfg{AccessControl} = 'Foswiki::Access::AdminOnlyAccess';
    $this->createNewFoswikiApp;
    $this->DENIED( "VIEW", $MrGreen );
    $this->DENIED( "VIEW", $MrYellow );
    $this->DENIED( "VIEW", $MrOrange );
    $this->DENIED( "VIEW", $MrWhite );
    $this->DENIED( "VIEW", $MrBlue );
    $this->PERMITTED( "VIEW", 'BaseUserMapping_333' );

    return;
}

# Test that explicitly defined ALLOWTOPIC excludes everyone else
sub test_allowtopic {
    my $this = shift;
    my ($topicObject) =
      Foswiki::Func::readTopic( $this->test_web, $this->test_topic );
    $topicObject->text(<<'THIS');
If ALLOWTOPIC is set
   1. people in the list are PERMITTED
   2. everyone else is DENIED
   * Set ALLOWTOPICVIEW = %USERSWEB%.MrOrange
THIS
    $topicObject->save();
    undef $topicObject;

    $Foswiki::cfg{AccessControl} = 'Foswiki::Access::AdminOnlyAccess';
    $this->createNewFoswikiApp;
    $this->DENIED( "VIEW", $MrOrange );
    $this->DENIED( "VIEW", $MrGreen );
    $this->DENIED( "VIEW", $MrYellow );
    $this->DENIED( "VIEW", $MrWhite );
    $this->DENIED( "VIEW", $MrBlue );
    $this->PERMITTED( "VIEW", 'BaseUserMapping_333' );

    return;
}

# Test that explicitly defined ALLOWTOPIC excludes everyone else
# Renew the session after each check to force refresh of any caches
sub test_allowtopic_a {
    my $this = shift;
    my ($topicObject) =
      Foswiki::Func::readTopic( $this->test_web, $this->test_topic );
    $topicObject->text(<<'THIS');
If ALLOWTOPIC is set
   1. people in the list are PERMITTED
   2. everyone else is DENIED
   * Set ALLOWTOPICVIEW = %USERSWEB%.MrOrange
THIS
    $topicObject->save();
    undef $topicObject;

    my @appParams = (
        requestParams => { initializer => "", },
        engineParams =>
          { path_info => "/" . $this->test_web . "/" . $this->test_topic },
    );

    # renew Foswiki, so WebPreferences gets re-read
    $Foswiki::cfg{AccessControl} = 'Foswiki::Access::AdminOnlyAccess';
    $this->createNewFoswikiApp(@appParams);
    $this->DENIED( "VIEW", $MrOrange );
    $this->createNewFoswikiApp(@appParams);
    $this->DENIED( "VIEW", $MrGreen );
    $this->createNewFoswikiApp(@appParams);
    $this->DENIED( "VIEW", $MrYellow );
    $this->createNewFoswikiApp(@appParams);
    $this->DENIED( "VIEW", $MrWhite );
    $this->createNewFoswikiApp(@appParams);
    $this->DENIED( "VIEW", $MrBlue );
    $this->createNewFoswikiApp(@appParams);
    $this->PERMITTED( "VIEW", 'BaseUserMapping_333' );

    return;
}

# Test that explicitly defined ALLOWTOPIC excludes everyone else
# Renew the session after each check to force refresh of any caches,
# but don't provide a context,
sub test_allowtopic_b {
    my $this = shift;
    my ($topicObject) =
      Foswiki::Func::readTopic( $this->test_web, $this->test_topic );
    $topicObject->text(<<'THIS');
If ALLOWTOPIC is set
   1. people in the list are PERMITTED
   2. everyone else is DENIED
   * Set ALLOWTOPICVIEW = %USERSWEB%.MrOrange
THIS
    $topicObject->save();
    undef $topicObject;

    # renew Foswiki, so WebPreferences gets re-read
    $Foswiki::cfg{AccessControl} = 'Foswiki::Access::AdminOnlyAccess';
    $this->createNewFoswikiApp;
    $this->DENIED( "VIEW", $MrOrange );
    $this->createNewFoswikiApp;
    $this->DENIED( "VIEW", $MrGreen );
    $this->createNewFoswikiApp;
    $this->DENIED( "VIEW", $MrYellow );
    $this->createNewFoswikiApp;
    $this->DENIED( "VIEW", $MrWhite );
    $this->createNewFoswikiApp;
    $this->DENIED( "VIEW", $MrBlue );
    $this->createNewFoswikiApp;
    $this->PERMITTED( "VIEW", 'BaseUserMapping_333' );

    return;
}

# Test that explicitly defined ALLOWTOPIC excludes everyone else
# Access control in META:PREFERENCE
sub test_allowtopic_c {
    my $this = shift;
    my ($topicObject) =
      Foswiki::Func::readTopic( $this->test_web, $this->test_topic );
    $topicObject->text(<<'THIS');
If ALLOWTOPIC is set
   1. people in the list are PERMITTED
   2. everyone else is DENIED
THIS
    $topicObject->putKeyed(
        'PREFERENCE',
        {
            name  => "ALLOWTOPICVIEW",
            title => "ALLOWTOPICVIEW",
            type  => "Set",
            value => "%USERSWEB%.MrOrange MrYellow"
        }
    );
    $topicObject->save();
    undef $topicObject;

    # renew Foswiki, so WebPreferences gets re-read
    $Foswiki::cfg{AccessControl} = 'Foswiki::Access::AdminOnlyAccess';
    $this->createNewFoswikiApp;
    $this->DENIED( "VIEW", $MrOrange );
    $this->createNewFoswikiApp;
    $this->DENIED( "VIEW", $MrGreen );
    $this->createNewFoswikiApp;
    $this->DENIED( "VIEW", $MrYellow );
    $this->createNewFoswikiApp;
    $this->DENIED( "VIEW", $MrWhite );
    $this->createNewFoswikiApp;
    $this->DENIED( "VIEW", $MrBlue );
    $this->createNewFoswikiApp;
    $this->PERMITTED( "VIEW", 'BaseUserMapping_333' );

    return;
}

# Test that DENYWEB works in a top-level web with no finalisation
sub test_denyweb {
    my $this = shift;
    my ($topicObject) =
      Foswiki::Func::readTopic( $this->test_web,
        $Foswiki::cfg{WebPrefsTopicName} );
    my $users_web = $this->users_web;
    $topicObject->text(<<"THIS");
If DENYWEB is set to a list of wikiname
    * people in the list are DENIED access
   * Set DENYWEBVIEW = $users_web.MrOrange %USERSWEB%.MrBlue
THIS
    $topicObject->save();
    undef $topicObject;

    # renew Foswiki, so WebPreferences gets re-read
    $this->createNewFoswikiApp;
    ($topicObject) =
      Foswiki::Func::readTopic( $this->test_web, $this->test_topic );
    $topicObject->text("Null points");
    $topicObject->save();
    undef $topicObject;

    $Foswiki::cfg{AccessControl} = 'Foswiki::Access::AdminOnlyAccess';
    $this->createNewFoswikiApp;

    $this->DENIED( "VIEW", $MrOrange );
    $this->DENIED( "VIEW", $MrGreen );
    $this->DENIED( "VIEW", $MrYellow );
    $this->DENIED( "VIEW", $MrWhite );
    $this->DENIED( "VIEW", $MrBlue );
    $this->PERMITTED( "VIEW", 'BaseUserMapping_333' );

    return;
}

# Test that ALLOWWEB works in a top-level web with no finalisation
sub test_allow_web {
    my $this = shift;
    my ($topicObject) =
      Foswiki::Func::readTopic( $this->test_web,
        $Foswiki::cfg{WebPrefsTopicName} );
    $topicObject->text(
        <<'THIS'
If ALLOWWEB is set to a list of wikinames
    * people in the list will be PERMITTED
    * everyone else will be DENIED
   * Set ALLOWWEBVIEW = MrGreen MrYellow MrWhite
THIS
    );
    $topicObject->save();
    undef $topicObject;

    ($topicObject) =
      Foswiki::Func::readTopic( $this->test_web, $this->test_topic );
    $topicObject->text("Null points");
    $topicObject->save();
    undef $topicObject;

    # renew Foswiki, so WebPreferences gets re-read
    $Foswiki::cfg{AccessControl} = 'Foswiki::Access::AdminOnlyAccess';
    $this->createNewFoswikiApp;

    $this->DENIED( "VIEW", $MrOrange );
    $this->DENIED( "VIEW", $MrGreen );
    $this->DENIED( "VIEW", $MrYellow );
    $this->DENIED( "VIEW", $MrWhite );
    $this->DENIED( "VIEW", $MrBlue );
    $this->PERMITTED( "VIEW", 'BaseUserMapping_333' );

    return;
}

# Test that Web.UserName is equivalent to UserName in ACLs
sub test_webDotUserName {
    my $this = shift;
    my ($topicObject) =
      Foswiki::Func::readTopic( $this->test_web, $this->test_topic );
    $topicObject->text(
        <<'THIS'
If ALLOWTOPIC is set
   1. people in the list are PERMITTED
   2. everyone else is DENIED
   * Set ALLOWTOPICVIEW = MrYellow,%USERSWEB%.MrOrange,Nosuchweb.MrGreen,%MAINWEB%.MrBlue,%SYSTEMWEB%.MrWhite
THIS
    );
    $topicObject->save();
    undef $topicObject;

    # renew Foswiki, so WebPreferences gets re-read
    $Foswiki::cfg{AccessControl} = 'Foswiki::Access::AdminOnlyAccess';
    $this->createNewFoswikiApp;

    $this->DENIED( "VIEW", $MrOrange );
    $this->DENIED( "VIEW", $MrGreen );
    $this->DENIED( "VIEW", $MrYellow );
    $this->DENIED( "VIEW", $MrWhite );
    $this->DENIED( "VIEW", $MrBlue );
    $this->PERMITTED( "VIEW", 'BaseUserMapping_333' );

    return;
}

sub _checkSettings {
    my ( $this, $meta ) = @_;

    $this->assert( !$meta->haveAccess( 'VIEW', $MrOrange ),
        " 'VIEW' " . $this->test_web . "." . $this->test_topic );
    $this->assert( !$meta->haveAccess( 'VIEW', $MrGreen ),
        " 'VIEW' " . $this->test_web . "." . $this->test_topic );
    $this->assert( !$meta->haveAccess( 'VIEW', $MrYellow ),
        " 'VIEW' " . $this->test_web . "." . $this->test_topic );
    $this->assert( !$meta->haveAccess( 'VIEW', $MrWhite ),
        " 'VIEW' " . $this->test_web . "." . $this->test_topic );
    $this->assert( !$meta->haveAccess( 'VIEW', $MrBlue ),
        " 'VIEW' " . $this->test_web . "." . $this->test_topic );
    $this->assert(
        $meta->haveAccess( 'VIEW', 'BaseUserMapping_333' ),
        " 'VIEW' " . $this->test_web . "." . $this->test_topic
    );

    return;
}

# Test a * Set embedded in text
sub test_SetInText {
    my $this = shift;

    my $text = <<'THIS';
   * Set ALLOWTOPICVIEW = %USERSWEB%.MrGreen
THIS
    my ($topicObject) =
      Foswiki::Func::readTopic( $this->test_web, $this->test_topic );
    $topicObject->text($text);
    $topicObject->save();
    undef $topicObject;

    # renew Foswiki, so WebPreferences gets re-read
    $Foswiki::cfg{AccessControl} = 'Foswiki::Access::AdminOnlyAccess';
    $this->createNewFoswikiApp;

    ($topicObject) =
      Foswiki::Func::readTopic( $this->test_web, $this->test_topic );
    $this->_checkSettings($topicObject);

    return;
}

# Test a set in meta-data
sub test_setInMETA {
    my $this = shift;

    my ($topicObject) =
      Foswiki::Func::readTopic( $this->test_web, $this->test_topic );
    $topicObject->text('Empty');
    my $args = {
        name  => 'ALLOWTOPICVIEW',
        title => 'ALLOWTOPICVIEW',
        value => "%USERSWEB%.MrGreen",
        type  => "Set"
    };
    $topicObject->putKeyed( 'PREFERENCE', $args );
    $topicObject->save();
    undef $topicObject;

    # renew Foswiki, so WebPreferences gets re-read
    $Foswiki::cfg{AccessControl} = 'Foswiki::Access::AdminOnlyAccess';
    $this->createNewFoswikiApp;

    ($topicObject) =
      Foswiki::Func::readTopic( $this->test_web, $this->test_topic );

    $this->_checkSettings($topicObject);

    return;
}

# Check that a PREFERENCE takes precedence over a setting in text
sub test_setInSetAndMETA {
    my $this = shift;

    my $text = <<'THIS';
   * Set ALLOWTOPICVIEW = %USERSWEB%.MrOrange
THIS
    my ($topicObject) =
      Foswiki::Func::readTopic( $this->test_web, $this->test_topic );
    $topicObject->text($text);
    my $args = {
        name  => 'ALLOWTOPICVIEW',
        title => 'ALLOWTOPICVIEW',
        value => "%USERSWEB%.MrGreen",
        type  => "Set"
    };
    $topicObject->putKeyed( 'PREFERENCE', $args );
    $topicObject->save();
    undef $topicObject;

    # renew Foswiki, so WebPreferences gets re-read
    $Foswiki::cfg{AccessControl} = 'Foswiki::Access::AdminOnlyAccess';
    $this->createNewFoswikiApp;

    ($topicObject) =
      Foswiki::Func::readTopic( $this->test_web, $this->test_topic );
    $this->_checkSettings($topicObject);

    return;
}

# Test that hierarchical subweb controls override the parent web
sub test_subweb_controls_override_parent {
    my $this   = shift;
    my $subweb = $this->test_web . ".SubWeb";

    $Foswiki::cfg{EnableHierarchicalWebs} = 1;

    # First build a parent web with view restricted to MrGreen
    my ($topicObject) =
      Foswiki::Func::readTopic( $this->test_web, $this->test_topic );
    $topicObject->text("Nowt");
    $topicObject->save();
    undef $topicObject;

    ($topicObject) =
      Foswiki::Func::readTopic( $this->test_web,
        $Foswiki::cfg{WebPrefsTopicName} );
    $topicObject->text(<<'THIS');
   * Set ALLOWWEBVIEW = MrGreen
THIS
    $topicObject->save();
    undef $topicObject;

    # Now build a subweb with view restricted to MrOrange
    my $webObject = $this->populateNewWeb($subweb);
    undef $webObject;
    ($topicObject) =
      Foswiki::Func::readTopic( $subweb, $Foswiki::cfg{WebPrefsTopicName} );
    $topicObject->text(<<'THIS');
   * Set ALLOWWEBVIEW = MrOrange
THIS
    $topicObject->save();
    undef $topicObject;
    $Foswiki::cfg{AccessControl} = 'Foswiki::Access::AdminOnlyAccess';
    $this->createNewFoswikiApp;
    $this->DENIED( "VIEW", $MrOrange, $subweb );
    $this->DENIED( "VIEW", $MrGreen,  $subweb );
    $this->DENIED( "VIEW", $MrGreen );
    $this->DENIED( "VIEW", $MrOrange );
    $this->PERMITTED( "VIEW", 'BaseUserMapping_333' );

    return;
}

# Test that controls are inherited from parent webs
sub test_subweb_inherits_from_parent {
    my $this   = shift;
    my $subweb = $this->test_web . ".SubWeb";

    $Foswiki::cfg{EnableHierarchicalWebs} = 1;

    # First build a parent web with view restricted to MrGreen, and
    # finalise the setting
    my ($topicObject) =
      Foswiki::Func::readTopic( $this->test_web,
        $Foswiki::cfg{WebPrefsTopicName} );
    $topicObject->text(<<'THIS');
   * Set ALLOWWEBVIEW = MrGreen
   * Set FINALPREFERENCES = ALLOWWEBVIEW
THIS
    $topicObject->save();
    undef $topicObject;

    # Now build a subweb with no restrictions
    my $webObject = $this->populateNewWeb($subweb);
    undef $webObject;
    ($topicObject) =
      Foswiki::Func::readTopic( $subweb, $Foswiki::cfg{WebPrefsTopicName} );
    $topicObject->text(<<'THIS');
THIS
    $topicObject->save();
    undef $topicObject;
    $Foswiki::cfg{AccessControl} = 'Foswiki::Access::AdminOnlyAccess';
    $this->createNewFoswikiApp;
    $this->DENIED( "VIEW", $MrGreen,  $subweb );
    $this->DENIED( "VIEW", $MrOrange, $subweb );
    $this->DENIED( "VIEW", $MrGreen );
    $this->DENIED( "VIEW", $MrOrange );
    $this->PERMITTED( "VIEW", 'BaseUserMapping_333' );

    return;
}

# Test that finalised controls in parent web override the subweb controls
sub test_finalised_parent_overrides_subweb {
    my $this   = shift;
    my $subweb = $this->test_web . ".SubWeb";

    $Foswiki::cfg{EnableHierarchicalWebs} = 1;

    # First build a parent web with view restricted to MrGreen, and
    # finalise the setting
    my ($topicObject) =
      Foswiki::Func::readTopic( $this->test_web,
        $Foswiki::cfg{WebPrefsTopicName} );
    $topicObject->text(<<'THIS');
   * Set ALLOWWEBVIEW = MrGreen
   * Set FINALPREFERENCES = ALLOWWEBVIEW
THIS
    $topicObject->save();
    undef $topicObject;

    # Now build a subweb with view restricted to MrOrange
    my $webObject = $this->populateNewWeb($subweb);
    undef $webObject;
    ($topicObject) =
      Foswiki::Func::readTopic( $subweb, $Foswiki::cfg{WebPrefsTopicName} );
    $topicObject->text(<<'THIS');
   * Set ALLOWWEBVIEW = MrOrange
THIS
    $topicObject->save();
    undef $topicObject;
    $Foswiki::cfg{AccessControl} = 'Foswiki::Access::AdminOnlyAccess';
    $this->createNewFoswikiApp;
    $this->DENIED( "VIEW", $MrOrange, $subweb );
    $this->DENIED( "VIEW", $MrGreen,  $subweb );
    $this->DENIED( "VIEW", $MrGreen );
    $this->DENIED( "VIEW", $MrOrange );
    $this->PERMITTED( "VIEW", 'BaseUserMapping_333' );

    return;
}

# As anchors are never sent by the browser, this is done through JS
# and only testable by Selenium
# Kept this test here as it is the only one I (Babar) know of doing the full
# Foswiki::UI chain, therefore catching the AccessControlExceptions
sub test_login_redirect_preserves_anchor {
    my $this       = shift;
    my $test_topic = 'TestAnchor';

    # Create a topic with an anchor, viewable only by MrYellow
    my ($topicObject) =
      Foswiki::Func::readTopic( $this->test_web, $test_topic );
    $topicObject->text( <<'THIS' );
If there is an anchor, and some access restrictions,
anchor is preserved after login.
#anchor
   * Set ALLOWTOPICVIEW = MrYellow
THIS
    $topicObject->save();
    undef $topicObject;
    my $viewUrl =
      $this->app->cfg->getScriptUrl( 0, 'view', $this->test_web, $test_topic );

    $this->createNewFoswikiApp(
        requestParams => {
            initializer => {
                webName   => [ $this->test_web ],
                topicName => ["$test_topic"],
            },

        },
        engineParams => {
            initialAttributes => {
                path_info => "/" . $this->test_web . "/$test_topic",
                method    => 'GET',
                action    => 'view',
                uri       => $viewUrl,
            },
        },
    );

    # Request the page with the full UI
    my ($text) = $this->capture(
        sub {
            return $this->app->handleRequest;
        }
    );

    # Get the login and view URLs to compare
    my $loginUrl =
      $this->app->cfg->getScriptUrl( 0, 'login', $this->test_web, $test_topic );
    my $fullViewUrl =
      $this->app->cfg->getScriptUrl( 1, 'view', $this->test_web, $test_topic );

    # Item11121: the test doesn't tolerate ShortURLs, for example.
    # ShortURLs may involve a {ScriptUrlPaths}{view} of '' or something
    # like '/foswiki' (where {ScriptUrlPath} looks like '/foswiki/bin').
    # In any case, the test is hard-wired to ignore {ScriptSuffix}
    $this->expect_failure( 'Test does\'t cater to ShortURL configurations',
        using => 'ShortURLs' );

    # Check we got a 401
    my ($status) = $text =~ m/^Status: (\d+)\r?$/m;
    $this->assert_not_null( $status, "Request did not return a Status header" );
    $this->assert_equals( 401, $status,
        "Request should have returned a 401, not a $status" );

    # Extract what we've been redirected to
    my ($formAction) =
      $text =~ m/<form action='(.*?)' name='loginform' method='post'/m;
    $this->assert_not_null( $formAction,
            "Request should have returned a 401 to $loginUrl\n"
          . "But it returned:\n$text" );
    $this->assert_equals( $loginUrl, $formAction );

    # Check the foswiki_origin contains the view URL to this topic
    my ($origin) = $text =~
      m/^<input type="hidden" name="foswiki_origin" value="([^"]+)" \/>\r?$/m;
    $this->assert_not_null( $origin,
        "No viewUrl (GET,view,$viewUrl) in foswiki_origin, got:\n$text" );
    $this->assert_equals( "GET,view,$viewUrl", $origin );

    # Get the redirected page after login

    return;
}

1;
