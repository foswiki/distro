# See bottom of file for more information
package Unit::TestRunner;

use strict;
use Devel::Symdump;
use Error qw(:try);

sub new {
    my $class = shift;
    return bless({}, $class);
}

sub start {
    my $this = shift;
    my @files = @_;
    @{$this->{failures}} = ();
    my $passes = 0;

    # First use all the tests to get them compiled
    while (scalar(@files)) {
        my $suite = shift @files;
        $suite =~ s/^(.*?)(\w+)\.pm$/$2/;
        if ($1) {
            push(@INC, $1);
        }
        eval "use $suite";
        if ($@) {
            my $m = "*** Failed to use $suite: $@";
            print $m;
            push(@{$this->{failures}}, $m);
            next;
        }
        print "Running $suite\n";
        my $tester = $suite->new($suite);
        if ($tester->isa('Unit::TestSuite')) {
            # Get a list of included tests
            push(@files, $tester->include_tests());
        } else {
            # Get a list of the test methods in the class
            my @tests = $tester->list_tests($suite);
            unless (scalar(@tests)) {
                print "*** No tests in $suite\n";
                next;
            }
            foreach my $test (@tests) {
                print "\t$test\n";
                $tester->set_up();
                try {
                    $tester->$test();
                    $passes++;
                } catch Error::Simple with {
                    my $e = shift;
                    print "*** ",$e->stringify(),"\n";
                    push(@{$this->{failures}}, $test."\n".$e->stringify());
                };
                $tester->tear_down();
            }
        }
    }

    if (scalar(@{$this->{failures}})) {
        print scalar(@{$this->{failures}})." failures\n";
        print  join("\n---------------------------\n",
                    @{$this->{failures}}),"\n";
        print "$passes of ",$passes + scalar(@{$this->{failures}})," test cases passed\n";
        return scalar(@{$this->{failures}});
    } else {
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
