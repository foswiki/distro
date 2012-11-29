# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2002-2009 Will Norris. All Rights Reserved. (wbniv@saneasylumstudios.com)
# Copyright (C) 2005-2011 Michael Daum http://michaeldaumconsulting.com
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
#
# =========================
package Foswiki::Plugins::ImageGalleryPlugin::Core;

use strict;
use Foswiki::Func ();
use Foswiki::Plugins ();
use constant DEBUG => 0; # toggle me
use vars qw(%imageSuffixes);

# =========================
# constructor
sub new {
  my ($class, $id, $topic, $web) = @_;
  my $this = bless({}, $class);

  $web =~ s/\//\./go;

  # init

  # Graphics::Magick is less buggy than Image::Magick
  my $impl = 
    $Foswiki::cfg{ImageGalleryPlugin}{Impl} || 
    $Foswiki::cfg{ImagePlugin}{Impl} || 'Image::Magick'; 

  eval "use $impl";
  die $@ if $@;
  $this->{mage} = new $impl;

  $this->{id} = $id;
  $this->{session} = $Foswiki::Plugins::SESSION;
  $this->{query} = Foswiki::Func::getCgiQuery();
  $this->{topic} = $topic;
  $this->{web} = $web;
  $this->{doRefresh} = 0;
  $this->{errorMsg} = ''; # from image mage

  $this->{wikiName} = Foswiki::Func::getWikiName();
  $this->{pubDir} = $Foswiki::cfg{PubDir};
  $this->{imagesDir} = $this->{pubDir}.'/images';
  $this->{pubUrlPath} = Foswiki::Func::getPubUrlPath();
  $this->{foswikiWebName} = $Foswiki::cfg{SystemWebName};

  my $defaultThumbSizes = $Foswiki::cfg{ImageGalleryPlugin}{ThumbSizes} || {};
  # get predefined thumbnail sizes
  $this->{thumbSizes} = {
    thin => '25x25',
    small => '50x50',
    medium => '95x95',
    large => '150x150',
    huge => '350x350',
    %$defaultThumbSizes,
  };

  # get image mimes
  unless (%imageSuffixes) {
    my $mimeTypesFilename = $Foswiki::cfg{MimeTypesFileName};
    #writeDebug("reading suffix file $mimeTypesFilename");
    my $excludeSuffix = $Foswiki::cfg{ImageGalleryPlugin}{ExcludeSuffix};
    $excludeSuffix = 'psd' unless defined $excludeSuffix;
    my $fileContent = Foswiki::Func::readFile($mimeTypesFilename);
    foreach my $line (split(/\r?\n/, $fileContent)) {
      next if $line =~ /^#/;
      next if $line =~ /^$/;
      next unless $line =~ /^image/;# only image types
      next unless $line =~ /^\s*[^\s]+\s+(.*)\s*$/;
      foreach my $suffix (split(/ /, $1)) {
        next if $excludeSuffix && $suffix =~ /^($excludeSuffix)$/;
        $imageSuffixes{$suffix} = 1;
      }
    }
  }

  my $topicPubDir = $this->normalizeFileName($this->{imagesDir} . "/$web/$topic");
  mkdir $this->{imagesDir} unless -d $this->{imagesDir};
  mkdir "$this->{imagesDir}/$web" unless -d "$this->{imagesDir}/$web";
  mkdir $topicPubDir unless -d $topicPubDir;

  if ($this->{id}) {
    $this->{igpDir} = $this->normalizeFileName("$topicPubDir/$this->{id}");
    mkdir $this->{igpDir} unless -d $this->{igpDir};

    $this->{imagesPubUrl} = $this->{pubUrlPath} .
      "/images/$this->{web}/$this->{topic}/$this->{id}";
    $this->{infoFile} = $this->normalizeFileName("$this->{igpDir}/info.txt");
  }

  return $this;
}

# =========================
# test if a file is an image
sub isImage {
  my ($this, $attachment) = @_;
     
  #writeDebug("called isImage(". $attachment->{name}.")");

  my $suffix = '';
  if ($attachment->{name} =~ /.*\.(.+?)$/) {
    $suffix = lc($1);
  }

  my $result = defined $imageSuffixes{$suffix};
  #writeDebug("not an image") unless $result;
  #writeDebug("this is an image") if $result;
  return $result;
}

