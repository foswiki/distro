# Copyright (C) 2004 Crawford Currie

package PrefsTests;
use v5.14;

use Foswiki();
use Foswiki::Prefs();
use Assert;
use Try::Tiny;

use Moo;
use namespace::clean;
extends qw( FoswikiFnTestCase );

around BUILDARGS => sub {
    my $orig = shift;
    $orig->( @_, testSuite => 'Prefs' );
};

my $testSysWeb = 'TemporaryTestPrefsSystemWeb';
my %topicAppParams;
my $original;

around set_up => sub {
    my $orig = shift;
    my $this = shift;

    $orig->( $this, @_ );

    my $cfgData = $this->app->cfg->data;

    $original = $cfgData->{SystemWebName};

    $cfgData->{SystemWebName}        = $testSysWeb;
    $cfgData->{LocalSitePreferences} = $this->users_web . ".SitePreferences";

    %topicAppParams = (
        requestParams => { initializer => '', },
        engineParams  => {
            initialAttributes => {
                path_info => "/" . $this->test_web . "/" . $this->test_topic,
                user      => $this->test_user_login,
            },
        },
    );

    try {
        my $webObject =
          $this->populateNewWeb( $cfgData->{SystemWebName}, $original );
        undef $webObject;
        my ($m) =
          Foswiki::Func::readTopic( $original, $cfgData->{SitePrefsTopicName} );
        $m->saveAs(
            web   => $cfgData->{SystemWebName},
            topic => $cfgData->{SitePrefsTopicName}
        );
    }
    catch {
        Foswiki::Exception::Fatal->rethrow($_);
    };

    #GROUPs are cached, so we need to go again
    $this->createNewFoswikiApp(%topicAppParams);
};

around tear_down => sub {
    my $orig = shift;
    my $this = shift;

    $this->removeWebFixture($testSysWeb);
    $orig->($this);
};

sub _set {
    my ( $this, $web, $topic, $pref, $val, $type ) = @_;
    $this->assert_not_null($web);
    $this->assert_not_null($topic);
    $this->assert_not_null($pref);
    $type ||= 'Set';

    my $user = $this->app->user;
    $this->assert_not_null($user);
    my ($topicObject) = Foswiki::Func::readTopic( $web, $topic );
    my $text = $topicObject->text() || '';
    $text =~ s/^\s*\* $type $pref =.*$//gm;
    $text .= "\n\t* $type $pref = $val\n";
    $topicObject->text($text);
    try {
        $topicObject->save();
    }
    catch {
        Foswiki::Exception::Fatal->rethrow($_);
    };

    return;
}

sub _setDefaultPref {
    my ( $this, $pref, $val, $type ) = @_;
    $this->_set( $testSysWeb, $this->app->cfg->data->{SitePrefsTopicName},
        $pref, $val, $type );

    return;
}

sub _setSitePref {
    my ( $this, $pref, $val, $type ) = @_;
    my ( $web, $topic ) =
      $this->app->request->normalizeWebTopicName( '',
        $this->app->cfg->data->{LocalSitePreferences} );
    $this->assert_str_equals( $web, $this->app->cfg->data->{UsersWebName} );
    $this->_set( $web, $topic, $pref, $val, $type );

    return;
}

sub _setWebPref {
    my ( $this, $pref, $val, $type ) = @_;
    $this->_set( $this->test_web, $this->app->cfg->data->{WebPrefsTopicName},
        $pref, $val, $type );

    return;
}

sub _setTopicPref {
    my ( $this, $pref, $val, $type ) = @_;
    $this->_set( $this->test_web, $this->test_topic, $pref, $val, $type );

    return;
}

sub _setUserPref {
    my ( $this, $pref, $val, $type ) = @_;
    $this->_set( $this->app->cfg->data->{UsersWebName},
        $this->test_user_wikiname, $pref, $val, $type );

    return;
}

