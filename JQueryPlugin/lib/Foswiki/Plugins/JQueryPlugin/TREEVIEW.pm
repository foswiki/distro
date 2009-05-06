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

package Foswiki::Plugins::JQueryPlugin::TREEVIEW;
use strict;

use base 'Foswiki::Plugins::JQueryPlugin::Plugin';

=begin TML

---+ package Foswiki::Plugins::JQueryPlugin::TREEVIEW

This is the perl stub for the jquery.empty plugin.

=cut

=begin TML

---++ ClassMethod new( $class, $session, ... )

=cut

sub new {
  my $class = shift;
  my $session = shift || $Foswiki::Plugins::SESSION;

  my $this = bless($class->SUPER::new( 
    $session,
    name => 'Treeview',
    version => '1.4',
    author => 'Joern Zaefferer',
    homepage => 'http://bassistance.de/jquery-plugins/jquery-plugin-treeview',
    css => ['jquery.treeview.css'],
    javascript => ['jquery.treeview.js', 'jquery.treeview.async.js', 'jquery.treeview.init.js'],
  ), $class);

  $this->{summary} = <<'HERE';
Lightweight and flexible transformation of an unordered list into an
expandable and collapsable tree, great for unobtrusive navigation enhancements.
Supports both location and cookie based persistence.

Subtrees can be loaded on demand using AJAX. See the Foswiki:Extensions/RenderPlugin
how to implement such REST handlers easily.
HERE

  return $this;
}

1;
