# tests for the correct expansion of ENCODE
#
#
package Fn_ENCODE;
use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

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
    $this->assert_str_equals( "%3cevil%20script%3e%0a%26\'%22%25*A", "$str" );

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

sub test_old_new_1 {
    my $this = shift;
    my $in   = <<'THIS';
%ENCODE{"| One |
| Two |
| Three |" old="|,$n" new="&vbar;,<br>"}%
THIS
    my $out = <<'THAT';
&vbar; One &vbar;<br>&vbar; Two &vbar;<br>&vbar; Three &vbar;
THAT
    $this->assert_equals( $out, $this->{test_topicObject}->expandMacros($in) );
}

sub test_old_new_2 {
    my $this = shift;
    my $in   = <<'THIS';
%ENCODE{"\"%>,<&" old="$lt,$gt,$amp,$percent,$comma,$quot" new="L,G,A,P,C,Q"}%
THIS
    my $out = "QPGCLA\n";
    $this->assert_equals( $out, $this->{test_topicObject}->expandMacros($in) );
}

sub test_old_new_3 {
    my $this = shift;
    my $in   = '%ENCODE{"spreadsheet" old="ee,sp" new="i,"}%';
    my $out  = 'readshit';
    $this->assert_equals( $out, $this->{test_topicObject}->expandMacros($in) );
}

sub test_old_new_4 {
    my $this = shift;
    my $in   = '%ENCODE{"101" old="0,1" new="x"}%';
    my $out  = 'x';
    $this->assert_equals( $out, $this->{test_topicObject}->expandMacros($in) );
}

sub test_old_new_5 {
    my $this = shift;
    my $in   = '%ENCODE{"XY" old="Y,X" new="X,Y"}%';
    my $out  = 'YX';
    $this->assert_equals( $out, $this->{test_topicObject}->expandMacros($in) );
}

sub test_old_new_sven2 {
    my $this = shift;
    my $in   = '%ENCODE{"go for it" old="g,o,f,r,i,t" new="w,h,a,t,t,h,e"}%';
    my $out  = "wh aht th";
    $this->assert_equals( $out, $this->{test_topicObject}->expandMacros($in) );
}

sub test_fail_1 {
    my $this = shift;
    my $in   = '%ENCODE{"schlob" old="sch" new="f" type="replace"}%';
    my $out = "ENCODE failed - =type= cannot be used alongside =old= and =new=";
    $this->assert_matches( qr/$out/,
        $this->{test_topicObject}->expandMacros($in) );
}

sub test_fail_2 {
    my $this = shift;
    my $in   = '%ENCODE{"schlob" old="sch"}%';
    my $out  = "ENCODE failed - both of =old= and =new= must be given";
    $this->assert_matches( qr/$out/,
        $this->{test_topicObject}->expandMacros($in) );
    $in = '%ENCODE{"schlob" new="sch"}%';
    $this->assert_matches( qr/$out/,
        $this->{test_topicObject}->expandMacros($in) );
}

sub test_fail_3 {
    my $this = shift;
    my $in   = '%ENCODE{"go for it" old="g,o,f,o,r,i,t" new="w,h,a,t,t,h,e"}%';
    my $out  = "ENCODE failed - token 'o' is repeated in =old=";
    $this->assert_matches( qr/$out/,
        $this->{test_topicObject}->expandMacros($in) );
}

1;
