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

my %validArgs = (
    USELOCAL => 1,
    EXPANDED => 1,
    DIR      => 1,
    NODEPS   => 1,
    SIMULATE => 1,
    CONTINUE => 1,
    ENABLE   => 1,
);

our $installRoot;

# (Un)Install the extensions selected by the parameters.

# Common initialisation
sub _getPackage {
    my ( $this, $reporter, $module, $repo, $seen ) = @_;

# Attempt to locate an "installation root".  This is a bit tricky because of
# varied installations. bin and lib might be relocated to outside of the installation
# directory. pub, data, working and templates are jiggered with by VirtualHostingContrib
# LocalesDir seems to be about the safest option.
#
# SMELL:  We really ought to let the package installer run without the concept of
# a root directory.
    my @instRoot = File::Spec->splitdir( $Foswiki::cfg{LocalesDir} );
    pop(@instRoot);

    # SMELL: Force a trailing separator - Linux and Windows are inconsistent
    $installRoot = File::Spec->catfile( @instRoot, 'x' );
    chop $installRoot;

    my $args = $this->param('args');

    my $repository;
    foreach my $place (
        Foswiki::Configure::Wizards::ExploreExtensions::findRepositories() )
    {
        if ( $place->{name} eq $repo ) {
            $repository = $place;
            last;
        }
    }
    if ( !$repository ) {
        if ( $args->{USELOCAL} ) {
            $reporter->WARN( "Repository not found: $repo",
                "Will try to use previously downloaded local copy" );
        }
        else {
            $reporter->ERROR("Repository $repo not found\n> Cannot proceed.");
            return undef;
        }
    }

    my $pkg = Foswiki::Configure::Package->new(
        root       => $installRoot,
        repository => $repository,
        seen       => $seen,
        module     => $module,
        DIR        => $args->{DIR},
        USELOCAL   => $args->{USELOCAL},
        EXPANDED   => $args->{EXPANDED},
        NODEPS     => $args->{NODEPS},
        SIMULATE   => $args->{SIMULATE},
        CONTINUE   => $args->{CONTINUE},
        ENABLE     => $args->{ENABLE},
    );

    return $pkg;
}

=begin TML

---++ WIZARD depreport

First step in an installation; generate a dependency report.

=cut

sub depreport {
    my ( $this, $reporter ) = @_;

    my $seen = {};    # Hash to prevent duplicate installs

    my $args = $this->param('args');

    while ( my ( $module, $repo ) = each %$args ) {

        # Don't mistake options for modules
        next if $validArgs{$module};

        my $pkg = $this->_getPackage( $reporter, $module, $repo, $seen );
        next unless $pkg;

        $reporter->NOTE( "---++ Dependency report for " . $pkg->module() );
        $pkg->loadInstaller($reporter);
        my ( $installed, $missing ) = $pkg->checkDependencies();
        $reporter->NOTE( "> *INSTALLED*", map { "\t* $_" } @$installed )
          if (@$installed);
        if (@$missing) {
            $reporter->NOTE( "> *MISSING*", map { "\t* $_" } @$missing );
        }
        else {
            $reporter->NOTE("> All dependencies satisfied");
        }

        $pkg->finish();
    }
}

=begin TML

---++ WIZARD manifest

Display an extension manifest

=cut

sub manifest {
    my ( $this, $reporter, $spec ) = @_;
    my $seen = {};

    my $args = $this->param('args');
    while ( my ( $module, $repo ) = each %$args ) {

        # Don't mistake options for modules
        next if $validArgs{$module};

        my $pkg = $this->_getPackage( $reporter, $module, $repo, $seen );
        next unless $pkg;

        $reporter->NOTE( "---++ Manifest for " . $pkg->module() );
        $pkg->loadInstaller($reporter);
        $reporter->NOTE( $pkg->manifest() );
        $pkg->finish();
    }

    return undef;    # return the report
}

=begin TML

---++ WIZARD add

Install an extension

=cut

sub add {
    my ( $this, $reporter, $spec ) = @_;
    my $seen = {};

    my $args = $this->param('args');
    while ( my ( $module, $repo ) = each %$args ) {

        # Don't mistake options for modules
        next if $validArgs{$module};

        my $pkg = $this->_getPackage( $reporter, $module, $repo, $seen );
        next unless $pkg;

        my $extension = $pkg->module();
        unless ( $pkg->install( $reporter, $spec ) ) {
            $reporter->ERROR( <<OMG );
The Extension may not be usable due to errors. Installation terminated.
OMG
        }

        $pkg->finish();
    }

    return undef;    # return the report
}

=begin TML

---++ WIZARD remove

Uninstall an extension

=cut

sub remove {
    my ( $this, $reporter ) = @_;

    my $args = $this->param('args');
    while ( my ( $module, $repo ) = each %$args ) {

        # Don't mistake options for modules
        next if $validArgs{$module};

        my $pkg = $this->_getPackage( $reporter, $module, $repo );
        next unless $pkg;

        $pkg->uninstall($reporter);

        $pkg->finish();
    }

    return undef;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2015 Foswiki Contributors. Foswiki Contributors
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
