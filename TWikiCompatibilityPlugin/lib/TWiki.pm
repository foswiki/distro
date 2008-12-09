#package TWiki;

use Foswiki;

sub TWiki::new {
    shift;
    return new Foswiki(@_);
}

%TWiki::regex = %Foswiki::regex;

1;
