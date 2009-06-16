# See bottom of file for license and copyright information
package Foswiki::Configure::UIs::EXTENSIONS;
use base 'Foswiki::Configure::UI';

use strict;
use Foswiki::Configure::Type;

# THE FOLLOWING MUST BE MAINTAINED CONSISTENT WITH Extensions.FastReport
# They describe the format of an extension topic.
my @tableHeads =
  qw( topic classification description version installedVersion compatibility install );
my $VERSION_LINE = qr/\n\|[\s\w-]*\s[Vv]ersion:\s*\|([^|]+)\|/;

my %headNames = (
    topic            => 'Extension',
    classification   => 'Classification',
    description      => 'Description',
    version          => 'Most Recent Version',
    installedVersion => 'Installed Version',
    compatibility    => 'Compatible with',
    install          => 'Action',
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

    if ( !$this->{list} ) {
        $this->{list}   = {};
        $this->{errors} = [];
        foreach my $place ( @{ $this->{repositories} } ) {
            next unless defined $place->{data};
            $place->{data} =~ s#/*$#/#;
            print CGI::div("Consulting $place->{name}...");
            my $url      = $place->{data} . 'FastReport?skin=text';
            my $response = $this->getUrl($url);
            if ( !$response->is_error() ) {
                my $page = $response->content();
                if (defined $page) {
                    $page =~ s/{(.*?)}/$this->_parseRow($1, $place)/ges;
                } else {
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
"This may be because the LWP CPAN module isn't installed."
                    );
                }
            }
        }
    }
    return $this->{list};
}

sub _parseRow {
    my ( $this, $row, $place ) = @_;
    my %data;
    return '' unless defined $row;
    return '' unless $row =~ s/^ *(\w+): *(.*?) *$/$data{$1} = $2;''/gem;
    ( $data{installedVersion}, $data{namespace} ) =
      $this->_getInstalledVersion( $data{topic} );
    $data{repository} = $place->{name};
    $data{data}       = $place->{data};
    $data{pub}        = $place->{pub};
    die "$row: " . Data::Dumper->Dump( [ \%data ] ) unless $data{topic};
    $this->{list}->{ $data{topic} } = \%data;
    return '';
}

