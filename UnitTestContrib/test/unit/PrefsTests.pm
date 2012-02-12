# Copyright (C) 2004 Crawford Currie

package PrefsTests;
use strict;
use warnings;
require 5.006;

use FoswikiFnTestCase();
our @ISA = qw( FoswikiFnTestCase );

use Foswiki();
use Foswiki::Prefs();
use Assert;
use Error qw( :try );

sub new {
    my ( $class, @args ) = @_;

    return $class->SUPER::new( 'Prefs', @args );
}

my $testSysWeb = 'TemporaryTestPrefsSystemWeb';
my $topicquery;
my $original;

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();

    $original = $Foswiki::cfg{SystemWebName};

    $Foswiki::cfg{SystemWebName}        = $testSysWeb;
    $Foswiki::cfg{LocalSitePreferences} = "$this->{users_web}.SitePreferences";

    $topicquery = Unit::Request->new('');
    $topicquery->path_info("/$this->{test_web}/$this->{test_topic}");

    try {
        my $webObject =
          $this->populateNewWeb( $TWiki::cfg{SystemWebName}, $original );
        $webObject->finish();
        my ($m) =
          Foswiki::Func::readTopic( $original,
            $TWiki::cfg{SitePrefsTopicName} );
        $m->saveAs( $TWiki::cfg{SystemWebName},
            $TWiki::cfg{SitePrefsTopicName} );
    }
    catch Foswiki::AccessControlException with {
        $this->assert( 0, shift->stringify() );
    }
    catch Error::Simple with {
        $this->assert( 0, shift->stringify() || '' );
    };

    #GROUPs are cached, so we need to go again
    $this->createNewFoswikiSession( undef, $topicquery );

    return;
}

sub tear_down {
    my $this = shift;

    $this->removeWebFixture( $Foswiki::Plugins::SESSION, $testSysWeb );
    $this->SUPER::tear_down();

    return;
}

sub _set {
    my ( $this, $web, $topic, $pref, $val, $type ) = @_;
    $this->assert_not_null($web);
    $this->assert_not_null($topic);
    $this->assert_not_null($pref);
    $type ||= 'Set';

    my $user = $this->{session}->{user};
    $this->assert_not_null($user);
    my ($topicObject) = Foswiki::Func::readTopic( $web, $topic );
    my $text = $topicObject->text() || '';
    $text =~ s/^\s*\* $type $pref =.*$//gm;
    $text .= "\n\t* $type $pref = $val\n";
    $topicObject->text($text);
    try {
        $topicObject->save();
    }
    catch Foswiki::AccessControlException with {
        $this->assert( 0, shift->stringify() );
    }
    catch Error::Simple with {
        $this->assert( 0, shift->stringify() || '' );
    };

    return;
}

sub _setDefaultPref {
    my ( $this, $pref, $val, $type ) = @_;
    $this->_set( $testSysWeb, $Foswiki::cfg{SitePrefsTopicName},
        $pref, $val, $type );

    return;
}

sub _setSitePref {
    my ( $this, $pref, $val, $type ) = @_;
    my ( $web, $topic ) =
      $this->{session}
      ->normalizeWebTopicName( '', $Foswiki::cfg{LocalSitePreferences} );
    $this->assert_str_equals( $web, $Foswiki::cfg{UsersWebName} );
    $this->_set( $web, $topic, $pref, $val, $type );

    return;
}

sub _setWebPref {
    my ( $this, $pref, $val, $type ) = @_;
    $this->_set( $this->{test_web}, $Foswiki::cfg{WebPrefsTopicName},
        $pref, $val, $type );

    return;
}

sub _setTopicPref {
    my ( $this, $pref, $val, $type ) = @_;
    $this->_set( $this->{test_web}, $this->{test_topic}, $pref, $val, $type );

    return;
}

sub _setUserPref {
    my ( $this, $pref, $val, $type ) = @_;
    $this->_set(
        $Foswiki::cfg{UsersWebName},
        $this->{test_user_wikiname},
        $pref, $val, $type
    );

    return;
}

