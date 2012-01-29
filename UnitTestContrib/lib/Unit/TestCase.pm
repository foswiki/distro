# See bottom of file for license and copyright
package Unit::TestCase;

=begin TML

---+ package Unit::TestCase
Base class of all unit test cases. Modeled on JUnit.TestCase.

This class is a general purpose and should not make any reference to
Foswiki.

=cut

use strict;
use Error qw( :try );
use Carp;
use Unit::HTMLDiffer;
use Unit::TestRunner();

$Carp::Verbose = 1;

use vars qw( $differ );

my $SEPARATOR_STRING = '########################################';

=begin TML

---++ ClassMethod new()
Construct a new testcase.

=cut

sub new {
    my $class = shift;
    my $this  = bless(
        {
            annotations    => [],
            expect_failure => 0
        },
        $class
    );
    return $this;
}

=begin TML

---+ ObjectMethod set_up()

Called by the test environment before each test case, used to set up
test fixtures.

Subclasses should call the superclass method in overrides.

=cut

sub set_up {
    my $this = shift;
    @{ $this->{annotations} } = ();
    $this->{expect_failure} = 0;
}

=begin TML

---++ ObjectMethod tear_down()
Tear down temporary test fixtures

Subclasses should call the superclass method in overrides.

=cut

sub tear_down {
}

=begin TML

---++ ObjectMethod run_in_new_process()

Override this method to return true 
in test suites that should be run in a separate process.
This facility is provided for tests that make non-reversible
changes to the system state e.g. tests that enable 
non-default plugins, whose initPlugin() handlers
could do just about anything

=cut

sub run_in_new_process {
    return;
}

sub _fixture_test {
    my ( $this, $set_up, $test ) = @_;
    $this->$set_up();
    $this->$test();
}

=begin TML

---++ ObjectMethod fixture_groups() ->\@\@functions

Implement this to return an array of arrays, each of which is a list
of the names of fixture setup functions. For example, ( [ A, B ], [ C, D] ).

This will generate a call for each of the functions whose names start
with verify_ in the test package, with a call to each of the setup
functions. For example, say we have a test function called verify_this.
Then the test functions generated will be:
   verify_this_A_C
   verify_this_A_D
   verify_this_B_C
   verify_this_B_D

The setup functions are called in order; for example, verify_this_A_C is
implemented as:
   $this->A();
   $this->C();
   $this->verify_this();

=cut

sub fixture_groups {
    return ();
}

=begin TML

---++ ObjectMethod list_tests() -> $list

Returns a list of the names of test functions defined by the testcase.
This method can be overridden to give an alternative list of tests.

=cut

our %tests_in;

sub list_tests {
    my ( $this, $suite ) = @_;
    die "No suite" unless $suite;

# We cache the test list because the test class is modified when we _gen_verification_functions
# and we don't want to list the lambda functions created therein
    return @{ $tests_in{$suite} } if ( defined $tests_in{$suite} );
    my @tests;
    my @verifies;
    my $clz = new Devel::Symdump($suite);
    for my $i ( $clz->functions() ) {
        if ( $i =~ /^$suite\:\:test/ ) {
            push( @tests, $i );
        }
        elsif ( $i =~ /^$suite\:\:(verify.*$)/ ) {
            push( @verifies, $1 );
        }
    }
    my @fgs = $this->fixture_groups();

    # Generate a verify method for each combination of the different
    # fixture methods
    my @setups = ();
    push(
        @tests,
        $this->_gen_verification_functions(
            \@setups, $suite, \@verifies, @fgs
        )
    );
    $tests_in{$suite} = \@tests;
    return @tests;
}

sub _gen_verification_functions {
    my $this     = shift;
    my $setups   = shift;
    my $suite    = shift;
    my $verifies = shift;
    my $group    = shift;
    my @tests;
    foreach my $setup_function (@$group) {
        push( @$setups, $setup_function );
        if ( scalar(@_) ) {
            push(
                @tests,
                $this->_gen_verification_functions(
                    $setups, $suite, $verifies, @_
                )
            );
        }
        else {
            foreach my $verify (@$verifies) {
                my $_fn  = $verify . '_' . join( '_', @$setups );
                my $fn   = $suite . '::' . $_fn;
                my $sup  = join( ';', map { '$this->' . $_ . '()' } @$setups );
                my $code = <<SUB;
*$fn = sub {
    my \$this = shift;
    $sup;
    \$this->$verify();
}
SUB
                eval $code;
                die "Couldn't make $code: $@" if $@;
                push( @tests, $fn );
                $this->{verify_permutations}{$fn} = $suite . '::' . $verify;
            }
        }
        pop(@$setups);
    }
    return @tests;
}

