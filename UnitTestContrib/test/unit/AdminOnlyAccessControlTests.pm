package AdminOnlyAccessControlTests;
use strict;
use warnings;

#Sven wishes he could use ISA AccessControlTest, but the unit test system doesn't do inherited test subs

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use Foswiki          ();
use Foswiki::Address ();
use Foswiki::Meta    ();
use Foswiki::Plugins ();

# For Anchor test
use Foswiki::UI ();

sub new {
    my ( $class, @args ) = @_;
    my $self = $class->SUPER::new( 'AccessControl', @args );

    return $self;
}

sub loadExtraConfig {
    my ( $this, $context, @args ) = @_;

    # $this - the Test::Unit::TestCase object

    $this->SUPER::loadExtraConfig( $context, @args );

#can't change to AdminOnlyAccessControl here, as we need to be able to create topics.
#$Foswiki::cfg{AccessControl} = 'Foswiki::Access::AdminOnlyAccess'

    return;
}

my $MrWhite;
my $MrBlue;
my $MrOrange;
my $MrGreen;
my $MrYellow;

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();

    my $topicObject = Foswiki::Meta->new(
        $this->{session},
        $Foswiki::cfg{UsersWebName},
        $Foswiki::cfg{DefaultUserWikiName}, ''
    );
    $topicObject->save();
    $this->registerUser( 'white', 'Mr', "White", 'white@example.com' );
    $MrWhite = $this->{session}->{users}->getCanonicalUserID('white');
    $this->registerUser( 'blue', 'Mr', "Blue", 'blue@example.com' );
    $MrBlue = $this->{session}->{users}->getCanonicalUserID('blue');
    $this->registerUser( 'orange', 'Mr', "Orange", 'orange@example.com' );
    $MrOrange = $this->{session}->{users}->getCanonicalUserID('orange');
    $this->registerUser( 'green', 'Mr', "Green", 'green@example.com' );
    $MrGreen = $this->{session}->{users}->getCanonicalUserID('green');
    $this->registerUser( 'yellow', 'Mr', "Yellow", 'yellow@example.com' );
    $MrYellow = $this->{session}->{users}->getCanonicalUserID('yellow');

    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{users_web},
        "ReservoirDogsGroup", <<"THIS");
   * Set GROUP = MrWhite, $this->{users_web}.MrBlue
THIS
    $topicObject->save();

    return;
}

sub tear_down {
    my $this = shift;
    $this->SUPER::tear_down();

    return;
}

sub DENIED {
    my ( $this, $mode, $user, $web, $topic ) = @_;
    $web   ||= $this->{test_web};
    $topic ||= $this->{test_topic};
    my $topicObject = Foswiki::Meta->load( $this->{session}, $web, $topic );
    $this->assert( !$topicObject->haveAccess( $mode, $user ),
        "$user $mode $web.$topic" );

    return;
}

sub PERMITTED {
    my ( $this, $mode, $user, $web, $topic ) = @_;
    $web   ||= $this->{test_web};
    $topic ||= $this->{test_topic};
    my $topicObject = Foswiki::Meta->load( $this->{session}, $web, $topic );
    $this->assert( $topicObject->haveAccess( $mode, $user ),
        "$user $mode $web.$topic" );

    return;
}

# Note: As we do not initialize with a query, the topic that topic prefs
# are initialized from is WebHome. Thus these tests also test reading a topic
# other than the current topic.

# Test that explicitly defined users are denied topic view
sub test_denytopic {
    my $this = shift;
    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        $this->{test_topic}, <<"THIS");
If DENYTOPIC is set to a list of wikinames
    * people in the list will be DENIED.
   * Set DENYTOPICVIEW = MrGreen
   * Set DENYTOPICVIEW = ,,MrYellow,,$this->{users_web}.MrOrange,%USERSWEB%.ReservoirDogsGroup,,,
THIS
    $topicObject->save();

    $this->{session}->finish();
    $Foswiki::cfg{AccessControl} = 'Foswiki::Access::AdminOnlyAccess';
    $this->{session} = Foswiki->new();

    $this->DENIED( "VIEW", $MrGreen );
    $this->DENIED( "VIEW", $MrYellow );
    $this->DENIED( "VIEW", $MrOrange );
    $this->DENIED( "VIEW", $MrWhite );
    $this->DENIED( "view", $MrBlue );
    $this->PERMITTED( "VIEW", 'BaseUserMapping_333' );

    return;
}

