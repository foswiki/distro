use strict;

# tests for the correct expansion of GROUPINFO

package Fn_GROUPINFO;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use Foswiki;
use Error qw( :try );

sub new {
    $Foswiki::cfg{Register}{AllowLoginName} = 1;
    my $self = shift()->SUPER::new( 'GROUPINFO', @_ );
    return $self;
}

sub set_up {
    my $this = shift;
    $this->SUPER::set_up(@_);
    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{users_web}, "GropeGroup",
        "   * Set GROUP = ScumBag,WikiGuest\n" );
    $topicObject->save();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{users_web}, "PopGroup",
        "   * Set GROUP = WikiGuest\n" );
    $topicObject->save();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{users_web}, "NestingGroup",
        "   * Set GROUP = GropeGroup\n" );
    $topicObject->save();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{users_web}, "OnlyAdminCanChangeGroup",
        "   * Set GROUP = WikiGuest\n   * Set TOPICCHANGE = AdminGroup\n" );
    $topicObject->save();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{users_web}, "GroupWithHiddenGroup",
        "   * Set GROUP = HiddenGroup,WikiGuest\n" );
    $topicObject->save();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{users_web}, "HiddenGroup",
        "   * Set GROUP = ScumBag\n   * Set ALLOWTOPICVIEW = AdminUser\n" );
    $topicObject->save();

    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{users_web}, "HiddenUserGroup",
        "   * Set GROUP = ScumBag,HidemeGood\n" );
    $topicObject->save();

    $topicObject =
      Foswiki::Meta->load( $this->{session}, $this->{users_web}, "HidemeGood");
    my $topText = $topicObject->text();
    $topText .= "   * Set ALLOWTOPICVIEW = AdminUser\n";
    $topText = $topicObject->text($topText);
    $topicObject->save();

}

sub test_basic {
    my $this = shift;

    my $ui = $this->{test_topicObject}->expandMacros('%GROUPINFO%');
    $this->assert_matches(qr/\bGropeGroup\b/, $ui);
    $this->assert_matches(qr/\bPopGroup\b/, $ui);
    $this->assert_matches(qr/\bNestingGroup\b/, $ui);
    $this->assert_matches(qr/\bGroupWithHiddenGroup\b/, $ui);
    $this->assert_does_not_match(qr/\bHiddenGroup\b/, $ui);
}

sub test_withName {
    my $this = shift;

    my $ui = $this->{test_topicObject}->expandMacros('%GROUPINFO{"GropeGroup"}%');
    $this->assert_matches( qr/\b$this->{users_web}.ScumBag\b/, $ui);
    $this->assert_matches( qr/\b$this->{users_web}.WikiGuest\b/, $ui);
    my @u = split(',', $ui);
    $this->assert(2, scalar(@u));
}

sub test_noExpand {
    my $this = shift;

    my $ui = $this->{test_topicObject}->expandMacros('%GROUPINFO{"NestingGroup" expand="off"}%');
    $this->assert_matches( qr/^$this->{users_web}.GropeGroup$/, $ui);

    $ui = $this->{test_topicObject}->expandMacros('%GROUPINFO{"NestingGroup"}%');
    $this->assert_matches( qr/\b$this->{users_web}.ScumBag\b/, $ui);
    $this->assert_matches( qr/\b$this->{users_web}.WikiGuest\b/, $ui);
    my @u = split(',', $ui);
    $this->assert(2, scalar(@u));
}

sub test_noExpandHidden {
    my $this = shift;

    my $ui = $this->{test_topicObject}->expandMacros('%GROUPINFO{"GroupWithHiddenGroup" expand="off"}%');
    $this->assert_matches( qr/\b$this->{users_web}.WikiGuest\b/, $ui);
    $this->assert_does_not_match( qr/\b$this->{users_web}.HiddenGroup\b/, $ui);
    my @u = split(',', $ui);
    $this->assert(1, scalar(@u));
}

sub test_expandHidden {
    my $this = shift;

    my $ui = $this->{test_topicObject}->expandMacros('%GROUPINFO{"GroupWithHiddenGroup" expand="on"}%');
    $this->assert_matches( qr/\b$this->{users_web}.WikiGuest\b/, $ui);
    $this->assert_does_not_match( qr/\b$this->{users_web}.HiddenGroup\b/, $ui, 'HiddenGroup revealed');
    $this->assert_does_not_match( qr/\b$this->{users_web}.ScumBag\b/, $ui, 'ScumBag revealed');
    my @u = split(',', $ui);
    $this->assert(1, scalar(@u));
}

sub test_expandHiddenUser {
    my $this = shift;

    my $ui = $this->{test_topicObject}->expandMacros('%GROUPINFO{"HiddenUserGroup" expand="on"}%');
    $this->assert_matches( qr/\b$this->{users_web}.ScumBag\b/, $ui, 'ScumBag missing from HiddenUserGroup');
    $this->assert_does_not_match( qr/\b$this->{users_web}.HidemeGood\b/, $ui, 'HidemeGood revealed');
    my @u = split(',', $ui);
    $this->assert(1, scalar(@u));
}

sub test_expandHiddenUserAsAdmin {
    my $this = shift;

    $this->{session}->finish();
    $this->{session} = new Foswiki( $Foswiki::cfg{AdminUserLogin} );
    $this->{test_topicObject} = Foswiki::Meta->new(
        $this->{session},    $this->{test_web},
        $this->{test_topic}, "BLEEGLE\n"
    );
    $this->{test_topicObject}->save();

    my $ui = $this->{test_topicObject}->expandMacros('%GROUPINFO{"HiddenUserGroup" expand="on"}%');
    print STDERR "($ui)";
    $this->assert_matches( qr/$this->{users_web}.ScumBag/, $ui);
    $this->assert_matches( qr/$this->{users_web}.HidemeGood/, $ui);
    my @u = split(',', $ui);
    $this->assert(2, scalar(@u));
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
    $ui = $this->{test_topicObject}->expandMacros(
        '%GROUPINFO{format="<$name>"}%');
    $this->assert_matches(qr/^<\w+>(, <\w+>)+$/, $ui);

    $ui = $this->{test_topicObject}->expandMacros(
        '%GROUPINFO{"GropeGroup" format="<$username>" separator=";"}%');
    $this->assert_matches(qr/^<\w+>(;<\w+>)+$/, $ui);

    $ui = $this->{test_topicObject}->expandMacros(
        '%GROUPINFO{"GropeGroup" format="<$name>" separator=";"}%');
    $this->assert_matches(qr/^<GropeGroup>(;<GropeGroup>)+$/, $ui);

    $ui = $this->{test_topicObject}->expandMacros(
        '%GROUPINFO{"GropeGroup" header="H" footer="F" format="<$username>" separator=";"}%');
    $this->assert_matches(qr/^H<\w+>(;<\w+>)+F$/, $ui);

    $ui = $this->{test_topicObject}->expandMacros(
        '%GROUPINFO{"GropeGroup" limit="1" limited="L" footer = "F" format="<$username>"}%');
    $this->assert_matches(qr/^<\w+>LF$/, $ui);
}

1;
