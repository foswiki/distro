package TopicUserMappingContribSuite;

use strict;
use warnings;

use Unit::TestSuite;
our @ISA = 'Unit::TestSuite';

sub include_tests {
    return qw(TopicUserMappingContribTests TopicUserMappingTests);
}

1;
