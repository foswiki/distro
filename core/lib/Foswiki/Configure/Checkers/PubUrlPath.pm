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
package Foswiki::Configure::Checkers::PubUrlPath;

use strict;

use Foswiki::Configure::Checker;

use base 'Foswiki::Configure::Checker';

sub check {
    my $this = shift;

    unless ( $Foswiki::cfg{PubUrlPath} && $Foswiki::cfg{PubUrlPath} ne 'NOT SET' ) {
        my $guess = $Foswiki::cfg{ScriptUrlPath};
        $guess =~ s/bin$/pub/;
        $Foswiki::cfg{PubUrlPath} = $guess;
        return $this->guessed(0);
    }
    return
        'This is not set correctly if the link below is broken:'
      . CGI::br()
      . '<a rel="nofollow" href="'
      . $Foswiki::cfg{PubUrlPath}
      . '">Go to &quot;pub&quot; directory</a>';
}

1;
