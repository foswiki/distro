# tests for the correct expansion of GROUPLIST

package Fn_GROUPLIST;
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

    return $class->SUPER::new( 'GROUPLIST', @args );
}

sub set_up {
    my $this = shift;
    $this->SUPER::set_up(@_);
    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{users_web}, "GropeGroup" );
    $topicObject->text("   * Set GROUP = ScumBag,WikiGuest\n");
    $topicObject->save();
    $topicObject->finish();
    ($topicObject) = Foswiki::Func::readTopic( $this->{users_web}, "PopGroup" );
    $topicObject->text("   * Set GROUP = WikiGuest\n");
    $topicObject->save();
    $topicObject->finish();
    ($topicObject) =
      Foswiki::Func::readTopic( $this->{users_web}, "NobodyGroup" );
    $topicObject->text("   * Set GROUP = \n");
    $topicObject->save();
    $topicObject->finish();
    ($topicObject) =
      Foswiki::Func::readTopic( $this->{users_web}, "NestingGroup" );
    $topicObject->text("   * Set GROUP = GropeGroup\n");
    $topicObject->save();
    $topicObject->finish();
    ($topicObject) =
      Foswiki::Func::readTopic( $this->{users_web}, "OnlyAdminCanChangeGroup" );
    $topicObject->text(
        "   * Set GROUP = WikiGuest\n   * Set TOPICCHANGE = AdminGroup\n");
    $topicObject->save();
    $topicObject->finish();
    ($topicObject) =
      Foswiki::Func::readTopic( $this->{users_web}, "GroupWithHiddenGroup" );
    $topicObject->text("   * Set GROUP = HiddenGroup,WikiGuest\n");
    $topicObject->save();
    $topicObject->finish();
    ($topicObject) =
      Foswiki::Func::readTopic( $this->{users_web}, "HiddenGroup" );
    $topicObject->text(
        "   * Set GROUP = ScumBag\n   * Set ALLOWTOPICVIEW = AdminUser\n");
    $topicObject->save();
    $topicObject->finish();
    ($topicObject) =
      Foswiki::Func::readTopic( $this->{users_web}, "HiddenUserGroup" );
    $topicObject->text("   * Set GROUP = ScumBag,HidemeGood\n");
    $topicObject->save();
    $topicObject->finish();
    ($topicObject) =
      Foswiki::Func::readTopic( $this->{users_web}, "HidemeGood" );
    my $topText = $topicObject->text();
    $topText .= "   * Set ALLOWTOPICVIEW = AdminUser\n";
    $topText = $topicObject->text($topText);
    $topicObject->save();
    $topicObject->finish();

    $Foswiki::cfg{FeatureAccess}{GROUPLIST} = 'all';

    return;
}

sub fixture_groups {

    return ( [ 'Acl', 'Admin', 'All', 'Authenticated' ], );
}

sub Acl {
    $Foswiki::cfg{FeatureAccess}{GROUPLIST} = 'acl';
}

sub Admin {
    $Foswiki::cfg{FeatureAccess}{GROUPLIST} = 'admin';
}

sub All {
    $Foswiki::cfg{FeatureAccess}{GROUPLIST} = 'all';
}

sub Authenticated {
    $Foswiki::cfg{FeatureAccess}{GROUPLIST} = 'authenticated';
}

