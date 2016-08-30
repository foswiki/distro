package Foswiki::Extension::Empty;

use Foswiki::Class qw(extension);
extends qw(Foswiki::Extension);

use version 0.77; our $VERSION = version->declare(0.0.1);
our $API_VERSION = version->declare("2.99.0");

extAfter qw(Sample);

extBefore qw(Test1 Foswiki::Extension::Test2);

1;
