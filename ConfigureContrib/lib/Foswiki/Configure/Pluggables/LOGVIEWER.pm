# See bottom of file for license and copyright information

package Foswiki::Configure::Pluggables::LOGVIEWER;

# Logviewer
#
# Instantiates items for logviewer
#
# SMELL: This is a heavily GUI-oriented component and should not be
# present in the item tree. Need to work out a way to post-process
# pluggables so this code doesn't pollute.
#
use strict;
use warnings;

use File::Basename ();

use Foswiki::Configure::Value ();
use Foswiki::Configure::Load  ();

#
# ---++ Logfile Viewer
# View log files
# *LOGVIEWER*
#
# **STRING H**
# Default severity selection for log viewer - not stored
#$Foswiki::cfg{ConfigureGUI}{LogViewer}{SystemLogs} = [ qw/debug info warning error critical alert emergency/ ];
# Default max records to display in log viewer - not stored
# **NUMBER H**
#$Foswiki::cfg{ConfigureGUI}{LogViewer}{RecordLimit} = 200;

our @SEVERITIES =
  ( 'debug', 'info', 'warning', 'error', 'critical', 'alert', 'emergency' );

my $stdLogHelp = <<HELP;
To view entries from this log, select the filename here, and click
the action button.<br />To limit the entries displayed to a range
of dates/times, enter the limits of the range below.
HELP

sub construct {
    my ( $settings, $file, $line ) = @_;

    my $logdir = $Foswiki::cfg{Log}{Dir};
    Foswiki::Configure::Load::expandValue($logdir);

    my $datadir = $Foswiki::cfg{DataDir};
    Foswiki::Configure::Load::expandValue($datadir);

    if ( $logdir && -d $logdir ) {
        push(
            @$settings,
            Foswiki::Configure::Value->new(
                'LOGVIEWER',
                keys    => '{ConfigureGUI}{LogViewer}{Configure}',
                dir     => $logdir,
                default => '0',
                _logtype    => bless( {}, __PACKAGE__ ),    # SMELL: NASTY!
                select_from => ["configure.log"],
                FEEDBACK    => [
                    {
                        label => 'Configure',
                        title => "View entries from Configure log"
                    }
                ],
                desc =>
'Configure maintains a log of configuration changes.<br />$stdLogHelp'
            )
        );
    }

    my %files;

    $files{$logdir}  = 'error%DATE%.txt' if $logdir;
    $files{$datadir} = 'error%DATE%.txt' if $datadir;
    _addLOGVIEWERValue(
        $settings,
        keys  => '{ConfigureGUI}{LogViewer}{ErrorFileName}',
        label => 'Errors',
        files => {%files},
        desc  => "Foswiki error log<br />$stdLogHelp"
    );

    $files{$logdir}  = 'warn%DATE%.txt' if $logdir;
    $files{$datadir} = 'warn%DATE%.txt' if $datadir;
    _addLOGVIEWERValue(
        $settings,
        keys  => '{ConfigureGUI}{LogViewer}{WarningFileName}',
        label => 'Warnings',
        files => {%files},
        desc  => "Foswiki warnings log<br />$stdLogHelp}"
    );

    $files{$logdir}  = 'debug%DATE%.txt' if $logdir;
    $files{$datadir} = 'debug%DATE%.txt' if $datadir;
    _addLOGVIEWERValue(
        $settings,
        keys  => '{ConfigureGUI}{LogViewer}{DebugFileName}',
        label => 'Debug',
        desc  => "Foswiki debug log<br />$stdLogHelp",
        files => {%files}
    );

    $files{$logdir}  = 'log%DATE%.txt' if $logdir;
    $files{$datadir} = 'log%DATE%.txt' if $datadir;
    _addLOGVIEWERValue(
        $settings,
        keys  => '{ConfigureGUI}{LogViewer}{LogFileName}',
        label => 'Activity',
        desc  => "Foswiki activity log<br />$stdLogHelp",
        files => {%files}
    );

    push(
        @$settings,
        Foswiki::Configure::Value->new(
            'SELECTLOG',
            keys     => "{ConfigureGUI}{LogViewer}{SystemLogs}",
            default  => "'$SEVERITIES[0]'",
            _logtype => bless( {}, __PACKAGE__ ),
            LABEL    => undef,
            FEEDBACK => [
                {
                    label  => 'System',
                    button => 2,
                    title  => 'View entries from Foswiki system logs'
                }
            ],
            MULTIPLE => scalar @SEVERITIES,
            opts     => join( ',', @SEVERITIES ),
            desc => "Foswiki maintains event and error logs.<br />$stdLogHelp"
        )
    );

    my $stdTimeHelp = <<HELP;
Recommended date format is dd-mmm-yyyy.<br />
Time is 24-hour UTC.  Enter date and time as dd-mmm-yyyy HH:MM:SS<br />
Validated input will be redisplayed in ISO format.
HELP

    push(
        @$settings,
        Foswiki::Configure::Value->new(
            'DATE',
            keys        => '{ConfigureGUI}{LogViewer}{StartTime}',
            UNDEFINEDOK => 1,
            LABEL       => 'Start time (UTC)',
            opts        => "FEEDBACK=AUTO CHECK='nullok zone:utc'",
            desc        => <<HELP ) );
Date or Date and time of the first entry to be displayed.<br />
Default is first entry in log.<br />
$stdTimeHelp
HELP

    push(
        @$settings,
        Foswiki::Configure::Value->new(
            'DATE',
            keys        => '{ConfigureGUI}{LogViewer}{EndTime}',
            LABEL       => 'End time (UTC)',
            UNDEFINEDOK => 1,
            opts        => "FEEDBACK=AUTO CHECK='nullok zone:utc' ",
            desc        => <<HELP ) );
Date or Date and time of the last entry to be displayed.<br />
Default is last entry in log.<br />
$stdTimeHelp
HELP
}

