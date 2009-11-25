# See bottom of file for license and copyright information

package Foswiki::Configure::UIs::EXTEND;

use strict;

use Foswiki::Configure::UI ();
our @ISA = ('Foswiki::Configure::UI');
use File::Temp ();
use File::Copy ();
use File::Spec ();
use Cwd        ();

# This UI uses *print* rather than gathering output. This is to give
# the caller early feedback.
# Note: changed this to present information grouped
sub ui {
    my $this  = shift;
    my $query = $Foswiki::query;

    $this->findRepositories();

    my @remove = $query->param('remove');
    foreach my $extension (@remove) {
        $extension =~ /(.*)\/(\w+)$/;
        my $repositoryPath = $1;
        my $extensionName = $2;
        print "Bad extension name" unless $extensionName && $repositoryPath;

        $this->_uninstall($repositoryPath, $extensionName);
    }

    my @add = $query->param('add');
    foreach my $extension (@add) {
        $extension =~ /(.*)\/(\w+)$/;
        my $repositoryPath = $1;
        my $extensionName = $2;
        print "Bad extension name" unless $extensionName && $repositoryPath;

        $this->_install($repositoryPath, $extensionName);
    }
    return '';
}

sub _install {
    my ($this, $repositoryPath, $extension) = @_;

    my $feedback = '';
    $feedback .= "<h3 style='margin-top:0'>Installing $extension</h3>";
    
    my $repository = $this->getRepository( $repositoryPath );
    if ( !$repository ) {
        $feedback .= $this->ERROR( "Repository not found. <pre> "
                              . $repository."</pre>");
        _printFeedback($feedback);
        return;
    }
    
    my $ext = '.tgz';
    my $arf = $repository->{pub} . $extension . '/' . $extension . $ext;
    my $ar;
    
    $feedback .= "Fetching <code>$arf</code>...<br />\n";

    my $response = $this->getUrl($arf);
    if ( !$response->is_error() ) {
        eval { $ar = $response->content(); };
    }
    else {
        $@ = $response->message();
    }
    
    if ($@) {
        $feedback .= $this->WARN(<<HERE);
I can't download $arf because of the following error:
<pre>$@</pre>
HERE
        _printFeedback($feedback);
        return;
    }

    if ( !defined($ar) ) {
        $feedback .= $this->WARN(<<HERE);
Extension may not have been packaged correctly.
Trying for a .zip file instead.
HERE
        $ext = '.zip';
        $arf = $repository->{pub} . $extension . '/' . $extension . $ext;
        $feedback .= "Fetching $arf...<br />\n";
        $response = $this->getUrl($arf);
        if ( !$response->is_error() ) {
            eval { $ar = $response->content(); };
        }
        else {
            $@ = $response->message();
        }
        if ($@) {
            $feedback .= $this->WARN(<<HERE);
I can't download $arf because of the following error:
<pre>$@</pre>
HERE
            undef $ar;
        }
    }
    
    unless ($ar) {
        $feedback .= $this->ERROR(<<MESS);
Please follow the published process for manual installation from the
command line.
MESS
        _printFeedback($feedback);
        return;
    }
    
    # Strip HTTP headers if necessary
    $ar =~ s/^HTTP(.*?)\r\n\r\n//sm;
        
    # Save it somewhere it will be cleaned up
    my ( $fh, $tmpfilename ) =
      File::Temp::tempfile( SUFFIX => $ext, UNLINK => 1 );
    binmode($fh);
    print $fh $ar;
    $fh->close();

    $feedback .= "Unpacking...<br />\n";
    my ($dir, $error) = _unpackArchive($tmpfilename);
    $feedback .= "$error<br />\n" if $error;
    
    my @names = _listDir($dir);
    
    # install the contents
    my $installScript = undef;
    my $query = $Foswiki::query;
    unless ( $query->param('confirm') ) {
        my $unpackedFeedback = '';
        foreach my $file (@names) {
            my $ef = $this->_findTarget($file);
            $unpackedFeedback .= "$file\n";
            if ( $file =~ /^${extension}_installer(\.pl)?$/ ) {
                $installScript = $ef;
            }
        }
        $feedback .= "<pre>$unpackedFeedback</pre>" if $unpackedFeedback;
        unless ($installScript) {
            $feedback .= $this->WARN("No installer script found in archive");
        }
    }
    
    # foreach file in archive, move it to the correct place
    foreach my $file (@names) {
        
        # The file may already have been moved along with its directory
        next unless -e "$dir/$file";
        
        # Find where it is meant to go
        my $ef = $this->_findTarget($file);
        if ( -e $ef && !-d $ef && !-w $ef ) {
            $feedback .= $this->ERROR("No permission to write to $ef");
            $feedback .= "Installation terminated";
            _printFeedback($feedback);
            return 0;
        }
        elsif ( !-d $ef ) {
            if ( -d "$dir/$file" ) {
                unless ( mkdir($ef) ) {
                    $feedback .= $this->ERROR("Cannot create directory $ef: $!");
                    $feedback .= "Installation terminated";
                    _printFeedback($feedback);
                    die();
                }
            }
            elsif ( !File::Copy::move( "$dir/$file", $ef ) ) {
                $feedback .=  $this->ERROR("Failed to move file '$file' to $ef: $!");
                $feedback .= "Installation terminated";
                _printFeedback($feedback);
                return 0;
            }
        }
    }
    
    if ( $installScript && -e $installScript ) {
        
        # invoke the installer script.
        # SMELL: Not sure yet how to handle
        # interaction if the script ignores -a. At the moment it
        # will just hang :-(
        chdir( $this->{root} );
        unshift( @ARGV, '-a' );    # don't prompt
        unshift( @ARGV, '-d' );    # yes, you can download
        unshift( @ARGV, '-u' );    # already unpacked
        unshift( @ARGV, '-c' );    # do not use CPAN
        # Note: -r not passed to the script, so it will _not_ try to
        # re-use existing archives found on disc to resolve dependencies.
        $feedback .= "Running <code>$installScript</code>...<br />";
        no warnings 'redefine';
        print '<!--';
        do $installScript;
        print '-->';
        use warnings 'redefine';
        if ($@) {
            $feedback .=  $this->ERROR( $@ );
            _printFeedback($feedback);
            return;
        }
        if ($@) {
            $feedback .= $this->ERROR(<<HERE);
Installer returned errors:
<pre>$@</pre>
You may be able to resolve these errors and complete the installation
from the command line, so I will leave the installed files where they are.
HERE
        }
        else {
            # OK
            $feedback .= $this->NOTE("Installer ran without errors");
        }
        chdir( $this->{bin} );
    }
    
    if ( $this->{warnings} ) {
        $feedback .= $this->NOTE( "Installation finished with $this->{errors} error"
                             . ( $this->{errors} == 1 ? '' : 's' )
                               . " and $this->{warnings} warning"
                                 . ( $this->{warnings} == 1 ? '' : 's' ) );
    }
    else {
        # OK
        $feedback .= $this->NOTE_OK( 'Installation finished' );
    }
    unless ($installScript) {
        $feedback .= $this->WARN(<<HERE);
You should test this installation very carefully, as there is no installer
script. This suggests that $arf may have been generated manually, and may
require further manual configuration.
HERE
    }
    if ( $extension =~ /Plugin$/ ) {
        $feedback .= $this->NOTE(<<HERE);
Note: Before you can use newly installed plugins, you must enable them in the
"Plugins" section in the main page.
HERE
    }
    _printFeedback($feedback);
}

