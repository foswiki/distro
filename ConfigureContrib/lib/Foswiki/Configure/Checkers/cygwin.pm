# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::cygwin;

=begin TML

---+ package Foswiki::Configure::Checkers::cygwin

Foswiki::Configure::Section for MSWin inspection.

SMELL: This is *not* a Checker, it is only in the Checkers package
for historical reasons and needs to be moved out.

=cut

use strict;
use warnings;

sub check {
    my $this = shift;
    return $class->SUPER::new( 'MS Windows Specific', '' );

    # Get Cygwin perl's package version number
    #    my $pkg = `perl -v`;
    #    if ($?) {
    #        return $this->WARN(<<HERE);
    #Cannot identify perl package version - cygcheck or grep not installed
    #HERE
    #    }
    #    else {
    #        $pkg = ( split ' ', $pkg )[1];    # Package version
    #        return $pkg
    #    }
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2013 Foswiki Contributors. Foswiki Contributors
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
