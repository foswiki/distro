use strict;

# tests for the correct expansion of USERINFO

package Fn_USERINFO;

use FoswikiFnTestCase();
our @ISA = qw( FoswikiFnTestCase );

use Foswiki();
use Foswiki::Func();
use Error qw( :try );

sub new {
    $Foswiki::cfg{Register}{AllowLoginName} = 1;
    my $self = shift()->SUPER::new( 'USERINFO', @_ );
    return $self;
}

sub set_up {
    my $this = shift;
    $this->SUPER::set_up(@_);
    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{users_web}, "GropeGroup");
    $topicObject->text("   * Set GROUP = ScumBag,WikiGuest\n" );
    $topicObject->save();
    $topicObject->finish();
    ($topicObject) =
      Foswiki::Func::readTopic( $this->{users_web}, "FriendsOfGropeGroup");
    $topicObject->text("   * Set GROUP = AdminUser, GropeGroup\n" );
    $topicObject->save();
    $topicObject->finish();
    ($topicObject) =
      Foswiki::Func::readTopic( $this->{users_web}, "FriendsOfFriendsOfGropeGroup");
    $topicObject->text("   * Set GROUP = AdminUser, FriendsOfGropeGroup\n" );
    $topicObject->save();
    $topicObject->finish();
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
    my $testformat =
'W$wikiusernameU$wikinameN$usernameE$emailsG$groupsA$adminIA$isadminIG$isgroupE$bogustoken nop$nopnop $percent $quot $comma$n$n()ewline $lt $gt $amp $dollar';

    $Foswiki::cfg{AntiSpam}{HideUserDetails} = 0;
    my $ui = $this->{test_topicObject}->expandMacros(<<"HERE");
%USERINFO{"ScumBag" format="$testformat"}%
HERE
    $this->assert_str_equals( <<"HERE", $ui );
W$Foswiki::cfg{UsersWebName}.ScumBagUScumBagNscumEscumbag\@example.comGFriendsOfFriendsOfGropeGroup, FriendsOfGropeGroup, GropeGroupAfalseIAfalseIGfalseE\$bogustoken nopnop % " ,

ewline < > & \$
HERE

    my $guest_ui = $this->{test_topicObject}->expandMacros(<<"HERE");
%USERINFO{"WikiGuest" format="$testformat"}%
HERE
    $this->assert_str_equals( <<"HERE", $guest_ui );
W$Foswiki::cfg{UsersWebName}.WikiGuestUWikiGuestNguestEGBaseGroup, FriendsOfFriendsOfGropeGroup, FriendsOfGropeGroup, GropeGroupAfalseIAfalseIGfalseE\$bogustoken nopnop % " ,

ewline < > & \$
HERE

    return;
}

sub test_isgroup {
    my $this = shift;
    my $testformat =
'W$wikiusernameU$wikinameN$usernameE$emailsG$groupsA$adminIA$isadminIG$isgroupE';

    $Foswiki::cfg{AntiSpam}{HideUserDetails} = 0;
    my $ui = $this->{test_topicObject}->expandMacros(<<"HERE");
%USERINFO{"FriendsOfFriendsOfGropeGroup" format="$testformat"}%
HERE
    $this->assert_str_equals( <<"HERE", $ui );
W$Foswiki::cfg{UsersWebName}.FriendsOfFriendsOfGropeGroupUFriendsOfFriendsOfGropeGroupNunknownEscumbag\@example.comGAfalseIAfalseIGtrueE
HERE

    return;
}

sub test_isadmin {
    my $this = shift;
    my $testformat =
'W$wikiusernameU$wikinameN$usernameE$emailsG$groupsA$adminIA$isadminIG$isgroupE';

    $Foswiki::cfg{AntiSpam}{HideUserDetails} = 0;
    my $ui = $this->{test_topicObject}->expandMacros(<<"HERE");
%USERINFO{"$Foswiki::cfg{AdminUserWikiName}" format="$testformat"}%
HERE
    my $adminEmail = $Foswiki::cfg{WebMasterEmail} || 'email not set';
    my $adminusername =
      Foswiki::Func::wikiToUserName( $Foswiki::cfg{AdminUserWikiName} );
    $this->assert_str_equals( <<"HERE", $ui );
W$Foswiki::cfg{UsersWebName}.$Foswiki::cfg{AdminUserWikiName}U$Foswiki::cfg{AdminUserWikiName}N${adminusername}E${adminEmail}GAdminGroup, BaseGroup, FriendsOfFriendsOfGropeGroup, FriendsOfGropeGroupAtrueIAtrueIGfalseE
HERE

    return;
}

1;
