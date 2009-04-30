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

package Foswiki::Plugins::JQueryPlugin::TOOLTIP;
use strict;

use base 'Foswiki::Plugins::JQueryPlugin::Plugin';

=begin TML

---+ package Foswiki::Plugins::JQueryPlugin::TOOLTIP

This is the perl stub for the jquery.tooltip plugin.

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
    name => 'Tooltip',
    version => '1.3',
    author => 'Joern Zaefferer',
    homepage => 'http://bassistance.de/jquery-plugins/jquery-plugin-tooltip/',
  ), $class);

  $this->{summary} = <<'HERE';
Display a customized tooltip instead of the default one for every selected
element. Tooltips can be added automatically to any element that has got
at =title= attribute thus replacing the standard tooltip as displayed by
the browsers with a customizable one.

Content can be reloaded using AJAX. For example, this can be used to
display an image preview in a tooltip. Have a look at the thumbnail REST
service of Foswiki:Extensions/ImagePlugin how to load the thumnail from the
backend dynamically.
HERE

  return $this;
}

=begin TML

---++ ClassMethod init( $this )

Initialize this plugin by adding the required static files to the html header

=cut

sub init {
  my $this = shift;

  return unless $this->SUPER::init();

  my $header;
  if ($this->{debug}) {
    $header = <<'HERE';
<link rel="stylesheet" href="%PUBURLPATH%/%SYSTEMWEB%/JQueryPlugin/plugins/tooltip/jquery.tooltip.uncompressed.css" type="text/css" media="all" />
<script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/JQueryPlugin/plugins/tooltip/jquery.tooltip.uncompressed.js"></script>
HERE
  } else {
    $header = <<'HERE';
<link rel="stylesheet" href="%PUBURLPATH%/%SYSTEMWEB%/JQueryPlugin/plugins/tooltip/jquery.tooltip.css" type="text/css" media="all" />
<script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/JQueryPlugin/plugins/tooltip/jquery.tooltip.js"></script>
HERE
  }

  Foswiki::Func::addToHEAD('JQUERYPLUGIN::TOOLTIP', $header, 'JQUERYPLUGIN::FOSWIKI');
}

1;

