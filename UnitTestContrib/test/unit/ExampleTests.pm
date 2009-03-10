use strict;

# Pathologically simple test case.
package ExampleTests;

use base qw(FoswikiTestCase);

use Foswiki;

sub set_up {

    # Set up test fixture; e.g. create webs, topics
    # See EmptyTests for an example
}

sub tear_down {

    # Remove fixtures created in set_up
    # Do *not* leave fixtures lying around!
    # See EmptyTests for an example
}

# Example of a test method.
sub testHelloWorld {
    my $this = shift;

    # NOTE: DO *NOT* print from tests. The prints just confuse the output when
    # the tests are all run together. Only use print when debugging.
    $this->assert(1);
}

1;
