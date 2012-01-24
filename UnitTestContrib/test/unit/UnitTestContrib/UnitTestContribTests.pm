package UnitTestContribTests;
use strict;
use warnings;

use FoswikiTestCase();
our @ISA = qw( FoswikiTestCase );

use Assert;

# For test_FOSWIKI_ASSERTS; compile Foswiki.pm
use Foswiki();
use Foswiki::Func();

sub test_FOSWIKI_ASSERTS {
    my ($this) = @_;

    $this->expect_failure('We need to die when: { ASSERT(0) if DEBUG }.');

    # Try to trip normalizeWebTopicName()'s ASSERT(defined $topic) if DEBUG;
    # Prior to Item11466, UnitTestContrib was setting FOSWIKI_ASSERTS=1 *after*
    # Foswiki.pm had already been compiled, meaning these kinds of ASSERTs would
    # not trip unless you also set ASSERTS in LocaLib.
    Foswiki::Func::normalizeWebTopicName();

    return;
}

#================================================================================

1;