# _addLOGVIEWERValue
#
# Adds a LOGVIEWER Foswiki::Configure::Value to @$settings if
# files matching the spec are present in disc.
# Various versions put files in different places & with different
# default names. The %DATE% macro is a wildcard.
#
# If the configuration item is present, we believe it.
# Otherwise, the caller will have us search in the newest places first.
#
# Non-standard Value attributes
#   * =_logtype= - package of log viewer - SMELL: NASTY!
#   * =files= - { $dir => $file)+ } - pairs of directory, filename to
#    search for files if %cfg item is undefined or empty
#    %DATE% will match yyyymm where it appears in filename
#
# Returns list of items.

sub _addLOGVIEWERValue {
    my ( $settings, %params ) = @_;

    my $logfile = '$Foswiki::cfg' . $params{keys};
    Foswiki::Configure::Load::expandValue( $logfile, 1 );
    return unless $params{files};

    my ( $dir, @known ) = _findFiles( $logfile, %{ $params{files} } );

    return unless (@known);

    delete $params{files};
    $params{_logtype} = bless( {}, __PACKAGE__ );
    push(
        @$settings,
        Foswiki::Configure::Value->new(
            'LOGVIEWER',
            %params,
            opts => join( ',', sort @known )
              . " NOLABEL FEEDBACK='$params{label}'"
        )
    );
}

# Given an optional known directory for log files and a list of
# possible places they may be found, search for xisting logfiles.
# Stops at the first directory that contains any files.
#
# If any files are found, returns the directory name followed by
# a list of file names.
#
# For example,
# _findFiles('/var/log/keepyuppy.log',
#    '/var/snoop' => 'error%DATE%.txt', '/var/glum' => 'error%DATE%.log' )
# will look in /var/log for keepyuppy.log and no further, while
# _findFiles(undef,
#    '/var/snoop' => 'error%DATE%.txt', '/var/glum' => 'error%DATE%.txt' )
# will look in /var/snoop and then /var/glam for files mathcing the pattern
# error%DATE%.txt / .log
sub _findFiles {
    my ( $logfile, %patterns ) = @_;

    if ($logfile) {

        # Override other params
        my ( $name, $path, $suffix ) = File::Basename::fileparse($logfile);
        %patterns = ( $path => $name );
    }

    my @files;
    while ( my ( $dir, $pattern ) = each %patterns ) {
        $pattern ||= '';
        $pattern =~ s/%DATE%/\\d{6}/g;
        my $dh;
        opendir( $dh, $dir ) or next;
        while ( defined( my $file = readdir($dh) ) ) {
            next if ( $file =~ /^\./ || -d "$dir/$file" );
            next unless ( $file =~ qr/$pattern/ );
            push @files, $file;
        }
        closedir($dh);
        if (@files) {
            unshift( @files, $dir );
            last;
        }
    }

    return @files;
}

1;
__END__

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2014 Foswiki Contributors. Foswiki Contributors
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
