#!/usr/bin/perl
#
# Examine TWiki dynamic function coverage
#
# To use this script:
#   1 Take a copy of the 'view' script; call it "view_dprof"
#   2 Change the -wT at the top of view_dprof to "-d:DProf"
#   3 View a page using the dprof script instead of view
#   4 set $bin in this script to point to the bin directory of the installation
#   5 run the script
# Functions will be sorted by the number of times they were called. You
# can pull the same trick for other scripts e.g. edit_dprof.
#
# Copyright (C) 2004 Crawford Currie http://c-dot.co.uk
#
use strict;

my $bin = "/home/twiki/mine/bin";

my $num = qr/(?:-?\d+\.\d+|-)/;
my @profiles;
my $lastWasDesc = 0;

foreach my $line ( split( /\n/, `cd $bin && dprofpp -O 1000 -U -q 2>&1` ) ) {
    if ( $line =~ /^\s+$num\s+$num\s+$num\s+(\d+)\s*$num\s+$num\s+(\S+)$/o ) {
        push( @profiles, { calls => $1, name => $2 } );
        $lastWasDesc = 1;
    }
    elsif ( $lastWasDesc && $line =~ /^\s+(0.0000\s+)?(\S+)$/ ) {
        $profiles[$#profiles]{name} .= $2;
    }
    else {
        $lastWasDesc = 0;
    }
}

@profiles =
  reverse sort { $a->{calls} <=> $b->{calls} }
  grep { $_->{name} =~ /^Foswiki::/ && $_->{name} !~ /BEGIN$/ } @profiles;

foreach my $prof (@profiles) {
    print $prof->{name}, " ", $prof->{calls}, "\n";
}

