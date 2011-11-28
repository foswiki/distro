# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# UpdatesPlugin is Copyright (C) 2011 Foswiki Contributors
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

package Foswiki::Plugins::UpdatesPlugin;

use strict;
use warnings;

use Assert;

use Foswiki::Func ();

our $VERSION           = '$Rev$';
our $RELEASE           = '0.20';
our $SHORTDESCRIPTION  = 'Checks Foswiki.org for updates';
our $NO_PREFS_IN_TOPIC = 1;

use constant RESPECT_COOKIE => 1; # Set to 0 to ignore the cookie

sub initPlugin {

    Foswiki::Func::registerRESTHandler( 'report', \&_REST_report );
    Foswiki::Func::registerTagHandler( 'EXTENSIONVERSIONJSON', \&_EXTENSIONVERSIONJSON );

    # bail out if not an admin and not in view mode
    return 0 unless
	Foswiki::Func::isAnAdmin() &&
	Foswiki::Func::getContext()->{view};

    my $request = Foswiki::Func::getRequestObject();
    my $cookie  = $request->cookie("FOSWIKI_UPDATESPLUGIN");

    return 0 if RESPECT_COOKIE && defined($cookie) && $cookie <= 0; # 0: DoNothing

    Foswiki::Func::readTemplate("updatesplugin");

    my $installedPlugins = '';
    
    # we already know that the admin has to do something, so don't search again.
    # this happens when the admin continues to click around but did not action
    # on the info banner.
    $installedPlugins = Foswiki::Func::expandTemplate("installedplugins")
      unless defined($cookie);

    my $css = Foswiki::Func::expandTemplate("css");
    my $messageTmpl = Foswiki::Func::expandTemplate("messagetmpl");

    require Foswiki::Plugins::JQueryPlugin;

    Foswiki::Plugins::JQueryPlugin::createPlugin("cookie");
    Foswiki::Plugins::JQueryPlugin::createPlugin("tmpl");

    my $reportUrl;
    if ( $Foswiki::cfg{Plugins}{UpdatesPlugin}{ProxyUrl} ) {
	$reportUrl = $Foswiki::cfg{Plugins}{UpdatesPlugin}{ProxyUrl};
    } else {
	# SMELL read Foswiki::cfg{ExtensionsRepositories} and generate the report url on its base
	$reportUrl = $Foswiki::cfg{Plugins}{UpdatesPlugin}{ReportUrl};
    }
    $reportUrl ||= "http://foswiki.org/Extensions/UpdatesPluginReport";

    my $configureUrl = $Foswiki::cfg{Plugins}{UpdatesPlugin}{ConfigureUrl} 
      || Foswiki::Func::getScriptUrl(undef, undef, "configure");

    my $debug = (DEBUG) ? '.uncompressed' : '';

    Foswiki::Func::addToZone("head", "UPDATESPLUGIN::META", <<META);
<meta name="foswiki.UPDATESPLUGIN::REPORTURL" content="$reportUrl" />
<meta name="foswiki.UPDATESPLUGIN::CONFIGUREURL" content="$configureUrl" />
$css
$messageTmpl
META

    Foswiki::Func::addToZone(
	"script", "UPDATESPLUGIN::JS",
	<<JS, "JQUERYPLUGIN::FOSWIKI, JQUERYPLUGIN::COOKIE, JQUERYPLUGIN::TMPL" );
$installedPlugins
<script src="%PUBURLPATH%/%SYSTEMWEB%/UpdatesPlugin/jquery.updates$debug.js"></script>
JS

  return 1;
}