# =========================
sub init {
  my ($this, $params) = @_;

  # read attributes
  $this->{size} = $params->{size};
  $this->{size} = 'medium' unless defined $this->{size};
  my $thumbsize = $this->{thumbSizes}{$this->{size}} || $this->{size};
  my $thumbwidth = 95;
  my $thumbheight = 95;
  if ($thumbsize =~ /^(\d+)x(\d+)$/) {
    $thumbwidth = $1;
    $thumbheight = $2;
  } elsif ($thumbsize =~ /^x(\d+)$/) {
    $thumbwidth = $1;
    $thumbheight = $1;
  } elsif ($thumbsize =~ /^(\d+)(px)?$/) {
    $thumbwidth = $1;
    $thumbheight = $1;
  }
  $this->{thumbwidth} = $thumbwidth;
  $this->{thumbheight} = $thumbheight;

  #writeDebug("size=$this->{size} thumbsize=$thumbsize thumbwidth=$thumbwidth thumbheight=$thumbheight");
  
  my $topics = 
    $params->{_DEFAULT}
    || $params->{topic}
    || $params->{topics}
    || "$this->{web}.$this->{topic}";

  $this->{topics} = undef;
  
  # normalize topic names
  foreach my $theTopic (split(/,\s*/, $topics)) {
    my $theWeb;
    ($theWeb, $theTopic) = Foswiki::Func::normalizeWebTopicName($this->{web}, $theTopic);
    push @{$this->{topics}}, "$theWeb.$theTopic";
  }

  if (!$this->{topics}) {
    #writeDebug("oops, no topics found");
    return 0;
  }
  #writeDebug("topics=" . join(", ", @{$this->{topics}}));


  $this->{columns} = $params->{columns} || 4;

  $this->{doDocRels} = $params->{docrels} || 1;
  $this->{doDocRels} = ($this->{doDocRels} eq "off")?0:1;
  $this->{maxheight} = $params->{maxheight} || 480;
  $this->{maxwidth} = $params->{maxwidth} || 640;
  $this->{minheight} = $params->{minheight} || 0;
  $this->{minheight} = $this->{maxheight} if $this->{minheight} > $this->{maxheight};
  $this->{minwidth} = $params->{minwidth} || 0;
  $this->{minwidth} = $this->{maxwidth} if $this->{minwidth} > $this->{maxwidth};
  $this->{format} = $params->{format};
  $this->{frontend} = $params->{frontend};
  $this->{header} = $params->{header};
  $this->{footer} = $params->{footer};
  $this->{title} = $params->{title} || ' $comment ($imgnr/$nrimgs)';
  $this->{doTitles} = ($this->{title} eq 'off')?0:1;
  $this->{thumbtitle} = $params->{thumbtitle} || ' $comment';
  $this->{doThumbTitles} = ($this->{thumbtitle} eq 'on')?1:0;
  $this->{titles} = $params->{titles};
  if ($this->{titles}) {
    $this->{doTitles} = ($this->{titles} eq 'on')?1:0;
    $this->{doThumbTitles} = $this->{doTitles};
  }

  $this->{listsvg} = $params->{listsvg} || 'off';
  $this->{listsvg} = ($this->{listsvg} eq 'on')?1:0;

  $this->{warn} = $params->{warn};
  $this->{warn} = 'no images found' unless defined $this->{warn};
  $this->{warn} = '' if $this->{warn} eq 'off';

  $this->{limit} = $params->{limit} || 0;
  $this->{skip} = $params->{skip} || 0;

  my $refresh = $this->{query}->param("refresh") || '';
  $this->{doRefresh} = ($refresh =~ /on|img/)?1:0;

  $this->{include} = $params->{include} || '';
  $this->{exclude} = $params->{exclude} || '';
  $this->{field} = $params->{field} || 'name';

  if ($this->{field} !~ /^(name|comment)$/) {
    $this->{field} = 'name';
  }

  $this->{sort} = $params->{sort} || 'name';
  $this->{sort} = 'date' unless $this->{sort} =~ /^date|name|comment|size$/;

  $this->{reverse} = $params->{rev} || $params->{reverse} || 'off';
  $this->{reverse} = 'off' unless $this->{reverse} =~ /^on|off$/;

  unless (defined $this->{frontend}) {
    $this->{frontend} = (Foswiki::Func::getContext()->{JQueryPluginEnabled})?'lightbox':'default';
  }

  return 1;
}

