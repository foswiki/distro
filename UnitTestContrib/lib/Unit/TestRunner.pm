# See bottom of file for license and copyright
package Unit::TestRunner;

=begin TML

---+ package Unit::TestRunner

Test run controller. Provides most of the functionality for the TestRunner.pl
script that runs testcases.

=cut

use strict;
use warnings;

use Assert;
use Devel::Symdump();
use File::Spec();
use Error qw(:try);

sub CHECKLEAK { 0 }

BEGIN {
    if (CHECKLEAK) {
        eval "use Devel::Leak::Object qw{ GLOBAL_bless };";
        die $@ if $@;
        $Devel::Leak::Object::TRACKSOURCELINES = 1;
    }
}

sub new {
    my $class = shift;
    return bless(
        {
            unexpected_passes   => [],
            expected_failures   => {},
            verify_permutations => {},
            failures            => [],
            number_of_asserts   => 0,
            unexpected_result   => {},
            tests_per_module    => {},
            failed_suites       => {},
            skipped_suites      => {},
            skipped_tests       => {},
            annotations         => {},
        },
        $class
    );
}

sub start {
    my $this  = shift;
    my @files = @_;
    @{ $this->{failures} }   = ();
    @{ $this->{initialINC} } = @INC;
    my $passes = 0;

    my ($start_cwd) = Cwd->cwd() =~ m/^(.*)$/;
    print "Starting CWD is $start_cwd \n";

    # First use all the tests to get them compiled
    while ( scalar(@files) ) {
        my $testSuiteModule = shift @files;
        $testSuiteModule =~
          s/\/$//;    # Trim final slash, for completion lovers like Sven
        my $testToRun;
        if ( $testSuiteModule =~ s/::(\w+)$// ) {
            $testToRun = $1;
        }
        my $suite = $testSuiteModule;
        if ( $testSuiteModule =~ /^(.*?)(\w+)\.pm$/ ) {
            $suite = $2;
            push( @INC, $1 ) if $1 && -d $1;
        }
        ($suite) = $suite =~ /^(.*)$/;

        if ( !eval "require $suite; 1;" ) {
            my $useError = $@;
            my $bad;

            # Try to be clever, look for it
            if ( $useError =~ /Can't locate \Q$suite\E\.pm in \@INC/ ) {
                my $testToFind = $testToRun ? "::$testToRun" : '';
                print "Looking for $suite$testToFind...\n";
                require File::Find;
                my @found;
                File::Find::find(
                    {
                        wanted => sub {
                            /^$suite/
                              && $File::Find::name =~ /^\.\/(.*\.pm)$/
                              && ( print("\tFound $1\n") )
                              && push( @found, $1 . $testToFind );
                        },
                        follow            => 1,
                        untaint           => 1,
                        dangling_symlinks => sub {
                            if ( $_[0] =~ m/^$suite/ ) {
                                print
"ERROR: $_[0] has dangling symlink, bypassing ...\n";
                                $bad = 1;
                            }
                        },
                        untaint_pattern => qr|^([-+@\w./:]+)$|,
                    },
                    '.'
                );

                next if ($bad);

                # Try to be even smarter: favor test suites
                # unless a specific test was requested
                my @suite = grep { /Suite\.pm/ } @found;
                if ( $#found and @suite ) {
                    if ($testToFind) {
                        @found = grep { !/Suite.pm/ } @found;
                        print "$testToRun is most likely not in @suite"
                          . ", removing it\n";
                        unshift @files, @found;
                    }
                    else {
                        print "Found "
                          . scalar(@found)
                          . " tests,"
                          . " favoring @suite\n";
                        unshift @files, @suite;
                    }
                }
                else {
                    unshift @files, @found;
                }
                next if @found;
            }
            print "*** Failed to use $suite: $useError";
            $this->{failed_suites}{$suite} = $useError;
            next;
        }
        print "Running $suite\n";
        my $tester = $suite->new($suite);
        if ( $tester->isa('Unit::TestSuite') ) {

            # Get a list of included tests
            my @set = $tester->include_tests();
            unshift( @files, @set );
        }
        else {
            my $completed;
            my $action;
            if ( $tester->run_in_new_process() ) {
                $action =
                  $this->runOneInNewProcess( $testSuiteModule, $suite,
                    $testToRun );
            }
            else {
                $action = $this->runOne( $tester, $suite, $testToRun );
            }

            if ( Cwd->cwd() ne $start_cwd ) {
                print "CWD changed to " . Cwd->cwd() . " by previous test!! \n";
                chdir $start_cwd
                  or die "Cannot change back to previous $start_cwd\n";
            }

            # untaint action for the case where the test is run in
            # another process
            $action =~ m/^(.*)$/ms;
            eval $1;
            die $@ if $@;
            die "Test suite $suite aborted\n" unless $completed;
        }
    }

    #marker so we can remove the above large output from the nightly emails
    print "\nUnit test run Summary:\n";
    print " - Tested with perl $^V, from $^X\n";
    my $actual_incorrect_failures = 0;
    my $actual_incorrect_passes   = 0;
    my $skipped_tests_total       = 0;
    my $actual_correct_failures   = 0;
    my $expected_passes;
    my $expected_correct;
    my $actual_correct;
    my $actual_correct_passes;
    my $actual_incorrect;
    my $total;

    if ( my $failed = scalar @{ $this->{failures} } ) {

        print "\n$failed failure" . ( $failed > 1 ? 's' : '' ) . ":\n";
        print join( "\n---------------------------\n", @{ $this->{failures} } ),
          "\n";
        $actual_incorrect_failures = $failed;
    }
    if ( my $failed = scalar @{ $this->{unexpected_passes} } ) {

     # Redundant displaying this in addition to the module failure summary.
     #print "\n$failed unexpected pass" . ( $failed > 1 ? 'es' : '' ) . ":\n\t";
     #print join( "\n\t", @{ $this->{unexpected_passes} } );
        $actual_incorrect_passes = $failed;
    }
    if ( my $skipped_tests =
        scalar( map { keys %{$_} } values %{ $this->{skipped_tests} } ) )
    {
        print "\n$skipped_tests skipped:\n";
        while ( my ( $suite, $tests ) = each %{ $this->{skipped_tests} } ) {
            my $ntests = scalar( keys %{$tests} );

            print
"$suite skipped $ntests (of $this->{tests_per_module}{$suite}):\n";
            while ( my ( $test, $reason ) = each %{$tests} ) {
                print "   * $test - $reason\n";
            }
        }
        $skipped_tests_total = $skipped_tests;
    }
    if ( my $skipped_suites = scalar( keys %{ $this->{skipped_suites} } ) ) {
        print "\n$skipped_suites skipped suite"
          . ( $skipped_suites > 1 ? 's' : '' ) . ":\n";
        while ( my ( $suite, $detail ) = each %{ $this->{skipped_suites} } ) {
            print "   * $suite ($detail->{tests}) - $detail->{reason}\n";
            $skipped_tests_total += $detail->{tests};
        }
    }
    if ( my $failed_suites = scalar( keys %{ $this->{failed_suites} } ) ) {
        while ( my ( $suite, $detail ) = each %{ $this->{failed_suites} } ) {
            $actual_incorrect_failures += 1;
        }
    }
    if ( my $failed =
        scalar( map { keys %{$_} } values %{ $this->{expected_failures} } ) )
    {
        print "\n$failed expected failure" . ( $failed > 1 ? 's' : '' ) . ":\n";
        while ( my ( $suite, $tests ) = each %{ $this->{expected_failures} } ) {
            my $ntests = scalar( keys %{$tests} );

            print "$suite has $ntests expected failure"
              . ( $ntests > 1 ? 's' : '' )
              . " (of $this->{tests_per_module}{$suite}):\n";
            while ( my ( $test, $reason ) = each %{$tests} ) {
                my @annotations = $this->get_annotations($test);

                if ( scalar(@annotations) ) {
                    print "   * $test: " . join( '; ', @annotations ) . "\n";
                }
                else {
                    print "   * $test\n";
                }
            }
        }
        $actual_correct_failures = $failed;
    }

    $total =
      $passes +
      $actual_incorrect_failures +
      $actual_correct_failures +
      $skipped_tests_total;
    $actual_incorrect = $actual_incorrect_passes + $actual_incorrect_failures;
    $expected_passes = $total - $skipped_tests_total - $actual_correct_failures;
    $expected_correct      = $expected_passes + $actual_correct_failures;
    $actual_correct        = $expected_correct - $actual_incorrect;
    $actual_correct_passes = $passes - $actual_incorrect_passes;
    if ($actual_incorrect) {
        print <<"HERE";

----------------------------
---++ Module Failure summary
HERE
        if ( my $failed_suites = scalar( keys %{ $this->{failed_suites} } ) ) {
            print "\n$failed_suites suite"
              . ( $failed_suites > 1 ? 's' : '' )
              . " FAILED to compile at all:\n";
            while ( my ( $suite, $detail ) = each %{ $this->{failed_suites} } )
            {
                $detail = substr( $detail, 0, 50 ) . '...';
                print "   * F: $suite - $detail\n";
            }
        }
        foreach my $module (
            sort {
                $this->{unexpected_result}->{$a}
                  <=> $this->{unexpected_result}->{$b}
            } keys( %{ $this->{unexpected_result} } )
          )
        {
            print "$module has "
              . $this->{unexpected_result}{$module}
              . " unexpected results (of "
              . $this->{tests_per_module}{$module} . "):\n";
            foreach my $test ( sort( @{ $this->{unexpected_passes} } ) ) {

                # SMELL: we should really re-arrange data structures to
                # avoid guessing which module the test belongs to...
                if ( $test =~ /^$module\b/ ) {
                    $this->_print_unexpected_test( $test, 'P' );
                }
            }
            foreach my $test ( sort( @{ $this->{failures} } ) ) {
                ($test) = split( /\n/, $test );

                # SMELL: we should really re-arrange data structures to
                # avoid guessing which module the test belongs to...
                if ( $test =~ /^$module\b/ ) {
                    $this->_print_unexpected_test( $test, 'F' );
                }
            }
        }

        print <<"HERE";
----------------------------
$actual_correct of $expected_correct test cases passed($actual_correct_passes)+failed($actual_correct_failures) ok from $total total, $skipped_tests_total skipped
$actual_incorrect_passes + $actual_incorrect_failures = $actual_incorrect incorrect results from unexpected passes + failures
HERE
        ::PRINT_TAP_TOTAL();
    }
    else {
        my $confusing_total = $actual_correct_failures + $skipped_tests_total;
        my $message         = "\nAll tests passed ($passes";

        if ($confusing_total) {
            $message .=
"/$total) [$skipped_tests_total skipped + $actual_correct_failures expected failure]\n";
        }
        else {
            $message .= ")\n";
        }
        print $message;
        ::PRINT_TAP_TOTAL();
    }
    return $actual_incorrect;
}

