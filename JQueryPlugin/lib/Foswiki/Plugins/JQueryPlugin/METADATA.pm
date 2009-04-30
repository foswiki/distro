# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/,
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

package Foswiki::Plugins::JQueryPlugin::METADATA;
use strict;

use base 'Foswiki::Plugins::JQueryPlugin::Plugin';

=begin TML

---+ package Foswiki::Plugins::JQueryPlugin::METADATA

This is the perl stub for the jquery.metadata plugin.

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
    name => 'Metadata',
    version => '3630',
    author => 'John Resig, Yehuda Katz, Joern Zaefferer, Paul <nop>McLanahan',
    homepage => 'http://plugins.jquery.com/project/metadata',
  ), $class);

  $this->{summary} = <<'HERE';
This plugin is capable of extracting metadata from classes, random attributes,
and child elements.
HERE

  # default plugin
  # TODO: make configurable
  $this->{isActive} = 1;

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
<script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/JQueryPlugin/plugins/metadata/jquery.metadata.uncompressed.js"></script>
HERE
  } else {
   $header = <<'HERE';
<script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/JQueryPlugin/plugins/metadata/jquery.metadata.js"></script>
HERE
  }

  Foswiki::Func::addToHEAD("JQUERYPLUGIN::METADATA", $header, 'JQUERYPLUGIN::FOSWIKI');
}

1;