# SMELL: hack assumes structure of plugins controller object
sub _EXTENSIONVERSIONJSON {
    my ($session, %params, $topic, $web, $topicObject) = @_;

    # First get contribs and skins by poking into the System web. The versions returned
    # may include %$VERSION% if this is a pseudo-install
    my $list = Foswiki::Func::expandCommonVariables( '{%SEARCH{"1" nosearch="on" nototal="on" web="System" topic="*Skin,*Contrib" format="$topic" separator=","}%};' );

    my $data = {};
    foreach my $thing (split(',', $list)) {
	next unless $thing =~ /^([a-zA-Z0-9_]+)$/;
	my $mn = $1;
	my $mod = "Foswiki::Contrib::$mn";
	# SMELL: unconditional loading of contribs (is that so bad?)
	eval "require $mod";
	unless ($@) {
	    $data->{$mn} = eval "\$Foswiki::Contrib::${mn}::RELEASE"
		|| '%$RELEASE';
	}
    }

    # Get plugins; this should obtain "true" version numbers
    my $controller = $session->{plugins};
    foreach my $plugin ( @{ $controller->{plugins} } ) {
        $data->{$plugin->{name}} = eval "\$$plugin->{module}::RELEASE"
	    || '%$RELEASE';
    }
    require JSON;
    return JSON::to_json($data);
}

# the plugin can be configured to proxy the request for data. In this case the local server
# publishes a REST method that responds with the data from f.o - either cached locally or
# freshly mined.
sub _REST_report {
    my ( $session, $plugin, $verb, $response ) = @_;

    my $query = Foswiki::Func::getCgiQuery();
    my $list = $query->param( 'list' );
    my @exts = split( /,/, $list );
    my $works = Foswiki::Func::getWorkArea( 'UpdatesPlugin' );
    my $fh;
    print STDERR "Handling report\n";
    my @reply; # array of JSON-encoded structures

    my @unfound;
    foreach my $ext (@exts) {
	# if the cache is fresh, use it
	if ( -e "$works/$ext"
	     && (stat( "$works/$ext" ))[9] >
	     time() - $Foswiki::cfg{Plugins}{UpdatesPlugin}{ProxyCacheTimeout} ) {
	    # Use the cache
	    local $/ = undef;
	    if ( open( $fh, '<:encoding(UTF-8)', "$works/$ext" ) ) {
		push( @reply, <$fh> );
		close( $fh );
		next;
	    }
	}
	# Not found in cache, or cache out of date. Update cache.
	push( @unfound, $ext );
    }
    print STDERR "notfound ".join(',', @unfound)."\n";
    if (scalar(@unfound)) {
	# One or more things in the cache need an update from f.o

	# SMELL read Foswiki::cfg{ExtensionsRepositories} and generate the report url on its base
	my $reportUrl = $Foswiki::cfg{Plugins}{UpdatesPlugin}{ReportUrl} 
	|| "http://foswiki.org/Extensions/UpdatesPluginReport";
	$reportUrl .= "?list=".join(',', @unfound);
	# Pass through a controlled subset of possible params
	for my $param (qw(contenttype skin)) {
	    my $ct = $query->param( $param );
	    $reportUrl .= ";$param=$ct" if $param;
	}
	my $resource = Foswiki::Func::getExternalResource( $reportUrl );

	if ( !$resource->is_error() && $resource->isa( 'HTTP::Response' ) ) {
	    my $content = $resource->decoded_content();
	    # "Verify" the format of the resource and reduce to a perl array
	    if ( $content =~ /^foswikiUpdates.handleResponse\((\[.*\])\);$/s ) {
		require JSON;
		my $data = JSON::from_json( $1 );
		# Refresh the cache
		foreach my $ext ( @$data ) {
		    my $text = JSON::to_json($ext);
		    if (open( $fh, '>:encoding(UTF-8)', "$works/$ext->{topic}" )) {
			print $fh $text;
		    }
		    push( @reply, $text );
		}
	    } else {
		_backREST($response, 500, "Response from $reportUrl is unparseable: $content");
		return undef;
	    }
	} else {
	    _backREST($response, 500, "Failed to get $reportUrl: ".$resource->message());
	    return undef;
	}
    }
    # Rebuild the reply and send to the client
    _backREST($response, 200, 'foswikiUpdates.handleResponse([' . join(',', @reply ) . ']);');
    return undef;
}

sub _backREST {
    my ($response, $status, $content) = @_;
    $response->header(
	-status  => 200,
	-type    => 'text/plain',
	-charset => 'UTF-8'
        );
    $response->print( Encode::encode_utf8($content) );
#
}

1;
