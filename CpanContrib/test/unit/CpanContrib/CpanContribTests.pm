use strict;

package CpanContribTests;

use FoswikiTestCase;
our @ISA = qw( FoswikiTestCase );

use strict;
use Foswiki;

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

# Set up the test fixture
sub set_up {
    my $this = shift;

    $this->SUPER::set_up();
}

sub tear_down {
    my $this = shift;
    $this->SUPER::tear_down();
}

sub test_self {
    my $this = shift;
}

1;
