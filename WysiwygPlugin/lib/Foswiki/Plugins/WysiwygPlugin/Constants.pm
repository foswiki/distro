# See bottom of file for license and copyright information
package Foswiki::Plugins::WysiwygPlugin::Constants;

=pod

---+ package Foswiki::Plugins::WysiwygPlugin::Constants a.k.a WC

Constants used throughout WysiwygPlugin

=cut

sub test_reset {
    $WC::encoding                 = undef;
    $WC::siteCharsetRepresentable = undef;
}

package WC;    # Short name

use strict;
use warnings;

use Encode;
use HTML::Entities;

=pod

---++ REs
REs for matching delimiters of wikiwords, must be consistent with TML2HTML.pm

| $STARTWW | Zero-width match for the start of a wikiword |
| $ENDWW | Zero-width match for the end of a wikiword |
| $PROTOCOL | match for a valid URL protocol e.g. http, mailto etc |

=cut

# STARTWW should match Foswiki::Render, execpt need to include protected whitespace spans.
our $STARTWW =
  qr/^|(?<=[ \t\n\(])|(?<=<p>)|(?<=nbsp;<\/span>)|(?<=160;<\/span>)/om;
our $ENDWW    = qr/$|(?=[ \t\n\,\.\;\:\!\?\)])|(?=<\/p>)|(?=<span\b[^>]*> )/om;
our $PROTOCOL = qr/^(file|ftp|gopher|https?|irc|news|nntp|telnet|mailto):/;

############ Encodings ###############

our $encoding;

# Wikipedia Windows-1252: "Most modern web browsers and e-mail clients
# treat the MIME charset ISO-8859-1 as Windows-1252 to accommodate such
# mislabeling. This is now standard behavior in the draft HTML 5
# specification, which requires that documents advertised as ISO-8859-1
# actually be parsed with the Windows-1252 encoding"

sub site_encoding {
    unless ($encoding) {
        $encoding =
          Encode::resolve_alias( $Foswiki::cfg{Site}{CharSet} || 'iso-8859-1' );

        $encoding = 'windows-1252' if $encoding =~ /^iso-8859-1$/i;
    }
    return $encoding;
}

our $siteCharsetRepresentable;

# Convert characters (unicode codepoints) that cannot be represented in
# the site charset to entities. Prefer named entities to numeric entities.
sub convertNotRepresentabletoEntity {
    if ( WC::site_encoding() =~ /^utf-?8/ ) {

        # UTF-8 can represent all characters, so no entities needed
    }
    else {
        unless ($siteCharsetRepresentable) {

            # Produce a string of unicode characters that contains
            # all of the characters representable in the site charset.
            # It's assumed that this is an 8-bit charset so only the
            # codepoints 0..255 are considered.
            $siteCharsetRepresentable = '';
            for my $code ( 0 .. 255 ) {
                eval {
                    my $unicodeChar =
                      Encode::decode( WC::site_encoding(), chr($code),
                        Encode::FB_CROAK );

                    # Escape codes in the standard ASCII range, as necessary,
                    # to avoid special interpretation by perl
                    $unicodeChar = quotemeta($unicodeChar)
                      if ord($unicodeChar) <= 127;

                    $siteCharsetRepresentable .= $unicodeChar;
                };

                # otherwise ignore
            }
        }

        $_[0] =
          HTML::Entities::encode_entities( $_[0],
            "^$siteCharsetRepresentable" );

        # All characters that cannot be represented in the site
        # charset are now encoded as entities
        # Named entities are used if available, otherwise numeric
        # entities, because named entities produce more readable TML
    }
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2014 Foswiki Contributors. Foswiki Contributors
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
