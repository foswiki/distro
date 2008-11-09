use strict;

# tests for the correct expansion of GROUPS

package Fn_GROUPS;

use base qw( TWikiFnTestCase );

use TWiki;
use Error qw( :try );

sub new {
    my $self = shift()->SUPER::new('GROUPS', @_);
    return $self;
}

sub set_up {
    my $this = shift;
    $this->SUPER::set_up(@_);
    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $this->{users_web},
        "GropeGroup",
        "   * Set GROUP = ScumBag,TWikiGuest\n");
}

sub test_basic {
    my $this = shift;

    my $ui = $this->{twiki}->handleCommonTags(
        '%GROUPS%', $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals(<<HUMPH, "$ui\n");
| *Group* | *Members* |
| <nop>AdminGroup | [[TemporaryGROUPSUsersWeb.AdminUser][AdminUser]] |
| <nop>TWikiBaseGroup | [[TemporaryGROUPSUsersWeb.AdminUser][AdminUser]] [[TemporaryGROUPSUsersWeb.TWikiGuest][TWikiGuest]] [[TemporaryGROUPSUsersWeb.UnknownUser][UnknownUser]] [[TemporaryGROUPSUsersWeb.ProjectContributor][ProjectContributor]] [[TemporaryGROUPSUsersWeb.TWikiRegistrationAgent][TWikiRegistrationAgent]] |
| [[TemporaryGROUPSUsersWeb.GropeGroup][GropeGroup]] | [[TemporaryGROUPSUsersWeb.ScumBag][ScumBag]] [[TemporaryGROUPSUsersWeb.TWikiGuest][TWikiGuest]] |
HUMPH
}

1;
