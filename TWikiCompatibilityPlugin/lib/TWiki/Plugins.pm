package TWiki::Plugins;

use TWiki;

use Foswiki::Plugins;

# Compatible version of TWiki::Plugins
our $VERSION = 1.2;

# Access to $TWiki::Plugins::SESSION is via a tie to $Foswiki::Plugins::SESSION
{
    package TWiki::Plugins::SESSION_TIE;
    use base 'Tie::Scalar';

    sub TIESCALAR { return bless({}, shift) }
    sub FETCH { return $Foswiki::Plugins::SESSION; }
};

tie($SESSION, 'TWiki::Plugins::SESSION_TIE');

1;
