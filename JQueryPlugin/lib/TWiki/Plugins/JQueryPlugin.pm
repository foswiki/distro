# Copyright (c) 2007-2008 Michael Daum, http://michaeldaumconsulting.com
# 
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
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
# For licensing info read LICENSE file in the TWiki root.

package TWiki::Plugins::JQueryPlugin;
use strict;
use vars qw( 
  $VERSION $RELEASE $SHORTDESCRIPTION 
  $NO_PREFS_IN_TOPIC
  $doneInit $doneHeader
  $header
);

$VERSION = '$Rev$';
$RELEASE = '1.01'; 
$SHORTDESCRIPTION = 'jQuery <nop>JavaScript library for NextWiki';
$NO_PREFS_IN_TOPIC = 1;

$header = <<'HERE';
<link rel="stylesheet" href="%PUBURLPATH%/%SYSTEMWEB%/JQueryPlugin/jquery-all.css" type="text/css" media="all" />
<script type="text/javascript">
var twiki;
if (!twiki) {
  twiki = {};
}
twiki.pubUrl = "%PUBURL%";
twiki.pubUrlPath = '%PUBURLPATH%';
twiki.twikiWebName = '%SYSTEMWEB%';
twiki.mainWebName = '%MAINWEB%';
twiki.wikiName = '%WIKINAME%';
twiki.loginName = '%USERNAME%';
twiki.wikiUserName = '%WIKIUSERNAME%';
twiki.serverTime = '%SERVERTIME%';
twiki.ImagePluginEnabled = %IF{"context ImagePluginEnabled" then="true" else="false"}%;
twiki.MathModePluginEnabled = %IF{"context MathModePluginEnabled" then="true" else="false"}%;
</script>
<script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/JQueryPlugin/jquery-all.js"></script>
<script type="text/javascript">
ChiliBook.recipeFolder = twiki.pubUrlPath+'/'+twiki.twikiWebName+'/JQueryPlugin/chili/';
ChiliBook.automaticSelector = 'pre';
//ChiliBook.lineNumbers = true;
</script>
HERE


###############################################################################
sub initPlugin {
  my( $topic, $web, $user, $installWeb ) = @_;

  $doneInit = 0;
  $doneHeader = 0;
  TWiki::Func::registerTagHandler('BUTTON', \&handleButton );
  TWiki::Func::registerTagHandler('TOGGLE', \&handleToggle );
  TWiki::Func::registerTagHandler('CLEAR', \&handleClear );
  TWiki::Func::registerTagHandler('TABPANE', \&handleTabPane );
  TWiki::Func::registerTagHandler('ENDTABPANE', \&handleEndTabPane );
  TWiki::Func::registerTagHandler('TAB', \&handleTab );
  TWiki::Func::registerTagHandler('ENDTAB', \&handleEndTab );
  TWiki::Func::registerTagHandler('JQSCRIPT', \&handleJQueryScript );
  TWiki::Func::registerTagHandler('JQSTYLE', \&handleJQueryStyle );
  TWiki::Func::registerTagHandler('JQTHEME', \&handleJQueryTheme );
  TWiki::Func::registerTagHandler('JQIMAGESURLPATH', \&handleJQueryImagesUrlPath );

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
  require TWiki::Plugins::JQueryPlugin::Core;
  TWiki::Plugins::JQueryPlugin::Core::init(@_);
}

###############################################################################
sub handleButton {
  initCore();
  return TWiki::Plugins::JQueryPlugin::Core::handleButton(@_);
}

###############################################################################
sub handleToggle {
  initCore();
  return TWiki::Plugins::JQueryPlugin::Core::handleToggle(@_);
}

###############################################################################
sub handleTabPane {
  initCore();
  return TWiki::Plugins::JQueryPlugin::Core::handleTabPane(@_);
}

###############################################################################
sub handleTab {
  initCore();
  return TWiki::Plugins::JQueryPlugin::Core::handleTab(@_);
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
  return "<span class='twikiClear'></span>";
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
