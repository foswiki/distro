# Copyright (C) 2004 Crawford Currie
require 5.006;
package PrefsTests;

use base qw(TWikiFnTestCase);

use TWiki;
use TWiki::Prefs;
use strict;
use Assert;
use Error qw( :try );

sub new {
    my $self = shift()->SUPER::new("Prefs", @_);
    return $self;
}

my $testSysWeb = 'TemporaryTestPrefsSystemWeb';

my $twiki;
my $topicquery;

my $original;
sub set_up {
    my $this = shift;

    $this->SUPER::set_up();

    $original = $TWiki::cfg{SystemWebName};

    $TWiki::cfg{SystemWebName} = $testSysWeb;
    $TWiki::cfg{LocalSitePreferences} = "$this->{users_web}.TWikiPreferences";

    $twiki = $this->{twiki};

    $topicquery = new Unit::Request( "" );
    $topicquery->path_info("/$this->{test_web}/$this->{test_topic}");

    try {
        $twiki->{store}->saveTopic(
            $twiki->{user}, $this->{users_web}, $TWiki::cfg{SuperAdminGroup},
            '   * Set GROUP = '.
              $twiki->{users}->getWikiName($twiki->{user})."\n");
        $twiki->{store}->createWeb($twiki->{user}, $testSysWeb, $original);

        $twiki->{store}->copyTopic(
            $twiki->{user}, $original, $TWiki::cfg{SitePrefsTopicName},
            $testSysWeb, $TWiki::cfg{SitePrefsTopicName} );

    } catch TWiki::AccessControlException with {
        $this->assert(0,shift->stringify());
    } catch Error::Simple with {
        $this->assert(0,shift->stringify()||'');
    };
    #GROUPs are cached, so we need to go again
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki(undef, $topicquery);
    $twiki = $this->{twiki};
    $TWiki::Plugins::SESSION = $this->{twiki};
}

sub tear_down {
    my $this = shift;

    $this->removeWebFixture($twiki, $testSysWeb);
    $this->SUPER::tear_down();
}

sub _set {
    my ( $this, $web, $topic, $pref, $val, $type ) = @_;
    $this->assert_not_null($web);
    $this->assert_not_null($topic);
    $this->assert_not_null($pref);
    $type ||= 'Set';

    my $user = $twiki->{user};
    $this->assert_not_null($user);
    my( $meta, $text) = $twiki->{store}->readTopic($user, $web, $topic);
    $text =~ s/^\s*\* $type $pref =.*$//gm;
    $text .= "\n\t* $type $pref = $val\n";
    try {
        $twiki->{store}->saveTopic($user, $web, $topic, $text, $meta);
    } catch TWiki::AccessControlException with {
        $this->assert(0,shift->stringify());
    } catch Error::Simple with {
        $this->assert(0,shift->stringify()||'');
    };
}

sub _setDefaultPref {
   my ( $this, $pref, $val, $type ) = @_;
   $this->_set($testSysWeb, $TWiki::cfg{SitePrefsTopicName},
               $pref, $val, $type);
}

sub _setSitePref {
   my ( $this, $pref, $val, $type ) = @_;
   my ( $web, $topic ) = $twiki->normalizeWebTopicName(
       '', $TWiki::cfg{LocalSitePreferences} );
   $this->assert_str_equals($web,$TWiki::cfg{UsersWebName});
   $this->_set($web, $topic, $pref, $val, $type);
}

sub _setWebPref {
   my ( $this, $pref, $val, $type ) = @_;
   $this->_set($this->{test_web}, $TWiki::cfg{WebPrefsTopicName},
               $pref, $val, $type);
}

sub _setTopicPref {
   my ( $this, $pref, $val, $type ) = @_;
   $this->_set($this->{test_web}, $this->{test_topic}, $pref, $val, $type);
}

sub _setUserPref {
   my ( $this, $pref, $val, $type ) = @_;
   $this->_set($TWiki::cfg{UsersWebName}, $this->{test_user_wikiname},
               $pref, $val, $type);
}

