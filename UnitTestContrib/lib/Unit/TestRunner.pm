# See bottom of file for license and copyright
package Unit::TestRunner;

=begin TML

---+ package Unit::TestRunner

Test run controller. Provides most of the functionality for the TestRunner.pl
script that runs testcases.

=cut

use strict;
use Devel::Symdump;
use Error qw(:try);

#use Devel::Leak::Object qw{ GLOBAL_bless };
#$Devel::Leak::Object::TRACKSOURCELINES = 1;

sub new {
    my $class = shift;
    return bless(
        {
            unexpected_passes => [],
            expected_failures => [],
            failures          => [],
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
        eval "use $suite";
        if ($@) {
            my $useError = $@;

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
                        follow => 1,
                        untaint => 1
                    },
                    '.'
                );

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
            my $m = "*** Failed to use $suite: $useError";
            print $m;
            push( @{ $this->{failures} }, $m );
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
                $action = runOne( $tester, $suite, $testToRun );
            }

          # untaint action for the case where the test is run in another process
            ($action) = $action =~ m/^(.*)$/ms;

            eval $action;
            die $@ if $@;
            die "Test suite $suite aborted\n" unless $completed;
        }
    }

    my $total = $passes;
    my $failed;
    if ( $failed = scalar @{ $this->{unexpected_passes} } ) {
        print "$failed unexpected pass" . ( $failed > 1 ? 'es' : '' ) . ":\n";
        print join( "\n", @{ $this->{unexpected_passes} } );
        $total += $failed;
    }
    if ( $failed = scalar @{ $this->{expected_failures} } ) {
        print "$failed expected failure" . ( $failed > 1 ? 's' : '' ) . ":\n";
        print join( "\n", @{ $this->{expected_failures} } );
        $total += $failed;
    }
    if ( $failed = scalar @{ $this->{failures} } ) {
        print "\n$failed failure" . ( $failed > 1 ? 's' : '' ) . ":\n";
        print join( "\n---------------------------\n", @{ $this->{failures} } ),
          "\n";
        $total += $failed;
        print "$passes of $total test cases passed\n";
        return $failed;
    }
    print "All tests passed ($passes"
      . ( $passes == $total ? '' : "/$total" ) . ")\n";
    return 0;
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

    my $paths =
      join( ' ', map { '-I ' . $_ } @unshiftedOntoINC, @pushedOntoINC );
    my $command = "perl -w $paths $0 -worker $suite $testToRun $tempfilename";
    print "Running: $command\n";
    system($command);
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
            die;
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
    my ( $this, $testSuiteModule, $testToRun, $tempfilename ) = @_;
    if ( $testToRun eq 'undef' ) {
        $testToRun = undef;
    }

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

    my $action = runOne( $tester, $suite, $testToRun );

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
    my $tester    = shift;
    my $suite     = shift;
    my $testToRun = shift;
    my $action    = '$completed = 1;';

    # Get a list of the test methods in the class
    my @tests = $tester->list_tests($suite);
    if ($testToRun) {
        @tests = grep { /^${suite}::$testToRun$/ } @tests;
        if ( !@tests ) {
            print "*** No test called $testToRun in $suite\n";
            return $action;
        }
    }
    unless ( scalar(@tests) ) {
        print "*** No tests in $suite\n";
        return $action;
    }
    foreach my $test (@tests) {

        #Devel::Leak::Object::checkpoint();
        print "\t$test\n";
        $action .= "\n# $test\n    ";
        $tester->set_up();
        try {
            $tester->$test();
            $action .= '$passes++;';
            if ( $tester->{expect_failure} ) {
                print "*** Unexpected pass\n";
                $action .=
                  'push( @{ $this->{unexpected_passes} }, "' . quotemeta($test);
            }
        }
        catch Error with {
            my $e = shift;
            print "*** ", $e->stringify(), "\n";
            if ( $tester->{expect_failure} ) {
                $action .= 'push( @{ $this->{expected_failures} }, "';
            }
            else {
                $action .= 'push( @{ $this->{failures} }, "';
            }
            $action .=
              quotemeta($test) . '\\n' . quotemeta( $e->stringify() ) . '" );';
        };
        $tester->tear_down();
    }
    return $action;
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

