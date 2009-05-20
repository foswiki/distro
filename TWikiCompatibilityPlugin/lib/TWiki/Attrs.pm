package TWiki::Attrs;

# Bridge between TWiki::Attra and Foswiki::Attrs

use strict;

use Foswiki::Attrs;

*{'TWiki::Attrs::'} = \*{'Foswiki::Attrs::'};

1;
