# See bottom of file for license and copyright information.
package Foswiki::Contrib::DBIStoreContrib;

use strict;
use Foswiki ();

our $VERSION = '1.1';          # plugin version is also locked to this
our $RELEASE = '4 Mar 2014';

# Very verbose debugging. Used by all modules in the suite.
use constant MONITOR => 0;

our $SHORTDESCRIPTION =
'Use DBI to implement searching using an SQL database. Supports SQL queries over Form data.';

# Type identifiers.
# FIRST 3 MUST BE KEPT IN LOCKSTEP WITH Foswiki::Infix::Node
# Declared again here because the constants are not defined
# in Foswiki 1.1 and earlier
use constant {
    NAME   => 1,
    NUMBER => 2,
    STRING => 3,
};

# Additional types local to this module - must not overlap known
# types
use constant {
    UNKNOWN => 0,

    # Gap for 1.2 types HASH and META

    BOOLEAN  => 10,
    SELECTOR => 11,    # Temporary, synonymous with UNKNOWN

    VALUE => 12,
    TABLE => 13,

    # An integer type used during hoisting where DB doesn't support
    # a BOOLEAN type
    PSEUDO_BOOL => 14,
};

1;
__DATA__

Author: Crawford Currie http://c-dot.co.uk

Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/, http://Foswiki.org/

Copyright (C) 2013-2014 Foswiki Contributors. All Rights Reserved.
Foswiki Contributors are listed in the AUTHORS file in the root
of this distribution. NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
