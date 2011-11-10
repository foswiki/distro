use strict;

# tests for the correct expansion of USERINFO

package Fn_USERINFO;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use Foswiki;
use Error qw( :try );

sub new {
    $Foswiki::cfg{Register}{AllowLoginName} = 1;
    my $self = shift()->SUPER::new( 'USERINFO', @_ );
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

    $Foswiki::cfg{AntiSpam}{HideUserDetails} = 0;
    my $ui = $this->{test_topicObject}->expandMacros('%USERINFO%');
    $this->assert_str_equals(
        $Foswiki::cfg{DefaultUserLogin}
          . ", $Foswiki::cfg{UsersWebName}."
          . $Foswiki::cfg{DefaultUserWikiName} . ", ",
        $ui
    );
}

sub test_withWikiName {
    my $this = shift;

    $Foswiki::cfg{AntiSpam}{HideUserDetails} = 0;
    my $ui = $this->{test_topicObject}->expandMacros('%USERINFO{"ScumBag"}%');
    $this->assert_str_equals(
        "scum, $Foswiki::cfg{UsersWebName}.ScumBag, scumbag\@example.com",
        $ui );
}

sub test_withLogin {
    my $this = shift;

    $Foswiki::cfg{AntiSpam}{HideUserDetails} = 0;
    my $ui = $this->{test_topicObject}->expandMacros('%USERINFO{"scum"}%');
    $this->assert_str_equals(
        "scum, $Foswiki::cfg{UsersWebName}.ScumBag, scumbag\@example.com",
        $ui );
}

sub test_formatted {
    my $this = shift;
    my $testformat = 'W$wikiusernameU$wikinameN$usernameE$emailsG$groupsE';

    $Foswiki::cfg{AntiSpam}{HideUserDetails} = 0;
    my $ui =
      $this->{test_topicObject}->expandMacros(<<"HERE");
%USERINFO{"ScumBag" format="$testformat"}%
HERE
    chomp($ui);
    $this->assert_str_equals(
"W$Foswiki::cfg{UsersWebName}.ScumBagUScumBagNscumEscumbag\@example.comGGropeGroupE",
        $ui
    );

    my $guest_ui =
      $this->{test_topicObject}->expandMacros(<<"HERE");
%USERINFO{"WikiGuest" format="$testformat"}%
HERE
    chomp($guest_ui);
    $this->assert_str_equals(
"WTemporaryUSERINFOUsersWeb.WikiGuestUWikiGuestNguestEGBaseGroup, GropeGroupE",
        $guest_ui
    );
}

1;
