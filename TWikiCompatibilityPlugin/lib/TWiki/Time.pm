package TWiki::Time;

# Bridge between TWiki::Time and Foswiki::Time

use strict;

use Foswiki::Time;

use vars qw( @ISOMONTH @WEEKDAY @MONTHLENS %MON2NUM );

@ISOMONTH = @Foswiki::Time::ISOMONTH;
@WEEKDAY = @Foswiki::Time::WEEKDAY;
@MONTHLENS = @Foswiki::Time::MONTHLENS;
%MON2NUM = %Foswiki::Time::MON2NUM;

sub parseTime { Foswiki::Time::parseTime(@_) }
sub formatTime { Foswiki::Time::formatTime(@_) }
sub _weekNumber { Foswiki::Time::_weekNumber(@_) }
sub formatDelta { Foswiki::Time::formatDelta(@_) }
sub parseInterval { Foswiki::Time::parseInterval(@_) }
sub _parseDuration { Foswiki::Time::_parseDuration(@_) }

1;