sub test_system {
    my $this = shift;
    $this->_setDefaultPref("SOURCE", "DEFAULT");
    $this->_setDefaultPref("FINALPREFERENCES", "");
    $this->_setSitePref("FINALPREFERENCES", "");
    $this->_setWebPref("FINALPREFERENCES", "");
    $this->_setUserPref("FINALPREFERENCES", "");

    my $t = new TWiki( $this->{test_user_login} );
    $this->assert_str_equals("DEFAULT",
                             $t->{prefs}->getPreferencesValue("SOURCE"));
    $t->finish();
}

sub test_local {
    my $this = shift;

    $this->_setDefaultPref("SOURCE", "SITE");

    $this->_setDefaultPref("FINALPREFERENCES", "");
    $this->_setSitePref("FINALPREFERENCES", "");
    $this->_setWebPref("FINALPREFERENCES", "");
    $this->_setUserPref("FINALPREFERENCES", "");

    my $t = new TWiki( $this->{test_user_login} );
    $this->assert_str_equals("SITE",
                             $t->{prefs}->getPreferencesValue("SOURCE"));
    $t->finish();
}

sub test_web {
    my $this = shift;

    $this->_setWebPref("SOURCE", "WEB");

    $this->_setDefaultPref("FINALPREFERENCES", "");
    $this->_setSitePref("FINALPREFERENCES", "");
    $this->_setWebPref("FINALPREFERENCES", "");
    $this->_setUserPref("FINALPREFERENCES", "");

    my $t = new TWiki( $this->{test_user_login}, $topicquery );
    $this->assert_str_equals("WEB",
                             $t->{prefs}->getPreferencesValue("SOURCE"));
    $t->finish();
}

sub test_user {
    my $this = shift;

    $this->_setUserPref("SOURCE", "USER");

    $this->_setDefaultPref("FINALPREFERENCES", "");
    $this->_setSitePref("FINALPREFERENCES", "");
    $this->_setWebPref("FINALPREFERENCES", "");
    $this->_setUserPref("FINALPREFERENCES", "");

    my $t = new TWiki( $this->{test_user_login}, $topicquery );
    $this->assert_str_equals("USER",
                             $t->{prefs}->getPreferencesValue("SOURCE"));
    $t->finish();
}

sub test_topic {
    my $this = shift;
    $this->_setTopicPref("SOURCE", "TOPIC");

    $this->_setDefaultPref("FINALPREFERENCES", "");
    $this->_setSitePref("FINALPREFERENCES", "");
    $this->_setWebPref("FINALPREFERENCES", "");
    $this->_setUserPref("FINALPREFERENCES", "");

    my $t = new TWiki( $this->{test_user_login}, $topicquery );
    $this->assert_str_equals("TOPIC",
                             $t->{prefs}->getPreferencesValue("SOURCE"));
    $t->finish();
}

sub test_order {
    my $this = shift;

    $this->_setDefaultPref("SOURCE", "DEFAULT");
    $this->_setSitePref("SOURCE", "SITE");
    $this->_setWebPref("SOURCE", "WEB");
    $this->_setUserPref("SOURCE", "USER");
    $this->_setTopicPref("SOURCE", "TOPIC");

    $this->_setDefaultPref("FINALPREFERENCES", "");
    $this->_setSitePref("FINALPREFERENCES", "");
    $this->_setWebPref("FINALPREFERENCES", "");
    $this->_setUserPref("FINALPREFERENCES", "");
    my $t = new TWiki( $this->{test_user_login}, $topicquery );
    $this->assert_str_equals("TOPIC",
                             $t->{prefs}->getPreferencesValue("SOURCE"));
    $t->finish();
}

