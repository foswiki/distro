use strict;

package SpreadSheetPluginTests;

use base qw(FoswikiFnTestCase);

use strict;
use Foswiki;
use Foswiki::Plugins::SpreadSheetPlugin;
use Foswiki::Plugins::SpreadSheetPlugin::Calc;


sub set_up {
    my $this = shift;
    $this->SUPER::set_up();

    $this->{target_web} = 'TestSpreadSheet' || "$this->{test_web}Target";
    $this->{target_topic} = 'SpreadSheetTestTopic' || "$this->{test_topic}Target";

    $this->{twiki}->{store}->createWeb( $this->{twiki}->{user}, $this->{target_web} );

    my $table = <<'HERE';
| *Region:* | *Sales:* |
| Northeast |  320 |
| Northwest |  580 |
| South |  240 |
| Europe |  610 |
| Asia |  220 |
| Total: |  %CALC{"$SUM( $ABOVE() )"}% |
HERE

    $this->writeTopic( $this->{target_web}, $this->{target_topic}, $table );
}

sub tear_down {
    my $this = shift;
    $this->{twiki}->{store}->removeWeb( $this->{twiki}->{user}, $this->{target_web} );
    $this->SUPER::tear_down();
}

sub writeTopic {
    my( $this, $web, $topic, $text ) = @_;
    my $meta = new Foswiki::Meta($this->{twiki}, $web, $topic);
    $this->{twiki}->{store}->saveTopic( $this->{twiki}->{user}, $web, $topic, $text, $meta );
}

sub CALC {
    my $this = shift;
    my $str = shift;
    my %args = (
	web => 'Web',
	topic => 'Topic',
	@_,
	);
    my $calc = '%CALC{"' . $str . '"}%';
    return Foswiki::Plugins::SpreadSheetPlugin::Calc::CALC( $calc, $args{topic}, $args{web} );
}

#sub test_MAIN {}
#sub test_EXEC {}
#sub test_NOEXEC {}

sub test_ABOVE {
    warn '$ABOVE not implemented';
}

sub test_ABS {
    my ($this) = @_;
    $this->assert( $this->CALC( '$ABS(-12.5)' ) == 12.5 );
    $this->assert( $this->CALC( '$ABS(12.5)' ) == 12.5 );
    $this->assert( $this->CALC( '$ABS(0)' ) == 0 );
    $this->assert( $this->CALC( '$ABS(-0)' ) == 0 );
    $this->assert( $this->CALC( '$ABS(-0.0)' ) == 0 );
}

sub test_AND {
    my ($this) = @_;
    $this->assert( $this->CALC( '$AND(0)' ) == 0 );
    $this->assert( $this->CALC( '$AND(0,0)' ) == 0 );
    $this->assert( $this->CALC( '$AND(0,0,0)' ) == 0 );

    $this->assert( $this->CALC( '$AND(1)' ) == 1 );
    $this->assert( $this->CALC( '$AND(1,0)' ) == 0 );
    $this->assert( $this->CALC( '$AND(0,1)' ) == 0 );
    $this->assert( $this->CALC( '$AND(1,0,0)' ) == 0 );
    $this->assert( $this->CALC( '$AND(1,0,1)' ) == 0 );
    $this->assert( $this->CALC( '$AND(0,1,0)' ) == 0 );
    $this->assert( $this->CALC( '$AND(0,1,1)' ) == 0 );

    $this->assert( $this->CALC( '$AND(0,0,0,0,0,1,1,1)' ) == 0 );
    $this->assert( $this->CALC( '$AND(1,1,1,1,1,1,1,1)' ) == 1 );
}

sub test_AVERAGE {
    my ($this) = @_;
    $this->assert( $this->CALC( '$AVERAGE(0)' ) == 0 );
    $this->assert( $this->CALC( '$AVERAGE(1)' ) == 1 );
    $this->assert( $this->CALC( '$AVERAGE(-1)' ) == -1 );
    $this->assert( $this->CALC( '$AVERAGE(0,1)' ) == 0.5 );
    $this->assert( $this->CALC( '$AVERAGE(-1,1)' ) == 0 );
    $this->assert( $this->CALC( '$AVERAGE(-1,-1,-1,-1)' ) == -1 );
}

