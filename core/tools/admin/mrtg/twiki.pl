#!/usr/bin/perl
#!/opt/csw/bin/perl
# twiki.pl ####################################################
#
# MRTG Performance Enhancements v1.0.2
#
#   this script grabs the last 5 minutes from the twiki log file
#   and returns the number of requests in that period
#
#   TODO: remove the hard coded 5 minutes and use mrtglib..
#   TODO: add a command line param list to select what variables you want to see
#
# Copyright 2005:
# Sven Dowideit, SvenDowideit@home.org.au
#####################################################################
use strict;

#settings that should be moved to the mrtg cfg file, and read using mrtglib?
my $numberOfMinutesToScan = 5;    #mrtg will not allow less than 5...
my $logFileTemplate = '/home/twiki/data/log%DATE%.txt';

#####  Subroutines  #####

sub analyseLogFile {
    my ( $logFile, $pos, $timeRegex ) = @_;

    my $linesProcessed = 0;

    die 'cannot find: ' . $logFile
      unless ( -e $logFile );     #change this to throw, so caller can continue
    open( logFile, '<', $logFile );
    if ( $pos->{$logFile} ) {
        seek( logFile, $pos->{$logFile}, 0 );
    }
    my @logLines = <logFile>;
    $pos->{$logFile} = tell(logFile);
    close(logFile);

    foreach my $line (@logLines) {
        $linesProcessed++;
        my ( $before, $date, $user, $oper, $topic, $browser, $host ) =
          split( /\|/, $line );
        if ( $date =~ /$timeRegex/ ) {
            $pos->{total_number_of_requests}++;

            if ( $user =~ /WikiGuest/ ) {
                $pos->{total_number_of_WikiGuest_requests}++;
            }
            if ( $oper =~ /view/ ) {
                $pos->{total_number_of_views}++;
            }
            else {
                $pos->{total_number_of_nonviews}++;
            }

            if ( $oper =~ /edit/ ) {
                $pos->{total_number_of_edits}++;
            }
        }
    }
}

#####  Main Program Begins Here  ######

#open the twiki log file for this month, and report on size?
my $systemTime = time();
my $log        = $logFileTemplate;
my $previousLog;
my $logTime = formatTime( $systemTime, '$year$mo', 'servertime' );
$log =~ s/%DATE%/$logTime/go;
my $total_number_of_requests           = 0;
my $total_number_of_views              = 0;
my $total_number_of_WikiGuest_requests = 0;

my %pos;
if ( -e 'twiki_seek.cfg' ) {

    #TODO: gonna need a lock file too
    open( seekFile, '<', 'twiki_seek.cfg' );
    while (<seekFile>) {
        if (/^(.*): (\d*)$/) {
            $pos{$1} = $2;
        }
    }
    close(seekFile);
}

if ( $systemTime - $pos{lastScanTime} > ( $numberOfMinutesToScan * 60 ) ) {

    #time to scan again

    $pos{lastScanTime} = $systemTime;
    my $timeRegex = '(?:';
    for ( my $count = 0 ; $count < $numberOfMinutesToScan ; $count++ ) {
        my $time = formatTime( $systemTime - ( $count * 60 ),
            '$day $mon $year - $hour:$min', 'servertime' );
        $timeRegex = $timeRegex . ' ' . $time . ' |';

        $time =
          formatTime( $systemTime - ( $count * 60 ), '$year$mo', 'servertime' );
        if ( $time ne $logTime ) {
            $previousLog = $logFileTemplate;
            $log =~ s/%DATE%/$time/go;
        }

    }
    $timeRegex = $timeRegex . '^$)';

    #reset the important vars
    $pos{total_number_of_WikiGuest_requests} = 0;
    $pos{total_number_of_requests}           = 0;
    $pos{total_number_of_views}              = 0;
    $pos{total_number_of_nonviews}           = 0;
    $pos{total_number_of_edits}              = 0;

    analyseLogFile( $log, \%pos, $timeRegex );
    if ($previousLog) {
        analyseLogFile( $previousLog, \%pos, $timeRegex );
    }
    open( seekFile, '>', 'twiki_seek.cfg' );
    foreach my $fileName ( keys %pos ) {
        print seekFile $fileName . ': ' . $pos{$fileName} . "\n";
    }
    close(seekFile);
}
else {

    #use the stored values from the twiki_seek file

}