# =========================
# main 
sub render {
  my ($this, $params) = @_;

  if (!$this->init($params)) {
    return '';
  }

  $this->getImages();
  $this->readInfo();

  # delete lost images
  foreach my $entry (values %{$this->{info}}) {
    next if $entry->{type} eq 'global';
    my $found = 0;
    foreach my $image (@{$this->{images}}) {
      if ($image->{name} eq $entry->{name}) {
        $found = 1;
        last;
      }
    }
    next if $found;
    my $img = "$this->{igpDir}/$entry->{name}";
    my $thumb = "$this->{igpDir}/thumb_$entry->{name}";
    if ($entry->{name} =~ /\.svgz?$/) {
      $img .= 'png'; 
      $thumb .= 'png'; 
    }

    $img = $this->normalizeFileName($img);
    $thumb = $this->normalizeFileName($thumb);

    unlink $img;
    unlink $thumb;

    delete $this->{info}{$entry->{name}};
  }


  # check for changes
  $this->{infoChanged} = 1
    if !$this->{info}{thumbwidth} || 
      !$this->{info}{thumbheight} || 
      !$this->{info}{topics} ||
      $this->{info}{thumbwidth}{value} ne $this->{thumbwidth} ||
      $this->{info}{thumbheight}{value} ne $this->{thumbheight} ||
      join(', ', $this->{info}{topics}{value}) ne join(', ', @{$this->{topics}});

  my $result = '';

  # get filename query string
  my $filename = $this->{query}->param("filename");
  my $id = $this->{query}->param("id") || '';
  my $context = Foswiki::Func::getContext();
  my $class = 'igp';

  if ($context->{'LazyLoadPluginEnabled'}) {
    Foswiki::Plugins::JQueryPlugin::createPlugin("lazyload");
    $result .= "\2<div class='jqLazyLoad'>"; # SMELL
  }

  if ($this->{frontend} eq 'lightbox') {
    require Foswiki::Plugins::JQueryPlugin;

    if ($context->{'PrettyPhotoEnabled'}) {
      Foswiki::Plugins::JQueryPlugin::createPlugin('prettyphoto');
      $class .= ' jqPrettyPhoto';
    } else {
      $class .= ' jqSlimbox ';
      Foswiki::Plugins::JQueryPlugin::createPlugin('slimbox');
    }

    $this->{header} = "<noautolink><div class=\"$class {itemSelector:'.igpThumbNail', singleMode:true}\" id='igp$this->{id}'>\n";
    $this->{footer} = "<span class='foswikiClear'></span></div></noautolink>";
    $this->{format} = "<a href='\$imageurl' class='igpThumbNail {origUrl:\"\$origurl\"}' style='width:".$this->{thumbwidth}."px; height:".$this->{thumbheight}."px;' title='\$comment'><img src='\$thumburl' alt='\$comment' /></a>"
      unless defined $this->{format};
    $result .= $this->renderFormatted();
  } elsif ($this->{format}) {
    $result .= $this->renderFormatted();
  } else {
    $result .= "<div class='$class'><a name='igp$this->{id}'></a>";
    if ($id eq $this->{id} && $filename) {
      # picture mode
      $result .= $this->renderImage($filename);
    } else {
      # thumbnails mode
      $result .= $this->renderThumbnails();
    }
    $result .= "</div>\n";
    $result = '<noautolink>'.$result.'</noautolink>';
  }

  if ($context->{'LazyLoadPluginEnabled'}) {
    $result .= "</div>\2"; # SMELL
  }

  $this->writeInfo();

  #writeDebug("result=$result");
  return Foswiki::Func::expandCommonVariables($result);
}

