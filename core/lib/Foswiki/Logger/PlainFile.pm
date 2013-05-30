# See bottom of file for license and copyright information
package Foswiki::Logger::PlainFile;

use strict;
use warnings;
use utf8;
use Assert;

use Foswiki::Logger                         ();
use Foswiki::Logger::EventIterator          ();
use Foswiki::Logger::AggregateEventIterator ();
use Foswiki::Logger::MergeEventIterator     ();
use Foswiki::Configure::Load;
use Fcntl qw(:flock);
our @ISA = ('Foswiki::Logger');

=begin TML

---+ package Foswiki::Logger::PlainFile

Plain file implementation of the Foswiki Logger interface. Mostly
compatible with TWiki (and Foswiki 1.0.0) log files, except that dates
are recorded using ISO format, and include the time, and it dies when
a log can't be written (rather than printing a warning).

This logger implementation maps groups of levels to a single logfile, viz.
   * =debug= messages are output to $Foswiki::cfg{Log}{Dir}/debug.log
   * =info= messages are output to $Foswiki::cfg{Log}{Dir}/events.log
   * =warning=, =error=, =critical=, =alert=, =emergency= messages are
     output to $Foswiki::cfg{Log}{Dir}/error.log.
   * =error=, =critical=, =alert=, and =emergency= messages are also
     written to standard error (the webserver log file, usually)

=cut

use Foswiki::Time ();

use constant TRACE => 0;

# Map from a log level to the root of a log file name
our %LEVEL2LOG = (
    debug     => 'debug',
    info      => 'events',
    warning   => 'error',
    error     => 'error',
    critical  => 'error',
    alert     => 'error',
    emergency => 'error'
);

our %nextCheckDue = (
    debug  => 0,
    events => 0,
    error  => 0,
);

# Symbols used so we can override during unit testing
our $dontRotate = 0;
sub _time { time() }
sub _stat { stat(@_); }

sub new {
    my $class = shift;
    return bless( { acceptsHash => 1 }, $class );
}

=begin TML

---++ ObjectMethod log($level, @fields)

See Foswiki::Logger for the interface.

=cut

sub log {
    my $this = shift;
    my $level;
    my @fields;

    # Native interface:  Convert the hash back to list format
    if ( ref( $_[0] ) eq 'HASH' ) {
        ( $level, @fields ) = Foswiki::Logger::getOldCall(@_);
        return unless defined $level;
    }
    else {
        ( $level, @fields ) = @_;
    }

    my @logs = _getLogsForLevel( [$level] );
    my $log  = shift @logs;
    my $now  = _time();
    _rotate( $LEVEL2LOG{$level}, $log, $now );
    my $time = Foswiki::Time::formatTime( $now, 'iso', 'gmtime' );

    # Unfortunate compatibility requirement; need the level, but the old
    # logfile format doesn't allow us to add fields. Since we are changing
    # the date format anyway, the least pain is to concatenate the level
    # to the date; Foswiki::Time::ParseTime can handle it, and it looks
    # OK too.
    unshift( @fields, "$time $level" );
    my $message =
      '| ' . join( ' | ', map { s/\|/&vbar;/g; $_ } @fields ) . ' |';

    my $file;
    my $mode = '>>';

    # Item10764, SMELL UNICODE: actually, perhaps we should open the stream this
    # way for any encoding, not just utf8. Babar says: check what Catalyst does.
    if (   $Foswiki::cfg{Site}{CharSet}
        && $Foswiki::cfg{Site}{CharSet} =~ /^utf-?8$/ )
    {
        $mode .= ":encoding($Foswiki::cfg{Site}{CharSet})";
    }
    elsif ( utf8::is_utf8($message) ) {
        require Encode;
        $message = Encode::encode( $Foswiki::cfg{Site}{CharSet}, $message, 0 );
    }
    if ( open( $file, $mode, $log ) ) {
        print $file "$message\n";
        close($file);
    }
    elsif ( $Foswiki::cfg{isVALID} ) {

        # Only whine if there is a known good configuration (in which case
        # $Foswiki::cfg{Log}{Dir} will be set sensibly)
        if ( !-w $log ) {
            die
"ERROR: Could not open logfile $log for write. Your admin should 'configure' now and fix the errors!\n";
        }

        # die to force the admin to get permissions correct
        die 'ERROR: Could not write ' . $message . ' to ' . "$log: $!\n";
    }
    if ( $level =~ /^(error|critical|alert|emergency)$/ ) {
        print STDERR "$message\n";
    }
}

