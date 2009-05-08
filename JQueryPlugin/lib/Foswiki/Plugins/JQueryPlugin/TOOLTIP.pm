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
    css => ['jquery.tooltip.css'],
    javascript => ['jquery.tooltip.js', 'jquery.tooltip.init.js'],
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

1;

