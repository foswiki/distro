#!/usr/bin/env perl
# See bottom of file for license and copyright information
use v5.14;
use Cwd;
use File::Spec;

my ( $rootDir, $scriptDir );

BEGIN {
    $rootDir   = $ENV{FOSWIKI_HOME};
    $scriptDir = $ENV{FOSWIKI_SCRIPTS};

    unless ($scriptDir) {
        my $script = __FILE__;

        # Try to guess our root dir by looking into %INC if __FILE__ isn't
        # there.
        $script = ( grep { /\/foswiki.*\.psgi$/ } keys %INC )[0]
          if defined $INC{$script};

        # If scipt is executed directly it won't be found in %INC. Use the
        # guessed script name then.
        my $scrFileName = $INC{$script} || $script;
        my ( $volume, $sdir ) = File::Spec->splitpath($scrFileName);
        $scriptDir = File::Spec->catpath( $volume, $sdir, "" );
    }

    unless ($rootDir) {
        $rootDir = File::Spec->catdir( $scriptDir, File::Spec->updir );
    }

    push @INC, File::Spec->catdir( $rootDir, "lib" );
}

use Foswiki::Aux::Dependencies rootDir => $rootDir, firstRunCheck => 1;
if (@Foswiki::Aux::Dependencies::messages) {
    say STDERR join( "\n", @Foswiki::Aux::Dependencies::messages );
}
use Plack::Builder;

my $app = sub {
    my $env = shift;

    $env->{FOSWIKI_SCRIPTS} = $scriptDir unless $env->{FOSWIKI_SCRIPTS};

    require Foswiki::App;
    return Foswiki::App->run( env => $env, );
};

builder {
    enable 'Plack::Middleware::Static',
      path => qr/^\/pub\//,
      root => $rootDir;
    $app;
}
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2016 Foswiki Contributors. Foswiki Contributors
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

# vim: ft=perl