sub test_CHAR {
    my ($this) = @_;
    $this->assert( $this->CALC( '$CHAR(65)' ) eq 'A' );
    $this->assert( $this->CALC( '$CHAR(97)' ) eq 'a' );
}

sub test_CODE {
    my ($this) = @_;
    $this->assert( $this->CALC( '$CODE(A)' ) == 65 );
    $this->assert( $this->CALC( '$CODE(a)' ) == 97 );
    $this->assert( $this->CALC( '$CODE(abc)' ) == 97 );
}

sub test_COLUMN {
    warn '$COLUMN not implemented';
}

sub test_COUNTITEMS {
    warn '$COUNTITEMS not implemented';
}

sub test_COUNTSTR {
    warn '$COUNTSTR not implemented';
}

sub test_DEF {
    warn '$DEF not implemented';
}

sub test_EMPTY {
    my ($this) = @_;
    $this->assert( $this->CALC( '$EMPTY(foo)' ) == 0 );
    $this->assert( $this->CALC( '$EMPTY()' ) == 1 );
    $this->assert( $this->CALC( '$EMPTY($TRIM( ))' ) == 1 );
}

sub test_EVAL {
    my ($this) = @_;
    $this->assert( $this->CALC( '$EVAL(1+1)' ) == 2 );
    $this->assert( $this->CALC( '$EVAL( (5 * 3) / 2 + 1.1 )' ) == 8.6 );
}

sub test_EVEN {
    my ($this) = @_;
    $this->assert( $this->CALC( '$EVEN(2)' ) == 1 );
    $this->assert( $this->CALC( '$EVEN(1)' ) == 0 );
    $this->assert( $this->CALC( '$EVEN(3)' ) == 0 );
    $this->assert( $this->CALC( '$EVEN(0)' ) == 1 );
    $this->assert( $this->CALC( '$EVEN(-4)' ) == 1 );
    $this->assert( $this->CALC( '$EVEN(-1)' ) == 0 );
}

sub test_EXACT {
    my ($this) = @_;
    $this->assert( $this->CALC( '$EXACT(foo, Foo)' ) == 0 );
    $this->assert( $this->CALC( '$EXACT(foo, $LOWER(Foo))' ) == 1 );
    $this->assert( $this->CALC( '$EXACT(,)' ) == 1 );
    $this->assert( $this->CALC( '$EXACT(, )' ) == 1 );
    $this->assert( $this->CALC( '$EXACT( , )' ) == 1 );
    $this->assert( $this->CALC( '$EXACT( ,  )' ) == 1 );
    $this->assert( $this->CALC( '$EXACT(  , )' ) == 1 );
}

sub test_EXISTS {
    my ($this) = @_;
    $this->assert( $this->CALC( '$EXISTS(' . $this->{target_web} . '.' . $this->{target_topic} . ')' ) != 0 );
    $this->assert( $this->CALC( '$EXISTS(NonExistWeb.NonExistTopic)' ) == 0 );
}

sub test_EXP {
    my ($this) = @_;
    $this->assert( $this->CALC( '$EXP(1)' ) == 2.71828182845905 );
}

sub test_FIND {
    my ($this) = @_;
    $this->assert( $this->CALC( '$FIND(f, fluffy)' ) == 1 );
    $this->assert( $this->CALC( '$FIND(f, fluffy, 2)' ) == 4 );
    $this->assert( $this->CALC( '$FIND(@, fluffy, 1)' ) == 0 );
}

sub test_FORMAT {
    my ($this) = @_;
    $this->assert( $this->CALC( '$FORMAT(COMMA, 2, 12345.6789)' ) eq '12,345.68' );
    $this->assert( $this->CALC( '$FORMAT(DOLLAR, 2, 12345.67)' ) eq '$12,345.67' );
    $this->assert( $this->CALC( '$FORMAT(KB, 2, 1234567)' ) eq '1205.63 KB' );
    $this->assert( $this->CALC( '$FORMAT(MB, 2, 1234567)' ) eq '1.18 MB' );
    $this->assert( $this->CALC( '$FORMAT(KBMB, 2, 1234567)' ) eq '1.18 MB'  );
    $this->assert( $this->CALC( '$FORMAT(KBMB, 2, 1234567890)' ) eq '1.15 GB' );
    $this->assert( $this->CALC( '$FORMAT(NUMBER, 1, 12345.67)' ) eq '12345.7' );
    $this->assert( $this->CALC( '$FORMAT(PERCENT, 1, 0.1234567)' ) eq '12.3%' );
}

