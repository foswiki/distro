# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::ScriptUrlPath;

use strict;
use warnings;

require Foswiki::Configure::Checkers::URLPATH;
our @ISA = ('Foswiki::Configure::Checkers::URLPATH');

sub check {
    my $this = shift;

    # Check Script URL Path against REQUEST_URI
    my $val    = $this->getCfg;
    my $report = '';
    my $guess  = $ENV{REQUEST_URI} || $ENV{SCRIPT_NAME} || '';

    if ( $val and $val ne 'NOT SET' ) {
        $report = $this->SUPER::check(@_);
        $val    = $this->getCfg;

        if ( $guess =~ s'/+configure\b.*$'' ) {
            if ( $guess !~ /^$val/ ) {
                $report .=
                  $this->WARN( 'This item is expected this to look like "'
                      . $guess
                      . '"' );
            }
        }
        else {
            $report .= $this->WARN(<< "HERE");
This web server does not set REQUEST_URI or SCRIPT_NAME
so it isn't possible to fully validate this setting.
HERE
        }
        if ( $val =~ s'/+$'' ) {
            $report .= $this->WARN(
                'A trailing / is not recommended and has been removed');
            $this->setItemValue($val);
            $this->{UpdatedValue} = $val;
        }
    }
    else {
        if ( $guess =~ s'/+configure\b.*$'' ) {
            $this->{GuessedValue} = $guess;
            $this->setItemValue($guess);
            $report .= $this->SUPER::check(@_);
        }
        else {
            $report .= $this->WARN(<< "HERE");
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
