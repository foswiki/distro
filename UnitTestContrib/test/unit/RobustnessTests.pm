# Copyright (C) 2004 Florian Weimer
package RobustnessTests;
require 5.008;
use strict;
use warnings;
use utf8;    # For test_sanitizeAttachmentNama_unicode

use FoswikiTestCase();
our @ISA = qw( FoswikiTestCase );

use Foswiki();
use Foswiki::Sandbox();
use Foswiki::Time();
use Error qw( :try );

my $slash = ( $^O eq 'MSWin32' ) ? '\\' : '/';

sub new {
    my ( $class, @args ) = @_;
    my $this = $class->SUPER::new(@args);

    $this->{test_web}   = 'Temporary' . $class . 'TestWeb';
    $this->{test_topic} = 'TestTopic' . $class;

    return $this;
}

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();
    $this->createNewFoswikiSession();
    Foswiki::Sandbox::_assessPipeSupport();

    return;
}

sub tear_down {
    my $this = shift;

    # NOTE: this test pokes globals in the sandbox, so we have to be extra
    # careful about restoring state.
    Foswiki::Sandbox::_assessPipeSupport();
    $this->SUPER::tear_down();

    return;
}

sub test_untaintUnchecked {
    my $this = shift;
    $this->assert_str_equals( '', Foswiki::Sandbox::untaintUnchecked('') );
    $this->assert_not_null( 'abc', Foswiki::Sandbox::untaintUnchecked('abc') );
    $this->assert_null( Foswiki::Sandbox::untaintUnchecked(undef) );

    return;
}

sub test_validateAttachmentName {
    my $this = shift;

    $this->assert_str_equals( "abc",
        Foswiki::Sandbox::validateAttachmentName("abc") );
    $this->assert_str_equals( "abc",
        Foswiki::Sandbox::validateAttachmentName("./abc") );
    $this->assert_str_equals( "abc",
        Foswiki::Sandbox::validateAttachmentName("abc/.") );
    $this->assert_str_equals( "abc",
        Foswiki::Sandbox::validateAttachmentName("/abc") );
    $this->assert_str_equals( "abc",
        Foswiki::Sandbox::validateAttachmentName("//abc") );

    $this->assert_str_equals( "",
        Foswiki::Sandbox::validateAttachmentName("c/..") );

    $this->assert_null( Foswiki::Sandbox::validateAttachmentName("../a") );

    $this->assert_null( Foswiki::Sandbox::validateAttachmentName("/a/../..") );
    $this->assert_str_equals( "a",
        Foswiki::Sandbox::validateAttachmentName("//a/b/c/../..") );
    $this->assert_str_equals( "..a",
        Foswiki::Sandbox::validateAttachmentName("..a/") );
    $this->assert_str_equals( "a/..b",
        Foswiki::Sandbox::validateAttachmentName("a/..b") );

    return;
}

sub _shittify {
    my ( $a, $b ) = Foswiki::Sandbox::sanitizeAttachmentName(shift);
    return $a;
}

=begin TML
 Item11185: This is how things were before we began Operation Unicode:

$regex{filenameInvalidCharRegex} = qr/[^$regex{mixedAlphaNum}\. _-]/o;

 Then devised, using the notes above (and subsequently abandoned for NameFilter):

