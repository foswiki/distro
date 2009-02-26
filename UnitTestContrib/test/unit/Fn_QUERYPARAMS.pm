# tests for the correct expansion of QUERYPARAMS
#
#
package Fn_QUERYPARAMS;
use base qw( FoswikiFnTestCase );

use strict;

sub new {
    my $self = shift()->SUPER::new('QUERYPARAMS', @_);
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
        '%QUERYPARAMS%', $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals('', "$str");
    
    $this->{request}->param( -name=>'foo', -value=>'<evil script>\'"%');
    $str = $this->{twiki}->handleCommonTags(
        '%QUERYPARAMS%', $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals('foo=&#60;evil script&#62;&#39;&#34;&#37;', "$str");
    
    $this->{request}->param( -name=>'foo', -value=>'<evil script>\'"%');
    $this->{request}->param( -name=>'fee', -value=>'free');
    $str = $this->{twiki}->handleCommonTags(
        '%QUERYPARAMS%', $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals("foo=&#60;evil script&#62;&#39;&#34;&#37;\nfee=free", "$str");
}

sub test_encode {
    my $this = shift;

    my $str;
    
    $this->{request}->param( -name=>'foo', -value=>"<evil script>\n&\'\"%*A");
    $this->{request}->param( -name=>'fee', -value=>'free');
    $str = $this->{twiki}->handleCommonTags(
        '%QUERYPARAMS{encoding="entity"}%', $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals("foo=&#60;evil script&#62;\n&#38;&#39;&#34;&#37;&#42;A\nfee=free", "$str");
    
    $this->{request}->param( -name=>'foo', -value=>"<evil script>\n&\'\"%*A");
    $this->{request}->param( -name=>'fee', -value=>'free');
    $str = $this->{twiki}->handleCommonTags(
        '%QUERYPARAMS{encoding="safe"}%', $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals("foo=&#60;evil script&#62;\n&&#39;&#34;&#37;*A\nfee=free", "$str");

    $this->{request}->param( -name=>'foo', -value=>"<evil script>\n&\'\"%*A");
    $this->{request}->param( -name=>'fee', -value=>'free');
    $str = $this->{twiki}->handleCommonTags(
        '%QUERYPARAMS{encoding="html"}%', $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals("foo=&#60;evil script&#62;&#10;&#38;&#39;&#34;&#37;&#42;A\nfee=free", "$str");    

    $this->{request}->param( -name=>'foo', -value=>"<evil script>\n&\'\"%*A");
    $this->{request}->param( -name=>'fee', -value=>'free');
    $str = $this->{twiki}->handleCommonTags(
        '%QUERYPARAMS{encoding="quotes"}%', $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals("foo=<evil script>\n&\'\\\"%*A\nfee=free", "$str");

    $this->{request}->param( -name=>'foo', -value=>"<evil script>\n&\'\"%*A");
    $this->{request}->param( -name=>'fee', -value=>'free');
    $str = $this->{twiki}->handleCommonTags(
        '%QUERYPARAMS{encoding="url"}%', $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals("foo=%3cevil%20script%3e%3cbr%20/%3e%26'%22%25*A\nfee=free", "$str");
}

sub test_format {
    my $this = shift;

    my $str;

    $this->{request}->param( -name=>'foo', -value=>'<evil script>\'"%');
    $this->{request}->param( -name=>'fee', -value=>'free');
    $str = $this->{twiki}->handleCommonTags(
        '%QUERYPARAMS{format="$name is equal to $value"}%', $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals("foo is equal to &#60;evil script&#62;&#39;&#34;&#37;\nfee is equal to free", "$str");

}

sub test_seperator {
    my $this = shift;

    my $str;

    $this->{request}->param( -name=>'foo', -value=>'<evil script>\'"%');
    $this->{request}->param( -name=>'fee', -value=>'free');
    $str = $this->{twiki}->handleCommonTags(
        '%QUERYPARAMS{format="$name is equal to $value" separator="NEXT"}%', $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals("foo is equal to &#60;evil script&#62;&#39;&#34;&#37;NEXTfee is equal to free", "$str");
}

1;
