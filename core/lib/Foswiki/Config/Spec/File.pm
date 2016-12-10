# See bottom of file for license and copyright information

# A single spec file object.
package Foswiki::Config::Spec::File;

use File::stat;
use File::Spec;

use Foswiki::Class qw(app extensible);
extends qw(Foswiki::File);

# This is the file where defaults would be cached for fast access.
has cachePath => (
    is      => 'rw',
    lazy    => 1,
    clearer => 1,
    builder => 'prepareCachePath',
);

has fmt => (
    is      => 'rw',
    lazy    => 1,
    builder => 'prepareFmt',
);

# Make trigger auto-save defaults cache onto disk.
has cacheContent => (
    is        => 'ro',
    lazy      => 1,
    clearer   => 1,
    predicate => 1,
    builder   => 'prepareCacheContent',
);

pluggable guessFormat => sub {
    my $this = shift;

    return 'legacy';
};

sub prepareFmt {
    my $this = shift;

    return $this->guessFormat;
}

sub prepareCachePath {
    my $this = shift;

    my ( $vol, $dir, $fname ) = File::Spec->splitpath( $this->path );

    $fname =~ s/^(.+)\.[^\.]+$/\.$1.cache/;

    return File::Spec->catpath( $vol, $dir, $fname );
}

sub prepareCacheContent {
    my $this = shift;

    my $cachePath = $this->cachePath;

    return '' unless -e $cachePath;

    return $this->app->readFile( $cachePath, raiseError => 1, );
}

1;
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