=begin TML

---++ ObjectMethod assert($condition [, $message])

Fail the test unless the $condition is true. $message is optional.

=cut

sub assert {
    my ( $this, $bool, $mess ) = @_;
    ::TAP( $bool, $mess );    #lets hack in perl TAP output
    return 1 if $bool;
    $mess ||= "Assertion failed";
    $mess = join( "\n", $this->annotations() ) . "\n" . $mess;
    $mess = Carp::longmess($mess);
    die $mess;
}

=begin TML

---++ ObjectMethod assert_equals($expected, $got [, $message])

Fail the test unless the $expected eq $got is true. $message is optional.

=cut

sub assert_equals {
    my ( $this, $expected, $got, $mess ) = @_;
    if ( defined($got) && defined($expected) ) {
        $this->assert( $expected eq $got,
            $mess || "Expected:'$expected'\n But got:'$got'\n" );
    }
    elsif ( defined($expected) && !defined($got) ) {
        $this->assert( 0, $mess || "Expected:'$expected'\n But got null\n" );
    }
    else {
        $this->assert_null($got);
    }
}

=begin TML

---++ ObjectMethod assert_not_null($wot [, $message])

Fail the test if $wot is undef. $message is optional.

=cut

sub assert_not_null {
    my ( $this, $wot, $mess ) = @_;
    $this->assert( defined($wot), $mess || "Expected not null value" );
}

=begin TML

---++ ObjectMethod assert_null($wot [, $message])

Fail the test unless $wot is undef. $message is optional.

=cut

sub assert_null {
    my ( $this, $wot, $mess ) = @_;
    $this->assert( !defined($wot),
        $mess || ( defined($wot) && "Expected null value, got '$wot'" ) );
}

=begin TML

---++ ObjectMethod assert_str_equals($expected, $got [, $message])

Fail the test unless $got eq $expected. $message is optional.

=cut

sub assert_str_equals {
    my ( $this, $expected, $got, $mess ) = @_;
    $this->assert_not_null( $expected, "Expected value may not be null" );
    $this->assert_not_null( $got,
        $mess || "Expected:'$expected'\n But got null value\n" );
    $this->assert( $expected eq $got,
        $mess || "Expected:'$expected'\n But got:'$got'\n" );
}

=begin TML

---++ ObjectMethod assert_str_not_equals($expected, $got [, $message])

Fail the test if $got eq $expected. $message is optional.

=cut

sub assert_str_not_equals {
    my ( $this, $expected, $got, $mess ) = @_;
    $this->assert_not_null( $expected, "Expected value may not be null" );
    $this->assert_not_null( $got,
        $mess || "Expected:'$expected'\n But got null value\n" );
    $this->assert( $expected ne $got,
        $mess || "Expected:'$expected'\n And got:'$got'\n" );
}

=begin TML

---++ ObjectMethod assert_num_equals($expected, $got [, $message])

Fail the test if $got == $expected. $message is optional.

=cut

sub assert_num_equals {
    my ( $this, $expected, $got, $mess ) = @_;
    $this->assert_not_null( $expected, "Expected value may not be null" );
    $this->assert_not_null( $got,
        $mess || "Expected:'$expected'\n But got null value\n" );
    $this->assert( $expected == $got,
        $mess || "Expected:'$expected'\n But got:'$got'\n" );
}

=begin TML

---++ ObjectMethod assert_num_not_equals($expected, $got [, $message])

Fail the test if $got != $expected. $message is optional.

=cut

sub assert_num_not_equals {
    my ( $this, $expected, $got, $mess ) = @_;
    $this->assert_not_null( $expected, "Expected value may not be null" );
    $this->assert_not_null( $got,
        $mess || "Expected:'$expected'\n But got null value\n" );
    $this->assert( $expected != $got,
        $mess || "Expected:'$expected'\n But got:'$got'\n" );
}

=begin TML

---++ ObjectMethod assert_matches($expected, $got [, $message])

Fail the test unless $got =~ /$expected/. $message is optional.

=cut