sub test_system {
    my $this = shift;
    $this->_setDefaultPref( "SOURCE",           "DEFAULT" );
    $this->_setDefaultPref( "FINALPREFERENCES", "" );
    $this->_setSitePref( "FINALPREFERENCES", "" );
    $this->_setWebPref( "FINALPREFERENCES", "" );
    $this->_setUserPref( "FINALPREFERENCES", "" );

    my $t = $this->createNewFoswikiApp( user => $this->test_user_login );
    $this->assert_str_equals( "DEFAULT", $t->prefs->getPreference("SOURCE") );

    return;
}

sub test_local {
    my $this = shift;

    $this->_setDefaultPref( "SOURCE", "SITE" );

    $this->_setDefaultPref( "FINALPREFERENCES", "" );
    $this->_setSitePref( "FINALPREFERENCES", "" );
    $this->_setWebPref( "FINALPREFERENCES", "" );
    $this->_setUserPref( "FINALPREFERENCES", "" );

    my $t = $this->createNewFoswikiApp( user => $this->test_user_login );
    $this->assert_str_equals( "SITE", $t->prefs->getPreference("SOURCE") );

    return;
}

sub test_web_prefs {
    my $this = shift;

    $this->_setWebPref( "SOURCE", "WEB" );

    $this->_setDefaultPref( "FINALPREFERENCES", "" );
    $this->_setSitePref( "FINALPREFERENCES", "" );
    $this->_setWebPref( "FINALPREFERENCES", "" );
    $this->_setUserPref( "FINALPREFERENCES", "" );

    my $t = $this->createNewFoswikiApp(
        user => $this->test_user_login,
        %topicAppParams,
    );
    $this->assert_str_equals( "WEB", $t->prefs->getPreference("SOURCE") );

    return;
}

sub test_user {
    my $this = shift;

    $this->_setUserPref( "SOURCE", "USER" );

    $this->_setDefaultPref( "FINALPREFERENCES", "" );
    $this->_setSitePref( "FINALPREFERENCES", "" );
    $this->_setWebPref( "FINALPREFERENCES", "" );
    $this->_setUserPref( "FINALPREFERENCES", "" );

    my $t = $this->createNewFoswikiApp(
        user => $this->test_user_login,
        %topicAppParams,
    );
    $this->assert_str_equals( "USER", $t->prefs->getPreference("SOURCE") );

    return;
}

sub test_topic_prefs {
    my $this = shift;
    $this->_setTopicPref( "SOURCE", "TOPIC" );

    $this->_setDefaultPref( "FINALPREFERENCES", "" );
    $this->_setSitePref( "FINALPREFERENCES", "" );
    $this->_setWebPref( "FINALPREFERENCES", "" );
    $this->_setUserPref( "FINALPREFERENCES", "" );

    my $t = $this->createNewFoswikiApp(
        user => $this->test_user_login,
        %topicAppParams,
    );
    $this->assert_str_equals( "TOPIC", $t->prefs->getPreference("SOURCE") );

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
    my $t = $this->createNewFoswikiApp(
        user => $this->test_user_login,
        %topicAppParams,
    );
    $this->assert_str_equals( "TOPIC", $t->prefs->getPreference("SOURCE") );

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

    my $t = $this->createNewFoswikiApp(
        user => $this->test_user_login,
        %topicAppParams,
    );
    $this->assert_str_equals( "DEFAULT", $t->prefs->getPreference("SOURCE") );

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

    my $t = $this->createNewFoswikiApp(
        user => $this->test_user_login,
        %topicAppParams,
    );
    $this->assert_str_equals( "SITE", $t->prefs->getPreference("SOURCE") );

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

    my $t = $this->createNewFoswikiApp(
        user => $this->test_user_login,
        %topicAppParams,
    );
    $this->assert_str_equals( "WEB", $t->prefs->getPreference("SOURCE") );

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

    my $t = $this->createNewFoswikiApp( %topicAppParams, );
    $this->assert_str_equals( "USER", $t->prefs->getPreference("SOURCE") );

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

    my $t = $this->createNewFoswikiApp(
        user => $this->test_user_login,
        %topicAppParams,
    );
    $this->assert_str_equals( "WEB",
        $t->prefs->getPreference( "SOURCE", undef, 1 ) );

    return;
}

