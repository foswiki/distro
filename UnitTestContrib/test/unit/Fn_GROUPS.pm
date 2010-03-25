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
}

sub test_basic {
    my $this = shift;

    my $ui = $this->{test_topicObject}->expandMacros('%GROUPS%');
    $this->assert_str_equals( <<HUMPH, "$ui\n" );
| *Group* | *Members* |
| <nop>AdminGroup | [[TemporaryGROUPSUsersWeb.AdminUser][AdminUser]] |
| <nop>BaseGroup | [[TemporaryGROUPSUsersWeb.AdminUser][AdminUser]] [[TemporaryGROUPSUsersWeb.WikiGuest][WikiGuest]] [[TemporaryGROUPSUsersWeb.UnknownUser][UnknownUser]] [[TemporaryGROUPSUsersWeb.ProjectContributor][ProjectContributor]] [[TemporaryGROUPSUsersWeb.RegistrationAgent][RegistrationAgent]] |
| [[TemporaryGROUPSUsersWeb.GropeGroup][GropeGroup]] | [[TemporaryGROUPSUsersWeb.ScumBag][ScumBag]] [[TemporaryGROUPSUsersWeb.WikiGuest][WikiGuest]] |
HUMPH
}

1;
