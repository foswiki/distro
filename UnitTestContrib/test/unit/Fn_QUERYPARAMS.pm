# tests for the correct expansion of QUERYPARAMS
#
#
package Fn_QUERYPARAMS;

use strict;
use warnings;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

sub new {
    my $self = shift()->SUPER::new( 'QUERYPARAMS', @_ );
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

    $str = $this->{test_topicObject}->expandMacros('%QUERYPARAMS%');
    $this->assert_str_equals( '', "$str" );

    $this->{request}->param( -name => 'foo', -value => '<evil script>\'"%' );
    $str = $this->{test_topicObject}->expandMacros('%QUERYPARAMS%');
    $this->assert_str_equals( 'foo=&#60;evil script&#62;&#39;&#34;&#37;',
        "$str" );

    $this->{request}->param( -name => 'foo', -value => '<evil script>\'"%' );
    $this->{request}->param( -name => 'fee', -value => 'free' );
    $str = $this->{test_topicObject}->expandMacros('%QUERYPARAMS%');
    $this->assert_str_equals(
        "foo=&#60;evil script&#62;&#39;&#34;&#37;\nfee=free", "$str" );
}

sub test_multi {
    my $this = shift;

    my $str;

    # test multiple parameters

    $str = $this->{test_topicObject}->expandMacros('%QUERYPARAMS%');
    $this->assert_str_equals( '', "$str" );

    $this->{request}->param( -name => 'foo', -value => ( 'beer', 'free' ) );
    $str = $this->{test_topicObject}->expandMacros('%QUERYPARAMS%');
    $this->assert_matches( qr/foo=free/, "$str" );
    $this->assert_matches( qr/foo=beer/, "$str" );
    $this->assert_equals( length($str), 17 );

    $this->{request}->param( -name => 'foo', -value => ( 'beer', 'beer' ) );
    $str = $this->{test_topicObject}->expandMacros('%QUERYPARAMS%');
    $this->assert_matches( qr/^foo=beer\nfoo=beer$/, "$str" );
}

sub test_encode {
    my $this = shift;

    my $str;

    $this->{request}
      ->param( -name => 'foo', -value => "<evil script>\n&\'\"%*A" );
    $this->{request}->param( -name => 'fee', -value => 'free' );
    $str =
      $this->{test_topicObject}
      ->expandMacros('%QUERYPARAMS{encoding="entity"}%');
    $this->assert_str_equals(
        "foo=&#60;evil script&#62;\n&#38;&#39;&#34;&#37;&#42;A\nfee=free",
        "$str" );

    $this->{request}
      ->param( -name => 'foo', -value => "<evil script>\n&\'\"%*A" );
    $this->{request}->param( -name => 'fee', -value => 'free' );
    $str =
      $this->{test_topicObject}->expandMacros('%QUERYPARAMS{encoding="safe"}%');
    $this->assert_str_equals(
        "foo=&#60;evil script&#62;\n&&#39;&#34;&#37;*A\nfee=free", "$str" );

    $this->{request}
      ->param( -name => 'foo', -value => "<evil script>\n&\'\"%*A" );
    $this->{request}->param( -name => 'fee', -value => 'free' );
    $str =
      $this->{test_topicObject}->expandMacros('%QUERYPARAMS{encoding="html"}%');
    $this->assert_str_equals(
        "foo=&#60;evil script&#62;&#10;&#38;&#39;&#34;&#37;&#42;A\nfee=free",
        "$str" );

    $this->{request}
      ->param( -name => 'foo', -value => "<evil script>\n&\'\"%*A" );
    $this->{request}->param( -name => 'fee', -value => 'free' );
    $str =
      $this->{test_topicObject}
      ->expandMacros('%QUERYPARAMS{encoding="quotes"}%');
    $this->assert_str_equals( "foo=<evil script>\n&\'\\\"%*A\nfee=free",
        "$str" );

    $this->{request}
      ->param( -name => 'foo', -value => "<evil script>\n&\'\"%*A" );
    $this->{request}->param( -name => 'fee', -value => 'free' );
    $str =
      $this->{test_topicObject}->expandMacros('%QUERYPARAMS{encoding="url"}%');
    $this->assert_str_equals(
        "foo=%3cevil%20script%3e%0a%26%27%22%25*A\nfee=free", "$str" );
}

