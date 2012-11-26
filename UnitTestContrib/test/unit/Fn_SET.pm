# tests for the correct expansion of SET

package Fn_SET;
use strict;
use warnings;

use FoswikiFnTestCase();
our @ISA = qw( FoswikiFnTestCase );

use File::Path();
use Assert;
use Foswiki();
use Foswiki::Func();
use Error qw( :try );

my $test_tmpls;
my $tmpls;

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();

    $this->{tempdir} = $Foswiki::cfg{TempfileDir} . '/test_TemplateTests';
    File::Path::mkpath( $this->{tempdir} );

    my $here = $this->{tempdir};
    $here =~ m/^(.*)$/;
    $test_tmpls = $1 . '/fake_templates';

    File::Path::mkpath($test_tmpls);

    $this->createNewFoswikiSession();
    $tmpls = $this->{session}->templates;

    $Foswiki::cfg{TemplateDir} = $test_tmpls;
    $Foswiki::cfg{TemplatePath} =
'$Foswiki::cfg{PubDir}/$web/$name.$skin.tmpl,$Foswiki::cfg{TemplateDir}/$web/$name.$skin.tmpl,$Foswiki::cfg{TemplateDir}/$name.$skin.tmpl,$Foswiki::cfg{TemplateDir}/$web/$name.tmpl,$Foswiki::cfg{TemplateDir}/$name.tmpl,$web.$skinSkin$nameTemplate,$Foswiki::cfg{SystemWebName}.$skinSkin$nameTemplate,$web.$nameTemplate,$Foswiki::cfg{SystemWebName}.$nameTemplate';
    $Foswiki::cfg{TemplatePath} =~
      s/\$Foswiki::cfg{TemplateDir}/$Foswiki::cfg{TemplateDir}/geo;
    $Foswiki::cfg{TemplatePath} =~
      s/\$Foswiki::cfg{SystemWebName}/$Foswiki::cfg{SystemWebName}/geo;

    return;
}

sub tear_down {
    my $this = shift;
    $this->SUPER::tear_down();
    File::Path::rmtree( $this->{tempdir} );    # Cleanup any old tests

    return;
}

sub write_template {
    my ( $tmpl, $content ) = @_;

    $content ||= $tmpl;
    if ( $tmpl =~ m!^(.*)/[^/]*$! ) {
        File::Path::mkpath("$test_tmpls/$1") unless -d "$test_tmpls/$1";
    }
    ASSERT( open( my $F, '>', "$test_tmpls/$tmpl.tmpl" ) );
    print $F $content;
    ASSERT( close($F) );

    return;
}

sub test_SET_basic_use {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros('%SET{"foo" value="bar"}%%foo%');

    $this->assert_str_equals( "bar", $result );
}

sub test_SET_use_before_set {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros('%foo%%SET{"foo" value="bar"}%');

    $this->assert_str_equals( "bar", $result );
}

sub test_SET_use_order {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
        '%foo%%SET{"foo" value="bar1"}%%foo%%SET{"foo" value="bar2"}%%foo%');

    $this->assert_str_equals( "bar2bar1bar2", $result );
}

sub test_SET_defined {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
        '%IF{"defined foo" then="FAIL" else="SUCCESS"}%%SET{"foo" value="bar"}%'
      );

    $this->assert_str_equals( "SUCCESS", $result );
}

sub test_SET_defined2 {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
        '%SET{"foo" value="bar"}%%IF{"defined foo" then="SUCCESS" else="FAIL"}%'
      );

    $this->assert_str_equals( "SUCCESS", $result );
}

sub test_SET_defined3 {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
        '%SET{"foo" value=""}%%IF{"defined foo" then="SUCCESS" else="FAIL"}%');

    $this->assert_str_equals( "SUCCESS", $result );
}

sub test_SET_empty {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
        '%IF{"isempty foo" then="SUCCESS" else="FAIL"}%%SET{"foo" value="bar"}%'
      );

    $this->assert_str_equals( "SUCCESS", $result );
}

sub test_SET_empty1 {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
        '%SET{"foo" value=""}%%IF{"isempty foo" then="SUCCESS" else="FAIL"}%');

    $this->assert_str_equals( "SUCCESS", $result );
}

sub test_SET_empty2 {
    my $this = shift;

    my $result =
      $this->{test_topicObject}->expandMacros(
        '%SET{"foo" value="bar"}%%IF{"isempty foo" then="FAIL" else="SUCCESS"}%'
      );

    $this->assert_str_equals( "SUCCESS", $result );
}

sub test_SET_topic_context {
    my $this = shift;

    $this->{session}{prefs}
      ->pushTopicContext( $this->{test_web}, $this->{test_topic} );
    my $result =
      $this->{test_topicObject}->expandMacros('%SET{"foo" value="bar"}%');

    $this->assert_str_equals( "", $result );

    $this->{session}{prefs}->popTopicContext();

    $result =
      $this->{test_topicObject}
      ->expandMacros('%IF{"defined foo" then="FAIL" else="SUCCESS"}%');

    $this->assert_str_equals( "SUCCESS", $result );
}

sub test_SET_INCLUDE {
    my $this = shift;

    my ( $meta, $text ) =
      Foswiki::Func::readTopic( $this->{test_web}, 'SomeTopic' );
    $meta->text('hi%SET{"foo" value="bar"}%there');
    $meta->save();

    my $result =
      $this->{test_topicObject}->expandMacros(
        '%foo%%INCLUDE{"' . $this->{test_web} . '.SomeTopic"}%%foo%' );

    $this->assert_str_equals( '%foo%hithere%foo%', $result );
}

sub test_SET_in_TMPL_DEF {
    my $this = shift;

    write_template( 'setter',
        '%TMPL:DEF{"setter"}%%SET{"foo" value="bar"}%%TMPL:END%' );

    my $data   = $tmpls->readTemplate('setter');
    my $result = $this->{test_topicObject}->expandMacros('%foo%');

    # not yet
    $this->assert_str_equals( '%foo%', $result );

    $data = $tmpls->expandTemplate('setter');

    # not yet
    $this->assert_str_equals( '%foo%', $result );

    # exec the setter now
    $this->{test_topicObject}->expandMacros($data);

    # ... and
    $result = $this->{test_topicObject}->expandMacros('%foo%');

    # now it is set
    $this->assert_str_equals( 'bar', $result );
}

sub test_SET_ACL {
    my $this = shift;

    my ( $meta, $text ) =
      Foswiki::Func::readTopic( $this->{test_web}, 'SomeTopic' );

    $meta->text(<<'TML');
      $this->{test_topicObject}->expandMacros(<<TML);
%SET{"ALLOWTOPICVIEW" value="NotherUSer"}%
TML
    $meta->save();

    $this->assert(
        Foswiki::Func::checkAccessPermission(
            'VIEW', 'NotherUser', '', 'SomeTopic', $this->{test_web}
        )
    );

}

sub test_SET_finalized_var {
    my $this = shift;

    my $result =
      $this->{test_topicObject}
      ->expandMacros('%SET{"TOPIC" value="woops"}%%TOPIC%');

    $this->assert_str_equals( $this->{test_topic}, $result );
}

1;