sub test_system {
    my $this = shift;
    $this->_setDefaultPref( "SOURCE",           "DEFAULT" );
    $this->_setDefaultPref( "FINALPREFERENCES", "" );
    $this->_setSitePref( "FINALPREFERENCES", "" );
    $this->_setWebPref( "FINALPREFERENCES", "" );
    $this->_setUserPref( "FINALPREFERENCES", "" );

    my $t = $this->createNewFoswikiSession( $this->{test_user_login} );
    $this->assert_str_equals( "DEFAULT", $t->{prefs}->getPreference("SOURCE") );

    return;
}

sub test_local {
    my $this = shift;

    $this->_setDefaultPref( "SOURCE", "SITE" );

    $this->_setDefaultPref( "FINALPREFERENCES", "" );
    $this->_setSitePref( "FINALPREFERENCES", "" );
    $this->_setWebPref( "FINALPREFERENCES", "" );
    $this->_setUserPref( "FINALPREFERENCES", "" );

    my $t = $this->createNewFoswikiSession( $this->{test_user_login} );
    $this->assert_str_equals( "SITE", $t->{prefs}->getPreference("SOURCE") );

    return;
}

sub test_web {
    my $this = shift;

    $this->_setWebPref( "SOURCE", "WEB" );

    $this->_setDefaultPref( "FINALPREFERENCES", "" );
    $this->_setSitePref( "FINALPREFERENCES", "" );
    $this->_setWebPref( "FINALPREFERENCES", "" );
    $this->_setUserPref( "FINALPREFERENCES", "" );

    my $t =
      $this->createNewFoswikiSession( $this->{test_user_login}, $topicquery );
    $this->assert_str_equals( "WEB", $t->{prefs}->getPreference("SOURCE") );

    return;
}

sub test_user {
    my $this = shift;

    $this->_setUserPref( "SOURCE", "USER" );

    $this->_setDefaultPref( "FINALPREFERENCES", "" );
    $this->_setSitePref( "FINALPREFERENCES", "" );
    $this->_setWebPref( "FINALPREFERENCES", "" );
    $this->_setUserPref( "FINALPREFERENCES", "" );

    my $t =
      $this->createNewFoswikiSession( $this->{test_user_login}, $topicquery );
    $this->assert_str_equals( "USER", $t->{prefs}->getPreference("SOURCE") );

    return;
}

sub test_topic {
    my $this = shift;
    $this->_setTopicPref( "SOURCE", "TOPIC" );

    $this->_setDefaultPref( "FINALPREFERENCES", "" );
    $this->_setSitePref( "FINALPREFERENCES", "" );
    $this->_setWebPref( "FINALPREFERENCES", "" );
    $this->_setUserPref( "FINALPREFERENCES", "" );

    my $t =
      $this->createNewFoswikiSession( $this->{test_user_login}, $topicquery );
    $this->assert_str_equals( "TOPIC", $t->{prefs}->getPreference("SOURCE") );

    return;
}

sub test_order {
    my $this = shift;

    $this->_setDefaultPref( "SOURCE", "DEFAULT" );
    $this->_setSitePref( "SOURCE", "SITE" );
    $this->_setWebPref( "SOURCE", "WEB" );
    $this->_setUserPref( "SOURCE", "USER" );
    $this->_setTopicPref( "SOURCE", "TOPIC" );

    $this->_setDefaultPref( "FINALPREFERENCES", "" );
    $this->_setSitePref( "FINALPREFERENCES", "" );
    $this->_setWebPref( "FINALPREFERENCES", "" );
    $this->_setUserPref( "FINALPREFERENCES", "" );
    my $t =
      $this->createNewFoswikiSession( $this->{test_user_login}, $topicquery );
    $this->assert_str_equals( "TOPIC", $t->{prefs}->getPreference("SOURCE") );

    return;
}

