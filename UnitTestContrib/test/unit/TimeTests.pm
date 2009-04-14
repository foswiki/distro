# tests for Foswiki::Time

package TimeTests;
use base qw( FoswikiTestCase );

use strict;
use Foswiki::Time;
require POSIX;
use Time::Local;

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();
    $ENV{TZ} = 'GMT';    # GMT
    POSIX::tzset();
    undef $Foswiki::Time::TZSTRING;
}

sub tear_down {
    my $this = shift;
    $this->SUPER::tear_down();    # should restore $ENV{TZ}
    POSIX::tzset();
    undef $Foswiki::Time::TZSTRING;
}

sub showTime {
    my $t    = shift;
    my @time = gmtime($t);
    $#time = 5;
    $time[4]++;                   # month
    $time[5] += 1900;
    return sprintf( "%04d:%02d:%02dT%02d:%02d:%02dZ", reverse @time );
}

sub checkTime {
    my ( $this, $s, $m, $h, $D, $M, $Y, $str, $dl ) = @_;
    $Y -= 1900;
    $M--;
    my $gmt = timegm( $s, $m, $h, $D, $M, $Y );
    my $tt = Foswiki::Time::parseTime( $str, $dl );
    $this->assert_equals( $gmt, $tt,
        showTime($tt) . ' != ' . showTime($gmt) . ' ' . join( ' ', caller ) );
}

sub test_parseTimeFoswiki {
    my $this = shift;
    $this->checkTime( 0, 1, 18, 10, 12, 2001, "10 Dec 2001 - 18:01" );
    $this->checkTime( 0, 0, 0,  10, 12, 2001, "10 Dec 2001" );
}

sub test_parseTimeRCS {
    my $this = shift;
    $this->checkTime( 2, 1,  18, 2, 12, 2001, "2001/12/2 18:01:02" );
    $this->checkTime( 3, 2,  1,  2, 12, 2001, "2001.12.2.01.02.03" );
    $this->checkTime( 0, 59, 21, 2, 12, 2001, "2001/12/2 21:59" );
    $this->checkTime( 0, 59, 21, 2, 12, 2001, "2001-12-02 21:59" );
    $this->checkTime( 0, 59, 21, 2, 12, 2001, "2001-12-02 - 21:59" );
    $this->checkTime( 0, 59, 21, 2, 12, 2001, "2001-12-02.21:59" );
    $this->checkTime( 0, 59, 23, 2, 12, 1976, "1976.12.2.23.59" );
    $this->checkTime( 2, 1,  18, 2, 12, 2001, "2001-12-02 18:01:02" );
    $this->checkTime( 2, 1,  18, 2, 12, 2001, "2001-12-02 - 18:01:02" );
    $this->checkTime( 2, 1,  18, 2, 12, 2001, "2001-12-02-18:01:02" );
    $this->checkTime( 2, 1,  18, 2, 12, 2001, "2001-12-02.18:01:02" );
}

sub test_parseTimeISO8601 {
    my $this = shift;

    $this->checkTime( 0, 0,  0,  4, 2, 1995, "1995-02-04" );
    $this->checkTime( 0, 0,  0,  1, 2, 1995, "1995-02" );
    $this->checkTime( 0, 0,  0,  1, 1, 1995, "1995" );
    $this->checkTime( 7, 59, 20, 3, 7, 1995, "1995-07-03T20:59:07" );
    $this->checkTime( 0, 59, 23, 3, 7, 1995, "1995-07-03T23:59" );
    $this->checkTime( 0, 0,  23, 2, 7, 1995, "1995-07-02T23" );
    $this->checkTime( 7, 59, 5,  2, 7, 1995, "1995-07-02T06:59:07+01:00" );
    $this->checkTime( 7, 59, 5,  2, 7, 1995, "1995-07-02T06:59:07+01" );
    $this->checkTime( 7, 59, 6,  2, 7, 1995, "1995-07-02T06:59:07Z" );

    $ENV{TZ} = 'Europe/Paris';    # GMT + 1
    POSIX::tzset();

    # Generate server time string
    $this->checkTime( 7, 59, 5, 2, 4, 1995, "1995-04-02T06:59:07",  1 );
    $this->checkTime( 7, 59, 6, 2, 4, 1995, "1995-04-02T06:59:07Z", 1 );

}

