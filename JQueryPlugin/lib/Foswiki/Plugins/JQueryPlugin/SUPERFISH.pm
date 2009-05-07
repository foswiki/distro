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

package Foswiki::Plugins::JQueryPlugin::SUPERFISH;
use strict;
use base 'Foswiki::Plugins::JQueryPlugin::Plugin';

=begin TML

---+ package Foswiki::Plugins::JQueryPlugin::SUPERFISH

This is the perl stub for the jquery.superfish plugin.

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
    name => 'Superfish',
    version => '1.4.1',
    author => 'Joel Birch',
    homepage => 'http://users.tpg.com.au/j_birch/plugins/superfish/',
    javascript => ['jquery.superfish.js'],
  ), $class);

  $this->{summary} = <<'HERE';
Superfish is an enhanced Suckerfish-style menu jQuery plugin that takes an
existing pure CSS drop-down menu (so it degrades gracefully without JavaScript).
Features:
   * Suckerfish-style hover support for IE6. The class added is sfHover by default but can be changed via the options object,
   * Timed delay on mouseout to be more forgiving of mouse-piloting errors. Default is 800 milliseconds but can be changed via the options object
   * Animation of sub-menu reveal. uses a fade-in by default but can be given a custom object to be used in the first argument of the animate function. The animation speed is also customisable but is set to ?normal? by default
   * Keyboard accessibility. Tab through the links and the relevant sub-menus are revealed and hidden as needed
   * Supports the hoverIntent plugin. Superfish automatically detects the presence of Brian Cherne?s hoverIntent plugin and uses its advanced hover behaviour for the mouseovers (mouseout delays are handled by Superfish regardless of the presence of hoverIntent). Using this is only an option, but a nice one. The examples on this page are using hoverIntent. If for some reason you want to use hoverIntent on your page for other plugins but do not want Superfish to use it you can set the option disableHI to true.
   * Indicates the presence of sub-menus by automatically adding arrow images to relevant anchors. Arrows are fully customisable via CSS. You can turn off auto-generation of the arrow mark-up via the ?autoArrows? option if required.
   * drop shadows for capable browsers ? degrades gracefully for Internet Explorer 6. Can disable shadows completely via options object.
   * Can show the path to your current page while the menu is idle. The easiest way to understand this is to view the nav-bar example.
   * Optional callback functions. The 'this' keyword within the handlers you attach will refer to the animated ul sub-menu. From version 1.4 there are now three other optional callbacks allowing for further enhancements and functionality to be added without needing to alter the core Superfish code.

TODO: upgrade to 1.4.8 or later
HERE

  return $this;
}

1;
