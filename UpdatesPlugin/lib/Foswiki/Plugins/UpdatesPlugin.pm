# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# UpdatesPlugin is Copyright (C) 2011-2017 Foswiki Contributors
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

use Foswiki::Func ();

our $VERSION           = '1.03';
our $RELEASE           = '03 May 2017';
our $SHORTDESCRIPTION  = 'Checks Foswiki.org for updates';
our $NO_PREFS_IN_TOPIC = 1;
our $core;

use constant TRACE => 0;    # Set to 1 to enable debug mode

sub initPlugin {

    # bail out if not an admin and not in view mode
    my $context = Foswiki::Func::getContext();
    return 1
      unless Foswiki::Func::isAnAdmin()
      && ( $context->{view} || $context->{rest} );

    my $request = Foswiki::Func::getRequestObject();
    my $cookie;

    $cookie = $request->cookie("FOSWIKI_UPDATESPLUGIN") unless TRACE;

    return 1 if defined($cookie) && $cookie <= 0;    # 0: DoNothing

    Foswiki::Func::readTemplate("updatesplugin");

    # add stuff to page
    my $css         = Foswiki::Func::expandTemplate("css");
    my $messageTmpl = Foswiki::Func::expandTemplate("messagetmpl");

    Foswiki::Plugins::JQueryPlugin::createPlugin("cookie");
    Foswiki::Plugins::JQueryPlugin::createPlugin("render");

    my $jsFile =
      (TRACE) ? 'jquery.updates.uncompressed.js' : 'jquery.updates.js';

    my $configureUrl = $Foswiki::cfg{Plugins}{UpdatesPlugin}{ConfigureUrl}
      || Foswiki::Func::getScriptUrl( undef, undef, "configure" );

    Foswiki::Func::addToZone( "head", "UPDATESPLUGIN::META", <<META);
<meta name="foswiki.UPDATESPLUGIN::CONFIGUREURL" content="$configureUrl" />
$css
$messageTmpl
META

    Foswiki::Func::addToZone( "script", "UPDATESPLUGIN::JS",
        <<JS, "JQUERYPLUGIN::FOSWIKI, JQUERYPLUGIN::COOKIE, JQUERYPLUGIN::RENDER" );
<script src="%PUBURLPATH%/%SYSTEMWEB%/UpdatesPlugin/$jsFile"></script>
JS

    Foswiki::Func::registerRESTHandler(
        'check',
        sub {
            return getCore( shift, debug => TRACE )->handleRESTCheck(@_);
        },
        authenticate => 0,       # Safe.  initPlugin bails if user not an admin.
        validate     => 0,       # Doesn't update.
        http_allow   => 'GET',
        description => 'Check if any extensions are out-of-date',
    );

    return 1;
}

sub getCore {
    unless ($core) {
        require Foswiki::Plugins::UpdatesPlugin::Core;
        $core = new Foswiki::Plugins::UpdatesPlugin::Core(@_);
    }

    return $core;
}

1;