# Test that an empty DENYTOPIC doesn't deny anyone
sub test_empty_denytopic {
    my $this = shift;
    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        $this->{test_topic}, <<'THIS');
If DENYTOPIC is set to empty ( i.e. Set DENYTOPIC = )
    * access is PERMITTED _i.e _ no-one is denied access to this topic
   * Set DENYTOPICVIEW=
THIS
    $topicObject->save();

    $this->{session}->finish();
    $Foswiki::cfg{AccessControl} = 'Foswiki::Access::AdminOnlyAccess';
    $this->{session} = Foswiki->new();
    $this->DENIED( "VIEW", $MrGreen );
    $this->DENIED( "VIEW", $MrYellow );
    $this->DENIED( "VIEW", $MrOrange );
    $this->DENIED( "VIEW", $MrWhite );
    $this->DENIED( "view", $MrBlue );
    $this->PERMITTED( "VIEW", 'BaseUserMapping_333' );

    return;
}

# Test that an empty DENYTOPIC doesn't deny anyone
sub test_whitespace_denytopic {
    my $this = shift;
    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        $this->{test_topic}, <<'THIS');
If DENYTOPIC is set to empty ( i.e. Set DENYTOPIC = )
    * access is PERMITTED _i.e _ no-one is denied access to this topic
   * Set DENYTOPICVIEW =   
THIS
    $topicObject->save();

    $this->{session}->finish();
    $Foswiki::cfg{AccessControl} = 'Foswiki::Access::AdminOnlyAccess';
    $this->{session} = Foswiki->new();
    $this->DENIED( "VIEW", $MrGreen );
    $this->DENIED( "VIEW", $MrYellow );
    $this->DENIED( "VIEW", $MrOrange );
    $this->DENIED( "VIEW", $MrWhite );
    $this->DENIED( "view", $MrBlue );
    $this->PERMITTED( "VIEW", 'BaseUserMapping_333' );

    return;
}

# Test that an whitespace at the end of DENYTOPIC is ok
sub test_denytopic_whitespace {
    my $this = shift;
    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        $this->{test_topic}, <<'THIS');
If DENYTOPIC is set to empty ( i.e. Set DENYTOPIC = )
    * access is PERMITTED _i.e _ no-one is denied access to this topic
   * Set DENYTOPICVIEW = MrBlue  
THIS
    $topicObject->save();

    $this->{session}->finish();
    $Foswiki::cfg{AccessControl} = 'Foswiki::Access::AdminOnlyAccess';
    $this->{session} = Foswiki->new();
    $this->DENIED( "VIEW", $MrGreen );
    $this->DENIED( "VIEW", $MrYellow );
    $this->DENIED( "VIEW", $MrOrange );
    $this->DENIED( "VIEW", $MrWhite );
    $this->DENIED( "view", $MrBlue );
    $this->PERMITTED( "VIEW", 'BaseUserMapping_333' );

    return;
}

# Test that explicitly defined ALLOWTOPIC excludes everyone else
sub test_allowtopic {
    my $this = shift;
    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        $this->{test_topic}, <<'THIS');
If ALLOWTOPIC is set
   1. people in the list are PERMITTED
   2. everyone else is DENIED
   * Set ALLOWTOPICVIEW = %USERSWEB%.MrOrange
THIS
    $topicObject->save();

    $this->{session}->finish();
    $Foswiki::cfg{AccessControl} = 'Foswiki::Access::AdminOnlyAccess';
    $this->{session} = Foswiki->new();
    $this->DENIED( "VIEW", $MrOrange );
    $this->DENIED( "VIEW", $MrGreen );
    $this->DENIED( "VIEW", $MrYellow );
    $this->DENIED( "VIEW", $MrWhite );
    $this->DENIED( "view", $MrBlue );
    $this->PERMITTED( "VIEW", 'BaseUserMapping_333' );

    return;
}

