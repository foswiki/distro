use strict;

package AccessControlTests;

use base qw(FoswikiFnTestCase);

sub new {
    my $class = shift;
    my $self = $class->SUPER::new('AccessControl', @_);
    return $self;
}

use Foswiki;
use Foswiki::Access;

my $testTopic = "TemporaryTestTopic";
my $currUser;
my $savePeople;
my $MrWhite;
my $MrBlue;
my $MrOrange;
my $MrGreen;
my $MrYellow;

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();

    $currUser = $Foswiki::cfg{DefaultUserLogin};
    $this->{twiki}->{store}->saveTopic($this->{twiki}->{user},
                               $Foswiki::cfg{UsersWebName},
                               $Foswiki::cfg{DefaultUserWikiName},'');
    $this->registerUser(
        'white', 'Mr', "White", 'white@example.com');
    $MrWhite = $this->{twiki}->{users}->getCanonicalUserID('white');
    $this->registerUser(
        'blue', 'Mr', "Blue", 'blue@example.com');
    $MrBlue = $this->{twiki}->{users}->getCanonicalUserID('blue');
    $this->registerUser(
        'orange', 'Mr', "Orange", 'orange@example.com');
    $MrOrange = $this->{twiki}->{users}->getCanonicalUserID('orange');
    $this->registerUser(
        'green', 'Mr', "Green", 'green@example.com');
    $MrGreen = $this->{twiki}->{users}->getCanonicalUserID('green');
    $this->registerUser(
        'yellow', 'Mr', "Yellow", 'yellow@example.com');
    $MrYellow = $this->{twiki}->{users}->getCanonicalUserID('yellow');
    $this->{twiki}->{store}->saveTopic(
        $currUser, $this->{users_web}, "ReservoirDogsGroup", <<THIS);
   * Set GROUP = MrWhite, $this->{users_web}.MrBlue
THIS
}

sub tear_down {
    my $this = shift;
    $this->SUPER::tear_down();
}

sub DENIED {
    my( $this, $web, $topic, $mode, $user ) = @_;
    $this->assert(!$this->{twiki}->security->checkAccessPermission
                  ($mode, $user,undef,undef,$topic,$web),
                  "$user $mode $web.$topic");
}

sub PERMITTED {
    my( $this, $web, $topic, $mode, $user ) = @_;
    $this->assert($this->{twiki}->security->checkAccessPermission
                  ($mode, $user,undef,undef,$topic,$web),
                 "$user $mode $web.$topic");
}

# Note: As we do not initialize twiki with a query, the topic that topic prefs
# are initialized from is WebHome. Thus these tests also test reading a topic
# other than the current topic.

sub test_denytopic {
    my $this = shift;
    $this->{twiki}->{store}->saveTopic( $currUser, $this->{test_web}, $testTopic,
                                <<THIS
If DENYTOPIC is set to a list of wikinames
    * people in the list will be DENIED.
\t* Set DENYTOPICVIEW = MrGreen
   * Set DENYTOPICVIEW = MrYellow,$this->{users_web}.MrOrange,%USERSWEB%.ReservoirDogsGroup
THIS
                                , undef);
    $this->{twiki}->finish();
    $this->{twiki} = new Foswiki();

    $this->PERMITTED($this->{test_web},$testTopic,"VIEW",$MrGreen);
    $this->DENIED($this->{test_web},$testTopic,"VIEW",$MrYellow);
    $this->DENIED($this->{test_web},$testTopic,"VIEW",$MrOrange);
    $this->DENIED($this->{test_web},$testTopic,"VIEW",$MrWhite);
    $this->DENIED($this->{test_web},$testTopic,"view",$MrBlue);

}

sub test_empty_denytopic {
    my $this = shift;
    $this->{twiki}->{store}->saveTopic( $currUser, $this->{test_web}, $testTopic,
                                <<THIS
If DENYTOPIC is set to empty ( i.e. Set DENYTOPIC = )
    * access is PERMITTED _i.e _ no-one is denied access to this topic
   * Set DENYTOPICVIEW=
THIS
                                , undef);
    $this->{twiki}->finish();
    $this->{twiki} = new Foswiki();
    $this->PERMITTED($this->{test_web},$testTopic,"VIEW",$MrGreen);
    $this->PERMITTED($this->{test_web},$testTopic,"VIEW",$MrYellow);
    $this->PERMITTED($this->{test_web},$testTopic,"VIEW",$MrOrange);
    $this->PERMITTED($this->{test_web},$testTopic,"VIEW",$MrWhite);
    $this->PERMITTED($this->{test_web},$testTopic,"view",$MrBlue);
}

