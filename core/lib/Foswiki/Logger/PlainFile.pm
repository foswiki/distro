# See bottom of file for license and copyright information
package Foswiki::Logger::PlainFile::EventIterator;
use strict;
use warnings;
use Assert;

use Fcntl qw(:flock);

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

# Internal class for Logfile iterators.
# So we don't break encapsulation of file handles.  Open / Close in same file.
our @ISA = qw/Foswiki::Iterator::EventIterator/;

# # Object destruction
# # Release locks and file
sub DESTROY {
    my $this = shift;
    flock( $this->{handle}, LOCK_UN )
      if ( defined $this->{logLocked} );
    close( delete $this->{handle} ) if ( defined $this->{handle} );
}

package Foswiki::Logger::PlainFile;

use strict;
use warnings;
use Assert;

use Foswiki::Logger                           ();
use Foswiki::Iterator::EventIterator          ();
use Foswiki::Iterator::AggregateEventIterator ();
use Foswiki::Iterator::MergeEventIterator     ();
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

use Foswiki::Time qw(-nofoswiki);

use constant TRACE => 0;

# Map from a log level to the root of a log file name
our %LEVEL2LOG = (
    debug     => 'debug',
    info      => 'events',
    notice    => 'configure',
    warning   => 'error',
    error     => 'error',
    critical  => 'error',
    alert     => 'error',
    emergency => 'error'
);

our %nextCheckDue = (
    configure => 0,
    debug     => 0,
    events    => 0,
    error     => 0,
);

# Symbols used so we can override during unit testing
our $dontRotate = 0;
sub _time { time() }
sub _stat { @_ ? stat( $_[0] ) : stat() }

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

    my $now  = _time();
    my @logs = _getLogsForLevel( [$level] );
    my $log  = shift @logs;
    _rotate( $LEVEL2LOG{$level}, $log, $now );
    my $time = Foswiki::Time::formatTime( $now, 'iso', 'servertime' );

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

    if ( open( $file, $mode, $log ) ) {
        binmode $file, ":encoding(utf-8)";
        _lock($file);
        print $file "$message\n";
        close($file);
    }
    elsif ( $Foswiki::cfg{isVALID} ) {

        use filetest 'access';    # Try to get more meaningful diagnostics.

        # Only whine if there is a known good configuration (in which case
        # $Foswiki::cfg{Log}{Dir} will be set sensibly)
        if ( !-w $log ) {
            die
"ERROR: Could not open logfile $log for write. Your admin should repair file or directory access permissions and/or ownership!\n";
        }

        # die to force the admin to get permissions correct
        die 'ERROR: Could not write ' . $message . ' to ' . "$log: $!\n";
    }
    if ( $level =~ m/^(error|critical|alert|emergency)$/ ) {
        print STDERR "$message\n";
    }
}

sub _lock {    # borrowed from Log::Dispatch::FileRotate, Thanks!
    my $fh = shift;
    eval { flock( $fh, LOCK_EX ) }; # Ignore lock errors,   not all platforms support flock
                                    # Make sure we are at the EOF
    seek( $fh, 0, 2 );
    return 1;
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

    my @log4level = _getLogsForLevel($level);

    # Find the year-month for the current time
    my $now         = _time();
    my $nowLogYear  = Foswiki::Time::formatTime( $now, '$year', 'servertime' );
    my $nowLogMonth = Foswiki::Time::formatTime( $now, '$mo', 'servertime' );

    # Find the year-month for the first time in the range
    my $logYear  = Foswiki::Time::formatTime( $time, '$year', 'servertime' );
    my $logMonth = Foswiki::Time::formatTime( $time, '$mo',   'servertime' );

    print STDERR "Scanning $logYear:$logMonth thru $nowLogYear:$nowLogMonth\n"
      if (TRACE);

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
            if ( open( $fh, '<:encoding(utf-8)', $logfile ) ) {
                my $logIt =
                  new Foswiki::Logger::PlainFile::EventIterator( $fh, $time,
                    $reqLevel, $version, $logfile );
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
          new Foswiki::Iterator::AggregateEventIterator( \@iterators );
    }

    if (TRACE) {
        require Data::Dumper;
        print STDERR "Merge built for \@mergeIterators "
          . Data::Dumper::Dumper( \@mergeIterators );
    }

    return new Foswiki::Iterator::MergeEventIterator( \@mergeIterators );
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

# See if the log needs to be rotated. If the log was last modified
# last month, we need to rotate it.
sub _rotate {
    my ( $level, $log, $now ) = @_;

    return if $dontRotate;
    return unless $level;

    # Don't bother checking if we have checked in this process already
    return if ( $now < $nextCheckDue{$level} );

    # Work out the current month
    my $curMonth = Foswiki::Time::formatTime( $now, '$year$mo', 'servertime' );
    print STDERR "Current MONTH = $curMonth\n" if (TRACE);

    # After this check, don't check again for a month.
    $curMonth =~ m/(\d{4})(\d{2})/;
    my ( $y, $m ) = ( $1, $2 + 1 );
    if ( $m > 12 ) {
        $m = '01';
        $y++;
    }
    else {
        $m = sprintf( '%0.2d', $m );
    }
    $nextCheckDue{$level} =
      Foswiki::Time::parseTime( "$y-$m-01", 1 );    # use local (server) time.
    print STDERR
      "Next log check due $nextCheckDue{$level} for $level, now: $now\n"
      if (TRACE);

    # If there's no existing log, there's nothing to rotate
    return unless -e $log;

    # Check when the log was last modified. If it was in the previous
    # month, if may need to be rotated.
    my @stat = _stat($log);
    my $modMonth =
      Foswiki::Time::formatTime( $stat[9], '$year$mo', 'servertime' );
    print STDERR "compare $modMonth,  $curMonth\n" if (TRACE);
    return if ( $modMonth == $curMonth );

    my $lockfile;
    unless ( open( $lockfile, '>', $log . 'LOCK' ) ) {
        print STDERR "ERROR: PlainFile Logger could not open $log.LOCK: $! \n";
        return;
    }
    flock( $lockfile, LOCK_EX );

    my $newname = $log;
    $newname =~ s/log$/$modMonth/;
    print STDERR "Renaming from $log to $newname \n" if (TRACE);

    unless ( -e $newname ) {
        open( my $lf, '>>', $log );
        _lock($lf);
        rename $log, $newname;
        close($lf);
        unlink $log . 'LOCK';
    }
    else {
        print STDERR "ROTATE SKIPPED - prior log ($log) exists\n";
        unlink $log . 'LOCK';
    }

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
