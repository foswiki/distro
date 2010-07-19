use strict;

package AccessControlTests;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

sub new {
    my $class = shift;
    my $self = $class->SUPER::new( 'AccessControl', @_ );
    return $self;
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
        "ReservoirDogsGroup", <<THIS);
   * Set GROUP = MrWhite, $this->{users_web}.MrBlue
THIS
    $topicObject->save();
}

sub tear_down {
    my $this = shift;
    $this->SUPER::tear_down();
}

sub DENIED {
    my ( $this, $mode, $user, $web, $topic ) = @_;
    $web   ||= $this->{test_web};
    $topic ||= $this->{test_topic};
    my $topicObject = Foswiki::Meta->load( $this->{session}, $web, $topic );
    $this->assert( !$topicObject->haveAccess( $mode, $user ),
        "$user $mode $web.$topic" );
}

sub PERMITTED {
    my ( $this, $mode, $user, $web, $topic ) = @_;
    $web   ||= $this->{test_web};
    $topic ||= $this->{test_topic};
    my $topicObject = Foswiki::Meta->load( $this->{session}, $web, $topic );
    $this->assert( $topicObject->haveAccess( $mode, $user ),
        "$user $mode $web.$topic" );
}

# Note: As we do not initialize with a query, the topic that topic prefs
# are initialized from is WebHome. Thus these tests also test reading a topic
# other than the current topic.

# Test that explicitly defined users are denied topic view
sub test_denytopic {
    my $this = shift;
    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        $this->{test_topic}, <<THIS);
If DENYTOPIC is set to a list of wikinames
    * people in the list will be DENIED.
   * Set DENYTOPICVIEW = MrGreen
   * Set DENYTOPICVIEW = ,,MrYellow,,$this->{users_web}.MrOrange,%USERSWEB%.ReservoirDogsGroup,,,
THIS
    $topicObject->save();

    $this->{session}->finish();
    $this->{session} = new Foswiki();

    $this->PERMITTED( "VIEW", $MrGreen );
    $this->DENIED( "VIEW", $MrYellow );
    $this->DENIED( "VIEW", $MrOrange );
    $this->DENIED( "VIEW", $MrWhite );
    $this->DENIED( "view", $MrBlue );
}

# Test that an empty DENYTOPIC doesn't deny anyone
sub test_empty_denytopic {
    my $this = shift;
    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        $this->{test_topic}, <<THIS);
If DENYTOPIC is set to empty ( i.e. Set DENYTOPIC = )
    * access is PERMITTED _i.e _ no-one is denied access to this topic
   * Set DENYTOPICVIEW=
THIS
    $topicObject->save();

    $this->{session}->finish();
    $this->{session} = new Foswiki();
    $this->PERMITTED( "VIEW", $MrGreen );
    $this->PERMITTED( "VIEW", $MrYellow );
    $this->PERMITTED( "VIEW", $MrOrange );
    $this->PERMITTED( "VIEW", $MrWhite );
    $this->PERMITTED( "view", $MrBlue );
}

# Test that an empty DENYTOPIC doesn't deny anyone
sub test_whitespace_denytopic {
    my $this = shift;
    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        $this->{test_topic}, <<THIS);
If DENYTOPIC is set to empty ( i.e. Set DENYTOPIC = )
    * access is PERMITTED _i.e _ no-one is denied access to this topic
   * Set DENYTOPICVIEW =   
THIS
    $topicObject->save();

    $this->{session}->finish();
    $this->{session} = new Foswiki();
    $this->PERMITTED( "VIEW", $MrGreen );
    $this->PERMITTED( "VIEW", $MrYellow );
    $this->PERMITTED( "VIEW", $MrOrange );
    $this->PERMITTED( "VIEW", $MrWhite );
    $this->PERMITTED( "view", $MrBlue );
}

# Test that an whitespace at the end of DENYTOPIC is ok
sub test_denytopic_whitespace {
    my $this = shift;
    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        $this->{test_topic}, <<THIS);
If DENYTOPIC is set to empty ( i.e. Set DENYTOPIC = )
    * access is PERMITTED _i.e _ no-one is denied access to this topic
   * Set DENYTOPICVIEW = MrBlue  
