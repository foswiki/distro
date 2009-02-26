#!/usr/bin/perl 
# Analyse who fixed what
use strict;
use Data::Dumper;
use List::Util;

my $REPOS = '/home/svn/nextwiki';
my $BUGS = '/home/foswiki.org/trunk/core/data/Tasks';
my $MANIFEST = '/home/trunk.foswiki.org/core/lib/MANIFEST';
my $svn = '/usr/local/bin/svn';
my $svnlook = '/usr/local/bin/svnlook';

# First determine what releases we know about, and the checkin number for that release
my $verbose = 0;
my $releases;
foreach my $release (
    split("\n",
          `$svn ls --verbose http://svn.foswiki.org/tags`)) {
    if ($release =~ s/^\s*(\d+).*Release(\d\d)x(\d\d)x(\d\d)\/$//) {
        $releases->{0+$2}->{0+$3}->{0+$4} = $1;
    }
}
#over-rides because tags were not created at time of release
$releases->{1}->{0}->{0} = 1878;

my @a = sort { $a <=> $b } keys(%$releases);
my $major = pop(@a) || 0;
my @a = sort { $a <=> $b } keys(%{$releases->{$major}});
my $minor = pop(@a) || 0;
my @a = sort { $a <=> $b } keys(%{$releases->{$major}->{$minor}});
my $patch = pop(@a) || 0;
my $patchcin = $releases->{$major}->{$minor}->{$patch};
my $minorcin = $releases->{$major}->{$minor}->{0};
my $majorcin = $releases->{$major}->{0}->{0};
my $repositoryRevision = `$svnlook youngest $REPOS`;

print "Last release $major($majorcin).$minor($minorcin).$patch($patchcin)\n" if $verbose;