sub test_FORMATGMTIME {
    my ($this) = @_;
    $this->assert( $this->CALC( '$FORMATGMTIME(1041379200, $day $mon $year)' ) eq '01 Jan 2003' );
}

sub test_FORMATTIME {
    my ($this) = @_;
    $this->assert( $this->CALC( '$FORMATTIME(0, $year/$month/$day GMT)' ) eq '1970/01/01 GMT' );
}

sub test_FORMATTIMEDIFF {
    my ($this) = @_;
    $this->assert( $this->CALC( '$FORMATTIMEDIFF(min, 1, 200)' ) eq '3 hours' );
    $this->assert( $this->CALC( '$FORMATTIMEDIFF(min, 2, 200)' ) eq '3 hours and 20 minutes' );
    $this->assert( $this->CALC( '$FORMATTIMEDIFF(min, 1, 1640)' ) eq '1 day' );
    $this->assert( $this->CALC( '$FORMATTIMEDIFF(min, 2, 1640)' ) eq '1 day and 3 hours' );
    $this->assert( $this->CALC( '$FORMATTIMEDIFF(min, 3, 1640)' ) eq '1 day, 3 hours and 20 minutes' );
}

sub test_GET {
    warn '$GET not implemented';
}

sub test_IF {
    my ($this) = @_;
    warn '$IF not implemented';
#    $this->assert( $this->CALC( '$IF($T(R1:C5) > 1000, Over Budget, OK)' ) eq 'OK' );	#==Over Budget== if value in R1:C5 is over 1000, ==OK== if not
#    $this->assert( $this->CALC( '$IF($EXACT($T(R1:C2),), empty, $T(R1:C2))' ) eq '' );	#returns the content of R1:C2 or ==empty== if empty
#    $this->assert( $this->CALC( '$SET(val, $IF($T(R1:C2) == 0, zero, $T(R1:C2)))' ) eq '?' );	#sets a variable conditionally
}

sub test_INSERTSTRING {
    my ($this) = @_;
    $this->assert( $this->CALC( '$INSERTSTRING(abcdefg, 2, XYZ)' ) eq 'abXYZcdefg' );
    $this->assert( $this->CALC( '$INSERTSTRING(abcdefg, -2, XYZ)' ) eq 'abcdeXYZfg' );
}

sub test_INT {
    my ($this) = @_;
    $this->assert( $this->CALC( '$INT(10 / 4)' ) == 2 );
    $this->assert( $this->CALC( '$INT($VALUE(09))' ) == 9 );
}

sub test_LEFT {
    warn '$LEFT not implemented';
}

sub test_LEFTSTRING {
    my ($this) = @_;
    $this->assert( $this->CALC( '$LEFTSTRING(abcdefg)' ) eq 'a' );
    $this->assert( $this->CALC( '$LEFTSTRING(abcdefg, 0)' ) eq '' );
    $this->assert( $this->CALC( '$LEFTSTRING(abcdefg, 5)' ) eq 'abcde' );
    $this->assert( $this->CALC( '$LEFTSTRING(abcdefg, 12)' ) eq 'abcdefg' );
    $this->assert( $this->CALC( '$LEFTSTRING(abcdefg, -3)' ) eq 'abcd' );
    $this->assert( $this->CALC( '$LEFTSTRING(abcdefg, -12)' ) eq '' );
}

sub test_LENGTH {
    my ($this) = @_;
    $this->assert( $this->CALC( '$LENGTH(abcd)' ) == 4 );
    $this->assert( $this->CALC( '$LENGTH()' ) == 0 );
}

sub test_LIST {
    warn '$LIST not implemented';
}

