package PlainFileStoreContribSuite;

use Unit::TestSuite;
our @ISA = qw( Unit::TestSuite );

sub name { 'PlainFileStoreContribSuite' }

sub include_tests { qw(PlainFileStoreContribTests) }

1;
