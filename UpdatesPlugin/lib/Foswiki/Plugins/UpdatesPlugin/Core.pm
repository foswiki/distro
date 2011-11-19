# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# UpdatesPlugin is Copyright (C) 2011 Foswiki Contributors
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

package Foswiki::Plugins::UpdatesPlugin::Core;

use strict;
use warnings;

=begin TML

---+ package UpdatesPlugin::Core

=cut

use Foswiki::Func ();

use constant DEBUG => 0; # toggle me

=begin TML

---++ writeDebug($message(

prints a debug message to STDERR when this module is in DEBUG mode

=cut

sub writeDebug {
  print STDERR "UpdatesPlugin::Core - $_[0]\n" if DEBUG;
}

=begin TML

---++ new($class, $baseWeb, $baseTopic)

constructor for the core

=cut

sub new {
  my $class = shift;

  return bless({
    @_
  }, $class);

}

=begin TML

---++ MACRO($this, $session, $params, $theTopic, $theWeb) -> $result

implementation of this macro

=cut

sub MACRO {
  my ($this, $session, $params, $theTopic, $theWeb) = @_;

  writeDebug("called MACRO()");
  my $result = '';

  return $result;
}


1;
