# tests for the correct expansion of SCRIPTURL
package Fn_SCRIPTURL;

use strict;
use warnings;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use Foswiki;
use Error qw( :try );

sub new {
    my $self = shift()->SUPER::new( 'SCRIPTURL', @_ );
    return $self;
}

sub test_SCRIPTURL {
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

# SMELL: rest and jsonrpc cannot built the path automatically. Ignore all params.
    $result =
      $this->{test_topicObject}->expandMacros(
        "%SCRIPTURLPATH{\"rest\" topic=\"Main.WebHome\" web=\"System\"}%");
    $this->assert_str_equals(
"<div class='foswikiAlert'>Parameters are not supported when generating rest or jsonrpc URLs.</div>",
        $result
    );

    $result =
      $this->{test_topicObject}->expandMacros(
        "%SCRIPTURLPATH{\"jsonrpc\" topic=\"Main.WebHome\" web=\"System\"}%");
    $this->assert_str_equals(
"<div class='foswikiAlert'>Parameters are not supported when generating rest or jsonrpc URLs.</div>",
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
}

1;
