# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Time

Time handling functions.

*Since* _date_ indicates where functions or parameters have been added since
the baseline of the API (TWiki release 4.2.3). The _date_ indicates the
earliest date of a Foswiki release that will support that function or
parameter.

*Deprecated* _date_ indicates where a function or parameters has been
[[http://en.wikipedia.org/wiki/Deprecation][deprecated]]. Deprecated
functions will still work, though they should
_not_ be called in new plugins and should be replaced in older plugins
as soon as possible. Deprecated parameters are simply ignored in Foswiki
releases after _date_.

*Until* _date_ indicates where a function or parameter has been removed.
The _date_ indicates the latest date at which Foswiki releases still supported
the function or parameter.

=cut

# THIS PACKAGE IS PART OF THE PUBLISHED API USED BY EXTENSION AUTHORS.
# DO NOT CHANGE THE EXISTING APIS (well thought out extensions are OK)
# AND ENSURE ALL POD DOCUMENTATION IS COMPLETE AND ACCURATE.

package Foswiki::Time;

use strict;
use warnings;

use Assert;

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

# In some environments, e.g. configure, we do NOT want Foswiki.pm
# use Foswiki::Time qw/-nofoswiki/ for that.  Since this module
# doesn't use Exporter, we don't need anything complicated.

sub import {
    my $class = shift;

    unless ( @_ && $_[0] eq '-nofoswiki' ) {
        require Foswiki;
    }
}

use POSIX qw( strftime );

# Constants
our @ISOMONTH = (
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
);

our @MONTHLENS = ( 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 );

our @WEEKDAY = ( 'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun' );

our %MON2NUM = (
    jan => 0,
    feb => 1,
    mar => 2,
    apr => 3,
    may => 4,
    jun => 5,
    jul => 6,
    aug => 7,
    sep => 8,
    oct => 9,
    nov => 10,
    dec => 11
);

=begin TML

---++ StaticMethod parseTime( $szDate, $defaultLocal ) -> $iSecs

Convert string date/time string to seconds since epoch (1970-01-01T00:00:00Z).
   * =$sDate= - date/time string

Handles the following formats:

Default Foswiki format
   * 31 Dec 2001 - 23:59
   * 31-Dec-2001 - 23:59

Foswiki format without time (defaults to 00:00)
   * 31 Dec 2001
   * 31-Dec-2001

Date separated by '/', '.' or '-', time with '.' or ':'
Date and time separated by ' ', '.' and/or '-'
   * 2001/12/31 23:59:59
   * 2001.12.31.23.59.59
   * 2001/12/31 23:59
   * 2001.12.31.23.59
   * 2001-12-31 23:59
   * 2001-12-31 - 23:59
   * 2009-1-12
   * 2009-1
   * 2009

ISO format
   * 2001-12-31T23:59:59
   * 2001-12-31T

ISO dates may have a timezone specifier, either Z or a signed difference
in hh:mm format. For example:
   * 2001-12-31T23:59:59+01:00
   * 2001-12-31T23:59Z
The default timezone is Z, unless $defaultLocal is true in which case
the local timezone will be assumed.

If the date format was not recognised, will return undef.

=cut

sub parseTime {
    my ( $date, $defaultLocal ) = @_;

    ASSERT( defined $date ) if DEBUG;
    $date =~ s/^\s*//;    #remove leading spaces without de-tainting.
    $date =~ s/\s*$//;

    use Time::Local qw( timelocal timegm);

    # NOTE: This routine *will break* if input is not one of below formats!
    my $timelocal =
      $defaultLocal
      ? \&Time::Local::timelocal
      : \&Time::Local::timegm;

    # try "31 Dec 2001 - 23:59"  (Foswiki date)
    # or "31 Dec 2001"
    #TODO: allow /.: too
    if ( $date =~
        m/(\d+)[-\s]+([a-z]{3})[-\s]+(\d+)(?:[-\s]+(\d+):(\d+)(?::(\d+))?)?/i )
    {
        my $year = $3;

        #$year -= 1900 if ( $year > 1900 );

        my $mon = $MON2NUM{ lc($2) };
        return undef unless defined $mon;

        #TODO: %MON2NUM needs to be updated to use i8n
        #TODO: and should really work for long form of the month name too.
        return &$timelocal( $6 || 0, $5 || 0, $4 || 0, $1, $mon, $year );
    }

    # ISO date 2001-12-31T23:59:59+01:00
    # Sven is going to presume that _all_ ISO dated must have a 'T' in them.
    if (
        ( $date =~ m/T/ )
        && ( $date =~
m/(\d\d\d\d)(?:-(\d\d)(?:-(\d\d))?)?(?:T(\d\d)(?::(\d\d)(?::(\d\d(?:\.\d+)?))?)?)?(Z|[-+]\d\d(?::\d\d)?)?/
        )
      )
    {
        my ( $Y, $M, $D, $h, $m, $s, $tz ) =
          ( $1, $2 || 1, $3 || 1, $4 || 0, $5 || 0, $6 || 0, $7 || '' );
        $M--;

        #$Y -= 1900 if ( $Y > 1900 );
        if ($tz) {
            my $tzadj = 0;
            if ( $tz eq 'Z' ) {
                $tzadj = 0;    # Zulu
            }
            elsif ( $tz =~ m/([-+])(\d\d)(?::(\d\d))?/ ) {
                $tzadj = ( $1 || '' ) . ( ( ( $2 * 60 ) + ( $3 || 0 ) ) * 60 );
                $tzadj -= 0;
            }
            return Time::Local::timegm( $s, $m, $h, $D, $M, $Y ) - $tzadj;
        }
        return &$timelocal( $s, $m, $h, $D, $M, $Y );
    }

    #any date that leads with a year (2 digit years too)
    if (
        $date =~ m|^
                    (\d\d+)                                 #year
                    (?:\s*[/\s.-]\s*                        #datesep
                        (\d\d?)                             #month
                        (?:\s*[/\s.-]\s*                    #datesep
                            (\d\d?)                         #day
                            (?:\s*[/\s.-]\s*                #datetimesep
                                (\d\d?)                     #hour
                                (?:\s*[:.]\s*               #timesep
                                    (\d\d?)                 #min
                                    (?:\s*[:.]\s*           #timesep
                                        (\d\d?)
                                    )?
                                )?
                            )?
                        )?
                    )?
                    $|x
      )
    {

        #no defaulting yet so we can detect the 2009--12 error
        my ( $year, $M, $D, $h, $m, $s ) = ( $1, $2, $3, $4, $5, $6 );

    # without range checking on the 12 Jan 2009 case above,
    # there is ambiguity - what is 14 Jan 12 ?
    # similarly, how would you decide what Jan 02 and 02 Jan are?
    #$month_p = $MON2NUM{ lc($month_p) } if (defined($MON2NUM{ lc($month_p) }));

        #TODO: unhappily, this means 09 == 1909 not 2009
        #$year -= 1900 if ( $year > 1900 );

        #range checks
        return undef if ( defined($M) && ( $M < 1 || $M > 12 ) );
        my $month = ( $M || 1 ) - 1;
        my $monthlength = $MONTHLENS[$month];

        # If leap year, note February is month number 1 starting from 0
        $monthlength = 29 if ( $month == 1 && _daysInYear($year) == 366 );
        return undef if ( defined($D) && ( $D < 0 || $D > $monthlength ) );
        return undef if ( defined($h) && ( $h < 0 || $h > 24 ) );
        return undef if ( defined($m) && ( $m < 0 || $m > 60 ) );
        return undef if ( defined($s) && ( $s < 0 || $s > 60 ) );

        #return undef if ( defined($year) && $year < 60 );

        my $day  = $D || 1;
        my $hour = $h || 0;
        my $min  = $m || 0;
        my $sec  = $s || 0;

        return &$timelocal( $sec, $min, $hour, $day, $month, $year );
    }

    # give up, return undef
    return undef;
}

=begin TML

---++ StaticMethod formatTime ($epochSeconds, $formatString, $outputTimeZone) -> $value

   * =$epochSeconds= epochSecs GMT
   * =$formatString= Foswiki time date format, default =$day $month $year - $hour:$min=
   * =$outputTimeZone= timezone to display, =gmtime= or =servertime=, default is whatever is set in $Foswiki::cfg{DisplayTimeValues}

=$formatString= supports:
   | $seconds | secs |
   | $minutes | mins |
   | $hours | hours |
   | $day | day |
   | $wday | weekday name |
   | $dow | day number (0 = Sunday) |
   | $week | week number |
   | $we | week number (~ISO 8601) |
   | $month | month name |
   | $mo | month number |
   | $year | 4-digit year |
   | $ye | 2-digit year |
   | $http | ful HTTP header format date/time |
   | $email | full email format date/time |
   | $rcs | full RCS format date/time |
   | $epoch | seconds since 1st January 1970 |
   | $tz | Timezone name (GMT or Local) |
   | $isotz | ISO 8601 timezone specifier e.g. 'Z, '+07:15' |

=cut

# previous known as Foswiki::formatTime

sub formatTime {
    my ( $epochSeconds, $formatString, $outputTimeZone ) = @_;
    my $value = $epochSeconds;

    ASSERT( defined $epochSeconds ) if DEBUG;

    # use default Foswiki format "31 Dec 1999 - 23:59" unless specified
    $formatString   ||= '$longdate';
    $outputTimeZone ||= $Foswiki::cfg{DisplayTimeValues};

    if ( $formatString =~ m/http/i ) {
        $outputTimeZone = 'gmtime';
    }

    my ( $sec, $min, $hour, $day, $mon, $year, $wday, $yday, $isdst );
    my ( $tz_str, $isotz_str );
    if ( $outputTimeZone eq 'servertime' ) {
        ( $sec, $min, $hour, $day, $mon, $year, $wday, $yday, $isdst ) =
          localtime($epochSeconds);

        # SMELL: how do we get the different timezone strings (and when
        # we add usertime, then what?)
        $tz_str = 'Local';

        # isotz_str is date dependant, ie different in summer and winter time
        $isotz_str = strftime(
            '%z', $sec,  $min,  $hour, $day,
            $mon, $year, $wday, $yday, $isdst
        );
        $isotz_str =~ s/([+-]\d\d)(\d\d)/$1:$2/;
    }
    else {
        ( $sec, $min, $hour, $day, $mon, $year, $wday, $yday ) =
          gmtime($epochSeconds);
        $tz_str    = 'GMT';
        $isotz_str = 'Z';
    }

    #standard Foswiki date time formats

    # RCS format, example: "2001/12/31 23:59:59"
    $formatString =~ s/\$rcs/\$year\/\$mo\/\$day \$hour:\$min:\$sec/gi;

    # HTTP and email header format, e.g. "Thu, 23 Jul 1998 07:21:56 EST"
    # RFC 822/2616/1123
    $formatString =~
      s/\$(http|email)/\$wday, \$day \$month \$year \$hour:\$min:\$sec \$tz/gi;

    # ISO Format, see spec at http://www.w3.org/TR/NOTE-datetime
    # e.g. "2002-12-31T19:30:12Z"
    # Undocumented: formatString='iso'
    $formatString = '$year-$mo-$dayT$hour:$min:$sec$isotz'
      if lc($formatString) eq 'iso';

    # Undocumented, but used in renderers: formatString can contain '$iso'
    $formatString =~ s/\$iso\b/\$year-\$mo-\$dayT\$hour:\$min:\$sec\$isotz/gi;

    # longdate
    $formatString =~
      s/\$longdate/$Foswiki::cfg{DefaultDateFormat} - \$hour:\$min/gi;

    $value = $formatString;
    $value =~ s/\$seco?n?d?s?/sprintf('%.2u',$sec)/gei;
    $value =~ s/\$minu?t?e?s?/sprintf('%.2u',$min)/gei;
    $value =~ s/\$hour?s?/sprintf('%.2u',$hour)/gei;
    $value =~ s/\$day/sprintf('%.2u',$day)/gei;
    $value =~ s/\$wday/$WEEKDAY[$wday]/gi;
    $value =~ s/\$dow/$wday/gi;
    $value =~ s/\$week/_weekNumber($wday, $yday, $year + 1900)/egi;
    $value =~ s/\$we/substr('0'._weekNumber($wday, $yday, $year + 1900),-2)/egi;
    $value =~ s/\$mont?h?/$ISOMONTH[$mon]/gi;
    $value =~ s/\$mo/sprintf('%.2u',$mon+1)/gei;
    $value =~ s/\$year?/sprintf('%.4u',$year + 1900)/gei;
    $value =~ s/\$ye/sprintf('%.2u',$year%100)/gei;
    $value =~ s/\$epoch/$epochSeconds/gi;
    $value =~ s/\$tz/$tz_str/gi;
    $value =~ s/\$isotz/$isotz_str/gi;

    return $value;
}

# Returns the ISO8601 week number for a date.
# Year is the real year
# Day of week is 0..6 where 0==Sunday
# Day of year is 0..364 (or 365) where 0==Jan1
# From http://www.perlmonks.org/?node_id=710571
sub _weekNumber {
    my ( $dayOfWeek, $dayOfYear, $year ) = @_;

    # rebase dow to Monday==0
    $dayOfWeek = ( $dayOfWeek + 6 ) % 7;

    # Locate the nearest Thursday, by locating the Monday at
    # or before and going forwards 3 days)
    my $dayOfNearestThurs = $dayOfYear - $dayOfWeek + 3;

    my $daysInThisYear = _daysInYear($year);

#print STDERR "dow:$dayOfWeek, doy:$dayOfYear, $year = thu:$dayOfNearestThurs ($daysInThisYear)\n";

    # Is nearest thursday in last year or next year?
    if ( $dayOfNearestThurs < 0 ) {

        # Nearest Thurs is last year
        # We are at the start of the year
        # Adjust by the number of days in LAST year
        $dayOfNearestThurs += _daysInYear( $year - 1 );
    }
    if ( $dayOfNearestThurs >= $daysInThisYear ) {

        # Nearest Thurs is next year
        # We are at the end of the year
        # Adjust by the number of days in THIS year
        $dayOfNearestThurs -= $daysInThisYear;
    }

    # Which week does the Thurs fall into?
    return int( $dayOfNearestThurs / 7 ) + 1;
}

# Returns the number of...
sub _daysInYear {
    return 366 unless $_[0] % 400;
    return 365 unless $_[0] % 100;
    return 366 unless $_[0] % 4;
    return 365;
}

=begin TML

---++ StaticMethod formatDelta( $s ) -> $string

Format a time in seconds as a string. For example,
"1 day, 3 hours, 2 minutes, 6 seconds"

=cut

sub formatDelta {
    my $secs     = shift;
    my $language = shift;

    ASSERT( defined $secs ) if DEBUG;
    my $rem = $secs % ( 60 * 60 * 24 );
    my $days = ( $secs - $rem ) / ( 60 * 60 * 24 );
    $secs = $rem;

    $rem = $secs % ( 60 * 60 );
    my $hours = ( $secs - $rem ) / ( 60 * 60 );
    $secs = $rem;

    $rem = $secs % 60;
    my $mins = ( $secs - $rem ) / 60;
    $secs = $rem;

    my $str = '';

    if ($language) {

        #format as in user's language
        if ($days) {
            $str .= $language->maketext( '[*,_1,day] ', $days );
        }
        if ($hours) {
            $str .= $language->maketext( '[*,_1,hour] ', $hours );
        }
        if ($mins) {
            $str .= $language->maketext( '[*,_1,minute] ', $mins );
        }
        if ($secs) {
            $str .= $language->maketext( '[*,_1,second] ', $secs );
        }
    }
    else {

        #original code, harcoded English (BAD)
        if ($days) {
            $str .= $days . ' day' . ( $days > 1 ? 's ' : ' ' );
        }
        if ($hours) {
            $str .= $hours . ' hour' . ( $hours > 1 ? 's ' : ' ' );
        }
        if ($mins) {
            $str .= $mins . ' minute' . ( $mins > 1 ? 's ' : ' ' );
        }
        if ($secs) {
            $str .= $secs . ' second' . ( $secs > 1 ? 's ' : ' ' );
        }
    }
    $str =~ s/\s+$//;
    return $str;
}

=begin TML

---++ StaticMethod parseInterval( $szInterval ) -> [$iSecs, $iSecs]

Convert string representing a time interval to a pair of integers
representing the amount of seconds since epoch for the start and end
extremes of the time interval.

   * =$szInterval= - time interval string

in yacc syntax, grammar and actions:
<verbatim>
interval ::= date                 { $$.start = fillStart($1); $$.end = fillEnd($1); }
         | date '/' date          { $$.start = fillStart($1); $$.end = fillEnd($3); }
         | 'P' duration '/' date  { $$.start = fillEnd($4)-$2; $$.end = fillEnd($4); }
         | date '/' 'P' duration  { $$.start = fillStart($1); $$.end = fillStart($1)+$4; }
         ;
</verbatim>
an =interval= may be followed by a timezone specification string (this is not supported yet).

=duration= has the form (regular expression):
<verbatim>
   P(<number><nameOfDuration>)+
</verbatim>

nameOfDuration may be one of:
   * y(year), m(month), w(week), d(day), h(hour), M(minute), S(second)

=date= follows ISO8601 and must include hyphens.  (any amount of trailing
       elements may be omitted and will be filled in differently on the
       differents ends of the interval as to include the longest possible
       interval):

   * 2001-01-01T00:00:00
   * 2001-12-31T23:59:59

timezone is optional. Default is local time.

If the format is not recognised, will return empty interval [0,0].

=cut

# TODO: timezone testing, especially on non valid strings

sub parseInterval {
    my ($interval) = @_;
    my @lt = localtime();
    my $today = sprintf( '%04d-%02d-%02d', $lt[5] + 1900, $lt[4] + 1, $lt[3] );
    my $now = $today . sprintf( 'T%02d:%02d:%02d', $lt[2], $lt[1], $lt[0] );

    ASSERT( defined $interval ) if DEBUG;

    # replace $now and $today shortcuts
    $interval =~ s/\$today/$today/g;
    $interval =~ s/\$now/$now/g;

    # if $theDate does not contain a '/': force it to do so.
    $interval = $interval . '/' . $interval
      unless ( $interval =~ m/\// );

    my ( $first, $last ) = split( /\//, $interval, 2 );
    my ( $start, $end );

    # first translate dates into seconds from epoch,
    # in the second loop we will examine interval durations.

    if ( $first !~ /^P/ ) {

        # complete with parts from "-01-01T00:00:00"
        if ( length($first) < length('0000-01-01T00:00:00') ) {
            $first .= substr( '0000-01-01T00:00:00', length($first) );
        }
        $start = parseTime( $first, 1 );
    }

    if ( $last !~ /^P/ ) {

        # complete with parts from "-12-31T23:59:60"
        # check last day of month
        if ( length($last) == 7 ) {
            my $month = substr( $last, 5 );
            my $year = substr( $last, 0, 4 );
            my $monthlength = $MONTHLENS[ $month - 1 ];

            # If leap year, note February is month number 2 here
            $monthlength = 29 if ( $month == 2 && _daysInYear($year) == 366 );
            $last .= '-' . $monthlength;
        }
        if ( length($last) < length('0000-12-31T23:59:59') ) {
            $last .= substr( '0000-12-31T23:59:59', length($last) );
        }
        $end = parseTime( $last, 1 );
    }

    if ( !defined($start) ) {
        $start = ( $end || 0 ) - _parseDuration($first);
    }
    if ( !defined($end) ) {
        $end = $start + _parseDuration($last);
    }
    return ( $start || 0, $end || 0 );
}

sub _parseDuration {
    my $s = shift;
    my $d = 0;
    $s =~ s/(\d+)y/$d += $1 * 31556925;''/gei;    # tropical year
    $s =~ s/(\d+)m/$d += $1 * 2592000; ''/ge;     # 1m = 30 days
    $s =~ s/(\d+)w/$d += $1 * 604800;  ''/gei;    # 1w = 7 days
    $s =~ s/(\d+)d/$d += $1 * 86400;   ''/gei;    # 1d = 24 hours
    $s =~ s/(\d+)h/$d += $1 * 3600;    ''/gei;    # 1 hour = 60 mins
    $s =~ s/(\d+)M/$d += $1 * 60;      ''/ge;     # note: m != M
    $s =~ s/(\d+)S/$d += $1 * 1;       ''/gei;
    return $d;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2013 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2002 John Talintyre, john.talintyre@btinternet.com
Copyright (C) 2002-2007  TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root of
this distribution.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
