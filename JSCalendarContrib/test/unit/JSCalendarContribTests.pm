use strict;

package JSCalendarContribTests;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use Error qw( :try );
use POSIX qw( strftime );

use Foswiki::Contrib::JSCalendarContrib ();

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

sub set_up {
    my $this = shift;

    $this->{DisplayTimeValues} = $Foswiki::cfg{DisplayTimeValues};
    $this->SUPER::set_up();
}

sub tear_down {
    my $this = shift;

    $Foswiki::cfg{DisplayTimeValues} = delete $this->{DisplayTimeValues};

    # Always do this, and always do it last
    $this->SUPER::tear_down();
}

# %a abbreviated weekday name
sub test_formatDate_a {
    my ($this) = @_;

    $this->_formatDateTest( '31 Dec 2011 - 23:59', '%a', 'Sat' );
}

# %A abbreviated weekday name
sub test_formatDate_A {
    my ($this) = @_;

    $this->_formatDateTest( '31 Dec 2011 - 23:59', '%A', 'Saturday' );
}

# %b abbreviated month name
sub test_formatDate_b {
    my ($this) = @_;

    $this->_formatDateTest( '31 Dec 2011 - 23:59', '%b', 'Dec' );
}

# %B full month name
sub test_formatDate_B {
    my ($this) = @_;

    $this->_formatDateTest( '31 Dec 2011 - 23:59', '%B', 'December' );
}

# %C century number
sub test_formatDate_C {
    my ($this) = @_;

    $this->_formatDateTest( '31 Dec 2011 - 23:59', '%C', '21' );
}

# %d the day of the month ( 00 .. 31 )
sub test_formatDate_d {
    my ($this) = @_;

    $this->_formatDateTest( '1 Dec 2011 - 23:59', '%d', '01' );
}

# %e the day of the month ( 0 .. 31 )
sub test_formatDate_e {
    my ($this) = @_;

    $this->_formatDateTest( '1 Dec 2011 - 23:59', '%e', '1' );
}

# %H hour ( 00 .. 23 )
sub test_formatDate_H {
    my ($this) = @_;

    $this->_formatDateTest( '1 Dec 2011 - 03:59', '%H', '03' );
}

# %I - hour ( 01 .. 12 ) (for AM/PM)
sub test_formatDate_I {
    my ($this) = @_;

    $this->_formatDateTest( '1 Dec 2011 - 23:59', '%I', '11' );
    $this->_formatDateTest( '1 Dec 2011 - 04:59', '%I', '04' );
    $this->_formatDateTest( '1 Dec 2011 - 12:59', '%I', '12' );
    $this->_formatDateTest( '1 Dec 2011 - 00:59', '%I', '12' );
}

# %j - day of the year ( 000 .. 366 )
sub test_formatDate_j {
    my ($this) = @_;

    $this->_formatDateTest( '31 Dec 2011 - 23:59', '%j', '365' );
    $this->_formatDateTest( '31 Jan 2011 - 23:59', '%j', '31' );
}

# %k - hour ( 0 .. 23 )
sub test_formatDate_k {
    my ($this) = @_;

    $this->_formatDateTest( '1 Dec 2011 - 23:59', '%k', '23' );
    $this->_formatDateTest( '1 Dec 2011 - 05:59', '%k', '5' );
}

# %l - hour ( 1 .. 12 ) (for AM/PM)
sub test_formatDate_l {
    my ($this) = @_;

    $this->_formatDateTest( '1 Dec 2011 - 23:59', '%I', '11' );
    $this->_formatDateTest( '1 Dec 2011 - 06:59', '%l', '6' );
    $this->_formatDateTest( '1 Dec 2011 - 12:59', '%l', '12' );
    $this->_formatDateTest( '1 Dec 2011 - 00:59', '%l', '12' );
}

# %m - month ( 01 .. 12 )
sub test_formatDate_m {
    my ($this) = @_;

    $this->_formatDateTest( '1 Jan 2011 - 03:59', '%m', '01' );
}

# %M - minute ( 00 .. 59 )
sub test_formatDate_M {
    my ($this) = @_;

    $this->_formatDateTest( '1 Jan 2011 - 23:01', '%M', '01' );
}

