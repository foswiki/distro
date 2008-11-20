package TWiki::Plugins;

use Foswiki::Plugins;

# Compatible version of TWiki::Plugins
our $VERSION = 1.026;

# Access to $TWiki::Plugins::SESSION is via a tie to $Foswiki::Plugins::SESSION
{
    package TWiki::Plugins::SESSION_TIE;
    use base 'Tie::Scalar';

    sub FETCH { return $Foswiki::Plugins::SESSION; }
};

tie($TWiki::Plugins::SESSION, 'TWiki::Plugins::SESSION_TIE');

1;
