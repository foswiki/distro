# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# UpdatesPlugin is Copyright (C) 2011-2014 Foswiki Contributors
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html

package Foswiki::Plugins::UpdatesPlugin::Core;

use strict;
use warnings;

use JSON ();
use Error qw(:try);
use Foswiki::Plugins::JQueryPlugin ();
use Foswiki::Configure::Dependency ();    # for _compare_extension_versions()

sub new {
    my $class   = shift;
    my $session = shift;

    my $this = bless(
        {
            session   => $session,
            debug     => 0,
            reportUrl => $Foswiki::cfg{Plugins}{UpdatesPlugin}{ReportUrl}
              || "https://foswiki.org/Extensions/UpdatesPluginReport",
            timeout => $Foswiki::cfg{Plugins}{UpdatesPlugin}{CacheTimeout},
            exclude => $Foswiki::cfg{Plugins}{UpdatesPlugin}{ExcludeExtensions}
              || '',

            @_
        },
        $class
    );

    # fix params
    $this->{timeout} = 86400 unless defined $this->{timeout};
    if ( $this->{exclude} ) {
        $this->{excludePattern} =
          '^(' . join( '|', split( /\s*,\s*/, $this->{exclude} ) ) . ')$';

#print STDERR "exclude pattern = ".$this->{excludePattern}."\n" if $this->{debug};
    }

    return $this;
}

# the plugin can be configured to proxy the request for data. In this case the local server
# publishes a REST method that responds with the data from f.o - either cached locally or
# freshly mined.
sub handleRESTCheck {
    my ( $this, $plugin, $verb, $response ) = @_;

    #print STDERR "called handleRESTCheck()\n";

    my $availablePlugins;
    my $error;

    try {
        $availablePlugins = $this->getAvailable();
    }
    catch Error::Simple with {
        $error = shift;
    };

    if ( defined $error ) {
        printRESTResponse( $response, 500, $error );
        return;
    }

#print STDERR "available=".JSON::to_json($availablePlugins, {pretty=>1})."\n" if $this->{debug};
#print STDERR "installed=".JSON::to_json($this->{_installed}, {pretty=>1})."\n" if $this->{debug};

    my @outdatedPlugins = ();

    foreach my $ext ( @{ $this->{_available} } ) {
        my $extName   = $ext->{topic};
        my $installed = $this->{_installed}{$extName};

        my $release = $ext->{release};
        my $version = $ext->{version} || '';

        my $fakeObj = {
            installedRelease => $release,
            installedVersion => $version
        };

        # SMELL: breaks encapsulation of F::Configure::Dependency
        my $result =
          Foswiki::Configure::Dependency::_compare_extension_versions( $fakeObj,
            ">", $installed );
        if ($result) {
            push @outdatedPlugins, $extName;
            print STDERR
"UPDATE: $extName: installed: $installed, available release=$release, available version=$version\n"
              if $this->{debug};
        }
    }

    printRESTResponse( $response, 200,
        JSON::to_json( \@outdatedPlugins, { pretty => 1 } ) );

    return;
}