sub assert_matches {
    my ( $this, $expected, $got, $mess ) = @_;
    $this->assert_not_null( $expected, "Expected value may not be null" );
    $this->assert_not_null( $got,
        $mess || "Expected:'$expected'\n But got null value\n" );
    if ( $] < 5.010 ) {

        # See perl bug http://rt.perl.org/rt3/Public/Bug/Display.html?id=22354
        no warnings;
        $* = $expected =~ /\(\?[^-]*m/;
        use warnings;
    }
    $this->assert( scalar( $got =~ /$expected/ ),
        $mess || "Expected:'$expected'\n But got:'$got'\n" );
    if ( $] < 5.010 ) {
        no warnings;
        $* = 0;
        use warnings;
    }
}

=begin TML

---++ ObjectMethod assert_does_not_match($expected, $got [, $message])

Fail the test if $got !~ /$expected/ undef. $message is optional.

=cut

sub assert_does_not_match {
    my ( $this, $expected, $got, $mess ) = @_;
    $this->assert_not_null( $expected, "Expected value may not be null" );
    $this->assert_not_null( $got,
        $mess || "Expected:'$expected'\n But got null value\n" );
    if ( $] < 5.010 ) {

        # See perl bug http://rt.perl.org/rt3/Public/Bug/Display.html?id=22354
        no warnings;
        $* = /\(\?[^-]*m/;
        use warnings;
    }
    $this->assert( scalar( $got !~ /$expected/ ),
        $mess || "Expected:'$expected'\n And got:'$got'\n" );
    if ( $] < 5.010 ) {
        no warnings;
        $* = 0;
        use warnings;
    }
}

=begin TML

---++ ObjectMethod assert_deep_equals($expected, $got [, $message])

Fail the test if $got != $expected. Comparison is deep. $message is optional.

=cut

sub assert_deep_equals {
    my ( $this, $expected, $got, $mess, $sniffed ) = @_;

    $sniffed = {} unless $sniffed;

    if ( ref($expected) ) {

        # Cycle eliminator.
        if ( defined( $sniffed->{$expected} ) ) {
            $this->assert_equals( $sniffed->{$expected}, $got );
            return;
        }

        $sniffed->{$expected} = $got;
    }

    if ( UNIVERSAL::isa( $expected, 'ARRAY' ) ) {
        $this->assert( UNIVERSAL::isa( $got, 'ARRAY' ) );
        $this->assert_equals( $#$expected, $#$got,
            'Different size arrays: ' . ( $mess || '' ) );

        for ( 0 .. $#$expected ) {
            $this->assert_deep_equals( $expected->[$_], $got->[$_], $mess,
                $sniffed );
        }
    }
    elsif ( UNIVERSAL::isa( $expected, 'HASH' ) ) {
        $this->assert( UNIVERSAL::isa( $got, 'HASH' ) );
        my %matched;
        for ( keys %$expected ) {
            $this->assert_deep_equals( $expected->{$_}, $got->{$_}, $mess,
                $sniffed );
            $matched{$_} = 1;
        }
        for ( keys %$got ) {
            $this->assert( $matched{$_}, $_ );
        }
    }
    elsif (UNIVERSAL::isa( $expected, 'REF' )
        || UNIVERSAL::isa( $expected, 'SCALAR' ) )
    {
        $this->assert_equals( ref($expected), ref($got), $mess );
        $this->assert_deep_equals( $$expected, $$got, $mess, $sniffed );
    }
    else {
        $this->assert_equals( $expected, $got, $mess );
    }
}

=begin TML

---++ ObjectMethod annotate($message)

Add an annotation to the test output

=cut

sub annotate {
    my ( $this, $mess ) = @_;
    push( @{ $this->{annotations} }, $mess ) if defined($mess);
}

=begin TML

---++ ObjectMethod annotations() -> @annotations

=cut

sub annotations {
    my ($this) = @_;

    return @{ $this->{annotations} || [] };
}

=begin TML

---++ ObjectMethod expect_failure($reason)

Flag that the test is expected to fail in the current environment. This
is used for example on platfroms where tests are known to fail e.g. case
sensitivity of filenames on Win32.

If supplied, the test is annotated with =$reason= for why the failure is
expected.

=cut

sub expect_failure {
    my ( $this, $reason ) = @_;

    if ($reason) {
        $this->annotate($reason);
    }
    $this->{expect_failure} = 1;

    return;
}

=begin TML

---+ ObjectMethod assert_html_equals($expected, $got [,$message])

