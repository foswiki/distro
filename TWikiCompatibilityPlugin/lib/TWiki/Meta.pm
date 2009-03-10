package TWiki::Meta;

use Foswiki::Meta;

sub new {
    shift;
    return Foswiki::Meta->new(@_);
}

1;

