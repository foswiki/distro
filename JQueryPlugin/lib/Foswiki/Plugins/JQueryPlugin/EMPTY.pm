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

package Foswiki::Plugins::JQueryPlugin::EMPTY;
use strict;

use base 'Foswiki::Plugins::JQueryPlugin::Plugin';

=begin TML

---+ package Foswiki::Plugins::JQueryPlugin::EMPTY

This is the perl stub for the jquery.empty plugin.

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
    name => 'Empty',
    version => '$Rev$',
    author => 'First Last',
    homepage => 'http://...',
    tags => 'EMPTY',
  ), $class);

  $this->{summary} = <<'HERE';
Template plugin for jQuery plugins integrated to Foswiki.
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
<link rel="stylesheet" href="%PUBURLPATH%/%SYSTEMWEB%/JQueryPlugin/plugins/empty/jquery.empty.uncompressed.css" type="text/css" media="all" />
<script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/JQueryPlugin/plugins/empty/jquery.empty.uncompressed.js"></script>
HERE
  } else {
   $header = <<'HERE';
<link rel="stylesheet" href="%PUBURLPATH%/%SYSTEMWEB%/JQueryPlugin/plugins/empty/jquery.empty.css" type="text/css" media="all" />
<script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/JQueryPlugin/plugins/empty/jquery.empty.js"></script>
HERE
  }

  # dependencies
  # $this->createPlugin('Validate');

  Foswiki::Func::addToHEAD("JQUERYPLUGIN::EMPTY", $header, 'JQUERYPLUGIN::FOSWIKI');
}

=begin TML

---++ ClassMethod handleEMPTY( $this, $params, $topic, $web ) -> $result

Tag handler for =%<nop>EMPTY%=. You might need to add 
to Foswiki::Plugins::JQueryPlugin::initPlugin() the following:

<verbatim>
  Foswiki::Func::registerTagHandler('EMPTY', \&handleEMPTY );
</verbatim>

and also

<verbatim>
sub handleEMPTY {
  my $session = shift;
  my $plugin = createPlugin('Empty', $session);
  return $plugin->handleEMPTY(@_) if $plugin;
  return '';
}
</verbatim>

=cut

sub handleEMPTY {
  my ($this, $params, $topic, $web) = @_;

  return "<span class='foswikiAlert'>This is empty.</span>";
}

1;

