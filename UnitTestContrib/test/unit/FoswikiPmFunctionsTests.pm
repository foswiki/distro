# NOTE: this is a VERY limited subset of subroutines in Foswiki.pm (um, ok, one - moved from ManageDotPmTests..)
package FoswikiPmFunctionsTests;

use strict;
use warnings;
use diagnostics;

use FoswikiFnTestCase();
our @ISA = qw( FoswikiFnTestCase );
use Foswiki();
use Foswiki::UI::Manage();
use Foswiki::UI::Save();

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

sub test_isValidTopicName_WebHome_NOT_nonwikiword {
    my $this = shift;

    my $result = Foswiki::isValidTopicName( 'WebHome', 0 );
    my $expected = 1;
    print("result=$result.\n")     if TRACE;
    print("expected=$expected.\n") if TRACE;
    $this->assert( $result eq $expected );

    return;
}

sub test_isValidTopicName_Aa_nonwikiword {
    my $this = shift;

    my $result = Foswiki::isValidTopicName( 'Aa', 1 );
    my $expected = 1;
    print("result=$result.\n")     if TRACE;
    print("expected=$expected.\n") if TRACE;
    $this->assert( $result eq $expected );

    return;
}

sub test_isValidTopicName_Aa_NOT_nonwikiword {
    my $this = shift;

    my $result = Foswiki::isValidTopicName( 'Aa', 0 );
    my $expected = 0;
    print("result=$result.\n")     if TRACE;
    print("expected=$expected.\n") if TRACE;
    $this->assert( $result eq $expected );

    return;
}

1;
