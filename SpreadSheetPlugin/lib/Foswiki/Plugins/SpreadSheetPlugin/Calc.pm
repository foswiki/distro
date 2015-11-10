# See bottom of file for license and copyright information
#
# This is part of Foswiki's Spreadsheet Plugin.
#
# The code below is kept out of the main plugin module for
# performance reasons, so it doesn't get compiled until it
# is actually used.

package Foswiki::Plugins::SpreadSheetPlugin::Calc;

use strict;
use warnings;
use HTML::Entities;
use Time::Local;
use Time::Local qw( timegm_nocheck timelocal_nocheck );    # Necessary for DOY

# =========================
my $web;
my $topic;
my $debug;
my @tableMatrix;
my $cPos;
my $rPos;
my $escToken = "\0";
my $escComma =
  "\1";    # Single char escapes so that size functions work as expected
my $escOpenP    = "\2";
my $escCloseP   = "\3";
my $escNewLn    = "\4";
my %varStore    = ();
my $dontSpaceRE = "";

# SMELL: I18N
my @monArr = (
    "Jan", "Feb", "Mar", "Apr", "May", "Jun",
    "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
);
my @wdayArr = (
    "Sunday",   "Monday", "Tuesday", "Wednesday",
    "Thursday", "Friday", "Saturday"
);
my %mon2num;
{
    my $count = 0;
    %mon2num = map { $_ => $count++ } @monArr;
}
my $recurseFunc = \&_recurseFunc;

my $allowHTML;

# =========================
sub init {
    ( $web, $topic, $debug ) = @_;

    # initialize variables, once per page view
    %varStore    = ();
    $dontSpaceRE = "";

    $allowHTML =
      Foswiki::Func::getPreferencesFlag("SPREADSHEETPLUGIN_ALLOWHTML");

    # Module initialized
    Foswiki::Func::writeDebug(
        "- Foswiki::Plugins::SpreadSheetPlugin::Calc::init( $web.$topic )")
      if $debug;
    return 1;
}

# =========================
sub CALC {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    Foswiki::Func::writeDebug("- SpreadSheetPlugin::Calc::CALC( $_[2].$_[1] )")
      if $debug;

    @tableMatrix = ();
    $cPos        = -1;
    $rPos        = -1;
    $web         = $_[2];

    my @result      = ();
    my $insidePRE   = 0;
    my $insideTABLE = 0;
    my $line        = "";
    my $before      = "";
    my $cell        = "";
    my @row         = ();

    $_[0] =~ s/\r//g;
    $_[0] =~ s/\\\n//g;    # Join lines ending in "\"
    foreach ( split( /\n/, $_[0] ) ) {

        # change state:
        m|<pre>|i       && ( $insidePRE = 1 );
        m|<verbatim>|i  && ( $insidePRE = 1 );
        m|</pre>|i      && ( $insidePRE = 0 );
        m|</verbatim>|i && ( $insidePRE = 0 );

        if ( !($insidePRE) ) {

            if (/^\s*\|.*\|\s*$/) {

                # inside | table |
                if ( !$insideTABLE ) {
                    $insideTABLE = 1;
                    @tableMatrix = ();    # reset table matrix
                    $cPos        = -1;
                    $rPos        = -1;
                }
                $line = $_;
                $line =~ s/^(\s*\|)(.*)\|\s*$/$2/;
                $before = $1;
                @row = split( /\|/, $line, -1 );
                $row[0] = '' unless @row;    # See Item5163
                push( @tableMatrix, [@row] );
                $rPos++;
                $line = "$before";

                for ( $cPos = 0 ; $cPos < @row ; $cPos++ ) {
                    $cell = $row[$cPos];
                    $cell =~ s/%CALC\{(.*?)\}%/_doCalc($1)/ge;
                    $line .= "$cell|";
                }
                s/.*/$line/;

            }
            else {

                # outside | table |
                if ($insideTABLE) {
                    $insideTABLE = 0;
                }
                s/%CALC\{(.*?)\}%/_doCalc($1)/ge;
            }
        }
        push( @result, $_ );
    }
    $_[0] = join( "\n", @result );
    return $_[0];
}

# =========================
sub _doCalc {
    my ($theAttributes) = @_;

    my $text = &Foswiki::Func::extractNameValuePair($theAttributes);

    # Escape commas, parenthesis and newlines in tripple quoted strings
    $text =~ s/'''(.*?)'''/_escapeString($1)/ges;

    # For better performance, use a function reference when calling the recurse
    # functions, instead of an "if" statement within the &$recurseFunc function
    if ( $text =~ /\n/ ) {

# recursively evaluate functions, and remove white space around functions and parameters
        $recurseFunc = \&_recurseFuncCutWhitespace;
    }
    else {

# recursively evaluate functions without removing white space (compatible with old spec)
        $recurseFunc = \&_recurseFunc;
    }

    # Add nesting level to parenthesis,
    # e.g. "A(B())" gets "A-esc-1(B-esc-2(-esc-2)-esc-1)"
    my $level = 0;
    $text =~ s/([\(\)])/_addNestingLevel($1, \$level)/ge;
    $text = _doFunc( "MAIN", $text );

    if ( defined($rPos) && defined($cPos) && $rPos >= 0 && $cPos >= 0 ) {

        # update cell in table matrix
        $tableMatrix[$rPos][$cPos] = $text;
    }

    # Restore escaped strings
    $text =~ s/$escComma/,/g;
    $text =~ s/$escOpenP/\(/g;
    $text =~ s/$escCloseP/\)/g;
    $text =~ s/$escNewLn/\n/g;

    unless ($allowHTML) {

        # encode < > to prevent html insertion
        # SMELL: what about '"%
        $text =~ s/([<>])/HTML::Entities::encode_entities($1)/ge;
    }
    return $text;
}

# =========================
sub _escapeString {
    my ($text) = @_;
    $text =~ s/,/$escComma/g;
    $text =~ s/\(/$escOpenP/g;
    $text =~ s/\)/$escCloseP/g;
    $text =~ s/\n/$escNewLn/g;
    return $text;
}

# =========================
sub _addNestingLevel {
    my ( $theParen, $theLevelRef ) = @_;

    my $result = "";
    if ( $theParen eq "(" ) {
        $$theLevelRef++;
        $result = "$escToken$$theLevelRef$theParen";
    }
    else {
        $result = "$escToken$$theLevelRef$theParen";
        $$theLevelRef--;
    }
    return $result;
}

# =========================
sub _recurseFunc {

    # Handle functions recursively
    no warnings 'uninitialized';
    $_[0] =~
s/\$([A-Z]+[A-Z0-9]*)$escToken([0-9]+)\((.*?)$escToken\2\)/_doFunc($1,$3)/geos;
    use warnings 'uninitialized';

    # Clean up unbalanced mess
    $_[0] =~ s/$escToken\-*[0-9]+([\(\)])/$1/go;
}

# =========================
sub _recurseFuncCutWhitespace {

    # Handle functions recursively
    $_[0] =~
s/\s*\$([A-Z]+[A-Z0-9]*)$escToken([0-9]+)\(\s*(.*?)\s*$escToken\2\)\s*/_doFunc($1,$3)/geos;

    # Clean up unbalanced mess
    $_[0] =~ s/$escToken\-*[0-9]+([\(\)])/$1/go;
}

#<<<  do not let perltidy touch this
    # Commented functions new in TWiki
