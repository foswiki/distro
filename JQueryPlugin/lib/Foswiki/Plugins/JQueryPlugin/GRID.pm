# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
# 
# Copyright (C) 2006-2010 Michael Daum, http://michaeldaumconsulting.com
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

package Foswiki::Plugins::JQueryPlugin::GRID;
use strict;

use base 'Foswiki::Plugins::JQueryPlugin::Plugin';
use Foswiki::Form ();

use constant DEBUG => 0; # toggle me
sub writeDebug {
  print STDERR "- GRID - $_[0]\n" if DEBUG;
}

=begin TML

---+ package Foswiki::Plugins::JQueryPlugin::GRID

This is the perl stub for the jquery.grid plugin.

=cut

=begin TML

---++ ClassMethod new( $class, $session, ... )

Constructor

=cut

sub new {
  my $class = shift;
  my $session = shift || $Foswiki::Plugins::SESSION;

  my $this = bless($class->SUPER::new( 
    $session,
    name => 'Grid',
    version => '3.6.0',
    author => 'Tony Tomov',
    homepage => 'http://www.trirand.com/blog/',
    javascript => ['jquery.jqgrid.js', 'jquery.jqgrid.init.js'],
    css => ['css/jquery.jqgrid.css'],
    dependencies => ['ui', 'JQUERYPLUGIN::THEME', 'JQUERYPLUGIN::GRID::LANG'], 
  ), $class);

  $this->{fieldNameMap} = {
    'topic' => 'Topic', 'Topic' => 'topic',
    'info.date' => 'Modified', 'Modified' => 'info.date',
    'info.author' => 'Changed By', 'Changed By' => 'info.author',
  };

  return $this;
}

=begin TML

---++ ClassMethod init( $this )

Initialize this plugin by adding the required static files to the html header

=cut

sub init {
  my $this = shift;

  return unless $this->SUPER::init();

  # open matching localization file if it exists
  my $langTag = $this->{session}->i18n->language();
  my $localePrefix = $Foswiki::cfg{SystemWebName}.'/JQueryPlugin/plugins/grid/i18n';
  my $localePath = $localePrefix.'/grid.locale-'.$langTag.'.js';
  $localePath = $localePrefix.'/grid.locale-en.js' 
    unless -f $Foswiki::cfg{PubDir}.'/'.$localePath;

  my $header .= <<"HERE";
<script type="text/javascript" src="$Foswiki::cfg{PubUrlPath}/$localePath"></script>
HERE
  Foswiki::Func::addToHEAD("JQUERYPLUGIN::GRID::LANG", $header, 'JQUERYPLUGIN::UI');
}

=begin TML

---++ ClassMethod handleGrid( $this, $params, $topic, $web ) -> $result

Tag handler for =%<nop>GRID%=. 

=cut

