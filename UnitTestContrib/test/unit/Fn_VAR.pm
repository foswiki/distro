# tests for the correct expansion of VAR

package Fn_VAR;
use strict;
use warnings;

use FoswikiFnTestCase();
our @ISA = qw( FoswikiFnTestCase );

use Foswiki();
use Foswiki::Func();
use Error qw( :try );

sub test_VAR {
    my $this = shift;

    my $result;

    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web},
        $Foswiki::cfg{WebPrefsTopicName} );
    $topicObject->text(<<'SPLOT');
   * Set BLEEGLE = gibbut
SPLOT
    $topicObject->save();
    $topicObject->finish();

    ($topicObject) =
      Foswiki::Func::readTopic( $this->{users_web},
        $Foswiki::cfg{WebPrefsTopicName} );
    $topicObject->text(<<'SPLOT');
   * Set BLEEGLE = frabbeque
SPLOT
    $topicObject->save();
    $topicObject->finish();

    $this->createNewFoswikiSession();
    ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );
    $result = $topicObject->expandMacros("%VAR{\"VAR\"}%");
    $this->assert_equals( "", $result );
    $result = $topicObject->expandMacros(
        "%VAR{\"BLEEGLE\" web=\"$this->{users_web}\"}%");
    $this->assert_equals( "frabbeque", $result );

    $result = $topicObject->expandMacros(
        "%VAR{\"BLEEGLE\" web=\"$this->{test_web}\"}%");
    $this->assert_equals( "gibbut", $result );

    $result = $topicObject->expandMacros("%VAR{\"BLEEGLE\"}%");
    $this->assert_equals( "gibbut", $result );

    $result = $topicObject->expandMacros("%VAR%");
    $this->assert_equals( '', $result );

    $topicObject->finish();

    return;
}

1;