sub _print_unexpected_test {
    my ( $this, $test, $sense ) = @_;
    my @annotations = $this->get_annotations($test);

    print "   * $sense: $test"
      . ( scalar(@annotations) ? ' - ' . join( '; ', @annotations ) : '' )
      . "\n";

    return;
}

sub runOneInNewProcess {
    my $this            = shift;
    my $testSuiteModule = shift;
    my $suite           = shift;
    my $testToRun       = shift;
    $testToRun ||= 'undef';

    my $tempfilename = 'worker_output.' . $$ . '.' . $suite;

    # Assume all new paths were either unshifted or pushed onto @INC
    my @pushedOntoINC    = @INC;
    my @unshiftedOntoINC = ();
    while ( $this->{initialINC}->[0] ne $pushedOntoINC[0] ) {
        push @unshiftedOntoINC, shift @pushedOntoINC;
    }
    for my $oneINC ( @{ $this->{initialINC} } ) {
        shift @pushedOntoINC if $pushedOntoINC[0] eq $oneINC;
    }

    my @paths;
    push( @paths, "-I", $_ ) for ( @unshiftedOntoINC, @pushedOntoINC );
    my @command = map {
        my $value = $_;
        if ( defined $value ) {
            $value =~ /(.*)/;
            $value = $1;    # untaint
        }
        $value;
      } (
        $^X, "-wT", @paths, File::Spec->rel2abs($0),
        "-worker", $suite,, $testToRun, $tempfilename
      );
    my $command = join( ' ', @command );
    print "Running: $command\n";

    $ENV{PATH} =~ /(.*)/;
    $ENV{PATH} = $1;        # untaint
    system(@command);
    if ( $? == -1 ) {
        my $error = $!;
        unlink $tempfilename;
        print "*** Could not spawn new process for $suite: $error\n";
        return
            'push( @{ $this->{failures} }, "'
          . $suite . '\n'
          . quotemeta($error) . '" );';
    }
    else {
        my $returnCode = $? >> 8;
        if ($returnCode) {
            print "*** Error trying to run $suite\n";
            unlink $tempfilename;
            return
                'push( @{ $this->{failures} }, "Process for '
              . $suite
              . ' returned '
              . $returnCode . '" );';
        }
        else {
            open my $testoutputfile, "<", $tempfilename
              or die
              "Cannot open '$tempfilename' to read output from $suite: $!";
            my $action = '';
            while (<$testoutputfile>) {
                $action .= $_;
            }
            close $testoutputfile or die "Error closing '$tempfilename': $!";
            unlink $tempfilename;
            return $action;
        }
    }
}

