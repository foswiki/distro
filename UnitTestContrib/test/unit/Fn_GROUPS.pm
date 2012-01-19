use strict;

# tests for the correct expansion of GROUPS

package Fn_GROUPS;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use Foswiki;
use Error qw( :try );

sub new {
    my $self = shift()->SUPER::new( 'GROUPS', @_ );
    return $self;
}

sub set_up {
    my $this = shift;
    $this->SUPER::set_up(@_);
    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{users_web}, "GropeGroup",
        "   * Set GROUP = ScumBag,WikiGuest\n" );
    $topicObject->save();

    $topicObject = Foswiki::Meta->new(
        $this->{session}, $this->{users_web},
        "NestingGroup",   "   * Set GROUP = GropeGroup\n"
    );
    $topicObject->save();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{users_web},
        "GroupWithHiddenGroup", "   * Set GROUP = HiddenGroup,WikiGuest\n" );
    $topicObject->save();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{users_web}, "HiddenGroup",
        "   * Set GROUP = ScumBag\n   * Set ALLOWTOPICVIEW = AdminUser\n" );
    $topicObject->save();

    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{users_web},
        "HiddenUserGroup", "   * Set GROUP = ScumBag,HidemeGood\n" );
    $topicObject->save();

    $topicObject =
      Foswiki::Meta->load( $this->{session}, $this->{users_web}, "HidemeGood" );
    my $topText = $topicObject->text();
    $topText .= "   * Set ALLOWTOPICVIEW = AdminUser\n";
    $topText = $topicObject->text($topText);
    $topicObject->save();

}

sub test_basic {
    my $this = shift;

    my $ui    = $this->{test_topicObject}->expandMacros('%GROUPS%');
    my $regex = <<STR;
^| *Group* | *Members* |
| <nop>AdminGroup | [[TemporaryGROUPSUsersWeb.AdminUser][AdminUser]] |
| <nop>BaseGroup | [[TemporaryGROUPSUsersWeb.AdminUser][AdminUser]] [[TemporaryGROUPSUsersWeb.WikiGuest][WikiGuest]] [[TemporaryGROUPSUsersWeb.UnknownUser][UnknownUser]] [[TemporaryGROUPSUsersWeb.ProjectContributor][ProjectContributor]] [[TemporaryGROUPSUsersWeb.RegistrationAgent][RegistrationAgent]] |
| [[TemporaryGROUPSUsersWeb.GropeGroup][GropeGroup]] | [[TemporaryGROUPSUsersWeb.ScumBag][ScumBag]] [[TemporaryGROUPSUsersWeb.WikiGuest][WikiGuest]] |
STR
    $this->assert_matches( $regex, "$ui\n",
        'Mismatch in headings and base groups' );
    $this->assert_matches(
qr/^\| \[\[TemporaryGROUPSUsersWeb.HiddenUserGroup\]\[HiddenUserGroup\]\] \| \[\[TemporaryGROUPSUsersWeb.ScumBag\]\[ScumBag\]\] \|/ms,
        $ui,
        'Missmatch on hidden user'
    );
    $this->assert_matches(
qr/^\| \[\[TemporaryGROUPSUsersWeb.NestingGroup\]\[NestingGroup\]\] \| \[\[TemporaryGROUPSUsersWeb.ScumBag\]\[ScumBag\]\] \[\[TemporaryGROUPSUsersWeb.WikiGuest\]\[WikiGuest\]\] \|/ms,
        $ui,
        'mismatch on nesting group'
    );
    $this->assert_does_not_match(
        qr/^\| \[\[TemporaryGROUPSUsersWeb.HiddenGroup\]\[HiddenGroup\]\] \|/ms,
        $ui,
        'Hidden group revealed'
    );

# SMELL: Tasks/Item10176 - GroupWithHiddenGroup contains HiddenGroup - which contains user ScumBag.  However user ScumBag is NOT hidden.
# So even though HiddenGroup is not visible,  the users it contains are still revealed if they are not also hidden.  Since the HiddenGroup
# itself is not revealed, this bug is questionable.
    $this->assert_matches(
qr/^\| \[\[TemporaryGROUPSUsersWeb\.GroupWithHiddenGroup\]\[GroupWithHiddenGroup\]\] \| \[\[TemporaryGROUPSUsersWeb\.ScumBag\]\[ScumBag\]\] \[\[TemporaryGROUPSUsersWeb\.WikiGuest\]\[WikiGuest\]\] \|$/ms,
        $ui,
        'Mismatch on hidden nested group'
    );

}

1;