# Test that explicitly defined ALLOWTOPIC excludes everyone else
# Renew the session after each check to force refresh of any caches
sub test_allowtopic_a {
    my $this = shift;
    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        $this->{test_topic}, <<'THIS');
If ALLOWTOPIC is set
   1. people in the list are PERMITTED
   2. everyone else is DENIED
   * Set ALLOWTOPICVIEW = %USERSWEB%.MrOrange
THIS
    $topicObject->save();

    my $topicquery = Unit::Request->new("");
    $topicquery->path_info("/$this->{test_web}/$this->{test_topic}");

    # reFoswiki->new, so WebPreferences gets re-read
    $this->{session}->finish();
    $Foswiki::cfg{AccessControl} = 'Foswiki::Access::AdminOnlyAccess';
    $this->{session} = Foswiki->new( undef, $topicquery );
    $this->DENIED( "VIEW", $MrOrange );
    $this->{session}->finish();
    $this->{session} = Foswiki->new( undef, $topicquery );
    $this->DENIED( "VIEW", $MrGreen );
    $this->{session}->finish();
    $this->{session} = Foswiki->new( undef, $topicquery );
    $this->DENIED( "VIEW", $MrYellow );
    $this->{session}->finish();
    $this->{session} = Foswiki->new( undef, $topicquery );
    $this->DENIED( "VIEW", $MrWhite );
    $this->{session}->finish();
    $this->{session} = Foswiki->new( undef, $topicquery );
    $this->DENIED( "view", $MrBlue );
    $this->{session}->finish();
    $this->{session} = Foswiki->new();
    $this->PERMITTED( "VIEW", 'BaseUserMapping_333' );

    return;
}

# Test that explicitly defined ALLOWTOPIC excludes everyone else
# Renew the session after each check to force refresh of any caches,
# but don't provide a context,
sub test_allowtopic_b {
    my $this = shift;
    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        $this->{test_topic}, <<'THIS');
If ALLOWTOPIC is set
   1. people in the list are PERMITTED
   2. everyone else is DENIED
   * Set ALLOWTOPICVIEW = %USERSWEB%.MrOrange
THIS
    $topicObject->save();

    # reFoswiki->new, so WebPreferences gets re-read
    $this->{session}->finish();
    $Foswiki::cfg{AccessControl} = 'Foswiki::Access::AdminOnlyAccess';
    $this->{session} = Foswiki->new();
    $this->DENIED( "VIEW", $MrOrange );
    $this->{session}->finish();
    $this->{session} = Foswiki->new();
    $this->DENIED( "VIEW", $MrGreen );
    $this->{session}->finish();
    $this->{session} = Foswiki->new();
    $this->DENIED( "VIEW", $MrYellow );
    $this->{session}->finish();
    $this->{session} = Foswiki->new();
    $this->DENIED( "VIEW", $MrWhite );
    $this->{session}->finish();
    $this->{session} = Foswiki->new();
    $this->DENIED( "view", $MrBlue );
    $this->{session}->finish();
    $this->{session} = Foswiki->new();
    $this->PERMITTED( "VIEW", 'BaseUserMapping_333' );

    return;
}

# Test that explicitly defined ALLOWTOPIC excludes everyone else
# Access control in META:PREFERENCE
sub test_allowtopic_c {
    my $this = shift;
    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        $this->{test_topic}, <<'THIS');
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

    # reFoswiki->new, so WebPreferences gets re-read
    $this->{session}->finish();
    $Foswiki::cfg{AccessControl} = 'Foswiki::Access::AdminOnlyAccess';
    $this->{session} = Foswiki->new();
    $this->DENIED( "VIEW", $MrOrange );
    $this->{session}->finish();
    $this->{session} = Foswiki->new();
    $this->DENIED( "VIEW", $MrGreen );
    $this->{session}->finish();
    $this->{session} = Foswiki->new();
    $this->DENIED( "VIEW", $MrYellow );
    $this->{session}->finish();
    $this->{session} = Foswiki->new();
    $this->DENIED( "VIEW", $MrWhite );
    $this->{session}->finish();
    $this->{session} = Foswiki->new();
    $this->DENIED( "view", $MrBlue );
    $this->{session}->finish();
    $this->{session} = Foswiki->new();
    $this->PERMITTED( "VIEW", 'BaseUserMapping_333' );

    return;
}