my $coreExt = join ('|',
                    map { $_ =~ s/^.*\///; $_ }
                      split("\n", `grep '!include ' $MANIFEST`));
print "SCAN $coreExt" if $verbose;

# First load and update WhoDunnit.sid2cin, the list of checkers-in for each rev
my $topSid = `$svnlook youngest $REPOS`;
my $maxSid = 0;
my %sid2who;
if (open(F, "<WhoDunnit.sid2cin")) {
    local $/ = "\n";
    while (<F>) {
        if (/(\S+) (\S+)$/) {
            $sid2who{$2} = $1;
            $maxSid = $2 if $2 > $maxSid;
        }
    }
}
close(F);
$maxSid++;
if ($maxSid < $topSid) {
    print "Refreshing $maxSid..$topSid\n" if $verbose;
    open(F, ">>WhoDunnit.sid2cin") || die $!;
    for ($maxSid..$topSid) {
        my $who = `$svnlook author -r $_ $REPOS`;
        chomp($who);
        $sid2who{$_} = $who;
        print F "$who $_\n";
        print "$_ $who            \r" if $verbose;
    }
    close(F);
}
print "\n" if $verbose;

# Now determine which bug(s) are closed, and what checkins contributed.
# Have to do this every time, as the bugs web changes constantly
my %zappedBy;
my %reportedBy;
my %contributedBy;
opendir(D, $BUGS) || die "$!";
foreach my $item (sort { $a <=> $b }
                      grep { s/^Item(\d+)\.txt$/$1/ }
                               readdir(D)) {
    print "Item$item      \r" if $verbose;
    open(F, "<$BUGS/Item$item.txt") || next;
    local $/ = undef;
    my $bug = <F>;
    close(F);
    my %field;
    while ($bug =~ s/^%META:FIELD.*name="(\w+)".*value="(.*?)".*%$//m) {
        $field{$1} = $2;
    }
    if (($field{AppliesTo} eq "Engine" ||
         $field{Extension} =~ /\b($coreExt)\b/)
        && $field{CurrentState} =~ /(Closed|Waiting for Release)/i) {
        foreach my $cin (split(/\s+/, $field{Checkins})) {
            $cin =~ s/^\w+://; # remove interwiki thingy
            my $who = $sid2who{$cin};
            if ($who) {
                print "$item zapped by $who with $cin\n" if $verbose;
                $zappedBy{$who}{$item} = $cin;
                $contributedBy{$who}{$item} = 1;
            }
        }
        if ($field{ReportedBy} =~ /Main\.(.*)$/) {
            $reportedBy{$1}++;
        }
    } else {
        foreach my $cin (split(/\s+/, $field{Checkins})) {
            $cin =~ s/^\w+://;
            my $who = $sid2who{$cin};
            $contributedBy{$who}{$item} = $cin;
        }
    }

}
closedir(D);
my (%majorc, %minorc, %patchc, %counts);
foreach my $zapper (keys %zappedBy) {
    while (my ($item, $cin) = each %{$zappedBy{$zapper}}) {
        if ($cin > $majorcin) {
            if ($cin > $minorcin) {
                if ($cin > $patchcin) {
                    $patchc{$zapper}++;
                }
                $minorc{$zapper}++;
            }
            $majorc{$zapper}++;
        }
        $counts{$zapper}++;
    }
}
print "\n" if $verbose;
open(F, ">$BUGS/HallOfFame.txt") || die $!;
print F <<HEADING;
The following tables show contributions to the core.
The tables are refreshed regularly
by a cron job. *THIS TOPIC IS AUTO_GENERATED*. Do not attempt to edit it!
%TOC%
---+ Task Closing Summary
This table shows the top 5 most active contributors to the
core and standard extensions in different timeframes. Bear in mind that
this only counts contributions that are checked in to subversion.

The count is of the number of Closed or Waiting for Release tasks
where a checkin
was done by the person (i.e. they contributed to closing the task).
%STARTINCLUDE%
| Top 5 task closers since the last: ||||||
| *Patch release ($patch)* || *Minor release ($minor)* || *Major release ($major)* ||
| _Who_ | _Tasks_ | _Who_ | _Tasks_ | _Who_ | _Tasks_ |
HEADING
my @pzs = sort { $patchc{$b} <=> $patchc{$a} } keys %patchc;
my @mzs = sort { $minorc{$b} <=> $minorc{$a} } keys %minorc;
my @Mzs = sort { $majorc{$b} <=> $majorc{$a} } keys %majorc;
for my $n (0..4) {
    if ($n < scalar(@pzs) && $pzs[$n]) {
        print F "| [[Main.$pzs[$n]][$pzs[$n]]] | $patchc{$pzs[$n]} ";
    } else {
        print F "| | ";
    }
    if ($n < scalar(@mzs) && $mzs[$n]) {
        print F "| [[Main.$mzs[$n]][$mzs[$n]]] | $minorc{$mzs[$n]} ";
    } else {
        print F "| | ";
    }
    if ($n < scalar(@Mzs) && $Mzs[$n]) {
        print F "| [[Main.$Mzs[$n]][$Mzs[$n]]] | $majorc{$Mzs[$n]} |\n";
    } else {
        print F "| | |\n";
    }

}
print F '| total | '.
	List::Util::sum(values(%patchc)).
	' | total | '.
	List::Util::sum(values(%minorc)).
	' | total | '.
	List::Util::sum(values(%majorc)).
	" |\n";
print F "%STOPINCLUDE%\n";

print F <<STUFF;
---+ Checkins Full Story
Here's the full story of core contributions since the inception
of this database.
| *Who* | *Tasks Opened* | *Tasks Closed* |
STUFF
foreach my $zapper (sort { $counts{$b} <=> $counts{$a} } keys %counts) {
    next unless $zapper;
    print F "| [[Main.$zapper][$zapper]] | $reportedBy{$zapper} | $counts{$zapper} |\n";
}

print F <<STUFF;
---+ Contributions
Here's a full breakdown of individual contributions. The counts are the number
of items (all priorities) in the database where the person contributed a
checkin. This covers core and all plugins.
| *Who* | *Contributions* |
STUFF
my %dumps;
foreach my $contributor (keys %contributedBy) {
    $dumps{$contributor} = scalar(keys %{$contributedBy{$contributor}}), "\n";
}
foreach my $zapper (sort { $dumps{$b} <=> $dumps{$a} } keys %dumps) {
    next unless $zapper;
    print F "| [[Main.$zapper][$zapper]] | $dumps{$zapper} |\n";
}

print F <<STUFF;
---+ Everyone who ever checked in anything
For completeness, here's a full list of everyone who has ever
contributed a checkin (all time contributions).
| *Who* | *Checkins* |
STUFF
my %sins;
foreach my $who (values %sid2who) {
    $sins{$who}++;
}

foreach my $zapper (sort { $sins{$b} <=> $sins{$a} } keys %sins) {
    print F "| [[Main.$zapper][$zapper]] | $sins{$zapper} |\n";
}
print F '| total | '.List::Util::sum(values(%sins))." |\n";

print F "\n\nSubversion repository Revision: $repositoryRevision\n";

close(F);
