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

package Foswiki::Plugins::JQueryPlugin::AUTOCOMPLETE;
use strict;
use base 'Foswiki::Plugins::JQueryPlugin::Plugin';

=begin TML

---+ pacakage Foswiki::Plugins::JQueryPlugin::AUTOCOMPLETE

Autocomplete - jQuery plugin 1.1pre

Copyright (c) 2007 Dylan Verheul, Dan G. Switzer, Anjesh Tuladhar, Jörn Zaefferer

Dual licensed under the MIT and GPL licenses:
  http://www.opensource.org/licenses/mit-license.php
  http://www.gnu.org/licenses/gpl.html

Revision: jquery.autocomplete.js 5785 2008-07-12 10:37:33Z joern.zaefferer

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
    name => 'Autocomplete',
    version => '1.1pre',
    author => 'Dylan Verheul, Dan G. Switzer, Anjesh Tuladhar, Jörn Zaefferer',
    homepage => 'http://bassistance.de/jquery-plugins/jquery-plugin-autocomplete/',
  ), $class);

  $this->{summary} = <<'HERE';
Autocomplete an input field to enable users quickly finding and selecting some
value, leveraging searching and filtering.  
By giving an autocompleted field focus or entering something into it, the
plugin starts searching for matching entries and displays a list of values to
choose from. By entering more characters, the user can filter down the list to
better matches.  
This can be used to enter previous selected values, eg. for tags, to complete
an address, eg. enter a city name and get the zip code, or maybe enter email
addresses from an addressbook.
HERE

  return $this;
}

=begin TML

---++ ClassMethod init ($this)

Initialize this plugin by adding the required static files to the html header

=cut

sub init {
  my $this = shift;

  return unless $this->SUPER::init();

  my $header;

  if ($this->{debug}) {
   $header = <<'HERE';
<link rel="stylesheet" href="%PUBURLPATH%/%SYSTEMWEB%/JQueryPlugin/plugins/autocomplete/jquery.autocomplete.uncompressed.css" type="text/css" media="all" />
<script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/JQueryPlugin/plugins/autocomplete/jquery.autocomplete.uncompressed.js"></script>
HERE
  } else {
   $header = <<'HERE';
<link rel="stylesheet" href="%PUBURLPATH%/%SYSTEMWEB%/JQueryPlugin/plugins/autocomplete/jquery.autocomplete.css" type="text/css" media="all" />
<script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/JQueryPlugin/plugins/autocomplete/jquery.autocomplete.js"></script>
HERE
  }

  Foswiki::Func::addToHEAD("JQUERYPLUGIN::AUTOCOMPLETE", $header, 'JQUERYPLUGIN::FOSWIKI');
}

1;
