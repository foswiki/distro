#!/usr/bin/env perl
# See bottom of file for license and copyright information
use v5.14;
use Cwd;
use File::Spec;

my $root;

BEGIN {
    $root = $ENV{FOSWIKI_HOME};
    if ( !$root ) {

        # Try to guess our root dir by looking into %INC
        my $incKey = ( grep { /\/foswiki.*\.psgi$/ } keys %INC )[0];
        my $scriptFile = $INC{$incKey};
        my ( $volume, $scriptDir ) = File::Spec->splitpath($scriptFile);
        $root =
          File::Spec->catpath( $volume,
            File::Spec->catdir( $scriptDir, File::Spec->updir ), "" );
    }

    push @INC, File::Spec->catdir( $root, "lib" );
}

use Plack::Builder;
use Foswiki::App;

my $app = sub {
    return Foswiki::App->run( env => shift, );
};

builder {
    enable 'Plack::Middleware::Static',
      path => qr/^\/pub\//,
      root => $root;
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
