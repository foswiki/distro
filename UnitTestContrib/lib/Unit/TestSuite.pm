# See bottom of file for description
package Unit::TestSuite;
use base 'Unit::TestCase';

sub include_tests {
    return ();
}

1;

__DATA__

=pod

A collection of test cases. Subclass and implement include_tests to return
a list of TestCase (file) names. TestSuite is also a TestCase, so a suite can
include other suites.

Author: Crawford Currie, http://c-dot.co.uk

Copyright (C) 2007 WikiRing, http://wikiring.com
All Rights Reserved.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.

=cut
