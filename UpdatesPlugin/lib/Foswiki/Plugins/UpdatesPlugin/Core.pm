# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# UpdatesPlugin is Copyright (C) 2011-2019 Foswiki Contributors
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
use Foswiki::Plugins ();
use Foswiki::Configure::Dependency ();    # for _compare_extension_versions()

sub new {
    my $class = shift;

    my $this = bless(
        {
            debug => $Foswiki::cfg{Plugins}{UpdatesPlugin}{Debug} || 0,
            reportUrl => $Foswiki::cfg{Plugins}{UpdatesPlugin}{ReportUrl}
              || "https://foswiki.org/Extensions/UpdatesPluginReport",
            timeout => $Foswiki::cfg{Plugins}{UpdatesPlugin}{CacheTimeout}
              // 86400,
            exclude => $Foswiki::cfg{Plugins}{UpdatesPlugin}{ExcludeExtensions}
              || '',
            messageVar => $Foswiki::cfg{Plugins}{UpdatesPlugin}{MessageVariable}
              || 'BROADCASTMESSAGE',
            @_
        },
        $class
    );

    # fix params
    if ( $this->{exclude} ) {
        $this->{_excludePattern} =
          '^(' . join( '|', split( /\s*,\s*/, $this->{exclude} ) ) . ')$';

        $this->writeDebug( "exclude pattern = " . $this->{_excludePattern} );
    }

    my $request = Foswiki::Func::getRequestObject();
    $this->{_refresh} =
      ( $request->param("refresh") || '' ) =~ /^(on|true|yes|updates)$/ ? 1 : 0;

    Foswiki::Func::readTemplate("updatesplugin");

    return $this;
}

sub DESTROY {
    my $this = shift;

    undef $this->{_json};
    undef $this->{_available};
    undef $this->{_installed};
    undef $this->{_outdated};
    undef $this->{_excludePattern};
}

sub json {
    my $this = shift;

    unless ( defined $this->{_json} ) {
        $this->{_json} = JSON->new->allow_nonref;
    }

    return $this->{_json};
}

sub writeDebug {
    my ( $this, $msg ) = @_;

    return unless $this->{debug};

    #Foswiki::Func::writeDebug("UpdatesPlugin - $msg");
    print STDERR "UpdatesPlugin - $msg\n";
}

sub setMessage {
    my ( $this, $text, $params ) = @_;

    if ($params) {
        while ( my ( $key, $val ) = each %$params ) {
            $text =~ s/\$$key\b/$val/g;
        }
    }

    $this->writeDebug( $this->{messageVar} . ": " . $text );

    Foswiki::Func::setPreferencesValue( $this->{messageVar}, $text );
}

sub check {
    my $this = shift;

    my $error;
    my $outdated;

    try {
        $outdated = $this->getOutdated();
    }
    catch Error::Simple with {
        $error = shift;
    };

    if ( defined $error ) {
        print STDERR "ERROR: $error\n";
        $this->setMessage($error);
        return;
    }

    if ( $outdated && @$outdated ) {
        my $text = Foswiki::Func::expandTemplate("updates::message");
        $this->setMessage(
            $text,
            {
                nrPlugins       => scalar(@$outdated),
                outdatedPlugins => join( "&#44; ", sort @$outdated ),
            }
        );
    }

    return;
}

sub getOutdated {
    my $this = shift;

    unless ( defined $this->{_outdated} ) {

        # fetch from session store
        my $outdated =
          $this->{_refresh}
          ? undef
          : Foswiki::Func::getSessionValue("UPDATESPLUGIN::OUTDATED");

        if ( defined $outdated ) {

            $this->writeDebug("found in session");
            $this->{_outdated} = [ split( /\s*,\s*/, $outdated ) ];
            return $this->{_outdated};
        }
        else {
            $this->writeDebug("NOT found in session");
        }

        $this->getInstalled();
        $this->getAvailable();

        my @outdated = ();

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
              Foswiki::Configure::Dependency::_compare_extension_versions(
                $fakeObj, ">", $installed );
            if ($result) {
                push @outdated, $extName;
                $this->writeDebug(
"UPDATE: $extName: installed: $installed, available release=$release, available version=$version"
                );
            }
        }

        # set to session store
        Foswiki::Func::setSessionValue( "UPDATESPLUGIN::OUTDATED",
            join( ", ", sort @outdated ) );

        $this->{_outdated} = \@outdated;
    }

    return $this->{_outdated};
}