sub worker {
    my $numArgs = scalar(@_);
    my ( $this, $testSuiteModule, $testToRun, $tempfilename ) = @_;
    if (   $numArgs != 4
        or not defined $this
        or not defined $testSuiteModule
        or not defined $testToRun
        or not defined $tempfilename )
    {
        my $pkg = __PACKAGE__;
        die <<"DIE";

Wrong number of arguments to $pkg->worker(). Got $numArgs, expected 4.
Are you trying to use -worker from the command-line?
-worker is only intended for use by $pkg->runOneInNewProcess().
To run your test in a separate process, override run_in_new_process() in your test class so that it returns true.
DIE
    }

    if ( $testToRun eq 'undef' ) {
        $testToRun = undef;
    }
    else {
        $testToRun =~ /(.*)/;    # untaint
        $testToRun = $1;
    }

    $testSuiteModule =~ /(.*)/;    # untaint
    $testSuiteModule = $1;

    $tempfilename =~ /(.*)/;       # untaint
    $tempfilename = $1;

    my $suite = $testSuiteModule;
    eval "use $suite";
    die $@ if $@;

    my $tester = $suite->new($suite);

    my $log = "stdout.$$.log";
    require Unit::Eavesdrop;
    open( my $logfh, ">", $log ) || die $!;
    print STDERR "Logging to $log\n";
    my $stdout = new Unit::Eavesdrop('STDOUT');
    $stdout->teeTo($logfh);

    # Don't need this, all the required info goes to STDOUT. STDERR is
    # really just treated as a black hole (except when debugging)
    #    my $stderr = new Unit::Eavesdrop('STDERR');
    #    $stderr->teeTo($logfh);

    my $action = __PACKAGE__->runOne( $tester, $suite, $testToRun );

    {
        local $SIG{__WARN__} = sub { die $_[0]; };
        eval { close $logfh; };
        if ($@) {
            if ( $@ =~ /Bad file descriptor/ and $suite eq 'EngineTests' ) {

                # This is expected - ignore it
            }
            else {

                # propagate the error
                die $@;
            }
        }
    }
    undef $logfh;
    $stdout->finish();
    undef $stdout;

    #    $stderr->finish();
    #    undef $stderr;
    open( $logfh, "<", $log ) or die $!;
    local $/;    # slurp in whole file
    my $logged_stdout = <$logfh>;
    close $logfh or die $!;
    unlink $log  or die "Could not unlink $log: $!";

    #escape characters so that it may be printed
    $logged_stdout =~ s{\\}{\\\\}g;
    $logged_stdout =~ s{'}{\\'}g;
    $action .= "print '" . $logged_stdout . "';";

    open my $outputfile, ">", $tempfilename
      or die "Cannot open output file '$tempfilename': $!";
    print $outputfile $action . "\n";
    close $outputfile or die "Error closing output file '$tempfilename': $!";
    exit(0);
}