sub test_finalSystem {
    my $this = shift;

    $this->_setDefaultPref( "SOURCE", "DEFAULT" );
    $this->_setSitePref( "SOURCE", "SITE" );
    $this->_setWebPref( "SOURCE", "WEB" );
    $this->_setUserPref( "SOURCE", "USER" );
    $this->_setTopicPref( "SOURCE", "TOPIC" );

    $this->_setDefaultPref( "FINALPREFERENCES", "SOURCE" );
    $this->_setSitePref( "FINALPREFERENCES", "" );
    $this->_setWebPref( "FINALPREFERENCES", "" );
    $this->_setUserPref( "FINALPREFERENCES", "" );

    my $t =
      $this->createNewFoswikiSession( $this->{test_user_login}, $topicquery );
    $this->assert_str_equals( "DEFAULT", $t->{prefs}->getPreference("SOURCE") );

    return;
}

sub test_finalSite {
    my $this = shift;

    $this->_setDefaultPref( "SOURCE", "DEFAULT" );
    $this->_setSitePref( "SOURCE", "SITE" );
    $this->_setWebPref( "SOURCE", "WEB" );
    $this->_setUserPref( "SOURCE", "USER" );
    $this->_setTopicPref( "SOURCE", "TOPIC" );

    $this->_setDefaultPref( "FINALPREFERENCES", "" );
    $this->_setSitePref( "FINALPREFERENCES", "SOURCE" );
    $this->_setWebPref( "FINALPREFERENCES", "" );
    $this->_setUserPref( "FINALPREFERENCES", "" );

    my $t =
      $this->createNewFoswikiSession( $this->{test_user_login}, $topicquery );
    $this->assert_str_equals( "SITE", $t->{prefs}->getPreference("SOURCE") );

    return;
}

sub test_finalWeb {
    my $this = shift;

    $this->_setDefaultPref( "SOURCE", "DEFAULT" );
    $this->_setSitePref( "SOURCE", "SITE" );
    $this->_setWebPref( "SOURCE", "WEB" );
    $this->_setUserPref( "SOURCE", "USER" );
    $this->_setTopicPref( "SOURCE", "TOPIC" );

    $this->_setDefaultPref( "FINALPREFERENCES", "" );
    $this->_setSitePref( "FINALPREFERENCES", "" );
    $this->_setWebPref( "FINALPREFERENCES", "SOURCE" );
    $this->_setUserPref( "FINALPREFERENCES", "" );

    my $t =
      $this->createNewFoswikiSession( $this->{test_user_login}, $topicquery );
    $this->assert_str_equals( "WEB", $t->{prefs}->getPreference("SOURCE") );

    return;
}

sub test_finalUser {
    my $this = shift;

    $this->_setDefaultPref( "SOURCE", "DEFAULT" );
    $this->_setSitePref( "SOURCE", "SITE" );
    $this->_setWebPref( "SOURCE", "WEB" );
    $this->_setUserPref( "SOURCE", "USER" );
    $this->_setTopicPref( "SOURCE", "TOPIC" );

    $this->_setDefaultPref( "FINALPREFERENCES", "" );
    $this->_setSitePref( "FINALPREFERENCES", "" );
    $this->_setWebPref( "FINALPREFERENCES", "" );
    $this->_setUserPref( "FINALPREFERENCES", "SOURCE" );

    my $t =
      $this->createNewFoswikiSession( $this->{test_user_login}, $topicquery );
    $this->assert_str_equals( "USER", $t->{prefs}->getPreference("SOURCE") );

    return;
}

sub test_nouser {
    my $this = shift;

    $this->_setDefaultPref( "SOURCE", "DEFAULT" );
    $this->_setSitePref( "SOURCE", "SITE" );
    $this->_setWebPref( "SOURCE", "WEB" );
    $this->_setUserPref( "SOURCE", "USER" );

    $this->_setDefaultPref( "FINALPREFERENCES", "" );
    $this->_setSitePref( "FINALPREFERENCES", "" );
    $this->_setWebPref( "FINALPREFERENCES", "" );
    $this->_setUserPref( "FINALPREFERENCES", "" );

    my $t =
      $this->createNewFoswikiSession( $this->{test_user_login}, $topicquery );
    $this->assert_str_equals( "WEB",
        $t->{prefs}->getPreference( "SOURCE", undef, 1 ) );

    return;
}

