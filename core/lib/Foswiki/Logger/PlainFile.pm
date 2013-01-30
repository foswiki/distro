# See bottom of file for license and copyright information
package Foswiki::Logger::PlainFile;

use strict;
use warnings;
use utf8;
use Assert;

use Foswiki::Logger ();
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

=begin TML

---++ =Foswiki::Logger::PlainFile::MergeEventIterator=
Private subclass of Foswiki::Iterator that
   * Is passed a array reference of a list of iterator arrays.
   * Scans across the list of iterators using snoopNext to find the iterator with the lowest timestamp
   * returns true to hasNext if any iterator has any records available.
   * returns the record with the lowest timestamp to the next() request.

=cut

    package Foswiki::Logger::PlainFile::MergeEventIterator;
    require Foswiki::Iterator;
    our @ISA = ('Foswiki::Iterator');

    sub new {
        my ( $class, $list ) = @_;
        my $this = bless(
            {
                Itr_list_ref => $list,
                process      => undef,
                filter       => undef,
                next         => undef,
            },
            $class
        );
        return $this;
    }

=begin TML

---+++ ObjectMethod hasNext() -> $boolean
Scans all the iterators to determine if any of them have a record available.

=cut

    sub hasNext {
        my $this = shift;

        foreach my $It ( @{ $this->{Itr_list_ref} } ) {
            return 1 if $It->hasNext();
        }
        return 0;
    }

=begin TML

---+++ ObjectMethod next() -> \$hash or @array
Snoop all of the iterators to find the lowest timestamp record, and return the
field hash, or field array, depending up on the requested API version.

=cut

    sub next {
        my $this = shift;
        my $lowIt;
        my $lowest;

        foreach my $It ( @{ $this->{Itr_list_ref} } ) {
            next unless $It->hasNext();
            my $nextRec = @{ $It->snoopNext() }[0];
            my $epoch   = $nextRec->{epoch};

            if ( !defined $lowest || $epoch <= $lowest ) {
                $lowIt  = $It;
                $lowest = $epoch;
            }
        }
        return $lowIt->next();
    }
}

{

=begin TML

---++ =Foswiki::Logger::PlainFile::AggregateEventIterator=
Private subclass of Foswiki::AggregateIterator that implements the snoopNext method

=cut

    # Private subclass of AggregateIterator that can snoop Events.
    package Foswiki::Logger::PlainFile::AggregateEventIterator;
    require Foswiki::AggregateIterator;
    our @ISA = ('Foswiki::AggregateIterator');

    sub new {
        my ( $class, $list, $unique ) = @_;
        my $this = bless(
            {
                Itr_list    => $list,
                Itr_index   => 0,
                index       => 0,
                process     => undef,
                filter      => undef,
                next        => undef,
                unique      => $unique,
                unique_hash => {}
            },
            $class
        );
        return $this;
    }

=begin TML

---+++ ObjectMethod snoopNext() -> $boolean
Return the field hash of the next availabable record.

=cut

    sub snoopNext {
        my $this = shift;
        return $this->{list}->snoopNext();
    }

}

