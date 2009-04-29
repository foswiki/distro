# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
# 
# Copyright (C) 2006-2009 Michael Daum, http://michaeldaumconsulting.com
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

package Foswiki::Plugins::JQueryPlugin::FOSWIKI;
use strict;
use Foswiki::Func;
use base 'Foswiki::Plugins::JQueryPlugin::Plugin';

sub init {
  my $this = shift;

  my $header= <<'HERE';
<meta name="foswiki.scriptUrl" content="%SCRIPTURL%" />
<meta name="foswiki.scriptUrlPath" content="%SCRIPTURLPATH%" />
<meta name="foswiki.pubUrl" content="%PUBURL%" />
<meta name="foswiki.pubUrlPath" content="%PUBURLPATH%" />
<meta name="foswiki.systemWebName" content="%SYSTEMWEB%" />
<meta name="foswiki.usersWebName" content="%USERSWEB%" />
<meta name="foswiki.wikiName" content="%WIKINAME%" />
<meta name="foswiki.loginName" content="%USERNAME%" />
<meta name="foswiki.wikiUserName" content="%WIKIUSERNAME%" />
<meta name="foswiki.serverTime" content="%SERVERTIME%" />
<meta name="foswiki.ImagePluginEnabled" content="%IF{"context ImagePluginEnabled" then="true" else="false"}%" />
<meta name="foswiki.MathModePluginEnabled" content="%IF{"context MathModePluginEnabled" then="true" else="false"}%" />
HERE

  unless ($this->{debug}) {
    $header .= '<script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/JQueryPlugin/jquery-all.js"></script>';
  } else {
    $header .= <<'MORE';
<script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/JQueryPlugin/jquery.uncompressed.js"></script>
<script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/JQueryPlugin/plugins/easing/jquery.easing.uncompressed.js"></script>
<script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/JQueryPlugin/plugins/metadata/jquery.metadata.uncompressed.js"></script>
<script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/JQueryPlugin/plugins/bgiframe/jquery.bgiframe.uncompressed.js"></script>
<script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/JQueryPlugin/plugins/hoverIntent/jquery.hoverIntent.uncompressed.js"></script>
<script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/JQueryPlugin/plugins/foswiki/jquery.foswiki.uncompressed.js"></script>
MORE
  }

  Foswiki::Func::addToHEAD('JQUERYPLUGIN::FOSWIKI', $header);

}

1;
