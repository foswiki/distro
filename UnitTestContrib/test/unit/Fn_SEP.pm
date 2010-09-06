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

# This particular test does not have to run in a separate process
# but this test is really short and as good as any other for
# exercising that part of the UnitTestContrib infrastructure
sub run_in_new_process {
    return 1;
}

1;
