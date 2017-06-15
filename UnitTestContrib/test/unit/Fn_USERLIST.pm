# tests for the correct expansion of USERLIST

package Fn_USERLIST;
use strict;
use warnings;

use FoswikiFnTestCase();
our @ISA = qw( FoswikiFnTestCase );

use Foswiki();
use Foswiki::Func();
use Error qw( :try );

sub new {
    my ( $class, @args ) = @_;

    $Foswiki::cfg{Register}{AllowLoginName} = 1;

    return $class->SUPER::new( 'USERLIST', @args );
}

sub set_up {
    my $this = shift;
    $this->SUPER::set_up(@_);

    $this->registerUser( 'UserA', 'User', 'A', 'user@example.com' );
    $this->registerUser( 'HiddenUser', 'Hidden', 'User',
        'user86a@example.com' );

    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{users_web}, "HiddenUser" );
    my $topText = $topicObject->text();
    $topText .= "   * Set ALLOWTOPICVIEW = HiddenUser\n";
    $topText = $topicObject->text($topText);
    $topicObject->save();
    $topicObject->finish();

    $Foswiki::cfg{FeatureAccess}{USERLIST} = 'all';
    return;
}

sub fixture_groups {

    return ( [ 'Acl', 'Admin', 'All', 'Authenticated' ], );
}

sub Acl {
    $Foswiki::cfg{FeatureAccess}{USERLIST} = 'acl';
}

sub Admin {
    $Foswiki::cfg{FeatureAccess}{USERLIST} = 'admin';
}

sub All {
    $Foswiki::cfg{FeatureAccess}{USERLIST} = 'all';
}

sub Authenticated {
    $Foswiki::cfg{FeatureAccess}{USERLIST} = 'authenticated';
}

sub verify_security {
    my $this = shift;

    if ( $Foswiki::cfg{FeatureAccess}{USERLIST} eq 'admin' ) {
        $this->createNewFoswikiSession('AdminUser');
    }

    my $ui = $this->{test_topicObject}->expandMacros('%USERLIST%');

#AdminUser, HiddenUser, ProjectContributor, RegistrationAgent, ScumBag, UnknownUser, UserA, WikiGuest

    if ( $Foswiki::cfg{FeatureAccess}{USERLIST} eq 'authenticated' ) {

# Normally we run as tests as guest.  so nothing returned in authenticated case.
        $this->assert_str_equals( '', $ui );
    }
    else {
        # must be acl, admin or all.
        $this->assert_matches( qr/\bAdminUser\b/,          $ui );
        $this->assert_matches( qr/\bProjectContributor\b/, $ui );
        $this->assert_matches( qr/\bRegistrationAgent\b/,  $ui );
        $this->assert_matches( qr/\bScumBag\b/,            $ui );
        $this->assert_matches( qr/\bUnknownUser\b/,        $ui );
        $this->assert_matches( qr/\bUserA\b/,              $ui );
        $this->assert_matches( qr/\bWikiGuest\b/,          $ui );
        $this->assert_matches( qr/\bHiddenUser\b/,         $ui )
          unless ( $Foswiki::cfg{FeatureAccess}{USERLIST} eq 'acl' );
    }

    if ( $Foswiki::cfg{FeatureAccess}{USERLIST} eq 'authenticated' ) {
        $this->createNewFoswikiSession('ScumBag');
        $ui = $this->{test_topicObject}->expandMacros('%USERLIST%');
        $this->assert_matches( qr/\bAdminUser\b/,          $ui );
        $this->assert_matches( qr/\bProjectContributor\b/, $ui );
        $this->assert_matches( qr/\bRegistrationAgent\b/,  $ui );
        $this->assert_matches( qr/\bScumBag\b/,            $ui );
        $this->assert_matches( qr/\bUnknownUser\b/,        $ui );
        $this->assert_matches( qr/\bUserA\b/,              $ui );
        $this->assert_matches( qr/\bWikiGuest\b/,          $ui );

        # This works because "authenticated" access doesn't do any ACL checking.
        $this->assert_matches( qr/\bHiddenUser\b/, $ui );
    }

    return;
}

