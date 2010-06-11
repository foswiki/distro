# Copyright (C) 2004 Florian Weimer
package RobustnessTests;

use FoswikiTestCase;
our @ISA = qw( FoswikiTestCase );
require 5.008;

use Foswiki;
use Foswiki::Sandbox;
use Foswiki::Time;
use Error qw( :try );

my $slash;

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();
    $this->{session} = new Foswiki();
    $slash = ( $Foswiki::cfg{OS} eq 'WINDOWS' ) ? '\\' : '/';
    Foswiki::Sandbox::_assessPipeSupport();
}

sub tear_down {
    my $this = shift;

    # NOTE: this test pokes globals in the sandbox, so we have to be extra
    # careful about restoring state.
    Foswiki::Sandbox::_assessPipeSupport();
    $this->{session}->finish();
    $this->SUPER::tear_down();
}

sub test_untaintUnchecked {
    my $this = shift;
    $this->assert_str_equals( '', Foswiki::Sandbox::untaintUnchecked('') );
    $this->assert_not_null( 'abc', Foswiki::Sandbox::untaintUnchecked('abc') );
    $this->assert_null( Foswiki::Sandbox::untaintUnchecked(undef) );
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

    $this->assert_str_equals(
        "", Foswiki::Sandbox::validateAttachmentName("c/.."));

    $this->assert_null(Foswiki::Sandbox::validateAttachmentName("../a"));

    $this->assert_null(Foswiki::Sandbox::validateAttachmentName("/a/../.."));
    $this->assert_str_equals(
        "a", Foswiki::Sandbox::validateAttachmentName("//a/b/c/../..") );
    $this->assert_str_equals( "..a",
        Foswiki::Sandbox::validateAttachmentName("..a/") );
    $this->assert_str_equals( "a/..b",
        Foswiki::Sandbox::validateAttachmentName("a/..b") );
}

sub _shittify {
    my ($a, $b) = Foswiki::Sandbox::sanitizeAttachmentName(shift);
    return $a;
}

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
    $Foswiki::cfg{UseLocale} = 0;
    for (0..255) {
        my $c = chr($_);
        $crap .= $c if $c =~ /$Foswiki::regex{filenameInvalidCharRegex}/;
    }
    my $x = $crap =~ / / ? '_' : '';
    $this->assert_str_equals( "pick_me${x}pick_me",
        _shittify("pick me${crap}pick me") );

    $crap = '';
    $Foswiki::cfg{UseLocale} = 1;
    for (0..255) {
        my $c = chr($_);
        $crap .= $c if $c =~ /$Foswiki::cfg{NameFilter}/;
    }
    $x = $crap =~ / / ? '_' : '';
    $this->assert_str_equals( "pick_me${x}pick_me",
        _shittify("pick me${crap}pick me") );

    # Check that the upload filter is applied.
    $Foswiki::cfg{UploadFilter} =
      qr(^(
             \.htaccess
         | .*\.(?i)(?:php[0-9s]?(\..*)?
         | [sp]htm[l]?(\..*)?
         | pl
         | py
         | cgi ))$)x;
    $this->assert_str_equals( ".htaccess.txt", _shittify(".htaccess") );
    for my $i qw(php shtm phtml pl py cgi PHP SHTM PHTML PL PY CGI) {
        my $x = "bog.$i";
        my $y = "$x.txt";
        $this->assert_str_equals( $y, _shittify($x) );
    }
    for my $i qw(php phtm shtml PHP PHTM SHTML) {
        my $x = "bog.$i.s";
        my $y = "$x.txt";
        $this->assert_str_equals( $y, _shittify($x) );
    }
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
    eval { Foswiki::Sandbox::_buildCommandLine('%A|%') };
    $this->assert_not_null( $@, '' );
    eval { Foswiki::Sandbox::_buildCommandLine('%A|X%') };
    $this->assert_not_null( $@, '' );
    eval { Foswiki::Sandbox::_buildCommandLine( ' %A|N%  ', A => '2/3' ) };
    $this->assert_not_null( $@, '' );
    eval { Foswiki::Sandbox::_buildCommandLine( ' %A|S%  ', A => '2/3' ) };
    $this->assert_not_null( $@, '' );
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
    ( $out, $exit ) =
      Foswiki::Sandbox->sysCommand( 'echo' );
    $this->assert_equals( 0, $exit );
    $this->assert_str_equals( `echo`, $out );
}

sub test_executeRSP {
    my $this = shift;
    return if $Foswiki::cfg{OS} eq 'WINDOWS';
    $Foswiki::Sandbox::REAL_SAFE_PIPE_OPEN     = 1;
    $Foswiki::Sandbox::EMULATED_SAFE_PIPE_OPEN = 0;
    $this->verify();
}

sub test_executeESP {
    my $this = shift;
    return if $Foswiki::cfg{OS} eq 'WINDOWS';
    $Foswiki::Sandbox::REAL_SAFE_PIPE_OPEN     = 0;
    $Foswiki::Sandbox::EMULATED_SAFE_PIPE_OPEN = 1;
    $this->verify();
}

sub test_executeNSP {
    my $this = shift;
    return if $Foswiki::cfg{OS} eq 'WINDOWS';
    $Foswiki::Sandbox::REAL_SAFE_PIPE_OPEN     = 0;
    $Foswiki::Sandbox::EMULATED_SAFE_PIPE_OPEN = 0;
    $this->verify();
}

1;
