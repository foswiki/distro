# Copyright (C) 2004 Florian Weimer
package RobustnessTests;

use base qw(TWikiTestCase);
require 5.006;

use TWiki;
use TWiki::Sandbox;
use TWiki::Time;
use Error qw( :try );

my $slash;

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();
    $this->{twiki} = new TWiki();
    $slash = ($TWiki::cfg{OS} eq 'WINDOWS') ? '\\' : '/';
    # NOTE: this test pokes the *shared* sandbox, so we have to be extra
    # careful about restoring state. We store the state, rather than
    # just destroying the sandbox object, so that we can
    # still pick up on potential mod_perl problems in the tests.
    $this->{RSPO} = $TWiki::sandbox->{REAL_SAFE_PIPE_OPEN};
    $this->{ESPO} = $TWiki::sandbox->{EMULATED_SAFE_PIPE_OPEN};
}

sub tear_down {
    my $this = shift;
    # NOTE: this test pokes the *shared* sandbox, so we have to be extra
    # careful about restoring state.
    $TWiki::sandbox->{REAL_SAFE_PIPE_OPEN} = $this->{RSPO};
    $TWiki::sandbox->{EMULATED_SAFE_PIPE_OPEN} = $this->{ESPO};
    $this->{twiki}->finish();
    $this->SUPER::tear_down();
}

sub test_untaint {
    my $this = shift;
    $this->assert_str_equals('', TWiki::Sandbox::untaintUnchecked (''));
    $this->assert_not_null('abc', TWiki::Sandbox::untaintUnchecked ('abc'));
    $this->assert_null(TWiki::Sandbox::untaintUnchecked (undef));
}

sub test_normalize {
    my $this = shift;

    $this->assert_str_equals( "abc", TWiki::Sandbox::normalizeFileName ("abc"));
    $this->assert_str_equals("abc", TWiki::Sandbox::normalizeFileName ("./abc"));
    $this->assert_str_equals("abc", TWiki::Sandbox::normalizeFileName ("abc/."));
    $this->assert_str_equals("${slash}abc", TWiki::Sandbox::normalizeFileName ("/abc"));
    $this->assert_str_equals("${slash}abc", TWiki::Sandbox::normalizeFileName ("//abc"));
    $this->assert_str_equals("${slash}a${slash}bc", TWiki::Sandbox::normalizeFileName ("/a/bc"));
    $this->assert_str_equals("${slash}a${slash}b${slash}c", TWiki::Sandbox::normalizeFileName ("/a/b/c"));
    $this->assert_str_equals("${slash}a${slash}b${slash}c", TWiki::Sandbox::normalizeFileName ("/a/b/c/"));

    $this->assert_str_equals("abc", TWiki::Sandbox::normalizeFileName (".${slash}abc"));
    $this->assert_str_equals("abc", TWiki::Sandbox::normalizeFileName ("abc${slash}."));
    $this->assert_str_equals("${slash}abc", TWiki::Sandbox::normalizeFileName ("${slash}${slash}abc"));
    $this->assert_str_equals("${slash}a${slash}bc", TWiki::Sandbox::normalizeFileName ("${slash}a${slash}bc"));
    $this->assert_str_equals("${slash}a${slash}b${slash}c", TWiki::Sandbox::normalizeFileName ("${slash}a${slash}b${slash}c"));
    $this->assert_str_equals("${slash}a${slash}b${slash}c", TWiki::Sandbox::normalizeFileName ("${slash}a${slash}b${slash}c${slash}"));
    unless ($TWiki::cfg{OS} eq 'WINDOWS') {
        $this->assert_str_equals("${slash}a${slash}b${slash}c", TWiki::Sandbox::normalizeFileName ("${slash}${slash}a${slash}b${slash}c"));
        $this->assert_str_equals("${slash}a${slash}bc", TWiki::Sandbox::normalizeFileName ("${slash}${slash}a${slash}bc"));
        $this->assert_str_equals("${slash}abc", TWiki::Sandbox::normalizeFileName ("${slash}abc"));
        $this->assert_str_equals("${slash}a${slash}b${slash}c", TWiki::Sandbox::normalizeFileName ("//a/b/c/"));
        $this->assert_str_equals("${slash}a${slash}b${slash}c", TWiki::Sandbox::normalizeFileName ("//a/b/c"));
        $this->assert_str_equals("${slash}a${slash}bc", TWiki::Sandbox::normalizeFileName ("//a/bc"));
        $this->assert_str_equals("${slash}a${slash}b${slash}c", TWiki::Sandbox::normalizeFileName ("${slash}${slash}a${slash}b${slash}c${slash}"));
    }

    try {
        TWiki::Sandbox::normalizeFileName("c/..");
        $this->assert(0);
    } catch Error::Simple with {
        $this->assert_matches(qr/^relative path/, shift->stringify());
    };
    try {
        TWiki::Sandbox::normalizeFileName ("../a");
        $this->assert(0);
    } catch Error::Simple with {
        $this->assert_matches(qr/^relative path/, shift->stringify());
    };
    try {
        $this->assert_str_equals("a/../b", TWiki::Sandbox::normalizeFileName ("//a/b/c/../.."));
        $this->assert(0);
    } catch Error::Simple with {
        $this->assert_matches(qr/^relative path/, shift->stringify());
    };
    $this->assert_str_equals("..a", TWiki::Sandbox::normalizeFileName ("..a/"));
    $this->assert_str_equals("a${slash}..b", TWiki::Sandbox::normalizeFileName ("a/..b"));
}

