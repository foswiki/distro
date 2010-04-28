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

package Foswiki::Plugins::JQueryPlugin::UI;
use strict;
use Foswiki::Plugins ();
use Foswiki::Plugins::JQueryPlugin::Plugins ();

use Foswiki::Plugins::JQueryPlugin::Plugin;
our @ISA = qw( Foswiki::Plugins::JQueryPlugin::Plugin );

=begin TML

---+ package Foswiki::Plugins::JQueryPlugin::UI

This is the perl stub for the jquery.ui

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
    name => 'UI',
    version => '1.7.2',
    puburl => '%PUBURLPATH%/%SYSTEMWEB%/JQueryPlugin/ui',
    author => 'see http://jqueryui.com/about',
    homepage => 'http://docs.jquery.com/UI',
    javascript => ['jquery-ui.js'],
  ), $class);

  return $this;
}

=begin TML

---++ ClassMethod init( $this )

Initialize this plugin by adding the required static files to the page 

=cut

sub init {
  my $this = shift;

  return unless $this->SUPER::init();

  my $themeName = $Foswiki::cfg{JQueryPlugin}{JQueryTheme} || 'base';
  Foswiki::Plugins::JQueryPlugin::Plugins::createTheme($themeName);

  # open matching localization file if it exists
  my $langTag = $this->{session}->i18n->language();
  my $messagePath = $Foswiki::cfg{SystemWebName}.'/JQueryPlugin/i18n/ui.datepicker-'.$langTag.'.js';
  my $messageFile = $Foswiki::cfg{PubDir}.'/'.$messagePath;
  if (-f $messageFile) {
    my $text .= "<script src='$Foswiki::cfg{PubUrlPath}/$messagePath'></script>\n";
    Foswiki::Func::addToZone('body', "JQUERYPLUGIN::UI::LANG", $text, 'JQUERYPLUGIN::UI');
  }
}
1;

