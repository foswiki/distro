# See bottom of file for license and copyright information.
package Foswiki::Contrib::DBIStoreContrib;

use strict;
use Foswiki ();

our $VERSION = '1.1';           # version of *this file*.
our $RELEASE = '12 Dec 2013';

use constant MONITOR => 1;

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