# %n - a newline character
sub test_formatDate_n {
    my ($this) = @_;

    $this->_formatDateTest( '1 Jan 2011 - 23:01', '%n', "\n" );
}

# %p - "PM" or "AM"
sub test_formatDate_p {
    my ($this) = @_;

    $this->_formatDateTest( '1 Jan 2011 - 00:01', '%p', "AM" );
    $this->_formatDateTest( '1 Jan 2011 - 12:01', '%p', "PM" );
    $this->_formatDateTest( '1 Jan 2011 - 23:01', '%p', "PM" );
}

# %P - "pm" or "am"
sub test_formatDate_P {
    my ($this) = @_;

    $this->_formatDateTest( '1 Jan 2011 - 00:01', '%P', "am" );
    $this->_formatDateTest( '1 Jan 2011 - 12:01', '%P', "pm" );
    $this->_formatDateTest( '1 Jan 2011 - 23:01', '%P', "pm" );
}

# %S - second ( 00 .. 59 )
sub test_formatDate_S {
    my ($this) = @_;

    $this->_formatDateTest( '2011/12/31 23:59:00', '%S', "00" );
    $this->_formatDateTest( '2011/12/31 23:59:59', '%S', "59" );
}

# %s - number of seconds since Epoch (since Jan 01 1970 00:00:00 UTC)
sub test_formatDate_s {
    my ($this) = @_;

    my $testEpoch = 1325375940;    # 2011/12/31 23:59:00 GMT
    my $timezoneDiff =
      strftime( "%s", gmtime($testEpoch) ) -
      strftime( "%s", localtime($testEpoch) );
    $this->_formatDateTest( '1970/00/00', '%s', "0" );
    $this->_formatDateTest( '2011/12/31 23:59:00',
        '%s', $testEpoch, $testEpoch + $timezoneDiff );
}

# %t - a tab character
sub test_formatDate_t {
    my ($this) = @_;

    $this->_formatDateTest( '2011/12/31 23:59:00', '%t', "\t" );
}

# %U, %W, %V - the week number
# The week 01 is the week that has the Thursday in the current year,
# which is equivalent to the week that contains the fourth day of January.
# Weeks start on Monday.
sub test_formatDate_UWV {
    my ($this) = @_;

    $this->_formatDateTest( '1 Jan 2011 - 23:01',  '%U %W %V', "52 52 52" );
    $this->_formatDateTest( '7 Jan 2011 - 23:01',  '%U %W %V', "1 1 1" );
    $this->_formatDateTest( '31 Dec 2011 - 23:01', '%U %W %V', "52 52 52" );
}

# %u - the day of the week ( 1 .. 7, 1 = MON )
sub test_formatDate_u {
    my ($this) = @_;

    $this->_formatDateTest( '3 Jan 2011 - 23:59', '%a', 'Mon' );
    $this->_formatDateTest( '3 Jan 2011 - 23:01', '%u', "1" );
}

# %w - the day of the week ( 0 .. 6, 0 = SUN )
sub test_formatDate_w {
    my ($this) = @_;

    $this->_formatDateTest( '31 Jul 2011', '%a', 'Sun' );
    $this->_formatDateTest( '31 Jul 2011', '%u', "0" );
}

# %y - year without the century ( 00 .. 99 )
sub test_formatDate_y {
    my ($this) = @_;

    $this->_formatDateTest( '31 Jul 2011', '%y', '11' );
    $this->_formatDateTest( '31 Jul 2001', '%y', "01" );
}

# %Y - year including the century ( ex. 1979 )
sub test_formatDate_Y {
    my ($this) = @_;

    $this->_formatDateTest( '31 Jul 2011', '%Y', '2011' );
}

# %% - a literal % character
sub test_formatDate_percent {
    my ($this) = @_;

    $this->_formatDateTest( '31 Jul 2011', '%%', '%' );
}

