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

package Foswiki::Plugins::JQueryPlugin::BLOCKUI;
use strict;

use base 'Foswiki::Plugins::JQueryPlugin::Plugin';

=begin TML

---+ package Foswiki::Plugins::JQueryPlugin::BLOCKUI

This is the perl stub for the jquery.blockUI plugin.

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
    name => 'blockUI',
    version => '2.18',
    author => 'M. Alsup',
    homepage => 'http://malsup.com/jquery/block/',
    javascript => ['jquery.blockUI.js'],
  ), $class);

  $this->{summary} = <<'HERE';
The jQuery BlockUI Plugin lets you simulate synchronous behavior when using
AJAX, without locking the browser. When activated, it will prevent user
activity with the page (or part of the page) until it is deactivated. BlockUI
adds elements to the DOM to give it both the appearance and behavior of
blocking user interaction.
HERE

  return $this;
}

1;

