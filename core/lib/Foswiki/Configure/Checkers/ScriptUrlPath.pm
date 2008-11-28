# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::ScriptUrlPath;

use strict;

use Foswiki::Configure::Checker;

use base 'Foswiki::Configure::Checker';

sub check {
    my $this = shift;

    # Check Script URL Path against REQUEST_URI
    my $n;
    my $val    = $Foswiki::cfg{ScriptUrlPath};
    my $report = '';

    my $guess = $ENV{REQUEST_URI} || $ENV{SCRIPT_NAME} || '';
    $guess =~ s(/+configure\b.*$)();

    if ( defined $val && $val ne 'NOT SET' ) {
        if ($guess) {
            if ( $guess !~ /^$val/ ) {
                $report .= $this->WARN(
                    'I expected this to look like "' . $guess . '"' );
            }
        }
        else {
            $report .= $this->WARN(<<HERE);
This web server does not set REQUEST_URI or SCRIPT_NAME
so it isn't possible to fully check the correctness of this setting.
HERE
        }
        if ( $val =~ m!/$! ) {
            $report .= $this->WARN(
'Don\'t put a / at the end of the path. It\'ll still work, but you will get double // in a few places.'
            );
        }
    }
    else {
        if ($guess) {
            $report .= $this->guessed(0);
        }
        else {
            $report .= $this->WARN(<<HERE);
This web server does not set REQUEST_URI or SCRIPT_NAME
so it isn't possible to guess this setting.
HERE
            $guess = '';
        }
        $Foswiki::cfg{ScriptUrlPath} = $guess;
    }
    return $report;
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
