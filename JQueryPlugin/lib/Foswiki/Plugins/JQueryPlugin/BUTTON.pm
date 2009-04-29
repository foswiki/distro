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

package Foswiki::Plugins::JQueryPlugin::BUTTON;
use strict;
use Foswiki::Plugins::JQueryPlugin::Core;
use base 'Foswiki::Plugins::JQueryPlugin::Plugin';

###############################################################################
sub init {
  my $this = shift;

  my $header;
  
  if ($this->{debug}) {
    $header = <<'HERE';
<link rel="stylesheet" href="%PUBURLPATH%/%SYSTEMWEB%/JQueryPlugin/plugins/button/jquery.button.uncompressed.css" type="text/css" media="all" />
HERE
  } else {
    $header = <<'HERE';
<link rel="stylesheet" href="%PUBURLPATH%/%SYSTEMWEB%/JQueryPlugin/plugins/button/jquery.button.css" type="text/css" media="all" />
HERE
  }

  Foswiki::Func::addToHEAD("JQUERYPLUGIN::BUTTON", $header, 'JQUERYPLUGIN::FOSWIKI');
}

###############################################################################
sub handleButton {
  my ($this, $params, $theTopic, $theWeb) = @_;

  my $theText = $params->{_DEFAULT} || $params->{value} || $params->{text} || 'Button';
  my $theHref = $params->{href} || '#';
  my $theOnClick = $params->{onclick};
  my $theOnMouseOver = $params->{onmouseover};
  my $theOnMouseOut = $params->{onmouseout};
  my $theOnFocus = $params->{onfocus};
  my $theTitle = $params->{title};
  my $theIconName = $params->{icon} || '';
  my $theAccessKey = $params->{accesskey};
  my $theId = $params->{id};
  my $theBg = $params->{bg} || '';
  my $theClass = $params->{class} || '';
  my $theStyle = $params->{style} || '';
  my $theTarget = $params->{target};
  my $theType = $params->{type} || 'button';

  my $theIcon;
  $theIcon = Foswiki::Plugins::JQueryPlugin::Core::getIconUrlPath($theWeb, $theTopic, $theIconName) 
    if $theIconName;

  if ($theIcon) {
    $theText = 
      "<span class='jqButtonIcon' style='background-image:url($theIcon)'>$theText</span>";
  }
  $theText = "<span> $theText </span>";

  if ($theTarget) {
    my $url;

    if ($theTarget =~ /^(http|\/).*$/) {
      $url = $theTarget;
    } else {
      my ($web, $topic) = Foswiki::Func::normalizeWebTopicName($theWeb, $theTarget);
      $url = Foswiki::Func::getViewUrl($web, $topic);
    }
    $theOnClick .= ";window.location.href='$url';";
  }

  if ($theType eq 'submit') {
    $theOnClick="\$(this).parents('form:first').submit();";
  }

  if ($theType eq 'reset') {
    $theOnClick="\$(this).parents('form:first').resetForm();";
    Foswiki::Plugins::JQueryPlugin::getPlugin($this->{session}, 'FORM');
  }
  if ($theType eq 'clear') {
    $theOnClick="\$(this).parents('form:first').clearForm();";
    Foswiki::Plugins::JQueryPlugin::getPlugin($this->{session}, 'FORM');
  }
  $theOnClick .= ';return false;' if $theOnClick;

  my $result = "<a class='jqButton $theBg $theClass' href='$theHref'";
  $result .= " accesskey='$theAccessKey' " if $theAccessKey;
  $result .= " id='$theId' " if $theId;
  $result .= " title='$theTitle' " if $theTitle;
  $result .= " onclick=\"$theOnClick\" " if $theOnClick;
  $result .= " onmouseover=\"$theOnMouseOver\" " if $theOnMouseOver;
  $result .= " onmouseout=\"$theOnMouseOut\" " if $theOnMouseOut;
  $result .= " onfocus=\"$theOnFocus\" " if $theOnFocus;
  $result .= " style='$theStyle' " if $theStyle;

  $result .= ">$theText</a>";
  $result .= "<input type='submit' style='display:none' />" if
    $theType eq 'submit';

  return $result;
}


1;
