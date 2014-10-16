# See bottom of file for license and copyright information
package Foswiki::Configure::Wizards::ExploreExtensions;

use strict;
use warnings;

use Assert;

=begin TML

---+ package Foswiki::Configure::Wizards:ExploreExtensions

Visits remote extensions repositories to pull down details of
available extensions. These are then presented to the reporter
in tabular form.

=cut

require Foswiki::Configure::Wizard;
our @ISA = ('Foswiki::Configure::Wizard');

use Foswiki::Configure::Dependency ();
use Foswiki::Func                  ();

# THE FOLLOWING MUST BE MAINTAINED CONSISTENT WITH Extensions.FastReport
# They describe the format of an extension topic.

# Ordered list of field names to column headings
my %tableHeads = (
    Installed   => [ 'description', 'release', 'installedRelease', 'install' ],
    Uninstalled => [ 'description', 'release', 'install' ]
);

# Mapping to column heading string
my %headNames = (
    release          => 'Most recent release',
    description      => 'Extension',
    compatibility    => 'Compatible with',
    installedRelease => 'Installed release',
    install          => '',

    # Not used; just here for completeness
    image            => 'Image',
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
    my ( $this, $reporter, %search ) = @_;
    my ( $release, $version, $pluginsapi ) =
      ( $Foswiki::RELEASE, $Foswiki::VERSION, $Foswiki::Plugins::VERSION );

    my @consulted = ();
    return ( $this->{list} ) if $this->{list};

    $this->{list}   = {};
    $this->{errors} = [];

    foreach my $place ( findRepositories() ) {
        next unless defined $place->{data};
        $place->{data} =~ s#/*$#/#;

        push( @consulted, $place->{name} );

        my $url = $place->{data}
          . "JsonReport?contenttype=application/json;skin=text;release=$release;version=$version;pluginsapi=$pluginsapi";
        while ( my ( $k, $v ) = each %search ) {
            $url .= ";$k=" . Foswiki::urlEncode($v);
        }
        if ( defined( $place->{user} ) ) {
            $url .= ';username=' . $place->{user};
            if ( defined( $place->{pass} ) ) {
                $url .= ';password=' . $place->{pass};
            }
        }
        my $response = Foswiki::Func::getExternalResource($url);

        if ( !$response->is_error() ) {

            my $page = $response->content();
            if ( defined $page ) {

                # "(Foswiki login)" or "Login - Foswiki"
                # status 400 for foswiki 1.0.0-1.0.9
                if (    ( $response->code == 200 || $response->code == 400 )
                    and
                    ( $response->content() =~ /<title>.*login.*<\/title>/i ) )
                {

                    #TemplateAuth login required....
                    my $errorMsg =
                      "Error accessing $place->{name}: TemplateAuth failure";
                    if (
                        not(    defined( $place->{user} )
                            and defined( $place->{pass} ) )
                      )
                    {
                        $errorMsg .=
" you probably need to add the optional =,username,password)= options to the repository definition";
                    }
                    push( @{ $this->{errors} }, $errorMsg );
                }
                else {
                    # probably a normal extensions JsonReport.
                    foreach my $row ( @{ JSON->new->decode($page) } ) {
                        $this->_studyRow( $row, $place );
                    }
                }

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
            eval { require LWP };
            if ($@) {
                push(
                    @{ $this->{errors} },
                    "This may be because the CPAN 'LWP' module isn't installed."
                );
            }
        }
    }

    return ( $this->{list}, @consulted );
}

sub _studyRow {
    my ( $this, $data, $place ) = @_;

    $data->{repository} = $place->{name};
    $data->{data}       = $place->{data};
    $data->{pub}        = $place->{pub};
    $data->{type}       = 'perl';

    my $dep = Foswiki::Configure::Dependency->new(%$data);
    $dep->studyInstallation();

    # If release isn't specified, then use the version string

    # SMELL:  $dep->{release} is defined as the "Required" release
    # string that will be compared by the dependency check function.
    # It is being misused here to report the latest "available"
    # release in the Extensions repository.
    if ( !$data->{release} && $data->{version} ) {

        # See if we can pull the release ID from the generated %$VERSION%
        if ( $data->{version} =~ /^\d+ \((.+)\)$/ ) {
            $dep->{release} = $1;
        }
        else {

            # Can't make sense of it; use the whole string
            $dep->{release} = $data->{version};

        }
    }

    $this->{list}->{ $dep->{name} } = $dep;
    return '';
}

# Wizard - Constructs an HTML table of installed extensions
sub get_installed_extensions {
    my ( $this, $reporter ) = @_;

    $this->_get_extensions( $reporter, 'Installed' );
    return undef;    # return the report
}

# Wizard - Constructs an HTML table of not-installed extensions
sub get_other_extensions {
    my ( $this, $reporter ) = @_;

    $this->_get_extensions( $reporter, 'Uninstalled' );
    return undef;    # return the report
}

sub _get_extensions {
    my ( $this, $reporter, $set, %search ) = @_;

    my ( $exts, @consultedLocations ) =
      $this->_getListOfExtensions( $reporter, %search );
    my $installedExts;
    my $installedCount = 0;
    my $uninstalledExts;
    my $uninstalledCount = 0;

    $reporter->NOTE("---++ $set Extensions");
    $reporter->NOTE(
'> Each extension is listed along with a "Study" button, which is used to generate a dependency report for the extension. From there, you can proceed with the installation. '
    );
    $reporter->NOTE('> ');

    # count
    while ( my ( $key, $ext ) = each %$exts ) {
        if ( $ext->{installedRelease} ) {
            $installedCount++;
            $installedExts->{$key} = $ext;
        }
        else {
            $uninstalledCount++;
            $uninstalledExts->{$key} = $ext;
        }
    }
    $exts = $set eq 'Installed' ? $installedExts : $uninstalledExts;

    $reporter->NOTE( "> Looked in " . join( ' ', @consultedLocations ) );

    $reporter->ERROR( @{ $this->{errors} } ) if scalar @{ $this->{errors} };

    if ( $set eq 'Installed' ) {
        $reporter->NOTE("> *Found $installedCount Installed extensions* ");
    }
    else {
        $reporter->NOTE("> *Found $uninstalledCount Uninstalled extensions* ");
    }

    # Table heads
    $reporter->NOTE(
        '|'
          . join( '|',
            map { $headNames{$_} ? " *$headNames{$_}* " : '' }
              @{ $tableHeads{$set} } )
          . '|'
    );

    # Each extension has two rows

    my $out = '';
    foreach my $key (
        sort {
            defined $exts->{$b}->{installedVersion} <=>
              defined $exts->{$a}->{installedVersion}
              || lc $a cmp lc $b
        } keys %$exts
      )
    {
        my $ext = $exts->{$key};

        next if $ext->{name} eq 'EmptyPlugin';    # special case

        # $ext is type Foswiki::Configure::Dependency, and studyInstallation
        # has already been called, so {installedRelease} and {installedVersion}
        # are known to be populated. Note that {version} in this dependency
        # is the version number read from FastReport, and {release} will be
        # the latest release from there.

        my $install   = 'Study';
        my $uninstall = '';

        if ( $ext->{installedRelease} ) {

            # The module is installed; check the version
            if ( $ext->{installedVersion} eq '9999.99_999' ) {

                # pseudo-installed
                $install = 'pseudo-installed';
            }
            elsif ( $ext->compare_versions( '<', $ext->{release} ) ) {

                # Installed version is < available version

                $install   = 'Upgrade';
                $uninstall = 'Uninstall';
            }
            else {

                # Installed version is current version

                $install   = 'Re-install';
                $uninstall = 'Uninstall';
            }
        }

        $install = $reporter->WIZARD(
            $install,
            {
                wizard => 'InstallExtensions',
                method => 'depreport',
                args   => {
                    repository  => $ext->{repository},
                    module      => $ext->{name},
                    installable => ( $install ne 'pseudo-installed' ),

                    # SIMULATE =>
                    # NODEPS =>
                    # USELOCAL =>
                }
            }
        );

        if ($uninstall) {
            $uninstall = $reporter->WIZARD(
                $uninstall,
                {
                    wizard => 'InstallExtensions',
                    method => 'remove',
                    args   => {
                        repository => $ext->{repository},
                        module     => $ext->{name},

                        # SIMULATE =>
                        # NODEPS =>
                        # USELOCAL =>
                    }
                }
            );
        }

        # Do the title + actions row
        my $thd = $ext->{name} || 'Unknown';
        $thd =~ s/!(\w+)/$1/go;    # remove ! escape syntax from text
        $thd = "[[$ext->{data}$ext->{name}][$thd]]";

        $reporter->NOTE(
            "| $thd" . '|' x scalar( @{ $tableHeads{$set} } ) . " $install |" );

        # Do the data row
        my @cols;
        foreach my $f ( @{ $tableHeads{$set} } ) {
            my $tdd = $ext->{$f} || '';
            $tdd =~ s/!(\w+)/$1/go;    # remove ! escape syntax from text
            if ( $f eq 'description' && $ext->{compatibility} ) {
                $tdd .= "<br />$ext->{compatibility}";
            }
            push( @cols, $tdd );
        }
        push( @cols, $uninstall );

        $reporter->NOTE( '|' . join( '|', map { " $_ " } @cols ) . '|' );
    }
    $reporter->NOTE("</div>");
}

=begin TML

---+ WIZARD find_extension_1

Stage 1 of the find extension process. Build a prompt page for the
extension search expression.

=cut

sub find_extension_1 {
    my ( $this, $reporter ) = @_;

    $reporter->NOTE("---+ Find New Extensions");
    $reporter->NOTE( '<form id="find_extensions">'
          . "Regular expression search <br/>"
          . 'Extension name: '
          . '<input type="text" length="30" name="name"></input></br/>'
          . 'Description: '
          . '<input type="text" length="30" name="text"></input><br/>'
          . '</form>' );
    my %data = (
        wizard => 'ExploreExtensions',
        method => 'find_extension_2',
        form   => '#find_extensions',
        args   => {

            # Other args come from the form
        }
    );
    $reporter->NOTE( $reporter->WIZARD( 'Find Extension', \%data ) );
    return undef;
}

sub find_extension_2 {
    my ( $this, $reporter ) = @_;

    my %filters;
    my $pa = $this->param('args');
    foreach my $p ( 'name', 'text' ) {
        $filters{$p} = $pa->{$p} if ( $pa->{$p} );
    }
    $this->_get_extensions( $reporter, 'Uninstalled', %filters );
    return undef;
}

# Build descriptive hashes for the repositories listed in
# $Foswiki::cfg{ExtensionsRepositories}
# name=(dataUrl,pubURL[,user,password]) ; ...

sub findRepositories {

    my $replist = '';
    $replist = $Foswiki::cfg{ExtensionsRepositories}
      if defined $Foswiki::cfg{ExtensionsRepositories};

    my @repositories;
    while ( $replist =~ s/^\s*([^=;]+)=\(([^)]*)\)\s*// ) {
        my ( $name, $value ) = ( $1, $2 );
        if ( $value =~
            /^([a-z]+:[^,]+),\s*([a-z]+:[^,]+)(?:,\s*([^,]*),\s*(.*))?$/ )
        {
            push(
                @repositories,
                {
                    name => $name,
                    data => $1,
                    pub  => $2,
                    user => $3,
                    pass => $4
                }
            );

            last unless ( $replist =~ s/^;\s*// );
        }
    }
    return @repositories;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2014 Foswiki Contributors. Foswiki Contributors
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
