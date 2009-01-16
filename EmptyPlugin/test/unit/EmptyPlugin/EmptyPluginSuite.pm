package EmptyPluginSuite;

use base qw(Unit::TestSuite);

sub name { 'EmptyPluginSuite' };

sub include_tests { qw(EmptyPluginTests) };

1;
