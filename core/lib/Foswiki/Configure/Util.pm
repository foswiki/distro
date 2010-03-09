# See bottom of file for license and copyright information

package Foswiki::Configure::Util;

use strict;

my $br = '';

sub getScriptName {
    my @script = File::Spec->splitdir( $ENV{SCRIPT_NAME} || 'THISSCRIPT' );
    my $scriptName = pop(@script);
    $scriptName =~ s/.*[\/\\]//;    # Fix for Item3511, on Win XP
    return $scriptName;
}

# very basic tool
sub findFileOnPath {
    my $file = shift;

    $file =~ s(::)(/)g;

    foreach my $dir (@INC) {
        if ( -e "$dir/$file" ) {
            return "$dir/$file";
        }
    }
    return;
}

=begin TML

---++ StaticMethod mapTarget($root, $file )
Map a standard filename from the default paths to any alternate file
locations defined in $Foswiki::cfg.  Adjust for changes in directory
names and also Web names.

=cut


sub mapTarget {
    my $root = shift;
    my $file = shift;

    foreach my $t qw( NotifyTopicName:WebNotify HomeTopicName:WebHome WebPrefsTopicName:WebPreferences
      ) {
        my ($val, $def) = split( ':', $t);
        if ( defined $Foswiki::cfg{$val} )
        {
            $file =~
              s#^data/(.*)/$def(\.txt(?:,v)?)$#data/$1/$Foswiki::cfg{$val}$2#;
            $file =~ s#^pub/(.*)/$def/([^/]*)$#pub/$1/$Foswiki::cfg{$val}/$2#;
        }
      } 

    if ( defined $Foswiki::cfg{MimeTypesFileName} && ($file eq 'data/mime.types') ) {
        $file =~ 
              s#^data/mime\.types$#$Foswiki::cfg{MimeTypesFileName}#;
        return $file;
        }

    if ( $Foswiki::cfg{SystemWebName} ne 'System' ) {
        $file =~ s#^data/System/#data/$Foswiki::cfg{SystemWebName}/#;
        $file =~ s#^pub/System/#pub/$Foswiki::cfg{SystemWebName}/#;
    }

    if ( $Foswiki::cfg{TrashWebName} ne 'Trash' ) {
        $file =~ s#^data/Trash/#data/$Foswiki::cfg{TrashWebName}/#;
        $file =~ s#^pub/Trash/#pub/$Foswiki::cfg{TrashWebName}/#;
    }

    if ( $Foswiki::cfg{UsersWebName} ne 'Main' ) {
        $file =~ s#^data/Main/#data/$Foswiki::cfg{UsersWebName}/#;
        $file =~ s#^pub/Main/#pub/$Foswiki::cfg{UsersWebName}/#;
    }

    if ( $Foswiki::cfg{UsersWebName} ne 'Users' ) {
        $file =~ s#^data/Users/#data/$Foswiki::cfg{UsersWebName}/#;
        $file =~ s#^pub/Users/#pub/$Foswiki::cfg{UsersWebName}/#;
    }

    # Canonical symbol mappings
    foreach my $w qw( SystemWebName TrashWebName UsersWebName ) {
        if ( defined $Foswiki::cfg{$w} ) {
            $file =~ s#^data/$w/#data/$Foswiki::cfg{$w}/#;
            $file =~ s#^pub/$w/#pub/$Foswiki::cfg{$w}/#;
        }
    }

    if ( $file =~ s#^data/#$Foswiki::cfg{DataDir}/# ) {
    }
    elsif ( $file =~ s#^pub/#$Foswiki::cfg{PubDir}/# ) {
    }
    elsif ( $file =~ s#^templates/#$Foswiki::cfg{TemplateDir}/# ) {
    }
    elsif ( $file =~ s#^tools/#$Foswiki::cfg{ToolsDir}/# ) {
    }
    elsif ( $file =~ s#^locale/#$Foswiki::cfg{LocalesDir}/# ) {
    }
    elsif ( $file =~ s#^(bin/\w+)$#$root$1$Foswiki::cfg{ScriptSuffix}# )
    {

        #This makes a couple of bad assumptions
        #1. that the twiki's bin dir _is_ called bin
        #2. that any file going into there _is_ a script - making installing the
        #   .htaccess file via this machanism impossible
        #3. that softlinks are not in use (same issue below)
    }
    else {
        $file = File::Spec->catfile( $root, $file );
    }
    return $file;
}


=begin TML

---++ StaticMethod unpackArchive($archive [,$dir] )
Unpack an archive. The unpacking method is determined from the file
extension e.g. .zip, .tgz. .tar, etc. If $dir is not given, unpack
to a temporary directory, the name of which is returned.

=cut

sub unpackArchive {
    my ( $name, $dir ) = @_;
  
    $br = (caller =~ /^Foswiki::Extender/)? '' : '<br />';

    $dir ||= File::Temp::tempdir( CLEANUP => 1 );
    my $here = Cwd::getcwd();
    $here =~ /(.*)/;
    $here = $1;    # untaint current dir name
    chdir($dir);
    my $error = '';
    unless ( $name =~ /(\.zip)/i && _unzip($name)
        || $name =~ /(\.tar\.gz|\.tgz|\.tar)/ && _untar($name) )
    {
        $dir = undef;
        $error = "Failed to unpack archive $name $br\n";
    }
    chdir($here);

    return ($dir, $error);
}

sub _unzip {
    my $archive = shift;

    eval 'use Archive::Zip';
    unless ($@) {
        my $zip = Archive::Zip->new($archive);
        unless ($zip) {
            print "Could not open zip file $archive $br\n";
            return 0;
        }

        my @members = $zip->members();
        foreach my $member (@members) {
            my $file = $member->fileName();
            $file =~ /(.*)/;
            $file = $1;    #yes, we must untaint
            my $target = $file;
            my $err = $zip->extractMember( $file, $target );
            if ($err) {
                print "Failed to extract '$file' from zip file ",
                  $zip, ". Archive may be corrupt.$br\n";
                return 0;
            }
        }
    }
    else {
        print
"Archive::Zip is not installed; trying unzip on the command line$br\n";
        print `unzip $archive`;

        # On certain older versions of perl / unzip it seems the unzip results
        # in an illegal seek error. But running the same command again often
        # goes well. Seems like the 2nd pass works because the subdirectories
        # are then created. A hack but it seems to work.
        if ($!) {
            print `unzip $archive`;
            if ($!) {
                print "unzip failed: $!$br\n";
                return 0;
            }
        }
    }

    return 1;
}

sub _untar {
    my $archive = shift;


    my $compressed = ( $archive =~ /z$/i ) ? 'z' : '';

    eval 'use Archive::Tar ()';
    unless ($@) {
        my $tar = Archive::Tar->new( $archive, $compressed );
        unless ($tar) {
            print "Could not open tar file $archive $br\n";
            return 0;
        }

        my @members = $tar->list_files();
        foreach my $file (@members) {
            my $err = $tar->extract($file);
            unless ($err) {
                print 'Failed to extract ', $file, ' from tar file ',
                  $tar, ". Archive may be corrupt.$br\n";
                return 0;
            }
        }
    }
    else {
        print
"Archive::Tar is not installed; trying tar on the command-line$br\n";
        print `tar xvf$compressed $archive`;
        if ($!) {
            print "tar failed: $!\n";
            return 0;
        }
    }

    return 1;
}

# Recursively list a directory
sub listDir {
    my ( $dir, $path ) = @_;
    $path ||= '';
    $dir .= '/' unless $dir =~ /\/$/;
    my $d;
    my @names = ();
    if ( opendir( $d, "$dir$path" ) ) {
        foreach my $f ( grep { !/^\.*$/ } readdir $d ) {

            # Someone might upload a package that contains
            # a filename which, when passed to File::Copy, does something
            # evil. Check and untaint the filenames here.
            # SMELL: potential problem with unicode chars in file names? (yes)
            # TODO: should really compare to MANIFEST
            if ( $f =~ /^([-\w.,]+)$/ ) {
                $f = $1;
                if ( -d "$dir$path/$f" ) {
                    push( @names, "$path$f/" );
                    push( @names, listDir( $dir, "$path$f/" ) );
                }
                else {
                    push( @names, "$path$f" );
                }
            }
            else {
                print
"WARNING: skipping possibly unsafe file (not able to show it for the same reason :( )<br />\n";
            }
        }
        closedir($d);
    }
    return @names;
}

=begin TML

---++ StaticMethod installFiles($root, $dir, @names )
Install files listed in @names.  $root is the root of the Foswiki installation.
and $dir is the root of the source directory.  @names is the list of source files and
directories beneath the $dir directory.  They should be passed in descending directory
order.  Missing directories are created as required.  The files are mapped into non-standard
locations by the mapTarget utility routine.  If a file is read-only, it is temporarily
overridden and the mode of the file is restored after the move.

=cut

sub installFiles {
    my ( $root, $dir, @names ) = @_;

    # foreach file in list, move it to the correct place
    foreach my $file (@names) {

        # Find where it is meant to go
        my $target = Foswiki::Configure::Util::mapTarget($root,$file);

        # If a file exists where a directory will go, clean it up.
        # and then make the directory if necessary.  Need to remove
        # trailing slash from filename to clean it up.
        if ( -d "$dir/$file" ) {
            my $tf = $target;
            chop $tf if ( substr( $tf, -1 ) eq '/' );
            chmod( oct(600), "$tf") if (!-w $tf);  
            unlink $tf if (-f $tf) ;
            unless ( -e $target) {
                unless ( mkdir($target) ) {
                    return "Cannot create directory $target: $!";
                }
            }
        }

        # Temporarily save file mode if readonly
        my $mode = undef;
        if ( -e $target && !-w $target && !-d "$dir/$file") {
            $mode = (stat($target))[2];
            chmod( oct(600), "$target");
            }

        # Move or copy the file, restoring mode if needed.
        if ( -f "$dir/$file" ) {
            if ( !File::Copy::move( "$dir/$file", $target ) ) {
                if ( !File::Copy::copy( "$dir/$file", $target ) ) {
                    chmod( $mode, "$target") if (defined $mode) ;
                    return "Failed to move/copy file '$file' to $target: $!";
                    }
                }
            chmod( $mode, "$target") if (defined $mode) ;
        }
    }
}

=begin TML

---++ StaticMethod applyManifest($root, @names, \%MANIFEST )
Check each installed file against the manifest.  Apply the
mode to the file.  

=cut

sub applyManifest {
    my $root = shift;
    my $files = shift;

    # foreach file in list, apply the permissions per the manifest
    foreach my $file (@$files) {

        # Find where it is meant to go
        my $target = Foswiki::Configure::Util::mapTarget($root,$file);

        if (-f $target) {

            my $mode = $_[0]->{$file}->{perms};

            if ($mode) {
                $target = Foswiki::Sandbox::untaintUnchecked($target);
                $mode = Foswiki::Sandbox::untaintUnchecked($mode);
                chmod( oct($mode), $target);
            }
        }
    }
}

=begin TML

---++ StaticMethod removeManifestFiles($root, \%MANIFEST )
Check each installed file against the manifest.  Apply the
mode to the file.  

=cut

sub removeManifestFiles {
    my $root = shift;
    my $manifest = shift;
    my @removed;

    # foreach file in the manifest, remove the file. 
    foreach my $key ( keys( %$manifest ) ) {

        # Find where it is meant to go
        my $target = Foswiki::Configure::Util::mapTarget($root,$key);

        if (-f $target) {
            chmod( '0600', $target);
            unlink "$target";
            push (@removed, "$target");
            }
        }
    return @removed;
    }
=begin TML

---++ StaticMethod getPerlLocation( )
This routine will read in the first line of the bin/configure 
script and recover the location of the perl interpreter.

=cut

sub getPerlLocation {

    open (my $fh, '<', "$Foswiki::cfg{ScriptDir}/configure$Foswiki::cfg{ScriptSuffix}") 
        || return '' ;
    my $shBang  = <$fh>;
    chomp $shBang;
    $shBang =~ s/^#\!\s*(.*?)\s?(:?\s-.*)?$/$1/;
    $shBang =~ s/\s+$//;
    close ($fh);
    return $shBang;

}
=begin TML

---++ StaticMethod rewriteShbang($file, $newShbang )
This routine will read in the first line of the bin/configure 
script and recover the location of the perl interpreter.

=cut

sub rewriteShbang {
    my $file = shift;
    my $newShbang = shift;

    return unless (-f $file );

    my $savesep = $/;
    $/ = undef;
    open(my $fh, '<', $file) || return "Rewrite shbang failed:  $!";
    my $contents = <$fh>;
    close $fh;

    # Note: space inserted after #! - needed on some flavors of Unix
    if( $contents =~ s/^#!\s*\S+/#! $newShbang/s ) {
        my $mode = (stat($file))[2];
        require Foswiki::Sandbox;
        $file = Foswiki::Sandbox::untaintUnchecked($file);
        chmod( oct(600), "$file");
        open(my $fh, '>', $file) || return "Rewrite shbang failed:  $!";
        print $fh  $contents;
        close $fh;
        $mode = Foswiki::Sandbox::untaintUnchecked($mode);
        chmod( $mode, "$file");
    } 
    $/ = $savesep;
}

=begin TML

---++ StaticMethod extractPkgData ($root, $extension,  \%Manifest, \%Dependency )
This routine looks for the $extension_installer or 
$extension_installer.pl and extracts the manifest
from the installer.  Manifest hash is passed to the routine by 
references, and updated with the extracted manifest 

->{filename}->{ci}      Flag if file should be "checked in"
->{filename}->{perms}   File permissions
->{filename}->{MD5}     MD5 of file (if available)

=cut

sub extractPkgData {
    my $root = shift;
    my $extension = shift;
    #$_[0] - reference to manifest hash
    #$_[1] - reference to dependency hash

    my $file;
    if (-e "$root/${extension}_installer") {
       $file = "$root/${extension}_installer"; 
    } else {
       if (-e "$root/${extension}_installer.pl") {
           $file = "$root/${extension}_installer.pl";
       } else {
           return "ERROR - Extension $extension package not found ";
           }
    }     

    return unless ($file);

    open(my $fh, '<', $file) || return "Extract manfiest failed: $file -  $!";

    while (<$fh>) {
        if ( $_ eq "__DATA__\n" ) {
            last;
         }
    }

    my $found = '';
    while (<$fh>) {
       if ( $_ eq "<<<< MANIFEST >>>>\n" ) {
           $found = 'M1';
           next;
       } else {
           if ( $_ eq "<<<< MANIFEST2 >>>>\n" ) { 
               $found = 'M2';
               next;
           } else {
               if ( $_ eq "<<<< DEPENDENCIES >>>>\n" ) { 
                   $found = 'D';
                   next;
               }
           }
       }

       if ($found eq 'M1' || $found eq 'M2' ) {
          if ( $_ eq "\n") {
             $found = '';
             next;
          }
          chomp $_;
          _parseManifest ( $_[0], $_, ($found eq 'M2') );
          next;
       }

       if ($found eq 'D' ) {
          if ( $_ eq "\n") {
             $found = '';
             next;
          }
          chomp $_;
          _parseDependency ( $_[1], $_ );
          next;
       }
    }
    
    close $fh;
    return 0;
}

=begin TML

---++ StaticMethod _parseManifest ( \%Manifest, $line, $v2)
Parse the manifest line into the manifest hash.  If $v2 is
true, use the version 2 format containing the MD5 sum of 
the file.

->{filename}->{ci}      Flag if file should be "checked in"
->{filename}->{perms}   File permissions
->{filename}->{MD5}     MD5 of file (if available)

=cut

sub _parseManifest {

    my $file = '';
    my $perms = '';
    my $md5 = '';
    my $desc = '';

    if ( $_[2] ) {
        ( $file, $perms, $md5, $desc ) = split( ',', $_[1], 4 ) ; 
    } else {
        ( $file, $perms, $desc ) = split( ',', $_[1], 3 );
    }

    return unless ($file);

    $_[0]->{$file}->{ci} = ( $desc =~ /\(noci\)/ ? 0 : 1 );
    $_[0]->{$file}->{perms} = $perms;
    $_[0]->{$file}->{md5} = $md5 if ($md5);

}

=begin TML

---++ StaticMethod _parseDependency ( \%DEPENDENCY, $line)
Parse the manifest line into the manifest hash.  

=cut

sub _parseDependency {

    require Foswiki::Sandbox;

    my $warn = undef;
    my ( $module, $condition, $trigger, $type, $desc ) =
        split( ',', $_[1], 5 );

    return unless ($module);
   
    if ( $type =~ m/cpan|perl/i ) {
        $module  = Foswiki::Sandbox::untaint( $module, \&_validatePerlModule );
    }   

    $_[0]->{$module}->{condition} = $condition;
    $_[0]->{$module}->{trigger} = $trigger;
    $_[0]->{$module}->{type} = $type ;
    $_[0]->{$module}->{desc} = $desc ;
    $_[0]->{$module}->{warning} = $warn ;

}

# This is used to ensure the perl module dependencies
# provided by the module are real module names, and not some random garbage
# which could be potentially insecure.
sub _validatePerlModule {
    my $module = shift;
    # Remove all non alpha-numeric caracters and :
    # Do not use \w as this is localized, and might be tainted
    my $replacements = $module =~ s/[^a-zA-Z:_0-9]//g;
    #my $warn = 'validatePerlModule removed '
    #  . $replacements
    #  . ' characters, leading to '
    #  . $module . "\n"
    #  if $replacements;
    #print "$module - $replacements - $warn \n";
    return $module;
}


1;
__DATA__
#
# Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008-2009 Foswiki Contributors. All Rights Reserved.
# Foswiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
#
# Copyright (C) 2000-2006 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.
#
