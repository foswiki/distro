# Pathologically simple test case.
package ExampleTests;
use v5.14;

use Foswiki;

use Moo;
use namespace::clean;
extends qw( FoswikiTestCase );

around set_up => sub {
    my $orig = shift;
    my $this = shift;

    $orig->( $this, @_ );

    # Set up test fixture; e.g. create webs, topics
    # See EmptyTests for an example
};

around tear_down => sub {
    my $orig = shift;
    my $this = shift;    # the Test::Unit::TestCase object

    $orig->( $this, @_ );

    # Remove fixtures created in set_up
    # Do *not* leave fixtures lying around!
    # See EmptyTests for an example
};

# Example of a test method.
sub testHelloWorld {
    my $this = shift;

    # NOTE: DO *NOT* print from tests. The prints just confuse the output when
    # the tests are all run together. Only use print when debugging.
    $this->assert(1);
}

1;
