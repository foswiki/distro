package InterwikiPluginSuite;

use strict;

use Unit::TestSuite;
our @ISA = 'Unit::TestSuite';

sub name { 'InterwikiPluginSuite' }

sub include_tests { qw(InterwikiPluginTests) }

1;