# =========================
# display one image
sub renderImage {
  my ($this, $filename) = @_;

  #writeDebug("renderImage($filename)");

  my $result = '';

  my $firstImg;
  my $lastImg;
  my $nextImg;
  my $thisImg;
  my $prevImg;

  my $state = 0;

  # find the first, prev, this, next and last image in the list
  # relative to the current filename
  foreach my $image (@{$this->{images}}) {
    $state = 3 if $state == 2;
    $state = 2 if $state == 1;
    $state = 1 if $image->{name} eq $filename; 
    
    $firstImg = $image unless $firstImg;
    $prevImg = $image if $state == 0;
    $thisImg = $image if $state == 1;
    $nextImg = $image if $state == 2;
    $lastImg = $image;
  }
  return renderError("unknown file $filename") unless $thisImg;

  # document relations
  if ($this->{doDocRels}) {
    $result .=
      "<link rel='parent' href='".
       $this->{session}->getScriptUrl(0, 'view', $this->{web}, $this->{topic}).
      "' title='Thumbnails' />\n";
    if ($firstImg && $firstImg->{name} ne $filename) {
      $result .=
        "<link rel='first' href='".
        $this->{session}->getScriptUrl(0, 'view', $this->{web}, $this->{topic},
          'id'=>$this->{id},
          'filename'=>$firstImg->{name},
          '#'=>"igp$this->{id}"
        )."' title='$firstImg->{name}' />\n";
    }
    if ($lastImg && $lastImg->{name} ne $filename) {
      $result .=
          "<link rel='last' href='".
          $this->{session}->getScriptUrl(0, 'view', $this->{web}, $this->{topic},
            'id'=>$this->{id},
            'filename'=>$lastImg->{name},
            '#'=>"igp$this->{id}"
          )."' title='$lastImg->{name}' />\n";
    }
    if ($nextImg && $nextImg->{name} ne $filename) {
      $result .=
          "<link rel='next' href='".
          $this->{session}->getScriptUrl(0, 'view', $this->{web}, $this->{topic},
            'id'=>$this->{id},
            'filename'=>$nextImg->{name},
            '#'=>"igp$this->{id}"
          )."' title='$nextImg->{name}' />\n";
    }
    if ($prevImg && $prevImg->{name} ne $filename) {
      $result .=
        "<link rel='previous' href='".
        $this->{session}->getScriptUrl(0, 'view', $this->{web}, $this->{topic},
          'id'=>$this->{id},
          'filename'=>$prevImg->{name},
          '#'=>"igp$this->{id}"
        )."' title='$prevImg->{name}' />\n";
    }
  }

  # collect image information
  $this->computeImageSize($thisImg);
  if (!$this->processImage($thisImg)) {
    return renderError($this->{errorMsg});
  }

  # layout img table
  $result .= "<table class='igpPicture' cellspacing='0' cellpadding='0'><tr><td colspan='2'>\n";

  # img
  my $imgFormat = '<a href="$origurl"><img src="$imageurl" title="$comment" width="$width" height="$height"/></a>';
  $result .= $this->replaceVars($imgFormat, $thisImg);
  $result .= '</td></tr><tr>';

  # title
  $result .= "<td class='igpPictureTitle'>";
  if ($this->{doTitles}) {
    $result .= $this->replaceVars($this->{title}, $thisImg);
  } else {
    $result .= "&nbsp;";
  }
  $result .= '</td>';

  # navi
  $result .= "<td class='igpNavi'>";

  if ($firstImg && $firstImg->{name} ne $filename) {
    $result .= "<a class='igpNaviFirst' title='go to first' href='".
    $this->{session}->getScriptUrl(0, 'view', $this->{web}, $this->{topic},
      'id'=>$this->{id},
      'filename'=>$firstImg->{name},
      '#'=>"igp$this->{id}"
    )."'><span>first</span></a>";
  } else {
    $result .= "<span class='igpNaviFirst igpNaviDisabled '><span>first</span></span>";
  }
  if ($prevImg) {
    $result .= "<a class='igpNaviPrev' title='go to previous' href='".
    $this->{session}->getScriptUrl(0, 'view', $this->{web}, $this->{topic},
      'id'=>$this->{id},
      'filename'=>$prevImg->{name},
      '#'=>"igp$this->{id}"
    )."'><span>prev</span></a>";
  } else {
    $result .= "<span class='igpNaviPrev igpNaviDisabled '><span>prev</span></span>";
  }
  if ($nextImg) {
    $result .= "<a class='igpNaviNext' title='go to next' href='".
    $this->{session}->getScriptUrl(0, 'view', $this->{web}, $this->{topic},
      'id'=>$this->{id},
      'filename'=>$nextImg->{name},
      '#'=>"igp$this->{id}"
    )."'><span>next</span></a>";
  } else {
    $result .= "<span class='igpNaviNext igpNaviDisabled '><span>next</span></span>";
  }
  if ($lastImg && $lastImg->{name} ne $filename) {
    $result .= "<a class='igpNaviLast' title='go to last' href='".
    $this->{session}->getScriptUrl(0, 'view', $this->{web}, $this->{topic},
      'id'=>$this->{id},
      'filename'=>$lastImg->{name},
      '#'=>"igp$this->{id}"
    )."'><span>last</span></a>";
  } else {
    $result .= "<span class='igpNaviLast igpNaviDisabled '><span>last</span></span>";
  }
  $result .= "<a class='igpNaviDone' href='".
    $this->{session}->getScriptUrl(0, 'view', $this->{web},$this->{topic}, "#"=>"igp$this->{id}").
    "'><span>done</span></a>";

  $result .= "<br clear='both' /></td></tr>\n</table>\n";

  return $result;
}

# =========================
sub renderFormatted {
  my $this = shift;
  
  #writeDebug("renderFormatted()");

  if (!@{$this->{images}}) {
    return renderError($this->{warn}); 
  }

  my $maxCols = $this->{columns};
  my $header = $this->{header} || '';
  my $footer = $this->{footer} || '';
  my $format = $this->{format} || '   * $imageurl';
  my $separator = $this->{separator};

  $separator = "\n" unless defined $separator;
  my @result;

  my $imageNr = 0;
  my @rowOfImages = ();
  my $skip = $this->{skip};
  foreach my $image (@{$this->{images}}) {

    $skip--;
    next if $skip >= 0;
    last if $this->{limit} && $imageNr >= $this->{limit};
    $imageNr++;

    $this->computeImageSize($image);
    if (!$this->processImage($image)) {
      return renderError($this->{errorMsg});
    }
    if (!$this->processImage($image, 1)) {
      return renderError($this->{errorMsg});
    }


    my $line = $this->replaceVars($format, $image);
    $line =~ s/\$index/$imageNr/g;
    push @result, $line;
    

  }
  return Foswiki::Func::decodeFormatTokens($header.join($separator, @result).$footer);
}

