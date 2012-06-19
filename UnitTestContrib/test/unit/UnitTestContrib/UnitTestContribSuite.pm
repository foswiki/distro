package UnitTestContribSuite;

use strict;

use Unit::TestSuite;
our @ISA = 'Unit::TestSuite';

sub name { 'UnitTestContribSuite' }

sub include_tests {
    return (
        qw(EavesdropTests UnitTestContribTests),

        # Item11956 - used for testing reporting of modules that fail to compile
        #'UnitTestContribFailsToCompileTest',
        #'UnitTestContribSuiteMissingTest',
    );
}

1;