#number of WikiGuest requests
print $pos{total_number_of_WikiGuest_requests} . "\n";

#number of registered user requests
print( $pos{total_number_of_requests} -
      $pos{total_number_of_WikiGuest_requests} );
print "\n";

#total number of views
print $pos{total_number_of_views} . "\n";

#total number of non-views
print $pos{total_number_of_requests} - $pos{total_number_of_views} . "\n";

# =========================

=pod
---++ sub formatTime ($epochSeconds, $formatString, $outputTimeZone) ==> $value
| $epochSeconds | epochSecs GMT |
| $formatString | twiki time date format |
| $outputTimeZone | timezone to display. (not sure this will work)(gmtime or servertime) |

from TWiki Cairo Codebase

=cut

sub formatTime {
    my ( $epochSeconds, $formatString, $outputTimeZone ) = @_;
    my $value = $epochSeconds;

    # use default TWiki format "31 Dec 1999 - 23:59" unless specified
    $formatString = "\$day \$month \$year - \$hour:\$min"
      unless ($formatString);

    #    my $outputTimeZone = $displayTimeValues unless( $outputTimeZone );

    my ( $sec, $min, $hour, $day, $mon, $year, $wday ) =
      localtime($epochSeconds);

    #standard twiki date time formats
    if ( $formatString =~ /rcs/i ) {

        # RCS format, example: "2001/12/31 23:59:59"
        $formatString = "\$year/\$mo/\$day \$hour:\$min:\$sec";
    }
    elsif ( $formatString =~ /http|email/i ) {

        # HTTP header format, e.g. "Thu, 23 Jul 1998 07:21:56 EST"
        # - based on RFC 2616/1123 and HTTP::Date; also used
        # by Foswiki::Net for Date header in emails.
        $formatString = "\$wday, \$day \$month \$year \$hour:\$min:\$sec \$tz";
    }
    elsif ( $formatString =~ /iso/i ) {

        # ISO Format, see spec at http://www.w3.org/TR/NOTE-datetime
        # e.g. "2002-12-31T19:30Z"
        $formatString = "\$year-\$mo-\$dayT\$hour:\$min";
        if ( $outputTimeZone eq "gmtime" ) {
            $formatString = $formatString . "Z";
        }
        else {

#TODO:            $formatString = $formatString.  # TZD  = time zone designator (Z or +hh:mm or -hh:mm)
        }
    }

    $value = $formatString;
    $value =~ s/\$sec[o]?[n]?[d]?[s]?/sprintf("%.2u",$sec)/geoi;
    $value =~ s/\$min[u]?[t]?[e]?[s]?/sprintf("%.2u",$min)/geoi;
    $value =~ s/\$hou[r]?[s]?/sprintf("%.2u",$hour)/geoi;
    $value =~ s/\$day/sprintf("%.2u",$day)/geoi;
    my @weekDay = ( "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" );
    $value =~ s/\$wday/$weekDay[$wday]/geoi;
    my @isoMonth = (
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    );
    $value =~ s/\$mon[t]?[h]?/$isoMonth[$mon]/goi;
    $value =~ s/\$mo/sprintf("%.2u",$mon+1)/geoi;
    $value =~ s/\$yea[r]?/sprintf("%.4u",$year+1900)/geoi;
    $value =~ s/\$ye/sprintf("%.2u",$year%100)/geoi;

#TODO: how do we get the different timezone strings (and when we add usertime, then what?)
    my $tz_str = "GMT";
    $tz_str = "Local" if ( $outputTimeZone eq "servertime" );
    $value =~ s/\$tz/$tz_str/geoi;

    return $value;
}
