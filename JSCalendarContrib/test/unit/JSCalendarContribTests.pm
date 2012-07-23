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

sub test_renderDateForEdit {
    my ($this) = @_;

    my ( $date, $format, $expected, $actual );
    my $pubUrlPathSystemWeb =
      Foswiki::Func::getPubUrlPath() . '/' . $Foswiki::cfg{SystemWebName};

    $date   = '2011-12-31 23:59:59';
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
"<input type=\"text\" name=\"test\" value=\"31 Dec 2011\" size=\"12\" id=\"id_test\" /><input type=\"image\" name=\"img_test\" src=\"$pubUrlPathSystemWeb/JSCalendarContrib/img.gif\" align=\"middle\" alt=\"Calendar\" onclick=\"javascript: return showCalendar('id_test','$format')\" />";
    $actual =
      Foswiki::Contrib::JSCalendarContrib::renderDateForEdit( 'test', $date,
        $format );
    $this->assert_html_equals( $expected, $actual );
}

1;
