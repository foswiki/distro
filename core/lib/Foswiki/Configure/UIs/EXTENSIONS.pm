# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Configure::UIs::EXTENSIONS

Specialised UI; an implementation of the "Find more extensions" UI screen.
When this screen is visited, the remote extensions repositories are visited
to pull down details of available extensions. These are then presented
in custom tabular form.

=cut

package Foswiki::Configure::UIs::EXTENSIONS;

use strict;
use warnings;

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

# Get release & version strings which should indicate the running Foswiki's
# version, unless this an un-built developer checkout...
sub _getBuildStrings {
    require Foswiki;
    require Foswiki::Plugins;

    my @strings;

    # SMELL: Should this be fully/properly URL encoded?
    foreach my $string ( $Foswiki::RELEASE, $Foswiki::VERSION,
        $Foswiki::Plugins::VERSION )
    {
        $string =~ s/;/&#59;/g;

        push( @strings, $string );
    }

    return @strings;
}

# Download the report page from the repository, and extract a hash of
# available extensions
sub _getListOfExtensions {
    my $this = shift;
    my ( $release, $version, $pluginsapi ) = _getBuildStrings();

    $this->findRepositories();

    my @consulted = ();
    if ( !$this->{list} ) {
        $this->{list}   = {};
        $this->{errors} = [];
        foreach my $place ( @{ $this->{repositories} } ) {
            next unless defined $place->{data};
            $place->{data} =~ s#/*$#/#;

            push( @consulted, $place->{name} );

            my $url = $place->{data}
              . "FastReport?skin=text;release=$release;version=$version;pluginsapi=$pluginsapi";
            if ( defined( $place->{user} ) ) {
                $url .= ';username=' . $place->{user};
                if ( defined( $place->{pass} ) ) {
                    $url .= ';password=' . $place->{pass};
                }
            }
            my $response = $this->getUrl($url);

            if ( !$response->is_error() ) {

                #print STDERR "a--- ".Data::Dumper->Dump( [ $response ] )."\n";
                my $page = $response->content();
                if ( defined $page ) {

                    # "(Foswiki login)" or "Login - Foswiki"
                    # status 400 for foswiki 1.0.0-1.0.9
                    if (
                            ( $response->code == 200 || $response->code == 400 )
                        and
                        ( $response->content() =~ /<title>.*login.*<\/title>/i )
                      )
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
" you probably need to add the optional <code>,username,password)</code> options to the repository definition";
                        }
                        push( @{ $this->{errors} }, $errorMsg );
                    }
                    else {

                        #probably a normal extensions FastReport. Item9786:
                        #content may contain '{','}' chars so anchor to newlines
                        $page =~ s/\n{(.*?)}\n/$this->_parseRow($1, $place)/ges;
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
    }
    return ( $this->{list}, @consulted );
}

sub _parseRow {
    my ( $this, $row, $place ) = @_;
    my %data;
    return '' unless defined $row;
    my $original_row = $row;
    return '' unless $row =~ s/^ *(\w+): *(.*?) *$/$data{$1} = $2;''/gem;

    if ( !$data{topic} ) {

#die "RANDOMERROR5 $row: " . Data::Dumper->Dump( [ \%data ] );
#its a shame that at this point we don't have enough info to extract (for eg) the <title> -
#which might tell the user that the site has been redirected to http://slashdot.org or something
        push(
            @{ $this->{errors} },
            "no valid Extensions report found. (" . $place->{name} . ")"
        );
        return '';
    }

    chomp( $data{topic} );
    $data{name}       = $data{topic};
    $data{repository} = $place->{name};
    $data{data}       = $place->{data};
    $data{pub}        = $place->{pub};
    $data{type}       = 'perl';

    my $dep = Foswiki::Configure::Dependency->new(%data);
    $dep->studyInstallation();

    # If release isn't specified, then use the version string

# SMELL:  $dep->{release} is defined as the "Required" release string that will be compared by the
#         dependency check function. It is being misused here to report the latest "available"
#         release in the Extensions repository.
    if ( !$data{release} && $data{version} ) {

        # See if we can pull the release ID from the generated %$VERSION%
        if ( $data{version} =~ /^\d+ \((.+)\)$/ ) {
            $dep->{release} = $1;
        }
        else {

            # Can't make sense of it; use the whole string
            $dep->{release} = $data{version};

        }
    }

#die "RANDOMERROR5 $row: " . Data::Dumper->Dump( [ \%data ] ) if ($data{name} eq "WordPressPlugin");

    $this->{list}->{ $dep->{name} } = $dep;
    return '';
}

=begin TML

---++ ObjectMethod getExtensions() -> ( $consultedLocations, $table, $errors, $installedCount, $allCount )

Called from =configure=, in _actionFindMoreExtensions, this constructs
the HTML table used in the Find more extensions screen

=cut

sub getExtensions {
    my $this = shift;

    my $table = '';

    my $rows      = 0;
    my $installed = 0;
    my ( $exts, @consultedLocations ) = $this->_getListOfExtensions();

    # Table heads
    my $tableHeads = '';
    my $colNum     = 0;
    foreach my $headNameKey (@tableHeads) {
        $colNum++;
        my $cssClass =
          ( $colNum == scalar @tableHeads )
          ? 'configureExtensionAction'
          : undef;
        $tableHeads .=
          CGI::th( { class => $cssClass }, $headNames{$headNameKey} );
    }
    $table .= CGI::Tr($tableHeads);

    # Each extension has two rows

    foreach my $key (
        sort {
            defined $exts->{$b}->{installedVersion} <=>
              defined $exts->{$a}->{installedVersion}
              || lc $a cmp lc $b
        } keys %$exts
      )
    {
        my $ext = $exts->{$key};

        next if $ext->{topic} eq 'EmptyPlugin';    # special case

        # $ext is type Foswiki::Configure::Dependency, and studyInstallation
        # has already been called, so {installedRelease} and {installedVersion}
        # are known to be populated. Note that {version} in this dependency
        # is the version number read from FastReport, and {release} will be
        # the latest release from there.

        my $install   = 'Install';
        my $uninstall = '';
        my $trClass   = 'configureInstall';
        if ( $ext->{installedRelease} ) {

            # The module is installed; check the version
            if ( $ext->{installedVersion} eq '9999.99_999' ) {

                # pseudo-installed
                $install = 'pseudo-installed';
                $trClass = 'configurePseudoInstalled';
            }
            elsif ( $ext->compare_versions( '<', $ext->{release} ) ) {

                # Installed version is < available version

                $install   = 'Upgrade';
                $uninstall = 'Uninstall';
                $trClass   = 'configureUpgrade';
            }
            else {

                # Installed version is current version

                $install   = 'Re-install';
                $uninstall = 'Uninstall';
                $trClass   = 'configureReInstall';
            }
            $installed++;
        }

        if ( $install ne 'pseudo-installed' ) {
            $install = CGI::checkbox(
                -name  => 'add',
                -value => $ext->{repository} . '/' . $ext->{topic},
                -class => 'foswikiCheckbox',
                -label => $install,
            );
        }

        if ($uninstall) {
            $uninstall = '<br />'
              . CGI::checkbox(
                -name  => 'remove',
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
        if ( $ext->{image} ) {
            $ext->{image} =
                '<div title="'
              . $ext->{image}
              . '" class="foswikiImage loadImage"></div>';
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
                    class => "configureExtensionTitle configureExtensionAction",
                    rowspan => 2
                },
                $install . ' ' . $uninstall
            )
        );

        foreach my $f (@tableHeads) {
            my $tdd = $ext->{$f} || '&nbsp;';
            $tdd =~ s/!(\w+)/$1/go;    # remove ! escape syntax from text
            my $cssClass = "configureExtensionData";
            $cssClass .= ' configureExtensionDataFirst' if $colCount == 0;
            if ( $colCount == scalar @tableHeads - 1 ) {

                # nothing (in colspan)
            }
            else {
                $row .= CGI::td( { class => $cssClass }, $tdd );
            }
            $colCount++;
        }

        $table .= CGI::Tr(
            {
                class => $trClass,
                id    => $ext->{topic},
                @imgControls
            },
            $row
        );

        $rows++;
    }

    return ( \@consultedLocations, $table, $this->{errors}, $installed, $rows );
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
