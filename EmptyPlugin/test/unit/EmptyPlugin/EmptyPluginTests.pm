use strict;

package EmptyPluginTests;

use base qw(TWikiTestCase);

use strict;
use TWiki;
use CGI;

my $twiki;

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

# Set up the test fixture
sub set_up {
    my $this = shift;

    $this->SUPER::set_up();

    $TWiki::Plugins::SESSION = $twiki;
}

sub tear_down {
    my $this = shift;
    $this->SUPER::tear_down();
}

sub test_self {
    my $this = shift;
}

1;
