#
# Foswiki - The Free Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2000-2006 Foswiki Contributors.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.
package Foswiki::Configure::Checkers::Site::CharSet;
use base 'Foswiki::Configure::Checker';

use strict;

sub check {
    my $this = shift;

    # Extract the character set from locale and use in HTML templates
    # and HTTP headers
    unless ( defined $Foswiki::cfg{Site}{CharSet} ) {
        $Foswiki::cfg{Site}{Locale} =~ m/\.([a-z0-9_-]+)$/i;
        $Foswiki::cfg{Site}{CharSet} = $1 if defined $1;
        $Foswiki::cfg{Site}{CharSet} =~ s/^utf8$/utf-8/i;
        $Foswiki::cfg{Site}{CharSet} =~ s/^eucjp$/euc-jp/i;
        $Foswiki::cfg{Site}{CharSet} = lc $Foswiki::cfg{Site}{CharSet};
    }
    return '';
}

1;