sub test_finalSystem {
    my $this = shift;

    $this->_setDefaultPref("SOURCE", "DEFAULT");
    $this->_setSitePref("SOURCE", "SITE");
    $this->_setWebPref("SOURCE", "WEB");
    $this->_setUserPref("SOURCE", "USER");
    $this->_setTopicPref("SOURCE", "TOPIC");

    $this->_setDefaultPref("FINALPREFERENCES", "SOURCE");
    $this->_setSitePref("FINALPREFERENCES", "");
    $this->_setWebPref("FINALPREFERENCES", "");
    $this->_setUserPref("FINALPREFERENCES", "");

    my $t = new TWiki( $this->{test_user_login}, $topicquery );
    $this->assert_str_equals("DEFAULT",
                             $t->{prefs}->getPreferencesValue("SOURCE"));
    $t->finish();
}

sub test_finalSite {
    my $this = shift;

    $this->_setDefaultPref("SOURCE", "DEFAULT");
    $this->_setSitePref("SOURCE", "SITE");
    $this->_setWebPref("SOURCE", "WEB");
    $this->_setUserPref("SOURCE", "USER");
    $this->_setTopicPref("SOURCE", "TOPIC");

    $this->_setDefaultPref("FINALPREFERENCES", "");
    $this->_setSitePref("FINALPREFERENCES", "SOURCE");
    $this->_setWebPref("FINALPREFERENCES", "");
    $this->_setUserPref("FINALPREFERENCES", "");

    my $t = new TWiki( $this->{test_user_login}, $topicquery );
    $this->assert_str_equals("SITE",
                             $t->{prefs}->getPreferencesValue("SOURCE"));
    $t->finish();
}

sub test_finalWeb {
    my $this = shift;

    $this->_setDefaultPref("SOURCE", "DEFAULT");
    $this->_setSitePref("SOURCE", "SITE");
    $this->_setWebPref("SOURCE", "WEB");
    $this->_setUserPref("SOURCE", "USER");
    $this->_setTopicPref("SOURCE", "TOPIC");

    $this->_setDefaultPref("FINALPREFERENCES", "");
    $this->_setSitePref("FINALPREFERENCES", "");
    $this->_setWebPref("FINALPREFERENCES", "SOURCE");
    $this->_setUserPref("FINALPREFERENCES", "");

    my $t = new TWiki( $this->{test_user_login}, $topicquery );
    $this->assert_str_equals("WEB",
                             $t->{prefs}->getPreferencesValue("SOURCE"));
    $t->finish();
}

sub test_finalUser {
    my $this = shift;

    $this->_setDefaultPref("SOURCE", "DEFAULT");
    $this->_setSitePref("SOURCE", "SITE");
    $this->_setWebPref("SOURCE", "WEB");
    $this->_setUserPref("SOURCE", "USER");
    $this->_setTopicPref("SOURCE", "TOPIC");

    $this->_setDefaultPref("FINALPREFERENCES", "");
    $this->_setSitePref("FINALPREFERENCES", "");
    $this->_setWebPref("FINALPREFERENCES", "");
    $this->_setUserPref("FINALPREFERENCES", "SOURCE");

    my $t = new TWiki( $this->{test_user_login}, $topicquery );
    $this->assert_str_equals("USER",
                             $t->{prefs}->getPreferencesValue("SOURCE"));
    $t->finish();
}

sub test_nouser {
    my $this = shift;

    $this->_setDefaultPref("SOURCE", "DEFAULT");
    $this->_setSitePref("SOURCE", "SITE");
    $this->_setWebPref("SOURCE", "WEB");
    $this->_setUserPref("SOURCE", "USER");

    $this->_setDefaultPref("FINALPREFERENCES", "");
    $this->_setSitePref("FINALPREFERENCES", "");
    $this->_setWebPref("FINALPREFERENCES", "");
    $this->_setUserPref("FINALPREFERENCES", "");

    my $t = new TWiki( $this->{test_user_login}, $topicquery );
    $this->assert_str_equals("WEB",
                             $t->{prefs}->getPreferencesValue("SOURCE", undef, 1));
    $t->finish();
}

