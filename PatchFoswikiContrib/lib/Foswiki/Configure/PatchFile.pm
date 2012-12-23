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
use File::stat;

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
    my $newMD5;

#~~~PATCH fdeeb7f236608b7792ad0845bf2279f9  lib/Foswiki/Configure/Dependency.pm (Foswiki 1.1.5)
#~~~PATCH fdeeb7f236608b7792ad0845bf2279f9:fdeeb7f236608b7792ad0845bf2279f9  lib/Foswiki/Configure/Dependency.pm (Foswiki 1.1.5)
    foreach my $line (@contents) {
        if ( substr( $line, 0, 8 ) eq '~~~PATCH' ) {
            my $target;
            my $desc;
            chomp $line;
            ( $md5, $target, $desc ) = split( ' ', substr( $line, 8 ), 3 );
            $desc =~ s/^\(//g;    # Remove leading/trailing parenthesis
            $desc =~ s/\)$//g;

            ( $md5, $newMD5 ) = split( ':', $md5, 2 );
            $foundPatch = _fixupFile($target);
            $patches{$foundPatch}{$md5}{patched} = $newMD5 || 'n/a';
            $patches{$foundPatch}{$md5}{version} = $desc   || 'n/a';
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
    my $digest = Digest::MD5->new->addfile($fh)->hexdigest;
    close $fh;
    return $digest;
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

    my $fstat = stat($file);
    my $mode  = $fstat->mode;
    ($file) = $file =~ /(.*)/;
    chmod( oct(600), "$file" );
    open( $fh, '>', $file ) || return "Rewrite $file failed:  $!";
    print $fh $patched;
    close $fh;
    ($mode) = $mode =~ /(.*)/;
    chmod( $mode, "$file" );

    return "Update successful for $file\n";
}

sub checkPatch {
    my $root = shift || _fixRoot();
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
            my $match =
                $origMD5 eq $md5                             ? 'NOT APPLIED'
              : $origMD5 eq $patchRef->{$key}{$md5}{patched} ? 'PATCHED'
              :                                                'N/A';
            $patchRef->{$key}{$md5}{status} = $match;
            $msgs .=
              "| $key | $md5 | $match | $patchRef->{$key}{$md5}{version} |\n";
        }
    }
    return $msgs . "\n";
}

# Copied from Foswiki::Configure::Package
sub _fixRoot {
    my @instRoot = File::Spec->splitdir( $Foswiki::cfg{DataDir} );
    pop(@instRoot);

    # SMELL: Force a trailing separator - Linux and Windows are inconsistent
    my $root = File::Spec->catfile( @instRoot, 'x' );
    chop $root;
    return $root;
}

sub applyPatch {
    my $root = shift || _fixRoot();
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

            $msgs .= "$rc\n" if $rc;
        }

    }

    $msgs .=
        ( $match > 1 )  ? "$match files patched."
      : ( $match == 1 ) ? '1 file patched.'
      :                   "No files matched  patch signatures.";
    return $msgs . "\n\n";

}

sub backupTargets {
    my $root     = shift || _fixRoot();
    my $patchRef = shift;
    my $msgs     = '';

    $msgs .= Foswiki::Configure::PatchFile::checkPatch( $root, $patchRef );
    $msgs .= "\n";

    my $stamp =
      Foswiki::Time::formatTime( time(),
        '$year$mo$day-$hour$minutes$seconds', 'servertime' );

    my $backup = 0;
    my %bkupFiles;

    # Get hash of all files that will be updated.
    foreach my $key ( keys %{$patchRef} ) {
        next if ( $key eq 'summary' );
        next if ( $key eq 'identifier' );
        next if ( $key eq 'error' );
        my $file = Foswiki::Configure::Util::mapTarget( $root, $key );
        next unless ( -f $file );
        foreach my $md5 ( keys %{ $patchRef->{$key} } ) {
            $bkupFiles{$key} = $file
              if ( $patchRef->{$key}{$md5}{status} eq 'NOT APPLIED' );
        }
    }

    if ( keys %bkupFiles ) {
        my $bkupDir  = "$patchRef->{identifier}-$stamp";
        my $bkupPath = $Foswiki::cfg{WorkingDir} . "/configure/backup";
        File::Path::mkpath("$bkupPath/$bkupDir");
        die "Create of backup directory $bkupDir failed"
          unless ( -d "$bkupPath/$bkupDir" );

        foreach my $file ( keys %bkupFiles ) {
            my $fstat = stat( $bkupFiles{$file} );
            my ( $vol, $dirs, $fn ) =
              File::Spec->splitpath("$bkupPath/$bkupDir/$file");
            if ($dirs) {
                File::Path::mkpath( File::Spec->catpath( $vol, $dirs, '' ) );
                my $mode = $fstat->mode;

                #( stat($file) )[2];    # File::Copy doesn't copy permissions
                File::Copy::copy( "$bkupFiles{$file}",
                    "$bkupPath/$bkupDir/$file" );
                ($mode) = $mode =~ /(.*)/;    # untaint
                chmod( $mode, "$bkupPath/$bkupDir/$file" );
            }

            $msgs .= "Backed up target: $file. to $bkupPath/$bkupDir/$file\n";
            $backup++;
        }
        my ( $rslt, $err );
        ( $rslt, $err ) =
          Foswiki::Configure::Util::createArchive( $bkupDir, $bkupPath, '1' );
        $rslt = "FAILED \n" . $err unless ($rslt);
        $msgs .= "Backup Archived as $rslt \n";
    }

    $msgs .=
        ( $backup > 1 )  ? "$backup files backed up."
      : ( $backup == 1 ) ? '1 file backed up.'
      :                    "No files backed up.";
    return $msgs . "\n\n";

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