$regex{filenameInvalidCharRegex} = qr/[-%'";!\+=<>&{\(\)}\x00-\x1f\x7f-\x9f]/o;

 UNICODE: "What's a character?" ... strip control characters. Probably
          don't need to strip layout chars. No attempt w/confusing chars.
          Let's all pretend to be experts:
    * http://www.unicode.org/faq/security.html
    * http://unicode.org/uni2book/ch13.pdf - C0 & C1 control codes
    * http://unicode.org/reports/tr36/ - Unicode Security Considerations
    * http://unicode.org/reports/tr39/ - Unicode Security Mechanismsa
       http://www.unicode.org/reports/tr39/#idmod is an impressive black &
       white-list of character ranges recommended to be restricted from use
       in "identifiers" (in a w3c sense?)
    * http://tools.ietf.org/html/draft-ietf-syslog-protocol-23#section-8.1

 XSS: Filter characters that might be useful for XSS.
    * http://ha.ckers.org/xss.html
    * http://support.microsoft.com/kb/252985
    * http://tldp.org/HOWTO/Secure-Programs-HOWTO/cross-site-malicious-content.html

 SMELL: Commented out parts of tests that assume we're filtering C1 control
 codes 0x7f-0x9f. I'm not sure if this range is used for legit printable chars
 in some weird charset out there
=cut

sub test_sanitizeAttachmentName {
    my $this = shift;

    # Check that leading paths are stripped
    $this->assert_str_equals( "abc", _shittify("abc") );
    $this->assert_str_equals( "abc", _shittify("./abc") );
    $this->assert_str_equals( "abc", _shittify("\\abc") );
    $this->assert_str_equals( "abc", _shittify("//abc") );
    $this->assert_str_equals( "abc", _shittify("\\\\abc") );

    # Check that "certain characters" are munched
    my $crap = '';
    for ( 0 .. 255 ) {
        my $c = chr($_);
        $crap .= $c if $c =~ /$Foswiki::cfg{NameFilter}/;
    }

    #$this->assert_num_equals(80, length($crap));
    $this->assert_num_equals( 51, length($crap) );
    my $x = $crap =~ / / ? '_' : '';
    $this->assert_str_equals( "pick_me${x}pick_me",
        _shittify("pick me${crap}pick me") );
    my %junkset = (
        '<script>'       => 'script',
        '%3cscript%3e'   => '3cscript3e',
        '&lt;script&gt;' => 'ltscriptgt',
        '"foo"'          => 'foo',
        "'foo'"          => 'foo',
        "foo\x00foo"     => 'foofoo',          # C0 Control
        "foo\x10foo"     => 'foofoo',          # C0 Control
        "foo\x1ffoo"     => 'foofoo',          # C0 Control
        "\xe2cret\xe9"   => "\xe2cret\xe9",    # cf. acrete - 'âcreté'
        '片仮名'      => '片仮名',
        'var a = { b : !(1 - 2 + 3) };' => 'var_a_=_{_b_:_!(1_-_2_+_3)_}',

        #'var a = { b : !(1 - 2 + 3) };' => 'var_a___b_:_1__2__3_',
        #"foo\x7ffoo" => 'foofoo', # C1 Control
        #"foo\x8ffoo" => 'foofoo', # C1 Control
        #"foo\x9ffoo" => 'foofoo', # C1 Control
    );
    while ( my ( $junk, $filtered ) = each %junkset ) {
        $this->assert_str_equals( $filtered, _shittify($junk) );
    }

    # Check that the upload filter is applied.
    $Foswiki::cfg{UploadFilter} = qr(^(
             \.htaccess
         | .*\.(?i)(?:php[0-9s]?(\..*)?
         | [sp]htm[l]?(\..*)?
         | pl
         | py
         | cgi ))$)x;
    $this->assert_str_equals( ".htaccess.txt", _shittify(".htaccess") );
    for my $i (qw(php shtm phtml pl py cgi PHP SHTM PHTML PL PY CGI)) {
        my $j = "bog.$i";
        my $y = "$j.txt";
        $this->assert_str_equals( $y, _shittify($j) );
    }
    for my $i (qw(php phtm shtml PHP PHTM SHTML)) {
        my $j = "bog.$i.s";
        my $y = "$j.txt";
        $this->assert_str_equals( $y, _shittify($j) );
    }

    return;
}

# Item11185 - see also: FuncTests::test_unicode_attachment
sub test_sanitizeAttachmentNama_unicode {
    my ($this) = shift;

# The second word in the string below consists only of two _graphemes_
# (logical characters as humans know them) both built from single _base
# characters_ but then decorated w/additional _modifier_ characters to add
# vowel marks and other signs.
#
# vim, scite, and probably other monospace/grid-based editors have problems
# with this and may show all five unicode characters separately.
# It's the word "hindi" in devanagari script. http://translate.google.com/#auto|hi|hindi
#
# - "use utf8;" needs to be at the top of this .pm.
# - Your editor/terminal needs to be editing in utf8.
# - You might also want ttf-devanagari-fonts or ttf-indic-fonts-core
# - First word german 'übermaß' to make the failure mode more easy to follow
    my $uniname = 'übermaß_हिंदी';

    # http://translate.google.com/#auto|hi|standard
    my $unicomment = 'मानक';
    $this->assert( utf8::is_utf8($uniname),
        'Our attachment name string doesn\'t have utf8 flag set' );
    my $query;

    $Foswiki::cfg{Site}{CharSet} = 'utf-8';
    require Unit::Request;
    $query = Unit::Request->new("");
    $query->path_info("/$this->{test_web}/$this->{test_topic}");
    $this->createNewFoswikiSession( undef, $query );
    $this->{request}  = $query;
    $this->{response} = Unit::Response->new();
    ( $this->{test_topicObject} ) =
      Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );
    $this->{test_topicObject}->text("BLEEGLE\n");
    my ($sanitized) = Foswiki::Func::sanitizeAttachmentName($uniname);

    # Fails without Foswikirev:12780
    $this->assert_str_equals( $uniname, $sanitized );

    return;
}