sub test_parseTimeLocal {
    my $this = shift;
    $ENV{TZ} = 'Australia/Lindeman';
    POSIX::tzset();
    undef $Foswiki::Time::TZSTRING;
    $this->checkTime( 13, 9, 16, 7, 11, 2006, "2006-11-08T02:09:13", 1 );

    # Ensure TZ specifier in string overrides parameter
    $this->checkTime( 46, 25, 14, 7, 11, 2006, "2006-11-07T14:25:46Z", 1 );
}

sub test_generateIsoOffset {
    my $this = shift;

    # Nepal has a wierd TZ difference; handy
    $ENV{TZ} = 'Asia/Katmandu';    # GMT+05:45
    POSIX::tzset();
    undef $Foswiki::Time::TZSTRING;
    my $tt = Foswiki::Time::parseTime('2009-02-07T10:22+05:45');
    # Should be 04:37 GMT
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime($tt);
    $this->assert_equals(4, $hour);
    $this->assert_equals(37, $min);
    # Generate server time string
    $this->assert_str_equals( '2009-02-07T10:22:00+05:45',
        Foswiki::Time::formatTime( $tt, 'iso', 'servertime' ) );
    $tt = Foswiki::Time::parseTime('2009-02-07T00:00Z');
    $this->assert_str_equals( '2009-02-07T05:45:00+05:45',
        Foswiki::Time::formatTime( $tt, 'iso', 'servertime' ) );
}

sub test_checkInterval {
    my $this = shift;

    $ENV{TZ} = 'GMT';
    POSIX::tzset();
    undef $Foswiki::Time::TZSTRING;

    my $basetime = 1000000000;
    my $start = Foswiki::Time::formatTime( $basetime, 'iso', 'gmtime' );
    my $end = Foswiki::Time::formatTime( $basetime + 500000, 'iso', 'gmtime' );
    my $gap = 31556925 + 2592000 + 604800 + 86400 + 3600 + 60 + 1;
    my $gap2 =
      2 * 31556925 +
      2 * 2592000 +
      2 * 604800 +
      2 * 86400 +
      2 * 3600 +
      2 * 60 + 2;

    my $interval = "$start/$end";
    my ( $s, $e ) = Foswiki::Time::parseInterval($interval);
    $this->assert_equals( $basetime,          $s );
    $this->assert_equals( $basetime + 500000, $e );

    $interval = "$start/P1y1m1w1d1h1M1s";
    ( $s, $e ) = Foswiki::Time::parseInterval($interval);
    $this->assert_equals( $basetime,        $s );
    $this->assert_equals( $basetime + $gap, $e );

    $interval = "$start/P2s2M2h2d2w2m2y";
    ( $s, $e ) = Foswiki::Time::parseInterval($interval);
    $this->assert_equals( $basetime,         $s );
    $this->assert_equals( $basetime + $gap2, $e );
    $interval = "$start/P1y1m1w1d1h1M1s";
    ( $s, $e ) = Foswiki::Time::parseInterval($interval);
    $this->assert_equals( $basetime,        $s );
    $this->assert_equals( $basetime + $gap, $e );

    $interval = "$start/P2s2M2h2d2w2m2y";
    ( $s, $e ) = Foswiki::Time::parseInterval($interval);
    $this->assert_equals( $basetime,         $s );
    $this->assert_equals( $basetime + $gap2, $e );

    $interval = "P1y1m1w1d1h1M1s/$start";
    ( $s, $e ) = Foswiki::Time::parseInterval($interval);
    $this->assert_equals( $basetime - $gap, $s );
    $this->assert_equals( $basetime,        $e );

    $interval = "2006/2007";
    ( $s, $e ) = Foswiki::Time::parseInterval($interval);
    $this->assert_str_equals( "2006-01-01T00:00:00Z",
        Foswiki::Time::formatTime( $s, 'iso', 'gmtime' ) );
    $this->assert_str_equals( "2007-12-31T23:59:59Z",
        Foswiki::Time::formatTime( $e, 'iso', 'gmtime' ) );
    $interval = "2006/2007-02";
    ( $s, $e ) = Foswiki::Time::parseInterval($interval);
    $this->assert_str_equals( "2006-01-01T00:00:00Z",
        Foswiki::Time::formatTime( $s, 'iso', 'gmtime' ) );
    $this->assert_str_equals( "2007-02-28T23:59:59Z",
        Foswiki::Time::formatTime( $e, 'iso', 'gmtime' ) );
}

