# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::RCS::SearchAlgorithm;
use base 'Foswiki::Configure::Checker';

use strict;

use Foswiki::Configure::Checker;

sub check {
    my $this = shift;

    my $mess = '';
    if ( $Foswiki::cfg{RCS}{SearchAlgorithm} =~ /Native$/ ) {
        eval 'use FoswikiNativeSearch';
        if ($@) {
            $mess .= $this->ERROR(<<EOF);
Sorry, I could not find the required components for Native search. The
error was: $@
EOF
        }
    }

    return $mess;
}

1;
__DATA__
#
# Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008 Foswiki Contributors. All Rights Reserved.
# Foswiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
#
# Copyright (C) 2000-2006 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
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
