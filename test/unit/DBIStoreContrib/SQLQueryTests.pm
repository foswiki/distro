package SQLQueryTests;
use strict;
use warnings;

# Re-use the standard unit tests
use QueryTests;
our @ISA = qw( QueryTests );

use Foswiki::Store ();

sub loadExtraConfig {
    my $this    = shift;    # the Test::Unit::TestCase object
    my $context = shift;

    $this->SUPER::loadExtraConfig( $context, @_ );

    if ( !defined &Foswiki::Store::recordChange ) {
        $Foswiki::cfg{Plugins}{DBIStorePlugin}{Module} =
          'Foswiki::Plugins::DBIStorePlugin';
        $Foswiki::cfg{Plugins}{DBIStorePlugin}{Enabled} = 1;
    }
}

sub test_match_field {
    shift->SUPER::test_match_field(@_);
}

1;
