package TWiki::Meta;

use Foswiki::Meta;

sub new {
    shift;
    return new Foswiki::Meta(@_);
}

1;