# Test that DENYWEB works in a top-level web with no finalisation
sub test_denyweb {
    my $this = shift;
    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        $Foswiki::cfg{WebPrefsTopicName}, <<'THIS');
If DENYWEB is set to a list of wikiname
    * people in the list are DENIED access
   * Set DENYWEBVIEW = $this->{users_web}.MrOrange %USERSWEB%.MrBlue
THIS
    $topicObject->save();

    # reFoswiki->new, so WebPreferences gets re-read
    $topicObject = Foswiki::Meta->new(
        $this->{session},    $this->{test_web},
        $this->{test_topic}, "Null points"
    );
    $topicObject->save();

    $this->{session}->finish();
    $Foswiki::cfg{AccessControl} = 'Foswiki::Access::AdminOnlyAccess';
    $this->{session} = Foswiki->new();

    $this->DENIED( "VIEW", $MrOrange );
    $this->DENIED( "VIEW", $MrGreen );
    $this->DENIED( "VIEW", $MrYellow );
    $this->DENIED( "VIEW", $MrWhite );
    $this->DENIED( "view", $MrBlue );
    $this->PERMITTED( "VIEW", 'BaseUserMapping_333' );

    return;
}

# Test that ALLOWWEB works in a top-level web with no finalisation
sub test_allow_web {
    my $this        = shift;
    my $topicObject = Foswiki::Meta->new(
        $this->{session},
        $this->{test_web}, $Foswiki::cfg{WebPrefsTopicName},
        <<'THIS'
If ALLOWWEB is set to a list of wikinames
    * people in the list will be PERMITTED
    * everyone else will be DENIED
   * Set ALLOWWEBVIEW = MrGreen MrYellow MrWhite
THIS
        , undef
    );
    $topicObject->save();

    $topicObject = Foswiki::Meta->new(
        $this->{session},    $this->{test_web},
        $this->{test_topic}, "Null points"
    );
    $topicObject->save();

    # reFoswiki->new, so WebPreferences gets re-read
    $this->{session}->finish();
    $Foswiki::cfg{AccessControl} = 'Foswiki::Access::AdminOnlyAccess';
    $this->{session} = Foswiki->new();

    $this->DENIED( "VIEW", $MrOrange );
    $this->DENIED( "VIEW", $MrGreen );
    $this->DENIED( "VIEW", $MrYellow );
    $this->DENIED( "VIEW", $MrWhite );
    $this->DENIED( "view", $MrBlue );
    $this->PERMITTED( "VIEW", 'BaseUserMapping_333' );

    return;
}

# Test that Web.UserName is equivalent to UserName in ACLs
sub test_webDotUserName {
    my $this        = shift;
    my $topicObject = Foswiki::Meta->new(
        $this->{session}, $this->{test_web}, $this->{test_topic},
        <<'THIS'
If ALLOWTOPIC is set
   1. people in the list are PERMITTED
   2. everyone else is DENIED
   * Set ALLOWTOPICVIEW = MrYellow,%USERSWEB%.MrOrange,Nosuchweb.MrGreen,%MAINWEB%.MrBlue,%SYSTEMWEB%.MrWhite
THIS
        , undef
    );
    $topicObject->save();

    # reFoswiki->new, so WebPreferences gets re-read
    $this->{session}->finish();
    $Foswiki::cfg{AccessControl} = 'Foswiki::Access::AdminOnlyAccess';
    $this->{session} = Foswiki->new();

    $this->DENIED( "VIEW", $MrOrange );
    $this->DENIED( "VIEW", $MrGreen );
    $this->DENIED( "VIEW", $MrYellow );
    $this->DENIED( "VIEW", $MrWhite );
    $this->DENIED( "view", $MrBlue );
    $this->PERMITTED( "VIEW", 'BaseUserMapping_333' );

    return;
}

