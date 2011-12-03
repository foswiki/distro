#! /usr/bin/perl -w
## Copyright 2004 Sven Dowideit.  All Rights Reserved.
## License: GPL
#please output results and errors to the dir specified on the command line

use strict;
use LWP;

my $URL = "http://ntwiki.ethermage.net/~develop/cgi-bin";

#my $URL = "http://localhost/DEVELOP/bin";

my $outputDir;

if (@ARGV) {
    $outputDir = shift @ARGV;
}
else {
    print "please provide an outputDir\n";
    exit(1);
}

my $outputUrl = $outputDir;

$outputUrl =~ s|(.*)(/pub/.*)|http://ntwiki.ethermage.net/~develop$2|;

my $args = join( " ", @ARGV );

my $now = `date +'%Y%m%d.%H%M%S'`;
chomp($now);

print "<HTML><TITLE>Running tests</TITLE><BODY>\n";

unless ( $args =~ /\bnodocs\b/ ) {
    print "<h1>Update docs</h1><pre>";
    print `cd ../tools && perl gendocs.pl`;
    print "</pre>";
}

unless ( $args =~ /\bnocompile\b/ ) {
    print "<h1>Compile Tests</h1>\n";
    my $pms  = `find ../lib -name '*.pm'`;
    my $rose = "";
    foreach my $pm ( split /\n/, $pms ) {
        my $mess = `perl -I ../lib -I . -w -c $pm 2>&1`;
        $mess =~ s/^.*Subroutine .*? redefined at .*?$//gmi;
        $mess =~ s/^.*Name ".*?" used only once: possible typo.*$//gm;
        $mess =~ s/^.*?syntax OK$//m;
        if ( $mess =~ /\S/ ) {
            $rose .= "<tr align='top'><td>$pm</td><td>\n";
            $rose .= "<pre>$mess</pre></td></tr>\n";
        }
    }
    $rose =~ s/\n+/\n/sg;
    if ($rose) {
        print "<table border='1'>$rose</table\n";
    }
    else {
        print "No compile errors\n";
    }
}

unless ( $args =~ /\bnounit\b/ ) {
    print "<h1>Unit Tests</h1>\n";
    print
"Errors will be in <a href=\"$outputUrl/unit$now\">$outputDir/unit$now</a>\n<pre>\n";
    execute(
"cd unit ; perl ../bin/TestRunner.pl TWikiUnitTestSuite.pm > $outputDir/unit$now ; cd .."
    ) or die $!;
    print "</pre>\n";
}

if ( $args =~ /\btestcases\b/ ) {
    print "<h1>Automated Test Cases</h1>\n";
    my $userAgent = LWP::UserAgent->new();
    $userAgent->agent("ntwiki Test Script ");

    opendir( TESTS, "../data/TestCases" ) || die "Can't get testcases: $!";
    foreach my $test ( grep { /^TestCaseAuto.*\.txt$/ } readdir TESTS ) {
        $test =~ s/\.txt//;
        my $result = $userAgent->get(
"$URL/view/TestCases/$test?test=compare&debugenableplugins=TestFixturePlugin"
        );

        print "$test ";
        if ( $result->content() =~ /ALL TESTS PASSED/ ) {
            print "<font color='green'>PASSED</font>";
        }
        else {
            print "<font color='red'><b>FAILED</b></font>";

            #print $result->content();
        }
        print "<br>\n";
    }
    closedir(TESTS);
}

print "</BODY></HTML>";

sub execute {
    my ($cmd) = @_;
    chomp( my @output = `$cmd` );
    print "$?: $cmd\n", join( "\n", @output );
    return not $?;
}

exit 0;
