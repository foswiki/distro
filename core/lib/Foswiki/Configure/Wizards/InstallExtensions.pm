# See bottom of file for license and copyright information
package Foswiki::Configure::Wizards::InstallExtensions;

use strict;
use warnings;

use File::Copy ();
use File::Spec ();
use Cwd        ();

use Assert;

=begin TML

---+ package Foswiki::Configure::Wizards:InstallExtensions

Install and remove extensions

=cut

require Foswiki::Configure::Wizard;
our @ISA = ('Foswiki::Configure::Wizard');

use Foswiki::Configure::Package                    ();
use Foswiki::Configure::Dependency                 ();
use Foswiki::Configure::Wizards::ExploreExtensions ();

our $installRoot;

# (Un)Install the extensions selected by the URL parameters.
#
# This method uses *print* rather than gathering output. This is to give
# the caller early feedback.

sub add {
    my ( $this, $reporter ) = @_;
    $this->_action( 'add', $reporter );
    return undef;    # return the report
}

sub remove {
    my ( $this, $reporter ) = @_;
    $this->_action( 'remove', $reporter );
    return undef;    # return the report
}

sub _action {
    my ( $this, $action, $reporter ) = @_;

    my ( $fwi, $ver, $fwp ) =
      Foswiki::Configure::Dependency::extractModuleVersion( 'Foswiki', 1 );
    ASSERT( $fwi, "No Foswiki.pm" ) if DEBUG;

    my @instRoot = File::Spec->splitdir($fwp);
    pop(@instRoot);

    # SMELL: Force a trailing separator - Linux and Windows are inconsistent
    $installRoot = File::Spec->catfile( @instRoot, 'x' );
    chop $installRoot;

    my $processExt = ''; #$Foswiki::Configure::query->param('processExt') || '';
    my $useCache   = ''; #$Foswiki::Configure::query->param('useCache')   || '';
    my $extension = $this->param('args');
    unless ( $extension && $extension =~ /(.*)\/(\w+)$/ ) {
        $reporter->ERROR("No extension specified");
        return;
    }
    my $repositoryPath = $1;
    my $extensionName  = $2;
    print "Bad extension name" unless $extensionName && $repositoryPath;

    if ( $action eq 'add' ) {
        $this->_install( $reporter, $repositoryPath, $extensionName,
            $processExt, $useCache );
    }
    else {
        $this->_uninstall( $reporter, $repositoryPath, $extensionName,
            $processExt );
    }
}

sub _getRepository {
    my $reponame = shift;

    foreach my $place (
        Foswiki::Configure::Wizards::ExploreExtensions::findRepositories() )
    {
        return $place if $place->{name} eq $reponame;
    }
    return;
}

# unused wizard, saved from old code
sub depreport {
    my ( $this, $reporter, $repositoryPath, $extension, $processExt ) = @_;

    my $repository = _getRepository($repositoryPath);
    if ( !$repository ) {
        $reporter->ERROR("Repository not found: $repository");
        return;
    }

    my $pkg = new Foswiki::Configure::Package( $installRoot, $extension );

    my $installed;
    my $missing;
    my $plugins;
    my $depCPAN;

    $pkg->repository($repository);

    $reporter->NOTE("Running dependency check for $extension");
    my ( $loadrslt, $err ) = $pkg->loadInstaller();
    $reporter->NOTE( '<verbatim>', $loadrslt, '</verbatim>' );
    $reporter->NOTE("Dependency Report");
    ( $installed, $missing ) = $pkg->checkDependencies();
    $reporter->NOTE(" *INSTALLED* $installed") if ($installed);
    $reporter->NOTE(" *MISSING* $missing")     if ($missing);

    $err = $pkg->errors();

    $pkg->finish();
    undef $pkg;
}

sub _install {
    my ( $this, $reporter, $repositoryPath, $extension, $processExt, $useCache )
      = @_;
    my $err;

    my $repository = _getRepository($repositoryPath);
    if ( !$repository ) {
        $reporter->ERROR("Repository not found: $repository");
        return;
    }

    my $simulate = 0;
    my $nodeps   = 0;

    if ($processExt) {
        $simulate = ( $processExt eq 'sim' )   ? 1 : 0;
        $nodeps   = ( $processExt eq 'nodep' ) ? 1 : 0;
    }

    my $pkg = new Foswiki::Configure::Package(
        $installRoot,
        $extension,
        $Foswiki::Plugins::SESSION,
        {
            SIMULATE => $simulate,
            NODEPS   => $nodeps,
            USELOCAL => ( $useCache eq 'on' ) ? 1 : 0,
        }
    );

    $pkg->repository($repository);

    my ( $rslt, $plugins, $depCPAN ) = $pkg->install();

    $err = $pkg->errors();

    $reporter->NOTE($rslt);

    $pkg->finish();
    undef $pkg;

    if ($err) {
        $reporter->ERROR(
"Errors encountered during package installation.  The Extension may not be usable.",
            '<verbatim>', $err, '</verbatim>', 'Installation terminated'
        );
        return 0;
    }

    if ( $this->{warnings} ) {
        $reporter->NOTE( "Installation finished with $this->{errors} error"
              . ( $this->{errors} == 1 ? '' : 's' )
              . " and $this->{warnings} warning"
              . ( $this->{warnings} == 1 ? '' : 's' ) );
    }
    else {

        # OK
        if ( $processExt eq 'sim' ) {
            $reporter->NOTE(
                "Simulated installation of $extension and dependencies finished"
            );
        }
        else {
            $reporter->NOTE(
                "Installation of $extension and dependencies finished");
        }
        $reporter->NOTE(<<HERE);
Before proceeding, review the dependency reports of each installed
extension and resolve any dependencies as required.  <ul><li>External
dependencies are never automatically resolved by Foswiki. <li>Dependencies
noted as "Optional" will not be automatically resolved, and <li>CPAN
dependencies are not resolved by the web installer.
HERE
    }

    if ( keys %$depCPAN ) {
        $reporter->NOTE(<<HERE);
Warning:  CPAN dependencies were detected, but will not be automatically
installed by the Web installer.  The following dependencies should be
manually resolved as required. 
HERE
        foreach my $dep ( sort { lc($a) cmp lc($b) } keys %$depCPAN ) {
            $reporter->NOTE( '<verbatim>', $dep, '</verbatim>' );
        }
    }
}

sub _uninstall {
    my ( $this, $reporter, $repositoryPath, $extension, $processExt ) = @_;

    my @removed;

    my $simulate = 0;
    my $sim      = '';

    if ( $processExt && $processExt eq 'sim' ) {
        $simulate = 1;
        $sim      = "Simulated: ";
    }

    my $pkg = new Foswiki::Configure::Package(
        $installRoot,
        $extension,
        $Foswiki::Plugins::SESSION,
        {
            SIMULATE => $simulate,
            USELOCAL => 1,
        }
    );

    # For uninstall, set repository in case local installer is not found
    # it can be downloaded to recover the manifest
    my $repository = _getRepository($repositoryPath);
    if ( !$repository ) {
        $reporter->NOTE(
"Repository not found ($repositoryPath) - Local installer must exist)"
        );
    }
    else {
        $pkg->repository($repository);
    }

    $reporter->NOTE( $pkg->uninstall() );

    $pkg->finish();
    undef $pkg;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2014 Foswiki Contributors. Foswiki Contributors
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
