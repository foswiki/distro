use strict;

# tests for the correct expansion of NOP

package Fn_NOP;

use base qw( TWikiFnTestCase );

use TWiki;
use Error qw( :try );

sub new {
    my $self = shift()->SUPER::new('NOP', @_);
    return $self;
}

sub test_NOP {
    my $this = shift;

    my $result = $this->{twiki}->handleCommonTags("%NOP%", $this->{test_web}, $this->{test_topic});
    $this->assert_equals('<nop>', $result);

    $result = $this->{twiki}->handleCommonTags("%NOP{   ignore me   }%", $this->{test_web}, $this->{test_topic});
    $this->assert_equals("   ignore me   ", $result);

    $result = $this->{twiki}->handleCommonTags("%NOP{%SWINE%}%", $this->{test_web}, $this->{test_topic});
    $this->assert_equals("%SWINE%", $result);

    $result = $this->{twiki}->handleCommonTags("%NOP{%WEB%}%", $this->{test_web}, $this->{test_topic});
    $this->assert_equals($this->{test_web}, $result);

    $result = $this->{twiki}->handleCommonTags("%NOP{%WEB{}%}%", $this->{test_web}, $this->{test_topic});
    $this->assert_equals($this->{test_web}, $result);

    $result = $this->{twiki}->expandVariablesOnTopicCreation("%NOP%");
    $this->assert_equals('', $result);

    $result = $this->{twiki}->expandVariablesOnTopicCreation("%GM%NOP%TIME%");
    $this->assert_equals('%GMTIME%', $result);

    $result = $this->{twiki}->expandVariablesOnTopicCreation("%NOP{   ignore me   }%");
    $this->assert_equals('', $result);

    # this *ought* to work, but by the definition of TML, it doesn't.
    #$result = $this->{twiki}->handleCommonTags("%NOP{%FLEEB{}%}%", $this->{test_web}, $this->{test_topic});
    #$this->assert_equals("%FLEEB{}%", $result);

}

1;