sub ui {
    my $this  = shift;
    my $table = '';

    my $rows      = 0;
    my $installed = 0;
    my $exts      = $this->_getListOfExtensions();
    foreach my $error ( @{ $this->{errors} } ) {
        $table .= CGI::Tr( { class => 'foswikiAlert' },
            CGI::td( { colspan => "7" }, $error ) );
    }

    $table .= CGI::Tr(
        join( '',
            map { CGI::th( { valign => 'bottom' }, $headNames{$_} ) }
              @tableHeads )
    );
    foreach my $key ( sort keys %$exts ) {
        my $ext = $exts->{$key};
        my $row = '';

        foreach my $f (@tableHeads) {
            my $text;
            if ( $f eq 'install' ) {
                my @script     = File::Spec->splitdir( $ENV{SCRIPT_NAME} );
                my $scriptName = pop(@script);
                $scriptName =~ s/.*[\/\\]//;    # Fix for Item3511, on Win XP

                my $link =
                    $scriptName
                  . '?action=InstallExtension'
                  . ';repository='
                  . $ext->{repository}
                  . ';extension='
                  . $ext->{topic};
                $text = 'Install';
                if ( $ext->{installedVersion} ) {
                    if ( $ext->{installedVersion} eq 'HEAD' ) {

                        # Unexpanded, assume pseudo-installed
                        $link = '';
                        $text = 'pseudo-installed';
                        $ext->{cssclass} = 'pseudoinstalled';
                    }
                    elsif ( $ext->{installedVersion} =~
                        /^\s*v?(\d+)\.(\d+)(?:\.(\d+))/ )
                    {

                        # X.Y, X.Y.Z, vX.Y, vX.Y.Z
                        # Combine into one number; allows up to 1000
                        # revs in each field
                        my $irev = ( $1 * 1000 + $2 ) * 1000 + $3;
                        $text = 'Re-install';
                        $ext->{cssclass} = 'reinstall';
                        if ( $ext->{version} =~
                               /^\s*v?(\d+)\.(\d+)(?:\.(\d+))?/ ) {

                            # Compatible version number
                            my $arev = ( $1 * 1000 + $2 ) * 1000 + ($3 || 0);
                            if ( $arev > $irev ) {
                                $text = 'Upgrade';
                                $ext->{cssclass} = 'upgrade';
                            }
                        }
                    }
                    elsif ( $ext->{installedVersion} =~ /^\s*(\d+)\s/ ) {

                        # SVN rev number
                        my $gotrev = $1;
                        $text = 'Re-install';
                        $ext->{cssclass} = 'reinstall';
                        if ( defined $ext->{version} &&
                               $ext->{version} =~ /^\s*(\d+)\s/ ) {
                            my $availrev = $1;
                            if ( $availrev > $gotrev ) {
                                $text = 'Upgrade';
                                $ext->{cssclass} = 'upgrade';
                            }
                        }
                    }
                    elsif ( $ext->{installedVersion} =~
                        /(\d{4})-(\d\d)-(\d\d)/ ) {
                        # ISO date
                        my $idate = d2n( $3, $2, $1 );
                        $text = 'Re-install';
                        $ext->{cssclass} = 'reinstall';
                        if ( defined $ext->{version} &&
                               $ext->{version} =~  /(\d{4})-(\d\d)-(\d\d)/ ) {
                            my $adate = d2n( $3, $2, $1 );
                            if ( $adate > $idate ) {
                                $text = 'Upgrade';
                                $ext->{cssclass} = 'upgrade';
                            }
                        }
                    }
                    elsif ( $ext->{installedVersion} =~
                        /(\d{1,2}) ($MNAME) (\d{4})/ ) {

                        # dd Mmm yyyy date
                        my $idate = d2n( $1, $N2M{lc($2)}, $3 );
                        $text = 'Re-install';
                        $ext->{cssclass} = 'reinstall';
                        if ( defined $ext->{version} &&
                               $ext->{version} =~
                                 /(\d{1,2}) ($MNAME) (\d{4})/ ) {
                            my $adate = d2n( $1, $N2M{lc($2)}, $3 );
                            if ( $adate > $idate ) {
                                $text = 'Upgrade';
                                $ext->{cssclass} = 'upgrade';
                            }
                        }
                    }
                    $installed++;
                }
                if ($link) {
                    $text = CGI::a( { href => $link }, $text );
                }
            }
            else {
                $text = $ext->{$f} || '-';
                $text =~ s/!(\w+)/$1/go; # remove ! escape syntax from text
                if ( $f eq 'topic' ) {
                    my $link = $ext->{data} . $ext->{topic};
                    $text = CGI::a( { href => $link }, $text );
                }
=pod
                elsif ($f eq 'image'
                    && $ext->{namespace}
                    && $ext->{namespace} ne 'Foswiki' )
                {
                    $text = "$text ($ext->{namespace})";
                }
=cut
            }
            my %opts = ( valign => 'top' );
            if ( $ext->{namespace} && $ext->{namespace} ne 'Foswiki' ) {
                $opts{class} = 'alienExtension';
            }
            $row .= CGI::td( \%opts, $text );
        }
        my @classes = ( $rows % 2 ? 'odd' : 'even' );
        if ( $ext->{installedVersion} ) {
            push @classes, 'installed';
            push( @classes, $ext->{cssclass} ) if ($ext->{cssclass}); 
            push @classes, 'twikiExtension'
              if $ext->{installedVersion} =~ /\(TWiki\)/;
        }
        $table .= CGI::Tr( { class => join( ' ', @classes ) }, $row );
        $rows++;
    }
    $table .= CGI::Tr(
        { class => 'patternAccessKeyInfo' },
        CGI::td(
            { colspan => "7" },
            $installed
              . ' extension'
              . ( $installed == 1 ? '' : 's' )
              . ' out of '
              . $rows
              . ' already installed'
        )
    );
    my $page = <<INTRO;
<div class="foswikiHelp">Note that the webserver user has to be able to
write files everywhere in your Foswiki installation. Otherwise you may see
'No permission to write' errors during extension installation.</div>
INTRO
    $page .= CGI::table( { class => 'foswikiTable extensionsTable' }, $table );
    return $page;
}

sub _getInstalledVersion {
    my ( $this, $module ) = @_;
    my $lib;

    return undef unless $module;

    if ( $module =~ /Plugin$/ ) {
        $lib = 'Plugins';
    }
    else {
        $lib = 'Contrib';
    }

    # See if we have a compileable module
    my $compileable = 0;
    my $from;
    foreach $from qw(Foswiki TWiki) {
        my $path = $from . '::' . $lib . '::' . $module;
        eval "require $path";
        unless ($@) {
            $compileable = 1;    # found the module
            last;
        }
    }

    # Now scrape the version information from the .txt
    my $release = '';
    if ($compileable) {
        foreach
          my $web ( split( /[, ]+/, $Foswiki::cfg{Plugins}{WebSearchPath} ) )
        {

            # SMELL: can't use Foswiki store to do this lookup; relying on
            # directories. Not a problem right now, but in the future.....
            my $path = "$Foswiki::cfg{DataDir}/$web/$module.txt";
            my $fh;
            local $/;
            if ( -e $path && open( $fh, '<', $path ) ) {
                my $text = <$fh>;
                if ( defined $ text && $text =~ /$VERSION_LINE/s ) {
                    $release = $+;
                    $release = 'HEAD' if $release =~ /%\$VERSION%/;
                }
                close($fh);
            }
            last;
        }
    }

    return ( $release, $from );
}

1;
__DATA__
#
# Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008 Foswiki Contributors. All Rights Reserved.
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
