package RCSStoreContribSuite;

use Unit::TestSuite;
our @ISA = qw( Unit::TestSuite );

sub name { 'RCSStoreContribSuite' }

sub include_tests {
    'RCSHandlerTests', 'RCSConfigureTests', 'VCStoreTests', 'AutoAttachTests',
      'VCMetaTests', 'LoadedRevTests';
}

1;
