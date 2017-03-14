use strict;

# tests for the correct expansion of SCRIPTURL

package Fn_SCRIPTURL;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use Foswiki;
use Error qw( :try );

sub new {
    my $self = shift()->SUPER::new( 'SCRIPTURL', @_ );
    return $self;
}

sub test_SCRIPTURL_view {
    my $this = shift;

    $Foswiki::cfg{ScriptUrlPaths}{snarf} = "sausages";
    undef $Foswiki::cfg{ScriptUrlPaths}{view};
    $Foswiki::cfg{ScriptSuffix} = ".dot";

    my $result = $this->{test_topicObject}->expandMacros("%SCRIPTURL%");
    $this->assert_str_equals(
        "$Foswiki::cfg{DefaultUrlHost}$Foswiki::cfg{ScriptUrlPath}", $result );

    $result = $this->{test_topicObject}->expandMacros("%SCRIPTURLPATH{view}%");
    $this->assert_str_equals( "$Foswiki::cfg{ScriptUrlPath}/view.dot",
        $result );

    # Topic is converted from query param to path web/topic.
    $result =
      $this->{test_topicObject}
      ->expandMacros("%SCRIPTURLPATH{\"view\" topic=\"Main.WebHome\"}%");
    $this->assert_str_equals(
        "$Foswiki::cfg{ScriptUrlPath}/view.dot/Main/WebHome", $result );

# Web is ignored in processing topic query param. so preserve in the query string.
    $result =
      $this->{test_topicObject}->expandMacros(
        "%SCRIPTURLPATH{\"view\" topic=\"Main.WebHome\" web=\"System\"}%");
    $this->assert_str_equals(
        "$Foswiki::cfg{ScriptUrlPath}/view.dot/Main/WebHome?web=System",
        $result );

    $result =
      $this->{test_topicObject}->expandMacros(
        "%SCRIPTURLPATH{\"jsonrpc\" topic=\"Main.WebHome\" web=\"System\"}%");
    $this->assert_str_equals(
"<div class='foswikiAlert'>jsonrpc requires the 'namespace' parameter if other parameters are supplied.</div>",
        $result
    );

    # Web is used if topic contains no web, remove from query string.
    $result =
      $this->{test_topicObject}->expandMacros(
        "%SCRIPTURLPATH{\"view\" topic=\"WebHome\" web=\"System\"}%");
    $this->assert_str_equals(
        "$Foswiki::cfg{ScriptUrlPath}/view.dot/System/WebHome", $result );

    $result = $this->{test_topicObject}->expandMacros("%SCRIPTURLPATH{snarf}%");
    $this->assert_str_equals( "sausages", $result );

    # anchor parameter # is added as a fragment.
    $result =
      $this->{test_topicObject}->expandMacros(
        "%SCRIPTURLPATH{\"view\" topic=\"Main.WebHome\" #=\"frag\"}%");
    $this->assert_str_equals(
        $Foswiki::cfg{ScriptUrlPath} . '/view.dot/Main/WebHome#frag', $result );

    # Use of # anywhere but the anchor tag is encoded.
    $result =
      $this->{test_topicObject}->expandMacros(
"%SCRIPTURLPATH{\"view\" topic=\"Main.WebHome\" #=\"frag\" A#A=\"another\"}%"
      );
    $this->assert_str_equals(
        $Foswiki::cfg{ScriptUrlPath}
          . '/view.dot/Main/WebHome?A%23A=another#frag',
        $result
    );
}

sub test_SCRIPTURL_rest {
    my $this = shift;

    $Foswiki::cfg{ScriptUrlPaths}{snarf} = "sausages";
    undef $Foswiki::cfg{ScriptUrlPaths}{view};
    $Foswiki::cfg{ScriptSuffix} = ".dot";

    my $result =
      $this->{test_topicObject}->expandMacros(
        "%SCRIPTURLPATH{\"rest\" topic=\"Main.WebHome\" web=\"System\"}%");
    $this->assert_str_equals(
"<div class='foswikiAlert'>rest requires both 'subject' and 'verb' parameters if other parameters are supplied.</div>",
        $result
    );

    $result =
      $this->{test_topicObject}->expandMacros(
"%SCRIPTURLPATH{\"rest\" subject=\"Weeble\" topic=\"Main.WebHome\" web=\"System\"}%"
      );
    $this->assert_str_equals(
"<div class='foswikiAlert'>rest requires both 'subject' and 'verb' parameters if other parameters are supplied.</div>",
        $result
    );

    $result =
      $this->{test_topicObject}->expandMacros(
"%SCRIPTURLPATH{\"rest\" subject=\"Weeble\" verb=\"wobble\" topic=\"Main.WebHome\" web=\"System\"}%"
      );
    $this->assert_str_equals(
"$Foswiki::cfg{ScriptUrlPath}/rest.dot/Weeble/wobble?topic=Main.WebHome;web=System",
        $result
    );
}

sub test_SCRIPTURL_jsonrpc {
    my $this = shift;

    $Foswiki::cfg{ScriptUrlPaths}{snarf} = "sausages";
    undef $Foswiki::cfg{ScriptUrlPaths}{view};
    $Foswiki::cfg{ScriptSuffix} = ".dot";

    my $result =
      $this->{test_topicObject}->expandMacros(
        "%SCRIPTURLPATH{\"jsonrpc\" topic=\"Main.WebHome\" web=\"System\"}%");
    $this->assert_str_equals(
"<div class='foswikiAlert'>jsonrpc requires the 'namespace' parameter if other parameters are supplied.</div>",
        $result
    );

    $result =
      $this->{test_topicObject}->expandMacros(
"%SCRIPTURLPATH{\"jsonrpc\" namespace=\"Weeble\" topic=\"Main.WebHome\" web=\"System\"}%"
      );
    $this->assert_str_equals(
"$Foswiki::cfg{ScriptUrlPath}/jsonrpc.dot/Weeble?topic=Main.WebHome;web=System",
        $result
    );

    $result =
      $this->{test_topicObject}->expandMacros(
"%SCRIPTURLPATH{\"jsonrpc\" namespace=\"Weeble\" method=\"wobble\" topic=\"Main.WebHome\" web=\"System\"}%"
      );
    $this->assert_str_equals(
"$Foswiki::cfg{ScriptUrlPath}/jsonrpc.dot/Weeble/wobble?topic=Main.WebHome;web=System",
        $result
    );

    $result =
      $this->{test_topicObject}->expandMacros(
"%SCRIPTURLPATH{\"jsonrpc\" namespace=\"Weeble\" method=\"wobble\" topic=\"Main.WebHome\" web=\"System\"}%"
      );
    $this->assert_str_equals(
"$Foswiki::cfg{ScriptUrlPath}/jsonrpc.dot/Weeble/wobble?topic=Main.WebHome;web=System",
        $result
    );
}
1;
