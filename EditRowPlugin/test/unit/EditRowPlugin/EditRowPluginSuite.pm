# See bottom of file for license and copyright information
package EditRowPluginSuite;

use strict;
use warnings;
use Unit::TestSuite;
our @ISA = 'Unit::TestSuite';

sub include_tests { return ( 'Parser', 'ERP_HTML', 'Rest' ) }

1;
