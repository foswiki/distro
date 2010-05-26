use strict;

# tests for the correct expansion of NOP

package Fn_NOP;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use Foswiki;
use Error qw( :try );

sub new {
    my $self = shift()->SUPER::new( 'NOP', @_ );
    return $self;
}

sub test_NOP {
    my $this        = shift;
    my $topicObject = Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'WebHome' );
    my $result      = $topicObject->expandMacros("%NOP%");
    $this->assert_equals( '<nop>', $result );

    $result = $topicObject->expandMacros("%NOP{   ignore me   }%");
    $this->assert_equals( "   ignore me   ", $result );

    $result = $topicObject->expandMacros("%NOP{%SWINE%}%");
    $this->assert_equals( "%SWINE%", $result );

    $result = $topicObject->expandMacros("%NOP{%WEB%}%");
    $this->assert_equals( $this->{test_web}, $result );

    $result = $topicObject->expandMacros("%NOP{%WEB{}%}%");
    $this->assert_equals( $this->{test_web}, $result );

    $result = $topicObject->expandNewTopic("%NOP%");
    $this->assert_equals( '', $result );

    $result = $topicObject->expandNewTopic("%GM%NOP%TIME%");
    $this->assert_equals( '%GMTIME%', $result );

    $result = $topicObject->expandNewTopic("%NOP{   ignore me   }%");
    $this->assert_equals( '', $result );

    # this *ought* to work, but by the definition of TML, it doesn't.
    #$result = $topicObject->expandMacros("%NOP{%FLEEB{}%}%");
    #$this->assert_equals("%FLEEB{}%", $result);
}

1;
