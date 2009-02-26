use strict;

# tests for the correct expansion of SCRIPTURL

package Fn_SCRIPTURL;

use base qw( FoswikiFnTestCase );

use Foswiki;
use Error qw( :try );

sub new {
    my $self = shift()->SUPER::new('SCRIPTURL', @_);
    return $self;
}

sub test_SCRIPTURL {
    my $this = shift;

    $Foswiki::cfg{ScriptUrlPaths}{snarf} = "sausages";
    undef $Foswiki::cfg{ScriptUrlPaths}{view};
    $Foswiki::cfg{ScriptSuffix} = ".dot";

    my $result = $this->{twiki}->handleCommonTags("%SCRIPTURL%", $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals(
        "$Foswiki::cfg{DefaultUrlHost}$Foswiki::cfg{ScriptUrlPath}", $result);

    $result = $this->{twiki}->handleCommonTags(
        "%SCRIPTURLPATH{view}%", $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals("$Foswiki::cfg{ScriptUrlPath}/view.dot", $result);

    $result = $this->{twiki}->handleCommonTags(
        "%SCRIPTURLPATH{snarf}%", $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals("sausages", $result);
}

1;
