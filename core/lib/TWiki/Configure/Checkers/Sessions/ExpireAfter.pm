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
package TWiki::Configure::Checkers::Sessions::ExpireAfter;

use strict;

use TWiki::Configure::Checker;

use base 'TWiki::Configure::Checker';

sub check {
    my $this = shift;

    return '' unless $TWiki::cfg{UseClientSessions};

    my $e = '';
    if( $TWiki::cfg{Sessions}{ExpireAfter} < 0) {
        $e .= $this->WARN(<<'MESSAGE');
TWiki will *not* clean up sessions automatically. Make sure you
have a cron job running.
MESSAGE
    }
    return $e;
}

1;