sub handleGrid {
  my ($this, $params, $topic, $web) = @_;

  my $theQuery = $params->{_DEFAULT} || $params->{query} || '';
  my $theWeb = $params->{web} || $web;
  my $theForm = $params->{form} || '';
  my $theCols = $params->{columns};
  my $theTitles = $params->{titles};
  my $theRows = $params->{rows} || 20;
  my $theRowNumbers = $params->{rownumbers} || 'off';
  my $theInclude = $params->{include};
  my $theExclude = $params->{exclude};
  my $theEditable = $params->{editable} || 'off';
  my $theFilterbar = $params->{filterbar} || 'off';
  my $theToolbar = $params->{toolbar} || 'off'; # navGrid
  my $theSort = $params->{sort};
  my $theReverse = $params->{reverse} || 'off';
  my $theCaption = $params->{caption};
  my $thePager = $params->{pager} || 'off';
  my $theViewRecords = $params->{viewrecords} || 'on';
  my $theHeight = $params->{height};
  my $theWidth = $params->{width};
  my $theScroll = $params->{scroll} || 'off';
  my $theRowList = $params->{rowlist} || '5, 10, 20, 30, 40, 50, 100';

  # sanitize params
  $theRowNumbers = ($theRowNumbers eq 'on')?'true':'false';
  my $gridId = "jqGrid".Foswiki::Plugins::JQueryPlugin::Plugins::getRandom();
  my $pagerId = "jqGridPager".Foswiki::Plugins::JQueryPlugin::Plugins::getRandom();

  my $filterToolbar = ($theFilterbar eq 'on'?'.filterToolbar()':'');
  my $navGrid = ($theToolbar eq 'on'?'.navGrid(\'#'.$pagerId.'\',{search:false})':'');

  my $sortOrder = ($theReverse eq 'on'?'desc':'asc');

  my @metadata = (
    "foswiki_filtertoolbar:".($theFilterbar eq 'on'?'true':'false'),
    "foswiki_navgrid:".($theToolbar eq 'on'?'true':'false'),
    "rowNum:$theRows",
    "rowList:[$theRowList]",
    "sortorder: '$sortOrder'",
    "rownumbers: $theRowNumbers",
  );
  
  push @metadata, "pager:'$pagerId'" if $thePager eq 'on';
  push @metadata, "sortname: '$theSort'" if $theSort;
  push @metadata, "height: '$theHeight'" if defined $theHeight;
  push @metadata, 'scroll: true' if $theScroll eq 'on';
  push @metadata, 'viewrecords: true' if $theViewRecords eq 'on';

  if ($theWidth) {
    if ($theWidth eq 'auto') {
      push @metadata, "autowidth: true";
    } else {
      push @metadata, "width: '$theWidth'";
    }
  }
  if ($theWidth || $theHeight) {
    push @metadata, 'forceFit: true';
  }

  push @metadata, "caption:'$theCaption'" if defined $theCaption; 

  if ($theQuery || $theForm) {
    # ajax mode #############################
    if (!$theQuery && $theForm) {
      $theQuery = "name='$theForm'";
    }

    my $theFormWeb = $theWeb;
    ($theFormWeb, $theForm) = Foswiki::Func::normalizeWebTopicName($theFormWeb, $theForm);

    my @selectedFields = ();
    if ($theCols) {
      foreach my $fieldName (split(/\s*,\s*/, $theCols)) {
        push @selectedFields, $fieldName;
      }
    } else {
      my $form = new Foswiki::Form($this->{session}, $theFormWeb, $theForm);
      @selectedFields = map {$_->{name}} @{$form->getFields()} if $form;
    }

    if ($theInclude) {
      @selectedFields = grep {/^($theInclude)$/} @selectedFields;
    }
    if ($theExclude) {
      @selectedFields = grep {!/^($theExclude)$/} @selectedFields;
    }

    my $colNames;
    if ($theTitles) {
      $colNames = "['".join("','", split(/\s*,\s*/, $theTitles))."']";
    } else {
      $colNames = "['".join("','", @selectedFields)."']";
    }
    push @metadata, "colNames: $colNames";

    my @colModel;
    foreach my $fieldName (@selectedFields) { 
      $theSort = $fieldName unless $theSort;
      my $col = "{name:'".$fieldName."', index:'".$fieldName."'}";
      push @colModel, $col;
    }
    push @metadata, 'colModel: ['.join(",\n", @colModel).']';

    my $gridConnectorUrl = Foswiki::Func::getScriptUrl('JQueryPlugin', 'gridconnector', 'rest',
      theweb=>$theWeb,
      thetopic=>$topic,
      query=>$theQuery,
      columns=>join(',', @selectedFields),
    );
    $gridConnectorUrl =~ s/'/\\'/g;
    push @metadata, "url:'$gridConnectorUrl'";
    push @metadata, "datatype: 'xml'";
    push @metadata, "mtype: 'GET'";

    my $metadata = '{'.join(",\n", @metadata)."}\n";
    my $jsTemplate = <<"HERE";
<script type="text/javascript">
jQuery(document).ready(function(){ 
  jQuery('#$gridId').jqGrid($metadata)$filterToolbar$navGrid;
}); 
</script>
HERE

    Foswiki::Func::addToHEAD("JQUERYPLUGIN::GRID::$gridId", $jsTemplate, 'JQUERYPLUGIN::GRID');

    my $result = "<table id='$gridId'></table>";
    $result .= "<div id='$pagerId'></div>" if $thePager eq 'on';
    return $result;
  } else {
    # table conversion mode #############################
    my $metadata = '{'.join(', ', @metadata).'}';
    return "<div class=\"jqTable2Grid $metadata\"></div>";
  }
}

