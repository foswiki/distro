#!/usr/bin/env perl
# See bottom of file for license and copyright information
use Cwd;
use lib Cwd::abs_path("../lib"),
  ( $ENV{FOSWIKI_HOME} ? $ENV{FOSWIKI_HOME} . "/lib" : () );
use Foswiki::App;
use HTTP::Server::PSGI;

my $app = sub {
    my $env = shift;
    my $rc = Foswiki::App->run( env => $env, );
    #$env->{'psgix.harakiri.commit'} = 1;
    return $rc;
};

my $server = HTTP::Server::PSGI->new(
    host => "127.0.0.1",
    port => 5000,
    timeout => 120,
);

$server->run($app);
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
