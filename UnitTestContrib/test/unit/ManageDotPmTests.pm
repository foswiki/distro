

use strict;
use warnings;
use diagnostics;

package ManageDotPmTests;

use base qw(FoswikiFnTestCase);
use Foswiki;
use Foswiki::UI::Manage;
use Foswiki::UI::Save;

# Set up the test fixture
sub set_up {
    my $this = shift;

    $this->SUPER::set_up();
}


1;
