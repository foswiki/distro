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

package Foswiki::Plugins::JQueryPlugin::CYCLE;
use strict;

use base 'Foswiki::Plugins::JQueryPlugin::Plugin';

=begin TML

---+ package Foswiki::Plugins::JQueryPlugin::EMPTY

This is the perl stub for the jquery.cycle plugin.

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
    name => 'Cycle',
    version => '2.65',
    author => 'M. Alsup',
    homepage => 'http://www.malsup.com/jquery/cycle',
  ), $class);

  $this->{summary} = <<'HERE';
The jQuery Cycle Plugin is a lightweight slideshow plugin. Its implementation
is based on the InnerFade Plugin by Torsten Baldes, the Slideshow Plugin by
Matt Oakes, and the jqShuffle Plugin by Benjamin Sterling. It supports
pause-on-hover, auto-stop, auto-fit, before/after callbacks, click triggers and
many transition effects. It also supports, but does not require, the Metadata
Plugin and the Easing Plugin.
HERE

  return $this;
}

###############################################################################
sub init {
  my $this = shift;

  return unless $this->SUPER::init();

  my $header;

  if ($this->{debug}) {
   $header = <<'HERE';
<script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/JQueryPlugin/plugins/cycle/jquery.cycle.uncompressed.js"></script>
HERE
  } else {
   $header = <<'HERE';
<script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/JQueryPlugin/plugins/cycle/jquery.cycle.js"></script>
HERE
  }

  Foswiki::Func::addToHEAD("JQUERYPLUGIN::CYCLE", $header, 'JQUERYPLUGIN::FOSWIKI');
}

1;
