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
  %plugins
);

$VERSION = '$Rev: 3740 $';
$RELEASE = '1.99'; 
$SHORTDESCRIPTION = 'jQuery <nop>JavaScript library for Foswiki';
$NO_PREFS_IN_TOPIC = 1;

###############################################################################
sub initPlugin {
  my( $topic, $web, $user, $installWeb ) = @_;

  %plugins = ();
  Foswiki::Func::registerTagHandler('TABPANE', \&handleTabPane );
  Foswiki::Func::registerTagHandler('ENDTABPANE', \&handleEndTabPane );
  Foswiki::Func::registerTagHandler('TAB', \&handleTab );
  Foswiki::Func::registerTagHandler('ENDTAB', \&handleEndTab );

  Foswiki::Func::registerTagHandler('BUTTON', \&handleButton );
  Foswiki::Func::registerTagHandler('TOGGLE', \&handleToggle );
  Foswiki::Func::registerTagHandler('CLEAR', \&handleClear );
  Foswiki::Func::registerTagHandler('JQSCRIPT', \&handleJQueryScript ); # DEPRECATED
  Foswiki::Func::registerTagHandler('JQSTYLE', \&handleJQueryStyle ); # DEPRECATED
  Foswiki::Func::registerTagHandler('JQTHEME', \&handleJQueryTheme );
  Foswiki::Func::registerTagHandler('JQREQUIRE', \&handleJQueryRequire );

  # required
  getPlugin($Foswiki::Plugins::SESSION, 'FOSWIKI');

  return 1;
}

###############################################################################
sub getPlugin {
  my ($session, $name) = @_;

  $name = uc($name);

  unless (defined $plugins{$name}) {
    my $packageName = 'Foswiki::Plugins::JQueryPlugin::'.$name;
    eval "use $packageName;";
    if ($@) {
      Foswiki::Func::writeWarning("ERROR: can't load jQuery plugin $name: $@");
      $plugins{$name} = 0;
    } else {
      $plugins{$name} = $packageName->new($session);
    }
  }

  return $plugins{$name};
}

###############################################################################
sub handleButton {
  my $session = shift;
  my $plugin = getPlugin($session, 'BUTTON');
  return $plugin->handleButton(@_) if $plugin;
  return '';
}

###############################################################################
sub handleToggle {
  my $session = shift;
  my $plugin = getPlugin($session, 'TOGGLE');
  return $plugin->handleToggle(@_) if $plugin;
  return '';
}

###############################################################################
sub handleTabPane {
  my $session = shift;
  my $plugin = getPlugin($session, 'TABPANE');
  return $plugin->handleTabPane(@_) if $plugin;
  return '';
}

###############################################################################
sub handleTab {
  my $session = shift;
  my $plugin = getPlugin($session, 'TABPANE');
  return $plugin->handleTab(@_) if $plugin;
  return '';
}

###############################################################################
sub handleEndTab {
  my $session = shift;
  my $plugin = getPlugin($session, 'TABPANE');
  return $plugin->handleEndTab(@_) if $plugin;
  return '';
}

###############################################################################
sub handleEndTabPane {
  my $session = shift;
  my $plugin = getPlugin($session, 'TABPANE');
  return $plugin->handleEndTabPane(@_) if $plugin;
  return '';
}

###############################################################################
sub handleClear {
  return "<span class='foswikiClear'></span>";
}

###############################################################################
sub handleJQueryRequire {
  my ($session, $params, $theTopic, $theWeb) = @_;   

  my $pluginName = $params->{_DEFAULT};
  my $plugin = getPlugin($session, $pluginName);
  return "<span class='foswikiAlert'>Error: no such plugin $pluginName</span>"
    unless $plugin;

  return '';
}

###############################################################################
# deprecated
sub handleJQueryScript {
  my ($session, $params, $theTopic, $theWeb) = @_;   

  my $scriptFileName = $params->{_DEFAULT};
  return '' unless $scriptFileName;
  $scriptFileName .= '.js' unless $scriptFileName =~ /\.js$/;
  return "<script type=\"text/javascript\" src=\"%PUBURLPATH%/%SYSTEMWEB%/JQueryPlugin/$scriptFileName\"></script>";
}

###############################################################################
# deprecated
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

  return "<style type='text/css'>\@import url(\"%PUBURLPATH%/%SYSTEMWEB%/JQueryPlugin/themes/$themeName/ui.all.css\");</style>";
}

1;
