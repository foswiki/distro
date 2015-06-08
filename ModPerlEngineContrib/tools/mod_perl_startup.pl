#!/usr/bin/env perl

# mod_perl Runtime Engine of Foswiki - The Free and Open Source Wiki,
# http://foswiki.org/
#
# Copyright (C) 2009 Gilmar Santos Jr, jgasjr@gmail.com and Foswiki
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

use strict;
use File::Spec;

BEGIN {
    my ( $vol, @path );
    foreach my $file ( keys %INC ) {
        next unless $file =~ /mod_perl_startup\.pl$/;
        my $dir;
        ( $vol, $dir ) = ( File::Spec->splitpath($file) )[ 0, 1 ];
        @path = File::Spec->splitdir($dir);
        last;
    }
    pop @path while scalar(@path) && $path[-1] eq '';
    $path[-1]             = 'bin';
    $ENV{FOSWIKI_SCRIPTS} = File::Spec->catdir(@path);
    $path[-1]             = 'lib';
    unshift @INC, File::Spec->catpath( $vol, File::Spec->catdir(@path) );
    push( @path, qw(CPAN lib) );
    unshift @INC, File::Spec->catpath( $vol, File::Spec->catdir(@path) );
}

use Foswiki::Engine::Apache ();

1;
