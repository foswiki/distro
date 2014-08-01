# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::LOGVIEWER;

=begin TML

---+ package Foswiki::Configure::Checkers::LOGVIEWER

Foswiki::Configure::Checkers::LOGVIEWER

=cut

use strict;
use warnings;

use Fcntl qw(:flock);

use Foswiki::Time qw/-nofoswiki/;

BEGIN {
    die "Bad version of Foswiki::Time" if ( exists $INC{'Foswiki.pm'} );
}

use Foswiki::Configure qw/:cgi :auth/;

use Foswiki::Configure::Checker;
our @ISA = qw(Foswiki::Configure::Checker);

sub provideFeedback {
    my $this = shift;
    my ( $valobj, $button, $buttonValue ) = @_;

    my $keys = $valobj->{keys};

    my $status  = '';
    my $content = '';

    my $startTime = $query->param('{ConfigureGUI}{LogViewer}{StartTime}');
    $startTime = Foswiki::Time::parseTime($startTime) if ( defined $startTime );

    my $endTime = $query->param('{ConfigureGUI}{LogViewer}{EndTime}');
    $endTime = Foswiki::Time::parseTime($endTime) if ( defined $endTime );

    if ( $button == 1 ) {
        ( $content, $status ) =
          $this->plainViewer( $keys, $startTime, $endTime );
    }
    elsif ( $button == 2 ) {
        ( $content, $status ) =
          $this->systemViewer( $keys, $startTime, $endTime );
    }
    else {
        $status = $this->ERROR("Unknown button $button");
    }

    return wantarray
      ? (
        $status . $this->FB_GUI( '{ConfigureGUI}{LogViewerWindow}', $content ),
        0
      )
      : $status;
}

# Viewer dispatch for plain text files

sub plainViewer {
    my $this = shift;
    my ( $keys, $startTime, $endTime ) = @_;

    my $status  = '';
    my $content = '';
    my $dir     = $this->{item}{dir};
    my $file    = $query->param($keys);
    defined $file or die "Feedback wthout value for LOGVIEW $keys\n";

    # Last key less 'FileName' constructs the name of built-in formatters
    # Plugin formatters use "formatLog"

    $keys =~ /\{(\w+)\}$/;
    my $logType = $1;
    $logType =~ s/FileName$//;

    if ( open( my $log, '<', "$dir/$file" ) ) {
        my $locked = flock( $log, LOCK_SH );

        # builtin or plugin formatter

        if ( eval "defined &display${logType}Log" ) {
            $logType = "display${logType}Log";
            ( $content, $status ) =
              $this->$logType( $log, $startTime, $endTime );
        }
        else {
            ( $content, $status ) =
              $this->{item}->{logtype}
              ->formatLog( $this, $log, $startTime, $endTime );
        }
        flock( $log, LOCK_UN ) if ($locked);
        close($log);
    }
    else {
        $status = $this->ERROR("Unable to open $file: $!");
    }

    return ( $content, $status );
}

# Built-in formatter for Configure's log
#
# Entries are grouped by timestamp by default.
# Optional comments delimit update groups, so they are parsed.
#
# Sequence number are useful when communicating with others.

sub displayConfigureLog {
    my $this = shift;
    my ( $log, $startTime, $endTime ) = @_;

    my $status = '';
    my $content =
"<table><tbody><tr class='configureLogHeader'><td>Seq<td>Date<td>User<td>Host<td>Item<td>New value";
    my $inwhy    = 0;
    my $sequence = 0;
    my ( $group, @group ) = ( 0, qw/configureLogDataEven configureLogDataOdd/ );
    my $lastDate = '';
    my $why;

    while (<$log>) {
        chomp;
        if (s/^\| //) {
            my @fields = split( / ?\| ?/, $_ );
            if ( defined $startTime || defined $endTime ) {
                my $thisTime = $fields[0];
                if ( $thisTime =~
                    /^\w+ (\w+)  ?(\d+) (\d\d:\d\d:\d\d) (\d{4})$/ )
                {
                    $thisTime = Foswiki::Time::parseTime("$2-$1-$4 $3");

                    if ( defined $thisTime ) {
                        next
                          if ( defined $startTime && $thisTime < $startTime );
                        last if ( defined $endTime && $thisTime > $endTime );
                    }
                }
            }
            if ( $inwhy == 1 ) {
                $group ^= 1;
                $content .=
"<tr class='$group[$group]'><td><td colspan='99'><pre>$why</pre>";
                $inwhy = 2;
            }
            $lastDate = $fields[0];
            $sequence++;
            $group ^= 1 if ( !$inwhy && $fields[0] ne $lastDate );
            if ( @fields >= 5 && $fields[4] eq '<--undefined-->' ) {
                @fields = map { $this->encode_entities($_) } @fields;
                $fields[4] =
                  '<span class="configureUndefinedValue">undefined</span>';
            }
            else {
                push @fields, ' ' while ( @fields < 5 );
                @fields = map { $this->encode_entities($_) } @fields;
            }
            $fields[0] =~ s/ /&nbsp;/g;
            $content .= "<tr class='$group[$group]'><td>"
              . join( '<td>', $sequence, @fields );
        }
        elsif (/^#\s+-+\s+Start of Update\s+-+$/) {
            $inwhy = 1;
            $why   = '';
        }
        elsif (/^#\s+-+\s+End of Update\s+-+$/) {
            $inwhy = 0;
        }
        elsif (s/^# //) {
            $why .= $this->encode_entities($_) . "\n";
        }
        else {
            $status .= $this->ERROR("Invalid format in log at line $.");
        }
    }
    return ( $content, $status );
}

