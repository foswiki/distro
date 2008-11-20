package TWiki::Attrs;

# Bridge between TWiki::Attra and Foswiki::Attrs

use strict;

use Foswiki::Attrs;

sub new { Foswiki::Attrs::new(@_) }
sub isEmpty { Foswiki::Attrs::isEmpty(@_) }
sub remove { Foswiki::Attrs::remove(@_) }
sub stringify { Foswiki::Attrs::stringify(@_) }
sub extractValue { Foswiki::Attrs::extractValue(@_) }
sub get { Foswiki::Attrs::get(@_) }

1;
