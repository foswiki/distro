package TWiki::OopsException;
use Error;
use Assert;
use base 'Error';

use Foswiki::OopsException;

sub new {
    shift;
    return new Foswiki::OopsException(@_);
}

1;

