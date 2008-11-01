# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2006-2007 Michael Daum http://wikiring.de
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

use vars qw($tabPaneCounter $tabCounter);

###############################################################################
sub handleTabPane {
  my ($session, $params, $theTopic, $theWeb) = @_;

  my $tpId = 'jqTabPane'.($tabPaneCounter++);
  my $select = $params->{select} || '';

  $select =~ s/[^\d]//go;
  $select ||= 1;


  TWiki::Func::addToHEAD($tpId, <<"EOS");
<script type="text/javascript">
jQuery(function(\$) {
  \$("#$tpId").tabpane({select:$select});
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

  my $theText = $params->{_DEFAULT} || $params->{text} || 'Button';
  my $theBackground = $params->{bg} || '';
  my $theForeground = $params->{fg} || '';
  my $theStyle = $params->{style} || '';
  my $theSize = $params->{size} || '100%';
  my $theHref = $params->{href} || 'javascript:void(0);';
  my $theTitle = $params->{title};
  my $theOnClick = $params->{onclick};
  my $theOnMouseOver = $params->{onmouseover};
  my $theOnMouseOut = $params->{onmouseout};
  my $theOnFocus = $params->{onfocus};

  $theBackground = '#2ae' if $theBackground eq 'bluish';
  $theBackground = '#9d4' if $theBackground eq 'greenish';
  $theBackground = '#e1a' if $theBackground eq 'pinkish';

  $theSize = '80%' if $theSize eq 'tiny';
  $theSize = '90%' if $theSize eq 'small';
  $theSize = '150%' if $theSize eq 'big';
  $theSize = '200%' if $theSize eq 'large';

  $theBackground = 'background-color:'.$theBackground.'; ' 
    if $theBackground;

  $theForeground = 'color:'.$theForeground.'; '
    if $theForeground;

  my $result = 
    '<a class="jqButton" '.
    'href="'.$theHref.'" '.
    'style="'.
      $theBackground.
      $theForeground.
      'font-size:'.$theSize.'; '.
      'line-height:normal; '.
      $theStyle.
    '"';
  $result .= ' title="'.$theTitle.'" ' if defined $theTitle;
  $result .= ' onclick="'.$theOnClick.'" ' if defined $theOnClick;
  $result .= ' onmouseover="'.$theOnMouseOver.'" ' if defined $theOnMouseOver;
  $result .= ' onmouseout="'.$theOnMouseOut.'" ' if defined $theOnMouseOut;
  $result .= ' onfocus="'.$theOnFocus.'" ' if defined $theOnFocus;
  $result .= '><i></i><span><span></span><i></i>'.
    expandVariables($theText,$theWeb, $theTopic).
    '</span></a>';

  return $result;
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
