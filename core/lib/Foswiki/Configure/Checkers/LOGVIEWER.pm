# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::LOGVIEWER;

=begin TML

---+ package Foswiki::Configure::Checkers::LOGVIEWER

Foswiki::Configure::Checkers::LOGVIEWER

=cut

use strict;
use warnings;

use Fcntl qw(:flock);

use Foswiki::Configure qw/:cgi :auth/;

use Foswiki::Configure::Checker;
our @ISA = qw(Foswiki::Configure::Checker);

sub provideFeedback {
    my $this = shift;
    my ( $valobj, $button, $buttonValue ) = @_;

    my $keys = $valobj->getKeys();

    my $status  = '';
    my $content = '';

    my $dir = $this->{item}{dir};

    my $file = $query->param($keys);
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
            ( $content, $status ) = $this->$logType($log);
        }
        else {
            ( $content, $status ) =
              $this->{item}{logtype}->formatLog( $this, $log );
        }
        flock( $log, LOCK_UN ) if ($locked);
        close($log);
    }
    else {
        $status = $this->ERROR("Unable to open $file: $!");
    }

    return wantarray
      ? (
        $status . $this->FB_GUI( '{ConfigureGUI}{LogViewerWindow}', $content ),
        0
      )
      : $status;
}

# Built-in formatter for Configure's log
#
# Entries are grouped by timestamp by default.
# Optional comments delimit update groups, so they are parsed.
#
# Sequence number are useful when communicating with others.

sub displayConfigureLog {
    my $this = shift;
    my ($log) = @_;

    my $status = '';
    my $content =
"<table><tbody><tr class='configureLogHeader'><td>Seq<td>Date<td>User<td>Host<td>Item<td>New value";
    my $inwhy    = 0;
    my $sequence = 0;
    my ( $group, @group ) = ( 0, qw/configureLogDataEven configureLogDataOdd/ );
    my $lastDate = '';

    while (<$log>) {
        chomp;
        if (s/^\| //) {
            if ( $inwhy == 1 ) {
                $content .= "</pre>";
                $inwhy = 2;
            }
            $sequence++;
            my @fields = split( / ?\| ?/, $_ );
            $group ^= 1 if ( !$inwhy && $fields[0] ne $lastDate );
            $lastDate = $fields[0];
            if ( @fields >= 5 && $fields[4] eq '<--undefined-->' ) {
                @fields = map { $this->encode_entities($_) } @fields;
                $fields[4] =
                  '<span class="configureUndefinedValue">undefined</span>';
            }
            else {
                push @fields, ' ' while ( @fields < 5 );
                @fields = map { $this->encode_entities($_) } @fields;
            }
            $content .= "<tr class='$group[$group]'><td>"
              . join( '<td>', $sequence, @fields );
        }
        elsif (/^#\s+-+\s+Start of Update\s+-+$/) {
            $inwhy = 1;
            $group ^= 1;
            $content .= "<tr class='$group[$group]'><td><td colspan='99'><pre>";
        }
        elsif (/^#\s+-+\s+End of Update\s+-+$/) {
            if ( $inwhy == 1 ) {
                $content .= '(Empty comment)</pre>';
            }
            $inwhy = 0;
        }
        elsif (s/^# //) {
            $content .= $this->encode_entities($_) . "\n";
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
    my ($log) = @_;

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
            $sequence++;
            my @fields = split( / ?\| ?/, $_ );
            push @fields, ' ' while ( @fields < 2 );
            my $severity = '';
            if ( $fields[0] =~ /^([\w:-]+) (\w+)/ ) {
                $fields[0] = $1;
                $severity = $2;
            }
            splice( @fields, 1, 0, $severity );
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
            $content .= "$_\n";
        }
    }
    return ( $content, $status );
}

# Formatter for the wiki access log (log*.txt)
# | Date | user | action | topic | detail | host |

sub displayLogLog {
    my $this = shift;
    my ($log) = @_;

    my $status = '';
    my $content =
"<table><tbody><tr class='configureLogHeader'><td>Seq<td>Date<td>Severity<td>User<td>Action<td>Topic<td>Detail<td>Host";
    my ( $group, @group ) = ( 0, qw/configureLogDataEven configureLogDataOdd/ );
    my $sequence = 0;

    while (<$log>) {
        chomp;
        s/ \|$//;
        if (s/^\| //) {
            $sequence++;
            my @fields = split( / ?\| ?/, $_ );
            push @fields, ' ' while ( @fields < 6 );
            my $severity = '';
            if ( $fields[0] =~ /^([\w:-]+) (\w+)/ ) {
                $fields[0] = $1;
                $severity = $2;
            }
            splice( @fields, 1, 0, $severity );
            $content .=
"<tr class='configureStdLog $group[$group]'><td>$sequence<td>$fields[0]<td>$fields[1]<td>"
              . join( '<td>',
                map { $this->encode_entities($_) } @fields[ 2 .. $#fields ] );
            $group ^= 1;
        }
        else {
            $content .= "$_\n";
        }
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
