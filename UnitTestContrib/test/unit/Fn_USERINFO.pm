# tests for the correct expansion of USERINFO
package Fn_USERINFO;

use strict;
use warnings;

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
      Foswiki::Func::readTopic( $this->{users_web}, "GropeGroup" );
    $topicObject->text("   * Set GROUP = ScumBag,WikiGuest\n");
    $topicObject->save();
    $topicObject->finish();
    ($topicObject) =
      Foswiki::Func::readTopic( $this->{users_web}, "FriendsOfGropeGroup" );
    $topicObject->text("   * Set GROUP = AdminUser, GropeGroup\n");
    $topicObject->save();
    $topicObject->finish();
    ($topicObject) =
      Foswiki::Func::readTopic( $this->{users_web},
        "FriendsOfFriendsOfGropeGroup" );
    $topicObject->text("   * Set GROUP = AdminUser, FriendsOfGropeGroup\n");
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

sub test_antispam {
    my $this = shift;
    my $testformat =
'W$wikiusernameU$wikinameN$usernameE$emailsG$groupsA$adminIA$isadminIG$isgroupE$bogustoken nop$nopnop $percent $quot $comma$n$n()ewline $lt $gt $amp $dollar';

    $Foswiki::cfg{AntiSpam}{HideUserDetails} = 1;

    # ScumBag should only see his own information
    $this->createNewFoswikiSession("ScumBag");
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

#'W$wikiusernameU$wikinameN$usernameE$emailsG$groupsA$adminIA$isadminIG$isgroupE$bogustoken nop$nopnop $percent $quot $comma$n$n()ewline $lt $gt $amp $dollar';
    $this->assert_str_equals( <<"HERE", $guest_ui );
W$Foswiki::cfg{UsersWebName}.WikiGuestUWikiGuestNEGAIAIGfalseE\$bogustoken nopnop % " ,

ewline < > & \$
HERE

 # Item11981: Prior request "cloaked" the user info.  Cloak was getting "stuck".
    $ui = $this->{test_topicObject}->expandMacros(<<"HERE");
%USERINFO%
HERE
    $this->assert_str_equals( <<"HERE", $ui );
scum, $Foswiki::cfg{UsersWebName}.ScumBag, scumbag\@example.com
HERE

    # Admin user should see everything
    $this->createNewFoswikiSession( $Foswiki::cfg{AdminUserLogin} );
    $ui = $this->{test_topicObject}->expandMacros(<<"HERE");
%USERINFO{"ScumBag" format="$testformat"}%
HERE
    $this->assert_str_equals( <<"HERE", $ui );
W$Foswiki::cfg{UsersWebName}.ScumBagUScumBagNscumEscumbag\@example.comGFriendsOfFriendsOfGropeGroup, FriendsOfGropeGroup, GropeGroupAfalseIAfalseIGfalseE\$bogustoken nopnop % " ,

ewline < > & \$
HERE

    $guest_ui = $this->{test_topicObject}->expandMacros(<<"HERE");
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
'W$wikiusernameU$wikinameN$usernameE$emailsG:$groups:A$adminIA$isadminIG$isgroupE';

    $Foswiki::cfg{AntiSpam}{HideUserDetails} = 0;
    my $ui = $this->{test_topicObject}->expandMacros(<<"HERE");
%USERINFO{"$Foswiki::cfg{AdminUserWikiName}" format="$testformat"}%
HERE
    my $adminEmail = $Foswiki::cfg{WebMasterEmail} || 'email not set';
    my $adminusername =
      Foswiki::Func::wikiToUserName( $Foswiki::cfg{AdminUserWikiName} );
    my $expected = <<"HERE";
W$Foswiki::cfg{UsersWebName}.$Foswiki::cfg{AdminUserWikiName}U$Foswiki::cfg{AdminUserWikiName}N${adminusername}E${adminEmail}G:AdminGroup, BaseGroup, FriendsOfFriendsOfGropeGroup, FriendsOfGropeGroup:AtrueIAtrueIGfalseE
HERE
    $this->assert_equals( length($ui), length($expected) );
    $this->assert_matches( qr/GfalseE$/,      $ui );    # $isgroup
    $this->assert_matches( qr/AtrueIAtrueIG/, $ui );    # $admin $isadmin

    # Group memberships
    $this->assert_matches( qr/\bAdminGroup\b/,                   $ui );
    $this->assert_matches( qr/\bBaseGroup\b/,                    $ui );
    $this->assert_matches( qr/\bFriendsOfGropeGroup\b/,          $ui );
    $this->assert_matches( qr/\bFriendsOfFriendsOfGropeGroup\b/, $ui );

    # Wikinames and usernames
    $this->assert_matches(
        qr/^W$Foswiki::cfg{UsersWebName}\.$Foswiki::cfg{AdminUserWikiName}U/,
        $ui );
    $this->assert_matches( qr/U$Foswiki::cfg{AdminUserWikiName}N/, $ui );
    $this->assert_matches( qr/N${adminusername}E/,                 $ui );

    #Email
    $this->assert_matches( qr/E${adminEmail}G/, $ui );

    return;
}

