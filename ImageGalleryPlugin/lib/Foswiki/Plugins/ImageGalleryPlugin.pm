# Copyright (C) 2002-2009 Will Norris. All Rights Reserved. (wbniv@saneasylumstudios.com)
# Copyright (C) 2005-2009 Michael Daum http://michaeldaumconsulting.com
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
package Foswiki::Plugins::ImageGalleryPlugin;
use strict;

# =========================
use vars qw(
        $VERSION $RELEASE $isInitialized $igpId
        $NO_PREFS_IN_TOPIC $SHORTDESCRIPTION 
    );

$VERSION = '$Rev$';
$RELEASE = '5.01';
$NO_PREFS_IN_TOPIC = 1;
$SHORTDESCRIPTION = 'Displays image gallery with auto-generated thumbnails from attachments';

# =========================
sub initPlugin {
  #my ($topic, $web, $user, $installWeb) = @_;

  if ($Foswiki::Plugins::VERSION < 1) {
    &Foswiki::Func::writeWarning("Version mismatch between ImageGalleryPlugin and Plugins.pm");
    return 0;
  }
  $igpId = 1;
  $isInitialized = 0;

  Foswiki::Func::registerTagHandler('IMAGEGALLERY', \&renderImageGallery);
  Foswiki::Func::registerTagHandler('NRIMAGES', \&renderNrImages);

  return 1;
}

# =========================
sub doInit {
  return if $isInitialized;
  $isInitialized = 1;

  Foswiki::Func::addToHEAD("IMAGEGALLERYPLUGIN", <<'HERE');
<link rel="stylesheet" href="%PUBURL%/%SYSTEMWEB%/ImageGalleryPlugin/style.css" type="text/css" media="all" />
HERE

  require Foswiki::Plugins::ImageGalleryPlugin::Core;
}

# =========================
sub renderImageGallery {
  my ($session, $params, $theTopic, $theWeb) = @_;

  doInit();

  my $igp = Foswiki::Plugins::ImageGalleryPlugin::Core->new($igpId++, $theTopic, $theWeb);
  return $igp->render($params);
}

# =========================
sub renderNrImages {
  my ($session, $params, $theTopic, $theWeb) = @_;

  doInit();

  my $igp = Foswiki::Plugins::ImageGalleryPlugin::Core->new(undef, $theTopic, $theWeb);
  if ($igp->init($params)) {
    return scalar @{$igp->getImages()};
  } else {
    return Foswiki::Plugins::ImageGalleryPlugin::Core::renderError("can't initialize");
  }
}

1;
