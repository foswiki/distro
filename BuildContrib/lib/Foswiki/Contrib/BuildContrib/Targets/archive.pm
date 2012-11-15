# See bottom of file for license and copyright information
package Foswiki::Contrib::Build;

use strict;
use warnings;
use Digest::MD5;

=begin TML

---++++ target_archive
Makes zip and tgz archives of the files in tmpDir. Also copies the installer.

=cut

sub target_archive {
    my $this    = shift;
    my $project = $this->{project};
    my $target  = $project;
    if ( defined $this->{options}->{archive_prefix} ) {

        # optional archive name prefix
        $target = "$this->{options}->{archive_prefix}$target";
    }

    die 'no tmpDir set'  unless defined( $this->{tmpDir} );
    die 'no project set' unless defined($project);
    die 'tmpDir (' . $this->{tmpDir} . ') not found'
      unless ( -e $this->{tmpDir} );

    $this->pushd( $this->{tmpDir} );

    $this->apply_perms( $this->{files}, $this->{tmpDir} );

    $this->sys_action( 'zip', '-r', '-q', $project . '.zip', '*' );
    $this->perl_action( 'File::Copy::move("'
          . $project
          . '.zip", "'
          . $this->{basedir} . '/'
          . $target
          . '.zip");' );

    # BSD and MacOS don't support owner/group options.
    if ( `tar --owner 2>&1` =~ m/(?:unrecognized|not supported)/ ) {

# SMELL: sys_action will auto quote any parameter containing a space.  So the parameter
# and argument for group and user must be passed in as separate parameters.
        print STDERR
          "tar --owner / --group  not supported.  Recommend building as root\n";
        $this->sys_action( 'tar', '-czhpf', $project . '.tgz', '*' );
    }
    else {
        $this->sys_action( 'tar', '--owner', '0', '--group', '0', '-czhpf',
            $project . '.tgz', '*' );
    }

    $this->perl_action( 'File::Copy::move("'
          . $project
          . '.tgz", "'
          . $this->{basedir} . '/'
          . $target
          . '.tgz")' );

    $this->perl_action( 'File::Copy::move("'
          . $this->{tmpDir} . '/'
          . $project
          . '_installer","'
          . $this->{basedir} . '/'
          . $target
          . '_installer")' );

    $this->pushd( $this->{basedir} );
    my @fs;
    foreach my $f (qw(.tgz _installer .zip)) {
        push( @fs, "$target$f" ) if ( -e "$target$f" );
    }

    open( my $cs, '>', "$target.md5" ) || die $!;
    my $md5 = Digest::MD5->new;
    foreach my $file (@fs) {
        $md5->new;
        open my $fh, '<', $file
          or die "Can't open $file: $!";
        binmode $fh;
        $md5->addfile($fh);
        close $fh;
        print $cs $md5->hexdigest . "  $file\n";
    }
    close(CS);
    print "MD5 checksums in $this->{basedir}/$target.md5\n";

    if ( eval { require Digest::SHA } ) {
        open( CS, '>', "$target.sha1" ) || die $!;
        foreach my $file (@fs) {
            open( F, '<', $file );
            local $/;
            my $data = <F>;
            close(F);
            my $cs = Digest::SHA::sha1_hex($data);
            print CS "$cs  $file\n";
        }
        close(CS);
        print "SHA1 checksums in $this->{basedir}/$target.sha1\n";
    }
    else {
        warn
          "WARNING: Digest::SHA not installed; cannot generate SHA1 checksum\n";
    }

    $this->popd();
    $this->popd();

    my $warn = 0;
    foreach my $f (qw(.tgz .zip .txt _installer)) {
        if ( -e "$this->{basedir}/$target$f" ) {
            print "$f in $this->{basedir}/$target$f\n";
        }
        else {
            warn "WARNING: no $target$f was generated\n";
            $warn++;
        }
    }
    if ($warn) {
        warn <<HERE;
Some release files were not generated, either because there was
no matching source file, or because they were disabled by !option.
HERE
    }
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2012 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2004-2012 C-Dot Consultants - All rights reserved

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details, published at
http://www.gnu.org/copyleft/gpl.html

As per the GPL, removal of this notice is prohibited.
