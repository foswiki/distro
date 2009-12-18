# See bottom of file for license and copyright information
package Foswiki::Configure::UIs::EXTENSIONS;
use strict;

use Foswiki::Configure::UI ();
our @ISA = ('Foswiki::Configure::UI');

use Foswiki::Configure::Type       ();
use Foswiki::Configure::Dependency ();

# THE FOLLOWING MUST BE MAINTAINED CONSISTENT WITH Extensions.FastReport
# They describe the format of an extension topic.

# Ordered list of field names to column headings
my @tableHeads =
  qw( image description compatibility release installedRelease install );

# Mapping to column heading string
my %headNames = (
    release          => 'Most Recent Release',
    description      => 'Description',
    compatibility    => 'Compatible with',
    installedRelease => 'Installed Release',
    install          => '',
    image            => '',

    # Not used; just here for completeness
    topic            => 'Extension',
    classification   => 'Classification',
    version          => 'Most Recent Version',
    installedVersion => 'Installed Version',
);

my @MNAMES  = qw(jan feb mar apr may jun jul aug sep oct nov dec);
my $mnamess = join( '|', @MNAMES );
my $MNAME   = qr/$mnamess/i;
my %N2M;
foreach ( 0 .. $#MNAMES ) { $N2M{ $MNAMES[$_] } = $_; }

# Convert a date in the formats dd mm yyyy or dd Mmm yyyy to a unique integer
sub d2n {
    my ( $d, $m, $y ) = @_;
    return ( $y * 12 + $m ) * 31 + $d;
}

# Download the report page from the repository, and extract a hash of
# available extensions
sub _getListOfExtensions {
    my $this = shift;

    $this->findRepositories();

    my @consulted = ();
    if ( !$this->{list} ) {
        $this->{list}   = {};
        $this->{errors} = [];
        foreach my $place ( @{ $this->{repositories} } ) {
            next unless defined $place->{data};
            $place->{data} =~ s#/*$#/#;

            push( @consulted, $place->{name} );

            my $url      = $place->{data} . 'FastReport?skin=text';
            my $response = $this->getUrl($url);
            if ( !$response->is_error() ) {
                my $page = $response->content();
                if ( defined $page ) {
                    $page =~ s/{(.*?)}/$this->_parseRow($1, $place)/ges;
                }
                else {
                    push(
                        @{ $this->{errors} },
                        "Error accessing $place->{name}: no content"
                    );
                }
            }
            else {
                push(
                    @{ $this->{errors} },
                    "Error accessing $place->{name}: " . $response->message()
                );

                #see if its because LWP isn't installed..
                eval "require LWP";
                if ($@) {
                    push(
                        @{ $this->{errors} },
"This may be because the CPAN 'LWP' module isn't installed."
                    );
                }
            }
        }
    }
    return ( $this->{list}, @consulted );
}

sub _parseRow {
    my ( $this, $row, $place ) = @_;
    my %data;
    return '' unless defined $row;
    return '' unless $row =~ s/^ *(\w+): *(.*?) *$/$data{$1} = $2;''/gem;

    die "$row: " . Data::Dumper->Dump( [ \%data ] ) unless $data{topic};

    $data{name}       = $data{topic};
    $data{repository} = $place->{name};
    $data{data}       = $place->{data};
    $data{pub}        = $place->{pub};

    my $dep = new Foswiki::Configure::Dependency(%data);
    $dep->studyInstallation();

    # If release isn't specified, then use the version string
    if ( !$dep->{release} && $dep->{version} ) {

        # See if we can pull the release ID from the generated %$VERSION%
        if ( $dep->{version} =~ /^\d+ \((.+)\)$/ ) {
            $dep->{release} = $1;
        }
        else {

            # Can't make sense of it; use the whole string
            $dep->{release} = $dep->{version};
        }
    }

    $this->{list}->{ $dep->{name} } = $dep;
    return '';
}

sub ui {
    my $this = shift;

    my $table = '';

    my $rows      = 0;
    my $installed = 0;
    my ( $exts, @consultedLocations ) = $this->_getListOfExtensions();

    return ( \@consultedLocations, undef, $this->{errors} )
      if scalar @{ $this->{errors} };

    # Table heads
    my $tableHeads = '';
    my $colNum = 0;
    foreach my $headNameKey (@tableHeads) {
	    $colNum++;
	    my $cssClass = ($colNum == scalar @tableHeads)
          ? 'configureExtensionAction' : undef;
	    $tableHeads .= CGI::th( {class => $cssClass},
                                $headNames{$headNameKey} );
	}
    $table .= CGI::Tr( $tableHeads );

    # Each extension has two rows
    
    foreach my $key ( sort keys %$exts ) {
        my $ext = $exts->{$key};

        next if $ext->{topic} eq 'EmptyPlugin';    # special case

        # $ext is type Foswiki::Configure::Dependency, and studyInstallation
        # has already been called, so {installedRelease} and {installedVersion}
        # are known to be populated. Note that {version} in this dependency
        # is the version number read from FastReport, and {release} will be
        # the latest release from there.

        my $install = 'Install';
        my $uninstall = '';
        my $trClass = 'configureInstall';
        if ( $ext->{installedRelease} ) {

            # The module is installed; check the version
            if ( $ext->{installedVersion} eq 'HEAD' ) {

                # pseudo-installed
                $install = 'pseudo-installed';
                $trClass = 'configurePseudoInstalled';
            }
            elsif ( $ext->compare_versions( '<', $ext->{release} ) ) {

                # Installed version is < available version

                $install = 'Upgrade';
                $uninstall = 'Uninstall';
                $trClass = 'configureUpgrade';
            }
            else {

                # Installed version is current version

                $install = 'Re-install';
                $uninstall = 'Uninstall';
                $trClass = 'configureReInstall';
            }
            $installed++;
        }

        if ($install ne 'pseudo-installed') {
            $install = CGI::checkbox(
                -name => 'add',
                -value => $ext->{repository} . '/' . $ext->{topic},
                -class => 'foswikiCheckbox',
                -label => $install,
               );
        }

        if ($uninstall) {
            $uninstall = '<br />'.CGI::checkbox(
                -name => 'remove',
                -value => $ext->{repository} . '/' . $ext->{topic},
                -class => 'foswikiCheckbox',
                -label => $uninstall,
               );
        }

        $trClass .= ' configureAlienExtension'
          if ( $ext->{module} && $ext->{module} !~ /^Foswiki::/ );
        $trClass .= ' extensionRow';

        # Do the title row
        my $thd = $ext->{topic} || 'Unknown';
        $thd =~ s/!(\w+)/$1/go;    # remove ! escape syntax from text
        $thd = CGI::a( { href => $ext->{data} . $ext->{topic} }, $thd );

        # Do the data row
        my $row      = '';
        my $colCount = 0;

        my @imgControls = ();
        if ($ext->{image}) {
            $ext->{image} = '<div title="'.$ext->{image}
              .'" class="loadImage"></div>';
        }

        $table .= CGI::Tr(
            { class => $trClass }, 
            CGI::td(
                {
                    colspan => $#tableHeads,
                    class   => "configureExtensionTitle"
                },
                $thd
            ),
            CGI::td(
                {
                    class =>
                      "configureExtensionTitle configureExtensionAction"
                },
                $install . ' ' . $uninstall
            )
        );

        foreach my $f (@tableHeads) {
            my $tdd = $ext->{$f} || '&nbsp;';
            $tdd =~ s/!(\w+)/$1/go;    # remove ! escape syntax from text
            my $cssClass = "configureExtensionData";
            $cssClass .= ' configureExtensionDataFirst' if $colCount == 0;
            $cssClass .= ' configureExtensionAction'
              if $colCount == scalar @tableHeads - 1;
            $row .= CGI::td( { class => $cssClass }, $tdd );
            $colCount++;
        }

        $table .= CGI::Tr( { class => $trClass, id => $ext->{topic},
                             @imgControls }, $row);

        $rows++;
    }

    return ( \@consultedLocations, $table, undef, $installed, $rows );
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