HTML comparison. Correctly compares attributes in tags. Uses HTML::Parser
which is tolerant of unbalanced tags, so the actual may have unbalanced
tags which will _not_ be detected.

=cut

sub assert_html_equals {
    my ( $this, $e, $a, $mess ) = @_;

    my ( $package, $filename, $line ) = caller(0);
    my $opts = {
        options  => '',
        reporter => \&Unit::HTMLDiffer::defaultReporter,
        result   => ''
    };

    $mess ||=
"$SEPARATOR_STRING Got as result:\n$a\n$SEPARATOR_STRING (end of result)\n$SEPARATOR_STRING But expected html equal string:\n$e\n$SEPARATOR_STRING (end of expected)";
    $this->assert( $e, "$filename:$line\n$mess" );
    $this->assert( $a, "$filename:$line\n$mess" );
    $differ ||= new Unit::HTMLDiffer();
    if ( $differ->diff( $e, $a, $opts ) ) {
        $this->assert( 0,
"$filename:$line\n$mess\n$SEPARATOR_STRING Diff:\n$opts->{result}\n$SEPARATOR_STRING (end diff)\n"
        );
    }
}

=begin TML

---+ ObjectMethod assert_html_matches($expected, $got [,$message])

See if a block of HTML occurs in a larger
block of HTML. Both blocks must be well-formed HTML.

=cut

sub assert_html_matches {
    my ( $this, $e, $a, $mess ) = @_;

    $differ ||= new Unit::HTMLDiffer();

    $mess ||=
"$SEPARATOR_STRING Got as result:\n$a\n$SEPARATOR_STRING (end of result)\n$SEPARATOR_STRING But expected html match string:\n$e\n$SEPARATOR_STRING (end of expected)";

    my ( $package, $filename, $line ) = caller(0);
    unless ( $differ->html_matches( $e, $a ) ) {
        $this->assert( 0, "$filename:$line\n$mess\n" );
    }
}

=begin TML

---+ ObjectMethod assert_json_equals($expected, $got [,$message])

Fail the test unless the two JSON data structures are equivalent.
The message is optional.

=cut

sub assert_json_equals {
    my ( $this, $expected, $got, $mess ) = @_;

    require JSON;
    my $json = JSON->new->allow_nonref;

    $this->assert_deep_equals( $json->decode($expected),
        $json->decode($got),
        $mess || "Expected:'$expected'\n But got:'$got'\n" );
}

=begin TML

---+ ObjectMethod captureSTD(\&fn, ...) -> ($stdout, $stderr, $result)

Invoke a function while grabbing stdout and stderr, so the output
doesn't flood the console that you're running the unit test from.

 ... params get passed on to &fn

$result is the return value from &fn

=cut

sub captureSTD {
    my $this = shift;
    my $proc = shift;

    require File::Temp;
    my %tempDirOptions = ( CLEANUP => 1 );
    if ( $^O eq 'MSWin32' ) {

        #on windows, don't make a big old mess of c:\
        $ENV{TEMP} =~ /(.*)/;
        $tempDirOptions{DIR} = $1;
    }
    my $tmpdir     = File::Temp::tempdir(%tempDirOptions);
    my $stdoutfile = "$tmpdir/stdout";
    my $stderrfile = "$tmpdir/stderr";

    my @params = @_;
    my $result;

    undef $this->{stdout};
    undef $this->{stderr};
    try {
        local *STDOUT;
        local *STDERR;
        open STDOUT, ">", $stdoutfile
          or die "Can't open temporary STDOUT file $stdoutfile: $!";
        open STDERR, ">", $stderrfile
          or die "Can't open temporary STDERR file $stderrfile: $!";

        $result = &$proc(@params);
    }
    finally {
        my $f;
        open( $f, '<', $stdoutfile )
          || die "Capture failed to reopen $stdoutfile";
        local $/;
        $this->{stdout} = <$f>;
        close($f);
        open( $f, '<', $stderrfile )
          || die "Capture failed to reopen $stderrfile";
        local $/;
        $this->{stderr} = <$f>;
        close($f);
    };
    return ( $this->{stdout}, $this->{stderr}, $result );
}

1;

__DATA__

Author: Crawford Currie, http://c-dot.co.uk

Copyright (C) 2008-2010 Foswiki Contributors

Additional copyrights apply to some or all of the code in this file
as follows:

Copyright (C) 2007-2008 WikiRing, http://wikiring.com

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.