#http://foswiki.org/Tasks/Item11619?raw=on
# its difficult to convert TOPICINFO.author into something you can show the users if you can't use USERINFO("cuid")
sub test_Item11619 {
    my $this = shift;

    $Foswiki::cfg{AntiSpam}{HideUserDetails} = 0;
    my $ui = $this->{test_topicObject}->expandMacros(<<'HERE');
---+++ cuid
   * USERINFO for !BaseUserMapping_999: %USERINFO{"BaseUserMapping_999" format="this is user $wikiusername"}%
   * USERINFO for !BaseUserMapping_666: %USERINFO{"BaseUserMapping_666" format="this is user $wikiusername"}%
   * USERINFO for !BaseUserMapping_333: %USERINFO{"BaseUserMapping_333" format="this is user $wikiusername"}%
   * USERINFO for !BaseUserMapping_222: %USERINFO{"BaseUserMapping_222" format="this is user $wikiusername"}%
   * USERINFO for !BaseUserMapping_111: %USERINFO{"BaseUserMapping_111" format="this is user $wikiusername"}%
---+++ login
   * USERINFO for !unknown: %USERINFO{"unknown" format="this is user $wikiusername"}%
   * USERINFO for !guest: %USERINFO{"guest" format="this is user $wikiusername"}%
   * USERINFO for !admin: %USERINFO{"admin" format="this is user $wikiusername"}%
   * USERINFO for !RegistrationAgent: %USERINFO{"RegistrationAgent" format="this is user $wikiusername"}%
   * USERINFO for !ProjectContributor: %USERINFO{"ProjectContributor" format="this is user $wikiusername"}%
---+++ wikiname
   * USERINFO for !UnknownUser: %USERINFO{"UnknownUser" format="this is user $wikiusername"}%
   * USERINFO for !WikiGuest: %USERINFO{"WikiGuest" format="this is user $wikiusername"}%
   * USERINFO for !AdminUser: %USERINFO{"AdminUser" format="this is user $wikiusername"}%
   * USERINFO for !RegistrationAgent: %USERINFO{"RegistrationAgent" format="this is user $wikiusername"}%
   * USERINFO for !ProjectContributor: %USERINFO{"ProjectContributor" format="this is user $wikiusername"}%
HERE
    $this->assert_str_equals(
        <<'RESULT',
---+++ cuid
   * USERINFO for !BaseUserMapping_999: 
   * USERINFO for !BaseUserMapping_666: 
   * USERINFO for !BaseUserMapping_333: 
   * USERINFO for !BaseUserMapping_222: 
   * USERINFO for !BaseUserMapping_111: 
---+++ login
   * USERINFO for !unknown: this is user TemporaryUSERINFOUsersWeb.UnknownUser
   * USERINFO for !guest: this is user TemporaryUSERINFOUsersWeb.WikiGuest
   * USERINFO for !admin: 
   * USERINFO for !RegistrationAgent: this is user TemporaryUSERINFOUsersWeb.RegistrationAgent
   * USERINFO for !ProjectContributor: this is user TemporaryUSERINFOUsersWeb.ProjectContributor
---+++ wikiname
   * USERINFO for !UnknownUser: this is user TemporaryUSERINFOUsersWeb.UnknownUser
   * USERINFO for !WikiGuest: this is user TemporaryUSERINFOUsersWeb.WikiGuest
   * USERINFO for !AdminUser: this is user TemporaryUSERINFOUsersWeb.AdminUser
   * USERINFO for !RegistrationAgent: this is user TemporaryUSERINFOUsersWeb.RegistrationAgent
   * USERINFO for !ProjectContributor: this is user TemporaryUSERINFOUsersWeb.ProjectContributor
RESULT
        $ui
    );
}

1;
