# See bottom of file for license and copyright information

=begin TML

---+!! package Foswiki::Engine::FastCGI

Class that implements FastCGI execution mode.

Refer to Foswiki::Engine documentation for explanation about methos below.

=cut

package Foswiki::Engine::FastCGI;

use strict;
use warnings;

use Foswiki          ();
use Foswiki::Sandbox ();
use Foswiki::Engine::CGI;
our @ISA = qw( Foswiki::Engine::CGI );

use FCGI;
use POSIX qw(:signal_h);
require File::Spec;

use vars qw( $VERSION $RELEASE );

*VERSION = \$Foswiki::Contrib::FastCGIEngineContrib::VERSION;
*RELEASE = \$Foswiki::Contrib::FastCGIEngineContrib::RELEASE;

our $hupRecieved = 0;

=begin TML

---++ Configuration

=MaxRequrests= limits the number of requests one backend process is allowed to
serve before it will terminate and respawn a substitute.  This can be used to
fight back memory leaks in the application where the processes memory
consumption grows over time. Default is 100 requests.  Lower this limit when
processes tend to grow too fast over time exceeding your server's memory
capacities. A negative value disables this heuristics. Reasonable values are
roughly 10 or 20 depending on the profile of additional plugins and libraries.

Note also, that mod_fcgid has got similar configuration parameters. Alas, this
project is abandoned at the time of this writing. mod_fastcgi on the other hand
is missing this option, as far as I can say. 

The actual value of =MaxRequest= also depends on the maximum number of parallel
threads and fcgi backend processes that are allowed to be spawned by the web server.

=cut

our $sock = 0;

sub run {
    my ( $this, $listen, $args ) = @_;

    # untaint pidfile
    $args->{pidfile} = Foswiki::Sandbox::untaintUnchecked( $args->{pidfile} );

    if ($listen) {
        $sock = FCGI::OpenSocket( $listen, 100 )
          or die "Failed to create FastCGI socket: $!";
    }
    $args ||= {};
    my $r = FCGI::Request( \*STDIN, \*STDOUT, \*STDERR, \%ENV, $sock,
        &FCGI::FAIL_ACCEPT_ON_INTR );
    my $manager;

    # make sure some ENV vars are set
    $ENV{"REQUEST_URI"} = ''             unless defined $ENV{REQUEST_URI};
    $ENV{"PATH_INFO"}   = ''             unless defined $ENV{PATH_INFO};
    $ENV{"SCRIPT_NAME"} = 'foswiki.fcgi' unless defined $ENV{SCRIPT_NAME};

    if ($listen) {
        $args->{manager} ||= 'Foswiki::Engine::FastCGI::ProcManager';
        $args->{nproc}   ||= 1;

        $this->fork() if $args->{detach};
        eval "use " . $args->{manager} . "; 1";
        unless ($@) {
            my $maxRequests = $Foswiki::cfg{FastCGIContrib}{MaxRequests} || 100;
            my $maxSize     = $Foswiki::cfg{FastCGIContrib}{MaxSize}     || 0;
            my $checkSize   = $Foswiki::cfg{FastCGIContrib}{CheckSize}   || 10;

            $manager = $args->{manager}->new(
                {
                    n_processes => $args->{nproc},
                    pid_fname   => $args->{pidfile},
                    quiet       => $args->{quiet},

                    max_requests =>
                      ( defined $args->{max} ? $args->{max} : $maxRequests ),

                    max_size =>
                      ( defined $args->{size} ? $args->{size} : $maxSize ),

                    sizecheck_num_requests =>
                      ( defined $args->{check} ? $args->{check} : $checkSize ),
                }
            );

            $manager->pm_manage();
        }
        else {    # No ProcManager

            # ProcManager is in charge SIGHUP handling. If there is no manager,
            # we handle SIGHUP ourslves.
            eval {
                sigaction( SIGHUP,
                    POSIX::SigAction->new( sub { $hupRecieved++ } ) );
            };
            warn "Could not install SIGHUP handler: $@$!" if $@ || $@;
        }
        $this->daemonize() if $args->{detach};
    }

    my $localSiteCfg;
    my $lastMTime = 0;
    my $mtime     = 0;

  # If $localSiteCfg is undefined, then foswiki is running in bootstrap mode.
  # kill and restart the proc manager after every transaction, so that
  # when the config file is saved, it gets used.   Note that on some high volume
  # installations, LocalSite.cfg checking needs to be disabled.

    if ( !defined $Foswiki::cfg{FastCGIContrib}{CheckLocalSiteCfg}
        || $Foswiki::cfg{FastCGIContrib}{CheckLocalSiteCfg} )
    {

        $localSiteCfg = $INC{'LocalSite.cfg'};
        if ( defined $localSiteCfg ) {
            $lastMTime = ( stat $localSiteCfg )[9];
        }
    }

    while ( $r->Accept() >= 0 ) {
        $manager && $manager->pm_pre_dispatch();
        CGI::initialize_globals();

        my $req = $this->prepare;
        if ( UNIVERSAL::isa( $req, 'Foswiki::Request' ) ) {
            my $res = Foswiki::UI::handleRequest($req);
            $this->finalize( $res, $req );
        }

        $mtime = ( stat $localSiteCfg )[9] if defined $localSiteCfg;

        if ( $mtime > $lastMTime || $hupRecieved ) {
            $r->LastCall();
            if ($manager) {
                kill SIGHUP, $manager->pm_parameter('MANAGER_PID');
            }
            else {
                $hupRecieved++;
            }
        }
        $manager && $manager->pm_post_dispatch();
    }
    reExec() if $hupRecieved;
    closeSocket();
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
      if ( $ENV{PATH_INFO} && defined $Foswiki::cfg{ScriptUrlPath} );

    $this->SUPER::preparePath(@_);
}

sub write {
    syswrite STDOUT, $_[1];
}

sub closeSocket {
    return unless $sock;
    FCGI::CloseSocket($sock);
    $sock = 0;
}

sub reExec {
    closeSocket();

    require Config;

    #SMELL: This was growing PERL5LIB on every reExec.
    #$ENV{PERL5LIB} .= join $Config::Config{path_sep}, @INC;

    $ENV{PATH} = $Foswiki::cfg{SafeEnvPath}
      if ( defined $Foswiki::cfg{SafeEnvPath} );
    my $perl = $Config::Config{perlpath};
    chdir $main::dir
      or die
      "Foswiki::Engine::FastCGI::reExec(): Could not restore directory: $!";

    exec $perl, $main::script, map { /^(.*)$/; $1 } @ARGV
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
    umask(0);
    chdir File::Spec->rootdir;
    open STDIN,  File::Spec->devnull or die $!;
    open STDOUT, ">&STDIN"           or die $!;
    open STDERR, ">&STDIN"           or die $!;
    POSIX::setsid();
}

1;

__END__
FastCGI Runtime Engine of Foswiki - The Free and Open Source Wiki,
http://foswiki.org/

Copyright (C) 2008-2015 Gilmar Santos Jr, jgasjr@gmail.com and Foswiki
contributors. Foswiki contributors are listed in the AUTHORS file in the root
of Foswiki distribution.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

------------------------------------------------------------------------------
Parts of this package are based on Net::Server::Daemonize, which is
 Copyright (C) 2001-2007

   Jeremy Howard
   j+daemonize@howard.fm

   Paul Seamons
   paul@seamons.com
   http://seamons.com/

For more details:
http://search.cpan.org/perldoc?Net::Server::Daemonize
------------------------------------------------------------------------------
As per the GPL, removal of this notice is prohibited.