sub _checkSettings {
    my ( $this, $meta ) = @_;

    $this->assert(
        !$meta->haveAccess( 'VIEW', $MrOrange ),
        " 'VIEW' $this->{test_web}.$this->{test_topic}"
    );
    $this->assert(
        !$meta->haveAccess( 'VIEW', $MrGreen ),
        " 'VIEW' $this->{test_web}.$this->{test_topic}"
    );
    $this->assert(
        !$meta->haveAccess( 'VIEW', $MrYellow ),
        " 'VIEW' $this->{test_web}.$this->{test_topic}"
    );
    $this->assert(
        !$meta->haveAccess( 'VIEW', $MrWhite ),
        " 'VIEW' $this->{test_web}.$this->{test_topic}"
    );
    $this->assert(
        !$meta->haveAccess( 'VIEW', $MrBlue ),
        " 'VIEW' $this->{test_web}.$this->{test_topic}"
    );
    $this->assert(
        $meta->haveAccess( 'VIEW', 'BaseUserMapping_333' ),
        " 'VIEW' $this->{test_web}.$this->{test_topic}"
    );

    return;
}

# Test a * Set embedded in text
sub test_SetInText {
    my $this = shift;

    my $text = <<'THIS';
   * Set ALLOWTOPICVIEW = %USERSWEB%.MrGreen
THIS
    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        $this->{test_topic}, $text );
    $topicObject->save();

    # reFoswiki->new, so WebPreferences gets re-read
    $this->{session}->finish();
    $Foswiki::cfg{AccessControl} = 'Foswiki::Access::AdminOnlyAccess';
    $this->{session} = Foswiki->new();

    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        $this->{test_topic} );
    $this->_checkSettings($topicObject);

    return;
}

# Test a set in meta-data
sub test_setInMETA {
    my $this = shift;

    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        $this->{test_topic}, 'Empty' );
    my $args = {
        name  => 'ALLOWTOPICVIEW',
        title => 'ALLOWTOPICVIEW',
        value => "%USERSWEB%.MrGreen",
        type  => "Set"
    };
    $topicObject->putKeyed( 'PREFERENCE', $args );
    $topicObject->save();

    # reFoswiki->new, so WebPreferences gets re-read
    $this->{session}->finish();
    $Foswiki::cfg{AccessControl} = 'Foswiki::Access::AdminOnlyAccess';
    $this->{session} = Foswiki->new();

    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        $this->{test_topic} );

    $this->_checkSettings($topicObject);

    return;
}

# Check that a PREFERENCE takes precedence over a setting in text
sub test_setInSetAndMETA {
    my $this = shift;

    my $text = <<'THIS';
   * Set ALLOWTOPICVIEW = %USERSWEB%.MrOrange
THIS
    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        $this->{test_topic}, $text );
    my $args = {
        name  => 'ALLOWTOPICVIEW',
        title => 'ALLOWTOPICVIEW',
        value => "%USERSWEB%.MrGreen",
        type  => "Set"
    };
    $topicObject->putKeyed( 'PREFERENCE', $args );
    $topicObject->save();

    # reFoswiki->new, so WebPreferences gets re-read
    $this->{session}->finish();
    $Foswiki::cfg{AccessControl} = 'Foswiki::Access::AdminOnlyAccess';
    $this->{session} = Foswiki->new();

    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        $this->{test_topic} );
    $this->_checkSettings($topicObject);

    return;
}

# Test that hierarchical subweb controls override the parent web
sub test_subweb_controls_override_parent {
    my $this   = shift;
    my $subweb = "$this->{test_web}.SubWeb";

    $Foswiki::cfg{EnableHierarchicalWebs} = 1;

    # First build a parent web with view restricted to MrGreen
    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        $this->{test_topic}, "Nowt" );
    $topicObject->save();

    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        $Foswiki::cfg{WebPrefsTopicName}, <<'THIS');
   * Set ALLOWWEBVIEW = MrGreen
THIS
    $topicObject->save();

    # Now build a subweb with view restricted to MrOrange
    my $webObject = Foswiki::Meta->new( $this->{session}, $subweb );
    $webObject->populateNewWeb();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $subweb,
        $Foswiki::cfg{WebPrefsTopicName}, <<'THIS');
   * Set ALLOWWEBVIEW = MrOrange
