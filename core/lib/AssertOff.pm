# See bottom of file for license and copyright information

# This file is required from Assert.pm (or FastAssert.pm) when
# asserts are inactive; it loads the runtme implementations of the
# Assert module functions.

use strict;

sub ASSERT { }

sub UNTAINTED {
    return 1;
}

sub TAINT {
    return $_[0];
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2013 Foswiki Contributors. Foswiki Contributors

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