sub _formatDateTest {
    my ( $this, $date, $format, $expectedGMT, $expectedServer ) = @_;

    $expectedServer = $expectedGMT unless defined $expectedServer;

    $Foswiki::cfg{DisplayTimeValues} = 'gmtime';
    my $actualGMT =
      Foswiki::Contrib::JSCalendarContrib::formatDate( $date, $format );
    $this->assert_str_equals( $expectedGMT, $actualGMT,
"With DisplayTimeValues = 'gmtime':\nExpected: '$expectedGMT'\n But got: '$actualGMT'\n"
    );
    $Foswiki::cfg{DisplayTimeValues} = 'servertime';
    my $actualServer =
      Foswiki::Contrib::JSCalendarContrib::formatDate( $date, $format );
    $this->assert_str_equals( $expectedServer, $actualServer,
"With DisplayTimeValues = 'servertime':\nExpected: '$expectedServer'\n But got: '$actualServer'\n"
    );
}

sub test_combined_formatDate {
    my ($this) = @_;

    my ( $date, $format, $expected, $actual );

    $date     = '1 Dec 2011 - 23:59';
    $format   = '$day $month $year';
    $expected = '01 Dec 2011';
    $actual = Foswiki::Contrib::JSCalendarContrib::formatDate( $date, $format );
    $this->assert_html_equals( $expected, $actual );

    $date     = '1 Dec 2011';
    $format   = '%Y %b %e';
    $expected = '2011 Dec 1';
    $actual = Foswiki::Contrib::JSCalendarContrib::formatDate( $date, $format );
    $this->assert_html_equals( $expected, $actual );

    $date     = '1 Dec 2011';
    $format   = '%Y-%m-%e %H:%M:%S';
    $expected = '2011-12-1 00:00:00';
    $actual = Foswiki::Contrib::JSCalendarContrib::formatDate( $date, $format );
    $this->assert_html_equals( $expected, $actual );

    $date     = '1 Dec 2011';
    $format   = '%d %B %y';
    $expected = '01 December 11';
    $actual = Foswiki::Contrib::JSCalendarContrib::formatDate( $date, $format );
    $this->assert_html_equals( $expected, $actual );

    $date     = '1 Dec 2011 - 23:59';
    $format   = '%H:%M:%S';
    $expected = '23:59:00';
    $actual = Foswiki::Contrib::JSCalendarContrib::formatDate( $date, $format );
    $this->assert_html_equals( $expected, $actual );

    $date     = '2011/12/31 23:59:59';
    $format   = '%H:%M:%S';
    $expected = '23:59:59';
    $actual = Foswiki::Contrib::JSCalendarContrib::formatDate( $date, $format );
    $this->assert_html_equals( $expected, $actual );
}

sub test_renderDateForEdit {
    my ($this) = @_;

    my ( $date, $format, $expected, $actual );
    my $pubUrlPathSystemWeb =
      Foswiki::Func::getPubUrlPath() . '/' . $Foswiki::cfg{SystemWebName};

    $date   = '2011/12/31 23:59:59';
    $format = '%Y-%m-%e %H:%M:%S';
    $expected =
"<input type=\"text\" name=\"test\" value=\"2011-12-31 23:59:59\" size=\"20\" id=\"id_test\" /><input type=\"image\" name=\"img_test\" src=\"$pubUrlPathSystemWeb/JSCalendarContrib/img.gif\" align=\"middle\" alt=\"Calendar\" onclick=\"javascript: return showCalendar('id_test','$format')\" />";
    $actual =
      Foswiki::Contrib::JSCalendarContrib::renderDateForEdit( 'test', $date,
        $format );
    $this->assert_html_equals( $expected, $actual );

    $date   = '31 Dec 2011';
    $format = '%Y %b %e';
    $expected =
"<input type=\"text\" name=\"test\" value=\"2011 Dec 31\" size=\"12\" id=\"id_test\" /><input type=\"image\" name=\"img_test\" src=\"$pubUrlPathSystemWeb/JSCalendarContrib/img.gif\" align=\"middle\" alt=\"Calendar\" onclick=\"javascript: return showCalendar('id_test','$format')\" />";
    $actual =
      Foswiki::Contrib::JSCalendarContrib::renderDateForEdit( 'test', $date,
        $format );
    $this->assert_html_equals( $expected, $actual );
}

1;