sub test_allowtopic {
    my $this = shift;
    $this->{twiki}->{store}->saveTopic( $currUser, $this->{test_web}, $testTopic,
                                <<THIS
If ALLOWTOPIC is set
   1. people in the list are PERMITTED
   2. everyone else is DENIED
\t* Set ALLOWTOPICVIEW = %USERSWEB%.MrOrange
THIS
                                , undef);
    $this->{twiki}->finish();
    $this->{twiki} = new Foswiki();
    $this->PERMITTED($this->{test_web},$testTopic,"VIEW",$MrOrange);
    $this->DENIED($this->{test_web},$testTopic,"VIEW",$MrGreen);
    $this->DENIED($this->{test_web},$testTopic,"VIEW",$MrYellow);
    $this->DENIED($this->{test_web},$testTopic,"VIEW",$MrWhite);
    $this->DENIED($this->{test_web},$testTopic,"view",$MrBlue);
}

sub test_allowtopic_a {
    my $this = shift;
    $this->{twiki}->{store}->saveTopic( $currUser, $this->{test_web}, $testTopic,
                                <<THIS
If ALLOWTOPIC is set
   1. people in the list are PERMITTED
   2. everyone else is DENIED
\t* Set ALLOWTOPICVIEW = %USERSWEB%.MrOrange
THIS
                                , undef);
    my $topicquery = new Unit::Request( "" );
    $topicquery->path_info("/$this->{test_web}/$testTopic");
    # renew Foswiki, so WebPreferences gets re-read
    $this->{twiki}->finish();
    $this->{twiki} = new Foswiki(undef, $topicquery);
    $this->PERMITTED($this->{test_web},$testTopic,"VIEW",$MrOrange);
    $this->{twiki}->finish();
    $this->{twiki} = new Foswiki(undef, $topicquery);
    $this->DENIED($this->{test_web},$testTopic,"VIEW",$MrGreen);
    $this->{twiki}->finish();
    $this->{twiki} = new Foswiki(undef, $topicquery);
    $this->DENIED($this->{test_web},$testTopic,"VIEW",$MrYellow);
    $this->{twiki}->finish();
    $this->{twiki} = new Foswiki(undef, $topicquery);
    $this->DENIED($this->{test_web},$testTopic,"VIEW",$MrWhite);
    $this->{twiki}->finish();
    $this->{twiki} = new Foswiki(undef, $topicquery);
    $this->DENIED($this->{test_web},$testTopic,"view",$MrBlue);
}

sub test_allowtopic_b {
    my $this = shift;
    $this->{twiki}->{store}->saveTopic( $currUser, $this->{test_web}, $testTopic,
                                <<THIS
If ALLOWTOPIC is set
   1. people in the list are PERMITTED
   2. everyone else is DENIED
\t* Set ALLOWTOPICVIEW = %USERSWEB%.MrOrange
THIS
                                , undef);
    # renew Foswiki, so WebPreferences gets re-read
    $this->{twiki}->finish();
    $this->{twiki} = new Foswiki();
    $this->PERMITTED($this->{test_web},$testTopic,"VIEW",$MrOrange);
    $this->{twiki}->finish();
    $this->{twiki} = new Foswiki();
    $this->DENIED($this->{test_web},$testTopic,"VIEW",$MrGreen);
    $this->{twiki}->finish();
    $this->{twiki} = new Foswiki();
    $this->DENIED($this->{test_web},$testTopic,"VIEW",$MrYellow);
    $this->{twiki}->finish();
    $this->{twiki} = new Foswiki();
    $this->DENIED($this->{test_web},$testTopic,"VIEW",$MrWhite);
    $this->{twiki}->finish();
    $this->{twiki} = new Foswiki();
    $this->DENIED($this->{test_web},$testTopic,"view",$MrBlue);
}

