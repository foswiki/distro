# See bottom of file for license and copyright information
package Assert;

# Significant performance gains are delivered by exporting a constant
# DEBUG to the calling module rather than an subroutine, which the perl
# optimiser fails to see as a constant.

use strict;

our $VERSION = "1.200";
$VERSION = eval $VERSION;

use Exporter;
our @ISA = ('Exporter');

use constant DEBUG => ( $ENV{FOSWIKI_ASSERTS} ) ? 1 : 0;
our @EXPORT = qw(ASSERT UNTAINTED TAINT DEBUG);

our $soft = 0;

# Easier than farting about with AUTOLOAD; pull in the implementation we want,
# either AssertOn or AssertOff
require 'Assert' . ( DEBUG ? 'On' : 'Off' ) . '.pm';

=begin TML
---++ DEBUG
Constant indicating whether asserts are currently active. This constant is
set at the start of the program run from the environment variable
FOSWIKI_ASSERTS.

---++ ASSERT(condition [, message]) if DEBUG
Assert that =condition= returns true. =message= is used to generate a 'friendly'
error message if it is provided. The =if DEBUG= is required to give the perl
optimiser a chance to eliminate this function call if asserts are not enabled.

---++ TAINT($val) -> $var
Generate a tainted version of the variable with the same value.

---++ UNTAINTED($val) -> $boolean
Return true if the vaue passed is untainted.

=cut

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2013 Foswiki Contributors. Foswiki Contributors
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