=begin TML

---++ ObjectMethod eachEventSince($time, \@levels, $version) -> $iterator
   * =$time= - a time in the past
   * =\@levels= - log levels to return events for.  Individual level or array reference.
   * =$version= - Version 1 of API returns a hash instead of an array.

See Foswiki::Logger for the interface.

=cut

sub eachEventSince {
    my ( $this, $time, $level, $version ) = @_;

    $level = ref $level ? $level : [$level];
    my $numLevels = scalar @$level;

    my @log4level = _getLogsForLevel($level);

    # Find the year-month for the current time
    my $now         = _time();
    my $nowLogYear  = Foswiki::Time::formatTime( $now, '$year', 'servertime' );
    my $nowLogMonth = Foswiki::Time::formatTime( $now, '$mo', 'servertime' );

    # Find the year-month for the first time in the range
    my $logYear  = Foswiki::Time::formatTime( $time, '$year', 'servertime' );
    my $logMonth = Foswiki::Time::formatTime( $time, '$mo',   'servertime' );

    # Convert the requested level into a regular expression for the scan
    my $reqLevel = join( '|', @$level );
    $reqLevel = "(?:$reqLevel)";

    my @mergeIterators;

    foreach my $log (@log4level) {

        # Get the names of all the logfiles in the time range
        my @logs;
        while ( !( $logMonth == $nowLogMonth && $logYear == $nowLogYear ) ) {
            my $logfile = $log;
            my $logTime = $logYear . sprintf( "%02d", $logMonth );

            $logfile =~ s/\.log$/.$logTime/g;
            push( @logs, $logfile );
            $logMonth++;
            if ( $logMonth == 13 ) {
                $logMonth = 1;
                $logYear++;
            }
        }

        # Finally the current log
        push( @logs, $log );

        my @iterators;
        foreach my $logfile (@logs) {
            next unless -r $logfile;

            my $fh;
            if ( open( $fh, '<', $logfile ) ) {
                my $logIt =
                  new Foswiki::Logger::EventIterator( $fh, $time,
                    $reqLevel, $numLevels, $version, $logfile );
                $logIt->{logLocked} =
                  eval { flock( $fh, LOCK_SH ) }; # No error in case on non-flockable FS; eval in case flock not supported.
                                                  #   print STDERR " pushed iterator for $reqLevel \n";
                push( @iterators, $logIt );
            }
            else {

                # Would be nice to report this, but it's chicken and egg and
                # besides, empty logfiles can happen.
                print STDERR "Failed to open $logfile: $!" if (TRACE);
            }
        }

        push @mergeIterators,
          new Foswiki::Logger::AggregateEventIterator( \@iterators );
    }

    if (TRACE) {
        require Data::Dumper;
        print STDERR "Merge built for \@mergeIterators "
          . Data::Dumper::Dumper( \@mergeIterators );
    }

    return new Foswiki::Logger::MergeEventIterator( \@mergeIterators );
}

# Get the name of the log for a given reporting level
sub _getLogsForLevel {
    my $level = shift;
    my %logs;

    foreach my $lvl (@$level) {
        ASSERT( defined $LEVEL2LOG{$lvl} ) if DEBUG;
        my $log = $Foswiki::cfg{Log}{Dir} . '/' . $LEVEL2LOG{$lvl} . '.log';

      # SMELL: Expand should not be needed, except if bin/configure tries
      # to log to locations relative to $Foswiki::cfg{WorkingDir}, DataDir, etc.
      # Windows seemed to be the most difficult to fix - this was the only thing
      # that I could find that worked all the time.
        Foswiki::Configure::Load::expandValue($log);
        $logs{$log} = 1;
    }

    return ( keys %logs );
}

sub _time2month {
    my $time = shift;
    my @t    = gmtime($time);
    $t[5] += 1900;
    return sprintf( '%0.4d%0.2d', $t[5], $t[4] + 1 );
}