THIS
    $topicObject->save();

    $this->{session}->finish();
    $this->{session} = new Foswiki();
    $this->PERMITTED( "VIEW", $MrGreen );
    $this->PERMITTED( "VIEW", $MrYellow );
    $this->PERMITTED( "VIEW", $MrOrange );
    $this->PERMITTED( "VIEW", $MrWhite );
    $this->DENIED( "view", $MrBlue );
}

# Test that explicitly defined ALLOWTOPIC excludes everyone else
sub test_allowtopic {
    my $this = shift;
    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        $this->{test_topic}, <<THIS);
If ALLOWTOPIC is set
   1. people in the list are PERMITTED
   2. everyone else is DENIED
   * Set ALLOWTOPICVIEW = %USERSWEB%.MrOrange
THIS
    $topicObject->save();

    $this->{session}->finish();
    $this->{session} = new Foswiki();
    $this->PERMITTED( "VIEW", $MrOrange );
    $this->DENIED( "VIEW", $MrGreen );
    $this->DENIED( "VIEW", $MrYellow );
    $this->DENIED( "VIEW", $MrWhite );
    $this->DENIED( "view", $MrBlue );
}

# Test that explicitly defined ALLOWTOPIC excludes everyone else
# Renew the session after each check to force refresh of any caches
sub test_allowtopic_a {
    my $this = shift;
    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        $this->{test_topic}, <<THIS);
If ALLOWTOPIC is set
   1. people in the list are PERMITTED
   2. everyone else is DENIED
   * Set ALLOWTOPICVIEW = %USERSWEB%.MrOrange
THIS
    $topicObject->save();

    my $topicquery = new Unit::Request("");
    $topicquery->path_info("/$this->{test_web}/$this->{test_topic}");

    # renew Foswiki, so WebPreferences gets re-read
    $this->{session}->finish();
    $this->{session} = new Foswiki( undef, $topicquery );
    $this->PERMITTED( "VIEW", $MrOrange );
    $this->{session}->finish();
    $this->{session} = new Foswiki( undef, $topicquery );
    $this->DENIED( "VIEW", $MrGreen );
    $this->{session}->finish();
    $this->{session} = new Foswiki( undef, $topicquery );
    $this->DENIED( "VIEW", $MrYellow );
    $this->{session}->finish();
    $this->{session} = new Foswiki( undef, $topicquery );
    $this->DENIED( "VIEW", $MrWhite );
    $this->{session}->finish();
    $this->{session} = new Foswiki( undef, $topicquery );
    $this->DENIED( "view", $MrBlue );
}

# Test that explicitly defined ALLOWTOPIC excludes everyone else
# Renew the session after each check to force refresh of any caches,
# but don't provide a context,
sub test_allowtopic_b {
    my $this = shift;
    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        $this->{test_topic}, <<THIS);
If ALLOWTOPIC is set
   1. people in the list are PERMITTED
   2. everyone else is DENIED
   * Set ALLOWTOPICVIEW = %USERSWEB%.MrOrange
THIS
    $topicObject->save();

    # renew Foswiki, so WebPreferences gets re-read
    $this->{session}->finish();
    $this->{session} = new Foswiki();
    $this->PERMITTED( "VIEW", $MrOrange );
    $this->{session}->finish();
    $this->{session} = new Foswiki();
    $this->DENIED( "VIEW", $MrGreen );
    $this->{session}->finish();
    $this->{session} = new Foswiki();
    $this->DENIED( "VIEW", $MrYellow );
    $this->{session}->finish();
    $this->{session} = new Foswiki();
    $this->DENIED( "VIEW", $MrWhite );
    $this->{session}->finish();
    $this->{session} = new Foswiki();
    $this->DENIED( "view", $MrBlue );
}

# Test that explicitly defined ALLOWTOPIC excludes everyone else
# Access control in META:PREFERENCE
sub test_allowtopic_c {
    my $this = shift;
    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        $this->{test_topic}, <<THIS);
