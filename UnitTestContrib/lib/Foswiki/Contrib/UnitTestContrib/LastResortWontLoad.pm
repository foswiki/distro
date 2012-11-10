package Foswiki::Contrib::UnitTestContrib::LastResortWontLoad;

# This module exists only to provide a module with version number
# that can't be loadded due to other errors.
#
use version 0.77; our $VERSION = version->declare("v1.2.3_100");

die "This module fails to force last resort processing";
1;
