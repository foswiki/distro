use strict;

# tests for the correct expansion of SECTION

package Fn_SECTION;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use Foswiki;
use Error qw( :try );

sub new {
    my $self = shift()->SUPER::new( 'SECTION', @_ );
    return $self;
}

sub dumpsec {
    my $sec = shift;
    return join( ";", map { $_->stringify() } @$sec );
}

sub test_sections1 {
    my $this = shift;

    # Named section closed without being opened
    my $text = '0%ENDSECTION{"name"}%1';
    my ( $nt, $s ) = Foswiki::parseSections($text);
    $this->assert_str_equals( "01", $nt );
    $this->assert_str_equals( '',   dumpsec($s) );
}

sub test_sections2 {
    my $this = shift;

    # Named section opened but never closed
    my $text = '0%STARTSECTION{"name"}%1';
    my ( $nt, $s ) = Foswiki::parseSections($text);
    $this->assert_str_equals( "01", $nt );
    $this->assert_str_equals( 'end="2" name="name" start="1" type="section"',
        dumpsec($s) );
}

sub test_sections3 {
    my $this = shift;

    # Unnamed section closed without being opened
    my $text = '0%ENDSECTION%1';
    my ( $nt, $s ) = Foswiki::parseSections($text);
    $this->assert_str_equals( "01", $nt );
    $this->assert_str_equals( '',   dumpsec($s) );
}

sub test_sections4 {
    my $this = shift;

    # Unnamed section opened but never closed
    my $text = '0%STARTSECTION%1';
    my ( $nt, $s ) = Foswiki::parseSections($text);
    $this->assert_str_equals( "01", $nt );
    $this->assert_str_equals(
        'end="2" name="_SECTION0" start="1" type="section"',
        dumpsec($s) );
}

sub test_sections5 {
    my $this = shift;

    # Unnamed section closed by opening another section of the same type
    my $text = '0%STARTSECTION%1%STARTSECTION%2';
    my ( $nt, $s ) = Foswiki::parseSections($text);
    $this->assert_str_equals( "012", $nt );
    $this->assert_str_equals(
'end="2" name="_SECTION0" start="1" type="section";end="3" name="_SECTION1" start="2" type="section"',
        dumpsec($s)
    );
}

sub test_sections6 {
    my $this = shift;

    # Named section overlaps unnamed section before it
    my $text =
'0%STARTSECTION%1%STARTSECTION{"named"}%2%ENDSECTION%3%ENDSECTION{"named"}%4';
    my ( $nt, $s ) = Foswiki::parseSections($text);
    $this->assert_str_equals( "01234", $nt );
    $this->assert_str_equals(
'end="2" name="_SECTION0" start="1" type="section";end="4" name="named" start="2" type="section"',
        dumpsec($s)
    );
}

sub test_sections7 {
    my $this = shift;

    # Named section overlaps unnamed section after it
    my $text =
'0%STARTSECTION{"named"}%1%STARTSECTION%2%ENDSECTION{"named"}%3%ENDSECTION%4';
    my ( $nt, $s ) = Foswiki::parseSections($text);
    $this->assert_str_equals( "01234", $nt );
    $this->assert_str_equals(
'end="3" name="named" start="1" type="section";end="4" name="_SECTION0" start="2" type="section"',
        dumpsec($s)
    );
}

sub test_sections8 {
    my $this = shift;

    # Unnamed sections of different types overlap
    my $text =
'0%STARTSECTION{type="include"}%1%STARTSECTION{type="templateonly"}%2%ENDSECTION{type="include"}%3%ENDSECTION{type="templateonly"}%4';
    my ( $nt, $s ) = Foswiki::parseSections($text);
    $this->assert_str_equals( "01234", $nt );
    $this->assert_str_equals(
'end="3" name="_SECTION0" start="1" type="include";end="4" name="_SECTION1" start="2" type="templateonly"',
        dumpsec($s)
    );
}

sub test_sections9 {
    my $this = shift;

    # Named sections of same type overlap
    my $text =
'0%STARTSECTION{"one"}%1%STARTSECTION{"two"}%2%ENDSECTION{"one"}%3%ENDSECTION{"two"}%4';
    my ( $nt, $s ) = Foswiki::parseSections($text);
    $this->assert_str_equals( "01234", $nt );
    $this->assert_str_equals(
'end="3" name="one" start="1" type="section";end="4" name="two" start="2" type="section"',
        dumpsec($s)
    );
}

sub test_sections10 {
    my $this = shift;

    # Named sections nested
    my $text =
'0%STARTSECTION{name="one"}%1%STARTSECTION{name="two"}%2%ENDSECTION{name="two"}%3%ENDSECTION{name="one"}%4';
    my ( $nt, $s ) = Foswiki::parseSections($text);
    $this->assert_str_equals( "01234", $nt );
    $this->assert_str_equals(
'end="4" name="one" start="1" type="section";end="3" name="two" start="2" type="section"',
        dumpsec($s)
    );
}

# Item10316
sub test_continuedsections {
    my ($this) = @_;
    my $text = <<'HERE';
Pre-INCLUDEable %STARTINCLUDE% In-the-INCLUDEable bit
%STARTSECTION{"1"}% 1 content %ENDSECTION{"1"}%
%STARTSECTION{"2"}% 2 content
%STARTSECTION{"21"}% 2.1 content %ENDSECTION{"21"}%
%STARTSECTION{"22"}% 2.2 content
%STARTSECTION{"221"}% 2.2.1 content %ENDSECTION{"221"}%
%STARTSECTION{"222"}% 2.2.2 content %ENDSECTION{"222"}%
%STARTSECTION{"223"}% 2.2.3 content %ENDSECTION{"223"}%
%STARTSECTION{"224"}% 2.2.4 continued content %ENDSECTION{"224"}%
%ENDSECTION{"22"}%
%STARTSECTION{"23"}% 2.3 content %ENDSECTION{"23"}%
%ENDSECTION{"2"}%
%STARTSECTION{"3"}% 3 content %ENDSECTION{"3"}%
Still-in-the-INCLUDEable bit
%STOPINCLUDE% Post-INCLUDEable
HERE

}

1;
