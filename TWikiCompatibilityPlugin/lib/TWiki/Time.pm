# See bottom of file for license and copyright information
package TWiki::Time;

# Bridge between TWiki::Time and Foswiki::Time

use strict;
use warnings;

use Foswiki::Time;

use vars qw( @ISOMONTH @WEEKDAY @MONTHLENS %MON2NUM );

@ISOMONTH  = @Foswiki::Time::ISOMONTH;
@WEEKDAY   = @Foswiki::Time::WEEKDAY;
@MONTHLENS = @Foswiki::Time::MONTHLENS;
%MON2NUM   = %Foswiki::Time::MON2NUM;

sub parseTime      { Foswiki::Time::parseTime(@_) }
sub formatTime     { Foswiki::Time::formatTime(@_) }
sub _weekNumber    { Foswiki::Time::_weekNumber(@_) }
sub formatDelta    { Foswiki::Time::formatDelta(@_) }
sub parseInterval  { Foswiki::Time::parseInterval(@_) }
sub _parseDuration { Foswiki::Time::_parseDuration(@_) }

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
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