sub runOne {
    my $this      = shift;
    my $tester    = shift;
    my $suite     = shift;
    my $testToRun = shift;
    my $action    = '$completed = 1;';

    # Get a list of the test methods in the class
    my @tests = $tester->list_tests($suite);
    if ($testToRun) {
        my @runTests = grep { /^${suite}::$testToRun$/ } @tests;
        if ( !@runTests ) {
            @runTests = grep { /^${suite}::$testToRun/ } @tests;
            if ( !@runTests ) {
                print "*** No test matching $testToRun in $suite\n";
                print join( "\n", "\t$suite contains:", @tests, '' );
                return $action;
            }
            else {
                print "*** Running "
                  . @runTests
                  . " tests matching your pattern ($testToRun)\n";
            }
        }
        @tests = @runTests;
    }
    unless ( scalar(@tests) ) {
        print "*** No tests in $suite\n";
        return $action;
    }
    my $skip_reason = $tester->can('skip') ? $tester->skip() : undef;
    if ( defined $skip_reason ) {
        my $ntests = scalar(@tests);
        print "*** Skipping suite $suite ($ntests) - $skip_reason\n";
        $action .=
          "\$this->{skipped_suites}{'$suite'} = {tests => $ntests, reason => \""
          . quotemeta($skip_reason) . "\"};";
    }
    else {
        foreach my $test (@tests) {
            my $skip = $tester->can('skip') ? $tester->skip($test) : undef;

            if ( defined $skip ) {
                $action .= "\$this->{skipped_tests}{'$suite'}{'$test'} = \""
                  . quotemeta($skip) . '";';
                $action .= '$this->{tests_per_module}->{\'' . $suite . '\'}++;';
                print "SKIP\t$test - $skip\n";
            }
            else {
                Devel::Leak::Object::checkpoint() if CHECKLEAK;
                print "\t$test\n";
                $action .= "\n# $test\n    ";
                $tester->set_up($test);
                try {
                    $action .=
                      '$this->{tests_per_module}->{\'' . $suite . '\'}++;';
                    $tester->$test();
                    _finish_singletons() if CHECKLEAK;
                    $action .= '$passes++;';
                    if ( $tester->{expect_failure} ) {
                        print "*** Unexpected pass\n";
                        $action .=
                          '$this->{unexpected_result}->{\'' . $suite . '\'}++;';
                        $action .= 'push( @{ $this->{unexpected_passes} }, "'
                          . quotemeta($test) . '");';
                    }
                }
                catch Error with {
                    my $e = shift;
                    print "*** ", $e->stringify(), "\n";
                    if ( $tester->{expect_failure} ) {
                        $action .=
                          "\$this->{expected_failures}{'$suite'}{'$test'} = \""
                          . quotemeta( $e->stringify() ) . '";';
                    }
                    else {
                        $action .=
                          '$this->{unexpected_result}->{\'' . $suite . '\'}++;';
                        $action .= 'push( @{ $this->{failures} }, "';
                        $action .=
                            quotemeta($test) . '\\n'
                          . quotemeta( $e->stringify() ) . '" );';
                    }
                };
                $this->set_annotations( $test, [ $tester->annotations() ] );
                $tester->tear_down($test);
                if (CHECKLEAK) {
                    _finish_singletons();

                    #require Devel::FindRef;
                    #foreach my $s (@Foswiki::Address::THESE) {
                    #    print STDERR Devel::FindRef::track($s);
                    #}
                }
            }
        }
    }
    return $action;
}

my %annotations;

sub set_annotations {
    my ( $this, $test, $annotations ) = @_;

    $annotations{$test} = $annotations;

    return;
}

sub get_annotations {
    my ( $this, $test, $annotations ) = @_;

    return @{ $annotations{$test} || [] };
}

sub _finish_singletons {

    # Item11349. This class keeps a bunch of singletons around, which is
    # the same as a memory leak.
    if ( eval { require Foswiki::Serialise; 1; }
        && Foswiki::Serialise->can('finish') )
    {
        Foswiki::Serialise->finish();
    }
}

1;

__DATA__

Author: Crawford Currie, http://c-dot.co.uk

Copyright (C) 2007-2010 Foswiki Contributors
All Rights Reserved.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
