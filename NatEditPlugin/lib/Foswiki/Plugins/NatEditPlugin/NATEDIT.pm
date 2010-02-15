# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
# 
# Copyright (C) 2006-2010 Michael Daum, http://michaeldaumconsulting.com
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

package Foswiki::Plugins::NatEditPlugin::NATEDIT;
use strict;

use base 'Foswiki::Plugins::JQueryPlugin::Plugin';

=begin TML

---+ package Foswiki::Plugins::NatEditPlugin::NATEDIT

This is the perl stub for the jquery.natedit plugin.

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
    name => 'NatEdit',
    version => '1.0',
    author => 'Michael Daum',
    homepage => 'http://foswiki.org/Extensions/NatEditPlugin',
    puburl => '%PUBURLPATH%/%SYSTEMWEB%/NatEditPlugin',
    css => ['styles.css'],
    documentation => "$Foswiki::cfg{SystemWebName}.NatEditPlugin",
    javascript => ['edit.js', 'jquery.natedit.js'],
    dependencies => ['simplemodal', 'textboxlist', 'form'],
  ), $class);

  return $this;
}

=begin TML

---++ ClassMethod init( $this )

Initialize this plugin by adding the required static files to the html header

=cut

sub init {
  my $this = shift;

  return unless $this->SUPER::init();

  Foswiki::Func::addToZone("head", "JQUERYPLUGIN::NATEDIT::THEME", <<"HERE", 'JQUERYPLUGIN::NATEDIT');
<link rel='stylesheet' href='%PUBURLPATH%/%SYSTEMWEB%/NatEditPlugin/%IF{\"defined NATEDIT_THEME\" then=\"%NATEDIT_THEME%\" else=\"default\"}%/styles.css?version=$this->{version}' type='text/css' media='all' />
HERE

}

1;
