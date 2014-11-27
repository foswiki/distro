package Foswiki::Contrib::DBIStoreContrib::UnitTestSetup;

# This contrib requires its companion plugin to be enabled
sub set_up {
    $Foswiki::cfg{Plugins}{DBIStorePlugin}{Module} ||=
      'Foswiki::Plugins::DBIStorePlugin';
    $Foswiki::cfg{Plugins}{DBIStorePlugin}{Enabled} = 1;
}

1;