sub test_local_to_default {
    my $this = shift;

    $this->_setDefaultPref( "SOURCE", "GLOBAL" );
    $this->_setDefaultPref( "SOURCE", "LOCAL", "Local" );

    my $t = $this->createNewFoswikiApp(
        user => $this->test_user_login,
        %topicAppParams,
    );
    $this->assert_str_equals( "GLOBAL", $t->prefs->getPreference("SOURCE") );

    $t = $this->createNewFoswikiApp(
        requestParams => { initializer => '', },
        engineParams  => {
            initialAttributes => {
                path_info => "/$testSysWeb/"
                  . $this->app->cfg->data->{SitePrefsTopicName},
                user => $this->test_user_login,
            },
        }
    );
    $this->assert_str_equals( "LOCAL", $t->prefs->getPreference("SOURCE") );

    return;
}

sub test_local_to_site {
    my $this = shift;

    $this->_setSitePref( "SOURCE", "GLOBAL" );
    $this->_setSitePref( "SOURCE", "LOCAL", "Local" );

    my $t = $this->createNewFoswikiApp(
        user => $this->test_user_login,
        %topicAppParams,
    );
    $this->assert_str_equals( "GLOBAL", $t->prefs->getPreference("SOURCE") );
    my ( $tw, $tt ) =
      $t->request->normalizeWebTopicName( '',
        $this->app->cfg->data->{LocalSitePreferences} );

    $t = $this->createNewFoswikiApp(
        user          => $this->test_user_login,
        requestParams => { initializer => '', },
        engineParams  => { initialAttributes => { path_info => "/$tw/$tt", }, },
    );
    $this->assert_str_equals( "LOCAL", $t->prefs->getPreference("SOURCE") );

    return;
}

sub test_local_to_user {
    my $this = shift;

    $this->_setUserPref( "SOURCE", "GLOBAL" );
    $this->_setUserPref( "SOURCE", "LOCAL", "Local" );

    my $t = $this->createNewFoswikiApp(
        user => $this->test_user_login,
        %topicAppParams
    );
    $this->assert_str_equals( "GLOBAL", $t->prefs->getPreference("SOURCE") );

    $t = $this->createNewFoswikiApp(
        user          => $this->test_user_login,
        requestParams => { initializer => '', },
        engineParams  => {
            initialAttributes => {
                    path_info => "/"
                  . $this->app->cfg->data->{UsersWebName} . "/"
                  . $this->test_user_wikiname,
            },
        }
    );
    $this->assert_str_equals( "LOCAL", $t->prefs->getPreference("SOURCE") );

    return;
}

sub test_local_to_web {
    my $this = shift;

    $this->_setWebPref( "SOURCE", "GLOBAL" );
    $this->_setWebPref( "SOURCE", "LOCAL", "Local" );

    my $t = $this->createNewFoswikiApp(
        user => $this->test_user_login,
        %topicAppParams,
    );
    $this->assert_str_equals( "GLOBAL", $t->prefs->getPreference("SOURCE") );

    $t = $this->createNewFoswikiApp(
        user          => $this->test_user_login,
        requestParams => { initializer => '', },
        engineParams  => {
            initialAttributes => {
                    path_info => "/"
                  . $this->test_web . "/"
                  . $this->app->cfg->data->{WebPrefsTopicName},
            },
        }
    );
    $this->assert_str_equals( "LOCAL", $t->prefs->getPreference("SOURCE") );

    return;
}

sub test_whitespace {
    my $this = shift;

    $this->_setTopicPref( "ONE",   "   VAL \n  UE   " );
    $this->_setTopicPref( "TWO",   "   VAL\n   U\n   E" );
    $this->_setTopicPref( "THREE", "VAL\n   " );

    my $t = $this->createNewFoswikiApp(
        user => $this->test_user_login,
        %topicAppParams,
    );
    $this->assert_str_equals( "VAL ", $t->prefs->getPreference("ONE") );
    $this->assert_str_equals( "VAL\n   U\n   E",
        $t->prefs->getPreference("TWO") );
    $this->assert_str_equals( "VAL", $t->prefs->getPreference("THREE") );

    return;
}

1;
