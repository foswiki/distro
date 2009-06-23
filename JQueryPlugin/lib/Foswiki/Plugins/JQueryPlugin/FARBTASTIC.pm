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

package Foswiki::Plugins::JQueryPlugin::FARBTASTIC;
use strict;

use base 'Foswiki::Plugins::JQueryPlugin::Plugin';

=begin TML

---+ package Foswiki::Plugins::JQueryPlugin::FARBTASTIC

This is the perl stub for the jquery.empty plugin.

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
    name => 'Farbtastic',
    version => '1.2',
    author => 'Steven Wittens',
    homepage => 'http://acko.net/dev/farbtastic',
    css => ['jquery.farbtastic.css'],
    javascript => ['jquery.farbtastic.js', 'jquery.farbtastic.init.js'],
    dependencies => ['metadata'], 
  ), $class);

  $this->{summary} = <<'HERE';
Farbtastic is a jQuery plug-in that can add one or more color picker widgets
into a page. Each widget is then linked to an existing element (e.g. a text
field) and will update the element's value when a color is selected.
Farbtastic uses layered transparent PNGs to render a saturation/luminance
gradient inside of a hue circle. No Flash or pixel-sized divs are used.

Basic usage:
<verbatim>
<input type="text" id="color" name="color" value="#123456" class="jqFarbtastic" />
</verbatim>

There's a =color= formfield for easy integration into Foswiki !DataForms.
HERE

  return $this;
}

1;

