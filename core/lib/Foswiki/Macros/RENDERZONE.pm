# See bottom of file for license and copyright information
package Foswiki;

use strict;
use warnings;

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

sub RENDERZONE {
    my ( $this, $params, $topicObject ) = @_;

    my $zones = $this->zones();

    # Note, that RENDERZONE is not expanded as soon as this function is called.
    # Instead, a placeholder is inserted into the page. Rendering the current
    # page continues as normal. That way all calls to ADDTOZONE will gather
    # content until the end of the rendering pipeline. Only then will all
    # of the zones' content be registered. The placeholder for RENDERZONE
    # will be expanded at the very end within the Foswiki::writeCompletePage
    # method.

    my $id = scalar( keys %{ $zones->{_renderZonePlaceholder} } );

    $zones->{_renderZonePlaceholder}{$id} = {
        params      => $params,
        topicObject => $topicObject,
    };

    return
        $Foswiki::RENDERZONE_MARKER
      . "RENDERZONE{$id}"
      . $Foswiki::RENDERZONE_MARKER;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2010 Foswiki Contributors. Foswiki Contributors
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
