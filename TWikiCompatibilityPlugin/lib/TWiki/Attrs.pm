package TWiki::Attrs;

# Bridge between TWiki::Attra and Foswiki::Attrs

use strict;
use warnings;

use Foswiki::Attrs;

no strict 'refs';
*{'TWiki::Attrs::'} = \*{'Foswiki::Attrs::'};
use strict 'refs';

1;
