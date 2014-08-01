# See bottom of file for license and copyright information

package Foswiki::Configure::Util;

use strict;
use warnings;

# Compatibility with old scripts

sub getScriptName {
    require Foswiki::Configure::CGI;
    if (1) {    # DEBUG find old callers
        print STDERR __PACKAGE__
          . "getScriptName called from "
          . join( ' ', ( caller(1) )[ 3, 1, 2 ] ) . "\n";
    }
    no warnings 'redefine';
    *getScriptName = \&Foswiki::Configure::CGI::getScriptName;
    goto &Foswiki::Configure::CGI::getScriptName;
}

=begin TML

---++ StaticMethod createArchive($name, $dir, $delete )
Create an archive of the passed directory. 
   * $name is the directory to be backed up _and_ the filename of the archive to be created.  $name will be given a suffix of the backup type - depends on what type of backup tools are installed.
   * $dir is the root directory of the backups - typically the working/configure/backup directory
   * $delete - set if the directory being backed up should be deleted after archive is created.

=cut

sub createArchive {
    my ( $name, $dir, $delete, $test ) = @_;
    eval { use File::Path qw(rmtree) };

    my $file    = undef;
    my $results = '';
    my $warn    = '';

    my $here = Cwd::getcwd();
    $here =~ /(.*)/;
    $here = $1;    # untaint current dir name

    return ( undef, "Directory $dir/$name does not exist \n" )
      unless ( -e "$dir/$name" && -d "$dir/$name" );

    chdir("$dir/$name");

    if ( !defined $test || ( defined $test && $test eq 'tar' ) ) {
        $results .= `tar -czvf "../$name.tgz" .`;

        if ( $results && !$@ ) {
            $file = "$dir/$name.tgz";
        }
    }

    unless ($results) {
        $warn .= "tar command failed $!, trying zip \n";

        if ( !defined $test || ( defined $test && $test eq 'zip' ) ) {
            $results .= `zip -r "../$name.zip" .`;

            if ( $results && !$@ ) {
                $file = "$dir/$name.zip";
            }
        }

        unless ($results) {
            $warn .= "zip failed $!, trying perl routines \n";

            if ( !defined $test || ( defined $test && $test eq 'Ptar' ) ) {
                my @flist = Foswiki::Configure::Util::listDir( '.', 1 );
                $results = _tar( "../$name.tgz", \@flist );

                if ($results) {
                    $file = "$dir/$name.tgz";
                }
            }

            unless ($results) {
                $warn .= "Perl Archive::Tar failed - trying zip \n";

                if ( !defined $test || ( defined $test && $test eq 'Pzip' ) ) {
                    my @flist = Foswiki::Configure::Util::listDir( '.', 1 );
                    $results = _zip( "../$name.zip", \@flist );

                    if ($results) {
                        $file = "$dir/$name.zip";
                    }
                    else {
                        $warn .=
"Perl Archive::Zip failed - Backup directory remains \n";
                    }
                }
            }
        }
    }

    chdir($here);

    return ( undef, $warn ) unless ($results);

    rmtree("$dir/$name") if ($delete);
    return ( $file, $results );

}

sub _zip {
    my $archive = shift;
    my $files   = shift;
    my $err;

    eval 'use Archive::Zip ( )';
    unless ($@) {
        my $zip = Archive::Zip->new();
        unless ($zip) {
            return 0;
        }

        # Note:  Archive::Zip addTree fails with taint errors.
        # Workaround was to add each file individually
        foreach my $f (@$files) {
            $zip->addFile($f);
        }
        $err = $zip->writeToFileNamed("$archive");
        return join( "\n", $zip->memberNames() ) unless ($err);
    }

    return 0;
}

sub _tar {
    my $archive = shift;
    my $files   = shift;

    eval 'use Archive::Tar ()';
    unless ($@) {
        my $tgz = Archive::Tar->new();
        return 0 unless ($tgz);
        $tgz->add_files(@$files);
        $tgz->write( "$archive", 7 );
        return join( "\n", $tgz->list_files() );
    }
    return 0;
}

=begin TML

---++ StaticMethod unpackArchive($archive [,$dir] )
Unpack an archive. The unpacking method is determined from the file
extension e.g. .zip, .tgz. .tar, etc. If $dir is not given, unpack
to a temporary directory, the name of which is returned.

