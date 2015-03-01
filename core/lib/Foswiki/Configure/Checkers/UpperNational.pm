# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::UpperNational;

use strict;
use warnings;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

sub check_current_value {
    my ( $this, $reporter ) = @_;

    # support upgrade from old configuration, where LowerNational and
    # UpperNational were stored as REGEX'es (now they are STRING's):
    if ( $Foswiki::cfg{UpperNational} =~ m/^\(\?-xism:(.*)\)$/ ) {
        $Foswiki::cfg{UpperNational} = $1;
    }

    if ( $] < 5.006 || !$Foswiki::cfg{UseLocale} ) {

        # Locales are off/broken, or using pre-5.6 Perl, so have to
        # explicitly list the accented characters (but not if using UTF-8)
        my $forUpperNat = join '',
          grep { uc($_) ne $_ and m/[^a-z]/ } map { chr($_) } 1 .. 255;

        if ($forUpperNat) {
            $reporter->WARN(
                <<HERE
The following upper case accented characters have been found in this locale
and should be considered for use in this parameter:
*$forUpperNat*
HERE
            );
        }
    }
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
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
