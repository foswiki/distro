# See bottom of file for license and copyright information

package Foswiki::Configure::PatchFile;

use strict;
use warnings;
use File::Copy    ();
use File::Path    ();
use File::Spec    ();
use Foswiki::Time ();
use Text::Patch   ();
use File::stat;

=begin TML

---++ parsePatch($file ) -> %patch{filename}
This routine will read in a patch file and parse it into separate patches.

Each patch file can patch one or more files.  Each file can have one or more separate patches matching different versions of the file.

Builds a hash describing the patch file.
   * {identifier} = The patch file name without the patch extension.  ItemNNNN-001
   * {summary} = The descriptive text from the head of the patch file.
   * {path/to/target/file}
      * {md5_of_target} = Will match the file version that can accept this patch.
         * {patched} = Expected MD5 of the patched file.
         * {version} = Relese from PATCH record describing the target. Parenthesis removed. Must match $Foswiki::RELEASE
         * {patch} = The patch in unified diff format.
         * {status} = Set by checkPatch to one 3 possible values:
            * "N/A" - neither the old nor the new MD5 matches the file.
            * "PATCHED" - The patch has been applied and the patched MD5 matches.
            * "NOT APPLIED" - The initial MD5 matches, so the patch will be applied 

Supports two differnt patch file record layouts:

<verbatim>
#             target file MD5                          relative path file         RELEASE
#~~~PATCH fdeeb7f236608b7792ad0845bf2279f9  lib/Foswiki/Configure/Dependency.pm (Foswiki-1.1.5)
#
#             target file MD5                    patched file MD5                   relative file path             RELEASE
#~~~PATCH fdeeb7f236608b7792ad0845bf2279f9:fdeeb7f236608b7792ad0845bf2279f9  lib/Foswiki/Configure/Dependency.pm (Foswiki-1.1.5,Foswiki-1.1.6)
</verbatim>

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

    foreach my $line (@contents) {
        if ( substr( $line, 0, 8 ) eq '~~~PATCH' ) {
            my $target;
            my $desc;
            chomp $line;
            ( $md5, $target, $desc ) = split( ' ', substr( $line, 8 ), 3 );

            ( $md5, $newMD5 ) = split( ':', $md5, 2 );
            $foundPatch = _fixupFile($target);
            $patches{$foundPatch}{$md5}{patched} = $newMD5 || 'n/a';
            if ( $desc && $desc =~ m/\(([^\)]+)\)/ ) {

                # Description contains a release string.
                $patches{$foundPatch}{$md5}{version} = $1 || 'n/a';
            }
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

=begin TML

---++ _getMD5($filename ) -> $digest
This routine will read calculate MD5 of the passed filename.

=cut

sub _getMD5 {

    my $filename = shift;

    open( my $fh, '<', $filename ) or die "Can't open '$filename': $!";
    binmode($fh);
    my $digest = Digest::MD5->new->addfile($fh)->hexdigest;
    close $fh;
    return $digest;
}

=begin TML

---++ _fixupFile($filename ) -> $filename
This routine will determine the fosiki filname from a patch filename.

=cut

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

---++ updateFile($file, $patch, $reverse )
This routine will update the filea and rewrite it into its original
location, preserving permissions.  If $reverse is true, the reverse of the diff is calculated, and the patch is removed.

=cut

sub updateFile {
    my $file    = shift;
    my $diff    = shift;
    my $reverse = shift || 0;
    my $msg     = 'successful';

    return "$file is not a file" unless ( -f $file );

    if ($reverse) {
        $diff = reverseDiff($diff);
        $msg  = 'reversed';
    }

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

    return "Update $msg for $file\n";
}

=begin TML

---++ checkPatch($file ) -> $messages 
This routine will read in a patch hash, determine which patches are applicable for the system, or have already been applied.
It will update the {status} field for each patch version, assigning one of 3 possible status.

(Note that for old style patch records, the "PATCHED" status can not be determined. Patched files will be reported as "N/A").

Each patch file can patch one or more files.  Each file can have one or more separate patches matching different versions of the file.

Builds a hash describing the patch file.
   * {identifier} = The patch file name without the patch extension.  ItemNNNN-001
   * {summary} = The descriptive text from the head of the patch file.
   * {path/to/target/file}
      * {md5_of_target} = Will match the file version that can accept this patch.
         * {patched} = Expected MD5 of the patched file.
         * {version} = Comment from PATCH record describing the target.  Parenthesis removed.
         * {patch} = The patch in unified diff format.
         * {status} = Set by checkPatch to one 3 possible values:
            * *"N/A" - neither the old nor the new MD5 matches the file.*
            * *"PATCHED" - The patch has been applied and the patched MD5 matches.*
            * *"NOT APPLIED" - The initial MD5 matches, so the patch will be applied*

The returned patch summary report:
| *Patch target* | *MD5SUM* | *Status* | *Applies to* | 
| $key | $md5 | $match | $patchRef->{$key}{$md5}{version} |

=cut

sub checkPatch {
    my $root = shift || _fixRoot();
    my $patchRef = shift;

    my $msgs = '';

    foreach my $key ( keys %{$patchRef} ) {
        next if ( $key eq 'summary' );
        next if ( $key eq 'error' );
        next if ( $key eq 'identifier' );
        foreach my $md5 ( keys %{ $patchRef->{$key} } ) {

            my $file = mapTarget( $root, $key );
            $msgs .= "| $key | | | Target Missing |\n" unless ( -f $file );

            my $origMD5 = _getMD5($file);
            my $match =
                $origMD5 eq $md5                             ? 'NOT APPLIED'
              : $origMD5 eq $patchRef->{$key}{$md5}{patched} ? 'PATCHED'
              :                                                'N/A';
            if (   $patchRef->{$key}{$md5}{version}
                && $patchRef->{$key}{$md5}{version} !~
                m/\b\Q$Foswiki::RELEASE\E\b/ )
            {
                $match = "N/A Release";
            }
            $patchRef->{$key}{$md5}{status} = $match;
            $msgs .=
              "| $key | $md5 | $match | $patchRef->{$key}{$md5}{version} |\n";
        }
    }
    return $msgs . "\n";
}

=begin TML

---++ _fixRoot -> $filepath
This routine will determine the root of the foswiki installation by 
working backwards from the DataDir setting.  

This is copied from Foswiki::Configure::Package.

=cut

sub _fixRoot {
    my @instRoot = File::Spec->splitdir( $Foswiki::cfg{DataDir} );
    pop(@instRoot);

    my $root = File::Spec->catfile( @instRoot, 'x' );
    chop $root;
    return $root;
}

=begin TML

---++ applyPatch($root, \%patchref, $reverse ) -> $messages
This routine will process the patch hash, and apply every applicable patch in the hash.

If the $reverse flag is passed, then the patches will be rmoved from the system.

=cut

sub applyPatch {
    my $root     = shift || _fixRoot();
    my $patchRef = shift;
    my $reverse  = shift || 0;

    my $msgs  = '';
    my $match = 0;

    foreach my $key ( keys %{$patchRef} ) {
        next if ( $key eq 'summary' );
        next if ( $key eq 'error' );
        next if ( $key eq 'identifier' );
        foreach my $md5 ( keys %{ $patchRef->{$key} } ) {

            my $file = mapTarget( $root, $key );

            my $fileMD5 = _getMD5($file);
            my $wantMD5 = ($reverse) ? $patchRef->{$key}{$md5}{patched} : $md5;
            next unless ( $fileMD5 eq $wantMD5 );
            next
              if ( $patchRef->{$key}{$md5}{version}
                && $patchRef->{$key}{$md5}{version} !~
                m/\b\Q$Foswiki::RELEASE\E\b/ );

            $msgs .=
"MD5 Matched - applying patch version $patchRef->{$key}{$md5}{version}.\n";
            $match++;

            my $rc =
              Foswiki::Configure::PatchFile::updateFile( $file,
                $patchRef->{$key}{$md5}{patch}, $reverse );

            $msgs .= "$rc\n" if $rc;
        }

    }

    $msgs .=
        ( $match > 1 )  ? "$match files patched."
      : ( $match == 1 ) ? '1 file patched.'
      :                   "No files matched  patch signatures.";
    return $msgs . "\n\n";

}

=begin TML

---++ reverseDiff($diff ) -> $diff
Uses the algorithm discussed in http://stackoverflow.com/questions/3902388/permanently-reversing-a-patch-file
to reverse the patch to "undo" a previous patch.

=cut

sub reverseDiff {
    my $diff = shift;

    # Flip old and new hunk ranges
    $diff =~ s/^@@ -([^\ ]+) \+([^\ ]+) @@/@@ -$2 +$1 @@/msg;

    # Temporarily protect the filename lines
    $diff =~ s/^\+\+\+/PPP/msg;
    $diff =~ s/^---/MMM/msg;

    # Reverse the deletions and additions
    $diff =~ s/^\+/\003/msg;
    $diff =~ s/^-/+/msg;
    $diff =~ s/^\003/-/msg;

    # Flip the old and new filenames
    $diff =~ s/^MMM(.*?)\nPPP(.*?)$/---$2\n+++$1/msg;

    return $diff;
}

=begin TML

---++ backupTargets($root, \%patchref, $reverse ) -> $messages
Examine the patch and create a backup of all files that will be modified by the patch.
If a file doesn't match, or has already been previously patched, it will not be backed up.  The
file needs to be in status "NOT APPLIED"

If the $reverse flag is set, then "PATCHED" files will be backed up rather that "NOT APPLIED" files.

The backup is written to the =working/configure/backup= directory. 
   * =working/configure/backup/=
      * =ItemNNNN-NNN-yyyymmdd-hhmmss/=
         * _full path to each file being backed up_

The backup directory will be archived to either =.tgz= or =.zip= format, depending upon the tools avaliable on the system.  If no archive tool is found the directory will be left as is.

=cut

sub backupTargets {
    my $root     = shift || _fixRoot();
    my $patchRef = shift;
    my $reverse  = shift || 0;

    my $targets = ($reverse) ? 'PATCHED' : 'NOT APPLIED';

    my $msgs = '';

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
        my $file = mapTarget( $root, $key );
        next unless ( -f $file );
        foreach my $md5 ( keys %{ $patchRef->{$key} } ) {
            $bkupFiles{$key} = $file
              if ( $patchRef->{$key}{$md5}{status} eq $targets );
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

            $msgs .= "Backed up target: $file to $bkupPath/$bkupDir/$file\n";
            $backup++;
        }
        my ( $rslt, $err );
        ( $rslt, $err ) = createArchive( $bkupDir, $bkupPath, '1' );
        $rslt = "FAILED \n" . $err unless ($rslt);
        $msgs .= "Backup Archived as $rslt \n";
    }

    $msgs .=
        ( $backup > 1 )  ? "$backup files backed up."
      : ( $backup == 1 ) ? '1 file backed up.'
      :                    "No files backed up.";
    return $msgs . "\n\n";

}

sub createArchive {

    no warnings 'redefine';
    eval { require Foswiki::Configure::Util };
    unless ($@) {
        *createArchive = \&Foswiki::Configure::Util::createArchive;
        goto &Foswiki::Configure::Util::createArchive;
    }
    else {
        *createArchive = \&Foswiki::Configure::FileUtil::createArchive;
        goto &Foswiki::Configure::FileUtil::createArchive;
    }
    use warnings 'redefine';
}

sub mapTarget {

    no warnings 'redefine';
    eval { require Foswiki::Configure::Util };
    unless ($@) {
        *mapTarget = \&Foswiki::Configure::Util::mapTarget;
        goto &Foswiki::Configure::Util::mapTarget;
    }
    else {
        *mapTarget = \&Foswiki::Configure::Package::_mapTarget;
        goto &Foswiki::Configure::Package::_mapTarget;
    }
    use warnings 'redefine';
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2015 Foswiki Contributors. Foswiki Contributors
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
