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
<link rel="stylesheet" href="%PUBURLPATH%/%SYSTEMWEB%/JQueryPlugin/plugins/treeview/jquery.treeview.uncompressed.css" type="text/css" media="all" />
<script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/JQueryPlugin/plugins/treeview/jquery.treeview.uncompressed.js"></script>
<script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/JQueryPlugin/plugins/treeview/jquery.treeview.init.uncompressed.js"></script>
HERE
  } else {
   $header = <<'HERE';
<link rel="stylesheet" href="%PUBURLPATH%/%SYSTEMWEB%/JQueryPlugin/plugins/treeview/jquery.treeview.css" type="text/css" media="all" />
<script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/JQueryPlugin/plugins/treeview/jquery.treeview.js"></script>
HERE
  }

  Foswiki::Func::addToHEAD("JQUERYPLUGIN::TREEVIEW", $header, 'JQUERYPLUGIN::FOSWIKI');
}

1;
