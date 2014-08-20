# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::Sessions::EnableGuestSessions;

use strict;
use warnings;

require Foswiki::Configure::Checker;
our @ISA = ('Foswiki::Configure::Checker');

sub check_current_value {
    my ($this, $reporter) = @_;

    unless ( defined $Foswiki::cfg{Sessions}{EnableGuestSessions}
        && $Foswiki::cfg{Sessions}{EnableGuestSessions} )
    {
        $reporter->WARN( <<'DONE' );
Guest sessions are disabled.  This is an experimental feature.  Some feaures of Foswiki will not work for guests unless this is enabled:
   * Commenting by guests
   * Editing by guests
   * Session variables (=%SESSIONVAR%= macro)
   * Any wiki application accessible to guests that uses POST with StrikeOne validation.
DONE
    }
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2014 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2000-2006 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root
of this distribution. NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
