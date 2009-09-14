# See bottom of file for license and copyright information
package Foswiki::Logger::PlainFile;
use base 'Foswiki::Logger';

=begin TML

---+ package Foswiki::Logger::PlainFile

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

=cut

use strict;

use Assert;

use Foswiki::Time;
use Foswiki::ListIterator;

# Local symbol used so we can override it during unit testing
sub _time { return time() }

sub new {
    my $class = shift;
    return bless({}, $class);
}

=begin TML

---++ ObjectMethod log($level, @fields)

See Foswiki::Logger for the interface.

=cut

sub log {
    my ( $this, $level, @fields ) = @_;

    my $log = _getLogForLevel($level);
    my $now = _time();
    $log = _expandDATE($log, $now);
    my $time = Foswiki::Time::formatTime( $now, 'iso', 'gmtime' );
    # Unfortunate compatibility requirement; need the level, but the old
    # logfile format doesn't allow us to add fields. Since we are changing
    # the date format anyway, the least pain is to concatenate the level
    # to the date; Foswiki::Time::ParseTime can handle it, and it looks
    # OK too.
    unshift(@fields, "$time $level");
    my $message = join(' | ', map { s/\|/&vbar;/g; $_ } @fields);
    my $file;
    if ( open( $file, '>>', $log ) ) {
        print $file "| $message |\n";
        close($file);
    }
    else {
        die 'ERROR: Could not write "' . $message . '" to ' . "$log: $!\n";
    }
    if ($level =~ /^(error|critical|alert|emergency)$/) {
        print STDERR "$message\n";
    }
}

{
    # Private subclass of LineIterator that splits events into fields
    package Foswiki::Logger::EventIterator;
    use base 'Foswiki::LineIterator';

    sub new {
        my ($class, $fh, $threshold, $level) = @_;
        my $this = $class->SUPER::new($fh);
        $this->{_threshold} = $threshold;
        $this->{_level} = $level;
        return $this;
    }

    sub hasNext {
        my $this = shift;
        return 1 if defined $this->{_nextEvent};
        while ($this->SUPER::hasNext()) {
            my @line = split(/\s*\|\s*/, $this->SUPER::next());
            shift @line; # skip the leading empty cell
            if ($line[0] =~ s/\s+$this->{_level}\s*$// # test the level
                # accept a plain 'old' format date with no level only if reading info (statistics)
		|| $line[0] =~ /^\d{1,2} [a-z]{3} \d{4}/i && $this->{_level} eq 'info') {
                $line[0] = Foswiki::Time::parseTime($line[0]);
                if ($line[0] >= $this->{_threshold}) { # test the time
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
    my ($this, $time, $level) = @_;
    my $log = _getLogForLevel($level);

    # Find the year-month for the current time
    my $now = _time();
    my $lastLogYear = Foswiki::Time::formatTime($now, '$year', 'servertime');
    my $lastLogMonth = Foswiki::Time::formatTime($now, '$mo', 'servertime');

    # Find the year-month for the first time in the range
    my $logYear = $lastLogYear;
    my $logMonth = $lastLogMonth;
    if ($log =~ /%DATE%/) {
        $logYear = Foswiki::Time::formatTime($time, '$year', 'servertime');
        $logMonth = Foswiki::Time::formatTime($time, '$mo', 'servertime');
    }

    # Enumerate over all the logfiles in the time range, creating an
    # iterator for each.
    my @iterators;
    while (1) {
        my $logfile = $log;
        my $logTime = $logYear.sprintf("%02d", $logMonth);
        $logfile =~ s/%DATE%/$logTime/g;
        my $fh;
        if (open($fh, '<', $logfile)) {
            push(@iterators,
                 new Foswiki::Logger::EventIterator($fh, $time, $level));
        } else {
            # Would be nice to report this, but it's chicken and egg and
            # besides, empty logfiles can happen.
            #print STDERR "Failed to open $logfile: $!";
        }
        last if $logMonth == $lastLogMonth && $logYear == $lastLogYear;
        $logMonth++;
        if ($logMonth == 13) {
            $logMonth = 1;
            $logYear++;
        }
    }
    return new Foswiki::ListIterator(\@iterators) if scalar(@iterators) == 0;
    return $iterators[0] if scalar(@iterators) == 1;
    return new Foswiki::AggregateIterator(\@iterators);
}

# Expand %DATE% in a logfile name
sub _expandDATE {
    my ($log, $time) = @_;
    my $stamp = Foswiki::Time::formatTime( $time, '$year$mo', 'servertime' );
    $log =~ s/%DATE%/$stamp/go;
    return $log;
}

# Get the name of the log for a given reporting level
sub _getLogForLevel {
    my $level = shift;
    my $log;
    if ($level eq 'debug') {
        $log = $Foswiki::cfg{DebugFileName};
    } elsif ($level eq 'info') {
        $log = $Foswiki::cfg{LogFileName};
    } else {
        ASSERT($level =~ /^(warning|error|critical|alert|emergency)$/)
          if DEBUG;
        $log = $Foswiki::cfg{WarningFileName};
    }
    return $log;
}

1;
__END__
# Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008-2009 Foswiki Contributors. Foswiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.
