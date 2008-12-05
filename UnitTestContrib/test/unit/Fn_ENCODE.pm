# tests for the correct expansion of ENCODE
#
#
package Fn_ENCODE;
use base qw( FoswikiFnTestCase );

use strict;

sub new {
    my $self = shift()->SUPER::new('ENCODE', @_);
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
        '%ENCODE{"<evil script>\'\"%"}%', $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals('%3cevil%20script%3e\'%22%25', "$str");
}

sub test_encode {
    my $this = shift;

    my $str;
    
    $this->{request}->param( -name=>'foo', -value=>"<evil script>\n&\'\"%*A");
    $str = $this->{twiki}->handleCommonTags(
        "%ENCODE{\"<evil script>\n&\'\\\"%*A\" type=\"entity\"}%", $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals("&#60;evil script&#62;\n&#38;&#39;&#34;&#37;&#42;A", "$str");
    
    $this->{request}->param( -name=>'foo', -value=>"<evil script>\n&\'\"%*A");
    $str = $this->{twiki}->handleCommonTags(
        "%ENCODE{\"<evil script>\n&\'\\\"%*A\" type=\"safe\"}%", $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals("&#60;evil script&#62;\n&&#39;&#34;&#37;*A", "$str");

    $this->{request}->param( -name=>'foo', -value=>"<evil script>\n&\'\"%*A");
    $str = $this->{twiki}->handleCommonTags(
        "%ENCODE{\"<evil script>\n&\'\\\"%*A\" type=\"html\"}%", $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals("&#60;evil script&#62;&#10;&#38;&#39;&#34;&#37;&#42;A", "$str");    

    $this->{request}->param( -name=>'foo', -value=>"<evil script>\n&\'\"%*A");
    $str = $this->{twiki}->handleCommonTags(
        "%ENCODE{\"<evil script>\n&\'\\\"%*A\" type=\"quotes\"}%", $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals("<evil script>\n&\'\\\"%*A", "$str");

    $this->{request}->param( -name=>'foo', -value=>"<evil script>\n&\'\"%*A");
    $str = $this->{twiki}->handleCommonTags(
        "%ENCODE{\"<evil script>\n&\'\\\"%*A\" type=\"url\"}%", $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals("%3cevil%20script%3e%3cbr%20/%3e%26'%22%25*A", "$str");
}

1;