sub getAvailable {
    my $this = shift;

    unless ( defined $this->{_available} ) {

        my $works = Foswiki::Func::getWorkArea('UpdatesPlugin');
        my $fh;
        my @result = ();
        my @unfound;

        my $installed = $this->getInstalled();
        foreach my $ext ( keys %$installed ) {

            # if the cache is fresh, use it
            if (   -e "$works/$ext"
                && !$this->{_refresh}
                && ( stat("$works/$ext") )[9] > time() - $this->{timeout} )
            {

                # Use the cache
                local $/ = undef;
                if ( open( $fh, '<:encoding(utf-8)', "$works/$ext" ) ) {
                    my $data = $this->json->decode(<$fh>);
                    push @result, $data;
                    close($fh);
                    next;
                }
            }

            # Not found in cache, or cache out of date. Update cache.
            push @unfound, $ext;
        }

        if ( scalar(@unfound) ) {
            my $reportUrl =
                $this->{reportUrl}
              . "?list="
              . join( ',', @unfound )
              . ";contenttype=text/plain;skin=text";

            $this->writeDebug("calling $reportUrl");

            my $resource = Foswiki::Func::getExternalResource($reportUrl);

            if ( !$resource->is_error() && $resource->isa('HTTP::Response') ) {
                my $content = $resource->decoded_content();

                #$this->writeDebug("content=$content");

                # "Verify" the format of the resource and reduce to a perl array
                if ( $content =~
                    /^foswikiUpdates.handleResponse\((\[.*\])\);$/s )
                {
                    my $data  = $this->json->decode($1);
                    my %found = ();

                    # Refresh the cache
                    foreach my $ext (@$data) {

                        #print STDERR Data::Dumper::Dumper( \$ext );
                        my $text = $this->json->encode($ext);
                        $found{ $ext->{topic} } = 1;
                        if (
                            open(
                                $fh, '>:encoding(utf-8)',
                                "$works/$ext->{topic}"
                            )
                          )
                        {
                            print $fh $text;
                        }
                        push @result, $ext;
                    }

# remember null-result for unfound extensions not in the rest result provided by f.o
                    foreach my $ext (@unfound) {
                        next if $found{$ext};
                        $this->writeDebug("no info about $ext in report");

                        # generate a report based on the installed release
                        my $data = {
                            topic   => $ext,
                            release => $this->{_installed}{$ext}
                        };
                        my $text = $this->json->encode($data);
                        if ( open( $fh, '>:encoding(utf-8)', "$works/$ext" ) ) {
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
        $this->writeDebug(
            "performing local SEARCH in $Foswiki::cfg{SystemWebName}");

        my $list = Foswiki::Func::expandCommonVariables(
                '{%SEARCH{"1" nosearch="on" nototal="on" web="'
              . $Foswiki::cfg{SystemWebName}
              . '" topic="*Skin,*Contrib" format="$topic" separator=","}%};' );

        my $data = {};

        foreach my $thing ( split( /\s*,\s*/, $list ) ) {
            next unless $thing =~ /^([a-zA-Z0-9_]+)$/;
            next
              if defined $this->{_excludePattern}
              && $thing =~ /$this->{_excludePattern}/;

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

                #$this->writeDebug("found extension $mn, release = $release");

                $data->{$mn} = $release;
            }
        }

        # Get plugins; this should obtain "true" release numbers
        # SMELL: hack assumes structure of plugins controller object
        my $controller = $Foswiki::Plugins::SESSION->{plugins};
        foreach my $plugin ( @{ $controller->{plugins} } ) {
            next
              if defined $this->{_excludePattern}
              && $plugin->{name} =~ /$this->{_excludePattern}/;

            my $release = eval "\$$plugin->{module}::VERSION" || '%$VERSION';

            $this->writeDebug(
                "found plugin $plugin->{name}, release = $release");

            $data->{ $plugin->{name} } = $release;
        }

        $this->{_installed} = $data;
    }

    return $this->{_installed};
}

1;
