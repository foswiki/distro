package TWiki::Meta;

use strict;

use Foswiki::Meta;

sub new {
    shift;
    return Foswiki::Meta->new(@_);
}

1;

