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

package Foswiki::Plugins::JQueryPlugin::EASING;
use strict;

use base 'Foswiki::Plugins::JQueryPlugin::Plugin';

=begin TML

---+ package Foswiki::Plugins::JQueryPlugin::EASING

This is the perl stub for the jquery.easing plugin.

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
    name => 'Easing',
    version => '1.3',
    author => 'George <nop>McGinley Smith',
    homepage => 'http://gsgd.co.uk/sandbox/jquery/easing',
  ), $class);

  $this->{summary} = <<'HERE';
Uses the built in easing capabilities added In jQuery 1.1
to offer multiple easing options.
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
<script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/JQueryPlugin/plugins/easing/jquery.easing.uncompressed.js"></script>
HERE
  } else {
   $header = <<'HERE';
<script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/JQueryPlugin/plugins/easing/jquery.easing.js"></script>
HERE
  }

  # dependencies
  # Foswiki::Plugins::JQueryPlugin::Plugins::createPlugin('Validate');

  Foswiki::Func::addToHEAD("JQUERYPLUGIN::EASING", $header, 'JQUERYPLUGIN::FOSWIKI');
}

1;