# =========================
sub renderThumbnails {

  my $this = shift;

  #writeDebug("renderThumbnails()");

  if (!@{$this->{images}}) {
    return renderError($this->{warn}); 
  }

  my $maxCols = $this->{columns};
  my $result = "<div class='igpThumbNails'>";
  my $imageNr = 0;
  my $skip = $this->{skip};
  my @lines = ();
  my $line = '';
  foreach my $image (@{$this->{images}}) {
    $this->computeImageSize($image);

    $skip--;
    next if $skip >= 0;
    last if $this->{limit} && $imageNr >= $this->{limit};

    $line .= "<td>"
      . "<table class='igpThumbNail' cellspacing='0' cellpadding='0'"
      . "style='width:".($this->{thumbwidth}+15)."px; height:".($this->{thumbheight}+15)."px;'>"
      . "<tr><td >"
      . "<a href='".Foswiki::Func::getViewUrl($this->{web}, $this->{topic})
      . "?id=$this->{id}&filename=$image->{name}#igp$this->{id}' "
      . ">"
      . "<img src='$this->{imagesPubUrl}/thumb_$image->{name}"
      . (($image->{name} =~ /\.svgz?$/ )?'.png':'')
      . "' title='$image->{IGP_comment}' alt='$image->{name}'/></a></td></tr>";

    if ($this->{doThumbTitles}) {
      $line .= 
        "<tr><td class='igpThumbNailTitle'><div>" . 
        $this->replaceVars($this->{thumbtitle}, $image) .
        "</div></td></tr>";
    }
    $line .= "</table></td>\n";

    if (!$this->processImage($image, 1)) {
      return renderError($this->{errorMsg});
    }

    $imageNr++;
    if ($imageNr % $maxCols == 0) {
      push @lines, $line;
      $line = '';
    }
  }

  # fill up the rest of the row
  while ($imageNr % $maxCols != 0) {
    $line .= "<td>&nbsp;</td>";
    $imageNr++;
  }
  push @lines, $line if $line;

  if (@lines) {
    $result .= 
      "\n<table class='igpThumbNailsTable' cellspacing='0' cellpadding='0'>\n" .
      "<tr>\n".join("</tr>\n<tr>\n", @lines)."</tr>\n" .
      "</table>\n";
  }
  $result .= "</div>\n";

  return $result;
}

# =========================
sub getImages {
  my $this = shift;

  #writeDebug("getImages(" . join(', ', @{$this->{topics}}) . ") called");

  # collect images from all topics
  my @images;
  foreach my $webtopic (@{$this->{topics}}) {
    my ($theWeb, $theTopic) = Foswiki::Func::normalizeWebTopicName($this->{web}, $webtopic);
    #writeDebug("reading from $theWeb.$theTopic");
    my $viewAccessOK = Foswiki::Func::checkAccessPermission("view", $this->{wikiName}, undef, 
      $theTopic, $theWeb);

    if (!$viewAccessOK) {
      #writeDebug("no view access to ... skipping");
      next;
    }

    my ($meta, undef) = Foswiki::Func::readTopic($theWeb, $theTopic);

    foreach my $image ($meta->find('FILEATTACHMENT')) {
      next unless $this->isImage($image);
      next if $this->{exclude} && $image->{$this->{field}} =~ /$this->{exclude}/;
      next if $this->{include} && $image->{$this->{field}} !~ /$this->{include}/;
      
      # SMELL work around for Image::Magick segfaulting reading svg image files
      next if !$this->{listsvg} && $image->{name} =~ /svgz?$/i;

      my $size = $image->{size} || 0;
      $image->{IGP_comment} = getImageTitle($image);
      $image->{IGP_sizeK} = sprintf("%dk", $size / 1024);
      $image->{IGP_topic} = $theTopic;
      $image->{IGP_web} = $theWeb;

      $image->{IGP_filename} = $this->normalizeFileName(
        $this->{pubDir} . "/$image->{IGP_web}/$image->{IGP_topic}/$image->{name}");
      $image->{IGP_url} = 
        $this->{pubUrlPath} . "/$image->{IGP_web}/$image->{IGP_topic}/$image->{name}";
      if ($image->{IGP_comment} =~ /^([0-9]+)\s+-\s+(.*)$/) {
        $image->{IGP_imgnr} = $1;
        $image->{IGP_comment} = $2;
      }

      # check for file existence
      if (! -e $image->{IGP_filename}) {
        Foswiki::Func::writeWarning("attachment error in " .
          "$image->{IGP_web}.$image->{IGP_topic}: " .
          "no such file '$image->{IGP_filename}'");
        next;
      }

      push @images, $image;
    }
  }
  #writeDebug("found ".scalar(@images)." images");

  # order images
  my @sortedImages;
  
  # pre sort
  if ($this->{sort} eq 'date') {
    @images = sort {$a->{date} <=> $b->{date}} @images;
  } elsif ($this->{sort} eq 'name') {
    @images = sort {lc($a->{name}) cmp lc($b->{name})} @images;
  } elsif ($this->{sort} eq 'comment') {
    @images = sort {lc($a->{comment}) cmp lc($b->{comment})} @images;
  } elsif ($this->{sort} eq 'size') {
    @images = sort {$a->{size} <=> $b->{size}} @images;
  }
  @images = reverse @images if $this->{reverse} eq 'on';

  # set natural order
  my $imgnr = 1;
  foreach my $image (@images) {
    $image->{IGP_natnr} = $imgnr++;
  }

  # obey explicite image positioning
  foreach my $image (@images) {
    next unless $image->{IGP_imgnr};
    my $imgnr = $image->{IGP_imgnr};
    while ($sortedImages[$imgnr]) { # first come first serve
      $imgnr++;
    }
    $sortedImages[$imgnr] = $image;
  }

  # merge rest according to natural position
  foreach my $image (@images) {
    next if $image->{IGP_imgnr};
    my $imgnr = $image->{IGP_natnr};
    while ($sortedImages[$imgnr]) { # first come first serve
      $imgnr++;
    }
    $sortedImages[$imgnr] = $image;
  }

  # reconstruct images list and normalize their number
  $imgnr = 1;
  @images = ();
  foreach my $image (@sortedImages) {
    next unless $image;
    push @images, $image;
    $image->{IGP_imgnr} = $imgnr++;
  }

  $this->{images} = \@images;
  return \@images;
}