sub test_buildCommandLine {
    my $this = shift;
    $this->assert_deep_equals( [ "a", "b", "c" ],
        [ Foswiki::Sandbox::_buildCommandLine( "a b c", () ) ] );
    $this->assert_deep_equals( [ "a", "b", "c" ],
        [ Foswiki::Sandbox::_buildCommandLine( " a  b  c ", () ) ] );
    $this->assert_deep_equals(
        [ 1, 2, 3 ],
        [
            Foswiki::Sandbox::_buildCommandLine(
                " %A%  %B%  %C% ",
                ( A => 1, B => 2, C => 3 )
            )
        ]
    );
    $this->assert_deep_equals(

#unfortuanatly, buildCommandLine cleans up paths using File::Spec, which thus uses \\ on some win32's (strawberry for eg)
        [ 1, "./-..", "a${slash}b" ],
        [
            Foswiki::Sandbox::_buildCommandLine(
                " %A|U%  %B|F%  %C|F% ",
                ( A => 1, B => "-..", C => "a/b" )
            )
        ]
    );
    $this->assert_deep_equals(
        [ 1, "2:3" ],
        [
            Foswiki::Sandbox::_buildCommandLine(
                " %A%  %B%:%C% ",
                ( A => 1, B => 2, C => 3 )
            )
        ]
    );
    $this->assert_deep_equals(
        [ 1, "-n2:3" ],
        [
            Foswiki::Sandbox::_buildCommandLine(
                " %A%  -n%B%:%C% ",
                ( A => 1, B => 2, C => 3 )
            )
        ]
    );
    $this->assert_deep_equals(
        [ 1, "-r2:HEAD", 3 ],
        [
            Foswiki::Sandbox::_buildCommandLine(
                " %A%  -r%B%:HEAD %C% ",
                ( A => 1, B => 2, C => 3 )
            )
        ]
    );

#unfortuanatly, buildCommandLine cleans up paths using File::Spec, which thus uses \\ on some win32's (strawberry for eg)
    $this->assert_deep_equals(
        [ "a", "b", "${slash}c" ],
        [
            Foswiki::Sandbox::_buildCommandLine(
                " %A|F%  ", ( A => [ "a", "b", "/c" ] )
            )
        ]
    );

    $this->assert_deep_equals(
        [ "1", "2.3", "4", 'str-.+_ing', "-09AZaz.+_" ],
        [
            Foswiki::Sandbox::_buildCommandLine(
                " %A|N% %B|S% %C|S%",
                ( A => [ 1, 2.3, 4 ], B => 'str-.+_ing', C => "-09AZaz.+_" )
            )
        ]
    );

    $this->assert_deep_equals(
        ["2004/11/20 09:57:41"],
        [
            Foswiki::Sandbox::_buildCommandLine(
                "%A|D%",
                A => Foswiki::Time::formatTime( 1100944661, '$rcs', 'gmtime' )
            )
        ]
    );

    my $result;
    $result = eval { Foswiki::Sandbox::_buildCommandLine('%A|%'); 1; };
    $this->assert( !$result );
    $result = eval { Foswiki::Sandbox::_buildCommandLine('%A|X%'); 1; };
    $this->assert( !$result );
    my $caught = 0;
    try { Foswiki::Sandbox::_buildCommandLine( ' %A|N%  ', A => '2/3' ); 1; }
    otherwise {
        $caught += 1;
    };
    $this->assert_num_equals( 1, $caught );

  # SMELL: Item11185 - this was an assert_not_null that implied the following
  # invocation should fail. After re-writing it as suggested by perlcritic/PBP,
  # the invocation actually works fine. PH thinks the old test only accidentally
  # worked before because of Error.pm try/catch propagation-under-test-craziness
    $result = eval {
        Foswiki::Sandbox::_buildCommandLine( ' %A|S%  ', A => '2/3' );
        1;
    };
    $this->assert($result);

    return;
}