my $Function = {
    ABOVE            => sub { my  $i = $cPos + 1; return "R1:C$i..R$rPos:C$i" },
    ABS              => sub { abs( _getNumber($_[0]) ) },
    # ADDLIST
    AND              => \&_AND,
    AVERAGE          => \&_AVERAGE,
    BIN2DEC          => \&_BIN2DEC,
    BITXOR           => \&_BITXOR,
    CEILING          => \&_CEILING,
    CHAR             => \&_CHAR,
    CODE             => sub { ord($_[0]) },
    COLUMN           => sub { $cPos + ( $_[0] || 0 ) + 1 },
    COUNTITEMS       => \&_COUNTITEMS,
    COUNTSTR         => \&_COUNTSTR,
    DEC2BIN          => \&_DEC2BIN,
    DEC2HEX          => \&_DEC2HEX,
    DEC2OCT          => \&_DEC2OCT,
    DEF              => \&_DEF,
    EMPTY            => sub { ( length($_[0]) ) ? 0 : 1 },
    EVAL             => sub { _safeEvalPerl($_[0]) },
    EVEN             => sub { ( _getNumber($_[0]) + 1 ) % 2 },
    EXACT            => \&_EXACT,
    EXEC             => \&_EXEC,
    EXISTS           => sub { ( Foswiki::Func::topicExists( $web, $_[0] ) ) ? 1 : 0 },
    EXP              => sub { exp( _getNumber($_[0]) ) },
    FILTER           => \&_FILTER,
    FIND             => \&_FIND,
    FLOOR            => \&_FLOOR,
    FORMAT           => \&_FORMAT,
    FORMATGMTIME     => \&_FORMATGMTIME,
    FORMATTIME       => \&_FORMATTIME,
    FORMATTIMEDIFF   => \&_FORMATTIMEDIFF,
    GET              => \&_GET,
    # GETHASH
    # GETLIST  - Get a saved list
    # HASH2LIST - Convert hash to list
    # HASHCOPY - Copy a hash
    # HASHEACH - Evaluate & update each element
    # HASHEXISTS - Test if hash exists
    # HASHREVERSE - Swap keys and values
    HEX2DEC          => \&_HEX2DEC,
    HEXDECODE        => \&_HEXDECODE,
    HEXENCODE        => sub { uc( unpack( "H*", $_[0] ) ) },
    IF               => \&_IF,
    INSERTSTRING     => \&_INSERTSTRING,
    INT              => sub {
                        my $rslt = _safeEvalPerl($_[0]);
                        return ( $rslt =~ /^ERROR/ ) ? $rslt : int( _getNumber($rslt) );
                       },
    ISDIGIT          => sub { ($_[0] =~ m/^[[:digit:]]+$/ ) ? 1 : 0 },
    ISLOWER          => sub { ($_[0] =~ m/^[[:lower:]]+$/ ) ? 1 : 0 },
    ISUPPER          => sub { ($_[0] =~ m/^[[:upper:]]+$/ ) ? 1 : 0 },
    ISWIKIWORD       => sub { (Foswiki::isValidWikiWord( $_[0] ) ) ? 1 : 0 },
    LEFT             => sub { my $i = $rPos + 1; return "R$i:C1..R$i:C$cPos" },
    LEFTSTRING       => \&_LEFTSTRING,
    LENGTH           => sub { length( $_[0] ) },
    LIST             => sub { _listToDelimitedString(_getList($_[0])) },
    # LIST2HASH
    LISTEACH         => \&_LISTMAP,
    LISTIF           => \&_LISTIF,
    LISTITEM         => \&_LISTITEM,
    LISTJOIN         => \&_LISTJOIN,
    LISTMAP          => \&_LISTMAP,
    LISTNONEMPTY     => sub { _listToDelimitedString( grep { /./ } _getList($_[0]) ) },
    LISTRAND         => \&_LISTRAND,
    LISTREVERSE      => sub { _listToDelimitedString(reverse _getList($_[0])) },
    LISTSHUFFLE      => \&_LISTSHUFFLE,
    LISTSIZE         => sub { scalar( _getList($_[0])) },
    LISTSORT         => \&_LISTSORT,
    LISTTRUNCATE     => \&_LISTTRUNCATE,
    LISTUNIQUE       => \&_LISTUNIQUE,
    LN               => sub { log( _getNumber($_[0]) ) },
    LOG              => \&_LOG,
    LOWER            => sub { lc( $_[0] ) },
    MAIN             => sub { $_[0] },
    MAX              => \&_MAX,
    MEDIAN           => \&_MEDIAN,
    MIN              => \&_MIN,
    MOD              => \&_MOD,
    NOEXEC           => sub { $_[0] },
    NOP              => \&_NOP,
    NOT              => sub { ( _getNumber( $_[0] )) ? 0 : 1 },
    OCT2DEC          => \&_OCT2DEC,
    ODD              => sub { _getNumber( $_[0] ) % 2 },
    OR               => \&_OR,
    PERCENTILE       => \&_PERCENTILE,
    PI               => sub { 3.1415926535897932384 },
    PRODUCT          => \&_PRODUCT,
    PROPER           => sub {
        $_[0] =~ s/(\w+)/\u\L$1/g;
        return $_[0];
    },
    PROPERSPACE      => sub { _properSpace($_[0]) },
    RAND             => sub {
                        my $max = _getNumber($_[0]);
                        $max = 1 if ( $max <= 0 );
                        rand($max);
                       },
    RANDSTRING       => \&_RANDSTRING,
    REPEAT           => \&_REPEAT,
    REPLACE          => \&_REPLACE,
    RIGHT            => sub {
                            my $i = $rPos + 1;
                            my $c = $cPos + 2;
                            return "R$i:C$c..R$i:C32000";
                            },
    RIGHTSTRING      => \&_RIGHTSTRING,
    ROUND            => \&_ROUND,
    ROW              => sub { $rPos + ( $_[0] || 0 ) + 1 },
    SEARCH           => \&_SEARCH,
    SET              => \&_SET,
    # SETHASH - Set a hash for later use
    SETIFEMPTY       => \&_SETIFEMPTY,
    # SETLIST - Save a list for later use
    SETM             => \&_SETM,
    # SETMHASH - Modify a hash
    SIGN             => sub {
                         my $i = _getNumber($_[0]);
                         return ( $i > 0 ) ? 1
                             :  ( $i < 0 ) ? -1
                             :  0;
                        },
    SPLIT            => \&_SPLIT,
    SQRT             => sub { sqrt( _getNumber( $_[0] ) ) },
    # STDEV  - Std. Deviation
    # STDEVP - Std. Deviation population
    SUBSTITUTE       => \&_SUBSTITUTE,
    SUBSTRING        => \&_SUBSTRING,
    SUM              => \&_SUM,
    SUMDAYS          => \&_SUMDAYS,,
    SUMPRODUCT       => \&_SUMPRODUCT,
    T                => \&_T,
    TIME             => \&_TIME,
    TIMEADD          => \&_TIMEADD,
    TIMEDIFF         => \&_TIMEDIFF,
    TODAY            => sub { _date2serial( _serial2date( time(), '$year/$month/$day GMT', 1 ) ) },
    TRANSLATE        => \&_TRANSLATE,
    TRIM             => sub {
                         $_[0] =~ s/^\s*//;
                         $_[0] =~ s/\s*$//;
                         $_[0] =~ s/\s+/ /g;
                         return $_[0];
                       },
    UPPER            => sub { uc( $_[0] ) },
    VALUE            => sub { _getNumber( $_[0] ) },
    # VAR  - Variance sample
    # VARP - Variance population
    WHILE            => \&_WHILE,
    WORKINGDAYS      => sub {
                        my ($stime, $etime) = split( /,\s*/, $_[0], 2);
                        _workingDays( _getNumber($stime), _getNumber($etime));
                       },
    XOR              => \&_XOR,
};
#>>>
$Function->{MIDSTRING} = $Function->{SUBSTRING};    # MIDSTRING Undocumented
$Function->{DURATION} = $Function->{SUMDAYS};  # DURATION undocumented, for Sven
$Function->{MULT}     = $Function->{PRODUCT};  # MULT deprecated
$Function->{MEAN}     = $Function->{AVERAGE};  # # Both documented & supported

sub _doFunc {
    my ( $theFunc, $theAttr ) = @_;

    $theAttr = "" unless ( defined $theAttr );
    Foswiki::Func::writeDebug(
        "- SpreadSheetPlugin::Calc::_doFunc: $theFunc( $theAttr ) start")
      if $debug;

    unless ( $theFunc =~ /^(IF|LISTEACH|LISTIF|LISTMAP|NOEXEC|WHILE)$/ ) {
        &$recurseFunc($theAttr);
    }

    # else: delay the function handler to after parsing the parameters,
    # in which case handling functions and cleaning up needs to be done later

    my $result = "";
    my $i      = 0;

    # Execute functions defined in the above $Function hash
    if ( defined $Function->{$theFunc} ) {
        my $f = $Function->{$theFunc};
        $result = &$f($theAttr);
    }

    Foswiki::Func::writeDebug(
"- SpreadSheetPlugin::Calc::_doFunc: $theFunc( $theAttr ) returns: $result"
    ) if $debug;
    return $result;
}

#########################
# Spreadsheet Cells
#########################

# ======================
sub _T {
    my @arr = _getTableRange("$_[0]..$_[0]");
    return (@arr) ? $arr[0] : '';
}

# ======================
sub _DEF {

    # Format DEF(list) returns first defined cell
    # Added by MF 26/3/2002, fixed by PeterThoeny
    my $result = '';
    my @arr    = _getList( $_[0] );
    foreach my $cell (@arr) {
        if ($cell) {
            $cell =~ s/^\s*(.*?)\s*$/$1/;
            if ($cell) {
                $result = $cell;
                last;
            }
        }
    }
    return $result;
}

#########################
#  Conditional and Looping
#########################

# ======================
sub _EXEC {

    # add nesting level escapes
    my $level = 0;
    $_[0] =~ s/([\(\)])/_addNestingLevel($1, \$level)/ge;

# execute functions in attribute recursively and clean up unbalanced parenthesis
    &$recurseFunc( $_[0] );
    return $_[0];
}

# =======================
sub _IF {

    # IF(condition, value if true, value if false)
    my ( $condition, $str1, $str2 ) = _properSplit( $_[0], 3 );

# with delay, handle functions in condition recursively and clean up unbalanced parenthesis
    &$recurseFunc($condition);
    $condition =~ s/^\s*(.*?)\s*$/$1/;
    my $result = _safeEvalPerl($condition);
    unless ( $result =~ /^ERROR/ ) {
        if ($result) {
            $result = $str1;
        }
        else {
            $result = $str2;
        }
        $result = "" unless ( defined($result) );

# with delay, handle functions in result recursively and clean up unbalanced parenthesis
        &$recurseFunc($result);

    }    # else return error message
    return $result;
}

# =========================
sub _NOP {

    # pass everything through, this will allow plugins to defy plugin order
    # for example the %SEARCH{}% variable
    $_[0] =~ s/\$per(cnt)?/%/g;
    $_[0] =~ s/\$quot/"/g;
    return $_[0];
}

