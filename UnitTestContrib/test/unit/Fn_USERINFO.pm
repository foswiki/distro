use strict;

# tests for the correct expansion of USERINFO

package Fn_USERINFO;

use base qw( FoswikiFnTestCase );

use Foswiki;
use Error qw( :try );

sub new {
    $Foswiki::cfg{Register}{AllowLoginName}    =  1;
    my $self = shift()->SUPER::new('USERINFO', @_);
    return $self;
}

sub set_up {
    my $this = shift;
    $this->SUPER::set_up(@_);
    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $this->{users_web},
        "GropeGroup",
        "   * Set GROUP = ScumBag,WikiGuest\n");
}

sub test_basic {
    my $this = shift;

    $Foswiki::cfg{AntiSpam}{HideUserDetails} = 0;
    my $ui = $this->{twiki}->handleCommonTags(
        '%USERINFO%', $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals(
        $Foswiki::cfg{DefaultUserLogin}.", $Foswiki::cfg{UsersWebName}.".$Foswiki::cfg{DefaultUserWikiName}.", ", $ui);
}

sub test_withWikiName {
    my $this = shift;

    $Foswiki::cfg{AntiSpam}{HideUserDetails} = 0;
    my $ui = $this->{twiki}->handleCommonTags('%USERINFO{"ScumBag"}%', $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals(
        "scum, $Foswiki::cfg{UsersWebName}.ScumBag, scumbag\@example.com", $ui);
}

sub test_withLogin {
    my $this = shift;

    $Foswiki::cfg{AntiSpam}{HideUserDetails} = 0;
    my $ui = $this->{twiki}->handleCommonTags('%USERINFO{"scum"}%', $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals(
        "scum, $Foswiki::cfg{UsersWebName}.ScumBag, scumbag\@example.com", $ui);
}

sub test_formatted {
    my $this = shift;

    $Foswiki::cfg{AntiSpam}{HideUserDetails} = 0;
    my $ui = $this->{twiki}->handleCommonTags('%USERINFO{"ScumBag" format="W$wikiusernameU$wikinameE$emailsG$groupsE"}%', $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals(
        "W$Foswiki::cfg{UsersWebName}.ScumBagUScumBagEscumbag\@example.comGGropeGroupE", $ui);

    my $guest_ui = $this->{twiki}->handleCommonTags('%USERINFO{"WikiGuest" format="W$wikiusernameU$wikinameE$emailsG$groupsE"}%', $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals(
		"WTemporaryUSERINFOUsersWeb.WikiGuestUWikiGuestEGBaseGroup, GropeGroupE", $guest_ui);
}

1;
