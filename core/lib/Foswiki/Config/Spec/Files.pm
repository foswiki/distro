# See bottom of file for license and copyright information

package Foswiki::Config::Spec::Files;

use Foswiki    ();
use File::Spec ();

use Foswiki::Class qw(app callbacks extensible);
extends qw(Foswiki::Object);

has list => (
    is      => 'rw',
    lazy    => 1,
    clearer => 1,
    isa     => Foswiki::Object::isaHASH( 'list', noUndef => 1, ),
    builder => 'prepareList',
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
          $this->create( 'Foswiki::Config::File', path => $fullpath );
    }
}

sub collectSpecs {
    my $this = shift;

    my @specFileList;

    my @subDirs = qw(Plugins Contrib Extension);

    my ( $vol, $dir ) = File::Spec->splitpath( $INC{'Foswiki.pm'} );

    my $baseDir = File::Spec->catpath( $vol, $dir );

    push @specFileList, File::Spec->catfile( $baseDir, 'Foswiki.spec' );

    foreach my $subDir (@subDirs) {
        my $specDir = File::Spec->catdir( $baseDir, 'Foswiki', $subDir );
        push @specFileList, $this->_scanDir($specDir);
    }

    return @specFileList;
}

sub prepareList {
    my $this = shift;

    return [ $this->collectSpecs ];
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
