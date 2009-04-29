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

###############################################################################
sub init {
  my $this = shift;

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
