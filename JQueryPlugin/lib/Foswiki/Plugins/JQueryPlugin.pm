# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
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
package Foswiki::Plugins::JQueryPlugin;
use strict;
use vars qw( 
  $VERSION $RELEASE $SHORTDESCRIPTION 
  $NO_PREFS_IN_TOPIC
  $doneInit $doneHeader
  $header
);

$VERSION = '$Rev: 3740 $';
$RELEASE = '1.99'; 
$SHORTDESCRIPTION = 'jQuery <nop>JavaScript library for Foswiki';
$NO_PREFS_IN_TOPIC = 1;

$header = <<'HERE';
<link rel="stylesheet" href="%PUBURLPATH%/%SYSTEMWEB%/JQueryPlugin/jquery-all.css" type="text/css" media="all" />
<script type="text/javascript">
var foswiki;
if (!foswiki) {
  foswiki = {};
}
foswiki.scriptUrl = "%SCRIPTURL%";
foswiki.scriptUrlPath = "%SCRIPTURLPATH%";
foswiki.pubUrl = "%PUBURL%";
foswiki.pubUrlPath = '%PUBURLPATH%';
foswiki.systemWebName = '%SYSTEMWEB%';
foswiki.usersWebName = '%USERSWEB%';
foswiki.wikiName = '%WIKINAME%';
foswiki.loginName = '%USERNAME%';
foswiki.wikiUserName = '%WIKIUSERNAME%';
foswiki.serverTime = '%SERVERTIME%';
foswiki.ImagePluginEnabled = %IF{"context ImagePluginEnabled" then="true" else="false"}%;
foswiki.MathModePluginEnabled = %IF{"context MathModePluginEnabled" then="true" else="false"}%;
var twiki = foswiki; // temporary alias: DEPRECATED
</script>
<script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/JQueryPlugin/jquery-all.js"></script>
<script type="text/javascript">
ChiliBook.recipeFolder = foswiki.pubUrlPath+'/'+foswiki.systemWebName+'/JQueryPlugin/plugins/chili/recipes/';
ChiliBook.automaticSelector = 'pre';
//ChiliBook.lineNumbers = true;
</script>
HERE


###############################################################################
sub initPlugin {
  my( $topic, $web, $user, $installWeb ) = @_;

  $doneInit = 0;
  $doneHeader = 0;
  Foswiki::Func::registerTagHandler('BUTTON', \&handleButton );
  Foswiki::Func::registerTagHandler('TOGGLE', \&handleToggle );
  Foswiki::Func::registerTagHandler('CLEAR', \&handleClear );
  Foswiki::Func::registerTagHandler('TABPANE', \&handleTabPane );
  Foswiki::Func::registerTagHandler('ENDTABPANE', \&handleEndTabPane );
  Foswiki::Func::registerTagHandler('TAB', \&handleTab );
  Foswiki::Func::registerTagHandler('ENDTAB', \&handleEndTab );
  Foswiki::Func::registerTagHandler('JQSCRIPT', \&handleJQueryScript );
  Foswiki::Func::registerTagHandler('JQSTYLE', \&handleJQueryStyle );
  Foswiki::Func::registerTagHandler('JQTHEME', \&handleJQueryTheme );
  Foswiki::Func::registerTagHandler('JQIMAGESURLPATH', \&handleJQueryImagesUrlPath );

  return 1;
}

###############################################################################
sub commonTagsHandler {

  return if $doneHeader;
  $doneHeader = 1 if ($_[0] =~ s/<head>(.*?[\r\n]+)/<head>$1$header/o);
}

###############################################################################
sub initCore {
  return if $doneInit;
  $doneInit = 1;
  require Foswiki::Plugins::JQueryPlugin::Core;
  Foswiki::Plugins::JQueryPlugin::Core::init(@_);
}

###############################################################################
sub handleButton {
  initCore();
  return Foswiki::Plugins::JQueryPlugin::Core::handleButton(@_);
}

###############################################################################
sub handleToggle {
  initCore();
  return Foswiki::Plugins::JQueryPlugin::Core::handleToggle(@_);
}

###############################################################################
sub handleTabPane {
  initCore();
  return Foswiki::Plugins::JQueryPlugin::Core::handleTabPane(@_);
}

###############################################################################
sub handleTab {
  initCore();
  return Foswiki::Plugins::JQueryPlugin::Core::handleTab(@_);
}

###############################################################################
sub handleEndTab {
  return '</div></div>';
}

###############################################################################
sub handleEndTabPane {
  return '</div>';
}

###############################################################################
sub handleClear {
  return "<span class='foswikiClear'></span>";
}

###############################################################################
sub handleJQueryScript {
  my ($session, $params, $theTopic, $theWeb) = @_;   

  my $scriptFileName = $params->{_DEFAULT};
  return '' unless $scriptFileName;
  $scriptFileName .= '.js' unless $scriptFileName =~ /\.js$/;
  return "<script type=\"text/javascript\" src=\"%PUBURLPATH%/%SYSTEMWEB%/JQueryPlugin/$scriptFileName\"></script>";
}

###############################################################################
sub handleJQueryStyle {
  my ($session, $params, $theTopic, $theWeb) = @_;   

  my $styleFileName = $params->{_DEFAULT};
  return '' unless $styleFileName;
  $styleFileName .= '.css' unless $styleFileName =~ /\.css$/;
  return "<style type='text/css'>\@import url('%PUBURLPATH%/%SYSTEMWEB%/JQueryPlugin/$styleFileName');</style>";
}

###############################################################################
sub handleJQueryTheme {
  my ($session, $params, $theTopic, $theWeb) = @_;   

  my $themeName = $params->{_DEFAULT};
  return '' unless $themeName;

  return "<style type='text/css'>\@import url(\"%PUBURLPATH%/%SYSTEMWEB%/JQueryPlugin/themes/$themeName/$themeName.all.css\");</style>";
}

###############################################################################
sub handleJQueryImagesUrlPath {
  my ($session, $params, $theTopic, $theWeb) = @_;   
  my $image = $params->{_DEFAULT};
  return "%PUBURLPATH%/%SYSTEMWEB%/JQueryPlugin/images/$image" if defined $image;
  return "%PUBURLPATH%/%SYSTEMWEB%/JQueryPlugin/images";
}

1;