sub verify_security {
    my $this = shift;

    if ( $Foswiki::cfg{FeatureAccess}{GROUPLIST} eq 'admin' ) {
        $this->createNewFoswikiSession('AdminUser');
    }

    my $ui = $this->{test_topicObject}->expandMacros('%GROUPLIST%');

    if ( $Foswiki::cfg{FeatureAccess}{GROUPLIST} eq 'authenticated' ) {

# Normally we run as tests as guest.  so nothing returned in authenticated case.
        $this->assert_str_equals( '', $ui );
    }
    else {
        # must be acl, admin or all.
        $this->assert_matches( qr/\bGropeGroup\b/,           $ui );
        $this->assert_matches( qr/\bPopGroup\b/,             $ui );
        $this->assert_matches( qr/\bNestingGroup\b/,         $ui );
        $this->assert_matches( qr/\bGroupWithHiddenGroup\b/, $ui );
        $this->assert_matches( qr/\bHiddenGroup\b/,          $ui )
          unless ( $Foswiki::cfg{FeatureAccess}{GROUPLIST} eq 'acl' );
    }

    if ( $Foswiki::cfg{FeatureAccess}{GROUPLIST} eq 'authenticated' ) {
        $this->createNewFoswikiSession('ScumBag');
        $ui = $this->{test_topicObject}->expandMacros('%GROUPLIST%');
        $this->assert_matches( qr/\bGropeGroup\b/,           $ui );
        $this->assert_matches( qr/\bPopGroup\b/,             $ui );
        $this->assert_matches( qr/\bNestingGroup\b/,         $ui );
        $this->assert_matches( qr/\bGroupWithHiddenGroup\b/, $ui );

        # This works because "authenticated" access doesn't do any ACL checking.
        $this->assert_matches( qr/\bHiddenGroup\b/, $ui );
    }

    return;
}

sub test_basic {
    my $this = shift;

    my $ui = $this->{test_topicObject}->expandMacros('%GROUPLIST%');
    $this->assert_matches( qr/\bGropeGroup\b/,           $ui );
    $this->assert_matches( qr/\bPopGroup\b/,             $ui );
    $this->assert_matches( qr/\bNestingGroup\b/,         $ui );
    $this->assert_matches( qr/\bGroupWithHiddenGroup\b/, $ui );
    $this->assert_matches( qr/\bHiddenGroup\b/,          $ui );

    return;
}

sub test_withName {
    my $this = shift;

    my $ui =
      $this->{test_topicObject}->expandMacros('%GROUPLIST{"^GropeGroup$"}%');
    $this->assert_matches( qr/\bGropeGroup\b/, $ui );
    my @u = split( /,/, $ui );
    $this->assert_equals( 1, scalar(@u) );

    return;
}

sub test_withExclude {
    my $this = shift;

    my $ui =
      $this->{test_topicObject}
      ->expandMacros('%GROUPLIST{exclude="Hidden*,PopGroup"}%');
    $this->assert_matches( qr/\bGropeGroup\b/, $ui );
    $this->assert_does_not_match( qr/\bPopGroup\b/, $ui );
    $this->assert_matches( qr/\bNestingGroup\b/,         $ui );
    $this->assert_matches( qr/\bGroupWithHiddenGroup\b/, $ui );
    $this->assert_does_not_match( qr/\bHiddenGroup\b/, $ui );

    return;
}

sub test_withLimit {
    my $this = shift;

    my $ui = $this->{test_topicObject}->expandMacros('%GROUPLIST{limit="3"}%');
    $this->assert_equals( 'AdminGroup, BaseGroup, GropeGroup', $ui );

    return;
}

sub test_formatted {
    my $this = shift;

    my $ui =
      $this->{test_topicObject}
      ->expandMacros('%GROUPLIST{"GropeGroup" format="$groupname"}%');
    $this->assert_str_equals( 'GropeGroup', $ui );
    $ui =
      $this->{test_topicObject}
      ->expandMacros('%GROUPLIST{format="<$groupname>"}%');
    $this->assert_matches( qr/^<\w+>(, <\w+>)+$/, $ui );

    $ui =
      $this->{test_topicObject}
      ->expandMacros('%GROUPLIST{ format="<$groupname>" separator=";"}%');
    $this->assert_matches( qr/^<\w+>(;<\w+>)+$/, $ui );

    $ui =
      $this->{test_topicObject}->expandMacros(
'%GROUPLIST{"Group" header="H" footer="F" format="<$groupname>" separator=";"}%'
      );
    $this->assert_matches( qr/^H<\w+>(;<\w+>)+F$/, $ui );

    $ui =
      $this->{test_topicObject}->expandMacros(
        '%GROUPLIST{"Group" limit="1" footer = "F" format="<$groupname>"}%');
    $this->assert_matches( qr/^<\w+>F$/, $ui );

    return;
}

1;
