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

package Foswiki::Plugins::JQueryPlugin::Plugin;
use strict;

=begin TML

---+ package Foswiki::Plugins::JQueryPlugin::Plugin

abstract class for a jQuery plugin

=cut

=begin TML

---++ ClassMethod new( $session, $name )

   * =$session= - Foswiki object
   * =$name= - name of the plugin e.g. autocomplete

=cut

sub new {
  my ($class, $session) = @_;

  my $this = bless({
    session => $session,
    debug => $Foswiki::cfg{JQueryPlugin}{Debug} || 0
  }, $class);

  $this->init();
  return $this;
}

=begin TML

---++ ClassMethod init()

add jQuery plugin to web and make sure all its dependencies 
are fulfilled

=cut

sub init {
  die "no init implemented";
}


1;
