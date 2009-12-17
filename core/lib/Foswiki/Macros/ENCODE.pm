# See bottom of file for license and copyright information
package Foswiki;

use strict;

sub ENCODE {
    my ( $this, $params ) = @_;
    my $type = $params->{type} || 'url';

    # Value 0 can be valid input so we cannot use simple = || ''
    my $text = defined( $params->{_DEFAULT} ) ? $params->{_DEFAULT} : '';

    if ( $type =~ /^entit(y|ies)$/i ) {
        return entityEncode($text);
    }
    elsif ( $type =~ /^html$/i ) {
        return entityEncode( $text, "\n\r" );
    }
    elsif ( $type =~ /^quotes?$/i ) {

        # escape quotes with backslash (Bugs:Item3383 fix)
        $text =~ s/\"/\\"/go;
        return $text;
    }
    elsif ( $type =~ /^url$/i ) {
        $text =~ s/\r*\n\r*/<br \/>/;    # Legacy.
        return urlEncode($text);
    }
    elsif ( $type =~ /^(off|none)$/i ) {

        # no encoding
        return $text;
    }
    else {                               # safe or default
                                         # entity encode ' " < > and %
        $text =~ s/([<>%'"])/'&#'.ord($1).';'/ge;
        return $text;
    }
}

1;
__DATA__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2009 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 1999-2007 Peter Thoeny, peter@thoeny.org
and TWiki Contributors. All Rights Reserved. TWiki Contributors
are listed in the AUTHORS file in the root of this distribution.
Based on parts of Ward Cunninghams original Wiki and JosWiki.
Copyright (C) 1998 Markus Peter - SPiN GmbH (warpi@spin.de)
Some changes by Dave Harris (drh@bhresearch.co.uk) incorporated

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