# =========================
# use the mage to get the image size
# enrich the givem image with the following information
# - IGP_origwidth: the original width of the image
# - IGP_origheight: the original height of the image
# - IGP_width: the max width to be used
# - IGP_height: the max height to be used
# - IGP_thumbwidth: the max thumbnail width to be used for 
# - IGP_thumbheight: the max thumbnail height to be used
sub computeImageSize {
  my ($this, $image) = @_;
  
  #writeDebug("computeImageSize($image->{name})");

  my $entry = $this->{info}{$image->{name}};
  if (!$this->{doRefresh} && $entry) {
    
    # look up igp info
    #writeDebug("found cached info");
    $image->{IGP_origwidth} = $entry->{origwidth};
    $image->{IGP_origheight} = $entry->{origheight};
    
  } else {
    
    # compute
    #writeDebug("consulting image mage on $image->{IGP_filename}");
    ($image->{IGP_origwidth}, $image->{IGP_origheight}, undef, undef) = 
      $this->{mage}->Ping($image->{IGP_filename});

    # forget
    my $mage = $this->{mage};
    @$mage = ();

    #writeDebug("done");
  }
    
  # compute max image width and height
  my $width = $image->{IGP_origwidth};
  my $height = $image->{IGP_origheight};
  my $aspect = $width ? $height / $width : 0;

  if ($width < $this->{minwidth}) {
    $width = $this->{minwidth};
    $height = $width * $aspect;
  } 
  if ($height < $this->{minheight}) {
    $height = $this->{minheight};
    $width = $aspect ? $height / $aspect : 0;
  }
  if ($this->{maxwidth} && $width > $this->{maxwidth}) {
    $width = $this->{maxwidth};
    $height = $width * $aspect;
  } 
  if ($this->{maxheight} && $height > $this->{maxheight}) {
    $height = $this->{maxheight};
    $width = $aspect ? $height / $aspect : 0;
  }
  $image->{IGP_width} = int($width+0.5);
  $image->{IGP_height} = int($height+0.5);

  #writeDebug("minwidth=$this->{minwidth}, minheight=$this->{minheight}, width=$width, height=$height");

  # compute optimal thumnail width and height
  $width = $image->{IGP_origwidth};
  $height = $image->{IGP_origheight};
  $aspect = $width ? $height / $width : 0;

  if ($aspect < 1) {
    # resize height, crop rest
    if ($height > $this->{thumbheight}) {
      $height = $this->{thumbheight};
      $width = $aspect ? $height / $aspect : 0;
    }
  } else {
    # resize width, crop rest
    if ($width > $this->{thumbwidth}) {
      $width = $this->{thumbwidth};
      $height = $width * $aspect;
    } 
  }
  #writeDebug("aspect=$aspect thumbwidth=$width, thumbheight=$height");


  $image->{IGP_thumbwidth} = int($width+0.5);
  $image->{IGP_thumbheight} = int($height+0.5);

  # update image info
  my $imgChanged = 0;
  if (!$entry ||
      $entry->{version} ne $image->{version} ||
      $entry->{width} ne $image->{IGP_width} ||
      $entry->{height} ne $image->{IGP_height} ||
      $entry->{origwidth} ne $image->{IGP_origwidth} ||
      $entry->{origheight} ne $image->{IGP_origheight} ||
      $entry->{thumbwidth} ne $image->{IGP_thumbwidth} ||
      $entry->{thumbheight} ne $image->{IGP_thumbheight}) {
    $this->{infoChanged} = 1;
    $imgChanged = 1;
  }

  $entry->{name} = $image->{name};
  $entry->{version} = $image->{version};
  $entry->{type} = 'image';
  $entry->{width} = $image->{IGP_width};
  $entry->{height} = $image->{IGP_height};
  $entry->{origwidth} = $image->{IGP_origwidth};
  $entry->{origheight} = $image->{IGP_origheight};
  $entry->{thumbwidth} = $image->{IGP_thumbwidth};
  $entry->{thumbheight} = $image->{IGP_thumbheight};
  $entry->{imgChanged} = $imgChanged;
  $this->{info}{$entry->{name}} = $entry;

  #writeDebug("done computeImageSize");
}