sub test_allowtopic_c {
    my $this = shift;
    $this->{twiki}->{store}->saveTopic( $currUser, $this->{test_web}, $testTopic,
                                <<THIS
If ALLOWTOPIC is set
   1. people in the list are PERMITTED
   2. everyone else is DENIED
%META:PREFERENCE{name="ALLOWTOPICVIEW" title="ALLOWTOPICVIEW" type="Set" value="%25USERSWEB%25.MrOrange MrYellow"}%
THIS
                                , undef);
    # renew Foswiki, so WebPreferences gets re-read
    $this->{twiki}->finish();
    $this->{twiki} = new Foswiki();
    $this->PERMITTED($this->{test_web},$testTopic,"VIEW",$MrOrange);
    $this->{twiki}->finish();
    $this->{twiki} = new Foswiki();
    $this->DENIED($this->{test_web},$testTopic,"VIEW",$MrGreen);
    $this->{twiki}->finish();
    $this->{twiki} = new Foswiki();
    $this->PERMITTED($this->{test_web},$testTopic,"VIEW",$MrYellow);
    $this->{twiki}->finish();
    $this->{twiki} = new Foswiki();
    $this->DENIED($this->{test_web},$testTopic,"VIEW",$MrWhite);
    $this->{twiki}->finish();
    $this->{twiki} = new Foswiki();
    $this->DENIED($this->{test_web},$testTopic,"view",$MrBlue);
}

sub test_denyweb {
    my $this = shift;
    $this->{twiki}->{store}->saveTopic( $currUser, $this->{test_web}, $Foswiki::cfg{WebPrefsTopicName},
                                <<THIS
If DENYWEB is set to a list of wikiname
    * people in the list are DENIED access
\t* Set DENYWEBVIEW = $this->{users_web}.MrOrange %USERSWEB%.MrBlue
THIS
                                , undef);
    # renew Foswiki, so WebPreferences gets re-read
    $this->{twiki}->finish();
    $this->{twiki} = new Foswiki();
    $this->{twiki}->{store}->saveTopic( $currUser, $this->{test_web}, $testTopic,
                                "Null points");
    $this->DENIED($this->{test_web},$testTopic,"VIEW",$MrOrange);
    $this->PERMITTED($this->{test_web},$testTopic,"VIEW",$MrGreen);
    $this->PERMITTED($this->{test_web},$testTopic,"VIEW",$MrYellow);
    $this->PERMITTED($this->{test_web},$testTopic,"VIEW",$MrWhite);
    $this->DENIED($this->{test_web},$testTopic,"view",$MrBlue);
}

sub test_allow_web {
    my $this = shift;
    $this->{twiki}->{store}->saveTopic(
        $currUser, $this->{test_web}, $Foswiki::cfg{WebPrefsTopicName},
        <<THIS
If ALLOWWEB is set to a list of wikinames
    * people in the list will be PERMITTED
    * everyone else will be DENIED
\t* Set ALLOWWEBVIEW = MrGreen MrYellow MrWhite
THIS
                                , undef);
    # renew Foswiki, so WebPreferences gets re-read
    $this->{twiki}->finish();
    $this->{twiki} = new Foswiki();
    $this->{twiki}->{store}->saveTopic( $currUser, $this->{test_web}, $testTopic,
                                "Null points");
    $this->DENIED($this->{test_web},$testTopic,"VIEW",$MrOrange);
    $this->PERMITTED($this->{test_web},$testTopic,"VIEW",$MrGreen);
    $this->PERMITTED($this->{test_web},$testTopic,"VIEW",$MrYellow);
    $this->PERMITTED($this->{test_web},$testTopic,"VIEW",$MrWhite);
    $this->DENIED($this->{test_web},$testTopic,"view",$MrBlue);
}

sub checkText {
    my ($this, $text, $meta) = @_;

    $this->assert(!$this->{twiki}->security->checkAccessPermission
                  ('VIEW', $MrOrange,
                   $text,$meta,$testTopic,$this->{test_web}),
                  " 'VIEW' $this->{test_web}.$testTopic");
    $this->assert($this->{twiki}->security->checkAccessPermission
                  ('VIEW', $MrGreen,
                   $text,$meta,$testTopic,$this->{test_web}),
                  " 'VIEW' $this->{test_web}.$testTopic");
    $this->assert(!$this->{twiki}->security->checkAccessPermission
                  ('VIEW', $MrYellow,
                   $text,$meta,$testTopic,$this->{test_web}),
                  " 'VIEW' $this->{test_web}.$testTopic");
    $this->assert(!$this->{twiki}->security->checkAccessPermission
                  ('VIEW', $MrWhite,
                   $text,$meta,$testTopic,$this->{test_web}),
                  " 'VIEW' $this->{test_web}.$testTopic");
    $this->assert(!$this->{twiki}->security->checkAccessPermission
                  ('VIEW', $MrBlue,
                   $text,$meta,$testTopic,$this->{test_web}),
                  " 'VIEW' $this->{test_web}.$testTopic");
}

