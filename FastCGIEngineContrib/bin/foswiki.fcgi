#!/usr/bin/env perl
# Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008-2015 Gilmar Santos Jr, jgasjr@gmail.com and Foswiki
# contributors. Foswiki contributors are listed in the AUTHORS file in the root
# of Foswiki distribution.
#
# This script is based/inspired on Catalyst framework. Refer to
#
# http://search.cpan.org/author/MRAMBERG/Catalyst-Runtime-5.7010/lib/Catalyst.pm
#
# For credits and liscence details.
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

use strict;
use warnings;

BEGIN {
    $Foswiki::cfg{Engine} = 'Foswiki::Engine::FastCGI';
    @INC = ( '.', grep { $_ ne '.' } @INC );
    delete $ENV{FOSWIKI_ACTION} if exists $ENV{FOSWIKI_ACTION};
    require 'setlib.cfg';
}

use Getopt::Long;
use Pod::Usage;
use Foswiki;
use Foswiki::UI;
use Cwd;

our ($script) = $0         =~ /^(.*)$/;
our ($dir)    = Cwd::cwd() =~ /^(.*)$/;

my @argv = @ARGV;

my ( $listen, $nproc, $max, $size, $check, $pidfile, $manager, $detach, $help, $quiet );
GetOptions(
    'listen|l=s'  => \$listen,
    'nproc|n=i'   => \$nproc,
    'max|x=i'     => \$max,
    'check|c=i'   => \$check,
    'size|s=i'    => \$size,
    'pidfile|p=s' => \$pidfile,
    'manager|M=s' => \$manager,
    'daemon|d'    => \$detach,
    'help|?'      => \$help,
    'quiet|q'     => \$quiet,
);

pod2usage(1) if $help;

# untaint
if (defined $pidfile) {
  $pidfile =~ /^(.*)$/ and $pidfile = $1;
}

@ARGV = @argv;
undef @argv;

$Foswiki::engine->run(
    $listen,
    {
        nproc   => $nproc,
        pidfile => $pidfile,
        manager => $manager,
        detach  => $detach,
        quiet   => $quiet,
        max     => $max,
        size    => $size,
        check   => $check,
    }
);

__END__

=head1 SYNOPSIS

foswiki.fcgi [options]

  Options:
    -l --listen     Socket to listen on
    -n --nproc      Number of backends to use, defaults to 1
    -p --pidfile    File used to write pid to
    -M --manager    FCGI manager class
    -x --max        Maximum requests served per server instance
    -c --check      Number of requests when to check the size of the server
    -s --size       Maximum memory size of a server before being recycled
    -d --daemon     Detach from terminal and keeps running as a daemon
    -q --quiet      Disable notification messages
    -? --help       Display this help and exits

  Note:
    FCGI manager class defaults to Foswiki::Engine::FastCGI::ProcManager, a
    wrapper around FCGI::ProcManager to enable automatic reload of 
    configurations if changed. If you provide another class, probably you'll 
    need to restart FastCGI processes manually.

=cut
