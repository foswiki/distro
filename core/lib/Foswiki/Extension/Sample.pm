
package Foswiki::Extension::Sample;

use Foswiki::Class qw(extension);
extends qw(Foswiki::Extension);

use version 0.77; our $VERSION = version->declare(0.0.1);
our $API_VERSION = version->declare("2.99.0");

plugBefore 'Foswiki::Exception::transmute' => sub {

};

extClass 'Foswiki::Logger', 'Foswiki::Extension::Sample::Logger';

extBefore qw(Empty);

1;