sub test_SetInText {
    my $this = shift;

    $this->{twiki}->{store}->saveTopic( $currUser, $this->{test_web}, $testTopic, 'Empty');
    $this->{twiki}->finish();
    $this->{twiki} = new Foswiki();

    my $text = <<THIS;
\t* Set ALLOWTOPICVIEW = %USERSWEB%.MrGreen
THIS
    $this->checkText($text, undef);
}

sub test_setInMETA {
    my $this = shift;

    $this->{twiki}->{store}->saveTopic( $currUser, $this->{test_web}, $testTopic, 'Empty');
    $this->{twiki}->finish();
    $this->{twiki} = new Foswiki();
    my $meta = new Foswiki::Meta($this->{twiki},$this->{test_web},$testTopic);
    my $args =
      {
          name =>  'ALLOWTOPICVIEW',
          title => 'ALLOWTOPICVIEW',
          value => "%USERSWEB%.MrGreen",
          type =>  "Set"
         };
    $meta->putKeyed('PREFERENCE', $args);
    $this->checkText('', $meta);
}

sub test_setInSetAndMETA {
    my $this = shift;

    $this->{twiki}->{store}->saveTopic( $currUser, $this->{test_web}, $testTopic, 'Empty');
    $this->{twiki}->finish();
    $this->{twiki} = new Foswiki();
    my $meta = new Foswiki::Meta($this->{twiki},$this->{test_web},$testTopic);
    my $args =
      {
          name =>  'ALLOWTOPICVIEW',
          title => 'ALLOWTOPICVIEW',
          value => "%USERSWEB%.MrGreen",
          type =>  "Set"
         };
    $meta->putKeyed('PREFERENCE', $args);
    my $text = <<THIS;
\t* Set ALLOWTOPICVIEW = %USERSWEB%.MrOrange
THIS
    $this->checkText($text, $meta);
}

sub test_setInEmbedAndNoMETA {
    my $this = shift;

    $this->{twiki}->{store}->saveTopic( $currUser, $this->{test_web}, $testTopic, 'Empty');
    $this->{twiki}->finish();
    $this->{twiki} = new Foswiki();
    my $text = <<THIS;
%META:PREFERENCE{name="ALLOWTOPICVIEW" title="ALLOWTOPICVIEW" type="Set" value="%25USERSWEB%25.MrGreen"}%
THIS
    $this->checkText($text, undef);
}

sub test_setInEmbedAndMETA {
    my $this = shift;

    $this->{twiki}->{store}->saveTopic( $currUser, $this->{test_web}, $testTopic, 'Empty');
    $this->{twiki}->finish();
    $this->{twiki} = new Foswiki();
    my $meta = new Foswiki::Meta($this->{twiki},$this->{test_web},$testTopic);
    my $args =
      {
          name =>  'ALLOWTOPICVIEW',
          title => 'ALLOWTOPICVIEW',
          value => "%USERSWEB%.MrGreen",
          type =>  "Set"
         };
    $meta->putKeyed('PREFERENCE', $args);
    my $text = <<THIS;
%META:PREFERENCE{name="ALLOWTOPICVIEW" title="ALLOWTOPICVIEW" type="Set" value="%25USERSWEB%25.MrOrange"}%
THIS
    $this->checkText($text, $meta);
}

sub test_hierarchical_subweb_controls_Item2815 {
    my $this = shift;
    my $subweb = "$this->{test_web}.SubWeb";

    $Foswiki::cfg{EnableHierarchicalWebs} = 1;
    $this->{twiki}->{store}->createWeb($this->{twiki}->{user}, $subweb);
    $this->{twiki}->{store}->saveTopic( $currUser, $this->{test_web}, $testTopic, "Nowt");
    $this->{twiki}->{store}->saveTopic(
        $currUser, $this->{test_web}, $Foswiki::cfg{WebPrefsTopicName},
        <<THIS, undef);
\t* Set ALLOWWEBVIEW = MrGreen
THIS
    $this->{twiki}->{store}->saveTopic(
        $currUser, $subweb, $Foswiki::cfg{WebPrefsTopicName},
        <<THIS, undef);
\t* Set ALLOWWEBVIEW = MrOrange
THIS
    $this->{twiki}->finish();
    $this->{twiki} = new Foswiki();
    $this->PERMITTED($subweb,$testTopic,"VIEW",$MrOrange);
    $this->DENIED($subweb,$testTopic,"VIEW",$MrGreen);
    $this->PERMITTED($this->{test_web},$testTopic,"VIEW",$MrGreen);
    $this->DENIED($this->{test_web},$testTopic,"VIEW",$MrOrange);
}

