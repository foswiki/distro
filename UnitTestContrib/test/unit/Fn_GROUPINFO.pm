# tests for the correct expansion of GROUPINFO

package Fn_GROUPINFO;
use strict;
use warnings;

use FoswikiFnTestCase();
our @ISA = qw( FoswikiFnTestCase );

use Foswiki();
use Foswiki::Func();
use Error qw( :try );

sub new {
    my ( $class, @args ) = @_;

    $Foswiki::cfg{Register}{AllowLoginName} = 1;

    return $class->SUPER::new( 'GROUPINFO', @args );
}

sub set_up {
    my $this = shift;
    $this->SUPER::set_up(@_);
    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{users_web}, "GropeGroup" );
    $topicObject->text("   * Set GROUP = ScumBag,WikiGuest\n");
    $topicObject->save();
    $topicObject->finish();
    ($topicObject) = Foswiki::Func::readTopic( $this->{users_web}, "PopGroup" );
    $topicObject->text("   * Set GROUP = WikiGuest\n");
    $topicObject->save();
    $topicObject->finish();
    ($topicObject) =
      Foswiki::Func::readTopic( $this->{users_web}, "NobodyGroup" );
    $topicObject->text("   * Set GROUP = \n");
    $topicObject->save();
    $topicObject->finish();
    ($topicObject) =
      Foswiki::Func::readTopic( $this->{users_web}, "NestingGroup" );
    $topicObject->text("   * Set GROUP = GropeGroup\n");
    $topicObject->save();
    $topicObject->finish();
    ($topicObject) =
      Foswiki::Func::readTopic( $this->{users_web}, "OnlyAdminCanChangeGroup" );
    $topicObject->text(
        "   * Set GROUP = WikiGuest\n   * Set TOPICCHANGE = AdminGroup\n");
    $topicObject->save();
    $topicObject->finish();
    ($topicObject) =
      Foswiki::Func::readTopic( $this->{users_web}, "GroupWithHiddenGroup" );
    $topicObject->text("   * Set GROUP = HiddenGroup,WikiGuest\n");
    $topicObject->save();
    $topicObject->finish();
    ($topicObject) =
      Foswiki::Func::readTopic( $this->{users_web}, "HiddenGroup" );
    $topicObject->text(
        "   * Set GROUP = ScumBag\n   * Set ALLOWTOPICVIEW = AdminUser\n");
    $topicObject->save();
    $topicObject->finish();
    ($topicObject) =
      Foswiki::Func::readTopic( $this->{users_web}, "HiddenUserGroup" );
    $topicObject->text("   * Set GROUP = ScumBag,HidemeGood\n");
    $topicObject->save();
    $topicObject->finish();
    ($topicObject) =
      Foswiki::Func::readTopic( $this->{users_web}, "HidemeGood" );
    my $topText = $topicObject->text();
    $topText .= "   * Set ALLOWTOPICVIEW = AdminUser\n";
    $topText = $topicObject->text($topText);
    $topicObject->save();
    $topicObject->finish();

    return;
}

sub test_basic {
    my $this = shift;

    my $ui = $this->{test_topicObject}->expandMacros('%GROUPINFO%');
    $this->assert_matches( qr/\bGropeGroup\b/,           $ui );
    $this->assert_matches( qr/\bPopGroup\b/,             $ui );
    $this->assert_matches( qr/\bNestingGroup\b/,         $ui );
    $this->assert_matches( qr/\bGroupWithHiddenGroup\b/, $ui );
    $this->assert_does_not_match( qr/\bHiddenGroup\b/, $ui );

    return;
}

sub test_withName {
    my $this = shift;

    my $ui =
      $this->{test_topicObject}->expandMacros('%GROUPINFO{"GropeGroup"}%');
    $this->assert_matches( qr/\b$this->{users_web}.ScumBag\b/,   $ui );
    $this->assert_matches( qr/\b$this->{users_web}.WikiGuest\b/, $ui );
    my @u = split( /,/, $ui );
    $this->assert_equals( 2, scalar(@u) );

    return;
}

sub test_withShow {
    my $this = shift;

    my $ui =
      $this->{test_topicObject}
      ->expandMacros('%GROUPINFO{ show="allowchange"}%');
    $this->assert_does_not_match( qr/NobodyGroup/, $ui );
    my @u = split( /,/, $ui );
    $this->assert_equals( 7, scalar(@u) );

    $ui =
      $this->{test_topicObject}
      ->expandMacros('%GROUPINFO{ show="denychange"}%');
    $this->assert_matches( qr/NobodyGroup/, $ui );
    $this->assert_matches( qr/BaseGroup/,   $ui );
    @u = split( /,/, $ui );
    $this->assert_equals( 2, scalar(@u) );

    $ui = $this->{test_topicObject}->expandMacros('%GROUPINFO{ show="all"}%');
    @u = split( /,/, $ui );
    $this->assert_equals( 9, scalar(@u) );
    return;
}