# ===========================
sub _WHILE {

    # WHILE(condition, do something)
    my ( $condition, $str ) = _properSplit( $_[0], 2 );
    return '' unless defined $condition;
    my $result;
    my $i = 0;
    while (1) {
        if ( $i++ >= 32767 ) {
            $result .= 'ERROR: Infinite loop (32767 cycles)';
            last;    # prevent infinite loop
        }

# with delay, handle functions in condition recursively and clean up unbalanced parenthesis
        my $cond = $condition;
        $cond =~ s/\$counter/$i/g;
        &$recurseFunc($cond);
        $cond =~ s/^\s*(.*?)\s*$/$1/;
        my $res = _safeEvalPerl($cond);
        if ( $res =~ /^ERROR/ ) {
            $result .= $res;
            last;    # exit loop and return error
        }
        last unless ($res);    # proper loop exit
        $res = $str;
        $res = "" unless ( defined($res) );

# with delay, handle functions in result recursively and clean up unbalanced parenthesis
        $res =~ s/\$counter/$i/g;
        &$recurseFunc($res);
        $result .= $res;
    }
    return $result;
}

#######################
# Numeric Functions
#######################

# =========================
sub _AVERAGE {
    my $result = 0;
    my $items  = 0;
    my @arr    = _getListAsFloat( $_[0] );
    foreach my $i (@arr) {
        if ( defined $i ) {
            $result += $i;
            $items++;
        }
    }
    if ( $items > 0 ) {
        $result = $result / $items;
    }
    return $result;
}

# =========================
sub _CEILING {
    my $i      = _getNumber( $_[0] );
    my $result = int($i);
    if ( $i > 0 && $i != $result ) {
        $result += 1;
    }
    return $result;
}

# =========================
sub _BIN2DEC {

    $_[0] =~ s/[^0-1]//g;    # only binary digits
    $_[0] ||= 0;
    return oct( '0b' . $_[0] );
}

# =========================
sub _DEC2BIN {

    my ( $num, $size ) = _getListAsInteger( $_[0] );
    $num ||= 0;
    my $format = '%';
    $format .= '0' . $size if ($size);
    $format .= 'b';
    return sprintf( $format, $num );
}

# =========================
sub _HEX2DEC {

    $_[0] =~ s/[^0-9A-Fa-f]//g;    # only hex numbers
    $_[0] ||= 0;
    return hex( $_[0] );
}

# =========================
sub _DEC2HEX {

    my ( $num, $size ) = _getListAsInteger( $_[0] );
    $num ||= 0;
    my $format = '%';
    $format .= '0' . $size if ($size);
    $format .= 'X';
    return sprintf( $format, $num );
}

# =========================
sub _OCT2DEC {

    $_[0] =~ s/[^0-7]//g;    # only octal digits
    $_[0] ||= 0;
    return oct( $_[0] );
}

# =========================
sub _DEC2OCT {

    my ( $num, $size ) = _getListAsInteger( $_[0] );
    $num ||= 0;
    my $format = '%';
    $format .= '0' . $size if ($size);
    $format .= 'o';
    return sprintf( $format, $num );
}

# =========================
sub _FLOOR {
    my $i      = _getNumber( $_[0] );
    my $result = int($i);
    if ( $i < 0 && $i != $result ) {
        $result -= 1;
    }
    return $result;
}

# =====================
sub _FORMAT {

# Format FORMAT(TYPE, precision, value) returns formatted value -- JimStraus - 05 Jan 2003
    my ( $format, $res, $value ) = split( /,\s*/, $_[0] );
    $format =~ s/^\s*(.*?)\s*$/$1/;    #Strip leading and trailing spaces
    $res    =~ s/^\s*(.*?)\s*$/$1/;
    $value  =~ s/^\s*(.*?)\s*$/$1/;
    $res    =~ m/^(.*)$/;              # SMELL why do we need to untaint
    $res = $1;
    my $result = '';
    if ( $format eq "DOLLAR" ) {
        my $neg = 0;
        $neg    = 1 if $value < 0;
        $value  = abs($value);
        $result = sprintf( "%0.${res}f", $value );
        my $temp = reverse $result;
        $temp =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
        $result = "\$" . ( scalar( reverse($temp) ) );
        $result = "(" . $result . ")" if $neg;
    }

    # TWIKI: Added CURRENCY format
    elsif ( $format eq "COMMA" ) {
        $result = sprintf( "%0.${res}f", $value );
        my $temp = reverse $result;
        $temp =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
        $result = scalar( reverse($temp) );
    }
    elsif ( $format eq "PERCENT" ) {
        $result = sprintf( "%0.${res}f%%", $value * 100 );
    }
    elsif ( $format eq "NUMBER" ) {
        $result = sprintf( "%0.${res}f", $value );
    }
    elsif ( $format eq "K" ) {
        $result = sprintf( "%0.${res}f K", $value / 1024 );
    }
    elsif ( $format eq "KB" ) {
        $result = sprintf( "%0.${res}f KB", $value / 1024 );
    }
    elsif ( $format eq "MB" ) {
        $result = sprintf( "%0.${res}f MB", $value / ( 1024 * 1024 ) );
    }
    elsif ( $format =~ /^KBMB/ ) {
        $value /= 1024;
        my @lbls = ( "MB", "GB", "TB", "PB", "EB", "ZB" );
        my $lbl = "KB";
        while ( $value >= 1024 && @lbls ) {
            $value /= 1024;
            $lbl = shift @lbls;
        }
        $result = sprintf( "%0.${res}f", $value ) . " $lbl";
    }
    else {

        # FORMAT not recognized, just return value
        $result = $value;
    }
    return $result;
}

# =========================
sub _HEXDECODE {
    my $theAttr = shift;
    $theAttr =~ s/[^0-9A-Fa-f]//g;                     # only hex numbers
    $theAttr =~ s/.$// if ( length($theAttr) % 2 );    # must be set of two
    return pack( "H*", $theAttr );
}

# =======================
sub _LOG {

    my ( $num, $base ) = split( /,\s*/, $_[0], 2 );
    $num  = _getNumber($num);
    $base = _getNumber($base);
    $base = 10 if ( $base <= 0 );
    return log($num) / log($base);

}

# =========================
sub _MAX {
    my @arr = sort { $a <=> $b }
      grep { /./ }
      grep { defined $_ } _getListAsFloat( $_[0] );
    return $arr[-1];
}

# =========================
sub _MEDIAN {
    my @arr =
      sort { $a <=> $b } grep { defined $_ } _getListAsFloat( $_[0] );
    my $i      = @arr;
    my $result = '';
    if ( ( $i % 2 ) > 0 ) {
        $result = $arr[ $i / 2 ];
    }
    elsif ($i) {
        $i /= 2;
        $result = ( $arr[$i] + $arr[ $i - 1 ] ) / 2;
    }
    return $result;
}

# =========================
sub _MIN {
    my @arr = sort { $a <=> $b }
      grep { /./ }
      grep { defined $_ } _getListAsFloat( $_[0] );
    return $arr[0];
}

# =======================
sub _MOD {

    my $result = 0;
    my ( $num1, $num2 ) = split( /,\s*/, $_[0], 2 );
    $num1 = _getNumber($num1);
    $num2 = _getNumber($num2);
    if ( $num1 && $num2 ) {
        $result = $num1 % $num2;
    }
    return $result;
}

# =========================
sub _PERCENTILE {
    my ( $percentile, $set ) = split( /,\s*/, $_[0], 2 );
    my $i;
    my @arr = sort { $a <=> $b } grep { defined $_ } _getListAsFloat($set);
    my $result = 0;

    my $size = scalar(@arr);
    if ( $size > 0 ) {
        $i = $percentile / 100 * ( $size + 1 );
        my $iInt = int($i);
        if ( $i <= 1 ) {
            $result = $arr[0];
        }
        elsif ( $i >= $size ) {
            $result = $arr[ $size - 1 ];
        }
        elsif ( $i == $iInt ) {
            $result = $arr[ $i - 1 ];
        }
        else {

            # interpolate beween neighbors # Example: $i = 7.25
            my $r1 = $iInt + 1 - $i;      # 0.75 = 7 + 1 - 7.25
            my $r2 = 1 - $r1;             # 0.25 = 1 - 0.75
            my $x1 = $arr[ $iInt - 1 ];
            my $x2 = $arr[$iInt];
            $result = ( $r1 * $x1 ) + ( $r2 * $x2 );
        }
    }
    return $result;
}

# =========================
sub _PRODUCT {
    my $result = 0;
    my @arr    = _getListAsFloat( $_[0] );

    # no arguments,  return 0.
    return 0 unless scalar @arr;
    $result = 1;
    foreach my $i (@arr) {
        $result *= $i if defined $i;
    }
    return $result;
}

# =========================
sub _ROUND {

    # ROUND(num, digits)
    my ( $num, $digits ) = split( /,\s*/, $_[0], 2 );
    my $result = _safeEvalPerl($num);
    unless ( $result =~ /^ERROR/ ) {
        $result = _getNumber($result);
        if (   ($digits)
            && ( $digits =~ s/^.*?(\-?[0-9]+).*$/$1/ )
            && ($digits) )
        {
            my $factor = 10**$digits;
            $result *= $factor;
            ( $result >= 0 ) ? ( $result += 0.5 ) : ( $result -= 0.5 );
            $result = int($result);
            $result /= $factor;
        }
        else {
            ( $result >= 0 ) ? ( $result += 0.5 ) : ( $result -= 0.5 );
            $result = int($result);
        }
    }
    return $result;
}