=begin TML

---++ ClassMethod restGridConnector( $this ) -> $xml

rest handler for the grid widget

=cut

sub restGridConnector {
   my ($this, $subject, $verb, $response ) = @_;

  my $request = Foswiki::Func::getCgiQuery();
  my $query = $request->param('query') || '1';
  $query = urlDecode($query);

  my $columns = urlDecode($request->param('columns') || '');
  foreach my $fieldName (split(/\s*,\s*/, $columns)) {
    my $values = $request->param($fieldName);
    next unless $values;

    $fieldName = $this->column2FieldName($fieldName);

    foreach my $value (split(/\s*,\s*/, $values)) {
      $query .= " AND lc($fieldName)=~lc('$value')";
    }
  }

  my $sort = $request->param('sidx') || '';
  my $sord = $request->param('sord') || 'asc';

  my $reverse = ($sord eq 'desc'?'on':'off');

  my $web = $request->param('theweb') || $this->{session}->{webName};
  my $topic = $request->param('thetopic') || $this->{session}->{topicName};

  my $count = $this->count($web, $query);
  unless (defined $count) {
    returnRESTResult($response, 500, "ERROR: can't count topis in web $web using $query");
    return '';
  }

  my $rows = $request->param('rows') || 10;
  my $totalPages = int($count / $rows + 1);

  my $page = $request->param('page') || 1;
  $page = $totalPages if $page > $totalPages;
  $page = 1 if $page < 1;

  my $end = $rows * $page;
  my $start = $end - $rows;
  $start = 0 if $start < 0;

  # create xml
  my $result = $this->search(
    web=>$web,
    topic=>$topic,
    query=>$query,
    sort=>$sort, 
    reverse=>$reverse, 
    start=>$start, 
    rows=>$rows,
    columns=>$columns,
    totalPages=>$totalPages,
    page=>$page,
    count=>$count,
  );
  if (defined $result) {
    $this->{session}->writeCompletePage($result, 'view', 'text/xml');
  } else {
    returnRESTResult($response, 500, "ERROR: can't search in web $web using $query");
  }
  return '';
}

=begin TML

---++ ClassMethod count( $web, $query ) -> $integer

Counts the number of topics the query matches. This will use Foswiki:Extensions/DBCachePlugin
if installed and fallback to standard means if not.

=cut

sub count {
  my ($this, $web, $query) = @_;

  my $count;
  if (Foswiki::Func::getContext->{DBCachePluginEnabled}) {
    require Foswiki::Plugins::DBCachePlugin;
    my $db = Foswiki::Plugins::DBCachePlugin::getDB($web);
    if(defined $db) {
      my ($topicNames, $hits, $msg) = $db->dbQuery($query);
      if ($topicNames) {
        $count = scalar(@$topicNames);
      } else {
        writeDebug("ERROR in count($query): $msg");
      }
    }
  } else {
    # TODO
    die "count not implemented";
  }

  return $count;
}

=begin TML

---++ ClassMethod column2FieldName( $fieldName ) -> $realFieldName

maps a column name to the real property in the TOM. returns the
identical fieldName if no mapping is defined

=cut