# Standard log formats are merged into displayStandardLog

sub displayDebugLog {
    goto &displayStandardLog;
}

sub displayWarningLog {
    goto &displayStandardLog;
}

# Format a log using the standard format, which is
#
# | Date | text - possibly multi-line
# Date can have severity attached
# Sequence is provided for ease of communication

sub displayStandardLog {
    my $this = shift;
    my ( $log, $startTime, $endTime ) = @_;

    my $status = '';
    my $content =
"<table><tbody><tr class='configureLogHeader'><td>Seq<td>Date<td>Severity<td>Event";

    my ( $group, @group ) = ( 0, qw/configureLogDataEven configureLogDataOdd/ );
    my $sequence = 0;
    my $open;

    while (<$log>) {
        chomp;
        s/ \|$//;
        if (s/^\| //) {
            $content .= '</pre>' if ($open);
            my @fields = split( / ?\| ?/, $_ );
            push @fields, ' ' while ( @fields < 2 );
            my $severity = '';
            if ( $fields[0] =~ /^([\w:-]+) (\w+)/ ) {
                $fields[0] = $1;
                $severity = $2;
            }
            if ( defined $startTime || defined $endTime ) {
                my $thisTime = Foswiki::Time::parseTime( $fields[0] );

                if ( defined $thisTime ) {
                    $open = 0;
                    next if ( defined $startTime && $thisTime < $startTime );
                    last if ( defined $endTime   && $thisTime > $endTime );
                }
            }
            $sequence++;
            splice( @fields, 1, 0, $severity );
            $fields[0] =~ s/ /&nbsp;/g;
            $content .=
"<tr class='configureStdLog $group[$group]'><td>$sequence<td>$fields[0]<td>$fields[1]<td>"
              . join( '<td>',
                map { '<pre>' . $this->encode_entities($_) }
                  @fields[ 2 .. $#fields ] )
              . "\n";
            $open = 1;
            $group ^= 1;
        }
        else {
            $content .= $this->encode_entities($_) . "\n" if ($open);
        }
    }
    return ( $content, $status );
}

# Formatter for the wiki access log (log*.txt)
# | Date | user | action | topic | detail | host |

sub displayLogLog {
    my $this = shift;
    my ( $log, $startTime, $endTime ) = @_;

    my $status = '';
    my $content =
"<table><tbody><tr class='configureLogHeader'><td>Seq<td>Date<td>Severity<td>User<td>Action<td>Topic<td>Detail<td>Host";
    my ( $group, @group ) = ( 0, qw/configureLogDataEven configureLogDataOdd/ );
    my $sequence = 0;
    my $open;

    while (<$log>) {
        chomp;
        s/ \|$//;
        if (s/^\| //) {
            my @fields = split( / ?\| ?/, $_ );
            push @fields, ' ' while ( @fields < 6 );
            my $severity = '';
            if ( $fields[0] =~ /^([\w:-]+) (\w+)/ ) {
                $fields[0] = $1;
                $severity = $2;
            }
            if ( defined $startTime || defined $endTime ) {
                my $thisTime = Foswiki::Time::parseTime( $fields[0] );

                if ( defined $thisTime ) {
                    $open = 0;
                    next if ( defined $startTime && $thisTime < $startTime );
                    last if ( defined $endTime   && $thisTime > $endTime );
                }
            }
            $sequence++;
            splice( @fields, 1, 0, $severity );
            $fields[0] =~ s/ /&nbsp;/g;
            $content .=
"<tr class='configureStdLog $group[$group]'><td>$sequence<td>$fields[0]<td>$fields[1]<td>"
              . join( '<td>',
                map { $this->encode_entities($_) } @fields[ 2 .. $#fields ] );
            $open = 1;
            $group ^= 1;
        }
        else {
            $content .= encode_entities($_) . "\n" if ($open);
        }
    }

    return ( $content, $status );
}

# Viewer for files using the system Logger interface

sub systemViewer {
    my $this = shift;
    my ( $keys, $startTime, $endTime ) = @_;

    my $status = '';
    my $content =
"<table><tbody><tr class='configureLogHeader'><td>Seq<td>Date<td>Severity<td colspan='99'>Event Detail";
    my ( $group, @group ) = ( 0, qw/configureLogDataEven configureLogDataOdd/ );
    my $sequence = 0;

    my $severities = [ $query->param($keys) ];

    my $logger = $Foswiki::cfg{Log}{Implementation};
    unless ($logger) {
        return ( '', $this->ERROR("No Foswiki logger implemented") );
    }

    eval "require $logger;";
    return ( '',
        $this->ERROR("Unable to activate Foswiki logger $logger: $@\n") )
      if ($@);
    $logger = $logger->new();

    my $version = 1;
    my $it = $logger->eachEventSince( $startTime || 0, $severities, $version );
    while ( $it->hasNext ) {
        my $event = $it->next;

        if ( $version == 0 ) {

          # Each event is returned as a reference to an array. The elements are:
          #   0 date of the event (seconds since the epoch)
          #   1 login name of the user who triggered the event
          #   2 the event name (the $action passed to =writeEvent=)
          #   3 the Web.Topic that the event applied to
          #   4 Extras (the $extra passed to =writeEvent=)
          #   5 The IP address that was the source of the event (if known)
          #   6 Severity

            if ( defined $endTime ) {
                my $thisTime = $event->[0];

                last
                  if ( defined $thisTime
                    && defined $endTime
                    && $thisTime > $endTime );
            }

            $sequence++;
            my $displayTime =
              Foswiki::Time::formatTime( $event->[0],
                '$year-$mo-$day&nbsp;$hours:$minutes:$seconds&nbsp;$tz' );
            my @fields = @$event;

            # Guess the data format.
            # For unstructured logs, 2 fields returned will be time and
            # message text. Othewise, should match documentation.

            # discard time, put severity first & detect unstructured log data
            if ( @fields >= 7 ) {
                $fields[0] = splice( @fields, 6, 1 ) || '';
                if (
                    join( '', @fields[ 1, 2, 3, 5 ], @fields[ 6 .. $#fields ] )
                    eq '' )
                {
                    @fields = @fields[ 0, 4 ];
                }
            }
            else {
                $fields[0] = '';
            }
            if ( @fields == 2 ) {
                $content .=
qq{<tr class='configureStdLog $group[$group]'><td>$sequence<td>$displayTime<td>$fields[0]<td>};
                if ( $fields[1] =~ /\n/ ) {
                    $content .=
                      '<pre>' . $this->encode_entities( $fields[1] ) . '</pre>';
                }
                else {
                    $content .= $this->encode_entities( $fields[1] );
                }
            }
            else {
                push @fields, '' while ( @fields < 6 );
                $content .=
"<tr class='configureStdLog $group[$group]'><td>$sequence<td>$displayTime<td>"
                  . join(
                    '<td>',
                    map {
                            /\n/
                          ? '<pre>' . $this->encode_entities($_) . '</pre>'
                          : $this->encode_entities($_)
                    } @fields
                  );
            }
        }
        else {
            my @fieldOrder = qw/action webTopic extra user remoteAddr/;
            my %labels     = (
                action     => 'Event name',
                extra      => 'Detail',
                remoteAddr => 'Host',
                user       => 'Username',
                webTopic   => 'Topic',
            );

            my $thisTime = delete $event->{epoch};
            if ( defined $endTime ) {
                last
                  if ( defined $thisTime
                    && defined $endTime
                    && $thisTime > $endTime );
            }
            ++$sequence;
            my $displayTime =
              Foswiki::Time::formatTime( $thisTime,
                '$year-$mo-$day&nbsp;$hours:$minutes:$seconds&nbsp;$tz' );

            $content .=
"<tr class='configureStdLog $group[$group]'><td>$sequence<td>$displayTime<td>"
              . ( delete $event->{level} )
              . "<td><table class='configureLogDetail'><tbody>";
            foreach my $name (@fieldOrder) {
                next unless ( exists $event->{$name} );

                my $value = delete $event->{$name};
                if ( defined $value ) {
                    my $multi = $value =~ /\n/;
                    $content .=
                        "<tr><td>$labels{$name}<td>"
                      . ( $multi ? '<pre>' : '' )
                      . $this->encode_entities($value)
                      . ( $multi ? '</pre>' : '' );
                }
                else {
                    $content .=
qq{<tr><td>$labels{$name}<td><span class="configureUndefinedValue">undefined</span>};
                }
            }
            foreach my $name ( sort keys %$event ) {
                my $value = $event->{$name};
                if ( defined $value ) {
                    my $multi = $value =~ /\n/;
                    $content .=
                        "<tr><td>"
                      . ucfirst($name) . "<td>"
                      . ( $multi ? '<pre>' : '' )
                      . $this->encode_entities($value)
                      . ( $multi ? '</pre>' : '' );
                }
                else {
                    $content .=
                        qq{<tr><td>}
                      . ucfirst($name)
                      . qq{<td><span class="configureUndefinedValue">undefined</span>};
                }
            }
            $content .= "</table>";
        }
        $group ^= 1;
    }

    return ( $content, $status );
}

# Encode 'dangerous' HTML characters from log files.

sub encode_entities {
    my $this = shift;
    my ($string) = @_;

    $string =~ s/([<>&'"[:cntrl:]])/sprintf( '&#x%X;', ord $1 )/ge;

    return $string;
}
1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2013 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2000-2006 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root
of this distribution. NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
