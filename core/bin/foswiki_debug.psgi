#!/usr/bin/env perl
# See bottom of file for license and copyright information
use v5.14;
use Cwd;
use File::Spec;
use Data::Dumper;

my ( $rootDir, $libDir, $scriptDir );
my ( $checkpointSub, $statusSub );

BEGIN {
    $rootDir              = $ENV{FOSWIKI_HOME};
    $scriptDir            = $ENV{FOSWIKI_SCRIPTS};
    $ENV{FOSWIKI_ASSERTS} = 1;

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

    $libDir = File::Spec->catdir( $rootDir, "lib" );
    push @INC, $libDir;
}
use Plack::Builder;
use Foswiki::App;

#use Devel::Leak;
#use Devel::Leak::Object;

use constant CHECKLEAK => $ENV{FOSWIKI_CHECKLEAK} // 0;

BEGIN {
    if (CHECKLEAK) {
        foreach my $class (qw(Unit::Leak::Object Devel::Leak::Object)) {
            say STDERR "Using $class";
            eval "use $class qw{ GLOBAL_bless };";
            if ($@) {
                say STDERR "!!! Failed to load $class\n", $@;
            }
            else {
                eval "
                \$${class}::TRACKSOURCELINES = 1;
                \$${class}::TRACKSTACK       = 1;";
                $checkpointSub = $class->can('checkpoint');
                $statusSub     = $class->can('status');
                last;
            }
        }
    }
}

my $app = sub {
    my $env = shift;

    &$checkpointSub if CHECKLEAK;

    $ENV{FOSWIKI_SCRIPTS} = $scriptDir unless $ENV{FOSWIKI_SCRIPTS};
    $ENV{FOSWIKI_LIBS}    = $libDir    unless $ENV{FOSWIKI_LIBS};
    $ENV{FOSWIKI_DISABLED_EXTENSIONS} = "DBConfig";

    my $rc = Foswiki::App->run( env => $env, );

    if (CHECKLEAK) {
        &$statusSub;
        eval {
            require Devel::MAT::Dumper;
            Devel::MAT::Dumper::dump(
                $rootDir . "/working/logs/foswiki_debug_psgi.pmat" );
        };
        $env->{'psgix.harakiri.commit'} = 1 if $env->{'psgix.harakiri'};
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
