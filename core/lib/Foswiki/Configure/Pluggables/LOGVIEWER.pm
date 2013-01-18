# -*- mode: CPerl; -*-

# See bottom of file for license and copyright information

package Foswiki::Configure::Pluggables::LOGVIEWER;

# Logviewer
#
# Instantiates items for logviewer

use strict;
use warnings;

use File::Basename;

use Foswiki::Configure::Pluggable;
our @ISA = (qw/Foswiki::Configure::Pluggable/);

use Foswiki::Configure::LOGVIEWER;

# Create built-in items if files exist (Configure always, since if it doesn't, it will.)
# Look for LOGVIEWER plugins, and activate any that are found

sub new {
    my $class = shift;
    my ( $file, $root, $settings ) = @_;

    my $fileLine = $.;
    my @items;
    my $logdir = $Foswiki::cfg{Log}{Dir};
    Foswiki::Configure::Load::expandValue($logdir);

    my $datadir = $Foswiki::cfg{DataDir};
    Foswiki::Configure::Load::expandValue($datadir);

    if ( $logdir && -d $logdir ) {
        push @items,
          Foswiki::Configure::Value->new(
            'LOGVIEWER',
            keys    => '{ConfigureGUI}{LogViewer}{Configure}',
            dir     => $logdir,
            logtype => bless( {}, $class ),
            opts    => "configure.log" . ' FEEDBACK="Configure" NOLABEL'
          );
    }

# Should be built-in, but currently only defined by Tasks Framework, so for now it's a sample plugin.
#
#    push @items, $class->logFileItem( '{ErrorFileName}', 'Errors', $logdir => 'error%DATE%.txt',
#                                                              $datadir => 'error%DATE%.txt' );

    push @items,
      $class->logFileItem(
        '{WarningFileName}', 'Warnings',
        $logdir  => 'warn%DATE%.txt',
        $datadir => 'warn%DATE%.txt'
      );
    push @items,
      $class->logFileItem(
        '{DebugFileName}', 'Debug',
        $logdir  => 'debug%DATE%.txt',
        $datadir => 'debug.txt'
      );
    push @items,
      $class->logFileItem(
        '{LogFileName}', 'Activity',
        $logdir  => 'log%DATE%.txt',
        $datadir => 'log%DATE%.txt'
      );

    # Locate any viewer plugins
    # See Pluggables/LOGVIEWER/Error.pm for a sample plugin

    my $dir = __PACKAGE__;
    $dir =~ s,::,/,g;
    foreach my $path (@INC) {
        opendir( my $dh, "$path/$dir" ) or next;
        while ( defined( my $file = readdir($dh) ) ) {
            next
              unless ( $file !~ /^\./
                && -f "$path/$dir/$file"
                && $file =~ /^([\w_-]+)\.pm$/ );

            my $module = __PACKAGE__ . "::$1";
            eval "require $module";
            die $@ if ($@);
            push @items, $module->discover( $logdir, $datadir );
        }
        closedir $dh;
    }

    unless (@items) {
        return 1;
    }

    my $section = SectionMarker->new( 0, 'Logfile Viewer' );
    $section->addToDesc('View Foswiki log files');

    unshift @items, $section, Foswiki::Configure::LOGVIEWER->new('');

    return [@items];
}

# logFileItem
#
# Creates a LOGVIEWER item if files are present
# Various versions put files in different places & with different default names.
# The %DATE% macro is a wildcard.
#
# If the configuration item is present, we believe it.
# Otherwise, the caller will have us search in the newest places first.
#
#    $keys - %cfg {key}{s}} that hold this item's full path (directory and filename)
#    $label - Label for action button
#    ($dir => $file)+ - pairs of directory, filename to search for files if %cfg item is undefined or empty
#    %DATE% will match yyyymm where it appears in filename
#
# Returns list of items.

sub logFileItem {
    my ( $class, $keys, $label ) = splice( @_, 0, 3 );

    my $logfile = Foswiki::Configure::Checker::getCfgUndefOk( undef, $keys );

    $logfile = findFiles( $logfile, @_ );

    if (@$logfile) {
        return Foswiki::Configure::Value->new(
            'LOGVIEWER',
            keys    => "{ConfigureGUI}{LogViewer}$keys",
            dir     => shift(@$logfile),
            logtype => bless( {}, $class ),
            opts => join( ',', sort @$logfile ) . " FEEDBACK='$label' NOLABEL"
        );
    }
    return ();
}

# Internal helper to find a list of matching files
#
# Stops at the first directory that contains any files.
#
# If any files are found, returns the directory followed by file names.

sub findFiles {
    my $logfile = shift;

    if ( defined $logfile && length $logfile ) {
        @_ = ( fileparse($logfile) )[ 1, 0 ];
    }
    my $files = [];
    while (@_) {
        my ( $dir, $filename ) = splice( @_, 0, 2 );
        $dir      ||= '';
        $filename ||= '';
        $filename =~ s/%DATE%/\\d{6}/g;

        opendir( my $dh, $dir ) or next;
        while ( defined( my $file = readdir($dh) ) ) {
            next if ( $file =~ /^\./ || -d "$dir/$file" );
            next unless ( $file =~ qr/$filename/ );
            push @$files, $file;
        }
        closedir($dh);
        if (@$files) {
            unshift @$files, $dir;
            last;
        }
    }
    return $files;
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
