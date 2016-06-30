# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2011 Crawford Currie, http://c-dot.co.uk
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

package Foswiki::Plugins::EditRowPlugin::JQuery;
use v5.14;

use Moo;
extends qw( Foswiki::Plugins::JQueryPlugin::Plugin );

our %pluginParams = (
    name          => 'EditRow',
    version       => '1.0',
    author        => 'Crawford Currie',
    homepage      => 'http://foswiki.org/Extensions/EditRowPlugin',
    puburl        => '%PUBURLPATH%/%SYSTEMWEB%/EditRowPlugin',
    css           => ["erp.css"],
    documentation => "$Foswiki::cfg{SystemWebName}.EditRowPlugin",
    javascript    => [ "erp.js", "TableSort.js" ],
    dependencies  => [ 'UI', 'JEditable' ]
);

1;
