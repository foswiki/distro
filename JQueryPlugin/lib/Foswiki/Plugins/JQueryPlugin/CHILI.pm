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

package Foswiki::Plugins::JQueryPlugin::CHILI;
use strict;

use base 'Foswiki::Plugins::JQueryPlugin::Plugin';

=begin TML

---+ package Foswiki::Plugins::JQueryPlugin::CHILI

This is the perl stub for the jquery.chili plugin.

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
    name => 'Chili',
    version => '2.2',
    author => 'Andrea Ercolino',
    homepage => 'http://noteslog.com/chili/',
    javascript => ['jquery.chili.js', 'jquery.chili.init.js'],
  ), $class);

  $this->{summary} = <<'HERE';
Chili is the jQuery code highlighter plugin. 

Features:
   * Very fast highlighting, trivial setup, fully customizable, thoroughly documented, and MIT licensed
   * Renders identically on IE, Firefox, Mozilla, Opera, and Safari
   * Comes bundled with recipes for C++, C#, CSS, Delphi, Java, JavaScript, LotusScript, MySQL, PHP, and XHTML
   * Many configuration options: Static, Dynamic, Automatic, Manual, Ad-Hoc, with Metaobjects.
   * Provides fine control over which elements get highlighted by means of a jQuery selector or the mithical jQuery chainability.
   * Fully supports javascript regular expressions, including backreferences
   * The replacement format gives full control on what HTML is used for highlighting
   * Provides examples which show setups and features

Additional recpipes: bash
HERE

  return $this;
}

1;

