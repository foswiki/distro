# See bottom of file for license and copyright information

# A single spec file object.
package Foswiki::Config::Spec::File;

use File::stat;
use File::Spec;
use Digest::SHA qw(sha1_hex);

use constant CACHE_SUBDIR => '.specCache';

use Foswiki::Class qw(app extensible);
extends qw(Foswiki::File);
with qw(Foswiki::Config::CfgObject);

# Spec file format:
# - 'legacy' for classical pre-3.0 format
# - 'perl' for plain Perl code (including call to method spec())
# - 'data' for the new keyed format (i.e. raw spec() arguments)
# Other values could be supported by extensions.
has fmt => (
    is      => 'rw',
    lazy    => 1,
    builder => 'prepareFmt',
);

has shebang => (
    is      => 'ro',
    lazy    => 1,
    clearer => 1,
    builder => 'prepareShebang',
);

has cacheFile => (
    is        => 'rw',
    lazy      => 1,
    clearer   => 1,
    predicate => 1,
    builder   => 'prepareCacheFile',
    isa =>
      Foswiki::Object::isaCLASS( 'cacheFile', 'Foswiki::File', noUndef => 1, ),
);

has section => (
    is   => 'rw',
    lazy => 1,
    isa  => Foswiki::Object::isaCLASS(
        'secion', 'Foswiki::Config::Section', noUndef => 1,
    ),
    builder => 'prepareSection',
);

has data => (
    is      => 'rw',
    lazy    => 1,
    builder => 'prepareData',
);

pluggable guessFormat => sub {
    my $this = shift;

    # If shebang is defined then it unambiguously defines spec format.
    # For empty shebang '#!' presume it's data format.
    if ( defined $this->shebang ) {
        return ( $this->shebang || 'data' );
    }

    # Determine file type by its extension if file is called Spec.
    my ( undef, undef, $filename ) = File::Spec->splitpath( $this->path );
    if ( $filename =~ /^Spec\.(.+)$/ ) {
        return $1;
    }

    my $content = $this->content;

    # Check for three key attributes to distinguish legacy format from others:
    # - A section comment of '# ---+' format
    # - A type comment line '# **TYPE '
    # - Actual config item '$Foswiki::cfg{Key}' on a line beginning.
    if (   $content =~ /^\s*#\s+---\++\s*/ms
        && $content =~ /^\s*(?:\$Foswiki::cfg\{|1;)/ms )
    {
        return 'legacy';
    }

    return 'data';
};

sub validCache {
    my $this = shift;

    my $cf = $this->cacheFile;

    return
         defined( $cf->stat )
      && defined( $cf->content )
      && ( $cf->stat->mtime >= $this->stat->mtime );
}

sub refreshCache {
    my $this = shift;

    return if $this->validCache;

    say STDERR "Invalided cache for ", $this->path if DEBUG;

    my $cfg = $this->cfg;

    my $parser = $cfg->getSpecParser( $this->fmt );

    return unless $parser;

    my @specs = $parser->parse($this);

    my $dataObj = tied %{ $this->data };
    $cfg->spec(
        source  => $this,
        data    => $dataObj,
        section => $this->section,
        specs   => \@specs,
    );

    $this->cacheFile->store( $dataObj->getLeafNodes );

    return;
}

sub prepareFmt {
    my $this = shift;

    return $this->guessFormat;
}

sub prepareShebang {
    my $this = shift;

    return undef unless $this->content =~ /^#!(\w*)\s*\n/s;
    return $1;
}

sub prepareCacheFile {
    my $this = shift;

    my ( $vol, $dir ) = File::Spec->splitpath( $this->path );

    my @dirs = File::Spec->splitdir( File::Spec->canonpath($dir) );

    my $fname = $dirs[-1] . "_" . sha1_hex( $this->path ) . ".defaults";

    # Don't let the cache object to raise exceptions because it's for support
    # purposes only. If it fails we simple shall follow the slower way of
    # re-reading the specs and fetching the defaults.
    return $this->create(
        'Foswiki::Config::Spec::CacheFile',
        path => File::Spec->catfile( $this->cfg->specFiles->cacheDir, $fname ),
        raiseError => 0,
    );
}

sub prepareSection {
    my $this = shift;

    return $this->create( 'Foswiki::Config::Section', name => 'Parser Root', );
}

# If data key was not supplied with constructor parameters then create our own.
# This would allow to have localized copy of defaults from a particular spec
# file.
sub prepareData {
    my $this = shift;

    return $this->cfg->makeSpecsHash;
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
