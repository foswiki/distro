# See bottom of file for license and copyright information
#
# See Plugin topic for history and plugin information

package Foswiki::Plugins::ConfigurePlugin::JQuery;
use strict;

use Foswiki::Plugins::JQueryPlugin::Plugin ();
our @ISA = qw( Foswiki::Plugins::JQueryPlugin::Plugin );

sub new {
    my $class = shift;
    my $session = shift || $Foswiki::Plugins::SESSION;

    my $this = $class->SUPER::new(
        $session,
        name          => 'Configure',
        version       => '1.0',
        author        => 'Crawford Currie',
        homepage      => 'http://foswiki.org/Extensions/ConfigurePlugin',
        puburl        => '%PUBURLPATH%/%SYSTEMWEB%/ConfigurePlugin',
        documentation => "$Foswiki::cfg{SystemWebName}.ConfigurePlugin",
        javascript =>
          [ 'resig.js', 'types.js', 'render_tml.js', 'configure.js' ],
        css          => ['configure.css'],
        dependencies => [
            'JQUERYPLUGIN', 'JQUERYPLUGIN::THEME',
            'UI',           'JsonRpc',
            'UI::Tabs',     'pnotify',
            'UI::Tooltip',  'UI::Dialog'
        ]
    );

    return $this;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2014 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
