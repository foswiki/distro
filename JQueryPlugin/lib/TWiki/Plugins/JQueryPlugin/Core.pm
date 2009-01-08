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

package TWiki::Plugins::JQueryPlugin::Core;

use strict;
use constant DEBUG => 0; # toggle me

use vars qw($tabPaneCounter $tabCounter $jqueryFormHeader $iconTopic);

$jqueryFormHeader=<<'HERE';
<script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/JQueryPlugin/jquery.form.js"></script>
HERE

###############################################################################
sub init {
  $tabPaneCounter = 0;
  $tabCounter = 0;
}

###############################################################################
sub handleTabPane {
  my ($session, $params, $theTopic, $theWeb) = @_;

  my $tpId = 'jqTabPane'.($tabPaneCounter++);
  my $select = $params->{select} || '';
  my $autoMaxExpand = $params->{automaxexpand} || 'off';

  $select =~ s/[^\d]//go;
  $select ||= 1;

  $autoMaxExpand = ($autoMaxExpand eq 'on')?'true':'false';


  TWiki::Func::addToHEAD($tpId, <<"EOS");
<script type="text/javascript">
jQuery(function(\$) {
  \$("#$tpId").tabpane({select:$select, autoMaxExpand:$autoMaxExpand});
});
</script>
EOS

  return "<div class=\"jqTabPane\" id=\"$tpId\">";
}

###############################################################################
sub handleTab {
  my ($session, $params, $theTopic, $theWeb) = @_;

  my $theName = $params->{_DEFAULT} || $params->{name} || 'Tab';
  my $beforeHandler = $params->{before} || '';
  my $afterHandler = $params->{after} || '';
  my $afterLoadHandler = $params->{afterload} || '';
  my $url = $params->{url} || '';
  my $container = $params->{container} || '';
  my $tabId = 'jqTab'.($tabCounter++);

  my @metaData = ();
  if ($beforeHandler) {
    $beforeHandler =~ s/'/\\'/go;
    push @metaData,  "beforeHandler: '$beforeHandler'";
  }
  if ($afterHandler) {
    $afterHandler =~ s/'/\\'/go;
    push @metaData,  "afterHandler: '$afterHandler'";
  }
  if ($afterLoadHandler) {
    $afterLoadHandler =~ s/'/\\'/go;
    push @metaData,  "afterLoadHandler: '$afterLoadHandler'";
  }
  if ($url) {
    push @metaData , "url: '$url'";
  }
  if ($container) {
    push @metaData , "container: '$container'";
  }
  my $metaData = scalar(@metaData)?' {'.join(',', @metaData).'}':'';

  return "<div id=\"$tabId\" class=\"jqTab$metaData\">\n<h2 >$theName</h2><div class=\"jqTabContents\">";
}

###############################################################################
sub handleToggle {
  my ($session, $params, $theTopic, $theWeb) = @_;

  my $theText = $params->{_DEFAULT} || $params->{text} || 'Button';
  my $theBackground = $params->{bg};
  my $theForeground = $params->{fg};
  my $theStyle = $params->{style};
  my $theTitle = $params->{title} || '';
  my $theTarget = $params->{target};
  my $theEffect = $params->{effect} || 'toggle';

  my $style = '';
  $style .= "background-color:$theBackground;" if $theBackground;
  $style .= "color:$theForeground;" if $theForeground;
  $style .= $theStyle if $theStyle;
  $style = "style=\"$style\" " if $style;

  my $result = 
   '<a '.
   'href="#" '.
   "onclick=\"twiki.JQueryPlugin.toggle('$theTarget', '$theEffect'); return false;\" ".
   'title="'.$theTitle.'" '.
   $style.
   '>'.
   '<i></i><span><span></span><i></i>'.
   expandVariables($theText,$theWeb, $theTopic).
   '</span></a>';

  return $result;
}

###############################################################################
sub handleButton {
  my ($session, $params, $theTopic, $theWeb) = @_;

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
  $theIcon = getIconUrlPath($theWeb, $theTopic, $theIconName) if $theIconName;
  if ($theIcon) {
    $theText = 
      "<span class='jqButtonIcon' style='background-image:url($theIcon)'>$theText</span>";
  }
  $theText = "<span> $theText </span>";

  if ($theTarget) {
    my $url;

    if ($theTarget =~ /^(http|\/)$/) {
      $url = $theTarget;
    } else {
      my ($web, $topic) = TWiki::Func::normalizeWebTopicName($theWeb, $theTarget);
      $url = TWiki::Func::getViewUrl($web, $topic);
    }
    $theOnClick .= ";window.location.href='$url';";
  }

  if ($theType eq 'submit') {
    $theOnClick="\$(this).parents('form:first').submit();";
  }

  if ($theType eq 'reset') {
    $theOnClick="\$(this).parents('form:first').resetForm();";
    TWiki::Func::addToHEAD('jquery.form', $jqueryFormHeader);
  }
  if ($theType eq 'clear') {
    $theOnClick="\$(this).parents('form:first').clearForm();";
    TWiki::Func::addToHEAD('jquery.form', $jqueryFormHeader);
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

###############################################################################
sub getIconUrlPath {
  my ($web, $topic, $iconName) = @_;

  return '' unless $iconName;

  my $iconWeb = TWiki::Func::getTwikiWebname();
  $iconName =~ s/^.*\.(.*?)$/$1/;

  unless ($iconTopic) {
    $iconTopic = TWiki::Func::getPreferencesValue('JQUERYPLUGIN_ICONTOPIC')
      || 'FamFamFamSilkIcons';
  }

  return TWiki::Func::getPubUrlPath().'/'.$iconWeb.'/'.$iconTopic.'/'.$iconName.'.png';
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