{

=begin TML

---++ =Foswiki::Logger::PlainFile::EventIterator=
Private subclass of LineIterator that
   * Selects log records that match the requested begin time and levels.
   * reasembles divided records into a single log record
   * splits the log record into fields

=cut

    package Foswiki::Logger::PlainFile::EventIterator;
    use Fcntl qw(:flock);
    require Foswiki::LineIterator;
    our @ISA = ('Foswiki::LineIterator');

    sub new {
        my ( $class, $fh, $threshold, $level, $numLevels, $version, $filename )
          = @_;
        my $this = $class->SUPER::new($fh);
        $this->{_multilevel} = ( $numLevels > 1 );
        $this->{_api}        = $version;
        $this->{_threshold}  = $threshold;
        $this->{_reqLevel}   = $level;
        $this->{_filename}   = $filename || 'n/a';

        #  print STDERR "EventIterator created for $this->{_filename} \n";
        return $this;
    }

=begin TML

---+++ PrivateMethod DESTROY
Cleans up opened files, closes them and clears the locks.

=cut

    sub DESTROY {
        my $this = shift;
        flock( $this->{handle}, LOCK_UN )
          if ( defined $this->{logLocked} );
        close( delete $this->{handle} ) if ( defined $this->{handle} );
    }

=begin TML

---+++ ObjectMethod hasNext() -> $boolean
Reads records, reassembling them and skipping until a record qualifies per the requested time and levels.

The next matching record is parsed and saved into an instance variable until requested.

Returns true if a cached record is available.

=cut

    sub hasNext {
        my $this = shift;
        return 1 if defined $this->{_nextEvent};
        while ( $this->SUPER::hasNext() ) {
            my $ln = $this->SUPER::next();

            # Merge records until record ends in |
            while ( substr( $ln, -1 ) ne '|' && $this->SUPER::hasNext() ) {
                $ln .= "\n" . $this->SUPER::next();
            }

            my @line = split( /\s*\|\s*/, $ln );
            shift @line;    # skip the leading empty cell
            next unless scalar(@line) && defined $line[0];

            if (
                $line[0] =~ s/\s+($this->{_reqLevel})\s*$//    # test the level
                  # accept a plain 'old' format date with no level only if reading info (statistics)
                || $line[0] =~ /^\d{1,2} [a-z]{3} \d{4}/i
                && $this->{_reqLevel} =~ m/info/
              )
            {
                $this->{_level} = $1 || 'info';
                $line[0] = Foswiki::Time::parseTime( $line[0] );
                next
                  unless ( defined $line[0] )
                  ;    # Skip record if time doesn't decode.
                if ( $line[0] >= $this->{_threshold} ) {    # test the time
                    $this->{_nextEvent}  = \@line;
                    $this->{_nextParsed} = $this->formatData();
                    return 1;
                }
            }
        }
        return 0;
    }

=begin TML

---+++ ObjectMethod snoopNext() -> $hashref
Returns a hash of the fields in the next available record without
moving the record pointer.  (If the file has not yet been read, the hasNext() method is called,
which will read the file until it finds a matching record.

=cut

    sub snoopNext {
        my $this = shift;
        return $this->{_nextParsed};    # if defined $this->{_nextParsed};
                                        #return undef unless $this->hasNext();
                                        #return $this->{_nextParsed};
    }

=begin TML

---+++ ObjectMethod next() -> \$hash or @array
Returns a hash, or an array of the fields in the next available record depending on the API version.

=cut

    sub next {
        my $this = shift;
        undef $this->{_nextEvent};
        return $this->{_nextParsed}[0] if $this->{_api};
        return $this->{_nextParsed}[1];
    }

=begin TML

---++ PrivateMethod formatData($this) -> ( $hashRef, @array )

Used by the EventIterator to assemble the read log record into a hash for the Version 1
interface, or the array returned for the original Version 0 interface.

=cut

    sub formatData {
        my $this = shift;
        my $data = $this->{_nextEvent};
        my %fhash;    # returned hash of identified fields
        $fhash{level}    = $this->{_level};
        $fhash{filename} = $this->{_filename}
          if (Foswiki::Logger::PlainFile::TRACE);
        if ( $this->{_level} eq 'info' ) {
            $fhash{epoch}      = @$data[0];
            $fhash{user}       = @$data[1];
            $fhash{action}     = @$data[2];
            $fhash{webTopic}   = @$data[3];
            $fhash{extra}      = @$data[4];
            $fhash{remoteAddr} = @$data[5];
        }
        elsif ( $this->{_level} =~ m/warning|error|critical|alert|emergency/ ) {
            $fhash{epoch} = @$data[0];
            $fhash{extra} = join( ' ', @$data[ 1 .. $#$data ] );
        }
        elsif ( $this->{_level} eq 'debug' ) {
            $fhash{epoch} = @$data[0];
            $fhash{extra} = join( ' ', @$data[ 1 .. $#$data ] );
        }

        return (
            [
                \%fhash,

                (
                    [
                        $fhash{epoch},
                        $fhash{user}       || '',
                        $fhash{action}     || '',
                        $fhash{webTopic}   || '',
                        $fhash{extra}      || '',
                        $fhash{remoteAddr} || '',
                        $fhash{level},
                    ]
                )
            ]
        );
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
                  new Foswiki::Logger::PlainFile::EventIterator( $fh, $time,
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
          new Foswiki::Logger::PlainFile::AggregateEventIterator( \@iterators );
    }

    if (TRACE) {
        require Data::Dumper;
        print STDERR "Merge built for \@mergeIterators "
          . Data::Dumper::Dumper( \@mergeIterators );
    }

    return new Foswiki::Logger::PlainFile::MergeEventIterator(
        \@mergeIterators );
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
