package TWiki::OopsException;
use strict;

use Foswiki::OopsException;
our @ISA = 'Foswiki::OopsException';

sub new {
    my $class = shift;
    return $class->SUPER::new(@_);
}

1;