sub test_LISTIF {
    my ($this) = @_;
    $this->assert( $this->CALC( '$LISTIF($item > 12, 14, 7, 25)' ) eq '14, 25' );
    $this->assert( $this->CALC( '$LISTIF($NOT($EXACT($item,)), A, B, , E)' ) eq 'A, B, E' );
    $this->assert( $this->CALC( '$LISTIF($index > 2, A, B, C, D)' ) eq 'C, D' );
}

sub test_LISTITEM {
    my ($this) = @_;
    $this->assert( $this->CALC( '$LISTITEM(2, Apple, Orange, Apple, Kiwi)' ) eq 'Orange' );
    $this->assert( $this->CALC( '$LISTITEM(-1, Apple, Orange, Apple, Kiwi)' ) eq 'Kiwi' );
}

sub test_LISTJOIN {
    my ($this) = @_;
    $this->assert( $this->CALC( '$LISTJOIN(,1,2,3)' ) eq '1, 2, 3' );
    $this->assert( $this->CALC( '$LISTJOIN($comma,1,2,3)' ) eq '1,2,3' );
    $this->assert( $this->CALC( '$LISTJOIN($n,1,2,3)' ) eq "1\n2\n3" );
    $this->assert( $this->CALC( '$LISTJOIN($sp,1,2,3)' ) eq "1 2 3" );
    $this->assert( $this->CALC( '$LISTJOIN( ,1,2,3)' ) eq "1 2 3" );
    $this->assert( $this->CALC( '$LISTJOIN(  ,1,2,3)' ) eq "1  2  3" );
    $this->assert( $this->CALC( '$LISTJOIN(:,1,2,3)' ) eq "1:2:3" );
    $this->assert( $this->CALC( '$LISTJOIN(::,1,2,3)' ) eq "1::2::3" );
    $this->assert( $this->CALC( '$LISTJOIN(0,1,2,3)' ) eq "10203" );
    $this->assert( $this->CALC( '$LISTJOIN($nop,1,2,3)' ) eq '123' );
}

sub test_LISTMAP {
    my ($this) = @_;
    $this->assert( $this->CALC( '$LISTMAP($index: $EVAL(2 * $item), 3, 5, 7, 11)' ) eq '1: 6, 2: 10, 3: 14, 4: 22' );
}

sub test_LISTRAND {
    warn '$LISTRAND not implemented';
}

sub test_LISTREVERSE {
    my ($this) = @_;
    $this->assert( $this->CALC( '$LISTREVERSE(Apple, Orange, Apple, Kiwi)' ) eq 'Kiwi, Apple, Orange, Apple' );
}

sub test_LISTSHUFFLE {
    warn '$LISTSHUFFLE not implemented';
}

sub test_LISTSIZE {
    my ($this) = @_;
    $this->assert( $this->CALC( '$LISTSIZE(Apple, Orange, Apple, Kiwi)' ) == 4 );
}

sub test_LISTSORT {
    my ($this) = @_;
    $this->assert( $this->CALC( '$LISTSORT(Apple, Orange, Apple, Kiwi)' ) eq 'Apple, Apple, Kiwi, Orange' );
}

sub test_LISTTRUNCATE {
    my ($this) = @_;
    $this->assert( $this->CALC( '$LISTTRUNCATE(2, Apple, Orange, Kiwi)' ) eq 'Apple, Orange' );
}

sub test_LISTUNIQUE {
    my ($this) = @_;
    $this->assert( $this->CALC( '$LISTUNIQUE(Apple, Orange, Apple, Kiwi)' ) eq 'Apple, Orange, Kiwi' );
}

sub test_LN {
    my ($this) = @_;
    $this->assert( $this->CALC( '$LN(10)' ) == 2.30258509299405 );
#    $this->assert( $this->CALC( '$LN(2.30258509299405)' ) == 1 );
}

sub test_LOG {
    my ($this) = @_;
    $this->assert( $this->CALC( '$LOG(1000)' ) == 3 );
    $this->assert( $this->CALC( '$LOG(16, 2)' ) == 4 );
}

