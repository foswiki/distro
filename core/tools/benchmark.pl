#!/usr/bin/perl
use strict;

# Benchmark script for TWiki
# Requires a local installation of Athens at $server/athens/ and
# $installdir/athens
# Requires installations for benchmarking at $server/version/ and
# $installdir/<version>
# where <version> is the diretcory name for that version e.g. "beta20040816"
# or "beijing"
# Requires a test page; for standard benchmarks this should be
# System.WhatIsWikiWiki.
# For benchmarking other functions, pick an appropriate page. It is best if all
# installations are running off the same data and pub areas.
# CONFIGURE THE FOLLOWING FOR YOUR LOCAL INSTALLATION

my $server     = "http://localhost";
my $installdir = "/home/twiki";
my $testpage   = "TWiki/WhatIsWikiWiki";

my $debug = 0;    # shows detailed runtimes

while ( scalar(@ARGV) ) {
    my $arg = shift @ARGV;
    if ( $arg eq "-d" ) {
        $debug = 1;
    }
    else {
        $testpage = $arg;
    }
}

print <<EOM;
TWiki core code benchmarks for $testpage.
This script is designed to benchmark the core TWiki code, eliminating any
variations caused by the web server by running the view script from the
*command-line*. All plugins are disabled and classic skin is selected.
Use ab instead to benchmark a server.

If the view script has been instrumented to benchmark internal runtime,
the seventh column gives the percentage of total runtime used to execute
the actual perl.
EOM
print
"| *Release* | *Skin* | *Plugins* | *Runs* | *Time per run* | *AthensMarks* |\n";
$testpage =~ s/\./\//g;

# Athens _must_ be run _first_ to establish the baseline.
experiment("athens");

# Now run what you want
#experiment( "beijing" );
#experiment( "cairo" );
#experiment( "MODPERL", "classic" );
#experiment( "marzia", "classic" );
experiment( "DEVELOP", "classic" );
experiment( "MAIN",    "classic" );

#experiment( "rlos", "classic" );

my $baseline;

sub experiment {
    my ( $install, $skin ) = @_;

    $skin = "" unless $skin;
    my $url = "$server/$install/bin/view/Foswiki/DefaultPreferences";
    print "*** Getting plugins for $install\n" if $debug;
    my $plugins =
`wget -O - $url 2>&1 | grep 'Currently activated plugins:' | sed -e 's/^.*: //'`;
    $plugins =~ s/<[^>]*>//g;
    $plugins =~ s/\s+//g;
    $plugins =~ s/TestFixturePlugin//;
    $plugins =~ s/SpreadSheetPlugin//;
    $plugins =~ s/CommentPlugin//;
    $plugins =~ s/EditTablePlugin//;
    $plugins =~ s/InterwikiPlugin//;
    $plugins =~ s/RenderListPlugin//;
    $plugins =~ s/SmiliesPlugin//;
    $plugins =~ s/TablePlugin//;
    $plugins =~ s/,,/,/g;
    print "*** Plugins for $install are $plugins\n" if $debug;
    $plugins = "";    # comment out to enable plugins
    my ( $runs, $elapsed, $internal ) = run( $install, $skin, $plugins );
    $baseline = $elapsed unless $baseline;
    print "| $install | $skin | $plugins | $runs | $elapsed | ";
    $baseline = $elapsed unless $baseline;
    print $baseline * 100 / $elapsed, " |";

    if ($internal) {
        my $overhead = $elapsed - $internal;
        print " ", $internal, " | $overhead |";
    }
    print "\n";
    print "*** Finished $install\n" if $debug;
    return $elapsed;
}

sub run {
    my ( $code, $skin, $plugins ) = @_;
    my $p = "?debugenableplugins=$plugins";
    if ($skin) {
        $p .= "&skin=$skin";
    }

    my $bm = "$installdir/$code/bin/view";

    if ( !-x $bm ) {
        die "No executable benchmark script in $bm";
    }

    # run once in the browser to generate the query file
    print "*** Query wget -O - $server/$code/bin/view/$testpage$p\n" if $debug;
    my $mess = `wget -O - '$server/$code/bin/benchmark/$testpage$p' 2>&1`;
    die "$mess\nFAILED $!" if ($?);

    my $total       = 0;
    my $totinternal = 0;
    my $i           = 0;
    my $cmdline = "perl -I $installdir/$code/bin -I $installdir/$code/lib $bm";
    print "*** $cmdline\n" if $debug;

    # run for 5s minimum CPU and 5 runs minimum. You can increase or
    # decrease either of these, the benchmarks will still be normalised
    # to Athens.
    print "\t" if $debug;
    while ( $total < 5 || $i < 5 ) {
        $i++;
        print "$i=" if $debug;
        my $r = `cd $installdir/$code/bin && ( time -p $bm ) 2>&1`;
        die "Compilation failed!\nRun $cmdline"
          if ( $r =~ /compilation aborted/ );
        die $r unless ( $r =~ /real\s+([\d.]+)$/m );
        my $cpu = $1;
        $total += $cpu;
        print "$cpu " if $debug;

        # Process optional internal times
        if ( $r =~ /^Internal time\s+([\d.]+)/m ) {
            $totinternal += $1;
            print " ($1) " if $debug;
        }
    }
    print " total $total\n" if $debug;

    # kill the query file
    unlink "/tmp/twiki_bm.cgi" || die "No query file";

    return ( $i, $total / $i, $totinternal / $i );
}

