use strict;

# tests for the correct expansion of SEP

package Fn_SEP;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use Foswiki;
use Error qw( :try );

sub new {
    my $self = shift()->SUPER::new( 'SEP', @_ );
    return $self;
}

sub test_SEP {
    my $this = shift;
    my $a    = $this->{test_topicObject}->expandMacros("%TMPL:P{sep}%");
    my $b    = $this->{test_topicObject}->expandMacros("%SEP%");
    $this->assert_str_equals( $a, $b );
}

1;
