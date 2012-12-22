# See bottom of file for license and copyright information

package Foswiki::Configure::PatchFile;

use strict;
use warnings;
use File::Copy               ();
use File::Path               ();
use File::Spec               ();
use Foswiki::Time            ();
use Text::Patch              ();
use Foswiki::Configure::Util ();

=begin TML

---++ parsePatch($file ) -> %patch{filename} = diff
This routine will read in a patch file and parse it into separate patches.

=cut

sub parsePatch {
    my $file = shift;

    my %patches;
    my $error = '';

    $error .= "Not a file $file" unless ( -f $file );

    local $/ = "\n";
    open( my $fh, '<', $file ) || die "read of $file failed:  $!";
    my @contents = <$fh>;
    close $fh;

    $error .= "empty file $file" unless ( scalar @contents );

    if ($error) {
        $patches{error} = $error;
        return %patches;
    }

    ( $patches{identifier} ) = $file =~ m/.*(Item.*?)\.patch$/;
    my $foundPatch = 'summary';
    my $md5        = 'na';

    foreach my $line (@contents) {
        if ( $line =~ /^~~~PATCH\s+([^\s]+)\s+(.*?)\s+\((.*?)\)$/ ) {
            $md5                                 = $1;
            $foundPatch                          = _fixupFile($2);
            $patches{$foundPatch}{$md5}{version} = $3;
            next;
        }
        if ( $foundPatch eq 'summary' ) {
            $patches{summary} .= $line;
        }
        else {
            $patches{$foundPatch}{$md5}{patch} .= $line;
        }
    }

    return %patches;
}

sub _getMD5 {

    my $filename = shift;
    open( my $fh, '<', $filename ) or die "Can't open '$filename': $!";
    binmode($fh);
    return Digest::MD5->new->addfile($fh)->hexdigest;
}

sub _fixupFile {
    my $patchFile = shift;

    my ( $volume, $directories, $file ) =
      File::Spec->splitpath( $patchFile, 0 );
    my @dirs = File::Spec->splitdir($directories);

    shift @dirs if $dirs[0] eq 'a';
    shift @dirs if $dirs[0] =~ /^core|Plugin$|Contrib$|Skin$|AddOn$/;

    # Don't include volume,  Caller will map to local name.
    $patchFile = File::Spec->catfile( @dirs, $file );

    return $patchFile;

}

=begin TML

---++ updateFile($file, patch )
This routine will update the filea and rewrite it into its original
location, preserving permissions.

=cut

sub updateFile {
    my $file  = shift;
    my $diff  = shift;
    my $write = shift;

    return "$file is not a file" unless ( -f $file );

    local $/ = undef;
    open( my $fh, '<', $file ) || return "read of $file failed:  $!";
    my $src = <$fh>;
    close $fh;

    my $patched;

    eval {
        $patched = Text::Patch::patch( $src, $diff, { STYLE => 'Unified' } );
    };

    return "FAILED: $@" if $@;

    my $mode = ( stat($file) )[2];
    $file =~ /(.*)/;
    $file = $1;
    chmod( oct(600), "$file" );
    open( $fh, '>', $file ) || return "Rewrite $file failed:  $!";
    print $fh $patched;
    close $fh;
    $mode =~ /(.*)/;
    $mode = $1;
    chmod( $mode, "$file" );

    return "Update successful for $file\n";
}

sub checkPatch {
    my $root     = shift;
    my $patchRef = shift;

    my $msgs = '';

    foreach my $key ( keys %{$patchRef} ) {
        next if ( $key eq 'summary' );
        next if ( $key eq 'error' );
        next if ( $key eq 'identifier' );
        foreach my $md5 ( keys %{ $patchRef->{$key} } ) {

            my $file = Foswiki::Configure::Util::mapTarget( $root, $key );
            $msgs .= "| $key | | | Target Missing |\n" unless ( -f $file );

            my $origMD5 = _getMD5($file);
            my $match = ( $origMD5 eq $md5 ) ? 'NOT APPLIED' : 'N/A';
            $msgs .=
              "| $key | $md5 | $match | $patchRef->{$key}{$md5}{version} |\n";
        }
    }
    return $msgs;
}

sub applyPatch {
    my $root     = shift;
    my $patchRef = shift;

    my $msgs  = '';
    my $match = 0;

    foreach my $key ( keys %{$patchRef} ) {
        next if ( $key eq 'summary' );
        next if ( $key eq 'error' );
        next if ( $key eq 'identifier' );
        foreach my $md5 ( keys %{ $patchRef->{$key} } ) {

            my $file = Foswiki::Configure::Util::mapTarget( $root, $key );

            my $origMD5 = _getMD5($file);
            next unless ( $origMD5 eq $md5 );
            $msgs .=
"MD5 Matched - applying patch version $patchRef->{$key}{$md5}{version}.\n";
            $match++;

            my $rc =
              Foswiki::Configure::PatchFile::updateFile( $file,
                $patchRef->{$key}{$md5}{patch} );

            $msgs .= "$rc.\n" if $rc;
        }

    }

    $msgs .=
      ($match)
      ? "$match files patched\n"
      : "No files matched  patch signatures\n";
    return $msgs;

}

sub backupTargets {
    my $root     = shift;
    my $patchRef = shift;

    my $stamp =
      Foswiki::Time::formatTime( time(), '$year$mo$day-$hour$minutes$seconds',
        'servertime' );

    my $msgs   = '';
    my $backup = 0;

    my $bkupPath = Foswiki::Configure::Util::mapTarget( $root,
        "working/configure/backup/$patchRef->{identifier}-$stamp" );

    File::Path::mkpath($bkupPath);
    die "Create of backup directory $bkupPath failed" unless ( -d $bkupPath );

    foreach my $key ( keys %{$patchRef} ) {
        next if ( $key eq 'summary' );
        next if ( $key eq 'identifier' );
        next if ( $key eq 'error' );
        my $file = Foswiki::Configure::Util::mapTarget( $root, $key );
        next unless ( -f $file );

        my ( $fv, $fp, $fn ) = File::Spec->splitpath( $file, 0 );

        File::Copy::copy( $file, "$bkupPath/$fn" );

        $msgs .= "Backed up target: $file. to $bkupPath/$fn\n";
        $backup++;

    }

    $msgs .=
      ($backup)
      ? "$backup files backed up.\n"
      : "No files backed up.\n";
    return $msgs;

}
1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2012 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2000-2006 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root
of this distribution. NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
