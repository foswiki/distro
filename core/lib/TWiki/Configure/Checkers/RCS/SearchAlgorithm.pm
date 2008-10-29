#
# TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2006 TWiki Contributors.
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
package TWiki::Configure::Checkers::RCS::SearchAlgorithm;
use base 'TWiki::Configure::Checker';

use strict;

use TWiki::Configure::Checker;

sub check {
    my $this = shift;

    my $mess = '';
    if( $TWiki::cfg{RCS}{SearchAlgorithm} =~ /Native$/) {
        eval 'use NativeTWikiSearch';
        if ($@) {
            $mess .= $this->ERROR(<<EOF);
Sorry, I could not find the required components for Native search. The
error was: $@
EOF
        }
    }

    return $mess;
};

1;