sub test_noExpand {
    my $this = shift;

    my $ui =
      $this->{test_topicObject}
      ->expandMacros('%GROUPINFO{"NestingGroup" expand="off"}%');
    $this->assert_matches( qr/^$this->{users_web}.GropeGroup$/, $ui );

    $ui =
      $this->{test_topicObject}->expandMacros('%GROUPINFO{"NestingGroup"}%');
    $this->assert_matches( qr/\b$this->{users_web}.ScumBag\b/,   $ui );
    $this->assert_matches( qr/\b$this->{users_web}.WikiGuest\b/, $ui );
    my @u = split( /,/, $ui );
    $this->assert_equals( 2, scalar(@u) );

    return;
}

sub test_noExpandHidden {
    my $this = shift;

    my $ui =
      $this->{test_topicObject}
      ->expandMacros('%GROUPINFO{"GroupWithHiddenGroup" expand="off"}%');
    $this->assert_matches( qr/\b$this->{users_web}.WikiGuest\b/, $ui );
    $this->assert_does_not_match( qr/\b$this->{users_web}.HiddenGroup\b/, $ui );
    my @u = split( /,/, $ui );
    $this->assert_equals( 1, scalar(@u) );

    return;
}

sub test_expandHidden {
    my $this = shift;

    my $ui =
      $this->{test_topicObject}
      ->expandMacros('%GROUPINFO{"GroupWithHiddenGroup" expand="on"}%');
    $this->assert_matches( qr/\b$this->{users_web}.WikiGuest\b/, $ui );
    $this->assert_does_not_match( qr/\b$this->{users_web}.HiddenGroup\b/,
        $ui, 'HiddenGroup revealed' );

# SMELL: Tasks/Item10176 - GroupWithHiddenGroup contains HiddenGroup - which contains user ScumBag.  However user ScumBag is NOT hidden.
# So even though HiddenGroup is not visible,  the users it contains are still revealed if they are not also hidden.  Since the HiddenGroup
# itself is not revealed, this bug is questionable.
    $this->assert_matches( qr/\b$this->{users_web}.ScumBag\b/,
        $ui, 'ScumBag revealed' );

    my @u = split( /,/, $ui );
    $this->assert_equals( 2, scalar(@u) );

    return;
}

sub test_expandHiddenUser {
    my $this = shift;

    my $ui =
      $this->{test_topicObject}
      ->expandMacros('%GROUPINFO{"HiddenUserGroup" expand="on"}%');
    $this->assert_matches( qr/\b$this->{users_web}.ScumBag\b/,
        $ui, 'ScumBag missing from HiddenUserGroup' );
    $this->assert_does_not_match( qr/\b$this->{users_web}.HidemeGood\b/,
        $ui, 'HidemeGood revealed' );
    my @u = split( /,/, $ui );
    $this->assert_equals( 1, scalar(@u) );

    return;
}

sub test_expandHiddenUserAsAdmin {
    my $this = shift;

    $this->createNewFoswikiSession( $Foswiki::cfg{AdminUserLogin} );
    $this->{test_topicObject}->finish if $this->{test_topicObject};
    ( $this->{test_topicObject} ) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );
    $this->{test_topicObject}->text("BLEEGLE\n");
    $this->{test_topicObject}->save();

    my $ui =
      $this->{test_topicObject}
      ->expandMacros('%GROUPINFO{"HiddenUserGroup" expand="on"}%');
    $this->assert_matches( qr/$this->{users_web}.ScumBag/,    $ui );
    $this->assert_matches( qr/$this->{users_web}.HidemeGood/, $ui );
    my @u = split( /,/, $ui );
    $this->assert_equals( 2, scalar(@u) );
    $this->{test_topicObject}->finish();

    return;
}

sub test_formatted {
    my $this = shift;

    my $ui =
      $this->{test_topicObject}->expandMacros(
        '%GROUPINFO{"GropeGroup" format="WU$wikiusernameU$usernameW$wikiname"}%'
      );
    $this->assert_str_equals(
"WU$Foswiki::cfg{UsersWebName}.ScumBagUscumWScumBag, WU$Foswiki::cfg{UsersWebName}.WikiGuestUguestWWikiGuest",
        $ui
    );
    $ui =
      $this->{test_topicObject}->expandMacros('%GROUPINFO{format="<$name>"}%');
    $this->assert_matches( qr/^<\w+>(, <\w+>)+$/, $ui );

    $ui =
      $this->{test_topicObject}->expandMacros(
        '%GROUPINFO{"GropeGroup" format="<$username>" separator=";"}%');
    $this->assert_matches( qr/^<\w+>(;<\w+>)+$/, $ui );

    $ui =
      $this->{test_topicObject}->expandMacros(
        '%GROUPINFO{"GropeGroup" format="<$name>" separator=";"}%');
    $this->assert_matches( qr/^<GropeGroup>(;<GropeGroup>)+$/, $ui );

    $ui =
      $this->{test_topicObject}->expandMacros(
'%GROUPINFO{"GropeGroup" header="H" footer="F" format="<$username>" separator=";"}%'
      );
    $this->assert_matches( qr/^H<\w+>(;<\w+>)+F$/, $ui );

    $ui =
      $this->{test_topicObject}->expandMacros(
'%GROUPINFO{"GropeGroup" limit="1" limited="L" footer = "F" format="<$username>"}%'
      );
    $this->assert_matches( qr/^<\w+>LF$/, $ui );

    return;
}

1;