sub test_format {
    my $this = shift;

    my $str;

    $this->{request}->param( -name => 'foo', -value => '<evil script>\'"%' );
    $this->{request}->param( -name => 'fee', -value => 'free' );
    $str =
      $this->{test_topicObject}
      ->expandMacros('%QUERYPARAMS{format="$name is equal to $value"}%');
    $this->assert_str_equals(
"foo is equal to &#60;evil script&#62;&#39;&#34;&#37;\nfee is equal to free",
        "$str"
    );

}

sub test_no_format_no_separator {
    my $this = shift;

    my $str;

    $this->{request}->param( -name => 'foo', -value => '<evil script>\'"%' );
    $this->{request}->param( -name => 'fee', -value => 'free' );
    $str = $this->{test_topicObject}->expandMacros('%QUERYPARAMS{}%');
    $this->assert_str_equals(
        "foo=&#60;evil script&#62;&#39;&#34;&#37;\nfee=free", "$str" );
}

sub test_no_format_with_separator {
    my $this = shift;

    my $str;

    $this->{request}->param( -name => 'foo', -value => '<evil script>\'"%' );
    $this->{request}->param( -name => 'fee', -value => 'free' );
    $str =
      $this->{test_topicObject}
      ->expandMacros('%QUERYPARAMS{separator="NEXT"}%');
    $this->assert_str_equals(
        "foo=&#60;evil script&#62;&#39;&#34;&#37;NEXTfee=free", "$str" );
}

sub test_no_format_empty_separator {
    my $this = shift;

    my $str;

    $this->{request}->param( -name => 'foo', -value => '<evil script>\'"%' );
    $this->{request}->param( -name => 'fee', -value => 'free' );
    $str =
      $this->{test_topicObject}->expandMacros('%QUERYPARAMS{separator=""}%');
    $this->assert_str_equals(
        "foo=&#60;evil script&#62;&#39;&#34;&#37;fee=free", "$str" );
}

sub test_with_format_no_separator {
    my $this = shift;

    my $str;

    $this->{request}->param( -name => 'foo', -value => '<evil script>\'"%' );
    $this->{request}->param( -name => 'fee', -value => 'free' );
    $str =
      $this->{test_topicObject}
      ->expandMacros('%QUERYPARAMS{format="$name is equal to $value"}%');
    $this->assert_str_equals(
"foo is equal to &#60;evil script&#62;&#39;&#34;&#37;\nfee is equal to free",
        "$str"
    );
}

sub test_with_format_with_separator {
    my $this = shift;

    my $str;

    $this->{request}->param( -name => 'foo', -value => '<evil script>\'"%' );
    $this->{request}->param( -name => 'fee', -value => 'free' );
    $str =
      $this->{test_topicObject}->expandMacros(
        '%QUERYPARAMS{format="$name is equal to $value" separator="NEXT"}%');
    $this->assert_str_equals(
"foo is equal to &#60;evil script&#62;&#39;&#34;&#37;NEXTfee is equal to free",
        "$str"
    );
}

sub test_with_format_empty_separator {
    my $this = shift;

    my $str;

    $this->{request}->param( -name => 'foo', -value => '<evil script>\'"%' );
    $this->{request}->param( -name => 'fee', -value => 'free' );
    $str =
      $this->{test_topicObject}->expandMacros(
        '%QUERYPARAMS{format="$name is equal to $value" separator=""}%');
    $this->assert_str_equals(
"foo is equal to &#60;evil script&#62;&#39;&#34;&#37;fee is equal to free",
        "$str"
    );
}

sub test_stdescapes_not_expanded {
    my $this = shift;

    my $str;

    $this->{request}->param( -name => 'percent', -value => '$percnt' );
    $this->{request}->param( -name => 'dollar',  -value => '$dollar' );
    $str =
      $this->{test_topicObject}->expandMacros(
'%QUERYPARAMS{format="$dollarname $name is equal to $dollarvalue $value" separator="$n"}%'
      );
    my $expected = <<'FOO';
$name percent is equal to $value $percnt
$name dollar is equal to $value $dollar
FOO
    chomp $expected;
    $this->assert_str_equals( $expected, "$str" );

}

1;