# =========================
sub _SUM {
    my $result = 0;
    my @arr    = _getListAsFloat( $_[0] );
    foreach my $i (@arr) {
        $result += $i if defined $i;
    }
    return $result;
}

# =========================
sub _SUMPRODUCT {
    my $result = 0;
    my @arr;
    my @lol = split( /,\s*/, $_[0] );
    my $size = 32000;
    for my $i ( 0 .. $#lol ) {
        @arr     = _getListAsFloat( $lol[$i] );
        $lol[$i] = [@arr];                        # store reference to array
        $size    = @arr if ( @arr < $size );      # remember smallest array
    }
    if ( ( $size > 0 ) && ( $size < 32000 ) ) {
        my $y;
        my $prod;
        my $val;
        $size--;
        for my $y ( 0 .. $size ) {
            $prod = 1;
            for my $i ( 0 .. $#lol ) {
                $val = $lol[$i][$y];
                if ( defined $val ) {
                    $prod *= $val;
                }
                else {
                    $prod = 0;    # don't count empty cells
                }
            }
            $result += $prod;
        }
    }
    return $result;
}

#######################
#   GET / SET Functions
#######################

# =========================
sub _GET {
    my $name = $_[0];
    $name =~ s/[^a-zA-Z0-9\_]//g;
    my $result = $varStore{$name} if ($name);
    $result = "" unless ( defined($result) );
    return $result;
}

# =========================
sub _SET {
    my ( $name, $value ) = split( /,\s*/, $_[0], 2 );
    return '' unless defined $name;
    $name =~ s/[^a-zA-Z0-9\_]//g;
    if ( $name && defined($value) ) {
        $value =~ s/\s*$//;
        $varStore{$name} = $value;
    }
    return '';
}

# =========================
sub _SETIFEMPTY {
    my ( $name, $value ) = split( /,\s*/, $_[0], 2 );
    return '' unless defined $name;
    $name =~ s/[^a-zA-Z0-9\_]//g;
    if ( $name && defined($value) && !$varStore{$name} ) {
        $value =~ s/\s*$//;
        $varStore{$name} = $value;
    }
    return '';
}

# =========================
sub _SETM {
    my ( $name, $value ) = split( /,\s*/, $_[0], 2 );
    return '' unless defined $name;
    $name =~ s/[^a-zA-Z0-9\_]//g;
    if ($name) {
        my $old = $varStore{$name};
        $old   = "" unless ( defined($old) );
        $value = "" unless ( defined($value) );
        $value = _safeEvalPerl("$old $value");
        $varStore{$name} = $value;
    }
    return '';
}

#######################
#   LIST Functions
#######################

# =====================
sub _COUNTITEMS {
    my $result = '';
    my @arr    = _getList( $_[0] );
    my %items  = ();
    foreach my $key (@arr) {
        $key =~ s/^\s*(.*?)\s*$/$1/ if ($key);
        if ($key) {
            if ( exists( $items{$key} ) ) {
                $items{$key}++;
            }
            else {
                $items{$key} = 1;
            }
        }
    }
    foreach my $key ( sort keys %items ) {
        $result .= "$key: $items{ $key }%BR% ";
    }
    $result =~ s|%BR% $||;
    return $result;
}

# =========================
# LISTIF(cmd, item 1, item 2, ...)
#
sub _LISTIF {
    my ( $cmd, $str ) = _properSplit( $_[0], 2 );
    $cmd = "" unless ( defined($cmd) );
    $cmd =~ s/^\s*(.*?)\s*$/$1/;
    $str = "" unless ( defined($str) );

# with delay, handle functions in result $str and clean up unbalanced parenthesis
    &$recurseFunc($str);

    my $item = qw{};
    my $eval = qw{};
    my $i    = 0;
    my @arr =
      grep { !/^FOSWIKI_GREP_REMOVE$/ }
      map {
        $item = $_;
        $_    = $cmd;
        $i++;
        s/\$index/$i/g;
        s/\$item/$item/g;
        &$recurseFunc($_);
        $eval = _safeEvalPerl($_);
        if ( $eval =~ /^ERROR/ ) {
            $_ = $eval;
        }
        elsif ($eval) {
            $_ = $item;
        }
        else {
            $_ = "FOSWIKI_GREP_REMOVE";
        }
      } _getList($str);
    return _listToDelimitedString(@arr);
}

# =========================
sub _LISTITEM {
    my ( $index, $str ) = _properSplit( $_[0], 2 );
    my $result = '';
    $index = _getNumber($index);
    $str = "" unless ( defined($str) );
    my @arr  = _getList($str);
    my $size = scalar(@arr);
    if ( $index && $size ) {
        $index-- if ( $index > 0 );    # documented index starts at 1
        $index = $size + $index
          if ( $index < 0 );           # start from back if negative
        $result = $arr[$index] if ( ( $index >= 0 ) && ( $index < $size ) );
    }
    return $result;
}

# =========================
sub _LISTJOIN {
    my ( $sep, $str ) = _properSplit( $_[0], 2 );
    $str = "" unless ( defined($str) );

# SMELL: repairing standard delimiter ", " in the constructed string to our custom separator
    my $result = _listToDelimitedString( _getList($str) );
    if ( length $sep ) {
        $sep =~ s/\$comma/,/g;
        $sep =~ s/\$sp/ /g;
        $sep =~ s/\$(nop|empty)//g
          ;  # make sure $nop appears before $n otherwise you end up with "\nop"
        $sep    =~ s/\$n/\n/g;
        $result =~ s/, /$sep/g;
    }
    return $result;
}

# =========================
sub _LISTMAP {

    # LISTMAP(action, item 1, item 2, ...)
    my ( $action, $str ) = _properSplit( $_[0], 2 );
    $action = "" unless ( defined($action) );
    $str    = "" unless ( defined($str) );

# with delay, handle functions in $str recursively and clean up unbalanced parenthesis
    &$recurseFunc($str);

    my $item = qw{};
    my $i    = 0;
    my @arr  = map {
        $item = $_;
        $_    = $action;
        $i++;
        s/\$index/$i/g;
        $_ .= $item unless (s/\$item/$item/g);
        &$recurseFunc($_);
        $_
    } _getList($str);
    return _listToDelimitedString(@arr);
}

# =========================
sub _LISTRAND {
    my @arr    = _getList( $_[0] );
    my $size   = scalar(@arr);
    my $result = '';
    if ( $size > 0 ) {
        my $i = int( rand($size) );
        $result = $arr[$i];
    }
    return $result;
}

# =========================
sub _LISTSHUFFLE {
    my @arr  = _getList( $_[0] );
    my $size = scalar(@arr);
    if ( $size > 1 ) {
        for ( my $i = $size ; $i-- ; ) {
            my $j = int( rand( $i + 1 ) );
            next if ( $i == $j );
            @arr[ $i, $j ] = @arr[ $j, $i ];
        }
    }
    return _listToDelimitedString(@arr);
}

# =========================
sub _LISTSORT {
    my $isNumeric = 1;
    my @arr       = map {
        $isNumeric = 0 unless ( $_ =~ /^[\+\-]?[0-9\.]+$/ );
        $_
    } _getList( $_[0] );
    if ($isNumeric) {
        @arr = sort { $a <=> $b } @arr;
    }
    else {
        @arr = sort @arr;
    }
    return _listToDelimitedString(@arr);
}

# =========================
sub _LISTTRUNCATE {
    my ( $index, $str ) = _properSplit( $_[0], 2 );
    $index = int( _getNumber($index) );
    $str = "" unless ( defined($str) );
    my @arr    = _getList($str);
    my $size   = scalar(@arr);
    my $result = '';
    if ( $index > 0 ) {
        $index  = $size if ( $index > $size );
        $#arr   = $index - 1;
        $result = _listToDelimitedString(@arr);
    }
    elsif ( $index < 0 ) {
        $index = -$size if ( $index < -$size );
        splice( @arr, 0, $size + $index );
        $result = _listToDelimitedString(@arr);
    }
    return $result;
}

# =========================
sub _LISTUNIQUE {
    my %seen = ();
    my @arr = grep { !$seen{$_}++ } _getList( $_[0] );
    return _listToDelimitedString(@arr);
}

###########################
#  Logical functions
###########################

# =========================
sub _AND {
    my $result = 0;
    my @arr    = _getListAsInteger( $_[0] );
    foreach my $i (@arr) {
        unless ($i) {
            $result = 0;
            last;
        }
        $result = 1;
    }
    return $result;
}

# =========================
sub _OR {
    my $result = 0;
    my @arr    = _getListAsInteger( $_[0] );
    foreach my $i (@arr) {
        if ($i) {
            $result = 1;
            last;
        }
    }
    return $result;
}

# =========================
sub _XOR {
    my @arr    = _getListAsInteger( $_[0] );
    my $result = shift(@arr);
    if ( scalar(@arr) > 0 ) {
        foreach my $i (@arr) {
            next unless defined $i;
            $result = ( $result xor $i );
        }
    }
    else {
        $result = 0;
    }
    $result = $result ? 1 : 0;
    return $result;
}