=cut

sub unpackArchive {
    my ( $name, $dir ) = @_;

    $dir ||= File::Temp::tempdir( CLEANUP => 1 );
    my $here = Cwd::getcwd();
    $here =~ /(.*)/;
    $here = $1;    # untaint current dir name
    chdir($dir);
    my $error = "Failed to unpack archive $name\n";

    if ( $name =~ m/\.zip$/i ) {
        $error = _unzip($name);
        $error .= "Failed to unpack archive $name\n" if ($error);
    }
    else {
        if ( $name =~ m/(\.tar\.gz|\.tgz|\.tar)$/i ) {
            $error = _untar($name);
            $error .= "Failed to unpack archive $name\n" if ($error);
        }
    }
    $dir = undef if ($error);
    chdir($here);

    return ( $dir, $error );
}

sub _unzip {
    my $archive = shift;
    my $usezip  = 0;       # Set true if shell zip is required
    my $error   = '';

    eval 'use Archive::Zip ();
          1;'
      or do {
        $usezip = 1;
      };

    my $zip;
    unless ($usezip) {
        eval {
            $zip = Archive::Zip->new($archive);
            unless ($zip) {
                die "unzip failed: Could not open zip file $archive\n";
            }
            1;
        } or do {
            $error = $@;
        };

        return $error if ($error);

        my @members = $zip->members();
        foreach my $member (@members) {
            my $file = $member->fileName();
            $file =~ /^(.*)$/;
            $file = $1;    #yes, we must untaint
            my $target = $file;
            my $dest   = Cwd::getcwd();
            ($dest) = $dest =~ m/^(.*)$/;

            #SMELL:  Archive::Zip->extractMember( $file)  would be better to use
            # but it has taint issues on Perl 5.12.
            my $contents = $zip->contents($file);
            if ($contents) {
                my ( $vol, $dir, $fn ) = File::Spec->splitpath($file);
                File::Path::mkpath("$dest/$dir");
                open( my $fh, '>', "$dest/$file" )
                  || die "Unable to open $dest/$file \n $! \n\n ";
                binmode $fh;
                print $fh $contents;
                close($fh);
            }
        }
    }
    else {
        eval {
            my $out = `unzip -n $archive`;
            die "$? - $!" if ($?);
            1;
        } or do {
            $error = "unzip failed $@ \n";
            $@     = '';
        };
    }

    return $error;
}

sub _untar {
    my $archive = shift;

    my $compressed = ( $archive =~ /z$/i ) ? 'z' : '';
    my $usetar     = 0;
    my $error      = '';

    eval 'use Archive::Tar ();
          1;'
      or do {
        $usetar = 1;
      };

    my $tar;
    unless ($usetar) {
        eval {
            $tar = Archive::Tar->new( $archive, $compressed );
            unless ($tar) {
                die "Could not open tar file $archive\n";
            }
            1;
        } or do {
            $error = $@;
        };

        return $error if ($error);

        my @members = $tar->list_files();
        foreach my $file (@members) {
            my $err = $tar->extract($file);
            unless ($err) {
                return 'Failed to extract ', $file, ' from tar file ',
                  $tar, ". Archive may be corrupt.\n";
            }
        }
    }
    else {
        eval {
            `tar xvf$compressed $archive`;
            die "$? - $!" if ($?);
            1;
        } or do {
            $error = "tar failed: $@\n";
            $@     = '';
          }
    }

    return $error;
}

=begin TML

---++ StaticMethod listDir($dir, [$dflag], [$path] )
Recursively list the files in directory $dir. Optional $dflag can be set to 1
to cause the list to exclude the directory names from the list. 

If $path is used internally for the recursive directory list. It is
appended to the Directory.  The list of files in @names is relative to the
$dir directory.   Subroutine called recursively for each subdirectory
encountered.

=cut

