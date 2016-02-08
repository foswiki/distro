use strict;

# tests for the correct expansion of SCRIPTURL

package Fn_SCRIPTURL;
use v5.14;

use Foswiki;
use Try::Tiny;

use Moo;
use namespace::clean;
extends qw( FoswikiFnTestCase );

around BUILDARGS => sub {
    my $orig = shift;
    return $orig->( @_, testSuite => 'SCRIPTURL' );
};

sub test_SCRIPTURL {
    my $this = shift;

    $Foswiki::cfg{ScriptUrlPaths}{snarf} = "sausages";
    undef $Foswiki::cfg{ScriptUrlPaths}{view};
    $Foswiki::cfg{ScriptSuffix} = ".dot";

    my $result = $this->test_topicObject->expandMacros("%SCRIPTURL%");
    $this->assert_str_equals(
        "$Foswiki::cfg{DefaultUrlHost}$Foswiki::cfg{ScriptUrlPath}", $result );

    $result = $this->test_topicObject->expandMacros("%SCRIPTURLPATH{view}%");
    $this->assert_str_equals( "$Foswiki::cfg{ScriptUrlPath}/view.dot",
        $result );

    $result = $this->test_topicObject->expandMacros("%SCRIPTURLPATH{snarf}%");
    $this->assert_str_equals( "sausages", $result );
}

1;
