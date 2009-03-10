# tests for the correct expansion of ENCODE
#
#
package Fn_ENCODE;
use base qw( FoswikiFnTestCase );

use strict;

sub new {
    my $self = shift()->SUPER::new( 'ENCODE', @_ );
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
    $str =
      $this->{test_topicObject}->expandMacros('%ENCODE{"<evil script>\'\"%"}%');
    $this->assert_str_equals( '%3cevil%20script%3e\'%22%25', "$str" );
}

sub test_encode {
    my $this = shift;

    my $str;

    $this->{request}
      ->param( -name => 'foo', -value => "<evil script>\n&\'\"%*A" );
    $str =
      $this->{test_topicObject}
      ->expandMacros("%ENCODE{\"<evil script>\n&\'\\\"%*A\" type=\"entity\"}%");
    $this->assert_str_equals(
        "&#60;evil script&#62;\n&#38;&#39;&#34;&#37;&#42;A", "$str" );

    $this->{request}
      ->param( -name => 'foo', -value => "<evil script>\n&\'\"%*A" );
    $str =
      $this->{test_topicObject}
      ->expandMacros("%ENCODE{\"<evil script>\n&\'\\\"%*A\" type=\"safe\"}%");
    $this->assert_str_equals( "&#60;evil script&#62;\n&&#39;&#34;&#37;*A",
        "$str" );

    $this->{request}
      ->param( -name => 'foo', -value => "<evil script>\n&\'\"%*A" );
    $str =
      $this->{test_topicObject}
      ->expandMacros("%ENCODE{\"<evil script>\n&\'\\\"%*A\" type=\"html\"}%");
    $this->assert_str_equals(
        "&#60;evil script&#62;&#10;&#38;&#39;&#34;&#37;&#42;A", "$str" );

    $this->{request}
      ->param( -name => 'foo', -value => "<evil script>\n&\'\"%*A" );
    $str =
      $this->{test_topicObject}
      ->expandMacros("%ENCODE{\"<evil script>\n&\'\\\"%*A\" type=\"quotes\"}%");
    $this->assert_str_equals( "<evil script>\n&\'\\\"%*A", "$str" );

    $this->{request}
      ->param( -name => 'foo', -value => "<evil script>\n&\'\"%*A" );
    $str =
      $this->{test_topicObject}
      ->expandMacros("%ENCODE{\"<evil script>\n&\'\\\"%*A\" type=\"url\"}%");
    $this->assert_str_equals( "%3cevil%20script%3e%3cbr%20/%3e%26'%22%25*A",
        "$str" );

    #http://trunk.foswiki.org/Tasks/Item5453
    #unfortuanatly, perl considers the string '0' to be
    #equivalent to 0 which is equivalent to false
    #making it impossible to have a %ENCODE{"0"}%
    #task:5453 suggests that the following test should fail.
    #see also AttrsTests::test_zero
    $str =
      $this->{test_topicObject}->expandMacros("%ENCODE{\"0\" type=\"url\"}%");
    $this->assert_str_equals( "0", "$str" );
    $str =
      $this->{test_topicObject}->expandMacros("%ENCODE{\"\" type=\"url\"}%");
    $this->assert_str_equals( "", "$str" );

}

1;
