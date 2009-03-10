use strict;

package AccessControlTests;

use base qw(FoswikiFnTestCase);

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
    $this->{session} = new Foswiki();

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

sub test_denytopic {
    my $this = shift;
    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        $this->{test_topic}, <<THIS);
If DENYTOPIC is set to a list of wikinames
    * people in the list will be DENIED.
\t* Set DENYTOPICVIEW = MrGreen
   * Set DENYTOPICVIEW = MrYellow,$this->{users_web}.MrOrange,%USERSWEB%.ReservoirDogsGroup
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

sub test_allowtopic {
    my $this = shift;
    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        $this->{test_topic}, <<THIS);
If ALLOWTOPIC is set
   1. people in the list are PERMITTED
   2. everyone else is DENIED
\t* Set ALLOWTOPICVIEW = %USERSWEB%.MrOrange
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

sub test_allowtopic_a {
    my $this = shift;
    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        $this->{test_topic}, <<THIS);
If ALLOWTOPIC is set
   1. people in the list are PERMITTED
   2. everyone else is DENIED
\t* Set ALLOWTOPICVIEW = %USERSWEB%.MrOrange
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

sub test_allowtopic_b {
    my $this = shift;
    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        $this->{test_topic}, <<THIS);
If ALLOWTOPIC is set
   1. people in the list are PERMITTED
   2. everyone else is DENIED
\t* Set ALLOWTOPICVIEW = %USERSWEB%.MrOrange
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

sub test_allowtopic_c {
    my $this = shift;
    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        $this->{test_topic}, <<THIS);
If ALLOWTOPIC is set
   1. people in the list are PERMITTED
   2. everyone else is DENIED
%META:PREFERENCE{name="ALLOWTOPICVIEW" title="ALLOWTOPICVIEW" type="Set" value="%25USERSWEB%25.MrOrange MrYellow"}%
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
    $this->PERMITTED( "VIEW", $MrYellow );
    $this->{session}->finish();
    $this->{session} = new Foswiki();
    $this->DENIED( "VIEW", $MrWhite );
    $this->{session}->finish();
    $this->{session} = new Foswiki();
    $this->DENIED( "view", $MrBlue );
}

sub test_denyweb {
    my $this = shift;
    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        $Foswiki::cfg{WebPrefsTopicName}, <<THIS);
If DENYWEB is set to a list of wikiname
    * people in the list are DENIED access
\t* Set DENYWEBVIEW = $this->{users_web}.MrOrange %USERSWEB%.MrBlue
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

sub test_allow_web {
    my $this        = shift;
    my $topicObject = Foswiki::Meta->new(
        $this->{session},
        $this->{test_web}, $Foswiki::cfg{WebPrefsTopicName},
        <<THIS
If ALLOWWEB is set to a list of wikinames
    * people in the list will be PERMITTED
    * everyone else will be DENIED
\t* Set ALLOWWEBVIEW = MrGreen MrYellow MrWhite
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

sub checkSettings {
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

sub test_SetInText {
    my $this = shift;

    my $text = <<THIS;
\t* Set ALLOWTOPICVIEW = %USERSWEB%.MrGreen
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
    $this->checkSettings($topicObject);
}

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

    $this->checkSettings($topicObject);
}

# Which takes precedence; a setting in text, or a META:PREFERENCE?
sub test_setInSetAndMETA {
    my $this = shift;

    my $text = <<THIS;
\t* Set ALLOWTOPICVIEW = %USERSWEB%.MrOrange
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
    $this->checkSettings($topicObject);
}

sub test_setInEmbed {
    my $this = shift;

    my $text = <<THIS;
%META:PREFERENCE{name="ALLOWTOPICVIEW" title="ALLOWTOPICVIEW" type="Set" value="%25USERSWEB%25.MrGreen"}%
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
    $this->checkSettings($topicObject);
}

sub test_hierarchical_subweb_controls_Item2815 {
    my $this   = shift;
    my $subweb = "$this->{test_web}.SubWeb";

    $Foswiki::cfg{EnableHierarchicalWebs} = 1;
    my $webObject = Foswiki::Meta->new( $this->{session}, $subweb );
    $webObject->populateNewWeb();
    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        $this->{test_topic}, "Nowt" );
    $topicObject->save();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        $Foswiki::cfg{WebPrefsTopicName}, <<THIS);
\t* Set ALLOWWEBVIEW = MrGreen
THIS
    $topicObject->save();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $subweb,
        $Foswiki::cfg{WebPrefsTopicName}, <<THIS);
\t* Set ALLOWWEBVIEW = MrOrange
THIS
    $topicObject->save();
    $this->{session}->finish();
    $this->{session} = new Foswiki();
    $this->PERMITTED( "VIEW", $MrOrange, $subweb );
    $this->DENIED( "VIEW", $MrGreen, $subweb );
    $this->PERMITTED( "VIEW", $MrGreen );
    $this->DENIED( "VIEW", $MrOrange );
}

sub test_webDotUserName {
    my $this        = shift;
    my $topicObject = Foswiki::Meta->new(
        $this->{session}, $this->{test_web}, $this->{test_topic},
        <<THIS
If ALLOWTOPIC is set
   1. people in the list are PERMITTED
   2. everyone else is DENIED
\t* Set ALLOWTOPICVIEW = MrYellow,%USERSWEB%.MrOrange,Nosuchweb.MrGreen,%MAINWEB%.MrBlue,%SYSTEMWEB%.MrWhite
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
1;
