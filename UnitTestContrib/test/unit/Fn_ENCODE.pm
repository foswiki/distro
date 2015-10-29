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
    $this->assert_str_equals( '%3cevil%20script%3e%27%22%25', "$str" );
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
    $this->assert_str_equals( "%3cevil%20script%3e%0a%26%27%22%25*A", "$str" );

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

sub test_coverage {
    my $this = shift;

    my $str;

    foreach my $chr ( 1 .. 127 ) {
        $str .= chr($chr);
    }

# Entities encoding using Foswiki::entityEncode
#   * all non-printable 7-bit chars (< \x1f), except \n (\xa) and \r (\xd)
#   * HTML special characters '>', '<', '&', ''' and '"'.                      60, 62, 38, 39, 34
#   * TML special characters '%', '|', '[', ']', '@', '_', '$', '*' and '='    37, 124, 91, 93, 64, 95, 36, 42, 61

    my $results = Foswiki::entityEncode($str);
    $this->assert_str_equals(
"&#1;&#2;&#3;&#4;&#5;&#6;&#7;&#8;&#9;'0a'&#11;&#12;'0d'&#14;&#15;&#16;&#17;&#18;&#19;&#20;&#21;&#22;&#23;&#24;&#25;&#26;&#27;&#28;&#29;&#30;&#31; !&#34;#&#36;&#37;&#38;&#39;()&#42;+,-./0123456789:;&#60;&#61;&#62;?&#64;ABCDEFGHIJKLMNOPQRSTUVWXYZ&#91;\\&#93;^&#95;`abcdefghijklmnopqrstuvwxyz{&#124;}~'7f'",
        hexdump($results)
    );

# Same encoding, using the %ENCODE macro
#SMELL:  Hex 01-02 are special markers used in render and don't encode correctly
    $results =
      $this->{test_topicObject}
      ->expandMacros( '%ENCODE{"' . $str . '" type="entities"}%' );

    $this->assert_str_equals(
"&#39;&#34;&#3;&#4;&#5;&#6;&#7;&#8;&#9;'0a'&#11;&#12;'0d'&#14;&#15;&#16;&#17;&#18;&#19;&#20;&#21;&#22;&#23;&#24;&#25;&#26;&#27;&#28;&#29;&#30;&#31; !&#34;#&#36;&#37;&#38;&#39;()&#42;+,-./0123456789:;&#60;&#61;&#62;?&#64;ABCDEFGHIJKLMNOPQRSTUVWXYZ&#91;\\&#93;^&#95;`abcdefghijklmnopqrstuvwxyz{&#124;}~'7f'",
        hexdump($results)
    );

    # HTML encoding,  same as entities,  adds CR & LF  0x10, 0x13
    $results =
      $this->{test_topicObject}
      ->expandMacros( '%ENCODE{"' . $str . '" type="html"}%' );

    $this->assert_str_equals(
"&#39;&#34;&#3;&#4;&#5;&#6;&#7;&#8;&#9;&#10;&#11;&#12;&#13;&#14;&#15;&#16;&#17;&#18;&#19;&#20;&#21;&#22;&#23;&#24;&#25;&#26;&#27;&#28;&#29;&#30;&#31; !&#34;#&#36;&#37;&#38;&#39;()&#42;+,-./0123456789:;&#60;&#61;&#62;?&#64;ABCDEFGHIJKLMNOPQRSTUVWXYZ&#91;\\&#93;^&#95;`abcdefghijklmnopqrstuvwxyz{&#124;}~'7f'",
        hexdump($results)
    );

# URL encoding, Tuned for Foswiki: HEX encodes *all* characters except 0-9a-zA-Z-_.:~!*#/
    $results =
      $this->{test_topicObject}
      ->expandMacros( '%ENCODE{"' . $str . '" type="url"}%' );

    $this->assert_str_equals(
"%27%22%03%04%05%06%07%08%09%0a%0b%0c%0d%0e%0f%10%11%12%13%14%15%16%17%18%19%1a%1b%1c%1d%1e%1f%20!%22%23%24%25%26%27%28%29*%2b%2c-./0123456789:%3b%3c%3d%3e%3f%40ABCDEFGHIJKLMNOPQRSTUVWXYZ%5b%5c%5d%5e_%60abcdefghijklmnopqrstuvwxyz%7b%7c%7d~%7f",
        hexdump($results)
    );

    # Default encoding should be URL encoding
    my $defaultResult =
      $this->{test_topicObject}->expandMacros( '%ENCODE{"' . $str . '"}%' );

    $this->assert_str_equals( $results, $defaultResult );

    # safe encoding,  Only encodes <>%'"
    $results =
      $this->{test_topicObject}
      ->expandMacros( '%ENCODE{"' . $str . '" type="safe"}%' );

    $this->assert_str_equals(
"&#39;&#34;'03''04''05''06''07''08''09''0a''0b''0c''0d''0e''0f''10''11''12''13''14''15''16''17''18''19''1a''1b''1c''1d''1e''1f' !&#34;#\$&#37;&&#39;()*+,-./0123456789:;&#60;=&#62;?\@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~'7f'",
        hexdump($results)
    );

}

sub hexdump {
    my $hex = '';
    foreach my $ch ( split( //, $_[0] ) ) {
        $hex .=
          ( $ch lt "\x20" || $ch gt "\x7e" )
          ? "'" . unpack( "H2", $ch ) . "'"
          : $ch;
    }
    return $hex;
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
    my $in   = '%ENCODE{"spreadsheet" old="heet,sp" new="tuf,"}%';
    my $out  = 'readstuf';
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
