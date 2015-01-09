# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::REGEX;

use strict;
use warnings;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

# This is a generic (item-independent) checker for regular expressions.
sub check_current_value {
    my ( $this, $reporter ) = @_;

    my $str = $this->checkExpandedValue($reporter);
    return unless defined $str;

    eval { qr/$str/ };
    if ($@) {
        my $msg = Foswiki::Configure::Reporter::stripStacktrace($@);
        $reporter->ERROR(<<"MESS");
Invalid regular expression: $msg <p />
See <a href="http://www.perl.com/doc/manual/html/pod/perlre.html">perl.com</a> for help with Perl regular expressions.
MESS
    }
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2014 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
