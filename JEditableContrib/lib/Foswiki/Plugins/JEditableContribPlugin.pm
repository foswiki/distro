package Foswiki::Plugins::JEditableContribPlugin;

use strict;
use warnings;

use Foswiki::Plugins::JQueryPlugin::Plugins       ();
use Foswiki::Contrib::JEditableContrib::JEDITABLE ();

our $NO_PREFS_IN_TOPIC = 1;

sub initPlugin {
    Foswiki::Plugins::JQueryPlugin::registerPlugin( 'JEditable',
        'Foswiki::Contrib::JEditableContrib::JEDITABLE' );
    Foswiki::Plugins::JQueryPlugin::createPlugin('JEditable');
}

1;
__END__
Author: Crawford Currie http://c-dot.co.uk

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2011 Foswiki Contributors. Foswiki Contributors
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
