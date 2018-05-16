# See bottom of file for license and copyright information

# A single spec file object.
package Foswiki::Config::Spec::File;

use File::stat;
use File::Spec;
use Assert;
use Digest::SHA qw(sha1_hex);
use Storable qw(dclone);
use Try::Tiny;

use constant CACHE_SUBDIR => '.specCache';

use Foswiki::Class -app;
extends qw(Foswiki::File);
with qw(Foswiki::Config::CfgObject Foswiki::Util::Localize);

# Spec file format:
# - 'legacy' for classical pre-3.0 format
# - 'perl' for plain Perl code (including call to the spec() method)
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
    clearer => 1,
    trigger => 1,
    builder => 'prepareData',
);

has parsed => (
    is      => 'rw',
    clearer => 1,
    default => 0,
);

# localData is TRUE if the data attribute has been generated locally by the
# object.
has localData => ( is => 'rw', clearer => 1, );

sub setLocalizableAttributes {
    return qw( data parsed localData );
}

sub guessFormat {
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
}

sub validCache {
    my $this = shift;

    my $cf = $this->cacheFile;

    my $fstat = $this->stat;

    return
         defined( $cf->stat )
      && defined( $cf->content )
      && $cf->isConsistent
      && ( $cf->stat->mtime >= $fstat->mtime )
      && ( !defined $cf->fileSize || ( $cf->fileSize == $fstat->size ) );
}

sub parse {
    my $this = shift;

    my $dataObj = tied %{ $this->data };

    # Don't run twice for the same file.
    unless ( $this->parsed ) {
        my $cfg = $this->cfg;
        my $cachedData;
        my @specs;

        $cachedData = $this->cacheFile->specData if $this->validCache;

        if ($cachedData) {
            @specs = @{$cachedData};
        }
        else {
            my $parser = $cfg->getSpecParser( $this->fmt );

            return undef unless $parser;

            @specs = $parser->parse($this);

            try {
                my $specData  = dclone( \@specs );
                my $cacheFile = $this->cacheFile;
                $cacheFile->specData($specData);
                my $data         = $this->cfg->makeSpecsHash;
                my $localDataObj = tied %$data;
                $cfg->spec(
                    source    => $this,
                    dataObj   => $localDataObj,
                    localData => 1,
                    section   => $this->section,
                    specs     => \@specs,
                );
                $cacheFile->storeNodes( $localDataObj->getLeafNodes );
                $cacheFile->complete;
            }
            catch {
                my $e = Foswiki::Exception::Fatal->transmute( $_, 0 );

                # We'd rather ignore any caching error. If specs cannot be
                # cached then go away with it and recall the parser for every
                # invocation.
                # SMELL Replace warn with bufferized messaging when it's ready.
                warn "Cannot cache specs: " . $e;
            };
        }

        $cfg->spec(
            source    => $this,
            dataObj   => $dataObj,
            localData => $this->localData,
            section   => $this->section,
            specs     => \@specs,
        );

        $this->parsed(1);
    }

    return $dataObj;
}

sub refreshCache {
    my $this = shift;

    return if $this->validCache;

    say STDERR "Invalid cache for ", $this->path if DEBUG;

    # To have the cache refreshed we must move away any data object supplied by
    # the caller and use a local one. The parsed attribute must be reset too.
    my $holder = $this->localize;

    my $dataObj = $this->parse;

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

    my ( $vol, $dir, $file ) = File::Spec->splitpath( $this->path );

    my @dirs = File::Spec->splitdir( File::Spec->canonpath($dir) );

    my $baseName;

    if ( File::Spec->canonpath( File::Spec->catpath( $vol, $dir, "" ) ) eq
        Foswiki::guessLibDir )
    {
        ( $baseName = $file ) =~ s/\./_/g;
    }
    else {
        $baseName = $dirs[-1];
    }

    my $fname = $baseName . "_" . sha1_hex( $this->path ) . ".cached";

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

    $this->localData(1);

    return $this->cfg->makeSpecsHash;
}

sub _trigger_data {
    my $this = shift;

    $this->clear_parsed;
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