sub test_LOWER {
    my ($this) = @_;
    $this->assert( $this->CALC( '$LOWER(lowercase)' ) eq 'lowercase' );
    $this->assert( $this->CALC( '$LOWER(LOWERCASE)' ) eq 'lowercase' );
    $this->assert( $this->CALC( '$LOWER(lOwErCaSe)' ) eq 'lowercase' );
    $this->assert( $this->CALC( '$LOWER()' ) eq '' );
    $this->assert( $this->CALC( '$LOWER(`~!@#$%^&*_+{}|:"<>?)' ) eq q(`~!@#$%^&*_+{}|:"<>?) );
}

sub test_MAX {
    my ($this) = @_;
    $this->assert( $this->CALC( '$MAX(-1,0,1,13)' ) == 13 );
}

sub test_MEDIAN {
    my ($this) = @_;
    $this->assert( $this->CALC( '$MEDIAN(3, 9, 4, 5)' ) == 4.5 );
}

sub test_MIN {
    my ($this) = @_;
    $this->assert( $this->CALC( '$MIN(15, 3, 28)' ) == 3 );
    $this->assert( $this->CALC( '$MIN(-1,0,1,13)' ) == -1 );
}

sub test_MOD {
    my ($this) = @_;
    $this->assert( $this->CALC( '$MOD(7, 3)' ) == 1 );
}

sub test_NOP {
    my ($this) = @_;
    $this->assert( $this->CALC( '$NOP(abcd)' ) eq 'abcd' );
}

sub test_NOT {
    my ($this) = @_;
    $this->assert( $this->CALC( '$NOT(0)' ) == 1 );
    $this->assert( $this->CALC( '$NOT(1)' ) == 0 );
}

sub test_ODD {
    my ($this) = @_;
    $this->assert( $this->CALC( '$ODD(2)' ) == 0 );
    $this->assert( $this->CALC( '$ODD(1)' ) == 1 );
    $this->assert( $this->CALC( '$ODD(3)' ) == 1 );
    $this->assert( $this->CALC( '$ODD(0)' ) == 0 );
    $this->assert( $this->CALC( '$ODD(-4)' ) == 0 );
    $this->assert( $this->CALC( '$ODD(-1)' ) == 1 );
}

sub test_OR {
    my ($this) = @_;
    $this->assert( $this->CALC( '$OR(0)' ) == 0 );
    $this->assert( $this->CALC( '$OR(0,0)' ) == 0 );
    $this->assert( $this->CALC( '$OR(0,0,0)' ) == 0 );

    $this->assert( $this->CALC( '$OR(1)' ) == 1 );
    $this->assert( $this->CALC( '$OR(1,0)' ) == 1 );
    $this->assert( $this->CALC( '$OR(0,1)' ) == 1 );
    $this->assert( $this->CALC( '$OR(1,0,0)' ) == 1 );
    $this->assert( $this->CALC( '$OR(1,0,1)' ) == 1 );
    $this->assert( $this->CALC( '$OR(0,1,0)' ) == 1 );
    $this->assert( $this->CALC( '$OR(0,1,1)' ) == 1 );

    $this->assert( $this->CALC( '$OR(0,0,0,0,0,0,0,0,0,1)' ) == 1 );
}

sub test_PERCENTILE {
    my ($this) = @_;
    $this->assert( $this->CALC( '$PERCENTILE(75, 400, 200, 500, 100, 300)' ) == 450 );
}

sub test_PI {
    my ($this) = @_;
    # SMELL: approx. equal
    $this->assert( $this->CALC( '$PI()' ) == 3.14159265358979 );
}

# mult
sub test_PRODUCT {
    my ($this) = @_;
    $this->assert( $this->CALC( '$PRODUCT(0,1,2,3)' ) == 0 );
    $this->assert( $this->CALC( '$PRODUCT(1,2,3)' ) == 6 );
    $this->assert( $this->CALC( '$PRODUCT(6,4,-1)' ) == -24 );
    $this->assert( $this->CALC( '$PRODUCT(84,-0.5)' ) == -42 );
}

sub test_PROPER {
    my ($this) = @_;
    $this->assert( $this->CALC( '$PROPER(a small STEP)' ) eq 'A Small Step' );
    $this->assert( $this->CALC( '$PROPER(f1 (formula-1))' ) eq 'F1 (Formula-1)' );
}

sub test_PROPERSPACE {
    my ($this) = @_;
    $this->assert( $this->CALC( '$PROPERSPACE(Old MacDonald had a ServerFarm, EeEyeEeEyeOh)' ) eq 'Old MacDonald had a Server Farm, Ee Eye Ee Eye Oh' );
}

sub test_RAND {
    my ($this) = @_;
    for ( 1..10 ) {
	$this->assert( $this->CALC( '$RAND(1)' ) < 1 );
	$this->assert( $this->CALC( '$RAND(2)' ) < 2 );
	$this->assert( $this->CALC( '$RAND(0.3)' ) < 0.3 );
    }
}

sub test_REPEAT {
    my ($this) = @_;
    $this->assert( $this->CALC( '$REPEAT(/\, 5)' ) eq q{/\\/\\/\\/\\/\\} );
}

sub test_REPLACE {
    my ($this) = @_;
    $this->assert( $this->CALC( '$REPLACE(abcdefghijk, 6, 5, *)' ) eq 'abcde*k' );
}

sub test_RIGHT {
    warn '$RIGHT not implemented';
}

sub test_RIGHTSTRING {
    my ($this) = @_;
    $this->assert( $this->CALC( '$RIGHTSTRING(abcdefg)' ) eq 'g' );
    $this->assert( $this->CALC( '$RIGHTSTRING(abcdefg, 0)' ) eq '' );
    $this->assert( $this->CALC( '$RIGHTSTRING(abcdefg, 5)' ) eq 'cdefg' );
    $this->assert( $this->CALC( '$RIGHTSTRING(abcdefg, 10)' ) eq 'abcdefg' );
    $this->assert( $this->CALC( '$RIGHTSTRING(abcdefg, -2)' ) eq '' );
}

sub test_ROUND {
    my ($this) = @_;
    $this->assert( $this->CALC( '$ROUND(3.15, 1)' ) == 3.2 );
    $this->assert( $this->CALC( '$ROUND(3.149, 1)' ) == 3.1 );
    $this->assert( $this->CALC( '$ROUND(-2.475, 2)' ) == -2.48 );
    $this->assert( $this->CALC( '$ROUND(34.9, -1)' ) == 30 );
    $this->assert( $this->CALC( '$ROUND(34.9)' ) == 35 );
    $this->assert( $this->CALC( '$ROUND(34.9, 0)' ) == 35 );
}

sub test_ROW {
    warn '$ROW not implemented';
}

sub test_SEARCH {
    my ($this) = @_;
    $this->assert( $this->CALC( '$SEARCH([uy], fluffy)' ) == 3 );
    $this->assert( $this->CALC( '$SEARCH([uy], fluffy, 4)' ) == 6 );
    $this->assert( $this->CALC( '$SEARCH([abc], fluffy,)' ) == 0 );
}

sub test_SET {
    warn '$SET not implemented';
}

sub test_SETIFEMPTY {
    warn '$SETIFEMPTY not implemented';
}

sub test_SETM {
    warn '$SETM not implemented';
}

sub test_SIGN {
    my ($this) = @_;
    $this->assert( $this->CALC( '$SIGN(-12.5)' ) == -1 );
    $this->assert( $this->CALC( '$SIGN(12.5)' ) == 1 );
    $this->assert( $this->CALC( '$SIGN(0)' ) == 0 );
    $this->assert( $this->CALC( '$SIGN(-0)' ) == 0 );
}

sub test_SQRT {
    my ($this) = @_;
    $this->assert( $this->CALC( '$SQRT(16)' ) == 4 );
    $this->assert( $this->CALC( '$SQRT(0)' ) == 0 );
    $this->assert( $this->CALC( '$SQRT(1)' ) == 1 );
#    $this->assert( $this->CALC( '$SQRT(-1)' ) == undef );
}

sub test_SUBSTITUTE {
    my ($this) = @_;
    $this->assert( $this->CALC( '$SUBSTITUTE(Good morning, morning, day)' ) eq 'Good day' );
    $this->assert( $this->CALC( '$SUBSTITUTE(Q2-2002, 2, 3)' ) eq 'Q3-3003' );
    $this->assert( $this->CALC( '$SUBSTITUTE(Q2-2002,2, 3, 3)' ) eq 'Q2-2003' );
    $this->assert( $this->CALC( '$SUBSTITUTE(abc123def, [0-9], 9, , r)' ) eq 'abc999def' );
}

sub test_SUBSTRING {
    my ($this) = @_;
    $this->assert( $this->CALC( '$SUBSTRING(abcdefghijk, 3, 5)' ) eq 'cdefg' );
    $this->assert( $this->CALC( '$SUBSTRING(abcdefghijk, 3, 20)' ) eq 'cdefghijk' );
    $this->assert( $this->CALC( '$SUBSTRING(abcdefghijk, -5, 3)' ) eq 'ghi' );
}

sub test_SUM {
    my ($this) = @_;
    $this->assert( $this->CALC( '$SUM(0)' ) == 0 );
    $this->assert( $this->CALC( '$SUM(1,2)' ) == 3 );
    $this->assert( $this->CALC( '$SUM(0,0,1,1,2,3,5,8,13)' ) == 33 );
}

sub test_SUMDAYS {
    my ($this) = @_;
    $this->assert( $this->CALC( '$SUMDAYS(2w, 1, 2d, 4h)' ) == 13.5 );
}

sub test_SUMPRODUCT {
    warn '$SUMPRODUCT not implemented';
}

sub test_T {
    my ($this) = @_;
    warn '$T not implemented';
###    $this->assert( $this->CALC( '$T(R1:C5)' ) eq '...' );
}

sub test_TIME {
    my ($this) = @_;
    $this->assert( $this->CALC( '$TIME(2003/10/14 GMT)' ) eq '1066089600' );
}

sub test_TIMEADD {
    my ($this) = @_;
    $this->assert( $this->CALC( '$TIMEADD($TIME(2009/04/29), 90, minute)' ) == 1240968600 );
    $this->assert( $this->CALC( '$TIMEADD($TIME(2009/04/29), 1, month)' ) == 1243591488 );
    $this->assert( $this->CALC( '$TIMEADD($TIME(2009/04/29), 1, year)' ) == 1272499200 );
}

sub test_TIMEDIFF {
    my ($this) = @_;
    $this->assert( $this->CALC( '$TIMEDIFF($TIME(), $EVAL($TIME()+90), minute)' ) == 1.5 );
}

sub test_TODAY {
    my ($this) = @_;
    warn '$TODAY not implemented';
}

sub test_TRANSLATE {
    my ($this) = @_;
    $this->assert( $this->CALC( '$TRANSLATE(boom,bm,cl)' ) eq 'cool' );
    $this->assert( $this->CALC( '$TRANSLATE(one, two,$comma,;)' ) eq 'one; two' );
}

sub test_TRIM {
    my ($this) = @_;
    $this->assert( $this->CALC( '$TRIM( eat  spaces  )' ) eq 'eat spaces' );
}

sub test_UPPER {
    my ($this) = @_;
    $this->assert( $this->CALC( '$UPPER(uppercase)' ) eq 'UPPERCASE' );
    $this->assert( $this->CALC( '$UPPER(UPPERCASE)' ) eq 'UPPERCASE' );
    $this->assert( $this->CALC( '$UPPER(uPpErCaSe)' ) eq 'UPPERCASE' );
    $this->assert( $this->CALC( '$UPPER()' ) eq '' );
    $this->assert( $this->CALC( '$UPPER(`~!@#$%^&*_+{}|:"<>?)' ) eq q(`~!@#$%^&*_+{}|:"<>?) );
}

sub test_VALUE {
    my ($this) = @_;
    $this->assert( $this->CALC( '$VALUE(US$1,200)' ) == 1200 );
    $this->assert( $this->CALC( '$VALUE(PrjNotebook1234)' ) == 1234 );
    $this->assert( $this->CALC( '$VALUE(Total: -12.5)' ) == -12.5 );
}

sub test_WORKINGDAYS {
    my ($this) = @_;
    $this->assert( $this->CALC( '$WORKINGDAYS($TIME(2004/07/15), $TIME(2004/08/03))' ) == 13 );
}

# undocumented - same as $SUMDAYS
#sub test_DURATION {
#}

# deprecated and undocumented
#sub test_MULT {
#}

# undocumted - same as $AVERAGE
#sub test_MEAN {
#}

# undocumented (same as $SUBSTRING)
#sub test_MIDSTRING {
#}

1;
