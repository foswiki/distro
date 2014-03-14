# See bottom of file for default license and copyright information

=begin TML

---+ package Foswiki::Contrib::CpanContrib

This is a stub module for a new contrib. Customise this module as
required.  It is typically not used by the Contrib.  Foswiki does not load it
automatically.  It is used by the Extensions Installer to detect the currently
installed version of the Contrib.

=cut

# change the package name!!!
package Foswiki::Contrib::CpanContrib;

# Always use strict to enforce variable scoping
use strict;
use warnings;

# $VERSION is referred to by Foswiki, and is the only global variable that
# *must* exist in this package.  Use "v1.2.3" format for releases,  and
# "v1.2.3_001" for "alpha" versions. The v prefix is required.
# These statements MUST be on the same line.
# See "perldoc version" for more information on version strings.
#
# Note:  Alpha versions compare as numerically lower than the non-alpha version
# so the versions in ascending order are:
#   v1.2.1_001 -> v1.2.1 -> v1.2.2_001 -> v1.2.2
#
use version; our $VERSION = version->declare("v1.0.0_001");

# $RELEASE is used in the "Find More Extensions" automation in configure.
# It is a manually maintained string used to identify functionality steps.
# You can use any of the following formats:
# tuple   - a sequence of integers separated by . e.g. 1.2.3. The numbers
#           usually refer to major.minor.patch release or similar. You can
#           use as many numbers as you like e.g. '1' or '1.2.3.4.5'.
# isodate - a date in ISO8601 format e.g. 2009-08-07
# date    - a date in 1 Jun 2009 format. Three letter English month names only.
# Note: it's important that this string is exactly the same in the extension
# topic - if you use %$RELEASE% with BuildContrib this is done automatically.
# It is preferred to keep this compatible with $VERSION. At some future
# date, Foswiki will deprecate RELEASE and use the VERSION string.
#
our $RELEASE = '15 Mar 2014';

# One-line description of the module
our $SHORTDESCRIPTION = 'CpanContrib ships basic CPAN modules Foswiki relies on.';

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2014 Foswiki Contributors. Foswiki Contributors
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
