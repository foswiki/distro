# FastCGI Runtime Engine Component of Foswiki - The Free and Open Source Wiki,
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

---+!! UNPUBLISHED package Foswiki::Engine::FastCGI::ProcManager

Wrapper around FastCGI::ProcManager to make FastCGI engine re-execute itself
automatically upon configuration change.

=cut

package Foswiki::Engine::FastCGI::ProcManager;

use FCGI::ProcManager;
our @ISA = qw( FCGI::ProcManager );
use strict;

sub sig_manager {
    my $this = shift;
    $this->SUPER::sig_manager(@_);
    $Foswiki::Engine::FastCGI::hupRecieved++;
    $this->n_processes(0);
}

sub pm_die {
    my $this = shift;
    if ($Foswiki::Engine::FastCGI::hupRecieved) {
        Foswiki::Engine::FastCGI::reExec();
    }
    else {
        $this->SUPER::pm_die(@_);
    }
}

1;
