# tests for the correct expansion of URLPARAM
#
# Author: Koen Martens
#
package Fn_URLPARAM;
use base qw( FoswikiFnTestCase );

use strict;

sub new {
    my $self = shift()->SUPER::new('URLPARAM', @_);
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

    $str = $this->{twiki}->handleCommonTags(
        '%URLPARAM{"foo"}%', $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals('', "$str");

    $str = $this->{twiki}->handleCommonTags(
        '%URLPARAM{"foo" default="0"}%', $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals('0', "$str");

    $str = $this->{twiki}->handleCommonTags(
        '%URLPARAM{"foo" default=""}%', $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals('', "$str");

    $str = $this->{twiki}->handleCommonTags(
        '%URLPARAM{"foo" default="bar"}%', $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals('bar', "$str");

    $this->{request}->param( -name=>'foo', -value=>'bar');
    $str = $this->{twiki}->handleCommonTags(
        '%URLPARAM{"foo" default="0"}%', $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals('bar', "$str");

    $this->{request}->param( -name=>'foo', -value=>'0');
    $str = $this->{twiki}->handleCommonTags(
        '%URLPARAM{"foo" default="bar"}%', $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals('0', "$str");

    $this->{request}->param( -name=>'foo', -value=>'');
    $str = $this->{twiki}->handleCommonTags(
        '%URLPARAM{"foo" default="bar"}%', $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals('', "$str");
}

sub test_encode {
    my $this = shift;

    my $str;

    $this->{request}->param( -name=>'foo', -value=>'&?*!"');
    $str = $this->{twiki}->handleCommonTags(
        '%URLPARAM{"foo" encode="entity"}%', $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals('&#38;?&#42;!&#34;', "$str");

    $this->{request}->param( -name=>'foo', -value=>'&?*!" ');
    $str = $this->{twiki}->handleCommonTags(
        '%URLPARAM{"foo" encode="url"}%', $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals('%26%3f*!%22%20', "$str");

    $this->{request}->param( -name=>'foo', -value=>'&?*!" ');
    $str = $this->{twiki}->handleCommonTags(
        '%URLPARAM{"foo" encode="quote"}%', $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals('&?*!\" ', "$str");
}

sub test_defaultencode {
    my $this = shift;

    my $str;

    $str = $this->{twiki}->handleCommonTags(
        '%URLPARAM{"foo" default="&?*!\" " encode="entity"}%', $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals('&?*!" ', "$str");

    $str = $this->{twiki}->handleCommonTags(
        '%URLPARAM{"foo" default="&?*!\" " encode="url"}%', $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals('&?*!" ', "$str");

    $str = $this->{twiki}->handleCommonTags(
        '%URLPARAM{"foo" default="&?*!\" " encode="quote"}%', $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals('&?*!" ', "$str");
}

sub test_multiple {
    my $this = shift;

    my $str;

    my @multiple=('foo','bar','baz');

    $this->{request}->param( -name=>'multi', -value=>['foo','bar','baz']);
    $str = $this->{twiki}->handleCommonTags(
        '%URLPARAM{"multi" multiple="on"}%', $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals("foo\nbar\nbaz", "$str");

    $this->{request}->param( -name=>'multi', -value=>['foo','bar','baz']);
    $str = $this->{twiki}->handleCommonTags(
        '%URLPARAM{"multi" multiple="on" separator=","}%', $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals("foo,bar,baz", "$str");

    $this->{request}->param( -name=>'multi', -value=>['foo','bar','baz']);
    $str = $this->{twiki}->handleCommonTags(
        '%URLPARAM{"multi" multiple="on" separator=""}%', $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals("foobarbaz", "$str");

    $this->{request}->param( -name=>'multi', -value=>['foo','bar','baz']);
    $str = $this->{twiki}->handleCommonTags(
        '%URLPARAM{"multi" multiple="-$item-" separator=" "}%', $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals("-foo- -bar- -baz-", "$str");

    $this->{request}->param( -name=>'multi', -value=>['foo','bar','baz']);
    $str = $this->{twiki}->handleCommonTags(
        '%URLPARAM{"multi" multiple="-$item-" separator=""}%', $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals("-foo--bar--baz-", "$str");

    $this->{request}->param( -name=>'multi', -value=>['foo','bar','baz']);
    $str = $this->{twiki}->handleCommonTags(
        '%URLPARAM{"multi" multiple="-$item-"}%', $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals("-foo-\n-bar-\n-baz-", "$str");
}

sub test_newline {
    my $this = shift;

    my $str;

    $this->{request}->param( -name=>'textarea', -value=>"foo\nbar\nbaz\n");
    $str = $this->{twiki}->handleCommonTags(
        '%URLPARAM{"textarea" newline="-"}%', $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals("foo-bar-baz-", "$str");

    $this->{request}->param( -name=>'textarea', -value=>"foo\nbar\nbaz\n");
    $str = $this->{twiki}->handleCommonTags(
        '%URLPARAM{"textarea" newline=""}%', $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals("foobarbaz", "$str");
}

1;
