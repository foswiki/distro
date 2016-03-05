# See bottom of file for license and copyright information
package EditRowPluginSuite;
use v5.14;

use Moo;
extends qw(Unit::TestSuite);

sub include_tests { return ( 'Parser', 'HTML', 'Rest' ) }

1;
