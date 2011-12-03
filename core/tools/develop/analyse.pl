#!/usr/bin/perl 
# Analyse who fixed what
# Copyright (C) 2008-2010 Foswiki Contributors
# Author: Crawford Currie
use strict;
use Data::Dumper;
use List::Util;
use Time::Local;

use constant DEBUG => 0;

# Number of top contributors to acknowledge
my $TOP_N = 10;

my $REPOS      = '/home/svn/nextwiki';
my $BUGS       = '/home/foswiki.org/public_html/data/Tasks';
my $HALLOFFAME = "$BUGS/HallOfFame.txt";
my $MANIFEST   = '/home/trunk.foswiki.org/core/lib/MANIFEST';
my $svn        = '/usr/local/bin/svn';
my $svnlook    = '/usr/local/bin/svnlook';
my %monthnames = (
    jan => 0,
    feb => 1,
    mar => 2,
    apr => 3,
    may => 4,
    jun => 5,
    jul => 6,
    aug => 7,
    sep => 8,
    oct => 9,
    nov => 10,
    dec => 11
);

# First determine what releases we know about, and the checkin number
# and date for that release
my %revs;
my %dates;
foreach
  my $release ( split( "\n", `$svn ls --verbose http://svn.foswiki.org/tags` ) )
{

    if ( $release =~
        /^\s*(\d+)\s*\w+\s*(.*?)\s*FoswikiRelease(\d+)x(\d+)x(\d+)\/$/ )
    {
        my $rev   = $1;
        my $date  = $2;
        my $major = 0 + $3;
        my $minor = 0 + $4;
        my $patch = 0 + $5;
        $revs{"$major.$minor.$patch"} = $rev;
        $date =~ s/\d\d:\d\d//;
        my @d = gmtime(time);
        my $y = $d[5];          # current year

        if ( $date =~ /(\S+)\s+(\d+)(?:\s+(\d+))?/ ) {
            $date = Time::Local::timegm( 0, 0, 0, $2, $monthnames{ lc($1) },
                $3 || $y );
        }
        else {
            $date = 0;
        }
        $dates{"$major.$minor.$patch"} = $date;
    }
}

# override because tag was not created at time of release
$revs{"1.0.0"} = 1878;

# Sort revs by date
my @a = sort { $dates{$a} <=> $dates{$b} } keys(%revs);

# Most recent releases at different levels
my ( $major, $minor, $patch ) = ( '1.0.0', '1.0.0', '1.0.0' );

foreach my $release (@a) {
    if ( $release =~ /\.0\.0$/ ) {
        $major = $release;
    }
    elsif ( $release =~ /\.0$/ ) {
        $minor = $release;
    }
    else {
        $patch = $release;
    }
}

my $repositoryRevision = `$svnlook youngest $REPOS`;

