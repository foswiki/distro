#
# TWiki WikiClone ($wikiversion has version info)
#
# Copyright (C) 2002-2003 Will Norris. All Rights Reserved. (wbniv@saneasylumstudios.com)
# Copyright (C) 2005-2008 Michael Daum http://michaeldaumconsulting.com
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
package TWiki::Plugins::ImageGalleryPlugin::Core;

use strict;

sub DEBUG { 0; } # toggle me

# =========================
# constructor
sub new {
  my ($class, $id, $topic, $web) = @_;
  my $this = bless({}, $class);

  $web =~ s/\//\./go;

  # init

  # Graphics::Magick is less buggy than Image::Magick
  my $impl = 
    $TWiki::cfg{ImageGalleryPlugin}{Impl} || 
    $TWiki::cfg{ImagePlugin}{Impl} || 'Image::Magick'; 

  eval "use $impl";
  die $@ if $@;
  $this->{mage} = new $impl;

  $this->{id} = $id;
  $this->{query} = TWiki::Func::getCgiQuery();
  $this->{isDakar} = defined $TWiki::RELEASE;
  $this->{topic} = $topic;
  $this->{web} = $web;
  $this->{doRefresh} = 0;
  $this->{errorMsg} = ''; # from image mage

  $this->{wikiUserName} = TWiki::Func::getWikiUserName();
  $this->{pubDir} = TWiki::Func::getPubDir();
  $this->{imagesDir} = $this->{pubDir}.'/images';
  $this->{pubUrlPath} = TWiki::Func::getPubUrlPath();
  $this->{twikiWebName} = TWiki::Func::getTwikiWebname();

  my $defaultThumbSizes = $TWiki::cfg{Plugins}{ImageGalleryPlugin}{ThumbSizes} || [];
  # get predefined thumbnail sizes
  %{$this->{thumbSizes}} = (
    thin => '25x25',
    small => '50x50',
    medium => '95x95',
    large => '150x150',
    huge => '250x250',
    @$defaultThumbSizes,
  );
  
  # get style url
  my $hostUrl = ($this->{isDakar})? $TWiki::cfg{DefaultUrlHost}:$TWiki::defaultUrlHost;
    
  # get image mimes
  my $mimeTypesFilename = ($this->{isDakar})?
    $TWiki::cfg{MimeTypesFileName}:$TWiki::mimeTypesFilename;
  my $fileContent = TWiki::Func::readFile($mimeTypesFilename);
  $this->{isImageSuffix} = ();
  foreach my $line (split(/\r?\n/, $fileContent)) {
    next if $line =~ /^#/;
    next if $line =~ /^$/;
    next unless $line =~ /^image/;# only image types
    next unless $line =~ /^\s*[^\s]+\s+(.*)\s*$/;
    foreach my $suffix (split(/ /, $1)) {
      $this->{isImageSuffix}{$suffix} = 1;
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
     
  writeDebug("called isImage(". $attachment->{name}.")");

  my $suffix = '';
  if ($attachment->{name} =~ /\.(.+?)$/) {
    $suffix = lc($1);
  }

  my $result = defined $this->{isImageSuffix}{$suffix};
  writeDebug("not an image") unless $result;
  writeDebug("this is an image") if $result;
  return $result;
}

# =========================
sub init {
  my ($this, $params) = @_;

  # read attributes
  $this->{size} = $params->{size} || 'medium';
  my $thumbsize = $this->{thumbSizes}{$this->{size}} || $this->{size};
  my $thumbwidth = 95;
  my $thumbheight = 95;
  if ($thumbsize =~ /^(.*)x(.*)$/) {
    $thumbwidth = $1;
    $thumbheight = $2;
  } elsif ($thumbsize =~ /^x(.*)$/) {
    $thumbwidth = $1;
    $thumbheight = $1;
  } elsif ($thumbsize =~ /^(.*)x$/) {
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
    ($theWeb, $theTopic) = TWiki::Func::normalizeWebTopicName($this->{web}, $theTopic);
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
  $this->{format} = $params->{format} || 
      '<a href="$origurl"><img src="$imageurl" title="$comment" width="$width" height="$height"/></a>';
  $this->{title} = $params->{title} || '$comment ($imgnr/$nrimgs)&nbsp;$reddot';
  $this->{doTitles} = ($this->{title} eq 'off')?0:1;
  $this->{thumbtitle} = $params->{thumbtitle} || '$comment&nbsp;$reddot';
  $this->{doThumbTitles} = ($this->{thumbtitle} eq 'off')?0:1;
  $this->{titles} = $params->{titles};
  if ($this->{titles}) {
    $this->{doTitles} = ($this->{titles} eq 'off')?0:1;
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
  $this->{doRefresh} = ($refresh eq 'on')?1:0;

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

  my $result = "<div class=\"igp\"><a name=\"igp$this->{id}\"></a>";

  # get filename query string
  my $filename = $this->{query}->param("filename");
  my $id = $this->{query}->param("id") || '';

  if ($id eq $this->{id} && $filename) {
    # picture mode
    $result .= $this->renderImage($filename);
  } else {
    # thumbnails mode
    $result .= $this->renderThumbnails();
  }

  $result .= "</div>\n";

  $this->writeInfo();
  return '<noautolink>'.$result.'</noautolink>';
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
      "<link rel=\"parent\" href=\"".
       TWiki::Func::getViewUrl($thisImg->{IGP_web}, $thisImg->{IGP_topic}) .
      "\" title=\"Thumbnails\" />\n";
    if ($firstImg && $firstImg->{name} ne $filename) {
      $result .=
        "<link rel=\"first\" href=\"".
        TWiki::Func::getViewUrl($firstImg->{IGP_web}, $firstImg->{IGP_topic}) .
        "?id=$this->{id}&filename=$firstImg->{name}#igp$this->{id}\" title=\"$firstImg->{name}\" />\n";
    }
    if ($lastImg && $lastImg->{name} ne $filename) {
      $result .=
          "<link rel=\"last\" href=\"".
          TWiki::Func::getViewUrl($lastImg->{IGP_web}, $lastImg->{IGP_topic}) .
          "?id=$this->{id}&filename=$lastImg->{name}#igp$this->{id}\" title=\"$lastImg->{name}\" />\n";
    }
    if ($nextImg && $nextImg->{name} ne $filename) {
      $result .=
          "<link rel=\"next\" href=\"".
          TWiki::Func::getViewUrl($nextImg->{IGP_web}, $nextImg->{IGP_topic}) .
          "?id=$this->{id}&filename=$nextImg->{name}#igp$this->{id}\" title=\"$nextImg->{name}\" />\n";
    }
    if ($prevImg && $prevImg->{name} ne $filename) {
      $result .=
        "<link rel=\"previous\" href=\"".
        TWiki::Func::getViewUrl($prevImg->{IGP_web}, $prevImg->{IGP_topic}) .
        "?id=$this->{id}&filename=$prevImg->{name}#igp$this->{id}\" title=\"$prevImg->{name}\" />\n";
    }
  }

  # collect image information
  $this->computeImageSize($thisImg);
  if (!$this->createImg($thisImg)) {
    return renderError($this->{errorMsg});
  }

  # title
  if ($this->{doTitles}) {
    $result .= "<div class=\"igpPictureTitle\"><h2>"
      . $this->replaceVars($this->{title}, $thisImg)
      . "</h2></div>\n";
  }

  # layout img table
  $result .= "<table class=\"igpPictureTable\">\n";

  # navi
  $result .= "<tr><td class=\"igpNavigation\">";
  if ($firstImg && $firstImg->{name} ne $filename) {
    $result .= "<a href=\"".
    TWiki::Func::getViewUrl($thisImg->{IGP_web}, $thisImg->{IGP_topic}) .
    "?id=$this->{id}&filename=$firstImg->{name}#igp$this->{id}\">first</a>";
  } else {
    $result .= "first";
  }
  $result .= ' | ';
  if ($prevImg) {
    $result .= "<a href=\"".
    TWiki::Func::getViewUrl($prevImg->{IGP_web}, $prevImg->{IGP_topic}) .
    "?id=$this->{id}&filename=$prevImg->{name}#igp$this->{id}\">prev</a>";
  } else {
    $result .= "prev";
  }
  $result .= " | <a href=\"".
    TWiki::Func::getViewUrl($this->{web},$this->{topic})."#igp$this->{id}".
    "\">up</a> |";
  if ($nextImg) {
    $result .= "<a href=\"".
    TWiki::Func::getViewUrl($nextImg->{IGP_web}, $nextImg->{IGP_topic}) .
    "?id=$this->{id}&filename=$nextImg->{name}#igp$this->{id}\">next</a>";
  } else {
    $result .= "next";
  }
  $result .= ' | ';
  if ($lastImg && $lastImg->{name} ne $filename) {
    $result .= "<a href=\"".
    TWiki::Func::getViewUrl($lastImg->{IGP_web}, $lastImg->{IGP_topic}) .
    "?id=$this->{id}&filename=$lastImg->{name}#igp$this->{id}\">last</a>";
  } else {
    $result .= "last";
  }
  $result .= "</td></tr>\n";

  # img
  $result .= "<tr><td class=\"igpPicture\">" 
    . $this->replaceVars($this->{format}, $thisImg)
    . "</td></tr></table>\n";

  return $result;
}

# =========================
sub renderThumbnails {

  my $this = shift;

  #writeDebug("renderThumbnails()");

  if (!@{$this->{images}}) {
    return renderError($this->{warn}); 
  }

  my $maxCols = $this->{columns};
  my $result = "<div class=\"igpThumbNails\"><table class=\"igpThumbNailsTable\"><tr>\n";
  my $imageNr = 0;
  my @rowOfImages = ();
  my $skip = $this->{skip};
  foreach my $image (@{$this->{images}}) {
    $this->computeImageSize($image);

    $skip--;
    next if $skip >= 0;
    last if $this->{limit} && $imageNr >= $this->{limit};

    if ($this->{doThumbTitles}) {
      push @rowOfImages, $image;
    }

    $result .= "<td width=\"" . (100 / $maxCols) . "%\" class=\"igpThumbNail\"><a href=\""
      .  TWiki::Func::getViewUrl($image->{IGP_web}, $image->{IGP_topic})
      . "?id=$this->{id}&filename=$image->{name}#igp$this->{id}\">"
      . "<img src=\"$this->{imagesPubUrl}/thumb_$image->{name}"
      . (($image->{name} =~ /\.svgz?$/ )?'.png':'')
      . "\" title=\"$image->{IGP_comment}\" alt=\"$image->{name}\"/></a></td>\n";

    if (!$this->createImg($image, 1)) {
      return renderError($this->{errorMsg});
    }

    $imageNr++;
    if ($imageNr % $maxCols == 0) {
      $result .= "</tr>\n";
      if ($this->{doThumbTitles}) {
        $result .= $this->renderTitleRow(\@rowOfImages);
        @rowOfImages = ();
      }
    }
  }
  while ($imageNr % $maxCols != 0) {
    $result .= "<td>&nbsp;</td>\n";
    $imageNr++;
  }
  $result .= "</tr>\n";
  if ($this->{doThumbTitles}) {
    $result .= $this->renderTitleRow(\@rowOfImages);
  }
  $result .= "</table></div>\n";

  return $result;
}

# =========================
sub renderTitleRow {

  my ($this, $images) = @_;
  
  my $result = '<tr>';

  my $imageNr = 0;
  foreach my $image (@$images) {
    $result .= 
      "<td class=\"igpThumbNailTitle\">" . 
      $this->replaceVars($this->{thumbtitle}, $image) .
      "</td>\n";
    $imageNr++;
  }
  my $maxCols = $this->{columns};
  while ($imageNr % $maxCols != 0) {
    $result .= "<td>&nbsp;</td>";
    $imageNr++;
  }
  $result .= "</tr>\n";

  return $result;
}

# =========================
sub renderRedDot {
  my ($this, $image) = @_;

  my $changeAccessOK =
    TWiki::Func::checkAccessPermission("change", $this->{wikiUserName}, undef,
      $image->{IGP_topic}, $image->{IGP_web});

  return '' unless $changeAccessOK;

  return 
    "<span class=\"igpRedDot\"><a href=\"" 
    . TWiki::Func::getScriptUrl($image->{IGP_web}, $image->{IGP_topic}, "attach")
    . "?filename=$image->{name}\">.</a></span>";
}

# =========================
sub getImages {
  my $this = shift;

  writeDebug("getImages(" . join(', ', @{$this->{topics}}) . ") called");

  # collect images from all topics
  my @images;
  foreach my $webtopic (@{$this->{topics}}) {
    my ($theWeb, $theTopic) = TWiki::Func::normalizeWebTopicName($this->{web}, $webtopic);
    writeDebug("reading from $theWeb.$theTopic}");
    my $viewAccessOK = TWiki::Func::checkAccessPermission("view", $this->{wikiUserName}, undef, 
      $theTopic, $theWeb);

    if (!$viewAccessOK) {
      writeDebug("no view access to ... skipping");
      next;
    }

    my ($meta, undef) = TWiki::Func::readTopic($theWeb, $theTopic);

    foreach my $image ($meta->find('FILEATTACHMENT')) {
      next unless $this->isImage($image);
      next if $this->{exclude} && $image->{$this->{field}} =~ /$this->{exclude}/;
      next if $this->{include} && $image->{$this->{field}} !~ /$this->{include}/;
      
      # SMELL work around for Image::Magick segfaulting reading svg image files
      next if !$this->{listsvg} && $image->{name} =~ /svgz?$/i;

      $image->{IGP_comment} = getImageTitle($image);
      $image->{IGP_sizeK} = sprintf("%dk", $image->{size} / 1024);
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
        TWiki::Func::writeWarning("attachment error in " .
          "$image->{IGP_web}.$image->{IGP_topic}: " .
          "no such file '$image->{IGP_filename}'");
        next;
      }

      push @images, $image;
    }
  }
  writeDebug("found ".scalar(@images)." images");

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

  # compute max thumnail width and height
  $width = $image->{IGP_origwidth};
  $height = $image->{IGP_origheight};
  $aspect = $width ? $height / $width : 0;

  if ($width > $this->{thumbwidth}) {
    $width = $this->{thumbwidth};
    $height = $width * $aspect;
  } 
  if ($height > $this->{thumbheight}) {
    $height = $this->{thumbheight};
    $width = $aspect ? $height / $aspect : 0;
  }
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

    $format =~ s/\$reddot/$this->renderRedDot($image)/goes;
    $format =~ s/\$width/$image->{IGP_width}/gos;
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
    $format =~ s/\$username/TWiki::Func::wikiToUserName($image->{user})/geos;
    $format =~ s,\$thumburl,$this->{imagesPubUrl}/thumb_$imageName,gos;
    $format =~ s,\$imageurl,$this->{imagesPubUrl}/$imageName,gos;
    $format =~ s,\$origurl,$image->{IGP_url},gos;
    $format =~ s/\$web/$image->{IGP_web}/gos;
    $format =~ s/\$topic/$image->{IGP_topic}/gos;

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
sub createImg {
  my ($this, $image, $thumbMode) = @_;
  
  #writeDebug("createImg($image->{name}) called");
  
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
  #writeDebug("mage->scale");
  if ($thumbMode) {
    $error = 
      $this->{mage}->Resize(geometry=>"$image->{IGP_thumbwidth}x$image->{IGP_thumbheight}");
  } else {
    $error = 
      $this->{mage}->Resize(geometry=>"$image->{IGP_width}x$image->{IGP_height}");
  }
  #writeDebug("done mage->scale");
  if ($error =~ /(\d+)/) {
    #writeDebug("Resize(): error=$error");
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
# stolen form TWiki::handleTime() 
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

  if (defined &TWiki::Sandbox::normalizeFileName) {
    return TWiki::Sandbox::normalizeFileName($fileName);
  }

  if (defined &TWiki::normalizeFileName) {
    return TWiki::normalizeFileName($fileName);
  }
    
  return $fileName;
}

# =========================
sub renderError {
  my $msg = shift;
  return '' unless $msg;
  return "<span class=\"igpAlert\">Error: $msg</span>" ;
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

  my $text = TWiki::Func::readFile($this->{infoFile});
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

  TWiki::Func::saveFile($this->{infoFile}, $text);
}

# =========================
# static
sub writeDebug {
  #TWiki::Func::writeDebug("ImageGalleryPlugin - $_[0]");
  print STDERR "ImageGalleryPlugin - $_[0]\n" if DEBUG;
}



1;
