# -*- mode: CPerl; -*-

# See bottom of file for license and copyright information

package Foswiki::Configure::Pluggables::LOGVIEWER::Error;

# Logviewer plugin
#
# Instantiates logviewer item for Error log.
# Provides formatter method for log data

use strict;
use warnings;

use File::Basename;

use Foswiki::Configure::Pluggables::LOGVIEWER;
use Foswiki::Configure::Checker;

our @ISA =
  (qw/Foswiki::Configure::Pluggables::LOGVIEWER Foswiki::Configure::Checker/);

# Discover logfiles handled by this LOGVIEWER Plugin.
#
# $logdir, $datadir are the paths to the logfile and data directories.
#
# return list of LOGVIEWER items - logFileItem will do all the work.
#                                  $keys, $ButtonLabel, directory => filename list used if $keys is empty.
#                                  Optional item help.
# list may be empty.

sub discover {
    my $class = shift;
    my ( $logdir, $datadir ) = @_;

    my @items;
    push @items,
      $class->logFileItem(
        '{ErrorFileName}', 'Errors',
        $logdir  => 'error%DATE%.txt',
        $datadir => 'error%DATE%.txt',
qq(Foswiki error log<br />$Foswiki::Configure::Pluggables::LOGVIEWER::stdLogHelp)
      );

    return @items;
}

# Format a logfile
#  $this = Checker object for the item
#  $log = open log file handle to be formatted
# returns (
#           $content - formatted file - usually a table but can be any HTML
#           $errors - for button's status window, e.g. format errors in data.
#         )

sub formatLog {
    my $logtype = shift;
    my $this    = shift;

    return $this->displayStandardLog(@_);
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
