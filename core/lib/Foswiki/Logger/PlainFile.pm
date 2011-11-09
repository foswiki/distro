# See bottom of file for license and copyright information
package Foswiki::Logger::PlainFile;

use strict;
use warnings;
use utf8;
use Assert;

use Foswiki::Logger ();
use Foswiki::Configure::Load;
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

use Foswiki::Time         ();
use Foswiki::ListIterator ();

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

our $nextCheckDue = 0;

# Symbols used so we can override during unit testing
our $dontRotate = 0;
sub _time { time() }
sub _stat { stat(@_); }

sub new {
    my $class = shift;
    return bless( {}, $class );
}

=begin TML

---++ ObjectMethod log($level, @fields)

See Foswiki::Logger for the interface.

=cut

sub log {
    my ( $this, $level, @fields ) = @_;

    my $log = _getLogForLevel($level);
    my $now = _time();
    _rotate( $log, $now );
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
    else {
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

{

    # Private subclass of LineIterator that splits events into fields
    package Foswiki::Logger::PlainFile::EventIterator;
    require Foswiki::LineIterator;
    @Foswiki::Logger::PlainFile::EventIterator::ISA = ('Foswiki::LineIterator');

    sub new {
        my ( $class, $fh, $threshold, $level ) = @_;
        my $this = $class->SUPER::new($fh);
        $this->{_threshold} = $threshold;
        $this->{_level}     = $level;
        return $this;
    }

    sub hasNext {
        my $this = shift;
        return 1 if defined $this->{_nextEvent};
        while ( $this->SUPER::hasNext() ) {
            my @line = split( /\s*\|\s*/, $this->SUPER::next() );
            shift @line;    # skip the leading empty cell
            if (
                $line[0] =~ s/\s+$this->{_level}\s*$//    # test the level
                  # accept a plain 'old' format date with no level only if reading info (statistics)
                || $line[0] =~ /^\d{1,2} [a-z]{3} \d{4}/i
                && $this->{_level} eq 'info'
              )
            {
                $line[0] = Foswiki::Time::parseTime( $line[0] );
                if ( $line[0] >= $this->{_threshold} ) {    # test the time
                    $this->{_nextEvent} = \@line;
                    return 1;
                }
            }
        }
        return 0;
    }

    sub next {
        my $this = shift;
        my $data = $this->{_nextEvent};
        undef $this->{_nextEvent};
        return $data;
    }
}

=begin TML

---++ StaticMethod eachEventSince($time, $level) -> $iterator

See Foswiki::Logger for the interface.

This logger implementation maps groups of levels to a single logfile, viz.
   * =info= messages are output together.
   * =warning=, =error=, =critical=, =alert=, =emergency= messages are
     output together.
This method cannot 

=cut

sub eachEventSince {
    my ( $this, $time, $level ) = @_;
    my $log = _getLogForLevel($level);

    # Find the year-month for the current time
    my $now         = _time();
    my $nowLogYear  = Foswiki::Time::formatTime( $now, '$year', 'servertime' );
    my $nowLogMonth = Foswiki::Time::formatTime( $now, '$mo', 'servertime' );

    # Find the year-month for the first time in the range
    my $logYear  = Foswiki::Time::formatTime( $time, '$year', 'servertime' );
    my $logMonth = Foswiki::Time::formatTime( $time, '$mo',   'servertime' );

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
            push(
                @iterators,
                new Foswiki::Logger::PlainFile::EventIterator(
                    $fh, $time, $level
                )
            );
        }
        else {

            # Would be nice to report this, but it's chicken and egg and
            # besides, empty logfiles can happen.
            #print STDERR "Failed to open $logfile: $!";
        }
    }
    return new Foswiki::ListIterator( \@iterators ) if scalar(@iterators) == 0;
    return $iterators[0] if scalar(@iterators) == 1;
    return new Foswiki::AggregateIterator( \@iterators );
}

# Get the name of the log for a given reporting level
sub _getLogForLevel {
    my $level = shift;
    ASSERT( defined $LEVEL2LOG{$level} ) if DEBUG;
    my $log = $Foswiki::cfg{Log}{Dir} . '/' . $LEVEL2LOG{$level} . '.log';

    # SMELL: Expand should not be needed, except if bin/configure tries
    # to log to locations relative to $Foswiki::cfg{WorkingDir}, DataDir, etc.
    # Windows seemed to be the most difficult to fix - this was the only thing
    # that I could find that worked all the time.
    Foswiki::Configure::Load::expandValue($log);
    return $log;
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
    my ( $log, $now ) = @_;

    return if $dontRotate;

    # Don't bother checking if we have checked in this process already
    return if ( $now < $nextCheckDue );

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
    $nextCheckDue = Foswiki::Time::parseTime("$y-$m-01");

    # If there's no existing log, there's nothing to rotate
    return unless -e $log;

    # Check when the log was last modified. If it was in the previous
    # month, if may need to be rotated.
    my @stat     = _stat($log);
    my $modMonth = _time2month( $stat[9] );
    return if ( $modMonth == $curMonth );

    # The log was last modified in a month that was not the current month.
    # Rotate older entries out into month-by-month logfiles.

    #print STDERR ">> Checking $log entries\n";

    # Open the current log
    my $lf;
    return unless open( $lf, '<', $log );

    # Analyse the log and partition the lines into month groups
    my %months;

    local $/ = "\n";
    my $line;
    while ( $line = <$lf> ) {
        my @event = split( /\s*\|\s*/, $line );
        last unless $event[1];
        my $eventTime = Foswiki::Time::parseTime( $event[1] );

        if ( !$eventTime ) {

            #print STDERR ">> Bad time in log: $line\n";
            close($lf);
            return;
        }

        my $eventMonth = _time2month($eventTime);

        if ( $eventMonth < $curMonth ) {
            push( @{ $months{$eventMonth} }, $line );
        }
        else {

            # Reached the start of log entries for this month
            last;
        }
    }

    if ( !scalar( keys %months ) ) {

        # no old months, we're done. The modify time on the current
        # log will be touched by the next write, so we won't attempt
        # to rotate again until next month (or $forceRotate is set).
        #print STDERR ">> No old months\n";
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
        if ( -e $backup || !open( $bf, '>', $backup ) ) {

            #print STDERR ">> Could not create $backup\n";
            return;
        }
        print $bf join( '', @{ $months{$month} } );
        close($bf);
    }

    # Finally rewrite the shortened current log
    return unless open( $lf, '>', $log );
    print $lf $curLog;
    close($lf);
}

1;
__END__
Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
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
