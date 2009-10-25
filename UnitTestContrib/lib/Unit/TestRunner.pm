# See bottom of file for more information
package Unit::TestRunner;

use strict;
use Devel::Symdump;
use Error qw(:try);
#use Devel::Leak::Object qw{ GLOBAL_bless };
#$Devel::Leak::Object::TRACKSOURCELINES = 1;

sub new {
    my $class = shift;
    return bless( {}, $class );
}

sub start {
    my $this  = shift;
    my @files = @_;
    @{ $this->{failures} } = ();
    my $passes = 0;

    # First use all the tests to get them compiled
    while ( scalar(@files) ) {
        my $suite = shift @files;
        $suite =~ s/\/$//;   # Trim final slash, for completion lovers like Sven
        my $testToRun;
        if ( $suite =~ s/::(\w+)$// ) {
            $testToRun = $1;
        }
        if ( $suite =~ s/^(.*?)(\w+)\.pm$/$2/ ) {
            push( @INC, $1 ) if $1 && -d $1;
        }
        eval "use $suite";
        if ($@) {

            # Try to be clever, look for it
            if ( $@ =~ /Can't locate \Q$suite\E\.pm in \@INC/ ) {
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
                        follow => 1
                    },
                    '.'
                );

                # Try to be even smarter: favor test suites
                # unless a specific test was requested
                my @suite = grep { /Suite.pm/ } @found;
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
            my $m = "*** Failed to use $suite: $@";
            print $m;
            push( @{ $this->{failures} }, $m );
            next;
        }
        print "Running $suite\n";
        my $tester = $suite->new($suite);
        if ( $tester->isa('Unit::TestSuite') ) {

            # Get a list of included tests
            push( @files, $tester->include_tests() );
        }
        else {

            # Get a list of the test methods in the class
            my @tests = $tester->list_tests($suite);
            if ($testToRun) {
                @tests = grep { /^${suite}::$testToRun$/ } @tests;
                if ( !@tests ) {
                    print "*** No test called $testToRun in $suite\n";
                    next;
                }
            }
            unless ( scalar(@tests) ) {
                print "*** No tests in $suite\n";
                next;
            }
            foreach my $test (@tests) {
                #Devel::Leak::Object::checkpoint();
                print "\t$test\n";
                $tester->set_up();
                try {
                    $tester->$test();
                    $passes++;
                    if ( $tester->{expect_failure} ) {
                        $this->{unexpected_passes}++;
                    }
                }
                catch Error with {
                    my $e = shift;
                    print "*** ", $e->stringify(), "\n";
                    if ( $tester->{expect_failure} ) {
                        $this->{expected_failures}++;
                    }
                    else {
                        $this->{unexpected_failures}++;
                    }
                    push(
                        @{ $this->{failures} },
                        $test . "\n" . $e->stringify()
                    );
                };
                $tester->tear_down();
            }
        }
   }

    if ( $this->{unexpected_failures} || $this->{unexpected_passes} ) {
        print $this->{unexpected_failures} . " failures\n"
          if $this->{unexpected_failures};
        print $this->{unexpected_passes} . " unexpected passes\n"
          if $this->{unexpected_passes};
        print join( "\n---------------------------\n", @{ $this->{failures} } ),
          "\n";
        $this->{unexpected_failures} ||= 0;
        print "$passes of ", $passes + $this->{unexpected_failures},
          " test cases passed\n";
        return scalar( @{ $this->{failures} } );
    }
    else {
        print $this->{expected_failures} . " expected failures\n"
          if $this->{expected_failures};
        print "All tests passed ($passes)\n";
        return 0;
    }
}

1;

__DATA__

=pod

Test run controller
Author: Crawford Currie, http://c-dot.co.uk

Copyright (C) 2007 WikiRing, http://wikiring.com
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

=cut
