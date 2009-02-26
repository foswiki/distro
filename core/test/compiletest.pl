#! /usr/bin/perl -w

my $pms = `find .. -name '*.pm'`;

my @pms = split /\n/, $pms;

foreach my $pm (@pms ){
  print "PM: ".$pm."\n";
  my $res = `perl -I ../lib -I . -w -c $pm`;
  print $res;
  print "\n\n";
}
