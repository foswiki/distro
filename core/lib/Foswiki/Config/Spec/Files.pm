# See bottom of file for license and copyright information

package Foswiki::Config::Spec::Files;

use Foswiki    ();
use File::Spec ();
use File::Path qw(make_path);

use Foswiki::Class -app, -callbacks, -types;
extends qw(Foswiki::Object);
with qw(Foswiki::Config::CfgObject);

has baseDir => (
    is      => 'ro',
    lazy    => 1,
    builder => 'prepareBaseDir'
);

has cacheDir => (
    is      => 'rw',
    lazy    => 1,
    builder => 'prepareCacheDir',
);

has list => (
    is      => 'rw',
    lazy    => 1,
    clearer => 1,
    assert  => ArrayRef,
    builder => 'prepareList',
);

has mainSpec => (
    is      => 'rw',
    lazy    => 1,
    clearer => 1,
    assert  => InstanceOf ['Foswiki::Config::Spec::File'],
    builder => 'prepareMainSpec',
);

sub _scanDir {
    my $this = shift;
    my $dir  = shift;

    return () unless -d $dir;

    my $dh;

    return ()
      unless opendir $dh, $dir;

    my @specFiles;

    state $curdir = File::Spec->curdir;
    state $updir  = File::Spec->updir;

  DIR_ENTRY:
    while ( my $entry = readdir $dh ) {
        next DIR_ENTRY if $entry eq $curdir || $entry eq $updir;

        my $fullpath = File::Spec->catdir( $dir, $entry );

        if ( -d $fullpath ) {
            push @specFiles, $this->_scanDir($fullpath);
            next DIR_ENTRY;
        }

        next DIR_ENTRY unless $entry =~ /(?:^Spec\.[^.]+|\.spec)$/;

        push @specFiles,
          $this->create(
            'Foswiki::Config::Spec::File',
            path => $fullpath,
            cfg  => $this->cfg,
          );
    }

    return @specFiles;
}

sub collectSpecFiles {
    my $this = shift;

    my @specFileList;

    my @subDirs = qw(Plugins Contrib Extension);

    my $baseDir = $this->baseDir;

    push @specFileList, $this->mainSpec;

    foreach my $subDir (@subDirs) {
        my $specDir = File::Spec->catdir( $baseDir, 'Foswiki', $subDir );
        push @specFileList, $this->_scanDir($specDir);
    }

    return @specFileList;
}

sub prepareMainSpec {
    my $this = shift;

    #say STDERR "Creating a new file object for Foswiki.spec";
    my $msf = $this->create(
        'Foswiki::Config::Spec::File',
        path => File::Spec->catfile( $this->baseDir, 'Foswiki.spec' ),
        cfg  => $this->cfg,
    );
    return $msf;
}

sub prepareList {
    my $this = shift;

    return [ $this->collectSpecFiles ];
}

sub prepareBaseDir {
    my $this = shift;

    # Even in case we get extensions modules spread acroos the filesystem at
    # some point the spec files are expected to be located where Foswiki.pm is -
    # i.e. in lib/ dir.
    return Foswiki::guessLibDir;
}

sub prepareCacheDir {
    my $this = shift;

    my $cacheDir = File::Spec->catdir( $this->baseDir, ".specCache" );

    unless ( -d $cacheDir ) {
        my $err;
        my $rc =
          make_path( $cacheDir,
            { mode => 0760, error => \$err, verbose => 0, } );
        unless ($rc) {
            foreach my $item (@$err) {
                $this->app->logger->error(
                    "Cannot create cache dir " . $_ . ": " . $item->{$_} )
                  foreach keys %$item;
            }
        }
    }

    return $cacheDir;
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
