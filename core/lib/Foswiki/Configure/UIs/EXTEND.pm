# See bottom of file for license and copyright information

package Foswiki::Configure::UIs::EXTEND;

use strict;

use Foswiki::Configure::UI ();
our @ISA = ('Foswiki::Configure::UI');
use Foswiki::Configure::Util ();
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
    my ($dir, $error) = Foswiki::Configure::Util::unpackArchive($tmpfilename);
    $feedback .= "$error<br />\n" if $error;
    
    my @names = Foswiki::Configure::Util::listDir($dir);
    
    # install the contents
    my $installScript = undef;
    my $query = $Foswiki::query;
    unless ( $query->param('confirm') ) {
        my $unpackedFeedback = '';
        foreach my $file (@names) {
            $unpackedFeedback .= "$file\n";
            if ( $file =~ /^${extension}_installer(\.pl)?$/ ) {
                $installScript = Foswiki::Configure::Util::mapTarget($this->{root},$file);
            }
        }
        $feedback .= "<pre>$unpackedFeedback</pre>" if $unpackedFeedback;
        unless ($installScript) {
            $feedback .= $this->WARN("No installer script found in archive");
        }
    }

    # Make sure that when new Foswiki is created, it reloads the configuration
    # and expands all variables.  Configure has already loaded the config with
    # noexpand specified.
    #delete $Foswiki::cfg{ConfigurationFinished};
    #Foswiki::Configure::Load::expandValue( \$Foswiki::cfg{Log}{Dir} );
    #$Foswiki::cfg{Engine} = 'Foswiki::Engine::CLI';
    unless ( eval { require Foswiki } ) {
     die "Can't load Foswiki: $@";
    }

    # Load up a new Foswiki session so that the install can checkin topics and attchments
    # that are under revision control.
    my $user = $Foswiki::cfg{AdminUserLogin};
    my $session = new Foswiki($user);
    require Foswiki::Configure::Package;

    my $pkg = new Foswiki::Configure::Package ($this->{root}, $extension, '', $session);
    my $err = $pkg->loadInstaller($dir);  # Recover the manifest from the _installer file

    my $rslt;
    ($rslt, $err) = $pkg->createBackup($dir) unless ($err); # Create a backup of the previous install if any
    
    $feedback .= "Creating Backup...<br />\n";
    $feedback .= "<pre>$rslt </pre>";

    ($rslt, $err) = $pkg->install($dir) unless ($err); # and do the installation
    
    $feedback .= "Installing...<br />\n";
    $feedback .= "<pre>$rslt </pre>";

    $pkg->finish();
    undef $pkg;
    $session->finish();
    undef $session;

    if ($err) {
        $feedback .= $this->ERROR("$err");
        $feedback .= "Installation terminated";
        _printFeedback($feedback);
        return 0;
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
        # Remove the functions from the package, in case of multiple installations
        for ( qw( preinstall postinstall preuninstall postuninstall ) ) {
            delete $Foswiki::{$_};
        }
        print '<!--';
        do $installScript;
        print '-->';
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

    my @removed;

    require Foswiki::Configure::Package;
    my $pkg = new Foswiki::Configure::Package ($this->{root}, $extension, '');
    my $err = $pkg->loadInstaller();

    my $rslt = $pkg->createBackup();
    $feedback .= "<b>Creating Backup:</b> <br />\n<pre>$rslt</pre>" if $rslt;

    @removed = $pkg->uninstall() unless ($err);

    $pkg->finish();
    undef $pkg;

    if ($err) {
        $feedback .= $this->WARN("Error $err encountered - uninstall not completed");
        _printFeedback($feedback);
        return;
    }

    unless (scalar @removed) {
        $feedback .= $this->WARN(" Nothing to remove for $extension");
        _printFeedback($feedback);
        return;
    }

    my @plugins;
    my $unpackedFeedback = '';
    foreach my $file (@removed) {
            $unpackedFeedback .= "$file\n";
            my ($plugName) = $file =~ m/.*\/Plugins\/(.*?Plugin)\.pm$/;
            push (@plugins,  $plugName) if $plugName;
            }
    $feedback .= "<b>Removing files:</b> <br />\n<pre>$unpackedFeedback</pre>" if $unpackedFeedback;

    if ( scalar @plugins ) {
        $feedback .= $this->WARN(<<HERE);
Note: Don't forget to disable uninstalled plugins in the
"Plugins" section in the main page, listed below:
HERE
        $feedback .= "<pre>";
        foreach my $plugName (@plugins) {
            $feedback .= "$plugName \n" if $plugName;
        }
        $feedback .= "</pre>";
    }
    _printFeedback($feedback);
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
