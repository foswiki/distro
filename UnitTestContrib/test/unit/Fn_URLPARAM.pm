# tests for the correct expansion of URLPARAM
#
# Author: Koen Martens
#
package Fn_URLPARAM;
use base qw( FoswikiFnTestCase );

use strict;

sub new {
    my $self = shift()->SUPER::new( 'URLPARAM', @_ );
    return $self;
}

sub set_up {
    my $this = shift;
    $this->SUPER::set_up(@_);
}

sub test_default {
    my $this = shift;

    my $str;

    # test default parameter

    $str = $this->{test_topicObject}->expandMacros('%URLPARAM{"foo"}%');
    $this->assert_str_equals( '', "$str" );

    $str =
      $this->{test_topicObject}->expandMacros('%URLPARAM{"foo" default="0"}%');
    $this->assert_str_equals( '0', "$str" );

    $str =
      $this->{test_topicObject}->expandMacros('%URLPARAM{"foo" default=""}%');
    $this->assert_str_equals( '', "$str" );

    $str =
      $this->{test_topicObject}
      ->expandMacros('%URLPARAM{"foo" default="bar"}%');
    $this->assert_str_equals( 'bar', "$str" );

    $this->{request}->param( -name => 'foo', -value => 'bar' );
    $str =
      $this->{test_topicObject}->expandMacros('%URLPARAM{"foo" default="0"}%');
    $this->assert_str_equals( 'bar', "$str" );

    $this->{request}->param( -name => 'foo', -value => '0' );
    $str =
      $this->{test_topicObject}
      ->expandMacros('%URLPARAM{"foo" default="bar"}%');
    $this->assert_str_equals( '0', "$str" );

    $this->{request}->param( -name => 'foo', -value => '' );
    $str =
      $this->{test_topicObject}
      ->expandMacros('%URLPARAM{"foo" default="bar"}%');
    $this->assert_str_equals( '', "$str" );

    $this->{request}->param( -name => 'foo', -value => '<evil script>\'\"%' );
    $str =
      $this->{test_topicObject}
      ->expandMacros('%URLPARAM{"foo" default="bar"}%');
    $this->assert_str_equals( '&#60;evil script&#62;&#39;\&#34;&#37;', "$str" );
}

sub test_encode {
    my $this = shift;

    my $str;

    $this->{request}->param( -name => 'foo', -value => '<>\'%&?*!"' );
    $str =
      $this->{test_topicObject}
      ->expandMacros('%URLPARAM{"foo" encode="entity"}%');
    $this->assert_str_equals( '&#60;&#62;&#39;&#37;&#38;?&#42;!&#34;', "$str" );

    $this->{request}->param( -name => 'foo', -value => '&?*!" ' );
    $str =
      $this->{test_topicObject}->expandMacros('%URLPARAM{"foo" encode="url"}%');
    $this->assert_str_equals( '%26%3f*!%22%20', "$str" );

    $this->{request}->param( -name => 'foo', -value => '&?*!" ' );
    $str =
      $this->{test_topicObject}
      ->expandMacros('%URLPARAM{"foo" encode="quote"}%');
    $this->assert_str_equals( '&?*!\" ', "$str" );

    $this->{request}->param( -name => 'foo', -value => '<evil script>\'\"%' );
    $str =
      $this->{test_topicObject}
      ->expandMacros('%URLPARAM{"foo" default="bar" encode="safe"}%');
    $this->assert_str_equals( '&#60;evil script&#62;&#39;\&#34;&#37;', "$str" );

    $this->{request}->param( -name => 'foo', -value => '<evil script>\'\"%' );
    $str =
      $this->{test_topicObject}
      ->expandMacros('%URLPARAM{"foo" default="bar" encode="off"}%');
    $this->assert_str_equals( '<evil script>\'\"%', "$str" );

    $this->{request}->param( -name => 'foo', -value => '<evil script>\'\"%' );
    $str =
      $this->{test_topicObject}
      ->expandMacros('%URLPARAM{"foo" default="bar" encode="none"}%');
    $this->assert_str_equals( '<evil script>\'\"%', "$str" );
}

sub test_defaultencode {
    my $this = shift;

    my $str;

    $str =
      $this->{test_topicObject}
      ->expandMacros('%URLPARAM{"foo" default="&?*!\" " encode="entity"}%');
    $this->assert_str_equals( '&?*!" ', "$str" );

    $str =
      $this->{test_topicObject}
      ->expandMacros('%URLPARAM{"foo" default="&?*!\" " encode="url"}%');
    $this->assert_str_equals( '&?*!" ', "$str" );

    $str =
      $this->{test_topicObject}
      ->expandMacros('%URLPARAM{"foo" default="&?*!\" " encode="quote"}%');
    $this->assert_str_equals( '&?*!" ', "$str" );
}

sub test_multiple {
    my $this = shift;

    my $str;

    my @multiple = ( 'foo', 'bar', 'baz' );

    $this->{request}
      ->param( -name => 'multi', -value => [ 'foo', 'bar', 'baz' ] );
    $str =
      $this->{test_topicObject}
      ->expandMacros('%URLPARAM{"multi" multiple="on"}%');
    $this->assert_str_equals( "foo\nbar\nbaz", "$str" );

    $this->{request}
      ->param( -name => 'multi', -value => [ 'foo', 'bar', 'baz' ] );
    $str =
      $this->{test_topicObject}
      ->expandMacros('%URLPARAM{"multi" multiple="on" separator=","}%');
    $this->assert_str_equals( "foo,bar,baz", "$str" );

    $this->{request}
      ->param( -name => 'multi', -value => [ 'foo', 'bar', 'baz' ] );
    $str =
      $this->{test_topicObject}
      ->expandMacros('%URLPARAM{"multi" multiple="on" separator=""}%');
    $this->assert_str_equals( "foobarbaz", "$str" );

    $this->{request}
      ->param( -name => 'multi', -value => [ 'foo', 'bar', 'baz' ] );
    $str =
      $this->{test_topicObject}
      ->expandMacros('%URLPARAM{"multi" multiple="-$item-" separator=" "}%');
    $this->assert_str_equals( "-foo- -bar- -baz-", "$str" );

    $this->{request}
      ->param( -name => 'multi', -value => [ 'foo', 'bar', 'baz' ] );
    $str =
      $this->{test_topicObject}
      ->expandMacros('%URLPARAM{"multi" multiple="-$item-" separator=""}%');
    $this->assert_str_equals( "-foo--bar--baz-", "$str" );

    $this->{request}
      ->param( -name => 'multi', -value => [ 'foo', 'bar', 'baz' ] );
    $str =
      $this->{test_topicObject}
      ->expandMacros('%URLPARAM{"multi" multiple="-$item-"}%');
    $this->assert_str_equals( "-foo-\n-bar-\n-baz-", "$str" );
}

sub test_newline {
    my $this = shift;

    my $str;

    $this->{request}->param( -name => 'textarea', -value => "foo\nbar\nbaz\n" );
    $str =
      $this->{test_topicObject}
      ->expandMacros('%URLPARAM{"textarea" newline="-"}%');
    $this->assert_str_equals( "foo-bar-baz-", "$str" );

    $this->{request}->param( -name => 'textarea', -value => "foo\nbar\nbaz\n" );
    $str =
      $this->{test_topicObject}
      ->expandMacros('%URLPARAM{"textarea" newline=""}%');
    $this->assert_str_equals( "foobarbaz", "$str" );
}

1;