sub test_parseTimeRobustness {
    my $this = shift;

    $this->checkTime( 0, 0, 0, 4, 2, 1995, "1995-02-04" );
    $this->checkTime( 0, 0, 0, 1, 2, 1995, "1995-02" );
    $this->checkTime( 0, 0, 0, 1, 1, 1995, "1995" );

    $this->checkTime( 0, 0, 0, 4, 2, 1995, "1995/02/04" );
    $this->checkTime( 0, 0, 0, 1, 2, 1995, "1995/02" );
    $this->checkTime( 0, 0, 0, 1, 1, 1995, "1995" );

    $this->checkTime( 0, 0, 0, 4, 2, 1995, "1995.02.04" );
    $this->checkTime( 0, 0, 0, 1, 2, 1995, "1995.02" );
    $this->checkTime( 0, 0, 0, 1, 1, 1995, "1995" );

    $this->checkTime( 0, 0, 0, 4, 2, 1995, "1995 - 02 -04" );
    $this->checkTime( 0, 0, 0, 1, 2, 1995, "1995- 02" );
    $this->checkTime( 0, 0, 0, 1, 1, 1995, "1995" );

    $this->checkTime( 0, 0, 0, 4, 2, 1995, "1995 / 02/04" );
    $this->checkTime( 0, 0, 0, 1, 2, 1995, "1995 /02" );
    $this->checkTime( 0, 0, 0, 1, 1, 1995, "1995" );

    $this->checkTime( 0, 0, 0, 4, 2, 1995, "1995. 02 .04" );
    $this->checkTime( 0, 0, 0, 1, 2, 1995, "1995.02 " );

    $this->checkTime( 0, 0, 0, 4, 2, 1995, "      1995-02-04" );
    $this->checkTime( 0, 0, 0, 1, 1, 1995, " 1995 " );

}

sub test_parseErrors {
    my $this = shift;

    $this->assert_equals( 0, Foswiki::Time::parseTime('wibble') );
    $this->assert_equals( 0, Foswiki::Time::parseTime('1234-qwer-3') );
    $this->assert_equals( 0, Foswiki::Time::parseTime('1234-1234-1234') );
    $this->assert_equals( 0, Foswiki::Time::parseTime('2008^12^12') );
    $this->assert_equals( 0, Foswiki::Time::parseTime('2008--12-23') );

    $this->assert_equals( 0, Foswiki::Time::parseTime('2008-13-23') );
    $this->assert_equals( 0, Foswiki::Time::parseTime('2008-10-32') );
}

sub test_week {
    my $this = shift;

    # 2004 started on a thursday, so 1st Jan is in week 1
    my $time = Time::Local::timegm( 1, 0, 0, 1, 0, 104 );
    my $week = Foswiki::Time::formatTime( $time, '$week', 'gmtime' );
    $this->assert_equals( 1, $week );

    # 4th was the sunday of the first week, so also week 1
    $time = Time::Local::timegm( 1, 0, 0, 4, 0, 104 );
    $week = Foswiki::Time::formatTime( $time, '$week', 'gmtime' );
    $this->assert_equals( 1, $week );

    # 5th was monday of second week, so week 2
    $time = Time::Local::timegm( 1, 0, 0, 5, 0, 104 );
    $week = Foswiki::Time::formatTime( $time, '$week', 'gmtime' );
    $this->assert_equals( 2, $week );

    # poke back into 2003; 31st is in week 1 of 2004
    $time = Time::Local::timegm( 1, 0, 0, 31, 11, 103 );
    $week = Foswiki::Time::formatTime( $time, '$week', 'gmtime' );
    $this->assert_equals( 1, $week );

    # and 28th in week 52
    $time = Time::Local::timegm( 1, 0, 0, 28, 11, 103 );
    $week = Foswiki::Time::formatTime( $time, '$week', 'gmtime' );
    $this->assert_equals( 52, $week );

    # 1999 started on a friday, so 1st is week 53 of 1998
    # (week 0 of 1999)
    $time = Time::Local::timegm( 1, 0, 0, 1, 0, 99 );
    $week = Foswiki::Time::formatTime( $time, '$week', 'gmtime' );
    $this->assert_equals( 53, $week );

    # And 4th is week 1
    $time = Time::Local::timegm( 1, 0, 0, 4, 0, 99 );
    $week = Foswiki::Time::formatTime( $time, '$week', 'gmtime' );
    $this->assert_equals( 1, $week );
}

1;
