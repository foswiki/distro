# NOTE: this is a VERY limited subset of subroutines in Foswiki.pm (um, ok, one - moved from ManageDotPmTests..)
package FoswikiPmFunctionsTests;
use v5.14;

use diagnostics -verbose;
use Foswiki    ();
use File::Spec ();

use Foswiki::Class;
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

sub test_guessLibDir {
    my $this = shift;

    local $ENV{FOSWIKI_LIBS};

    my ( $v, $d, $f ) = File::Spec->splitpath(__FILE__);
    my $updir = File::Spec->updir;
    my @d     = File::Spec->splitdir($d);
    splice( @d, -3, 2, 'lib' );
    my $myguess =
      File::Spec->canonpath(
        File::Spec->catpath( $v, File::Spec->catdir(@d), '' ) );
    my $libDir = Foswiki::guessLibDir;
    $this->assert_equals( $myguess, $libDir );
}

1;
