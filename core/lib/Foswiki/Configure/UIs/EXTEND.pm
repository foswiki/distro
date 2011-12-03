# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Configure::UIs::EXTEND

Specialised UI used by =configure= to generate the extension installation
screen (and to actually perform the installation). Does not use the
conventional renderHtml interface, instead implementing a special
'install' method.

=cut

package Foswiki::Configure::UIs::EXTEND;

use strict;
use warnings;

use Foswiki::Configure::UI      ();
use Foswiki::Configure::Package ();
our @ISA = ('Foswiki::Configure::UI');
use Foswiki::Configure::Util ();

use File::Copy ();
use File::Spec ();
use Cwd        ();

my $installRoot;

=begin TML

---++ ObjectMethod install() -> $html

(Un)Install the extensions selected by the URL parameters.

This method uses *print* rather than gathering output. This is to give
the caller early feedback.

=cut

sub install {
    my $this  = shift;
    my $query = $Foswiki::query;

    #   The safest directory to use for the foswiki root is probably DataDir.
    #   bin is possibly relocated to a cgi-bin,  and pub might be in a webroot.
    #   data, locale, working, etc. are probably the most stable.   Unknown
    #   directories should be created in this directory.
    #
    my @instRoot = File::Spec->splitdir( $Foswiki::cfg{DataDir} );
    pop(@instRoot);

    # SMELL: Force a trailing separator - Linux and Windows are inconsistent
    $installRoot = File::Spec->catfile( @instRoot, 'x' );
    chop $installRoot;

    $this->findRepositories();

    my $processExt = $query->param('processExt') || '';
    my @remove     = $query->param('remove');
    my @add        = $query->param('add');

    if ( $processExt && $processExt eq 'dep' ) {
        my @extensions = sort ( @add, @remove );
        my $lastext = '';
        foreach my $extension (@extensions) {
            next if ( $lastext eq $extension );
            $lastext = $extension;
            $extension =~ /(.*)\/(\w+)$/;
            my $repositoryPath = $1;
            my $extensionName  = $2;
            print "Bad extension name" unless $extensionName && $repositoryPath;

            $this->_depreport( $repositoryPath, $extensionName );
        }
    }
    else {

        foreach my $extension (@remove) {
            $extension =~ /(.*)\/(\w+)$/;
            my $repositoryPath = $1;
            my $extensionName  = $2;
            print "Bad extension name" unless $extensionName && $repositoryPath;

            $this->_uninstall( $repositoryPath, $extensionName, $processExt );
        }

        foreach my $extension (@add) {
            $extension =~ /(.*)\/(\w+)$/;
            my $repositoryPath = $1;
            my $extensionName  = $2;
            print "Bad extension name" unless $extensionName && $repositoryPath;

            $this->_install( $repositoryPath, $extensionName, $processExt );
        }
    }

    return '';
}

sub _getSession {
    unless ( eval { require Foswiki } ) {
        die "Can't load Foswiki: $@";
    }

    # Load up a new Foswiki session so that the install can checkin
    # topics and attchments that are under revision control.
    my $user = $Foswiki::cfg{AdminUserLogin};

    # Temporarily override the password and mapping manager
    # So configure can still work if LDAP or other extensions are not functional
    $Foswiki::cfg{PasswordManager}    = 'none';
    $Foswiki::cfg{UserMappingManager} = 'Foswiki::Users::BaseUserMapping';

# SMELL: The Cache uses $Foswiki::cfg variables that are not expanded when running
# in a configure setting.   Disable the cache because the init routine fails.
# This might leave stale cache entries for topics updated by the installer.
# See Item9944 for more background.
    $Foswiki::cfg{Cache}{Enabled} = 0;

    my $session = new Foswiki($user);

    return $session;

}

sub _depreport {
    my ( $this, $repositoryPath, $extension, $processExt ) = @_;

    my $feedback = '';

    my $repository = $this->getRepository($repositoryPath);
    if ( !$repository ) {
        $feedback .= $this->ERROR(
            "Repository not found. <pre> " . $repository . "</pre>" );
        _printFeedback($feedback);
        return;
    }

    my $pkg = new Foswiki::Configure::Package( $installRoot, $extension );

    my $installed;
    my $missing;
    my $rslt = '';
    my $plugins;
    my $depCPAN;

    $pkg->repository($repository);

    $rslt = "Running dependency check for $extension";
    my ( $loadrslt, $err ) = $pkg->loadInstaller();
    $rslt .= "<pre>" . $loadrslt . "</pre>";
    $rslt .= "Dependency Report<pre>";
    ( $installed, $missing ) = $pkg->checkDependencies();
    $rslt .= "===== INSTALLED =======\n$installed\n" if ($installed);
    $rslt .= "====== MISSING ========\n$missing\n"   if ($missing);
    $rslt .= "</pre>";

    $err = $pkg->errors();

    _printFeedback($rslt);

    $pkg->finish();
    undef $pkg;
}

