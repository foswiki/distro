# NOTE: this is a VERY limited subset of subroutines in Foswiki.pm (um, ok, one - moved from ManageDotPmTests..)
package FoswikiPmFunctionsTests;
use v5.14;

use diagnostics -verbose;
use Foswiki();
use Foswiki::UI::Manage();
use Foswiki::UI::Save();

use Moo;
use namespace::clean;
extends qw( FoswikiFnTestCase );

sub TRACE { return 0; }

sub test_isValidTopicName_WebHome {
    my $this = shift;

    my $result = Foswiki::isValidTopicName( 'WebHome', 1 );
    my $expected = 1;
    print("result=$result.\n")     if TRACE;
    print("expected=$expected.\n") if TRACE;
    $this->assert( $result eq $expected );

    return;
}

sub test_isValidTopicName_WebHome_onlywikiname {
    my $this = shift;

    my $result = Foswiki::isValidTopicName( 'WebHome', 0 );
    my $expected = 1;
    print("result=$result.\n")     if TRACE;
    print("expected=$expected.\n") if TRACE;
    $this->assert( $result eq $expected );

    return;
}

sub test_isValidTopicName_Aa_not_onlywikiname {
    my $this = shift;

    my $result = Foswiki::isValidTopicName( 'Aa', 1 );
    my $expected = 1;
    print("result=$result.\n")     if TRACE;
    print("expected=$expected.\n") if TRACE;
    $this->assert( $result eq $expected );

    return;
}

sub test_isValidTopicName_Aa_onlywikiname {
    my $this = shift;

    my $result = Foswiki::isValidTopicName( 'Aa', 0 );
    my $expected = 0;
    print("result=$result.\n")     if TRACE;
    print("expected=$expected.\n") if TRACE;
    $this->assert( $result eq $expected );

    return;
}

1;
