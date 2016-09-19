#!/usr/bin/env perl
# See bottom of file for license and copyright information
use Cwd;
use File::Spec;

my $root = $ENV{FOSWIKI_HOME};
if ( !$root ) {

    # Try to guess our root dir by looking into %INC
    my $incKey = ( grep { /\/foswiki.*\.psgi$/ } keys %INC )[0];
    my $scriptFile = $INC{$incKey};
    my ( $volume, $scriptDir ) = File::Spec->splitpath($scriptFile);
    $root =
      File::Spec->catpath( $volume,
        File::Spec->catdir( $scriptDir, File::Spec->updir ), "" );
}

use lib Cwd::abs_path( File::Spec->catdir( $root, "lib" ) );
use Plack::Builder;
use Foswiki::App;
use HTTP::Server::PSGI;

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

    my $rc = Foswiki::App->run( env => $env, );

    if (CHECKLEAK) {
        Devel::Leak::Object::status;
        eval {
            require Devel::MAT::Dumper;
            Devel::MAT::Dumper::dump(
                $starting_root . "/working/logs/foswiki_debug_psgi.pmat" );
        };
    }

    return $rc;
};

my $server = HTTP::Server::PSGI->new(
    host    => "127.0.0.1",
    port    => 5000,
    timeout => 120,
);

$server->run(
    builder {
        enable 'Plack::Middleware::Static',
          path => qr/^\/pub\//,
          root => $root;
        $app;
    }
);
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