If ALLOWTOPIC is set
   1. people in the list are PERMITTED
   2. everyone else is DENIED
THIS
    $topicObject->putKeyed('PREFERENCE', { name=>"ALLOWTOPICVIEW", title=>"ALLOWTOPICVIEW", type=>"Set", value=>"%USERSWEB%.MrOrange MrYellow" });
    $topicObject->save();

    # renew Foswiki, so WebPreferences gets re-read
    $this->{session}->finish();
    $this->{session} = new Foswiki();
    $this->PERMITTED( "VIEW", $MrOrange );
    $this->{session}->finish();
    $this->{session} = new Foswiki();
    $this->DENIED( "VIEW", $MrGreen );
    $this->{session}->finish();
    $this->{session} = new Foswiki();
    $this->PERMITTED( "VIEW", $MrYellow );
    $this->{session}->finish();
    $this->{session} = new Foswiki();
    $this->DENIED( "VIEW", $MrWhite );
    $this->{session}->finish();
    $this->{session} = new Foswiki();
    $this->DENIED( "view", $MrBlue );
}

# Test that DENYWEB works in a top-level web with no finalisation
sub test_denyweb {
    my $this = shift;
    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        $Foswiki::cfg{WebPrefsTopicName}, <<THIS);
If DENYWEB is set to a list of wikiname
    * people in the list are DENIED access
   * Set DENYWEBVIEW = $this->{users_web}.MrOrange %USERSWEB%.MrBlue
THIS
    $topicObject->save();

    # renew Foswiki, so WebPreferences gets re-read
    $this->{session}->finish();
    $this->{session} = new Foswiki();
    $topicObject = Foswiki::Meta->new(
        $this->{session},    $this->{test_web},
        $this->{test_topic}, "Null points"
    );
    $topicObject->save();
    $this->DENIED( "VIEW", $MrOrange );
    $this->PERMITTED( "VIEW", $MrGreen );
    $this->PERMITTED( "VIEW", $MrYellow );
    $this->PERMITTED( "VIEW", $MrWhite );
    $this->DENIED( "view", $MrBlue );
}

# Test that ALLOWWEB works in a top-level web with no finalisation
sub test_allow_web {
    my $this        = shift;
    my $topicObject = Foswiki::Meta->new(
        $this->{session},
        $this->{test_web}, $Foswiki::cfg{WebPrefsTopicName},
        <<THIS
If ALLOWWEB is set to a list of wikinames
    * people in the list will be PERMITTED
    * everyone else will be DENIED
   * Set ALLOWWEBVIEW = MrGreen MrYellow MrWhite
THIS
        , undef
    );
    $topicObject->save();

    # renew Foswiki, so WebPreferences gets re-read
    $this->{session}->finish();
    $this->{session} = new Foswiki();
    $topicObject = Foswiki::Meta->new(
        $this->{session},    $this->{test_web},
        $this->{test_topic}, "Null points"
    );
    $topicObject->save();
    $this->DENIED( "VIEW", $MrOrange );
    $this->PERMITTED( "VIEW", $MrGreen );
    $this->PERMITTED( "VIEW", $MrYellow );
    $this->PERMITTED( "VIEW", $MrWhite );
    $this->DENIED( "view", $MrBlue );
}

# Test that Web.UserName is equivalent to UserName in ACLs
sub test_webDotUserName {
    my $this        = shift;
    my $topicObject = Foswiki::Meta->new(
        $this->{session}, $this->{test_web}, $this->{test_topic},
        <<THIS
If ALLOWTOPIC is set
   1. people in the list are PERMITTED
   2. everyone else is DENIED
   * Set ALLOWTOPICVIEW = MrYellow,%USERSWEB%.MrOrange,Nosuchweb.MrGreen,%MAINWEB%.MrBlue,%SYSTEMWEB%.MrWhite
THIS
        , undef
    );
    $topicObject->save();
    $this->{session}->finish();
    $this->{session} = new Foswiki();
    $this->PERMITTED( "VIEW", $MrOrange );
    $this->DENIED( "VIEW", $MrGreen );
    $this->PERMITTED( "VIEW", $MrYellow );
    $this->DENIED( "VIEW", $MrWhite );
    $this->PERMITTED( "view", $MrBlue );
}

