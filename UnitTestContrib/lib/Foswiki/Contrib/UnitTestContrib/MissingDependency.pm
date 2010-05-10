package Foswiki::Contrib::UnitTestContrib::MissingDependency;


# This module exists only to provide a module with version number
# that includes multiple dots, for the purposes of unit-testing
# extender.pl
#our $VERSION = 'Caught a comment!';
 our $VERSION = '$Rev: 1234 (2010-01-19) $';
  $RELEASE = "1.23.4";

require Archive::Missing;

1;
