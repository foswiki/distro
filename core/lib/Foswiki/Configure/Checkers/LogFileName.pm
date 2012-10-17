# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::LogFileName;

use strict;
use warnings;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

use Foswiki::Configure::Load ();

sub check {
    my $this = shift;
    my $mess = '';
    unless (
        $Foswiki::cfg{Log}{Implementation} eq 'Foswiki::Logger::Compatibility' )
    {

        $mess .= $this->NOTE( <<NOTE );
This setting might be used by old plugins that have not been migrated to the Foswiki API.
If not provided, Foswik core will provide a default setting of  <code>$Foswiki::cfg{Log}{Dir}/event.log</code>.
NOTE
        my $logger = $Foswiki::cfg{Log}{Implementation};
        $logger =~ s/Foswiki::Logger:://;
        $mess .= $this->NOTE("It is not used by the $logger logger.");
    }
    if ( $Foswiki::cfg{LogFileName} ) {
        $mess .= $this->showExpandedValue( $Foswiki::cfg{LogFileName} );
    }
    else {
        if ( $Foswiki::cfg{Log}{Implementation} eq
            'Foswiki::Logger::Compatibility' )
        {
            $mess .= $this->WARN(
'This setting is recommended for the CompatibilityLogger.  If not set, logs are written to <code>$Foswiki::cfg{DataDir}/log%DATE%.txt</code>'
            );
        }
    }

    return $mess;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2012 Foswiki Contributors. Foswiki Contributors
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
