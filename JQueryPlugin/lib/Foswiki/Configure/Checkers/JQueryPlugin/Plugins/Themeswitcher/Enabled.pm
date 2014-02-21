# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::JQueryPlugin::Plugins::Themeswitcher::Enabled;

use warnings;
use strict;

use Foswiki::Configure::Checker ();
our @ISA = qw( Foswiki::Configure::Checker );

sub check {
    my $this = shift;
    my $warnings;

    if ( $Foswiki::cfg{JQueryPlugin}{Plugins}{Themeswitcher}{Enabled} ) {
        $warnings .= $this->ERROR(<<'HERE');
Themeswitcher has been removed from Foswiki.  This should be disabled to avoid
errors during Foswiki operation.
HERE
    }

    return $warnings;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2014 Foswiki Contributors. Foswiki Contributors
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