THIS
    $topicObject->save();
    $this->{session}->finish();
    $Foswiki::cfg{AccessControl} = 'Foswiki::Access::AdminOnlyAccess';
    $this->{session} = Foswiki->new();
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
    my $subweb = "$this->{test_web}.SubWeb";

    $Foswiki::cfg{EnableHierarchicalWebs} = 1;

    # First build a parent web with view restricted to MrGreen, and
    # finalise the setting
    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        $Foswiki::cfg{WebPrefsTopicName}, <<'THIS');
   * Set ALLOWWEBVIEW = MrGreen
   * Set FINALPREFERENCES = ALLOWWEBVIEW
THIS
    $topicObject->save();

    # Now build a subweb with no restrictions
    my $webObject = Foswiki::Meta->new( $this->{session}, $subweb );
    $webObject->populateNewWeb();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $subweb,
        $Foswiki::cfg{WebPrefsTopicName}, <<'THIS');
THIS
    $topicObject->save();
    $this->{session}->finish();
    $Foswiki::cfg{AccessControl} = 'Foswiki::Access::AdminOnlyAccess';
    $this->{session} = Foswiki->new();
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
    my $subweb = "$this->{test_web}.SubWeb";

    $Foswiki::cfg{EnableHierarchicalWebs} = 1;

    # First build a parent web with view restricted to MrGreen, and
    # finalise the setting
    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        $Foswiki::cfg{WebPrefsTopicName}, <<'THIS');
   * Set ALLOWWEBVIEW = MrGreen
   * Set FINALPREFERENCES = ALLOWWEBVIEW
THIS
    $topicObject->save();

    # Now build a subweb with view restricted to MrOrange
    my $webObject = Foswiki::Meta->new( $this->{session}, $subweb );
    $webObject->populateNewWeb();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $subweb,
        $Foswiki::cfg{WebPrefsTopicName}, <<'THIS');
   * Set ALLOWWEBVIEW = MrOrange
THIS
    $topicObject->save();
    $this->{session}->finish();
    $Foswiki::cfg{AccessControl} = 'Foswiki::Access::AdminOnlyAccess';
    $this->{session} = Foswiki->new();
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
    my $topicObject = Foswiki::Meta->new(
        $this->{session}, $this->{test_web}, $test_topic,
        <<'THIS'
If there is an anchor, and some access restrictions,
anchor is preserved after login.
#anchor
   * Set ALLOWTOPICVIEW = MrYellow
THIS
        , undef
    );
    $topicObject->save();

    # Request the page with the full UI
    my $query = Unit::Request->new(
        {
            webName   => [ $this->{test_web} ],
            topicName => ["$test_topic"],
        }
    );
    $query->path_info("/$this->{test_web}/$test_topic");
    $query->method('GET');
    $query->action('view');
    my $viewUrl =
      $this->{session}
      ->getScriptUrl( '0', 'view', $this->{test_web}, $test_topic );
    $query->uri("$viewUrl");
    my ($text) = $this->capture(
        sub {
            $Foswiki::Plugins::SESSION->{response} =
              Foswiki::UI::handleRequest($query);
        }
    );

    # Get the login URL to compare
    my $loginUrl =
      $this->{session}
      ->getScriptUrl( '0', 'login', $this->{test_web}, $test_topic );

    # Item11121: the test doesn't tolerate ShortURLs, for example.
    # ShortURLs may involve a {ScriptUrlPaths}{view} of '' or something
    # like '/foswiki' (where {ScriptUrlPath} looks like '/foswiki/bin').
    # In any case, the test is hard-wired to ignore {ScriptSuffix}
    $this->expect_failure(
        'Test does\'t cater to ShortURL configurations', using => 'ShortURLs' );

    # Extract what we've been redirected to
    my ($redirect_to) = $text =~ /^Location: (.*?)\r?$/m;
    $this->assert_not_null( $redirect_to,
            "Request should have return a 302 to $loginUrl\n"
          . "But it returned:\n$text" );

    # Check the redirect contains the login url + view to this topic
    $this->assert_matches(
        qr#^$loginUrl.*/view/$this->{test_web}/$test_topic$#,
        $redirect_to,
        "Login did not redirect to a page with the proper anchor:\n"
          . "Location: $redirect_to\n"
          . "Expected: ^$loginUrl.*\%23anchor\$"
    );

    # Get the redirected page after login

    return;
}

1;
