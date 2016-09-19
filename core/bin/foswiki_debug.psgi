#!/usr/bin/env perl
# See bottom of file for license and copyright information
use v5.14;
use Cwd;
use File::Spec;
use Data::Dumper;

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
use Plack::Builder;
use Foswiki::App;
use Devel::Leak;
use Devel::Leak::Object;

use constant CHECKLEAK => 0;

BEGIN {
    if (CHECKLEAK) {
        eval "use Devel::Leak::Object qw{ GLOBAL_bless };";
        die $@ if $@;
        $Devel::Leak::Object::TRACKSOURCELINES = 1;
        $Devel::Leak::Object::TRACKSTACK       = 1;
    }
}

my $app = sub {
    my $env = shift;

    Devel::Leak::Object::checkpoint if CHECKLEAK;
    
    $env->{FOSWIKI_SCRIPTS} = $scriptDir unless $env->{FOSWIKI_SCRIPTS};

    my $rc = Foswiki::App->run( env => $env, );

    if (CHECKLEAK) {
        Devel::Leak::Object::status;
        eval {
            require Devel::MAT::Dumper;
            Devel::MAT::Dumper::dump(
                $rootDir . "/working/logs/foswiki_debug_psgi.pmat" );
        };
    }

    return $rc;
};

builder {
    enable 'Plack::Middleware::Static',
      path => qr/^\/pub\//,
      root => $rootDir;
    $app;
};
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
