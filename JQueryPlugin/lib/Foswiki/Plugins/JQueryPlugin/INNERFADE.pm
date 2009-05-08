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

package Foswiki::Plugins::JQueryPlugin::INNERFADE;
use strict;

use base 'Foswiki::Plugins::JQueryPlugin::Plugin';

=begin TML

---+ package Foswiki::Plugins::JQueryPlugin::INNERFADE

This is the perl stub for the jquery.innerfade plugin.

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
    name => 'InnerFade',
    version => '20080214',
    author => 'Torsten Baldes',
    homepage => 'http://medienfreunde.com/lab/innerfade',
    css => ['jquery.innerfade.css'],
    javascript => ['jquery.innerfade.js', 'jquery.innerfade.init.js' ],
  ), $class);

  $this->{summary} = <<'HERE';
InnerFade is a small plugin for the jQuery-JavaScript-Library. It's designed to
fade you any element inside a container in and out.  These elements could be
anything you want, e.g. images, list-items, divs. Simply produce your own
slideshow for your portfolio or advertisings. Create a newsticker or do an
animation.

Example:
<verbatim class="html">
<ul id="news">
    <li>content 1</li>
    <li>content 2</li>
    <li>content 3</li>
</ul>

$('#news').innerfade({
    animationtype: 
      Type of animation 'fade' or 'slide' 
      (Default: 'fade'),

    speed: 
      Fading-/Sliding-Speed in milliseconds or keywords 
      (slow, normal or fast) (Default: 'normal'),

    timeout: 
      Time between the fades in milliseconds (Default: '2000'),

    type: 
      Type of slideshow: 'sequence', 'random' or 'random_start' 
      (Default: 'sequence'), 

    containerheight: 
      Height of the containing element in any css-height-value 
      (Default: 'auto'),

    runningclass: 
      CSS-Class which the container get’s applied 
      (Default: 'innerfade'),

    children: 
      optional children selector (Default: null)
});
</verbatim>
HERE

  return $this;
}

1;

