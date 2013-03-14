# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2013 Crawford Currie, http://c-dot.co.uk
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

package Foswiki::Plugins::SubscribePlugin::JQuery;
use strict;

use Assert;

use Foswiki::Plugins::JQueryPlugin::Plugin ();
our @ISA = qw( Foswiki::Plugins::JQueryPlugin::Plugin );

sub new {
    my $class = shift;
    my $session = shift || $Foswiki::Plugins::SESSION;

    my $this = $class->SUPER::new(
        $session,
        name          => 'Subscribe',
        version       => '2.0',
        author        => 'Crawford Currie',
        homepage      => 'http://foswiki.org/Extensions/SubscribePlugin',
        puburl        => '%PUBURLPATH%/%SYSTEMWEB%/SubscribePlugin',
        documentation => "$Foswiki::cfg{SystemWebName}.SubscribePlugin",
        javascript    => ["subscribe_plugin.js"],
        dependencies  => [ 'UI', "Theme" ]
    );

    return $this;
}

1;