sub getAvailable {
    my $this = shift;

    unless ( defined $this->{_available} ) {

        my $installedPlugins = $this->getInstalled();

        my $works = Foswiki::Func::getWorkArea('UpdatesPlugin');
        my $fh;
        my @result = ();

        my @unfound;
        foreach my $ext ( keys %$installedPlugins ) {

            # if the cache is fresh, use it
            if ( -e "$works/$ext"
                && ( stat("$works/$ext") )[9] > time() - $this->{timeout} )
            {

                # Use the cache
                local $/ = undef;
                if ( open( $fh, '<:encoding(UTF-8)', "$works/$ext" ) ) {
                    my $data = JSON::from_json(<$fh>);
                    push( @result, $data );
                    close($fh);
                    next;
                }
            }

            # Not found in cache, or cache out of date. Update cache.
            push( @unfound, $ext );
        }

        if ( scalar(@unfound) ) {
            my $reportUrl =
                $this->{reportUrl}
              . "?list="
              . join( ',', @unfound )
              . ";contenttype=text/plain;skin=text";

            print STDERR "calling $reportUrl\n" if $this->{debug};

            my $resource = Foswiki::Func::getExternalResource($reportUrl);

            if ( !$resource->is_error() && $resource->isa('HTTP::Response') ) {
                my $content = $resource->decoded_content();

                #print STDERR "content=$content\n" if $this->{debug};

                # "Verify" the format of the resource and reduce to a perl array
                if ( $content =~
                    /^foswikiUpdates.handleResponse\((\[.*\])\);$/s )
                {
                    my $data  = JSON::from_json($1);
                    my %found = ();

                    # Refresh the cache
                    foreach my $ext (@$data) {

                        #print STDERR Data::Dumper::Dumper( \$ext );
                        my $text = JSON::to_json($ext);
                        $found{ $ext->{topic} } = 1;
                        if (
                            open(
                                $fh, '>:encoding(UTF-8)',
                                "$works/$ext->{topic}"
                            )
                          )
                        {
                            print $fh $text;
                        }
                        push( @result, $ext );
                    }

# remember null-result for unfound extensions not in the rest result provided by f.o
                    foreach my $ext (@unfound) {
                        next if $found{$ext};
                        print STDERR "no info about $ext in report\n"
                          if $this->{debug};

                        # generate a report based on the installed release
                        my $data = {
                            topic   => $ext,
                            release => $this->{_installed}{$ext}
                        };
                        my $text = JSON::to_json($data);
                        if ( open( $fh, '>:encoding(UTF-8)', "$works/$ext" ) ) {
                            print $fh $text;
                        }
                    }
                }
                else {
                    throw Error::Simple(
                        "Response from $reportUrl is unparseable: $content");
                }
            }
            else {
                throw Error::Simple(
                    "Failed to get $reportUrl: " . $resource->message() );
            }
        }

        $this->{_available} = \@result;
    }

    return $this->{_available};
}

sub getInstalled {
    my $this = shift;

    unless ( defined $this->{_installed} ) {

# First get contribs and skins by poking into the System web. The versions returned
# may include %$RELEASE% if this is a pseudo-install
# print STDERR "performing local SEARCH in $Foswiki::cfg{SystemWebName}\n" if $this->{debug};

        my $list = Foswiki::Func::expandCommonVariables(
                '{%SEARCH{"1" nosearch="on" nototal="on" web="'
              . $Foswiki::cfg{SystemWebName}
              . '" topic="*Skin,*Contrib" format="$topic" separator=","}%};' );

        my $data = {};

        foreach my $thing ( split( /\s*,\s*/, $list ) ) {
            next unless $thing =~ /^([a-zA-Z0-9_]+)$/;
            next
              if defined $this->{excludePattern}
              && $thing =~ /$this->{excludePattern}/;

            my $mn  = $1;
            my $mod = "Foswiki::Contrib::$mn";

            # SMELL: unconditional loading of contribs (is that so bad?)
            eval "require $mod";
            unless ($@) {

                my $release = eval "\$Foswiki::Contrib::${mn}::VERSION"
                  || '0';

                # Convert version objects back to a simple string
                if ( $release && ref($release) eq 'version' ) {
                    $release = $release->stringify();
                }

    #print STDERR "found extension $mn, release = $release\n" if $this->{debug};

                $data->{$mn} = $release;
            }
        }

        # Get plugins; this should obtain "true" release numbers
        # SMELL: hack assumes structure of plugins controller object
        my $controller = $this->{session}{plugins};
        foreach my $plugin ( @{ $controller->{plugins} } ) {
            next
              if defined $this->{excludePattern}
              && $plugin->{name} =~ /$this->{excludePattern}/;

            my $release = eval "\$$plugin->{module}::VERSION" || '%$VERSION';

#print STDERR "found plugin $plugin->{name}, release = $release\n" if $this->{debug};

            $data->{ $plugin->{name} } = $release;
        }

        $this->{_installed} = $data;
    }

    return $this->{_installed};
}

sub printRESTResponse {
    my ( $response, $status, $content ) = @_;
    $response->header(
        -status  => 200,
        -type    => 'text/plain',
        -charset => 'utf-8'
    );
    $response->print($content);
}

1;
