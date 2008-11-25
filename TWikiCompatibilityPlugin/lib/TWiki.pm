#package TWiki;

use Foswiki;

sub TWiki::new {
    shift;
    return new Foswiki(@_);
}

1;