# =========================
sub replaceVars {
  my ($this, $format, $image) = @_;

  if ($image) {

    my $imageName = $image->{name}.(($image->{name} =~ /\.svgz?$/ )?'.png':'');

    $format =~ s/\$width/$image->{IGP_width}/gos;
    $format =~ s/\$framewidth/($image->{IGP_width}+2)/ge;
    $format =~ s/\$height/$image->{IGP_height}/gos;
    $format =~ s/\$thumbwidth/$image->{IGP_thumbwidth}/gos;
    $format =~ s/\$thumbheight/$image->{IGP_thumbheight}/gos;
    $format =~ s/\$origwidth/$image->{IGP_origwidth}/gos;
    $format =~ s/\$origheight/$image->{IGP_origheight}/gos;
    $format =~ s/\$sizeK/$image->{IGP_sizeK}/gos;
    $format =~ s/\$comment/$image->{IGP_comment}/geos;
    $format =~ s/\$imgnr/$image->{IGP_imgnr}/gos;

    $format =~ s/\$date(\{([^\}]*)\})?/formatTime($image->{date}, $2)/goes;
    $format =~ s/\$version/$image->{version}/gos;
    $format =~ s/\$name/$imageName/gos;
    $format =~ s/\$size/$image->{size}/gos;
    $format =~ s/\$wikiusername/$image->{user}/gos;
    $format =~ s/\$username/Foswiki::Func::wikiToUserName($image->{user})/geos;
    $format =~ s/\$thumburl/$this->{imagesPubUrl}\/thumb_$imageName/gos;
    $format =~ s/\$imageurl/$this->{imagesPubUrl}\/$imageName/gos;
    $format =~ s/\$origurl/$image->{IGP_url}/gos;
    $format =~ s/\$web/$image->{IGP_web}/gos;
    $format =~ s/\$topic/$image->{IGP_topic}/gos;
    $format =~ s/\$id/$this->{id}/gos;

  }

  $format =~ s/\$nrimgs/scalar @{$this->{images}}/geos;
  $format =~ s/\$n((\([^\)]*\))|(\{[^\}]*\}))?/\n/gos; # $n or $n(....) or $n{...}
  
  return $format;
}

# =========================
# only update the image if 
# (1) it doesn't exist or 
# (2) the thumbnail is older than the source image
# (3) it should be resized
# returns 1 on success and 0 on an error (see errorMsg)
sub processImage {
  my ($this, $image, $thumbMode) = @_;
  
  #writeDebug("processImage($image->{name}) called");
  
  my $prefix = ($thumbMode)?'thumb_':'';

  my $target = "$this->{igpDir}/$prefix$image->{name}".
               (($image->{name} =~ /\.svgz?$/)?'.png':'');
  $target = $this->normalizeFileName($target);

  my $entry = $this->{info}{$image->{name}};
  return 1 if !$this->{doRefresh} && -e $target && !$entry->{imgChanged};

  $this->{errorMsg} = '';

  # read
  #writeDebug("mage->read($image->{IGP_filename})");
  my $error = $this->{mage}->Read($image->{IGP_filename});
  #writeDebug("done read");
  if ($error =~ /(\d+)/) {
    #writeDebug("Read(): error=$error");
    $this->{errorMsg} = " $error";
    return 0 if $1 >= 400;
  }

  # compute
  if ($thumbMode) {
    $error = 
      $this->{mage}->Resize(geometry=>"$image->{IGP_thumbwidth}x$image->{IGP_thumbheight}")." ".
      $this->{mage}->Crop(width=>$this->{thumbwidth}, height=>$this->{thumbheight})." ".
      $this->{mage}->Set(page=>"0x0+0+0");
  } else {
    $error = 
      $this->{mage}->Resize(geometry=>"$image->{IGP_width}x$image->{IGP_height}");
  }
  if ($error =~ /(\d+):/) {
    #writeDebug("Transform(): error=$error");
    $this->{errorMsg} .= " $error";
    return 0 if $1 >= 400;
  }

  # write
  #writeDebug("mage->write($target)");
  $error = $this->{mage}->Write($target);
  #writeDebug("done mage->write()");
  if ($error =~ /(\d+)/) {
    #writeDebug("Write(): error=$error");
    $this->{errorMsg} .= " $error";
    return 0 if $1 >= 400;
  }

  #writeDebug("writing target '$target'");

  # forget
  my $mage = $this->{mage};
  @$mage = ();
  #writeDebug("done createImage()");
  return 1;
}

