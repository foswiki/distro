# See the bottom of the file for description, copyright and license information
package Foswiki::Plugins::SubscribePlugin::JQuery;
use strict;

use Foswiki::Plugins::JQueryPlugin::Plugin ();
our @ISA = qw( Foswiki::Plugins::JQueryPlugin::Plugin );

use Foswiki::Plugins::SubscribePlugin ();

sub new {
    my $class = shift;
    my $session = shift || $Foswiki::Plugins::SESSION;

    my $this = $class->SUPER::new(
        $session,
        name          => 'Subscribe',
        version       => $Foswiki::Plugins::SubscribePlugin::VERSION,
        author        => 'Crawford Currie',
        homepage      => 'http://foswiki.org/Extensions/SubscribePlugin',
        puburl        => '%PUBURLPATH%/%SYSTEMWEB%/SubscribePlugin',
        documentation => "$Foswiki::cfg{SystemWebName}.SubscribePlugin",
        javascript    => ["subscribe_plugin.js"],
        dependencies  => [ 'FOSWIKI', 'UI' ]
    );

    return $this;
}

1;
__END__

Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2013-2014 Crawford Currie http://c-dot.co.uk
and Foswiki Contributors. All Rights Reserved. Foswiki Contributors
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

For licensing info read LICENSE file in the Foswiki root.

Author: Crawford Currie http://c-dot.co.uk