sub _printFeedback {
	my ($feedback) = @_;
	
	print "<div class='configureMessageBox foswikiAlert'>$feedback</div>";
}

sub _uninstall {
    my ($this, $repositoryPath, $extension) = @_;

    my $feedback = '';
    $feedback .= "<h3 style='margin-top:0'>Uninstalling $extension</h3>";
    
    # find the uninstaller
    my $query = $Foswiki::query;
    my $file = "${extension}_installer";
    my $installScript = $this->_findTarget($file);

    unless ($installScript && -e $installScript) {
        $feedback .= $this->WARN("No $installScript found - cannot uninstall");
        _printFeedback($feedback);
        return;
    }
  
    # invoke the installer script.
    # SMELL: Not sure yet how to handle
    # interaction if the script ignores -a. At the moment it
    # will just hang :-(
    chdir( $this->{root} );
    unshift( @ARGV, '-a' );    # don't prompt
    unshift( @ARGV, '-uninstall' );
    eval {
        no warnings 'redefine';
        print '<!--';
        do $installScript;
        print '-->';
        use warnings 'redefine';
    };
    if ($@) {
        $feedback .= $this->ERROR( $@ );
        _printFeedback($feedback);
        return;
    }
    if ($@) {
        $feedback .= $this->ERROR(<<HERE);
Uninstall returned errors:
<pre>$@</pre>
You may be able to resolve these errors and complete the installation
from the command line, so I will leave the installed files where they are.
HERE
    }
    else {
        # OK
        $feedback .= $this->NOTE("Installer ran without errors");
    }
    chdir( $this->{bin} );
    
    if ( $this->{warnings} ) {
        $feedback .= $this->NOTE( "Installation finished with $this->{errors} error"
                             . ( $this->{errors} == 1 ? '' : 's' )
                               . " and $this->{warnings} warning"
                                 . ( $this->{warnings} == 1 ? '' : 's' ) );
    }
    else {
        # OK
        $feedback .= $this->NOTE_OK( 'Uninstallation finished' );
    }

    if ( $extension =~ /Plugin$/ ) {
        $feedback .= $this->NOTE(<<HERE);
Note: Don't forget to disable uninstalled plugins in the
"Plugins" section in the main page.
HERE
    }
    _printFeedback($feedback);
}