# See if the log needs to be rotated. If the log was last modified
# last month, we need to rotate it.
sub _rotate {
    my ( $level, $log, $now ) = @_;

    return if $dontRotate;
    return unless $level;

    # Don't bother checking if we have checked in this process already
    return if ( $now < $nextCheckDue{$level} );

    # Work out the current month
    my $curMonth = _time2month($now);

    # After this check, don't check again for a month.
    $curMonth =~ /(\d{4})(\d{2})/;
    my ( $y, $m ) = ( $1, $2 + 1 );
    if ( $m > 12 ) {
        $m = '01';
        $y++;
    }
    else {
        $m = sprintf( '%0.2d', $m );
    }
    $nextCheckDue{$level} = Foswiki::Time::parseTime("$y-$m-01");
    print STDERR "Next log check due $nextCheckDue{$level} for $level\n"
      if (TRACE);

    # If there's no existing log, there's nothing to rotate
    return unless -e $log;

    # Check when the log was last modified. If it was in the previous
    # month, if may need to be rotated.
    my @stat     = _stat($log);
    my $modMonth = _time2month( $stat[9] );
    print STDERR "compare $modMonth,  $curMonth\n" if (TRACE);
    return if ( $modMonth == $curMonth );

    # The log was last modified in a month that was not the current month.
    # Rotate older entries out into month-by-month logfiles.

    # Open the current log
    my $lf;
    unless ( open( $lf, '<', $log ) ) {
        print STDERR
          "ERROR: PlainFile Logger could not open logfile $log for read: $! \n";
        return;
    }

    my %months;

    local $/ = "\n";
    my $line;
    my $linecount;
    my $stashline = '';
    while ( $line = <$lf> ) {
        $stashline .= $line;
        my @event = split( /\s*\|\s*/, $line );
        $linecount++;
        if ( scalar(@event) > 7 ) {
            print STDERR "Bad log "
              . join( ' | ', @event )
              . " | - Skipped \n "
              if (TRACE);
            $stashline = '';
            next;
        }

        unless ( $event[1] ) {
            print STDERR
              "BAD LOGFILE LINE - skip $line - line $linecount in $log\n"
              if (TRACE);
            next;
        }

        #Item12022: parseTime bogs the CPU down here, so try a dumb regex first
        # (assuming ISO8601 format Eg. 2000-01-31T23:59:00Z). Result: 4x speedup
        my $eventMonth;
        if ( $event[1] =~ /^(\d{4})-(\d{2})-\d{2}T[0-9:]+Z\b/ ) {
            $eventMonth = $1 . $2;
        }
        else {
            print STDERR ">> Non-ISO date string encountered\n" if (TRACE);
            $eventMonth = _time2month( Foswiki::Time::parseTime( $event[1] ) );
        }

        if ( !defined $eventMonth ) {

            print STDERR
              ">> Bad time in log - skip: $line - line $linecount in $log\n"
              if (TRACE);
            next;
        }

        if ( $eventMonth < $curMonth ) {
            push( @{ $months{$eventMonth} }, $stashline );
            $stashline = '';
        }
        else {

            # Reached the start of log entries for this month
            print STDERR ">> Reached start of this month - count $linecount \n"
              if (TRACE);
            last;
        }
    }
    print STDERR " Months "
      . join( ' ', keys %months )
      . " - processed $linecount records \n"
      if (TRACE);

    if ( !scalar( keys %months ) ) {

        # no old months, we're done. The modify time on the current
        # log will be touched by the next write, so we won't attempt
        # to rotate again until next month.
        print STDERR ">> No old months\n" if (TRACE);
        close($lf);
        return;
    }

    # Sook up the rest of the current log
    $line ||= '';
    $/ = undef;
    my $curLog = $line . <$lf>;
    close($lf);

    foreach my $month ( keys %months ) {
        my $bf;
        my $backup = $log;
        $backup =~ s/log$/$month/;
        if ( -e $backup ) {
            print STDERR
"ERROR: PlainFile Logger could not create $backup - file exists\n";
            return;
        }
        unless ( open( $bf, '>', $backup ) ) {
            print STDERR
              "ERROR: PlainFile Logger could not create $backup - $! \n";
            return;
        }
        print $bf join( '', @{ $months{$month} } );
        close($bf);
    }

    # Finally rewrite the shortened current log
    unless ( open( $lf, '>', $log ) ) {
        print STDERR
"ERROR: PlainFile Logger could not open logfile $log for write: $! \n";
        return;
    }
    print $lf $curLog;
    close($lf);
}

1;
__END__
Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2013 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
