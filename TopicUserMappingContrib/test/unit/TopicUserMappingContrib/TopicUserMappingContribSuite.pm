package TopicUserMappingContribSuite;

use strict;

use Unit::TestSuite;
our @ISA = 'Unit::TestSuite';

sub include_tests {
    return qw(TopicUserMappingContribTests TopicUserMappingTests);
}

1;
