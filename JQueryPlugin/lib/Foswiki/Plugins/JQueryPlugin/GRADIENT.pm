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

package Foswiki::Plugins::JQueryPlugin::GRADIENT;
use strict;

use base 'Foswiki::Plugins::JQueryPlugin::Plugin';

=begin TML

---+ package Foswiki::Plugins::JQueryPlugin::EMPTY

This is the perl stub for the jquery.gradient plugin.

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
    name => 'Gradient',
    version => '1.0.1-pre',
    author => 'Brandon Aaron Last',
    homepage => 'http://brandonaaron.net',
    javascript => ['jquery.gradient.js', 'jquery.gradient.init.js'],
    dependencies => ['metadata'], 
  ), $class);

  $this->{summary} = <<'HERE';
Adds a gradient to the background of an element.

example:
<verbatim>$('div').gradient({ from: '000000', to: 'CCCCCC' });</verbatim>

options:
   * from: The hex color code to start the gradient with. By default the value is "000000".
   * to: The hex color code to end the gradient with. 
     By default the value is "FFFFFF".
   * direction: This tells the gradient to be horizontal or vertical. 
     By default the value is "horizontal".
   * length: This is used to constrain the gradient to a
     particular width or height (depending on the direction). By default
     the length is set to null, which will use the width or height
     (depending on the direction) of the element.
   * position: This tells the gradient to be positioned
     at the top, bottom, left and/or right within the element. The
     value is just a string that specifices top or bottom and left or right.
     By default the value is 'top left'.
HERE

  return $this;
}

1;

