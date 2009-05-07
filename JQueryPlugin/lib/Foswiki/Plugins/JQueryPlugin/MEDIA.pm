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

package Foswiki::Plugins::JQueryPlugin::MEDIA;
use strict;

use base 'Foswiki::Plugins::JQueryPlugin::Plugin';

=begin TML

---+ package Foswiki::Plugins::JQueryPlugin::MEDIA

This is the perl stub for the jquery.media plugin.

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
    name => 'Media',
    version => '0.89',
    author => 'M. Alsup',
    homepage => 'http://malsup.com/jquery/media',
    javascript => ['jquery.media.js', 'jquery.media.init.js'],
  ), $class);

  $this->{summary} = <<'HERE';
jQuery Media Plugin for converting elements into rich media content.

Supported Media Players:
   * Flash
   * Quicktime
   * Real Player
   * Silverlight
   * Windows Media Player
   * iframe

Supported Media Formats:%BR%
Any types supported by the above players, such as:
   * Video: asf, avi, flv, mov, mpg, mpeg, mp4, qt, smil, swf, wmv, 3g2, 3gp
   * Audio: aif, aac, au, gsm, mid, midi, mov, mp3, m4a, snd, rm, wav, wma
   * Other: bmp, html, pdf, psd, qif, qtif, qti, tif, tiff, xaml
HERE

  return $this;
}

1;

