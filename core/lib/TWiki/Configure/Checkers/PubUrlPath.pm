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
package TWiki::Configure::Checkers::PubUrlPath;

use strict;

use TWiki::Configure::Checker;

use base 'TWiki::Configure::Checker';

sub check {
    my $this = shift;

    unless( $TWiki::cfg{PubUrlPath} && $TWiki::cfg{PubUrlPath} ne 'NOT SET') {
        my $guess = $TWiki::cfg{ScriptUrlPath};
        $guess =~ s/bin$/pub/;
        $TWiki::cfg{PubUrlPath} = $guess;
        return $this->guessed(0);
    }
    return 'This is not set correctly if the link below is broken:'.CGI::br().
      '<a rel="nofollow" href="'.$TWiki::cfg{PubUrlPath}.'">Go to &quot;pub&quot; directory</a>';
}

1;
