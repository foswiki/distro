#!/usr/bin/perl -wT

use strict;

require Benchmark;
import Benchmark ':hireswallclock';

#https://bugzilla.redhat.com/show_bug.cgi?id=196836
#http://blog.vipul.net/2008/08/24/redhat-perl-what-a-tragedy/
#http://lists.scsys.co.uk/pipermail/dbix-class/2007-October/005119.html

my $count = 50000;

use overload q(<) => sub { };
my %h;
my $i = 0;
my $t = timeit( $count,
    '$h{$i++} = bless [ ] => \'main\'; print STDERR \'.\' if $i % 1000 == 0;' );
print "\n $count loops of other code took:", timestr($t),
  " (on a normal Perl it should take significantly less than 1 second)\n";

no overload q(<);