# Recursively list a directory
sub listDir {
    my ( $dir, $dflag, $path ) = @_;
    $path  ||= '';
    $dflag ||= '';
    $dir .= '/' unless $dir =~ /\/$/;
    my $d;
    my @names = ();
    if ( opendir( $d, "$dir$path" ) ) {
        foreach my $f ( grep { !/^\.*$/ } readdir $d ) {

            # Someone might upload a package that contains
            # a filename which, when passed to File::Copy, does something
            # evil. Check and untaint the filenames here.
            # SMELL: potential problem with unicode chars in file names? (yes)
            if ( $f =~ /^([-\w.,]+)$/ ) {
                $f = $1;
                if ( -d "$dir$path/$f" ) {
                    push( @names, "$path$f/" ) unless ($dflag);
                    push( @names, listDir( $dir, $dflag, "$path$f/" ) );
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

---++ StaticMethod mapTarget($root, $file )
Map a standard filename from the default paths to any alternate file
locations defined in $Foswiki::cfg.  Adjust for changes in directory
names and also Web names.   The following mapping is performed:

---+++ Web names

   * =SystemWebName=
   * =TrashWebname=
   * =UsersWebname=
   * =SandboxWebName= ( Future - see  Foswikitask:Item8744 )

---+++ Topic Names
   * =NotifyTopicName=
   * =HomeTopicName=
   * =WebPrefsTopicName= 

---+++ Directory locations
   * =DataDir=
   * =PubDir=
   * =WorkingDir=
   * =TemplateDir=
   * =ToolsDir=
   * =LocalesDir=
   * =ScriptDir=

---+++ Other 
   * =ScriptSuffix=
   * =MimeTypesFileName=

=cut

sub mapTarget {
    my $root = shift;
    my $file = shift;

    # Workaround for Tasks.Item8744 feature proposal
    my $sandbox = $Foswiki::cfg{SandboxWebName} || 'Sandbox';

    foreach my $t (
        qw( NotifyTopicName:WebNotify HomeTopicName:WebHome WebPrefsTopicName:WebPreferences
        )
      )
    {
        my ( $val, $def ) = split( ':', $t );
        if ( defined $Foswiki::cfg{$val} ) {
            $file =~
              s#^data/(.*)/$def(\.txt(?:,v)?)$#data/$1/$Foswiki::cfg{$val}$2#;
            $file =~ s#^pub/(.*)/$def/([^/]*)$#pub/$1/$Foswiki::cfg{$val}/$2#;
        }
    }

    if ( defined $Foswiki::cfg{MimeTypesFileName}
        && ( $file eq 'data/mime.types' ) )
    {
        $file =~ s#^data/mime\.types$#$Foswiki::cfg{MimeTypesFileName}#;
        return $file;
    }

    if ( $sandbox ne 'Sandbox' ) {
        $file =~ s#^data/Sandbox/#data/$sandbox/#;
        $file =~ s#^pub/Sandbox/#pub/$sandbox/#;
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
#foreach my $w (qw( SystemWebName TrashWebName UsersWebName SandboxWebName )) {  #Waiting for Item8744
    foreach my $w (qw( SystemWebName TrashWebName UsersWebName )) {
        if ( defined $Foswiki::cfg{$w} ) {
            $file =~ s#^data/$w/#data/$Foswiki::cfg{$w}/#;
            $file =~ s#^pub/$w/#pub/$Foswiki::cfg{$w}/#;
        }
    }
    $file =~ s#^data/Sandbox/#data/$sandbox/#;
    $file =~ s#^pub/Sandbox/#pub/$sandbox/#;

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
    elsif ( $file =~ s#^lib/#$Foswiki::foswikiLibPath/# ) {
    }
    elsif ( $file =~
        s#^bin/(.*)$#$Foswiki::cfg{ScriptDir}/$1$Foswiki::cfg{ScriptSuffix}# )
    {

        #This makes a couple of bad assumptions
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

---++ StaticMethod getMappedWebTopic( $file )
Extract a mapped Web,TopicName from the default path from a topic in the manifest.
(Works for topics, not attachments)

Returns ($web, $topic) 

---+++ Web names

   * =SystemWebName=
   * =TrashWebname=
   * =UsersWebname=
   * =SandboxWebName= ( Future - see  Foswikitask:Item8744 )

---+++ Topic Names
   * =NotifyTopicName=
   * =HomeTopicName=
   * =WebPrefsTopicName= 

=cut

sub getMappedWebTopic {
    my $file = shift;

    # Workaround for Tasks.Item8744 feature proposal
    my $sandbox = $Foswiki::cfg{SandboxWebName} || 'Sandbox';

    foreach my $t (
        qw( NotifyTopicName:WebNotify HomeTopicName:WebHome WebPrefsTopicName:WebPreferences
        )
      )
    {
        my ( $val, $def ) = split( ':', $t );
        if ( defined $Foswiki::cfg{$val} ) {
            $file =~
              s#^data/(.*)/$def(\.txt(?:,v)?)$#data/$1/$Foswiki::cfg{$val}$2#;
        }
    }

    if ( $sandbox ne 'Sandbox' ) {
        $file =~ s#^data/Sandbox/#$sandbox/#;
    }

    if ( $Foswiki::cfg{SystemWebName} ne 'System' ) {
        $file =~ s#^data/System/#$Foswiki::cfg{SystemWebName}/#;
    }

    if ( $Foswiki::cfg{TrashWebName} ne 'Trash' ) {
        $file =~ s#^data/Trash/#$Foswiki::cfg{TrashWebName}/#;
    }

    if ( $Foswiki::cfg{UsersWebName} ne 'Main' ) {
        $file =~ s#^data/Main/#$Foswiki::cfg{UsersWebName}/#;
    }

    if ( $Foswiki::cfg{UsersWebName} ne 'Users' ) {
        $file =~ s#^data/Users/#$Foswiki::cfg{UsersWebName}/#;
    }

# Canonical symbol mappings
#foreach my $w (qw( SystemWebName TrashWebName UsersWebName SandboxWebName )) {  #Waiting for Item8744
    foreach my $w (qw( SystemWebName TrashWebName UsersWebName )) {
        if ( defined $Foswiki::cfg{$w} ) {
            $file =~ s#^data/$w/#$Foswiki::cfg{$w}/#;
        }
    }
    $file =~ s#^data/Sandbox/#$sandbox/#;

    my ( $tweb, $ttopic ) = $file =~ /^(?:data\/)?(.*)\/(\w+).txt$/;

    return ( $tweb, $ttopic );
}

=begin TML

---++ StaticMethod getPerlLocation( )
This routine will read in the first line of the bin/configure 
script and recover the location of the perl interpreter. 

Optional parameter is file used to retrieve the shebang.  If not 
specified, defaults to the configure script

=cut

sub getPerlLocation {

    my $file = shift
      || "$Foswiki::cfg{ScriptDir}/configure$Foswiki::cfg{ScriptSuffix}";

    local $/ = "\n";
    open( my $fh, '<', "$file" )
      || return "";
    my $Shebang = <$fh>;
    chomp $Shebang;
    ($Shebang) = $Shebang =~ m/^#\!\s*(.*?perl.*?)\s?(?:\s-.*?)?$/;
    $Shebang =~ s/\s+$//;
    close($fh);
    return $Shebang;

}

=begin TML

---++ StaticMethod rewriteShebang($file, $newShebang )
This routine will rewrite the Shebang line of the target script
with the specified script name.

=cut

sub rewriteShebang {
    my $file       = shift;
    my $newShebang = shift;

    return 'Not a file' unless ( -f $file );
    return 'Missing Shebang' unless $newShebang;

    local $/ = undef;
    open( my $fh, '<', $file ) || return "Rewrite shebang failed:  $!";
    my $contents = <$fh>;
    close $fh;

    my $firstline = substr( $contents, 0, index( $contents, "\n" ) );
    ( my $match ) = $firstline =~ m/^#\!\s*(.*?perl.*?)\s?(?:\s-.*?)?$/ms;
    $match = '' unless $match;

    return "Not a perl script" unless ($match);

    # Note: space inserted after #! - needed on some flavors of Unix
    my $perlIdx = index( $contents, $match );
    substr( $contents, $perlIdx, length($match) ) =
      ( substr( $contents, $perlIdx - 1, 1 ) eq ' ' ? '' : ' ' )
      . "$newShebang";

    return "No change required"
      if ( $match eq $newShebang
        && substr( $contents, $perlIdx - 1, 1 ) eq ' ' );

    my $mode = ( stat($file) )[2];
    $file =~ /(.*)/;
    $file = $1;
    chmod( oct(600), "$file" );
    open( $fh, '>', $file ) || return "Rewrite shebang failed:  $!";
    print $fh $contents;
    close $fh;
    $mode =~ /(.*)/;
    $mode = $1;
    chmod( $mode, "$file" );

    return '';
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
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
