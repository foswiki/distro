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
package TWiki::Configure::Checkers::ScriptUrlPath;

use strict;

use TWiki::Configure::Checker;

use base 'TWiki::Configure::Checker';

sub check {
    my $this = shift;

    # Check Script URL Path against REQUEST_URI
    my $n;
    my $val = $TWiki::cfg{ScriptUrlPath};
    my $report = '';

    my $guess = $ENV{REQUEST_URI} || $ENV{SCRIPT_NAME} || '';
    $guess =~ s(/+configure\b.*$)();

    if( defined $val && $val ne 'NOT SET' ) {
        if( $guess ) {
            if ( $guess !~ /^$val/ ) {
                $report .= $this->WARN('I expected this to look like "'.$guess.'"');
            }
        } else {
            $report .= $this->WARN(<<HERE);
This web server does not set REQUEST_URI or SCRIPT_NAME
so it isn't possible to fully check the correctness of this setting.
HERE
        }
        if ($val =~ m!/$!) {
            $report .= $this->WARN('Don\'t put a / at the end of the path. It\'ll still work, but you will get double // in a few places.');
        }
    } else {
        if( $guess ) {
            $report .= $this->guessed(0);
        } else {
            $report .= $this->WARN(<<HERE);
This web server does not set REQUEST_URI or SCRIPT_NAME
so it isn't possible to guess this setting.
HERE
            $guess = '';
        }
        $TWiki::cfg{ScriptUrlPath} = $guess;
    }
    return $report;
}

1;