sub test_sanitizeAttachmentName {
    my $this = shift;
    
    $this->assert_str_equals("abc", TWiki::Sandbox::sanitizeAttachmentName ("abc"));
    $this->assert_str_equals("abc.txt", TWiki::Sandbox::sanitizeAttachmentName ("abc.txt"));
    $this->assert_str_equals("abc.txt", TWiki::Sandbox::sanitizeAttachmentName ("../abc.txt"));
    $this->assert_str_equals("abc.txt", TWiki::Sandbox::sanitizeAttachmentName (".abc.txt"));
    $this->assert_str_equals("abc.txt", TWiki::Sandbox::sanitizeAttachmentName ("\\abc.txt"));
    $this->assert_str_equals("abc.txt", TWiki::Sandbox::sanitizeAttachmentName ("/abc.txt"));
    
    $this->assert_str_equals("abc.php.txt", TWiki::Sandbox::sanitizeAttachmentName ("abc.php")); # just checking the string conversion, not the tainted input filename
    
    $this->assert_str_equals("a_b_c", TWiki::Sandbox::sanitizeAttachmentName ("a b c"));
    
    # checking tainted variable
    my $tainted = $ENV{PATH};
    my $untainted = $tainted;
    $untainted =~ s/(.*?)/$1/;
    $untainted =~ s{[\\/]+$}{};          # Get rid of trailing slash/backslash (unlikely)
    $untainted =~ s!^.*[\\/]!!;          # Get rid of directory part
    $untainted =~ s/^([\.\/\\]*)*(.*?)$/$2/go;

    $this->assert_str_equals($untainted, TWiki::Sandbox::sanitizeAttachmentName ($tainted));
}