# =========================
# stolen form Foswiki::handleTime() 
sub formatTime {
  my ($time, $format) = @_;
  $format ||= '$day $mon $year - $hour:$min';
  my $value = "";

  my ($sec, $min, $hour, $day, $mon, $year) = localtime($time);
  $year = sprintf("%.4u", $year + 1900);
  use constant ISOMONTH => qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
  my $tmon = (ISOMONTH)[$mon];

  $value = $format;
  $value =~ s/\$sec[o]?[n]?[d]?[s]?/sprintf("%.2u",$sec)/geoi;
  $value =~ s/\$min[u]?[t]?[e]?[s]?/sprintf("%.2u",$min)/geoi;
  $value =~ s/\$hou[r]?[s]?/sprintf("%.2u",$hour)/geoi;
  $value =~ s/\$day/sprintf("%.2u",$day)/geoi;
  $value =~ s/\$mon[t]?[h]?/$tmon/goi;
  $value =~ s/\$mo/sprintf("%.2u",$mon+1)/geoi;
  $value =~ s/\$yea[r]?/$year/goi;
  $value =~ s/\$ye/sprintf("%.2u",$year%100)/geoi;

  return $value;
}

# =========================
# wrapper
sub normalizeFileName {
  my ($this, $fileName) = @_;

  #writeDebug("normalizeFileName($fileName)");

  if (defined &Foswiki::Sandbox::_cleanUpFilePath) {
    return Foswiki::Sandbox::_cleanUpFilePath($fileName);
  }

  if (defined &Foswiki::Sandbox::normalizeFileName) {
    return Foswiki::Sandbox::normalizeFileName($fileName);
  }

  if (defined &Foswiki::normalizeFileName) {
    return Foswiki::normalizeFileName($fileName);
  }

  # outch
  return $fileName;
}

# =========================
sub renderError {
  my $msg = shift;
  return '' unless $msg;
  return "<span class='foswikiAlert'>Error: $msg</span>" ;
}

# =========================
sub getImageTitle {
  my $image = shift;

  my $title;
  if ($image->{comment}) {
    $title = $image->{comment};
  } else {
    $title =  $image->{name};
    $title =~ s/^(.*)\.[a-zA-Z]*$/$1/;
  }
  $title =~ s/^\s+//;
  $title =~ s/\s+$//;

  return $title;
}

# =========================
sub readInfo {
  my $this = shift;

  #writeDebug("readInfo() called");

  $this->{infoChanged} = 1;
  return unless -e $this->{infoFile};

  my $text = Foswiki::Func::readFile($this->{infoFile});
  foreach my $line (split(/\n/, $text)) {
    my $entry;
    if ($line =~ /^name=(.*), version=(.*), origwidth=(.*), origheight=(.*), width=(.*), height=(.*), thumbwidth=(.*), thumbheight=(.*)$/) {
      $entry = {
        name=>$1,
        version=>$2,
        type=>'image',
        origwidth=>$3,
        origheight=>$4,
        width=>$5,
        height=>$6,
        thumbwidth=>$7,
        thumbheight=>$8,
      };
    } elsif ($line =~ /^(thumbwidth|thumbheight|topics|web)=(.*)$/) {
      $entry = {
        name=>$1,
        type=>'global',
        value=>$2,
      };
    } else {
      next;
    }
    $this->{info}{$entry->{name}} = $entry;
  }

  $this->{infoChanged} = 0;
}

# =========================
sub writeInfo {
  my $this = shift;

  #writeDebug("writeInfo() called");

  return unless $this->{infoChanged};

  my $text = "# ImageGalleryPlugin info file: DON'T EDIT BY HAND\n";
  $text .= "thumbwidth=$this->{thumbwidth}\n";
  $text .= "thumbheight=$this->{thumbheight}\n";
  $text .= "topics=" . join (', ', @{$this->{topics}}) . "\n";
  foreach my $entry (values %{$this->{info}}) {
    next if $entry->{type} eq 'global';
    $text .= 
      "name=$entry->{name}, " .
      "version=$entry->{version}, " .
      "origwidth=$entry->{origwidth}, " .
      "origheight=$entry->{origheight}, " .
      "width=$entry->{width}, " .
      "height=$entry->{height}, " .
      "thumbwidth=$entry->{thumbwidth}, " .
      "thumbheight=$entry->{thumbheight}" .
      "\n";
  }

  #writeDebug("writing infoFile=$this->{infoFile}");

  Foswiki::Func::saveFile($this->{infoFile}, $text);
}

# =========================
# static
sub writeDebug {
  #Foswiki::Func::writeDebug("ImageGalleryPlugin - $_[0]");
  print STDERR "ImageGalleryPlugin - $_[0]\n" if DEBUG;
}

1;