sub test_webDotUserName {
    my $this = shift;
    $this->{twiki}->{store}->saveTopic( $currUser, $this->{test_web}, $testTopic,
                                <<THIS
If ALLOWTOPIC is set
   1. people in the list are PERMITTED
   2. everyone else is DENIED
\t* Set ALLOWTOPICVIEW = MrYellow,%USERSWEB%.MrOrange,Nosuchweb.MrGreen,%MAINWEB%.MrBlue,%SYSTEMWEB%.MrWhite
THIS
                                , undef);
    $this->{twiki}->finish();
    $this->{twiki} = new Foswiki();
    $this->PERMITTED($this->{test_web},$testTopic,"VIEW",$MrOrange);
    $this->DENIED($this->{test_web},$testTopic,"VIEW",$MrGreen);
    $this->PERMITTED($this->{test_web},$testTopic,"VIEW",$MrYellow);
    $this->DENIED($this->{test_web},$testTopic,"VIEW",$MrWhite);
    $this->PERMITTED($this->{test_web},$testTopic,"view",$MrBlue);
}

# Test that controls are inherited from parent webs
sub test_subweb_inherits_from_parent {
    my $this   = shift;
    my $subweb = "$this->{test_web}.SubWeb";

    $Foswiki::cfg{EnableHierarchicalWebs} = 1;

    # First build a parent web with view restricted to MrGreen, and
    # finalise the setting
    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $this->{test_web},
        $Foswiki::cfg{WebPrefsTopicName}, <<THIS);
   * Set ALLOWWEBVIEW = MrGreen
   * Set FINALPREFERENCES = ALLOWWEBVIEW
THIS

    # Now build a subweb with no restrictions
    $this->{twiki}->{store}->createWeb($this->{twiki}->{user}, $subweb);
    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $subweb,
        $Foswiki::cfg{WebPrefsTopicName}, <<THIS);
THIS
    $this->{twiki}->finish();

    $this->{twiki} = new Foswiki();
    $this->PERMITTED( $this->{test_web},$testTopic,"VIEW", $MrGreen, $subweb );
    $this->DENIED( $this->{test_web},$testTopic,"VIEW", $MrOrange, $subweb );
    $this->PERMITTED( $this->{test_web},$testTopic,"VIEW", $MrGreen );
    $this->DENIED( $this->{test_web},$testTopic,"VIEW", $MrOrange );
}

# Test that finalised controls in parent web override the subweb controls
sub test_finalised_parent_overrides_subweb {
    my $this   = shift;
    my $subweb = "$this->{test_web}.SubWeb";

    $Foswiki::cfg{EnableHierarchicalWebs} = 1;

    # First build a parent web with view restricted to MrGreen, and
    # finalise the setting
    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $this->{test_web},
        $Foswiki::cfg{WebPrefsTopicName}, <<THIS);
   * Set ALLOWWEBVIEW = MrGreen
   * Set FINALPREFERENCES = ALLOWWEBVIEW
THIS

    # Now build a subweb with view restricted to MrOrange
    $this->{twiki}->{store}->createWeb($this->{twiki}->{user}, $subweb);
    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $subweb,
        $Foswiki::cfg{WebPrefsTopicName}, <<THIS);
   * Set ALLOWWEBVIEW = MrOrange
THIS
    $this->{twiki}->finish();

    $this->{twiki} = new Foswiki();
    $this->DENIED( $this->{test_web},$testTopic,"VIEW", $MrOrange, $subweb );
    $this->PERMITTED( $this->{test_web},$testTopic,"VIEW", $MrGreen, $subweb );
    $this->PERMITTED( $this->{test_web},$testTopic,"VIEW", $MrGreen );
    $this->DENIED( $this->{test_web},$testTopic,"VIEW", $MrOrange );
}

1;