sub test_local_to_default {
    my $this = shift;

    $this->_setDefaultPref( "SOURCE", "GLOBAL" );
    $this->_setDefaultPref( "SOURCE", "LOCAL", "Local" );

    my $t =
      $this->createNewFoswikiSession( $this->{test_user_login}, $topicquery );
    $this->assert_str_equals( "GLOBAL", $t->{prefs}->getPreference("SOURCE") );

    my $localquery = Unit::Request->new('');
    $localquery->path_info("/$testSysWeb/$Foswiki::cfg{SitePrefsTopicName}");

    $t =
      $this->createNewFoswikiSession( $this->{test_user_login}, $localquery );
    $this->assert_str_equals( "LOCAL", $t->{prefs}->getPreference("SOURCE") );

    return;
}

sub test_local_to_site {
    my $this = shift;

    $this->_setSitePref( "SOURCE", "GLOBAL" );
    $this->_setSitePref( "SOURCE", "LOCAL", "Local" );

    my $t =
      $this->createNewFoswikiSession( $this->{test_user_login}, $topicquery );
    $this->assert_str_equals( "GLOBAL", $t->{prefs}->getPreference("SOURCE") );
    my ( $tw, $tt ) =
      $t->normalizeWebTopicName( '', $Foswiki::cfg{LocalSitePreferences} );
    my $localquery = Unit::Request->new('');
    $localquery->path_info("/$tw/$tt");

    $t =
      $this->createNewFoswikiSession( $this->{test_user_login}, $localquery );
    $this->assert_str_equals( "LOCAL", $t->{prefs}->getPreference("SOURCE") );

    return;
}

sub test_local_to_user {
    my $this = shift;

    $this->_setUserPref( "SOURCE", "GLOBAL" );
    $this->_setUserPref( "SOURCE", "LOCAL", "Local" );

    my $t =
      $this->createNewFoswikiSession( $this->{test_user_login}, $topicquery );
    $this->assert_str_equals( "GLOBAL", $t->{prefs}->getPreference("SOURCE") );

    my $localquery = Unit::Request->new('');
    $localquery->path_info(
        "/$Foswiki::cfg{UsersWebName}/$this->{test_user_wikiname}");

    $t =
      $this->createNewFoswikiSession( $this->{test_user_login}, $localquery );
    $this->assert_str_equals( "LOCAL", $t->{prefs}->getPreference("SOURCE") );

    return;
}

sub test_local_to_web {
    my $this = shift;

    $this->_setWebPref( "SOURCE", "GLOBAL" );
    $this->_setWebPref( "SOURCE", "LOCAL", "Local" );

    my $t =
      $this->createNewFoswikiSession( $this->{test_user_login}, $topicquery );
    $this->assert_str_equals( "GLOBAL", $t->{prefs}->getPreference("SOURCE") );

    my $localquery = Unit::Request->new('');
    $localquery->path_info(
        "/$this->{test_web}/$Foswiki::cfg{WebPrefsTopicName}");

    $t =
      $this->createNewFoswikiSession( $this->{test_user_login}, $localquery );
    $this->assert_str_equals( "LOCAL", $t->{prefs}->getPreference("SOURCE") );

    return;
}

sub test_whitespace {
    my $this = shift;

    $this->_setTopicPref( "ONE",   "   VAL \n  UE   " );
    $this->_setTopicPref( "TWO",   "   VAL\n   U\n   E" );
    $this->_setTopicPref( "THREE", "VAL\n   " );

    my $t =
      $this->createNewFoswikiSession( $this->{test_user_login}, $topicquery );
    $this->assert_str_equals( "VAL ", $t->{prefs}->getPreference("ONE") );
    $this->assert_str_equals( "VAL\n   U\n   E",
        $t->{prefs}->getPreference("TWO") );
    $this->assert_str_equals( "VAL", $t->{prefs}->getPreference("THREE") );

    return;
}

1;
