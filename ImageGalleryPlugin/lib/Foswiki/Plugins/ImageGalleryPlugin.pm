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
package Foswiki::Plugins::ImageGalleryPlugin;
use strict;

# =========================
our $VERSION = '$Rev$';
our $RELEASE = '6.00';
our $NO_PREFS_IN_TOPIC = 1;
our $SHORTDESCRIPTION = 'Displays image gallery with auto-generated thumbnails from attachments';
our $isInitialized;
our $igpId;
our $TranslationToken = "\2\3\2"; # SMELL arbitrary but may clash with other plugin's transtoks
our %knownGalleries;

# =========================
sub initPlugin {
  #my ($topic, $web, $user, $installWeb) = @_;

  if ($Foswiki::Plugins::VERSION < 1) {
    &Foswiki::Func::writeWarning("Version mismatch between ImageGalleryPlugin and Plugins.pm");
    return 0;
  }
  $igpId = 0;
  $isInitialized = 0;
  %knownGalleries = ();

  Foswiki::Func::registerTagHandler('IMAGEGALLERY', \&renderImageGalleryPlaceholder);
  Foswiki::Func::registerTagHandler('NRIMAGES', \&renderNrImages);

  return 1;
}

# =========================
sub doInit {
  return if $isInitialized;
  $isInitialized = 1;

  Foswiki::Func::addToHEAD("IMAGEGALLERYPLUGIN", <<'HERE');
<link rel="stylesheet" href="%PUBURLPATH%/%SYSTEMWEB%/ImageGalleryPlugin/style.css" type="text/css" media="all" />
HERE

  require Foswiki::Plugins::ImageGalleryPlugin::Core;
}

# =========================
sub renderImageGalleryPlaceholder {
  my ($session, $params, $theTopic, $theWeb) = @_;

  doInit();

  $igpId++;
  $knownGalleries{$igpId} = {
    core => Foswiki::Plugins::ImageGalleryPlugin::Core->new($igpId, $theTopic, $theWeb),
    params => $params
  };
  return $TranslationToken.'IMAGEGALLERY{'.$igpId.'}'.$TranslationToken;
}

# =========================
sub postRenderingHandler {
  # my $text = shift;

  $_[0] =~ s/${TranslationToken}IMAGEGALLERY{(.*?)}$TranslationToken/renderImageGallery($1)/ge;
}

# =========================
sub renderImageGallery {
  my $igpId = shift;

  my $igp = $knownGalleries{$igpId};
  return '' unless $igp;

  return $igp->{core}->render($igp->{params});
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
