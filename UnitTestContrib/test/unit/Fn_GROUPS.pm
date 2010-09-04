use strict;

# tests for the correct expansion of GROUPS

package Fn_GROUPS;

use base qw( FoswikiFnTestCase );

use Foswiki;
use Error qw( :try );

sub new {
    my $self = shift()->SUPER::new('GROUPS', @_);
    return $self;
}

sub set_up {
    my $this = shift;
    $this->SUPER::set_up(@_);
}

sub test_basic {
    my $this = shift;

    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $this->{users_web},
        "GropeGroup",
        "   * Set GROUP = ScumBag,WikiGuest\n");

    my $ui = $this->{twiki}->handleCommonTags(
        '%GROUPS%', $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals(<<HUMPH, "$ui\n");
| *Group* | *Members* |
| <nop>AdminGroup | [[TemporaryGROUPSUsersWeb.AdminUser][AdminUser]] [[TemporaryGROUPSUsersWeb.RegistrationAgent][RegistrationAgent]] |
| <nop>BaseGroup | [[TemporaryGROUPSUsersWeb.AdminUser][AdminUser]] [[TemporaryGROUPSUsersWeb.WikiGuest][WikiGuest]] [[TemporaryGROUPSUsersWeb.UnknownUser][UnknownUser]] [[TemporaryGROUPSUsersWeb.ProjectContributor][ProjectContributor]] [[TemporaryGROUPSUsersWeb.RegistrationAgent][RegistrationAgent]] |
| [[TemporaryGROUPSUsersWeb.GropeGroup][GropeGroup]] | [[TemporaryGROUPSUsersWeb.ScumBag][ScumBag]] [[TemporaryGROUPSUsersWeb.WikiGuest][WikiGuest]] |
HUMPH
}

sub test_one_dot_one_compatibility {
    my $this = shift;

    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $this->{users_web},
        "GropeGroup",
        'don\'t Set GROUP = ScumBag,WikiGuest
%META:PREFERENCE{name="GROUP" title="GROUP" type="Set" value="ScumBag,WikiGuest"}%
');

    my $ui = $this->{twiki}->handleCommonTags(
        '%GROUPS%', $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals(<<HUMPH, "$ui\n");
| *Group* | *Members* |
| <nop>AdminGroup | [[TemporaryGROUPSUsersWeb.AdminUser][AdminUser]] [[TemporaryGROUPSUsersWeb.RegistrationAgent][RegistrationAgent]] |
| <nop>BaseGroup | [[TemporaryGROUPSUsersWeb.AdminUser][AdminUser]] [[TemporaryGROUPSUsersWeb.WikiGuest][WikiGuest]] [[TemporaryGROUPSUsersWeb.UnknownUser][UnknownUser]] [[TemporaryGROUPSUsersWeb.ProjectContributor][ProjectContributor]] [[TemporaryGROUPSUsersWeb.RegistrationAgent][RegistrationAgent]] |
| [[TemporaryGROUPSUsersWeb.GropeGroup][GropeGroup]] | [[TemporaryGROUPSUsersWeb.ScumBag][ScumBag]] [[TemporaryGROUPSUsersWeb.WikiGuest][WikiGuest]] |
HUMPH
}

1;
