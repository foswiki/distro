# See bottom of file for license and copyright information
package TWiki::Sandbox;

# Bridge between TWiki::Sandbox and Foswiki::Sandbox

use strict;
use warnings;

use Foswiki::Sandbox;

# Required because TWiki sysCommand is invoked as an object method.
sub new {
    my $class = shift;
    return bless( {}, $class );
}

sub untaintUnchecked { Foswiki::Sandbox::untaintUnchecked(@_) }

sub normalizeFileName {
    Foswiki::Sandbox::untaint( shift,
        \&Foswiki::Sandbox::validateAttachmentName );
}
sub sanitizeAttachmentName { Foswiki::Sandbox::sanitizeAttachmentName(@_) }
sub sysCommand             { return Foswiki::Sandbox::sysCommand(@_) }

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
