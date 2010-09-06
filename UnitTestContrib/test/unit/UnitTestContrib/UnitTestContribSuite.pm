package UnitTestContribSuite;

use strict;

use Unit::TestSuite;
our @ISA = 'Unit::TestSuite';

sub name { 'UnitTestContribSuite' }

sub include_tests { qw(EavesdropTests) }

1;
