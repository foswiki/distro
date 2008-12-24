# FastCGI Runtime Engine of Foswiki - The Free and Open Source Wiki,
# http://foswiki.org/
#
# Copyright (C) 2008 Gilmar Santos Jr, jgasjr@gmail.com and Foswiki
# contributors. Foswiki contributors are listed in the AUTHORS file in the root
# of Foswiki distribution.
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
#------------------------------------------------------------------------------
# Parts of this package are based on Net::Server::Daemonize, which is
#  Copyright (C) 2001-2007
#
#    Jeremy Howard
#    j+daemonize@howard.fm
#
#    Paul Seamons
#    paul@seamons.com
#    http://seamons.com/
#
# For more details:
# http://search.cpan.org/perldoc?Net::Server::Daemonize
#------------------------------------------------------------------------------
# As per the GPL, removal of this notice is prohibited.

=begin TML

---+!! package Foswiki::Engine::FastCGI

Class that implements FastCGI execution mode.

Refer to Foswiki::Engine documentation for explanation about methos below.

=cut

package Foswiki::Engine::FastCGI;

use base 'Foswiki::Engine::CGI';

use strict;

use FCGI;
use POSIX qw(:signal_h);
require File::Spec;

our $hupRecieved = 0;

sub run {
    my ( $this, $listen, $args ) = @_;

    my $sock = 0;
    if ($listen) {
        $sock = FCGI::OpenSocket( $listen, 100 )
          or die "Failed to create FastCGI socket: $!";
    }
    else {
        sigaction( SIGHUP, POSIX::SigAction->new( sub { $hupRecieved++ } ) )
          or warn "Could not install SIGHUP handler: $!";
    }
    $args ||= {};
    my $r = FCGI::Request( \*STDIN, \*STDOUT, \*STDERR, \%ENV, $sock,
        &FCGI::FAIL_ACCEPT_ON_INTR );
    my $manager;

    if ($listen) {
        $args->{manager} ||= 'Foswiki::Engine::FastCGI::ProcManager';
        $args->{nproc}   ||= 1;

        $this->fork() if $args->{detach};
        if ( $args->{manager} ) {
            eval "use " . $args->{manager} . "; 1" or die $@;
            $manager = $args->{manager}->new(
                {
                    n_processes => $args->{nproc},
                    pid_fname   => $args->{pidfile},
                }
            );
            $this->daemonize() if $args->{detach};
            $manager->pm_manage();
        }
        elsif ( $args->{detach} ) {
            $this->daemonize();
        }
    }

    my $localSiteCfg = File::Spec->catpath(
        ( File::Spec->splitpath( $INC{'Foswiki.pm'} ) )[ 0, 1 ],
        'LocalSite.cfg' );
    my $lastMTime = (stat $localSiteCfg)[9];

    while ( $r->Accept() >= 0 ) {
        $manager && $manager->pm_pre_dispatch();
        CGI::initialize_globals();
        my $req = $this->prepare;
        if ( UNIVERSAL::isa( $req, 'Foswiki::Request' ) ) {
            my $res = Foswiki::UI::handleRequest($req);
            $this->finalize( $res, $req );
        }
        $manager && $manager->pm_post_dispatch();
        my $mtime = (stat $localSiteCfg)[9];
        if ($mtime > $lastMTime || $hupRecieved) {
            $r->LastCall();
            if ($manager) {
                kill SIGHUP, $manager->pm_parameter('MANAGER_PID');
            }
            else {
                $hupRecieved++;
            }
        }
    }
    reExec() if $hupRecieved;
    FCGI::CloseSocket($sock) if $sock;
}

sub preparePath {
    my $this = shift;

    # In some hosted environments, users don't have access to "Alias", so they
    # should use in .htaccess something like:
    #
    # SetHandler foswiki-fastcgi
    # Action foswiki-fastcgi /foswiki/bin/foswiki.fcgi
    # <Files "foswiki.fcgi">
    #    SetHandler fastcgi-script
    # </Files>
    #
    # but then, the script is called by the webserver as
    # /foswiki/bin/foswiki.fcgi/foswiki/bin/edit, for example. In other words:
    # the seen PATH_INFO starts with ScriptUrlPath, so it must be removed. This
    # way, SUPER::preparePath works fine.

    $ENV{PATH_INFO} =~ s#^$Foswiki::cfg{ScriptUrlPath}/*#/#
      if $ENV{PATH_INFO};
    $this->SUPER::preparePath(@_);
}

sub write {
    my ( $this, $buffer ) = @_;
    syswrite STDOUT, $buffer;
}

sub reExec {
    require Config;
    $ENV{PERL5LIB} .= join $Config::Config{path_sep}, @INC;
    $ENV{PATH} = $Foswiki::cfg{SafeEnvPath};
    my $perl = $Config::Config{perlpath};
    chdir $main::dir
      or die
      "Foswiki::Engine::FastCGI::reExec(): Could not restore directory: $!";
    exec $perl, '-wT', $main::script, map { /^(.*)$/; $1 } @ARGV
      or die "Foswiki::Engine::FastCGI::reExec(): Could not exec(): $!";
}

sub fork () {

    ### block signal for fork
    my $sigset = POSIX::SigSet->new(SIGINT);
    POSIX::sigprocmask( SIG_BLOCK, $sigset )
      or die "Can't block SIGINT for fork: [$!]\n";

    ### fork off a child
    my $pid = fork;
    unless ( defined $pid ) {
        die "Couldn't fork: [$!]\n";
    }

    ### make SIGINT kill us as it did before
    $SIG{INT} = 'DEFAULT';

    ### put back to normal
    POSIX::sigprocmask( SIG_UNBLOCK, $sigset )
      or die "Can't unblock SIGINT for fork: [$!]\n";
    
    $pid && exit;

    return $pid;
}


=begin TML

---++ StaticMethod detach()

Daemonize process. Currently not portable...

=cut

sub daemonize {
    print "FastCGI daemon started (pid $$)\n";
    umask(0);
    chdir File::Spec->rootdir;
    open STDIN,  File::Spec->devnull or die $!;
    open STDOUT, ">&STDIN"           or die $!;
    open STDERR, ">&STDIN"           or die $!;
    POSIX::setsid();
}

1;
