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

package Foswiki::Plugins::UpdatesPlugin;

use strict;
use warnings;

use Foswiki::Func ();

our $VERSION = '$Rev$';
our $RELEASE = '0.01';
our $SHORTDESCRIPTION = 'Checks Foswiki.org for updates';
our $NO_PREFS_IN_TOPIC = 1;
our $baseWeb;
our $baseTopic;
our $core;

=begin TML

---++ initPlugin($topic, $web, $user) -> $boolean

=cut

sub initPlugin {
  ($baseTopic, $baseWeb) = @_;

  Foswiki::Func::registerTagHandler('MACRO', sub {
    return getCore->MACRO(@_);
  });

  if (Foswiki::Func::isAnAdmin()) {
    Foswiki::Func::addToZone("script", "UPDATES::JS", <<JS, "JQUERYPLUGIN");
<script src="%PUBURLPATH%/%SYSTEMWEB%/UpdatesPlugin/jquery.updates.js"></script>
JS
  };

  return 1;
}

sub getCore {

  unless (defined $core) {
    require Foswiki::Plugins::UpdatesPlugin::Core;
    $core = new Foswiki::Plugins::UpdatesPlugin::Core();
  }

  return $core;
}

1;