# Find the installation target of a single file. This involves remapping
# through the settings in LocalSite.cfg. If the target is not remapped, then
# the file is installed relative to the root, which is the directory
# immediately above bin.
sub _findTarget {
    my ( $this, $file ) = @_;

    if ( $file =~ s#^data/#$Foswiki::cfg{DataDir}/# ) {
    }
    elsif ( $file =~ s#^pub/#$Foswiki::cfg{PubDir}/# ) {
    }
    elsif ( $file =~ s#^templates/#$Foswiki::cfg{TemplateDir}/# ) {
    }
    elsif ( $file =~ s#^locale/#$Foswiki::cfg{LocalesDir}/# ) {
    }
    elsif ( $file =~ s#^(bin/\w+)$#$this->{root}$1$Foswiki::cfg{ScriptSuffix}# )
    {

        #This makes a couple of bad assumptions
        #1. that the twiki's bin dir _is_ called bin
        #2. that any file going into there _is_ a script - making installing the
        #   .htaccess file via this machanism impossible
        #3. that softlinks are not in use (same issue below)
    }
    else {
        $file = File::Spec->catfile( $this->{root}, $file );
    }
    return $file;
}

# Recursively list a directory
sub _listDir {
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
                    push( @names, _listDir( $dir, "$path$f/" ) );
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

---++ StaticMethod _unpackArchive($archive [,$dir] )
Unpack an archive. The unpacking method is determined from the file
extension e.g. .zip, .tgz. .tar, etc. If $dir is not given, unpack
to a temporary directory, the name of which is returned.

=cut

sub _unpackArchive {
    my ( $name, $dir ) = @_;

    $dir ||= File::Temp::tempdir( CLEANUP => 1 );
    my $here = Cwd::getcwd();
    $here =~ /(.*)/;
    $here = $1;    # untaint current dir name
    chdir($dir);
    my $error;
    unless ( $name =~ /(\.zip)/i && _unzip($name)
        || $name =~ /(\.tar\.gz|\.tgz|\.tar)/ && _untar($name) )
    {
        $dir = undef;
        $error = "Failed to unpack archive $name";
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
            print "Could not open zip file $archive<br />\n";
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
                  $zip, ". Archive may be corrupt.<br />\n";
                return 0;
            }
        }
    }
    else {
        print
"Archive::Zip is not installed; trying unzip on the command line<br />\n";
        print `unzip $archive`;

        # On certain older versions of perl / unzip it seems the unzip results
        # in an illegal seek error. But running the same command again often
        # goes well. Seems like the 2nd pass works because the subdirectories
        # are then created. A hack but it seems to work.
        if ($!) {
            print `unzip $archive`;
            if ($!) {
                print "unzip failed: $!\n";
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
            print "Could not open tar file $archive<br />\n";
            return 0;
        }

        my @members = $tar->list_files();
        foreach my $file (@members) {
            my $err = $tar->extract($file);
            unless ($err) {
                print 'Failed to extract ', $file, ' from tar file ',
                  $tar, ". Archive may be corrupt.<br />\n";
                return 0;
            }
        }
    }
    else {
        print
"Archive::Tar is not installed; trying tar on the command-line<br />\n";
        print `tar xvf$compressed $archive`;
        if ($!) {
            print "tar failed: $!\n";
            return 0;
        }
    }

    return 1;
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
