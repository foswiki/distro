# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::OS;

use strict;
use warnings;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

sub check_current_value {
    my ( $this, $reporter ) = @_;

    return unless $Foswiki::cfg{OS};    # Default
    my $expected = 'UNIX';

    if ( $^O =~ m/darwin/i ) {          # MacOS X
        $expected = 'UNIX';
    }
    elsif ( $^O =~ m/Win/i ) {
        $expected = 'WINDOWS';
    }
    elsif ( $^O =~ m/vms/i ) {
        $expected = 'VMS';
    }
    elsif ( $^O =~ m/bsdos/i ) {
        $expected = 'UNIX';
    }
    elsif ( $^O =~ m/solaris/i ) {
        $expected = 'UNIX';
    }
    elsif ( $^O =~ m/dos/i ) {
        $expected = 'DOS';
    }
    elsif ( $^O =~ m/^MacOS$/i ) {

        # MacOS 9 or earlier
        $expected = 'MACINTOSH';
    }
    elsif ( $^O =~ m/os2/i ) {
        $expected = 'OS2';
    }

    if ( $Foswiki::cfg{OS} ne $expected ) {
        $reporter->WARN( <<HMMM );
Your chosen value conflicts with what Perl says the operating
system is ($^O = $expected). If this wasn't intended then save a blank
value and the setting will revert to the Perl default.
HMMM
    }
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2014 Foswiki Contributors. Foswiki Contributors
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
