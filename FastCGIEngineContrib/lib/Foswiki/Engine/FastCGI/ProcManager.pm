# FastCGI Runtime Engine Component of Foswiki - The Free and Open Source Wiki,
# http://foswiki.org/
#
# Copyright (C) 2008-2015 Gilmar Santos Jr, jgasjr@gmail.com and Foswiki
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

---+!! UNPUBLISHED package Foswiki::Engine::FastCGI::ProcManager

Wrapper around FastCGI::ProcManager to make FastCGI engine re-execute itself
automatically upon configuration change.

=cut

package Foswiki::Engine::FastCGI::ProcManager;

use strict;
use warnings;

use FCGI::ProcManager::Constrained;
use Foswiki::Engine::FastCGI ();
our @ISA = qw( FCGI::ProcManager::Constrained );

sub sig_manager {
    my $this = shift;
    $this->SUPER::sig_manager(@_);
    $Foswiki::Engine::FastCGI::hupRecieved++;
    $this->n_processes(0);
}

sub pm_die {
    my ($this, $msg, $n) = @_;

    $msg ||= ''; # protect against error in FCGI.pm

    if ($Foswiki::Engine::FastCGI::hupRecieved) {
        Foswiki::Engine::FastCGI::reExec();
    }
    else {
        $this->SUPER::pm_die($msg, $n);
    }
}

sub pm_notify {
    my ($this, $msg) = @_;

    return if $this->{quiet};    
    $this->SUPER::pm_notify($msg);
}

sub pm_change_process_name {
    my ($this,$name) = @_;

    $name =~ s/perl/foswiki/g;
    $0 = $name;
}

1;
