#!/usr/bin/perl -w
# See bottom of file for description

require 5.006;
use FindBin;
use Cwd ();
my $starting_root;

sub _findRelativeTo {
    my ( $startdir, $name ) = @_;

    my @path = split( /\/+/, $startdir );

    while ( scalar(@path) > 0 ) {
        my $found = join( '/', @path ) . '/' . $name;
        return $found if -e $found;
        pop(@path);
    }
    return undef;
}

BEGIN {
    $Foswiki::cfg{Engine} = 'Foswiki::Engine::CGI';
    # root the tree
    my $here = Cwd::abs_path;

    # Look for the installation that we are testing in context
    # with. This will be defined by either by finding an installation
    # on the path to the current dir, or by finding the first install
    # in FOSWIKI_LIBS.

    my $root = _findRelativeTo( $here, 'core/bin/setlib.cfg' )
      || _findRelativeTo( $here, 'bin/setlib.cfg' );

    die "Cannot locate bin/setlib.cfg" unless $root;

    $root =~ s{/bin/setlib.cfg$}{};
    ($root) = $root =~ /^(.*)$/;   # untaint 

    unshift @INC, "$root/test/unit";
    unshift @INC, "$root/bin";
    unshift @INC, "$root/lib";
    unshift @INC, "$root/lib/CPAN/lib";
    require 'setlib.cfg';
    $starting_root = $root;
};

use strict;
use Foswiki;   # If you take this out then TestRunner.pl will fail on IndigoPerl
use Unit::TestRunner;

my %options;
while (scalar(@ARGV) && $ARGV[0] =~ /^-/) {
    $options{shift(@ARGV)} = 1;
}

my ($stdout, $stderr, $log); # will be destroyed at the end, if created
if ($options{-log} and not $options{-worker}) {
    require Unit::Eavesdrop;
    my @gmt = gmtime(time());
    $gmt[4]++;
    $gmt[5] += 1900;
    $log = sprintf("%0.4d",$gmt[5]);
    for (my $i = 4; $i >= 0; $i--) {
        $log .= sprintf("%0.2d", $gmt[$i]);
    }
    $log .= '.log';
    open(F, ">$log") || die $!;
    print STDERR "Logging to $log\n";
    $stdout = new Unit::Eavesdrop('STDOUT');
    $stdout->teeTo(\*F);
    # Don't need this, all the required info goes to STDOUT. STDERR is
    # really just treated as a black hole (except when debugging)
#    $stderr = new Unit::Eavesdrop('STDERR');
#    $stderr->teeTo(\*F);
}
print STDERR "Options: ",join(' ',keys %options),"\n";

unless (defined $ENV{FOSWIKI_ASSERTS}) {
    print "exporting FOSWIKI_ASSERTS=1 for extra checking; disable by exporting FOSWIKI_ASSERTS=0\n";
    $ENV{FOSWIKI_ASSERTS} = 1;
}

if ($ENV{FOSWIKI_ASSERTS}) {
    print "Assert checking on $ENV{FOSWIKI_ASSERTS}\n";
} else {
    print "Assert checking off $ENV{FOSWIKI_ASSERTS}\n";
}

if ($options{-clean}) {
    require File::Path;
    my $rmDir = $Foswiki::cfg{DataDir};
    opendir( DIR, "$rmDir" );
    my @x = grep { s/^(Temp.*)/$rmDir\/$1/ } readdir(DIR);
    foreach my $x (@x) {
       ($x) = $x =~ /^(.*)$/;
        File::Path::rmtree($x) if ($x);
    }

    $rmDir = $Foswiki::cfg{PubDir};
    opendir( DIR, "$rmDir" );
    @x = grep { s/^(Temp.*)/$rmDir\/$1/ } readdir(DIR);
    foreach my $x (@x) {
       ($x) = $x =~ /^(.*)$/;
        File::Path::rmtree($x) if ($x);
    }
}

if (not $options{-worker}) {
    testForFiles($Foswiki::cfg{DataDir},'/Temp*');
    testForFiles($Foswiki::cfg{PubDir},'/Temp*');
}

my $testrunner = Unit::TestRunner->new();
my $exit;
if ($options{-worker}) {
    $exit = $testrunner->worker(@ARGV);
}
else {
    $exit = $testrunner->start(@ARGV);
}

print STDERR "Run was logged to $log\n" if $options{-log};


Cwd::chdir($starting_root) if ($starting_root);
exit $exit;

sub testForFiles {
    my $testDir = shift;
    my $pattrn = shift;
    opendir( DIR, "$testDir" );
    my @list = grep { s/^($pattrn)/$testDir\/$1\n/ } readdir(DIR);
    die "Please remove @list (or run with the -clean option) to run tests\n" if (scalar(@list));
}

1;

__DATA__

This script runs the test suites/cases defined on the command-line.

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
