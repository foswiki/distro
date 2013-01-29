# See bottom of file for license and copyright information
package Foswiki::Logger::Compatibility;

use strict;
use warnings;
use utf8;
use Assert;

use Foswiki::Logger ();
our @ISA = ('Foswiki::Logger');

=begin TML

---+ package Foswiki::Logger::Compatibility

Compatibility with old LocalSite.cfg settings, if user has not run
configure yet. This logger is automatically used if Foswiki senses
that the LocalSite.cfg hasn't been modified for 1.1 (configure has
not been run yet). It may also be explicitly selected in
=configure=.

Plain file implementation of the Foswiki Logger interface. Mostly
compatible with TWiki (and Foswiki 1.0.0) log files, except that dates
are recorded using ISO format, and include the time, and it dies when
a log can't be written (rather than printing a warning).

This logger implementation maps groups of levels to a single logfile, viz.
   * =debug= messages are output to $Foswiki::cfg{DebugFileName}
   * =info= messages are output to $Foswiki::cfg{LogFileName}
   * =warning=, =error=, =critical=, =alert=, =emergency= messages are
     output to $Foswiki::cfg{WarningFileName}.
   * =error=, =critical=, =alert=, and =emergency= messages are also
     written to standard error (the webserver log file, usually)

This is a copy of the Foswiki 1.0 code.

=cut

use Foswiki::Time            ();
use Foswiki::Configure::Load ();
use Fcntl qw(:flock);

# Local symbol used so we can override it during unit testing
sub _time { return time() }

sub new {
    my $class = shift;
    return bless( { acceptsHash => 1, }, $class );
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
    my $log = shift @logs;

    my $now = _time();
    $log = _expandDATE( $log, $now );
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
        die 'ERROR: Could not write ' . $message . ' to ' . "$log: $!\n";
    }
    if ( $level =~ /^(error|critical|alert|emergency)$/ ) {
        print STDERR "$message\n";
    }
}

{

=begin TML

---++ =Foswiki::Logger::Compatibility::MergeEventIterator=
Private subclass of Foswiki::Iterator that
   * Is passed a array reference of a list of iterator arrays.
   * Scans across the list of iterators using snoopNext to find the iterator with the lowest timestamp
   * returns true to hasNext if any iterator has any records available.
   * returns the record with the lowest timestamp to the next() request.

=cut

    package Foswiki::Logger::Compatibility::MergeEventIterator;
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

---++ =Foswiki::Logger::Compatibility::AggregateEventIterator=
Private subclass of Foswiki::AggregateIterator that implements the snoopNext method

=cut

    # Private subclass of AggregateIterator that can snoop Events.
    package Foswiki::Logger::Compatibility::AggregateEventIterator;
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

---++ =Foswiki::Logger::Compatibility::EventIterator=
Private subclass of LineIterator that
   * Selects log records that match the requested begin time and levels.
   * reasembles divided records into a single log record
   * splits the log record into fields

=cut

    package Foswiki::Logger::Compatibility::EventIterator;
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
          if ($Foswiki::Logger::Compatibility::TRACE);
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

---++ StaticMethod eachEventSince($time, $level) -> $iterator

See Foswiki::Logger for the interface.

This logger implementation maps groups of levels to a single logfile, viz.
   * =info= messages are output together.
   * =warning=, =error=, =critical=, =alert=, =emergency= messages are
     output together.
This method cannot 

=cut

sub eachEventSince {
    my ( $this, $time, $level, $version ) = @_;

    $level = ref $level ? $level : [$level];    # Convert level to array.
    my $numLevels = scalar @$level;

    #SMELL: Only returns a single logfile for now
    my @log4level = _getLogsForLevel($level);

    # Find the year-month for the current time
    my $now          = _time();
    my $lastLogYear  = Foswiki::Time::formatTime( $now, '$year', 'servertime' );
    my $lastLogMonth = Foswiki::Time::formatTime( $now, '$mo', 'servertime' );

    # Convert requested level to a regex
    my $reqLevel = join( '|', @$level );
    $reqLevel = qr/(?:$reqLevel)/;

    my @mergeIterators;

    foreach my $log (@log4level) {

        # Find the year-month for the first time in the range
        my $logYear  = $lastLogYear;
        my $logMonth = $lastLogMonth;
        if ( $log =~ /%DATE%/ ) {
            $logYear =
              Foswiki::Time::formatTime( $time, '$year', 'servertime' );
            $logMonth = Foswiki::Time::formatTime( $time, '$mo', 'servertime' );
        }

        # Enumerate over all the logfiles in the time range, creating an
        # iterator for each.
        my @iterators;
        while (1) {
            my $logfile = $log;
            my $logTime = $logYear . sprintf( "%02d", $logMonth );
            $logfile =~ s/%DATE%/$logTime/g;
            my $fh;
            if ( -f $logfile && open( $fh, '<', $logfile ) ) {
                my $logIt =
                  new Foswiki::Logger::Compatibility::EventIterator( $fh, $time,
                    $reqLevel, $numLevels, $version, $logfile );
                $logIt->{logLocked} =
                  eval { flock( $fh, LOCK_SH ) }; # No error in case on non-flockable FS; eval in case flock not supported.
                push( @iterators, $logIt );
            }
            else {

                # Would be nice to report this, but it's chicken and egg and
                # besides, empty logfiles can happen.
                #print STDERR "Failed to open $logfile: $!";
            }
            last if $logMonth == $lastLogMonth && $logYear == $lastLogYear;
            $logMonth++;
            if ( $logMonth == 13 ) {
                $logMonth = 1;
                $logYear++;
            }
        }
        push @mergeIterators,
          new Foswiki::Logger::Compatibility::AggregateEventIterator(
            \@iterators );
    }

    #use Data::Dumper;
    #print STDERR Data::Dumper::Dumper( \@mergeIterators );

    return new Foswiki::Logger::Compatibility::MergeEventIterator(
        \@mergeIterators );
}

# Expand %DATE% in a logfile name
sub _expandDATE {
    my ( $log, $time ) = @_;
    my $stamp = Foswiki::Time::formatTime( $time, '$year$mo', 'servertime' );
    $log =~ s/%DATE%/$stamp/go;
    return $log;
}

# Get the name of the log for a given reporting level
sub _getLogsForLevel {
    my $level = shift;
    my %logs;
    my $defaultLogDir = '';
    $defaultLogDir = "$Foswiki::cfg{DataDir}/" if $Foswiki::cfg{DataDir};
    my $log;

    foreach my $lvl (@$level) {
        if ( $lvl eq 'debug' ) {
            $log = $Foswiki::cfg{DebugFileName}
              || $defaultLogDir . 'debug%DATE%.txt';
        }
        elsif ( $lvl eq 'info' ) {
            $log = $Foswiki::cfg{LogFileName}
              || $defaultLogDir . 'log%DATE%.txt';
        }
        else {
            ASSERT( $lvl =~ /^(warning|error|critical|alert|emergency)$/ )
              if DEBUG;
            $log = $Foswiki::cfg{WarningFileName}
              || $defaultLogDir . 'warn%DATE%.txt';
        }

      # SMELL: Expand should not be needed, except if bin/configure tries
      # to log to locations relative to $Foswiki::cfg{WorkingDir}, DataDir, etc.
      # Windows seemed to be the most difficult to fix - this was the only thing
      # that I could find that worked all the time.
        Foswiki::Configure::Load::expandValue($log);    # Expand in place
        $logs{$log} = 1;
    }

    return ( keys %logs );
}

1;
__END__
Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2009 Foswiki Contributors. Foswiki Contributors
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
