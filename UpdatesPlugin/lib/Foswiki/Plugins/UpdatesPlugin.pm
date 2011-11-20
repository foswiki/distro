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

use Foswiki::Func ();

our $VERSION           = '$Rev$';
our $RELEASE           = '0.10';
our $SHORTDESCRIPTION  = 'Checks Foswiki.org for updates';
our $NO_PREFS_IN_TOPIC = 1;

sub initPlugin {

    # bail out if not an admin and not in view mode
    return 1 unless Foswiki::Func::isAnAdmin() && Foswiki::Func::getContext()->{view};

    my $request = Foswiki::Func::getRequestObject();
    my $cookie  = $request->cookie("FOSWIKI_UPDATESPLUGIN");

    return 1 if defined($cookie) && $cookie == 0; # 0: DoNothing

    Foswiki::Func::readTemplate("updatesplugin");

    my $installedPlugins = '';
    
    # we already know that the admin has to do something. so don't search again.
    # this happens when the admin continues to click around but did not action
    # on the info banner.
    $installedPlugins = Foswiki::Func::expandTemplate("installedplugins")
      unless defined($cookie);

    my $css = Foswiki::Func::expandTemplate("css");
    my $messageTmpl = Foswiki::Func::expandTemplate("messagetmpl");

    require Foswiki::Plugins::JQueryPlugin;

    Foswiki::Plugins::JQueryPlugin::createPlugin("cookie");
    Foswiki::Plugins::JQueryPlugin::createPlugin("tmpl");

    # SMELL read Foswiki::cfg{ExtensionsRepositories} and generate the report url on its base
    my $reportUrl = $Foswiki::cfg{UpdatesPlugin}{ReportUrl} 
      || "http://foswiki.org/Extensions/UpdatesPluginReport";

    my $configureUrl = $Foswiki::cfg{UpdatesPlugin}{ConfigureUrl} 
      || Foswiki::Func::getScriptUrl(undef, undef, "configure");

    Foswiki::Func::addToZone("head", "UPDATESPLUGIN::META", <<META);
<meta name="foswiki.UPDATESPLUGIN::REPORTURL" content="$reportUrl" />
<meta name="foswiki.UPDATESPLUGIN::CONFIGUREURL" content="$configureUrl" />
$css
$messageTmpl
META

    Foswiki::Func::addToZone( "script", "UPDATESPLUGIN::JS", <<JS, "JQUERYPLUGIN::FOSWIKI, JQUERYPLUGIN::COOKIE, JQUERYPLUGIN::TMPL" );
$installedPlugins
<script src="%PUBURLPATH%/%SYSTEMWEB%/UpdatesPlugin/jquery.updates.js"></script>
JS

  return 1;
}

1;
