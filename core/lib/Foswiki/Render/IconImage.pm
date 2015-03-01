# See bottom of file for license and copyright information
package Foswiki::Render::IconImage;

use strict;
use warnings;

use Foswiki       ();
use Foswiki::Meta ();

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

=begin TML

---++ StaticMethod render($session, $url [, $alt]) -> $html
Generate the output for representing an 16x16 icon image. The source of
the image is taken from =$url=. The optional =$alt= specifies an alt string.

re-written using TMPL:DEF{icon:image} in Foswiki.tmpl
%TMPL:DEF{"icon:image"}%<span class='foswikiIcon'><img src="%URL%" width="%WIDTH%" height="%HEIGHT%" alt="%ALT%" /></span>%TMPL:END%
see System.SkinTemplates:base.css for the default of .foswikiIcon img

TODO: Sven's not sure this code belongs here - its only use appears to be the ICON macro

=cut

sub render {
    my ( $session, $url, $alt, $quote ) = @_;

    if ( !defined($alt) ) {

        #yes, you really should have a useful alt text.
        $alt = $url;
    }

    my $html = $session->templates->expandTemplate("icon:image");
    $html =~ s/%URL%/$url/ge;
    $html =~ s/%WIDTH%/16/g;
    $html =~ s/%HEIGHT%/16/g;
    $html =~ s/%ALT%/$alt/ge;

    $quote ||= '';

    return $html if ( !$quote || $html =~ m/$quote/ );

    if ( $html =~ m/(['"])/ ) {
        my $q = $1;
        $html =~ s/$q/$quote/g;
    }

    return $html;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2012 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2001-2007 Peter Thoeny, peter@thoeny.org
and TWiki Contributors. All Rights Reserved.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
