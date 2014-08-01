# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::UseClientSessions;

use strict;
use warnings;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

my @modules = (
    {
        name            => 'CGI::Session',
        usage           => "Sessions",
        requiredVersion => 1,
    },
    {
        name               => 'CGI::Cookie',
        usage              => "Sessions",
        recommendedVersion => 1,
    },
);

sub check {
    my $this = shift;

    my $mess = '';
    if ( !eval "use CGI::Cookie; 1" ) {
        $mess .= <<HERE;
The CGI::Cookie Perl module is required for session support, but is not
available.
HERE
    }
    if ( !eval "use CGI::Session; 1" ) {
        $mess .= <<HERE;
The CGI::Session Perl module is required for session support, but is not
available.
HERE
    }
    if ($mess) {
        if ( $Foswiki::cfg{UseClientSessions} ) {
            $mess = $this->ERROR($mess);
        }
        else {
            $mess = $this->WARN($mess);
        }
    }
    return $mess;
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