sub _install {
    my ( $this, $repositoryPath, $extension, $processExt ) = @_;
    my $err;

    my $feedback = '';

    my $repository = $this->getRepository($repositoryPath);
    if ( !$repository ) {
        $feedback .= $this->ERROR(
            "Repository not found. <pre> " . $repository . "</pre>" );
        _printFeedback($feedback);
        return;
    }

    my $session = $this->_getSession();

    my $simulate = 0;
    my $nodeps   = 0;

    if ($processExt) {
        $simulate = ( $processExt eq 'sim' )   ? 1 : 0;
        $nodeps   = ( $processExt eq 'nodep' ) ? 1 : 0;
    }

    my $pkg = new Foswiki::Configure::Package(
        $installRoot,
        $extension,
        $session,
        {
            SIMULATE => $simulate,
            NODEPS   => $nodeps,
        }
    );

    $pkg->repository($repository);

    my ( $rslt, $plugins, $depCPAN ) = $pkg->install();

    $err = $pkg->errors();

    _printFeedback($rslt);

    $pkg->finish();
    undef $pkg;
    $session->finish();
    undef $session;

    if ($err) {
        $feedback .= $this->ERROR(
"Errors encountered during package installation.  The Extension may not be usable. <pre>$err</pre>"
        );
        $feedback .= "Installation terminated";
        _printFeedback($feedback);
        return 0;
    }

    if ( $this->{warnings} ) {
        $feedback .=
          $this->NOTE( "Installation finished with $this->{errors} error"
              . ( $this->{errors} == 1 ? '' : 's' )
              . " and $this->{warnings} warning"
              . ( $this->{warnings} == 1 ? '' : 's' ) );
    }
    else {

        # OK
        if ( $processExt eq 'sim' ) {
            $feedback .= $this->NOTE_OK(
                "Simulated installation of $extension and dependencies finished"
            );
        }
        else {
            $feedback .= $this->NOTE_OK(
                "Installation of $extension and dependencies finished");
        }
        $feedback .= $this->NOTE(<<HERE);
Before proceeding, review the dependency reports of each installed
extension and resolve any dependencies as required.  <ul><li>External
dependencies are never automatically resolved by Foswiki. <li>Dependencies
noted as "Optional" will not be automatically resolved, and <li>CPAN
dependencies are not resolved by the web installer.
HERE
    }

    if ( keys %$depCPAN ) {
        $feedback .= $this->NOTE(<<HERE);
Warning:  CPAN dependencies were detected, but will not be automatically
installed by the Web installer.  The following dependencies should be
manually resolved as required. 
HERE
        $feedback .= "<pre>";
        foreach my $dep ( sort { lc($a) cmp lc($b) } keys %$depCPAN ) {
            $feedback .= "$dep\n";
        }
        $feedback .= "</pre>";
    }

    _printFeedback($feedback);
}

sub _printFeedback {
    my ($feedback) = @_;

    print "<div class='configureMessageBox'>$feedback</div>";
}

sub _uninstall {
    my ( $this, $repositoryPath, $extension, $processExt ) = @_;

    my $feedback = '';

    my @removed;
    my $rslt;
    my $err;

    my $simulate = 0;
    my $sim      = '';

    if ( $processExt && $processExt eq 'sim' ) {
        $simulate = 1;
        $sim      = "Simulated: ";
    }

    my $session = $this->_getSession();

    my $pkg = new Foswiki::Configure::Package(
        $installRoot,
        $extension,
        $session,
        {
            SIMULATE => $simulate,
            USELOCAL => 1,
        }
    );

    # For uninstall, set repository in case local installer is not found
    # it can be downloaded to recover the manifest
    my $repository = $this->getRepository($repositoryPath);
    if ( !$repository ) {
        $rslt .=
            "Repository not found. "
          . $repository
          . " - Local installer must exist)\n";
    }
    else {
        $pkg->repository($repository);
    }

    $feedback .= $pkg->uninstall();

    $pkg->finish();
    undef $pkg;

    $session->finish();
    undef $session;

    if ($err) {
        $feedback .=
          $this->WARN("Error $err encountered - uninstall not completed");
        _printFeedback($feedback);
        return;
    }

    _printFeedback($feedback);
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
