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

use vars qw($tabPaneCounter $tabCounter $jqueryFormHeader @iconSearchPath $toggleCounter);

$jqueryFormHeader=<<'HERE';
<script type="text/javascript" src="%PUBURLPATH%/%TWIKIWEB%/JQueryPlugin/jquery.form.js"></script>
HERE

###############################################################################
sub init {
  $tabPaneCounter = int(rand(1000));
  $tabCounter = int(rand(1000));
  @iconSearchPath = ();
  $toggleCounter = 0;
}

###############################################################################
sub handleTabPane {
  my ($session, $params, $theTopic, $theWeb) = @_;

  my $tpId = 'jqTabPane'.($tabPaneCounter++);
  my $select = $params->{select} || 1;
  my $autoMaxExpand = $params->{automaxexpand} || 'off';

  $autoMaxExpand = ($autoMaxExpand eq 'on')?'true':'false';

  my $javascript = <<"EOS";
<script type="text/javascript">
//<![CDATA[
jQuery(function(\$) {
  \$("#$tpId").tabpane({select:'$select', autoMaxExpand:$autoMaxExpand});
});
//]]>
</script>
EOS
  TWiki::Func::addToHEAD("jqTabPane:$tpId", $javascript);
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
  my $tabId = $params->{id};
  $tabId = 'jqTab'.($tabCounter++) unless defined $tabId;

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
  $style = "style='$style'" if $style;

  my $showEffect;
  my $hideEffect;
  if ($theEffect eq 'fade') {
    $showEffect = $hideEffect = "animate({height:'toggle', opacity:'toggle'},'fast')";
  } elsif ($theEffect eq 'slide') {
    $showEffect = $hideEffect = "slideToggle('fast')";
  } elsif ($theEffect eq 'ease') {
    $showEffect = $hideEffect = "slideToggle({duration:400, easing:'easeInOutQuad'})";
  } elsif ($theEffect eq 'bounce') {
    $showEffect = "slideUp({ duration:300, easing:'easeInQuad'})";
    $hideEffect = "slideDown({ duration:500, easing:'easeOutBounce'})";
  } else {
    $showEffect = $hideEffect = "toggle()";
  }
  my $cmd = "\$('$theTarget').each(function() {\$(this).is(':visible')?\$(this).$showEffect:\$(this).$hideEffect;})";

  $toggleCounter++;
  my $toggleId = "toggle$toggleCounter";

  return
   "<a id='toggle$toggleCounter' href='#' onclick=\"$cmd; return false;\" title='".$theTitle."' ".$style.'>'.
   "<span>".
   expandVariables($theText,$theWeb, $theTopic).'</span></a>';
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

    if ($theTarget =~ /^(http|\/).*$/) {
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

  unless (@iconSearchPath) {
    my $iconSearchPath = 
      TWiki::Func::getPreferencesValue('JQUERYPLUGIN_ICONSEARCHPATH')
      || 'FamFamFamSilkIcons, FamFamFamSilkCompanion1Icons, FamFamFamFlagIcons, FamFamFamMiniIcons, FamFamFamMintIcons';
    @iconSearchPath = split(/\s*,\s*/, $iconSearchPath);
  }

  $iconName =~ s/^.*\.(.*?)$/$1/;
  my $iconPath;
  my $iconWeb = TWiki::Func::getTwikiWebname();
  my $pubSystemDir = TWiki::Func::getPubDir().'/'.TWiki::Func::getTwikiWebname();

  foreach my $path (@iconSearchPath) {
    if (-f $pubSystemDir.'/'.$path.'/'.$iconName.'.png') {
      return TWiki::Func::getPubUrlPath().'/'.$iconWeb.'/'.$path.'/'.$iconName.'.png';
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
