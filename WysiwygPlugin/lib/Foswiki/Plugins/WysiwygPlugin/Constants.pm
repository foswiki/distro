# See bottom of file for license and copyright information
package Foswiki::Plugins::WysiwygPlugin::Constants;

=pod

---+ package Foswiki::Plugins::WysiwygPlugin::Constants

Constants used throughout WysiwygPlugin

Note that constants are used 'aliased'. This is similar to Exporter,
but doesn't have Exporter's problem of importing symbols into a namespace,
which makes it very hard to track down where a symbol comes from.

=cut

sub test_reset {
    $encoding                 = undef;
    $siteCharsetRepresentable = undef;
}

package Foswiki::Plugins::WysiwygPlugin::Constants;    # Short name

use strict;
use warnings;

use Encode;
use HTML::Entities;

require Exporter;
our @ISA = qw(Exporter);

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

# Colours with colour settings in DefaultPreferences.
our @TML_COLOURS = (
    'BLACK',  'MAROON', 'PURPLE', 'PINK',       'RED',   'ORANGE',
    'YELLOW', 'LIME',   'AQUA',   'AQUAMARINE', 'GREEN', 'OLIVE',
    'BROWN',  'NAVY',   'TEAL',   'BLUE',       'GRAY',  'SILVER',
    'WHITE',
);

our @EXPORT = qw( $STARTWW $ENDWW $PROTOCOL @TML_COLOURS );

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2015 Foswiki Contributors. Foswiki Contributors
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