sub column2FieldName {
  my ($this, $fieldName) = @_;

  return unless defined $fieldName;

  foreach my $key (keys %{$this->{fieldNameMap}}) {
    return $this->{fieldNameMap}{$key} 
      if $key eq $fieldName;
  }

  return $fieldName;
}


=begin TML

---++ ClassMethod search( $web, %params ) -> $xml

search $web and generate an xml result suitable for jquery.grid

This will use Foswiki:Extensions/DBCachePlugin
if installed and fallback to standard means if not.

=cut

sub search {
  my ($this, %params) = @_;
  
  my $tml;
  my $context = Foswiki::Func::getContext();

  $params{sort} = $this->column2FieldName($params{sort});

  if ($context->{DBCachePluginEnabled}) {
    $tml = '%DBQUERY{"'.$params{query}.'" web="'.$params{web}.'" reverse="'.$params{reverse}.'" sort="'.$params{sort}.'" skip="'.$params{start}.'" limit="'.$params{rows}.'" ';
    $tml .= 'separator="$n"';
    $tml .= 'footer="$n</noautolink></rows>"';
    $tml .= 'header="<?xml version=\'1.0\' encoding=\'utf-8\'?><noautolink><rows>$n';
    $tml .= '  <page>'.$params{page}.'</page>$n';
    $tml .= '  <total>'.$params{totalPages}.'</total>$n';
    $tml .= '  <records>'.$params{count}.'</records>$n" ';
    $tml .= 'format="<row id=\'$index\'>$n';

    my @selectedFields = split(/\s*,\s*/, $params{columns});
    foreach my $fieldName (@selectedFields) {
      my $cell = '';
      $fieldName = $this->column2FieldName($fieldName);
      if ($fieldName =~ /Image|Photo/) {
        if ($context->{ImagePluginEnabled}) {
          $cell .= '$percntIMAGE{\"$expand('.$fieldName.')\" size=\"135\" type=\"plain\" warn=\"off\"}$percnt';
        } else {
          $cell .= '<img src=\'$expand('.$fieldName.')\' style=\'max-width:135px\' />';
        }
      } elsif ($fieldName =~ /info.author/) {
        $cell .= '[[%USERSWEB%.$expand(info.author)][$expand(info.author)]]';
      } elsif ($fieldName =~ /info.date|createdate/) {
        $cell .= '$formatTime('.$fieldName.')';
      } elsif ($fieldName eq 'topic') {
        $cell .= '[[$web.$topic][$topic]]';
      } else {
        $cell .= '$expand('.$fieldName.')';
      }
      $tml .= '<cell><![CDATA['.$cell.']]></cell>'."\n";
    }
    $tml .= '</row>"}%';

  } else {
    # TODO
    die "count not implemented";
  }

  $tml = Foswiki::Func::expandCommonVariables($tml, $params{topic}, $params{web});
  $tml = Foswiki::Func::renderText($tml, $params{web}, $params{topic});
  return $tml;
}


=begin TML

---++ StaticMethod returnRESTResult( $response, $status, $text )

helper function to generate REST error messages 

=cut

sub returnRESTResult {
  my ($response, $status, $text) = @_;

  $response->header(
    -status  => $status,
    -type    => 'text/html',
  );

  $response->print("$text\n");
  writeDebug($text) if $status >= 400;
}

=begin TML

---++ StaticMethod urlDecode( $text ) -> $text

from Fowiki.pm

=cut

sub urlDecode {
  my $text = shift;
  $text =~ s/%([\da-f]{2})/chr(hex($1))/gei;
  return $text;
}

=begin TML

---++ StaticMethod urlEncode( $text ) -> $text

from Fowiki.pm

=cut

sub urlEncode {
  my $text = shift;
  $text =~ s/([^0-9a-zA-Z-_.:~!*'\/])/'%'.sprintf('%02x',ord($1))/ge;
  return $text;
}

1;
