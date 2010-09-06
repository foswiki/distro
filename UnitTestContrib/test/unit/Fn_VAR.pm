use strict;

# tests for the correct expansion of VAR

package Fn_VAR;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use Foswiki;
use Error qw( :try );

sub new {
    my $self = shift()->SUPER::new( 'VAR', @_ );
    return $self;
}

sub test_VAR {
    my $this = shift;

    my $result;

    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        $Foswiki::cfg{WebPrefsTopicName}, <<SPLOT);
   * Set BLEEGLE = gibbut
SPLOT
    $topicObject->save();

    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{users_web},
        $Foswiki::cfg{WebPrefsTopicName}, <<SPLOT);
   * Set BLEEGLE = frabbeque
SPLOT
    $topicObject->save();

    $this->{session}->finish();
    $this->{session} = new Foswiki();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        $this->{test_topic} );
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
}

1;
