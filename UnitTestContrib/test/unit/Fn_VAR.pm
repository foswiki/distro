use strict;

# tests for the correct expansion of VAR

package Fn_VAR;

use base qw( FoswikiFnTestCase );

use Foswiki;
use Error qw( :try );

sub new {
    my $self = shift()->SUPER::new('VAR', @_);
    return $self;
}

sub test_VAR {
    my $this = shift;

    my $result;

    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $this->{test_web},
        'WebPreferences', <<SPLOT);
   * Set BLEEGLE = gibbut
SPLOT
    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $this->{users_web},
        'WebPreferences', <<SPLOT);
   * Set BLEEGLE = frabbeque
SPLOT

    $this->{twiki}->finish();
    $this->{twiki} = new Foswiki();

    $result = $this->{twiki}->handleCommonTags("%VAR{\"VAR\"}%", $this->{test_web}, $this->{test_topic});
    $this->assert_equals("", $result);

    $result = $this->{twiki}->handleCommonTags("%VAR{\"BLEEGLE\" web=\"$this->{users_web}\"}%", $this->{users_web}, $this->{test_topic});
    $this->assert_equals("frabbeque", $result);

    $result = $this->{twiki}->handleCommonTags("%VAR{\"BLEEGLE\" web=\"$this->{test_web}\"}%", $this->{test_web}, $this->{test_topic});
    $this->assert_equals("gibbut", $result);

    $result = $this->{twiki}->handleCommonTags("%VAR{\"BLEEGLE\"}%", $this->{test_web}, $this->{test_topic});
    $this->assert_equals("gibbut", $result);

    $result = $this->{twiki}->handleCommonTags("%VAR%", $this->{test_web}, $this->{test_topic});
    $this->assert_equals('', $result);
}

1;
