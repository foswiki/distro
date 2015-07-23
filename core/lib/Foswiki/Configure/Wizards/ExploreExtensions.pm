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

# THE FOLLOWING MUST BE MAINTAINED CONSISTENT WITH Extensions.JsonReport
# They describe the format of an extension topic.

# Ordered list of field names to column headings
my %tableHeads = (
    Installed   => [ 'description', 'release', 'installedRelease' ],
    Uninstalled => [ 'description', 'release' ]
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
            if ( $k =~ m/name|text/ && $v ) {
                eval { qr/$v/ };
                if ($@) {
                    my $msg = Foswiki::Configure::Reporter::stripStacktrace($@);
                    $reporter->ERROR(<<"MESS");
Invalid regular expression: $msg <p />
See <a href="http://www.perl.com/doc/manual/html/pod/perlre.html">perl.com</a> for help with Perl regular expressions.
MESS
                    return undef;
                }
            }
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
                    ( $response->content() =~ m/<title>.*login.*<\/title>/i ) )
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
                    eval {
                        foreach my $row ( @{ JSON->new->decode($page) } )
                        {
                            $this->_studyRow( $row, $place );
                        }
                    };
                    if ($@) {
                        my $msg =
                          Foswiki::Configure::Reporter::stripStacktrace($@);
                        $msg .= "<br/> Response from server: $page";
                        $reporter->ERROR(<<"MESS");
Failure processing response from the repository search: $msg <p />
MESS
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
            eval('require LWP');
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
        if ( $data->{version} =~ m/^\d+ \((.+)\)$/ ) {
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
'> Each extension has a check box which you can use to select the extension. Use the "Report" button to generate a dependency report for each selected extensions, or the "'
          . ( $set eq 'Installed' ? 'Remove' : 'Install' )
          . '" button to '
          . (
            $set eq 'Installed' ? 'remove' : 'install (or upgrade/re-install)'
          )
          . ' them. '
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

    $reporter->ERROR( @{ $this->{errors} } ) if scalar( @{ $this->{errors} } );

    if ( $set eq 'Installed' ) {
        $reporter->NOTE("> *Found $installedCount Installed extensions* ");
    }
    else {
        $reporter->NOTE("> *Found $uninstalledCount Uninstalled extensions* ");
    }

    $reporter->NOTE(
        $reporter->WIZARD(
            'Report',
            {
                wizard => 'InstallExtensions',
                method => 'depreport',
                form   => "#${set}_extensions_list",
                args   => {

                    # will be extended by the #extensions_list form
                    # SIMULATE =>
                    # NODEPS =>
                    # USELOCAL =>
                }
            }
          )
          . $reporter->WIZARD(
            ( $set eq 'Installed' ? 'Upgrade' : 'Install' ),
            {
                wizard => 'InstallExtensions',
                method => 'add',
                form   => "#${set}_extensions_list",
                args   => {

                    # will be extended by the #extensions_list form
                    # SIMULATE =>
                    # NODEPS =>
                    # USELOCAL =>
                }
            }
          )
          . $reporter->WIZARD(
            'Remove',
            {
                wizard => 'InstallExtensions',
                method => 'remove',
                form   => "#${set}_extensions_list",
                args   => {

                    # will be extended by the #extensions_list form
                    # SIMULATE =>
                    # NODEPS =>
                    # USELOCAL =>
                }
            }
          )
          . "<div class='extensions_table'><form id='${set}_extensions_list'>"
    );

    $reporter->NOTE(<<CHECKBOXES);
<input type='checkbox' class="wizard_checkbox" id="simulate" name='SIMULATE' value='1' title="Check to get a detailed report on what will happen during installation, without actually installing." />
<label for="simulate">Simulated install</label>
<input type='checkbox' class="wizard_checkbox" id="nodeps" name='NODEPS' value='1' title="If this is unchecked, any required dependencies will automatically be installed. Check to install ONLY the extensions, IGNORING any dependencies." />
<label for="nodeps">Don't install dependencies</label>
CHECKBOXES

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
        # is the version number read from JsonReport, and {release} will be
        # the latest release from there.

        my $status = "";

        if ( $ext->{installedRelease} ) {

            # The module is installed; check the version
            if ( $ext->{installedVersion} eq '9999.99_999' ) {

                # pseudo-installed
                $status = ' _is pseudo-installed_ ';
            }
            elsif ( $ext->compare_versions( '<', $ext->{version} ) ) {

                # Installed version is < available version

                $status = ' *has a more recent version available* ';
            }
            else {

                # Installed version is current version

                $status = ' _is installed_ ';
            }
        }

        # The nice thing about checkboxes is that they don't get added
        # to the query unless they are checked, and then the value returned
        # is the value we give them here i.e. the repo
        my $thd =
            "<input type='checkbox'"
          . " class='wizard_checkbox'"
          . " name='$ext->{name}'"
          . " value='$ext->{repository}'/> ";

        $thd .= "[[$ext->{data}$ext->{name}][";
        $thd .= $ext->{name} || 'Unknown';
        $thd .= ']]';
        $thd =~ s/!(\w+)/$1/g;    # remove ! escape syntax from text
        $thd .= " <sup>[$ext->{repository}]</sup>"
          if ( scalar(@consultedLocations) > 1 );

        $thd .= " $status";

        # Do the data
        my @cols;
        foreach my $f ( @{ $tableHeads{$set} } ) {
            my $tdd = $ext->{$f} || '';
            $tdd =~ s/!(\w+)/$1/g;    # remove ! escape syntax from text
            if ( $f eq 'description' && $ext->{compatibility} ) {
                $tdd .= "<br />$ext->{compatibility}";
            }
            push( @cols, $tdd );
        }
        $cols[0] = "$thd <br /> $cols[0]";
        $reporter->NOTE( '|' . join( '|', map { " $_ " } @cols ) . '|' );
    }
    $reporter->NOTE("</form></div>");
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

=begin TML

---+ WIZARD find_extension_2

Stage 2 of the find extension process, follows on from find_extension_1.
Given a search, get matching extensions. the report will then permit
study and installation of the extensions.

=cut

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
            m/^([a-z]+:[^,]+),\s*([a-z]+:[^,]+)(?:,\s*([^,]*),\s*(.*))?$/ )
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
