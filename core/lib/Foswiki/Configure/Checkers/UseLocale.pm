# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::UseLocale;

use strict;
use warnings;

use Assert;
use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

use Foswiki::Configure::Dependency ();

our @required = ();

sub check_current_value {
    my ( $this, $reporter ) = @_;

    return unless $Foswiki::cfg{UseLocale};

    Foswiki::Configure::Dependency::checkPerlModules(@required);
    foreach my $mod (@required) {
        if ( !$mod->{ok} && !$mod->{optional} ) {
            $reporter->ERROR( $mod->{check_result} );
        }
        else {
            $reporter->NOTE( $mod->{check_result} );
        }
    }

    if ( $Foswiki::cfg{OS} eq 'WINDOWS' ) {

        # Warn re known broken locale setup
        $this->WARN( <<HERE );
Using Perl on Windows, which may have missing or incorrect locales (in Cygwin
or ActiveState Perl, respectively).
HERE
    }

    # Check for 'useperlio' in Config on Perl 5.8 or higher - required
    # for use of ':utf8' layer.
    if (
        $] >= 5.008
        and not( exists $Config::Config{useperlio}
            and $Config::Config{useperlio} eq 'define' )
      )
    {
        $this->WARN( <<HERE );
This version of Perl was not compiled to use PerlIO by default ('useperlio'
not set in Config.pm, see <i>Perl's Unicode Model</i> in 'perldoc
perluniintro') - re-compilation of Perl will be required before it can be
used to enable Foswiki's UTF-8 support.
HERE
    }

    # Check for d_setlocale in Config (same as 'perl -V:d_setlocale')
    eval("use Config");
    if (
        !(
            exists $Config::Config{d_setlocale}
            && $Config::Config{d_setlocale} eq 'define'
        )
      )
    {
        $this->WARN(<<HERE);
This version of Perl was not compiled with locale support ('d_setlocale' not
set in Config.pm) - re-compilation of Perl will be required before it can be
used to support internationalisation.
HERE
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