my $coreExt = join( '|',
    map { $_ =~ s/^.*\///; $_ }
      split( "\n", `grep '!include ' $MANIFEST` ) );

# First load and update WhoDunnit.sid2cin, the list of checkers-in for each rev
my $maxSid = 0;
my %sid2who;
my $fh;
if ( open( $fh, '<', 'WhoDunnit.sid2cin' ) ) {
    local $/ = "\n";
    while (<$fh>) {
        if (/(\S+) (\S+)$/) {
            $sid2who{$2} = $1;
            $maxSid = $2 if $2 > $maxSid;
        }
    }
}
close($fh);
$maxSid++;
if ( $maxSid < $repositoryRevision ) {
    print "Refreshing $maxSid..$repositoryRevision\n" if DEBUG;
    open( $fh, '>>', 'WhoDunnit.sid2cin' ) || die $!;
    for ( $maxSid .. $repositoryRevision ) {
        my $who  = `$svnlook author -r $_ $REPOS`;
        my $what = `$svnlook dirs-changed -r $_ $REPOS`;
        chomp($who);
        $sid2who{$_} = $who;
        print $fh "$who $_\n";
        print "$_ $who            \r" if DEBUG;
    }
    close($fh);
}
print "\n" if DEBUG;

# Now determine which bug(s) are closed, and what checkins contributed.
# Have to do this every time, as the bugs web changes constantly
my %zappedBy;
my %reportedBy;
my %contributedBy;
my %priority;
opendir( D, $BUGS ) || die "$!";
foreach my $item (
    sort { $a <=> $b }
    grep { s/^Item(\d+)\.txt$/$1/ } readdir(D)
  )
{
    print "Item$item      \r" if DEBUG;
    my $bh;
    open( $bh, '<', "$BUGS/Item$item.txt" ) || next;
    local $/;
    my $bug = <$bh>;
    close($bh);
    my %field;
    while ( $bug =~ s/^%META:FIELD.*name="(\w+)".*value="(.*?)".*%$//m ) {
        $field{$1} = $2;
    }
    if (
        (
               $field{AppliesTo} eq "Engine"
            || $field{Extension} =~ /\b($coreExt)\b/
        )
        && $field{CurrentState} =~ /(Closed|Waiting for Release)/i
      )
    {
        foreach my $cin ( split( /\s+/, $field{Checkins} ) ) {
            $cin =~ s/^\w+://;    # remove interwiki thingy
            my $who = $sid2who{$cin};
            if ($who) {
                print "$item zapped by $who with $cin\n" if DEBUG;
                $zappedBy{$who}{$item}      = $cin;
                $contributedBy{$who}{$item} = 1;
            }
        }
        $priority{$item} = $field{Priority};
        $field{ReportedBy} =~ s/((TWiki|Foswiki):)?Main\.//g;
        $reportedBy{ $field{ReportedBy} }++;

        # Not used yet; may be used to build a table of who
        # contributed to which releases
        #if ($field{ReleasedIn} && $field{ReleasedIn} =~ /^\d/) {
        #    while ($field{ReleasedIn} !~ /\d+\.\d+\.\d+$/) {
        #        $field{ReleasedIn} .= '.0';
        #    }
        #    $unleashed{$item} = $field{ReleasedIn};
        #}
    }
    else {
        foreach my $cin ( split( /\s+/, $field{Checkins} ) ) {
            $cin =~ s/^\w+://;
            my $who = $sid2who{$cin};
            $contributedBy{$who}{$item} = $cin;
        }
    }
}
closedir(D);

my $row0 = "*Major release ($major)* ||";
my $row1 = "_Who_ | _Tasks_ |";

my $doPatch = 0;
my $doMinor = 0;

if ( $minor ne $major ) {
    $row0    = "*Minor release ($minor)* || $row0";
    $row1    = "_Who_ | _Tasks_ | $row1";
    $doMinor = 1;
}

if ( $patch ne $major && $patch ne $minor ) {
    $row0    = "*Patch release ($patch)* || $row0";
    $row1    = "_Who_ | _Tasks_ | $row1";
    $doPatch = 1;
}

my $ofh;
open( $ofh, '>', $HALLOFFAME ) || die $!;
print $ofh <<HEADING;
---+ Foswiki Subversion Activity

The following tables show contributions to the Foswiki subversion 
database. The tables are refreshed regularly
by a cron job. *THIS TOPIC IS AUTO-GENERATED*.
%TOC%
---+ Bug Crushing Summary
This table shows the top $TOP_N most active bug crushers to the
core and standard extensions in different timeframes.

The count is of the number of Closed or Waiting for Release tasks
where a checkin was done by the person (i.e. they contributed to closing 
the task) and the task was *not* an Enhancement.
%STARTINCLUDE%
| Top $TOP_N bug fixers since the last: ||||||
HEADING

my ( %majorc, %minorc, %patchc, %counts );
foreach my $zapper ( keys %zappedBy ) {
    while ( my ( $item, $cin ) = each %{ $zappedBy{$zapper} } ) {
        $counts{$zapper}++;
        next if $priority{$item} eq 'Enhancement';
        if ( $cin > $revs{$major} ) {
            if ( $cin > $revs{$minor} ) {
                if ( $cin > $revs{$patch} ) {
                    $patchc{$zapper}++;
                }
                $minorc{$zapper}++;
            }
            $majorc{$zapper}++;
        }
    }
}

print $ofh "| $row0\n| $row1\n";

my @pzs = sort { $patchc{$b} <=> $patchc{$a} } keys %patchc;
my @mzs = sort { $minorc{$b} <=> $minorc{$a} } keys %minorc;
my @Mzs = sort { $majorc{$b} <=> $majorc{$a} } keys %majorc;
for my $n ( 0 .. $TOP_N - 1 ) {

    if ($doPatch) {
        if ( $n < scalar(@pzs) && $pzs[$n] ) {
            print $ofh "| [[Main.$pzs[$n]][$pzs[$n]]] | $patchc{$pzs[$n]}";
        }
        else {
            print $ofh "| | ";
        }
    }
    if ($doMinor) {
        if ( $n < scalar(@mzs) && $mzs[$n] ) {
            print $ofh "| [[Main.$mzs[$n]][$mzs[$n]]] | $minorc{$mzs[$n]}";
        }
        else {
            print $ofh "| | ";
        }
    }
    if ( $n < scalar(@Mzs) && $Mzs[$n] ) {
        print $ofh "| [[Main.$Mzs[$n]][$Mzs[$n]]] | $majorc{$Mzs[$n]} |\n";
    }
    else {
        print $ofh "| | |\n";
    }

}
print $ofh (
    $doPatch ? '| total | ' . List::Util::sum( values(%patchc) . ' ' ) : '' )
  . ( $doMinor ? '| total | ' . List::Util::sum( values(%minorc) . ' ' ) : '' )
  . '| total | '
  . List::Util::sum( values(%majorc) ) . " |\n";

print $ofh <<STUFF;
%STOPINCLUDE%
---+ Enhancement Summary
This table shows the top $TOP_N most active enhancers to the
core and standard extensions in different timeframes.

The count is of the number of Closed or Waiting for Release tasks
where a checkin was done by the person (i.e. they contributed to closing 
the task) and the task was an Enhancement.

You have to take this with a pinch of salt. A minor spelling correction
has the same weight as a complete rewrite of the core.
STUFF

%majorc = ();
%minorc = ();
%patchc = ();
foreach my $zapper ( keys %zappedBy ) {
    while ( my ( $item, $cin ) = each %{ $zappedBy{$zapper} } ) {
        next unless $priority{$item} eq 'Enhancement';
        if ( $cin > $revs{$major} ) {
            if ( $cin > $revs{$minor} ) {
                if ( $cin > $revs{$patch} ) {
                    $patchc{$zapper}++;
                }
                $minorc{$zapper}++;
            }
            $majorc{$zapper}++;
        }
    }
}

print $ofh "| $row0\n| $row1\n";

my @pzs = sort { $patchc{$b} <=> $patchc{$a} } keys %patchc;
my @mzs = sort { $minorc{$b} <=> $minorc{$a} } keys %minorc;
my @Mzs = sort { $majorc{$b} <=> $majorc{$a} } keys %majorc;
for my $n ( 0 .. $TOP_N - 1 ) {

    if ($doPatch) {
        if ( $n < scalar(@pzs) && $pzs[$n] ) {
            print $ofh "| [[Main.$pzs[$n]][$pzs[$n]]] | $patchc{$pzs[$n]}";
        }
        else {
            print $ofh "| | ";
        }
    }
    if ($doMinor) {
        if ( $n < scalar(@mzs) && $mzs[$n] ) {
            print $ofh "| [[Main.$mzs[$n]][$mzs[$n]]] | $minorc{$mzs[$n]}";
        }
        else {
            print $ofh "| | ";
        }
    }
    if ( $n < scalar(@Mzs) && $Mzs[$n] ) {
        print $ofh "| [[Main.$Mzs[$n]][$Mzs[$n]]] | $majorc{$Mzs[$n]} |\n";
    }
    else {
        print $ofh "| | |\n";
    }

}
print $ofh (
    $doPatch ? '| total | ' . List::Util::sum( values(%patchc) . ' ' ) : '' )
  . ( $doMinor ? '| total | ' . List::Util::sum( values(%minorc) . ' ' ) : '' )
  . '| total | '
  . List::Util::sum( values(%majorc) ) . " |\n";
print $ofh "%STOPINCLUDE%\n";

print $ofh <<STUFF;
---+ The Eternal Story
Here's the full story of core contributions since the inception
of this database in October 2008.
| *Who* | *Tasks Opened* | *Tasks Closed* |
STUFF
foreach my $zapper ( sort { $counts{$b} <=> $counts{$a} } keys %counts ) {
    next unless $zapper;
    print $ofh
"| [[Main.$zapper][$zapper]] | $reportedBy{$zapper} | $counts{$zapper} |\n";
}

print $ofh <<STUFF;
---++ Contributions
Here's a full breakdown of individual contributions. The counts are the
number of items (all priorities) in the database where the person
contributed a checkin. This covers core and *all* plugins.
| *Who* | *Contributions* |
STUFF
my %dumps;
foreach my $contributor ( keys %contributedBy ) {
    $dumps{$contributor} = scalar( keys %{ $contributedBy{$contributor} } ),
      "\n";
}
foreach my $zapper ( sort { $dumps{$b} <=> $dumps{$a} } keys %dumps ) {
    next unless $zapper;
    print $ofh "| [[Main.$zapper][$zapper]] | $dumps{$zapper} |\n";
}

print $ofh <<STUFF;
---++ Everyone who ever checked in anything
For completeness, here's a full list of everyone who has ever
contributed a checkin (all time contributions).
| *Who* | *Checkins* |
STUFF
my %sins;
foreach my $who ( values %sid2who ) {
    $sins{$who}++;
}

foreach my $zapper ( sort { $sins{$b} <=> $sins{$a} } keys %sins ) {
    print $ofh "| [[Main.$zapper][$zapper]] | $sins{$zapper} |\n";
}
print $ofh '| total | ' . List::Util::sum( values(%sins) ) . " |\n";

print $ofh <<STUFF;

Subversion repository Revision: $repositoryRevision

If you want to edit the content of this topic, it's generated by a 
script
in the trunk of the subversion repository, in tools/develop/analyse.pl
STUFF

close($ofh);

