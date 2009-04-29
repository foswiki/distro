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

package Foswiki::Plugins::JQueryPlugin::TABPANE;
use strict;

use base 'Foswiki::Plugins::JQueryPlugin::Plugin';

###############################################################################
sub init {
  my $this = shift;
  $this->{tabPaneCounter} = int(rand(1000));
  $this->{tabCounter} = int(rand(1000));

  my $header;

  if ($this->{debug}) {
   $header = <<'HERE';
<link rel="stylesheet" href="%PUBURLPATH%/%SYSTEMWEB%/JQueryPlugin/plugins/tabpane/jquery.tabpane.uncompressed.css" type="text/css" media="all" />
<script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/JQueryPlugin/plugins/tabpane/jquery.tabpane.uncompressed.js"></script>
HERE
  } else {
   $header = <<'HERE';
<link rel="stylesheet" href="%PUBURLPATH%/%SYSTEMWEB%/JQueryPlugin/plugins/tabpane/jquery.tabpane.css" type="text/css" media="all" />
<script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/JQueryPlugin/plugins/tabpane/jquery.tabpane.js"></script>
HERE
  }

  Foswiki::Func::addToHEAD("JQUERYPLUGIN::TABPANE", $header, 'JQUERYPLUGIN::FOSWIKI');
}

###############################################################################
sub handleTabPane {
  my ($this, $params, $theTopic, $theWeb) = @_;

  my $tpId = 'jqTabPane'.($this->{tabPaneCounter}++);
  my $select = $params->{select} || 1;
  my $autoMaxExpand = $params->{automaxexpand} || 'off';

  $autoMaxExpand = ($autoMaxExpand eq 'on')?'true':'false';

  Foswiki::Func::addToHEAD("JQUERYPLUGIN::TABPANE:$tpId", <<"HERE", 'JQUERYPLUGIN::TABPANE');
<script type="text/javascript">
//<![CDATA[
jQuery(function(\$) {
  \$("#$tpId").tabpane({select:'$select', autoMaxExpand:$autoMaxExpand});
});
//]]>
</script>
HERE
  return "<div class='jqTabPane' id='$tpId'>";
}

###############################################################################
sub handleTab {
  my ($this, $params, $theTopic, $theWeb) = @_;

  my $theName = $params->{_DEFAULT} || $params->{name} || 'Tab';
  my $beforeHandler = $params->{before} || '';
  my $afterHandler = $params->{after} || '';
  my $afterLoadHandler = $params->{afterload} || '';
  my $url = $params->{url} || '';
  my $container = $params->{container} || '';
  my $tabId = $params->{id};
  $tabId = 'jqTab'.($this->{tabCounter}++) unless defined $tabId;

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

  return "<div id='$tabId' class=\"jqTab$metaData\">\n<h2 >$theName</h2><div class='jqTabContents'>";
}

###############################################################################
sub handleEndTab {
  return '</div></div>';
}

###############################################################################
sub handleEndTabPane {
  return '</div>';
}

1;