sub test_local_to_default {
    my $this = shift;

    $this->_setDefaultPref("SOURCE", "GLOBAL");
    $this->_setDefaultPref("SOURCE", "LOCAL", "Local");

    my $t = new TWiki( $this->{test_user_login}, $topicquery );
    $this->assert_str_equals("GLOBAL",
                             $t->{prefs}->getPreferencesValue("SOURCE"));

    my $localquery = new Unit::Request( "" );
    $localquery->path_info("/$testSysWeb/$TWiki::cfg{SitePrefsTopicName}");
    $t->finish();
    $t = new TWiki( $this->{test_user_login}, $localquery );
    $this->assert_str_equals("LOCAL",
                             $t->{prefs}->getPreferencesValue("SOURCE"));
    $t->finish();
}

sub test_local_to_site {
    my $this = shift;

    $this->_setSitePref("SOURCE", "GLOBAL");
    $this->_setSitePref("SOURCE", "LOCAL", "Local");

    my $t = new TWiki( $this->{test_user_login}, $topicquery );
    $this->assert_str_equals("GLOBAL",
                             $t->{prefs}->getPreferencesValue("SOURCE"));
    my($tw, $tt ) = $t->normalizeWebTopicName('',
                                            $TWiki::cfg{LocalSitePreferences});
    my $localquery = new Unit::Request( "" );
    $localquery->path_info("/$tw/$tt");
    $t->finish();
    $t = new TWiki( $this->{test_user_login}, $localquery );
    $this->assert_str_equals("LOCAL",
                             $t->{prefs}->getPreferencesValue("SOURCE"));
    $t->finish();
}

sub test_local_to_user {
    my $this = shift;

    $this->_setUserPref("SOURCE", "GLOBAL");
    $this->_setUserPref("SOURCE", "LOCAL", "Local");

    my $t = new TWiki( $this->{test_user_login}, $topicquery );
    $this->assert_str_equals("GLOBAL",
                             $t->{prefs}->getPreferencesValue("SOURCE"));

    my $localquery = new Unit::Request( "" );
    $localquery->path_info("/$TWiki::cfg{UsersWebName}/$this->{test_user_wikiname}");
    $t->finish();
    $t = new TWiki( $this->{test_user_login}, $localquery );
    $this->assert_str_equals("LOCAL",
                             $t->{prefs}->getPreferencesValue("SOURCE"));
    $t->finish();
}

sub test_local_to_web {
    my $this = shift;

    $this->_setWebPref("SOURCE", "GLOBAL");
    $this->_setWebPref("SOURCE", "LOCAL", "Local");

    my $t = new TWiki( $this->{test_user_login}, $topicquery );
    $this->assert_str_equals("GLOBAL",
                             $t->{prefs}->getPreferencesValue("SOURCE"));

    my $localquery = new Unit::Request( "" );
    $localquery->path_info("/$this->{test_web}/$TWiki::cfg{WebPrefsTopicName}");
    $t->finish();
    $t = new TWiki( $this->{test_user_login}, $localquery );
    $this->assert_str_equals("LOCAL",
                             $t->{prefs}->getPreferencesValue("SOURCE"));
    $t->finish();
}

sub test_whitespace {
    my $this = shift;

    $this->_setTopicPref("ONE", "   VAL \n  UE   ");
    $this->_setTopicPref("TWO", "   VAL\n   U\n   E");
    $this->_setTopicPref("THREE", "VAL\n   ");

    my $t = new TWiki( $this->{test_user_login}, $topicquery );
    $this->assert_str_equals("VAL ",
                             $t->{prefs}->getPreferencesValue("ONE"));
    $this->assert_str_equals("VAL\n   U\n   E",
                             $t->{prefs}->getPreferencesValue("TWO"));
    $this->assert_str_equals("VAL",
                             $t->{prefs}->getPreferencesValue("THREE"));
    $t->finish();
}

1;