sub test_basic {
    my $this = shift;

    my $ui = $this->{test_topicObject}->expandMacros('%USERLIST%');
    my @u = split( /,/, $ui );
    $this->assert_matches( qr/\bAdminUser\b/,          shift(@u) );
    $this->assert_matches( qr/\bHiddenUser\b/,         shift(@u) );
    $this->assert_matches( qr/\bProjectContributor\b/, shift(@u) );
    $this->assert_matches( qr/\bRegistrationAgent\b/,  shift(@u) );
    $this->assert_matches( qr/\bScumBag\b/,            shift(@u) );
    $this->assert_matches( qr/\bUnknownUser\b/,        shift(@u) );
    $this->assert_matches( qr/\bUserA\b/,              shift(@u) );
    $this->assert_matches( qr/\bWikiGuest\b/,          shift(@u) );
    $this->assert_equals( 0, scalar(@u) );

    return;
}

sub test_withName {
    my $this = shift;

    my $ui = $this->{test_topicObject}->expandMacros('%USERLIST{"^ScumBag$"}%');
    $this->assert_matches( qr/\bScumBag\b/, $ui );
    my @u = split( /,/, $ui );
    $this->assert_equals( 1, scalar(@u) );

    return;
}

sub test_withExclude {
    my $this = shift;

    my $ui =
      $this->{test_topicObject}
      ->expandMacros('%USERLIST{exclude="Scum*,AdminUser,Unknown"}%');
    my @u = split( /,/, $ui );
    $this->assert_matches( qr/\bHiddenUser\b/,         shift(@u) );
    $this->assert_matches( qr/\bProjectContributor\b/, shift(@u) );
    $this->assert_matches( qr/\bRegistrationAgent\b/,  shift(@u) );
    $this->assert_matches( qr/\bUnknownUser\b/,        shift(@u) );
    $this->assert_matches( qr/\bUserA\b/,              shift(@u) );
    $this->assert_matches( qr/\bWikiGuest\b/,          shift(@u) );
    $this->assert_equals( 0, scalar(@u) );

    return;
}

sub test_withLimit {
    my $this = shift;

    my $ui = $this->{test_topicObject}->expandMacros('%USERLIST{limit="3"}%');
    $this->assert_equals( 'AdminUser, HiddenUser, ProjectContributor', $ui );

    return;
}

sub test_formatted {
    my $this = shift;

    my $ui =
      $this->{test_topicObject}->expandMacros(
'%USERLIST{"foo" header="HHH$n" footer="FFF$n" format="$wikiname" separator="XXX"}%'
      );

    #No users match,  so results should be empty.
    $this->assert_str_equals( '', $ui );

    $ui =
      $this->{test_topicObject}
      ->expandMacros('%USERLIST{format="<$wikiname>"}%');
    $this->assert_matches( qr/^<\w+>(, <\w+>)+$/, $ui );

    $ui =
      $this->{test_topicObject}
      ->expandMacros('%USERLIST{"User" format="<$wikiname>" separator=";"}%');
    $this->assert_matches( qr/^<\w+>(;<\w+>)+$/, $ui );

    $ui =
      $this->{test_topicObject}
      ->expandMacros('%USERLIST{"User" format="<$wikiname>" separator="; "}%');
    $this->assert_matches( qr/^<AdminUser>;/,  $ui );
    $this->assert_matches( qr/<HiddenUser>;/,  $ui );
    $this->assert_matches( qr/<UnknownUser>;/, $ui );
    $this->assert_matches( qr/<UserA>$/,       $ui );

    $ui =
      $this->{test_topicObject}->expandMacros(
'%USERLIST{"User" header="HHH$n()" footer="$n()FFF$n" format="$wikiname" separator="XXX"}%'
      );
    $this->assert_str_equals( $ui, <<RESULTS );
HHH
AdminUserXXXHiddenUserXXXUnknownUserXXXUserA
FFF
RESULTS

    return;
}

1;
