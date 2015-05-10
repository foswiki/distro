# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::DetailedOS;

use strict;
use warnings;
use CGI ();

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

sub check_current_value {
    my ( $this, $reporter ) = @_;

    if ( $Foswiki::cfg{DetailedOS} ) {
        unless ( $Foswiki::cfg{DetailedOS} eq $^O ) {
            $reporter->WARN( <<HMMM );
Your chosen value conflicts with what Perl says the
operating system is ($^O). If this wasn't intended then save a blank
value and the setting will revert to the Perl default.
HMMM
        }
    }

    my $cgiver = $CGI::VERSION || 0;

    $reporter->NOTE("You are running CGI Version $cgiver.");

    if ( $cgiver > 4.10 && $cgiver < 4.14 ) {
        $reporter->ERROR( <<OOPS );
CGI Versions 4.11 .. 4.13 are known to corrupt topic & form data.
OOPS
    }

    if ( $cgiver =~ m/^(2\.89|3\.37|3\.43|3\.47|4\.11|4\.12|4\.13)$/ ) {
        $reporter->WARN( <<HERE );
You are using a version of =CGI= that is known to have issues with Foswiki.
=CGI= should be upgraded to a version > 3.11, avoiding 3.37, 3.43, 3.47 and 4.11-4.13.
HERE
    }

    # Check for potential CGI.pm module upgrade
    # CGI.pm version, on some platforms - actually need CGI 2.93 for
    # mod_perl 2.0 and CGI 2.90 for Cygwin Perl 5.8.0.  See
    # http://perl.apache.org/products/apache-modules.html#
    #       Porting_CPAN_modules_to_mod_perl_2_0_Status
    if ( $cgiver < 2.93 ) {
        if ( $Config::Config{osname} eq 'cygwin' && $] >= 5.008 ) {

            # Recommend CGI.pm upgrade if using Cygwin Perl 5.8.0
            $reporter->WARN( <<HERE );
Perl CGI version 3.11 or higher is recommended to avoid problems with
attachment uploads on Cygwin Perl.
HERE
        }
        elsif ($Foswiki::cfg{DETECTED}{ModPerlVersion}
            && $Foswiki::cfg{DETECTED}{ModPerlVersion} >= 1.99 )
        {

            # Recommend CGI.pm upgrade if using mod_perl 2.0, which
            # is reported as version 1.99 and implies Apache 2.0
            $reporter->WARN( <<HERE );
Perl CGI version 3.11 or higher is recommended to avoid problems with
mod_perl.
HERE
        }
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