sub verify {
    my $this = shift;
    my ( $out, $exit ) =
      Foswiki::Sandbox->sysCommand( 'sh -c %A%', A => 'echo OK; echo BOSS' );
    $this->assert_str_equals( "OK\nBOSS\n", $out );
    $this->assert_equals( 0, $exit );
    ( $out, $exit ) =
      Foswiki::Sandbox->sysCommand( 'sh -c %A%',
        A => 'echo JUNK ON STDERR 1>&2' );
    $this->assert_equals( 0, $exit );
    $this->assert_str_equals( "", $out );
    ( $out, $exit ) = Foswiki::Sandbox->sysCommand(
        'test %A% %B% %C%',
        A => '1',
        B => '-eq',
        C => '2'
    );
    $this->assert_equals( 1, $exit, $exit . ' ' . $out );
    $this->assert_str_equals( "", $out );
    ( $out, $exit ) =
      Foswiki::Sandbox->sysCommand( 'sh -c %A%', A => 'echo urmf; exit 7' );
    $this->assert( $exit != 0 );
    $this->assert_str_equals( "urmf\n", $out );
    ( $out, $exit ) = Foswiki::Sandbox->sysCommand('echo');
    $this->assert_equals( 0, $exit );
    $this->assert_str_equals( `echo`, $out );

    return;
}

sub test_executeRSP {
    my $this = shift;
    return if ( $^O eq 'MSWin32' );
    $Foswiki::Sandbox::REAL_SAFE_PIPE_OPEN     = 1;
    $Foswiki::Sandbox::EMULATED_SAFE_PIPE_OPEN = 0;
    $this->verify();

    return;
}

sub test_executeESP {
    my $this = shift;
    return if ( $^O eq 'MSWin32' );
    $Foswiki::Sandbox::REAL_SAFE_PIPE_OPEN     = 0;
    $Foswiki::Sandbox::EMULATED_SAFE_PIPE_OPEN = 1;
    $this->verify();

    return;
}

sub test_executeNSP {
    my $this = shift;
    return if ( $^O eq 'MSWin32' );
    $Foswiki::Sandbox::REAL_SAFE_PIPE_OPEN     = 0;
    $Foswiki::Sandbox::EMULATED_SAFE_PIPE_OPEN = 0;
    $this->verify();

    return;
}

1;
