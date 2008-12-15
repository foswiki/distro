# Runtime Engine of Foswiki - The Free and Open Source Wiki,
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
use IO::Handle;

sub run {
    my ( $this, $listen, $args ) = @_;

    my $sock = 0;
    if ( $listen ) {
        $sock = FCGI::OpenSocket( $listen, 100)
          or die "Failed to create FastCGI socket: $!";
    }
    my %env = ();
    $args ||= {};
    my $r = FCGI::Request( \*STDIN, \*STDOUT, \*STDERR, \%ENV, $sock, &FCGI::FAIL_ACCEPT_ON_INTR);
    my $manager;
    
    if ($listen) {
        $args->{manager} ||= 'FCGI::ProcManager';
        $args->{nproc}   ||= 1;

        $this->fork() if $args->{detach};
        if ( $args->{manager} ) {
            eval "use " . $args->{manager} . "; 1" or die $@;
            $manager = $args->{manager}->new(
                {
                    n_processes => $args->{nproc},
                    pid_fname   => $args->{pidfile}
                }
            );
            $this->daemonize() if $args->{detach};
            $manager->pm_manage();
        }
        elsif ( $args->{detach} ) {
            $this->daemonize();
        }
    }

    while ( $r->Accept() >= 0 ) {
        $manager && $manager->pm_pre_dispatch();
        CGI::initialize_globals();
        my $req = $this->prepare;
        if ( UNIVERSAL::isa($req, 'Foswiki::Request') ) {
            my $res = Foswiki::UI::handleRequest($req);
            $this->finalize( $res, $req );
        }
        $manager && $manager->pm_post_dispatch();
    }
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

    $ENV{PATH_INFO} =~ s#^$Foswiki::cfg{ScriptUrlPath}/*#/#;
    $this->SUPER::preparePath(@_);
}

sub write {
    my ($this, $buffer) = @_;
    syswrite STDOUT, $buffer;
}

sub fork {
    require POSIX;
    fork && exit;
}

=begin TML

---++ StaticMethod detach()

Daemonize process. Currently not portable...

=cut

sub daemonize {
    print "FastCGI daemon started (pid $$)\n";
    umask(0);
    chdir '/';
    open STDIN, "+</dev/null" or die $!;
    open STDOUT, ">&STDIN"    or die $!;
    open STDERR, ">&STDIN"    or die $!;
    POSIX::setsid();
}

1;
