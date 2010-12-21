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
    $this->assert_matches( qr/^$this->{users_web}.WikiGuest$/, $ui);
    $this->assert_does_not_match( qr/^$this->{users_web}.HiddenGroup$/, $ui);
    my @u = split(',', $ui);
    $this->assert(1, scalar(@u));
}

#sub test_expandHidden {
#    my $this = shift;
#
#    my $ui = $this->{test_topicObject}->expandMacros('%GROUPINFO{"GroupWithHiddenGroup" expand="on"}%');
#    $this->assert_matches( qr/^$this->{users_web}.WikiGuest$/, $ui);
#    $this->assert_does_not_match( qr/^$this->{users_web}.HiddenGroup$/, $ui);
#    $this->assert_does_not_match( qr/^$this->{users_web}.ScumBag$/, $ui);
#    my @u = split(',', $ui);
#    $this->assert(1, scalar(@u));
#}

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