sub _checkSettings {
    my ( $this, $meta ) = @_;

    $this->assert(
        !$meta->haveAccess( 'VIEW', $MrOrange ),
        " 'VIEW' $this->{test_web}.$this->{test_topic}"
    );
    $this->assert(
        $meta->haveAccess( 'VIEW', $MrGreen ),
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
}

# Test a * Set embedded in text
sub test_SetInText {
    my $this = shift;

    my $text = <<THIS;
   * Set ALLOWTOPICVIEW = %USERSWEB%.MrGreen
THIS
    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        $this->{test_topic}, $text );
    $topicObject->save();
    $this->{session}->finish();

    $this->{session} = new Foswiki();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        $this->{test_topic} );
    $this->_checkSettings($topicObject);
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
    $this->{session}->finish();

    $this->{session} = new Foswiki();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        $this->{test_topic} );

    $this->_checkSettings($topicObject);
}

# Check that a PREFERENCE takes precedence over a setting in text
sub test_setInSetAndMETA {
    my $this = shift;

    my $text = <<THIS;
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
    $this->{session}->finish();

    $this->{session} = new Foswiki();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        $this->{test_topic} );
    $this->_checkSettings($topicObject);
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
        $Foswiki::cfg{WebPrefsTopicName}, <<THIS);
   * Set ALLOWWEBVIEW = MrGreen
THIS
    $topicObject->save();

    # Now build a subweb with view restricted to MrOrange
    my $webObject = Foswiki::Meta->new( $this->{session}, $subweb );
    $webObject->populateNewWeb();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $subweb,
        $Foswiki::cfg{WebPrefsTopicName}, <<THIS);
   * Set ALLOWWEBVIEW = MrOrange
THIS
    $topicObject->save();
    $this->{session}->finish();

    # Ensure that MrOrange can read the subweb and MrGreen the parent web
    $this->{session} = new Foswiki();
    $this->PERMITTED( "VIEW", $MrOrange, $subweb );
    $this->DENIED( "VIEW", $MrGreen, $subweb );
    $this->PERMITTED( "VIEW", $MrGreen );
    $this->DENIED( "VIEW", $MrOrange );
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
        $Foswiki::cfg{WebPrefsTopicName}, <<THIS);
   * Set ALLOWWEBVIEW = MrGreen
   * Set FINALPREFERENCES = ALLOWWEBVIEW
THIS
    $topicObject->save();

    # Now build a subweb with no restrictions
    my $webObject = Foswiki::Meta->new( $this->{session}, $subweb );
    $webObject->populateNewWeb();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $subweb,
        $Foswiki::cfg{WebPrefsTopicName}, <<THIS);
THIS
    $topicObject->save();
    $this->{session}->finish();

    $this->{session} = new Foswiki();
    $this->PERMITTED( "VIEW", $MrGreen, $subweb );
    $this->DENIED( "VIEW", $MrOrange, $subweb );
    $this->PERMITTED( "VIEW", $MrGreen );
    $this->DENIED( "VIEW", $MrOrange );
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
        $Foswiki::cfg{WebPrefsTopicName}, <<THIS);
   * Set ALLOWWEBVIEW = MrGreen
   * Set FINALPREFERENCES = ALLOWWEBVIEW
THIS
    $topicObject->save();

    # Now build a subweb with view restricted to MrOrange
    my $webObject = Foswiki::Meta->new( $this->{session}, $subweb );
    $webObject->populateNewWeb();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $subweb,
        $Foswiki::cfg{WebPrefsTopicName}, <<THIS);
   * Set ALLOWWEBVIEW = MrOrange
THIS
    $topicObject->save();
    $this->{session}->finish();

    $this->{session} = new Foswiki();
    $this->DENIED( "VIEW", $MrOrange, $subweb );
    $this->PERMITTED( "VIEW", $MrGreen, $subweb );
    $this->PERMITTED( "VIEW", $MrGreen );
    $this->DENIED( "VIEW", $MrOrange );
}

1;
