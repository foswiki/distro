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
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html

package Foswiki::Plugins::JQueryPlugin::Core;
use strict;

our @iconSearchPath;

###############################################################################
sub init {
  @iconSearchPath = ();
}

###############################################################################
sub getIconUrlPath {
  my ($web, $topic, $iconName) = @_;

  return '' unless $iconName;

  unless (@iconSearchPath) {
    my $iconSearchPath = 
      Foswiki::Func::getPreferencesValue('JQUERYPLUGIN_ICONSEARCHPATH')
      || 'FamFamFamSilkIcons, FamFamFamSilkCompanion1Icons, FamFamFamFlagIcons, FamFamFamMiniIcons, FamFamFamMintIcons';
    @iconSearchPath = split(/\s*,\s*/, $iconSearchPath);
  }

  $iconName =~ s/^.*\.(.*?)$/$1/;
  my $iconPath;
  my $iconWeb = $Foswiki::cfg{SystemWebName};
  my $pubSystemDir = $Foswiki::cfg{PubDir}.'/'.$Foswiki::cfg{SystemWebName};

  foreach my $path (@iconSearchPath) {
    if (-f $pubSystemDir.'/'.$path.'/'.$iconName.'.png') {
      return Foswiki::Func::getPubUrlPath().'/'.$iconWeb.'/'.$path.'/'.$iconName.'.png';
    }
  }

  return '';
}

###############################################################################
sub expandVariables {
  my ($theFormat, $web, $topic, %params) = @_;

  return '' unless $theFormat;
  
  foreach my $key (keys %params) {
    $theFormat =~ s/\$$key\b/$params{$key}/g;
  }
  $theFormat =~ s/\$percnt/\%/go;
  $theFormat =~ s/\$nop//g;
  $theFormat =~ s/\$n/\n/go;
  $theFormat =~ s/\$dollar/\$/go;

  return $theFormat;
}

1;