# =========================
sub _BITXOR {
    my @arr    = _getList( $_[0] );
    my $result = '';

# SMELL: This usage is bogus.   It takes the ones-complement of the string, and does NOT do a bit-wise XOR
# which would require two operators.   An XOR with itself would clear the field not flip all the bits.
# This should probably be called a BITNOT.
#if ( scalar(@arr) == 1 ) {
#    use bytes;
#    my $ff = chr(255) x length( $_[0] );
#    $result = $_[0] ^ $ff;
#    no bytes;
#}

    # This is a standard bit-wise xor of a list of integers.
    #else {
    @arr = _getListAsInteger( $_[0] );

    return '' unless scalar @arr;
    my $ent = shift(@arr);
    $result = ( defined $ent ) ? int($ent) : 0;
    if ( scalar(@arr) > 0 ) {
        foreach my $i (@arr) {
            next unless defined $i;
            $result = ( $result ^ int($i) );
        }
    }
    else {
        $result = 0;
    }

    #}
    return $result;
}

# =========================
sub _RANDSTRING {
    my ($theAttr) = @_;
    my ( $chars, $format ) = split( /,\s*/, $theAttr, 2 );
    $chars = '' unless defined($chars);
    $chars =~ s/(.)\.\.(.)/_expandRange($1, $2)/ge;
    my @pool = split( //, $chars );
    @pool = ( 'a' .. 'z', 'A' .. 'Z', '0' .. '9', '_' )
      unless ( scalar(@pool) );
    my $num = 0;
    $format = '' unless defined($format);

    if ( $format =~ m/^([0-9]*)$/ ) {
        $num    = _getNumber($format);
        $num    = 8 if ( $num < 1 );
        $num    = 1024 if ( $num > 1024 );
        $format = 'x' x $num;
    }
    else {
        $num = length($format);
    }
    my $result;
    foreach my $ch ( split( //, $format ) ) {
        if ( $ch eq 'x' ) {
            $result .= $pool[ rand @pool ];
        }
        else {
            $result .= $ch;
        }
    }
    return $result;
}

# =========================
sub _expandRange {
    my ( $lowCh, $highCh ) = @_;
    my $text =
      "$1$2";    # in case out of range, return just low char and high char
    if ( ord $highCh > ord $lowCh ) {
        $text = join( '', ( $lowCh .. $highCh ) );
    }
    return $text;
}

##########################
# DATE / TIME Functions
# #######################

# =========================
sub _FORMATGMTIME {

    # Call FORMATTIME with flag to suggest use GMT
    _FORMATTIME( $_[0], '1' );
}

# =========================
sub _FORMATTIME {

    #elsif ( $theFunc =~ /^(FORMATTIME|FORMATGMTIME)$/ ) {

    my ( $time, $str ) = split( /,\s*/, $_[0], 2 );
    if ( $time =~ /(-?[0-9]+)/ ) {
        $time = $1;
    }
    else {
        $time = time();
    }
    my $isGmt = $_[1] || 0;
    $isGmt = 1
      if ( ( $str =~ m/ gmt/i ) );
    return _serial2date( $time, $str, $isGmt );
}

# =========================
sub _FORMATTIMEDIFF {
    my ( $scale, $prec, $time ) = split( /,\s*/, $_[0], 3 );
    $scale = "" unless ($scale);
    $prec  = int( _getNumber($prec) - 1 );
    $prec  = 0 if ( $prec < 0 );
    $time  = _getNumber($time);
    $time *= -1 if ( $time < 0 );
    my @unit = ( 0, 0, 0, 0, 0, 0 );    # sec, min, hours, days, month, years
    my @factor =
      ( 1, 60, 60, 24, 30.4166, 12 );    # sec, min, hours, days, month, years
    my @singular = ( 'second',  'minute',  'hour',  'day',  'month', 'year' );
    my @plural   = ( 'seconds', 'minutes', 'hours', 'days', 'month', 'years' );
    my $min      = 0;
    my $max      = $prec;

    if ( $scale =~ /^min/i ) {
        $min = 1;
        $unit[1] = $time;
    }
    elsif ( $scale =~ /^hou/i ) {
        $min = 2;
        $unit[2] = $time;
    }
    elsif ( $scale =~ /^day/i ) {
        $min = 3;
        $unit[3] = $time;
    }
    elsif ( $scale =~ /^mon/i ) {
        $min = 4;
        $unit[4] = $time;
    }
    elsif ( $scale =~ /^yea/i ) {
        $min = 5;
        $unit[5] = $time;
    }
    else {
        $unit[0] = $time;
    }
    my @arr  = ();
    my $i    = 0;
    my $val1 = 0;
    my $val2 = 0;
    for ( $i = $min ; $i < 5 ; $i++ ) {
        $val1 = $unit[$i];
        $val2 = $unit[ $i + 1 ] = int( $val1 / $factor[ $i + 1 ] );
        $val1 = $unit[$i] = $val1 - int( $val2 * $factor[ $i + 1 ] );

        push( @arr, "$val1 $singular[$i]" ) if ( $val1 == 1 );
        push( @arr, "$val1 $plural[$i]" )   if ( $val1 > 1 );
    }
    push( @arr, "$val2 $singular[$i]" ) if ( $val2 == 1 );
    push( @arr, "$val2 $plural[$i]" )   if ( $val2 > 1 );
    push( @arr, "0 $plural[$min]" ) unless (@arr);
    my @reverse = reverse(@arr);
    $#reverse = $prec if ( @reverse > $prec );
    my $result = join( ', ', @reverse );
    $result =~ s/(.+)\, /$1 and /;
    return $result;
}

# =========================
sub _SUMDAYS {

    # Also implements DURATION
    # DURATION is undocumented, is for SvenDowideit
    # contributed by SvenDowideit - 07 Mar 2003; modified by PTh
    my $result = 0;
    my @arr    = _getListAsDays( $_[0] );
    foreach my $i (@arr) {
        $result += $i if defined $i;
    }
    return $result;
}

# =========================
sub _TIME {
    my $result = $_[0];
    $result =~ s/^\s+//;
    $result =~ s/\s+$//;
    if ($result) {
        $result = _date2serial($result);
    }
    else {
        $result = time();
    }
    return $result;
}

# =========================
sub _TIMEADD {

    my ( $time, $value, $scale ) = split( /,\s*/, $_[0], 3 );
    $time  = 0  unless ($time);
    $value = 0  unless ($value);
    $scale = "" unless ($scale);
    $time  =~ s/.*?(-?[0-9]+).*/$1/   || 0;
    $value =~ s/.*?(-?[0-9\.]+).*/$1/ || 0;
    $value *= 60            if ( $scale =~ /^min/i );
    $value *= 3600          if ( $scale =~ /^hou/i );
    $value *= 3600 * 24     if ( $scale =~ /^day/i );
    $value *= 3600 * 24 * 7 if ( $scale =~ /^week/i );
    $value *= 3600 * 24 * 30.42
      if ( $scale =~ /^mon/i );    # FIXME: exact calc
    $value *= 3600 * 24 * 365 if ( $scale =~ /^year/i );    # FIXME: exact calc
    return int( $time + $value );

}

# =========================
sub _TIMEDIFF {

    my ( $time1, $time2, $scale ) = split( /,\s*/, $_[0], 3 );
    $scale ||= '';
    $time1 = 0 unless ($time1);
    $time2 = 0 unless ($time2);
    $time1 =~ s/[^-0-9]*?(-?[0-9]+).*/$1/ || 0;
    $time2 =~ s/[^-0-9]*?(-?[0-9]+).*/$1/ || 0;
    my $result = $time2 - $time1;
    $result /= 60            if ( $scale =~ /^min/i );
    $result /= 3600          if ( $scale =~ /^hou/i );
    $result /= 3600 * 24     if ( $scale =~ /^day/i );
    $result /= 3600 * 24 * 7 if ( $scale =~ /^week/i );
    $result /= 3600 * 24 * 30.42
      if ( $scale =~ /^mon/i );    # FIXME: exact calc
    $result /= 3600 * 24 * 365
      if ( $scale =~ /^year/i );    # FIXME: exact calc
    return $result;
}

###########################
# String Functions
###########################

# =========================
sub _CHAR {
    my $i = 0;
    if ( $_[0] =~ /([0-9]+)/ ) {
        $i = $1;
    }
    $i = 255 if $i > 255;
    $i = 0   if $i < 0;
    return chr($i);
}

# =========================
sub _COUNTSTR {
    my $result = 0;       # count any string
    my $i      = 0;       # count string equal second attr
    my $list   = $_[0];
    my $str    = "";
    if ( $_[0] =~ /^(.*),\s*(.*?)$/ ) {    # greedy match for last comma
        $list = $1;
        $str  = $2;
    }
    $str =~ s/\s*$//;
    my @arr = _getList($list);
    foreach my $cell (@arr) {
        if ( defined $cell ) {
            $cell =~ s/^\s*(.*?)\s*$/$1/;
            $result++ if ($cell);
            $i++ if ( $cell eq $str );
        }
    }
    $result = $i if ($str);
    return $result;
}

# ========================
sub _EXACT {
    my ( $str1, $str2 ) = split( /,\s*/, $_[0], 2 );
    $str1 = "" unless ($str1);
    $str2 = "" unless ($str2);
    $str1 =~ s/^\s*(.*?)\s*$/$1/;    # cut leading and trailing spaces
    $str2 =~ s/^\s*(.*?)\s*$/$1/;
    return ( $str1 eq $str2 ) ? 1 : 0;
}

# =========================
sub _FILTER {
    my $result = '';
    my ( $filter, $string ) = split( /,\s*/, $_[0], 2 );
    if ( defined $string ) {
        $filter =~ s/\$comma/,/g;
        $filter =~ s/\$sp/ /g;
        eval '$string =~ s/$filter//go';
        $result = $string;
    }
    return $result;
}

# ========================
sub _FIND {
    return _SEARCH( $_[0], 'FIND' );
}

# ========================
sub _SEARCH {
    my ( $searchString, $string, $pos ) = split( /,\s*/, $_[0], 3 );
    $string       = '' unless ( defined $string );
    $searchString = '' unless ( defined $searchString );
    my $result = 0;
    $pos--;
    $pos = 0 if ( $pos < 0 );
    $searchString = quotemeta($searchString) if ( $_[1] );
    pos($string) = $pos if ($pos);

    # using zero width lookahead '(?=...)' to keep pos at the beginning of match
    if ( $searchString ne '' && eval '$string =~ m/(?=$searchString)/g' ) {
        $result = pos($string) + 1;
    }
    return $result;
}

# ========================
sub _REPLACE {
    my ( $string, $start, $num, $replace ) = split( /,\s*/, $_[0], 4 );
    $string = "" unless ( defined $string );
    my $result = $string;
    $start ||= 0;
    $start-- unless ( $start < 1 );
    $num     = 0  unless ($num);
    $replace = "" unless ( defined $replace );
    $replace =~ s/\$comma/,/g;
    $replace =~ s/\$sp/ /g;
    eval 'substr( $string, $start, $num, $replace )';
    $result = $string;
    return $result;
}

# ========================
sub _SUBSTITUTE {
    my ( $string, $from, $to, $inst, $options ) = split( /,\s*/, $_[0] );
    $string = "" unless ( defined $string );
    my $result = $string;
    $from = "" unless ( defined $from );
    $from =~ s/\$comma/,/g;
    $from =~ s/\$sp/ /g;
    $from = quotemeta($from) unless ( $options && $options =~ /r/i );
    $to = "" unless ( defined $to );
    $to =~ s/\$comma/,/g;
    $to =~ s/\$sp/ /g;

    # Note that the number 0 is valid string. An empty string as well as 0
    # are valid return values
    if ( $string ne "" && $from ne "" ) {
        if ($inst) {

            # replace Nth instance
            my $count = 0;
            if (
                eval
'$string =~ s/($from)/if( ++$count == $inst ) { $to; } else { $1; }/gex;'
              )
            {
                $result = $string;
            }
        }
        else {

            # global replace
            if ( eval '$string =~ s/$from/$to/g' ) {
                $result = $string;
            }
        }
    }
    return $result;

}

# ========================
sub _LEFTSTRING {
    my ( $string, $num ) = split( /,\s*/, $_[0], 2 );
    my $result = '';
    $string = "" unless ( defined $string );
    $num = 1 if ( !defined $num );
    eval '$result = substr( $string, 0, $num )';
    return $result;
}

# ========================
sub _RIGHTSTRING {
    my ( $string, $num ) = split( /,\s*/, $_[0], 2 );
    my $result = '';
    $string = "" unless ( defined $string );
    $num = 1 if ( !defined $num );
    $num = 0 if ( $num < 0 );
    my $start = length($string) - $num;
    $start = 0 if $start < 0;
    eval '$result = substr( $string, $start, $num )';
    return $result;
}

# ========================
sub _INSERTSTRING {
    my ( $string, $start, $new ) = split( /,\s*/, $_[0], 3 );
    $string = "" unless ( defined $string );
    $start = _getNumber($start);
    eval 'substr( $string, $start, 0, $new )';
    return $string;

}

# ========================
sub _TRANSLATE {
    my $result = $_[0];

# greedy match for comma separated parameters (in case first parameter has embedded commas)
    if ( $_[0] =~ /^(.*)\,\s*(.+)\,\s*(.+)$/ ) {
        my $string = $1;
        my $from   = $2;
        my $to     = $3;
        $from =~ s/\$comma/,/g;
        $from =~ s/\$sp/ /g;
        $from = quotemeta($from);
        $to =~ s/\$comma/,/g;
        $to =~ s/\$sp/ /g;
        $to = quotemeta($to);
        $from =~ s/([a-zA-Z0-9])\\\-([a-zA-Z0-9])/$1\-$2/g
          ;    # fix quotemeta (allow only ranges)
        $to =~ s/([a-zA-Z0-9])\\\-([a-zA-Z0-9])/$1\-$2/g;
        $result = $string;

        if ( $string && eval "\$string =~ tr/$from/$to/" ) {
            $result = $string;
        }
    }
    return $result;
}

# =========================
sub _REPEAT {
    my ( $str, $num ) = split( /,\s*/, $_[0], 2 );
    $str = "" unless ( defined($str) );
    $num = _getNumber($num);
    return "$str" x $num;
}

# ========================
sub _SPLIT {
    my ( $sep, $str ) = _properSplit( $_[0], 2 );

    # Not documented - if called without 2 parameters,  assume space delimiter
    if ( !defined $str || $str eq '' ) {
        $str = $_[0];
        $sep = '$sp$sp*';
    }

    $str =~ s/^\s+//;
    $str =~ s/\s+$//;

    $sep = '$sp$sp*' if ( $sep eq '' );
    $sep =~ s/\$sp/\\s/g;

   #SMELL:  Optimizing this next regex breaks reuse for some reason, perl 5.12.3
    $sep =~ s/\$(nop|empty)//g;
    $sep =~ s/\$comma/,/g;

    return _listToDelimitedString( split( /$sep/, $str ) );
}

# =========================
sub _SUBSTRING {
    my $result = '';

# greedy match for comma separated parameters (in case first parameter has embedded commas)
    if ( $_[0] =~ /^(.*)\,\s*(.+)\,\s*(.+)$/ ) {
        my ( $string, $start, $num ) = ( $1, $2, $3 );
        if ( $start && $num ) {
            $start-- unless ( $start < 1 );
            eval '$result = substr( $string, $start, $num )';
        }
    }
    return $result;
}

######################
#  Utility Functions
#####################

# =========================
sub _listToDelimitedString {
    my @arr = map { s/^\s*//; s/\s*$//; $_ } @_;
    my $text = join( ", ", @arr );
    return $text;
}

# =========================
sub _properSplit {
    my ( $theAttr, $theLevel ) = @_;

    # escape commas inside functions
    $theAttr =~
      s/(\$[A-Z]+$escToken([0-9]+)\(.*?$escToken\2\))/_escapeCommas($1)/geo;

    # split at commas and restore commas inside functions
    my @arr =
      map { s/<$escToken>/\,/go; $_ } split( /,\s*/, $theAttr, $theLevel );
    return @arr;
}

# =========================
sub _escapeCommas {
    my ($theText) = @_;
    $theText =~ s/\,/<$escToken>/g;
    return $theText;
}

# =========================
sub _getNumber {
    my ($theText) = @_;
    return 0 unless ($theText);
    $theText =~ s/([0-9])\,(?=[0-9]{3})/$1/g;    # "1,234,567" ==> "1234567"
    if ( $theText =~ /[0-9]e/i ) {               # "1.5e-3"    ==> "0.0015"
        $theText = sprintf "%.20f", $theText;
        $theText =~ s/0+$//;
    }
    unless ( $theText =~ s/^.*?(\-?[0-9\.]+).*$/$1/ )
    {                                            # "xy-1.23zz" ==> "-1.23"
        $theText = 0;
    }
    $theText =~ s/^(\-?)0+([0-9])/$1$2/;         # "-0009.12"  ==> "-9.12"
    $theText =~ s/^(\-?)\./${1}0\./;             # "-.25"      ==> "-0.25"
    $theText =~ s/^\-0$/0/;                      # "-0"        ==> "0"
    $theText =~ s/\.$//;                         # "123."      ==> "123"
    return $theText;
}

# =========================
sub _safeEvalPerl {
    my ($theText) = @_;
    $theText = '' unless defined $theText;

    # Allow only simple math with operators - + * / % ( )
    $theText =~ s/\%\s*[^\-\+\*\/0-9\.\(\)]+//g; # defuse %hash but keep modulus
      # keep only numbers and operators (shh... don't tell anyone, we support comparison operators)
    $theText =~ s/[^\!\<\=\>\-\+\*\/\%0-9e\.\(\)]*//g;
    $theText =~ s/(^|[^\.])\b0+(?=[0-9])/$1/g
      ;    # remove leading 0s to defuse interpretation of numbers as octals
    $theText =~
      s/(^|[^0-9])e/$1/g;   # remove "e"-s unless in expression such as "123e-4"
    $theText =~ /(.*)/;
    $theText = $1;          # untainted variable
    return "" unless ($theText);
    local $SIG{__DIE__} =
      sub { Foswiki::Func::writeDebug( $_[0] ); warn $_[0] };
    my $result = eval $theText;

    if ($@) {
        $result = $@;
        $result =~ s/[\n\r]//g;
        $result =~
          s/\[[^\]]+.*view.*?\:\s?//;  # Cut "[Mon Mar 15 23:31:39 2004] view: "
        $result =~ s/\s?at \(eval.*?\)\sline\s?[0-9]*\.?\s?//g
          ;                            # Cut "at (eval 51) line 2."
        $result = "ERROR: $result";

    }
    else {
        $result = 0 unless ($result);    # logical false is "0"
    }
    return $result;
}

# =========================
sub _getListAsInteger {
    my ($theAttr) = @_;

    my $val  = 0;
    my @list = _getList($theAttr);
    ( my $baz = "foo" ) =~ s/foo//;      # reset search vars. defensive coding
    for my $i ( 0 .. $#list ) {
        $val = $list[$i];

        # search first integer pattern, skip over HTML tags
        if ( $val =~ /^\s*(?:<[^>]*>)*([\-\+]*[0-9]+).*/ ) {
            $list[$i] = $1;              # untainted variable, possibly undef
        }
        else {
            $list[$i] = undef;
        }
    }
    return @list;
}

# =========================
sub _getListAsFloat {
    my ($theAttr) = @_;

    my $val  = 0;
    my @list = _getList($theAttr);
    ( my $baz = "foo" ) =~ s/foo//;    # reset search vars. defensive coding
    for my $i ( 0 .. $#list ) {
        $val = $list[$i];
        $val = "" unless defined $val;

        # search first float pattern, skip over HTML tags
        if ( $val =~ /^\s*(?:<[^>]*>)*\$?([\-\+]*[0-9\.]+).*/ ) {
            $list[$i] = $1;            # untainted variable, possibly undef
        }
        else {
            $list[$i] = undef;
        }
    }
    return @list;
}

# =========================
sub _getListAsDays {
    my ($theAttr) = @_;

    # contributed by by SvenDowideit - 07 Mar 2003; modified by PTh
    my $val = 0;
    my @arr = _getList($theAttr);
    ( my $baz = "foo" ) =~ s/foo//;    # reset search vars. defensive coding
    for my $i ( 0 .. $#arr ) {
        $val = $arr[$i] || "";

        # search first float pattern
        if ( $val =~ /^\s*([\-\+]*[0-9\.]+)\s*d/i ) {
            $arr[$i] = $1;             # untainted variable, possibly undef
        }
        elsif ( $val =~ /^\s*([\-\+]*[0-9\.]+)\s*w/i ) {
            $arr[$i] = 5 * $1;         # untainted variable, possibly undef
        }
        elsif ( $val =~ /^\s*([\-\+]*[0-9\.]+)\s*h/i ) {
            $arr[$i] = $1 / 8;         # untainted variable, possibly undef
        }
        elsif ( $val =~ /^\s*([\-\+]*[0-9\.]+)/ ) {
            $arr[$i] = $1;             # untainted variable, possibly undef
        }
        else {
            $arr[$i] = undef;
        }
    }
    return @arr;
}

# =========================
sub _getList {
    my ($theAttr) = @_;

    my @list = ();
    return @list unless $theAttr;
    $theAttr =~ s/^\s*//;    # Drop leading / trailing spaces
    $theAttr =~ s/\s*$//;
    foreach ( split( /\s*,\s*/, $theAttr ) ) {
        if (m/\s*R([0-9]+)\:C([0-9]+)\s*\.\.+\s*R([0-9]+)\:C([0-9]+)/) {
            foreach ( _getTableRange($_) ) {

                # table range - appears to contain a list
                if ( $_ =~ m/,/ ) {
                    push( @list, ( split( /\s*,\s*/, $_ ) ) );
                }
                else {
                    push( @list, $_ );
                }
            }
        }
        else {

            # list item
            push( @list, $_ );
        }
    }
    return @list;
}

# =========================
sub _getTableRange {
    my ($theAttr) = @_;

    my @arr = ();
    if ( $rPos < 0 ) {
        return @arr;
    }

    Foswiki::Func::writeDebug(
        "- SpreadSheetPlugin::Calc::_getTableRange( $theAttr )")
      if $debug;
    unless (
        $theAttr =~ /\s*R([0-9]+)\:C([0-9]+)\s*\.\.+\s*R([0-9]+)\:C([0-9]+)/ )
    {
        return @arr;
    }
    my $r1 = $1 - 1;
    my $c1 = $2 - 1;
    my $r2 = $3 - 1;
    my $c2 = $4 - 1;
    my $r  = 0;
    my $c  = 0;
    if ( $c1 < 0 ) { $c1 = 0; }
    if ( $c2 < 0 ) { $c2 = 0; }
    if ( $c2 < $c1 ) { $c = $c1; $c1 = $c2; $c2 = $c; }
    if ( $r1 > $rPos ) { $r1 = $rPos; }
    if ( $r1 < 0 )     { $r1 = 0; }
    if ( $r2 > $rPos ) { $r2 = $rPos; }
    if ( $r2 < 0 )     { $r2 = 0; }
    if ( $r2 < $r1 ) { $r = $r1; $r1 = $r2; $r2 = $r; }

    my $pRow = ();
    for my $r ( $r1 .. $r2 ) {
        $pRow = $tableMatrix[$r];
        for my $c ( $c1 .. $c2 ) {
            if ( $c < @$pRow ) {

                # Strip trailing spaces from each cell.
                # The are for left/right justification and should
                # not be considered part of the table data.
                my ($rd) = $$pRow[$c] =~ m/^\s*(.*?)\s*$/;
                push( @arr, $rd );
            }
        }
    }
    Foswiki::Func::writeDebug(
        "- SpreadSheetPlugin::Calc::_getTableRange() returns @arr")
      if $debug;
    return @arr;
}

# =========================
sub _date2serial {
    my ($theText) = @_;

    my $sec  = 0;
    my $min  = 0;
    my $hour = 0;
    my $day  = 1;
    my $mon  = 0;
    my $year = 0;

    # Handle DOY (Day of Year)
    if ( $theText =~
m|([Dd][Oo][Yy])\s*([0-9]{4})[\.]([0-9]{1,3})[\.]([0-9]{1,2})[\.]([0-9]{1,2})[\.]([0-9]{1,2})|
      )
    {

        # "DOY2003.122.23.15.59", "DOY2003.2.9.3.5.9" i.e. year.ddd.hh.mm.ss
        $year = $2;
        $day  = $3;
        $hour = $4;
        $min  = $5;
        $sec  = $6;    # Note: $day is in fact doy
    }
    elsif ( $theText =~
m|([Dd][Oo][Yy])\s*([0-9]{4})[\.]([0-9]{1,3})[\.]([0-9]{1,2})[\.]([0-9]{1,2})|
      )
    {

        # "DOY2003.122.23.15", "DOY2003.2.9.3" i.e. year.ddd.hh.mm
        $year = $2;
        $day  = $3;
        $hour = $4;
        $min  = $5;
    }
    elsif ( $theText =~
        m|([Dd][Oo][Yy])\s*([0-9]{4})[\.]([0-9]{1,3})[\.]([0-9]{1,2})| )
    {

        # "DOY2003.122.23", "DOY2003.2.9" i.e. year.ddd.hh
        $year = $2;
        $day  = $3;
        $hour = $4;
    }
    elsif ( $theText =~ m|([Dd][Oo][Yy])\s*([0-9]{4})[\.]([0-9]{1,3})| ) {

        # "DOY2003.122", "DOY2003.2" i.e. year.ddd
        $year = $2;
        $day  = $3;
    }
    elsif ( $theText =~
m|([0-9]{1,2})[-\s/]+([A-Z][a-z][a-z])[-\s/]+([0-9]{4})[-\s/]+([0-9]{1,2}):([0-9]{1,2}):([0-9]{1,2})|
      )
    {

# "31 Dec 2003 - 23:59:59", "31-Dec-2003 - 23:59:59", "31 Dec 2003 - 23:59:59 - any suffix"
        $day  = $1;
        $mon  = $mon2num{$2} || 0;
        $year = $3;
        $hour = $4;
        $min  = $5;
        $sec  = $6;
    }
    elsif ( $theText =~
m|([0-9]{1,2})[-\s/]+([A-Z][a-z][a-z])[-\s/]+([0-9]{4})[-\s/]+([0-9]{1,2}):([0-9]{1,2})|
      )
    {

# "31 Dec 2003 - 23:59", "31-Dec-2003 - 23:59", "31 Dec 2003 - 23:59 - any suffix"
        $day  = $1;
        $mon  = $mon2num{$2} || 0;
        $year = $3;
        $hour = $4;
        $min  = $5;
    }
    elsif (
        $theText =~ m|([0-9]{1,2})[-\s/]+([A-Z][a-z][a-z])[-\s/]+([0-9]{2,4})| )
    {

        # "31 Dec 2003", "31 Dec 03", "31-Dec-2003", "31/Dec/2003"
        $day  = $1;
        $mon  = $mon2num{$2} || 0;
        $year = $3;
        $year += 2000 if ( $year < 80 );
        $year += 1900 if ( $year < 100 and $year >= 80 );
    }
    elsif ( $theText =~
m|([0-9]{4})[-/\.]([0-9]{1,2})[-/\.]([0-9]{1,2})[-/\.\,\s]+([0-9]{1,2})[-\:/\.]([0-9]{1,2})[-\:/\.]([0-9]{1,2})|
      )
    {

        # "2003/12/31 23:59:59", "2003-12-31-23-59-59", "2003.12.31.23.59.59"
        $year = $1;
        $mon  = $2 - 1;
        $day  = $3;
        $hour = $4;
        $min  = $5;
        $sec  = $6;
    }
    elsif ( $theText =~
m|([0-9]{4})[-/\.]([0-9]{1,2})[-/\.]([0-9]{1,2})[-/\.\,\s]+([0-9]{1,2})[-\:/\.]([0-9]{1,2})|
      )
    {

        # "2003/12/31 23:59", "2003-12-31-23-59", "2003.12.31.23.59"
        $year = $1;
        $mon  = $2 - 1;
        $day  = $3;
        $hour = $4;
        $min  = $5;
    }
    elsif ( $theText =~ m|([0-9]{4})[-/]([0-9]{1,2})[-/]([0-9]{1,2})| ) {

        # "2003/12/31", "2003-12-31"
        $year = $1;
        $mon  = $2 - 1;
        $day  = $3;
    }
    elsif ( $theText =~ m|([0-9]{1,2})[-/]([0-9]{1,2})[-/]([0-9]{2,4})| ) {

# "12/31/2003", "12/31/03", "12-31-2003"
# (shh, don't tell anyone that we support ambiguous American dates, my boss asked me to)
        $year = $3;
        $mon  = $1 - 1;
        $day  = $2;
        $year += 2000 if ( $year < 80 );
        $year += 1900 if ( $year < 100 and $year >= 80 );
    }
    else {

        # unsupported format
        return 0;
    }
    if (   ( $sec > 60 )
        || ( $min > 59 )
        || ( $hour > 23 )
        || ( $day < 1 )
        || ( $day > 365 )
        || ( $mon > 11 ) )
    {

        # unsupported, out of range
        return 0;
    }

    # Flag to force the TIME function to convert entered dates to GMT.
    # This will normally cause trouble for users on a server installed
    # the east of Greenwich because dates entered without a time get
    # converted to the day before and this is usually not what the user
    # intended. Especially the function WORKINGDAYS suffer from this.
    # and it also causes surprises with respect to daylight saving time

    my $timeislocal =
      Foswiki::Func::getPreferencesFlag("SPREADSHEETPLUGIN_TIMEISLOCAL") || 0;
    $timeislocal = Foswiki::Func::isTrue($timeislocal);

    $timeislocal = 0 if ( $theText =~ /GMT/i );    #If explicitly GMT, ignore

# To handle DOY, use timegm_nocheck or timelocal_nocheck that won't check input data range.
# This is necessary because with DOY, $day must be able to be greater than 31 and timegm
# and timelocal won't allow it. Keep using timegm or timelocal for non-DOY stuff.

    if ( ( $theText =~ /local/i ) || ($timeislocal) ) {
        if ( $theText =~ /DOY/i ) {
            return timelocal_nocheck( $sec, $min, $hour, $day, $mon, $year );
        }
        else {
            return timelocal( $sec, $min, $hour, $day, $mon, $year );
        }
    }
    else {
        if ( $theText =~ /DOY/i ) {
            return timegm_nocheck( $sec, $min, $hour, $day, $mon, $year );
        }
        else {
            return timegm( $sec, $min, $hour, $day, $mon, $year );
        }
    }
}

# =========================
sub _serial2date {
    my ( $theTime, $theStr, $isGmt ) = @_;

    my ( $sec, $min, $hour, $day, $mon, $year, $wday, $yday ) =
      ( $isGmt ? gmtime($theTime) : localtime($theTime) );

    $theStr =~
s/\$isoweek\(([^\)]*)\)/_isoWeek( $1, $day, $mon, $year, $wday, $theTime )/gei;
    $theStr =~
      s/\$isoweek/_isoWeek( '$week', $day, $mon, $year, $wday, $theTime )/gei;
    $theStr =~ s/\$sec[o]?[n]?[d]?[s]?/sprintf("%.2u",$sec)/gei;
    $theStr =~ s/\$min[u]?[t]?[e]?[s]?/sprintf("%.2u",$min)/gei;
    $theStr =~ s/\$hou[r]?[s]?/sprintf("%.2u",$hour)/gei;
    $theStr =~ s/\$day/sprintf("%.2u",$day)/gei;
    $theStr =~ s/\$mon(?!t)/$monArr[$mon]/gi;
    $theStr =~ s/\$mo[n]?[t]?[h]?/sprintf("%.2u",$mon+1)/gei;
    $theStr =~ s/\$yearday/$yday+1/gei;
    $theStr =~ s/\$yea[r]?/sprintf("%.4u",$year+1900)/gei;
    $theStr =~ s/\$ye/sprintf("%.2u",$year%100)/gei;
    $theStr =~ s/\$wday/substr($wdayArr[$wday],0,3)/gei;
    $theStr =~ s/\$wd/$wday+1/gei;
    $theStr =~ s/\$weekday/$wdayArr[$wday]/gi;

    return $theStr;
}

# =========================
sub _isoWeek {
    my ( $format, $day, $mon, $year, $wday, $serial ) = @_;

    # Contributed by PeterPayne - 22 Oct 2007
    # Enhanced by PeterThoeny 2010-08-27
    # Calculate the ISO8601 week number from the serial.

    my $isoyear = $year + 1900;
    my $yearserial = _year2isoweek1serial( $year + 1900, 1 );
    if ( $mon >= 11 ) {    # check if date is in next year's first week
        my $yearnextserial = _year2isoweek1serial( $year + 1900 + 1, 1 );
        if ( $serial >= $yearnextserial ) {
            $yearserial = $yearnextserial;
            $isoyear += 1;
        }
    }
    elsif ( $serial < $yearserial ) {
        $yearserial = _year2isoweek1serial( $year + 1900 - 1, 1 );
        $isoyear -= 1;
    }

    # calculate GMT of just past midnight today
    my $today_gmt = timegm( 0, 0, 0, $day, $mon, $year );
    my $isoweek = int( ( $today_gmt - $yearserial ) / ( 7 * 24 * 3600 ) ) + 1;
    my $isowk = sprintf( "%.2u", $isoweek );
    my $isoday = $wday;
    $isoday = 7 unless ($isoday);

    $format =~ s/\$iso/$isoyear-W$isoweek/g;
    $format =~ s/\$year/$isoyear/g;
    $format =~ s/\$week/$isoweek/g;
    $format =~ s/\$wk/$isowk/g;
    $format =~ s/\$day/$isoday/g;

    return $format;
}

# =========================
sub _year2isoweek1serial {
    my ( $year, $isGmt ) = @_;

    # Contributed by PeterPayne - 22 Oct 2007
    # Calculate the serial of the beginning of week 1 for specified year.
    # Year is 4 digit year (e.g. "2000")

    $year -= 1900;

    # get Jan 4
    my @param = ( 0, 0, 0, 4, 0, $year );
    my $jan4epoch = ( $isGmt ? timegm(@param) : timelocal(@param) );

    # what day does Jan 4 fall on?
    my $jan4day =
      ( $isGmt ? ( gmtime($jan4epoch) )[6] : ( localtime($jan4epoch) )[6] );

    $jan4day += 7 if ( $jan4day < 1 );

    return ( $jan4epoch - ( 24 * 3600 * ( $jan4day - 1 ) ) );
}

# =========================
sub _properSpace {
    my ($theStr) = @_;

    # FIXME: I18N

    unless ($dontSpaceRE) {
        $dontSpaceRE =
             &Foswiki::Func::getPreferencesValue("DONTSPACE")
          || &Foswiki::Func::getPreferencesValue("SPREADSHEETPLUGIN_DONTSPACE")
          || "CodeWarrior, MacDonald, McIntosh, RedHat, SuSE";
        $dontSpaceRE =~ s/[^a-zA-Z0-9\,\s]//g;
        $dontSpaceRE =
          "(" . join( "|", split( /[\,\s]+/, $dontSpaceRE ) ) . ")";

        # Example: "(RedHat|McIntosh)"
    }
    $theStr =~ s/$dontSpaceRE/_spaceWikiWord( $1, "<DONT_SPACE>" )/geo
      ;    # e.g. "Mc<DONT_SPACE>Intosh"
    $theStr =~
      s/(^|[\s\(]|\]\[)([a-zA-Z0-9]+)/$1 . _spaceWikiWord( $2, " " )/ge;
    $theStr =~ s/<DONT_SPACE>//g;    # remove "<DONT_SPACE>" marker

    return $theStr;
}

# =========================
sub _spaceWikiWord {
    my ( $theStr, $theSpacer ) = @_;

    $theStr =~ s/([a-z])([A-Z0-9])/$1$theSpacer$2/g;
    $theStr =~ s/([0-9])([a-zA-Z])/$1$theSpacer$2/g;

    return $theStr;
}

# =========================
sub _workingDays {
    my ( $start, $end ) = @_;

# Rewritten by PeterThoeny - 2009-05-03 (previous implementation was buggy)
# Calculate working days between two times. Times are standard system times (secs since 1970).
# Working days are Monday through Friday (sorry, Israel!)
# A day has 60 * 60 * 24 sec
# Adding 3601 sec to account for daylight saving change in March in Northern Hemisphere
    my $days                = int( ( abs( $end - $start ) + 3601 ) / 86400 );
    my $weeks               = int( $days / 7 );
    my $fullWeekWorkingDays = 5 * $weeks;
    my $extra               = $days % 7;
    if ( $extra > 0 ) {
        $start = $end if ( $start > $end );
        my @tm   = gmtime($start);
        my $wday = $tm[6];           # 0 is Sun, 6 is Sat
        if ( $wday == 0 ) {
            $extra--;
        }
        else {
            my $sum = $wday + $extra;
            $extra-- if ( $sum > 6 );
            $extra-- if ( $sum > 7 );
        }
    }
    return $fullWeekWorkingDays + $extra;
}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2015 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

&copy; 2001-2015 Peter Thoeny, [[http://twiki.org/][TWiki.org]]
&copy; 2008-2015 TWiki:TWiki.TWikiContributor
&copy; 2015 Wave Systems Corp.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
