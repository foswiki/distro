# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::WarningFileName;

use strict;
use warnings;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

use Foswiki::Configure::Load ();

sub check {
    my $this = shift;
    my $mess = '';

    if ( $Foswiki::cfg{WarningFileName} ) {
        $mess .= $this->showExpandedValue( $Foswiki::cfg{WarningFileName} );
        if ( $Foswiki::cfg{Log}{Implementation} eq
            'Foswiki::Logger::Compatibility' )
        {
            $mess .= $this->ERROR(
                <<ERROR
WarningFileName is set, your chosen logger: PlainFileLogger, is being overridden back to the Compatibility logger.
Delete this setting to use the PlainFileLogger.
ERROR
            );
        }
        else {
            $mess .= $this->NOTE(
'This setting is deprecated. Delete it unless you want to use the CompatibilityLogger'
            );
        }
    }
    else {
        if (
            $Foswiki::cfg{Log}{Implementation} eq 'Foswiki::Logger::PlainFile' )
        {
            $mess .= $this->WARN(
'This setting is recommended for the CompatibilityLogger.  If not set, logs are written to <code>$Foswiki::cfg{DataDir}/warn%DATE%.txt</code>'
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