sub test_buildCommandLine {
    my $this = shift;
    $this->assert_deep_equals(["a", "b", "c"],
                              [$TWiki::sandbox->_buildCommandLine("a b c", ())]);
    $this->assert_deep_equals(["a", "b", "c"],
                              [$TWiki::sandbox->_buildCommandLine(" a  b  c ", ())]);
    $this->assert_deep_equals([1, 2, 3],
                              [$TWiki::sandbox->_buildCommandLine(" %A%  %B%  %C% ", (A => 1, B => 2, C => 3))]);
    $this->assert_deep_equals([1, "./-..", "a${slash}b"],
                              [$TWiki::sandbox->_buildCommandLine(" %A|U%  %B|F%  %C|F% ", (A => 1, B => "-..", C => "a/b"))]);
    $this->assert_deep_equals([1, "2:3"],
                              [$TWiki::sandbox->_buildCommandLine(" %A%  %B%:%C% ", (A => 1, B => 2, C => 3))]);
    $this->assert_deep_equals([1, "-n2:3"],
                              [$TWiki::sandbox->_buildCommandLine(" %A%  -n%B%:%C% ", (A => 1, B => 2, C => 3))]);
    $this->assert_deep_equals([1, "-r2:HEAD", 3],
                              [$TWiki::sandbox->_buildCommandLine(" %A%  -r%B%:HEAD %C% ", (A => 1, B => 2, C => 3))]);
    $this->assert_deep_equals(["a", "b", "${slash}c"],
                              [$TWiki::sandbox->_buildCommandLine(" %A|F%  ", (A => ["a", "b", "/c"]))]);

    $this->assert_deep_equals(
            ["1", "2.3", "4", 'str-.+_ing', "-09AZaz.+_"],
            [$TWiki::sandbox->_buildCommandLine(" %A|N% %B|S% %C|S%",
                 (A => [1, 2.3, 4], B => 'str-.+_ing', C => "-09AZaz.+_"))]);

    $this->assert_deep_equals(["2004/11/20 09:57:41"],
                              [$TWiki::sandbox->_buildCommandLine("%A|D%", A => TWiki::Time::formatTime (1100944661, '$rcs', 'gmtime'))]);
    eval { $TWiki::sandbox->_buildCommandLine('%A|%') };
    $this->assert_not_null($@, '');
    eval { $TWiki::sandbox->_buildCommandLine('%A|X%') };
    $this->assert_not_null($@, '');
    eval { $TWiki::sandbox->_buildCommandLine(' %A|N%  ', A => '2/3') };
    $this->assert_not_null($@, '');
    eval { $TWiki::sandbox->_buildCommandLine(' %A|S%  ', A => '2/3') };
    $this->assert_not_null($@, '');
}

sub verify {
    my $this = shift;
    my($out, $exit) = $TWiki::sandbox->sysCommand(
        'sh -c %A%', A => 'echo OK; echo BOSS');
    $this->assert_str_equals("OK\nBOSS\n", $out);
    $this->assert_equals(0, $exit);
    ($out, $exit) = $TWiki::sandbox->sysCommand(
        'sh -c %A%', A => 'echo JUNK ON STDERR 1>&2');
    $this->assert_equals(0, $exit);
    $this->assert_str_equals("", $out);
    ($out, $exit) = $TWiki::sandbox->sysCommand(
        'test %A% %B% %C%', A => '1', B=>'-eq', C=>'2');
    $this->assert_equals(1, $exit, $exit.' '.$out);
    $this->assert_str_equals("", $out);
    ( $out, $exit) = $TWiki::sandbox->sysCommand(
        'sh -c %A%', A => 'echo urmf; exit 7');
    $this->assert($exit != 0);
    $this->assert_str_equals("urmf\n", $out);
}

sub test_executeRSP {
    my $this = shift;
    return if $TWiki::cfg{OS} eq 'WINDOWS';
    $TWiki::sandbox->{REAL_SAFE_PIPE_OPEN} = 1;
    $TWiki::sandbox->{EMULATED_SAFE_PIPE_OPEN} = 0;
    $this->verify();
}

sub test_executeESP {
    my $this = shift;
    return if $TWiki::cfg{OS} eq 'WINDOWS';
    $TWiki::sandbox->{REAL_SAFE_PIPE_OPEN} = 0;
    $TWiki::sandbox->{EMULATED_SAFE_PIPE_OPEN} = 1;
    $this->verify();
}

sub test_executeNSP {
    my $this = shift;
    return if $TWiki::cfg{OS} eq 'WINDOWS';
    $TWiki::sandbox->{REAL_SAFE_PIPE_OPEN} = 0;
    $TWiki::sandbox->{EMULATED_SAFE_PIPE_OPEN} = 0;
    $this->verify();
}

1;
