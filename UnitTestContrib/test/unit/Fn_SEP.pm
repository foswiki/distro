use strict;

# tests for the correct expansion of SEP

package Fn_SEP;

use base qw( FoswikiFnTestCase );

use Foswiki;
use Error qw( :try );

sub new {
    my $self = shift()->SUPER::new('SEP', @_);
    return $self;
}

sub test_SEP {
    my $this = shift;
    my $a = $this->{twiki}->handleCommonTags("%TMPL:P{sep}%", $this->{test_web}, $this->{test_topic});
    my $b = $this->{twiki}->handleCommonTags("%SEP%", $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals($a,$b);
}

1;
