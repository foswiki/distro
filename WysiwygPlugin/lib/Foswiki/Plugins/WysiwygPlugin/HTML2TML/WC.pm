# See bottom of file for license and copyright information
package Foswiki::Plugins::WysiwygPlugin::HTML2TML::WC;

# VERY IMPORTANT: ALL STRINGS STORED IN NODES ARE UNICODE
# (perl character strings)
#
#
# Note on constants: most string constants are not declared 'use constant'
# because they are widely used in string interpolations. There is no value
# in 'use constant' for non-scalar values as perl does not inline them.

use strict;
use warnings;

use Foswiki::Plugins::WysiwygPlugin::Constants ();
use HTML::Entities;

sub test_reset {
    Foswiki::Plugins::WysiwygPlugin::Constants::test_reset;
    $WC::representable_entities = undef;
    $WC::encoded_nbsp           = undef;
    $WC::safe_entities          = undef;
}

=pod

---+ package Foswiki::Plugins::WysiwygPlugin::HTML2TML::WC a.k.a WC

Extend Foswiki::Plugins::WysiwygPlugin::Constants with
constants specific to HTML2TML

=cut

package WC;

use Assert;

=pod

---++ Generator flags
| NO_TML | Flag that gets passed _down_ into generator functions. Constrains output to HTML only. |
| NO_BLOCK_TML | Flag that gets passed _down_ into generator functions. Don't generate block TML e.g. tables, lists |
| NOP_ALL | Flag that gets passed _down_ into generator functions. NOP all variables and WikiWords. |
| BLOCK_TML | Flag passed up from generator functions; set if expansion includes block TML |
| VERY_CLEAN | Flag passed to indicate that HTML must be aggressively cleaned (unrecognised or unuseful tags stripped out) |
| BR2NL | Flag set to force BR tags to be converted to newlines. |
| KEEP_WS | Set to force the generator to keep all whitespace. Otherwise whitespace gets collapsed (as it is when HTML is rendered) |
| PROTECTED | In a block marked as PROTECTED |
| KEEP_ENTITIES | Don't decode HTML entities |

=cut

use constant {
    NO_HTML       => 1 << 0,
    NO_TML        => 1 << 1,
    NO_BLOCK_TML  => 1 << 2,
    NOP_ALL       => 1 << 3,
    VERY_CLEAN    => 1 << 4,
    BR2NL         => 1 << 5,
    KEEP_WS       => 1 << 6,
    PROTECTED     => 1 << 7,
    KEEP_ENTITIES => 1 << 8,
    IN_TABLE      => 1 << 9
};

use constant BLOCK_TML => NO_BLOCK_TML;

my %specials = (
    'NBSP'   => 14,    # unbreakable space
    'NBBR'   => 15,    # para break required
    'CHECKn' => 16,    # require adjacent newline (\n or $NBBR)
    'CHECKs' => 17,    # require adjacent space character (' ' or $NBSP)
    'CHECKw' => 18,    # require adjacent whitespace (\s|$NBBR|$NBSP)
    'CHECK1' => 19,    # start of wiki-word
    'CHECK2' => 20,    # end of wiki-word
    'TAB'    => 21,    # list indent
    'PON'    => 22,    # protect on
    'POFF'   => 23,    # protect off
);

=pod

---++ Forced whitespace
These single-character shortcuts are used to assert the presence of
non-breaking whitespace.

| $NBSP | Non-breaking space |
| $NBBR | Non-breaking linebreak |

=cut

our $NBSP = chr( $specials{NBSP} );
our $NBBR = chr( $specials{NBBR} );

=pod

---++ Inline Assertions
The generator works by expanding to "decorated" text, where the decorators
are characters below ' '. These characters act to express format
requirements - for example, the need to have a newline before some text,
or the need for a space. The generator sticks this format requirements into
the text stream, and they are then optimised down to the minimum in a post-
process.

| $CHECKn | there must be an adjacent newline (\n or $NBBR) |
| $CHECKs | there must be an adjacent space (' ' or $NBSP) |
| $CHECKw | There must be adjacent whitespace (\s or $NBBR or $NBSP) |
| $CHECK1 | Marks the start of an inline wikiword. |
| $CHECK2 | Marks the end of an inline wikiword. |
| $TAB    | Shorthand for an indent level in a list |

=cut

our $CHECKn   = chr( $specials{CHECKn} );
our $CHECKs   = chr( $specials{CHECKs} );
our $CHECKw   = chr( $specials{CHECKw} );
our $CHECK1   = chr( $specials{CHECK1} );
our $CHECK2   = chr( $specials{CHECK2} );
our $TAB      = chr( $specials{TAB} );
our $PON      = chr( $specials{PON} );
our $POFF     = chr( $specials{POFF} );
our $WS_NOTAB = qr/[$NBSP$NBBR$CHECKn$CHECKs$CHECKw$CHECK1$CHECK2\s]*/;
our $WS       = qr/[$NBSP$NBBR$CHECKn$CHECKs$CHECKw$CHECK1$CHECK2$TAB\s]*/;

# HTML elements that are strictly block type, as defined by
# http://www.htmlhelp.com/reference/html40/block.html.
# Block type elements do not require
# <br /> to be generated for newlines on the boundary - see WC::isInline.
our %ALWAYS_BLOCK = (
    address    => 1,
    blockquote => 1,
    center     => 1,
    dir        => 1,
    div        => 1,
    dl         => 1,
    fieldset   => 1,
    form       => 1,
    h1         => 1,
    h2         => 1,
    h3         => 1,
    h4         => 1,
    h5         => 1,
    h6         => 1,
    hr         => 1,
    isindex    => 1,
    menu       => 1,
    noframes   => 1,
    noscript   => 1,
    ol         => 1,
    p          => 1,
    pre        => 1,
    table      => 1,
    ul         => 1
);

# Colours with colour settings in DefaultPreferences.
our @TML_COLOURS = (
    'BLACK',  'MAROON', 'PURPLE', 'PINK',       'RED',   'ORANGE',
    'YELLOW', 'LIME',   'AQUA',   'AQUAMARINE', 'GREEN', 'OLIVE',
    'BROWN',  'NAVY',   'TEAL',   'BLUE',       'GRAY',  'SILVER',
    'WHITE',
);

# Map of possible colours back to TML %COLOUR%...%ENDCOLOR%
our %HTML2TML_COLOURMAP = (
    BLACK      => 'BLACK',
    '#000000'  => 'BLACK',
    MAROON     => 'MAROON',
    '#800000'  => 'MAROON',
    PURPLE     => 'PURPLE',
    '#800080'  => 'PURPLE',
    FUCHSIA    => 'PINK',
    '#FF00FF'  => 'PINK',
    RED        => 'RED',
    '#FF0000'  => 'RED',
    ORANGE     => 'ORANGE',
    '#FF6600'  => 'ORANGE',
    YELLOW     => 'YELLOW',
    '#FFFF00'  => 'YELLOW',
    LIME       => 'LIME',
    '#00FF00'  => 'LIME',
    AQUA       => 'AQUA',
    AQUAMARINE => 'AQUA',
    '#00FFFF'  => 'AQUA',
    GREEN      => 'GREEN',
    '#008000'  => 'GREEN',
    OLIVE      => 'OLIVE',
    '#808000'  => 'OLIVE',
    BROWN      => 'BROWN',
    '#996633'  => 'BROWN',
    NAVY       => 'NAVY',
    '#000080'  => 'NAVY',
    TEAL       => 'TEAL',
    '#008080'  => 'TEAL',
    BLUE       => 'BLUE',
    '#0000FF'  => 'BLUE',
    GRAY       => 'GRAY',
    '#808080'  => 'GRAY',
    SILVER     => 'SILVER',
    '#C0C0C0'  => 'SILVER',
    WHITE      => 'WHITE',
    '#FFFFFF'  => 'WHITE',
);

# Genuine HTML colors as follows:
# '#4682B4' => 'steelblue',
# '#041690' => 'royalblue',
# '#6495ED' => 'cornflowerblue',
# '#B0C4DE' => 'lightsteelblue',
# '#7B68EE' => 'mediumslateblue',
# '#6A5ACD' => 'slateblue',
# '#483D8B' => 'darkslateblue',
# '#191970' => 'midnightblue',
# '#000080' => 'navy',
# '#00008B' => 'darkblue',
# '#0000CD' => 'mediumblue',
# '#0000FF' => 'blue',
# '#1E90FF' => 'dodgerblue',
# '#00BFFF' => 'deepskyblue',
# '#87CEFA' => 'lightskyblue',
# '#87CEEB' => 'skyblue',
# '#ADD8E6' => 'lightblue',
# '#B0E0E6' => 'powderblue',
# '#F0FFFF' => 'azure',
# '#E0FFFF' => 'lightcyan',
# '#AFEEEE' => 'paleturquoise',
# '#48D1CC' => 'mediumturquoise',
# '#20B2AA' => 'lightseagreen',
# '#008B8B' => 'darkcyan',
# '#008080' => 'teal',
# '#5F9EA0' => 'cadetblue',
# '#00CED1' => 'darkturquoise',
# '#00FFFF' => 'aqua',
# '#00FFFF' => 'cyan',
# '#40E0D0' => 'turquoise',
# '#7FFFD4' => 'aquamarine',
# '#66CDAA' => 'mediumaquamarine',
# '#8FBC8F' => 'darkseagreen',
# '#3CB371' => 'mediumseagreen',
# '#2E8B57' => 'seagreen',
# '#006400' => 'darkgreen',
# '#008000' => 'green',
# '#228B22' => 'forestgreen',
# '#32CD32' => 'limegreen',
# '#00FF00' => 'lime',
# '#7FFF00' => 'chartreuse',
# '#7CFC00' => 'lawngreen',
# '#ADFF2F' => 'greenyellow',
# '#9ACD32' => 'yellowgreen',
# '#98FB98' => 'palegreen',
# '#90EE90' => 'lightgreen',
# '#00FF7F' => 'springgreen',
# '#00FA9A' => 'mediumspringgreen',
# '#556B2F' => 'darkolivegreen',
# '#6B8E23' => 'olivedrab',
# '#808000' => 'olive',
# '#BDB76B' => 'darkkhaki',
# '#B8860B' => 'darkgoldenrod',
# '#DAA520' => 'goldenrod',
# '#FFD700' => 'gold',
# '#FFFF00' => 'yellow',
# '#F0E68C' => 'khaki',
# '#EEE8AA' => 'palegoldenrod',
# '#FFEBCD' => 'blanchedalmond',
# '#FFE4B5' => 'moccasin',
# '#F5DEB3' => 'wheat',
# '#FFDEAD' => 'navajowhite',
# '#DEB887' => 'burlywood',
# '#D2B48C' => 'tan',
# '#BC8F8F' => 'rosybrown',
# '#A0522D' => 'sienna',
# '#8B4513' => 'saddlebrown',
# '#D2691E' => 'chocolate',
# '#CD853F' => 'peru',
# '#F4A460' => 'sandybrown',
# '#8B0000' => 'darkred',
# '#800000' => 'maroon',
# '#A52A2A' => 'brown',
# '#B22222' => 'firebrick',
# '#CD5C5C' => 'indianred',
# '#F08080' => 'lightcoral',
# '#FA8072' => 'salmon',
# '#E9967A' => 'darksalmon',
# '#FFA07A' => 'lightsalmon',
# '#FF7F50' => 'coral',
# '#FF6347' => 'tomato',
# '#FF8C00' => 'darkorange',
# '#FFA500' => 'orange',
# '#FF4500' => 'orangered',
# '#DC143C' => 'crimson',
# '#FF0000' => 'red',
# '#FF1493' => 'deeppink',
# '#FF00FF' => 'fuchsia',
# '#FF00FF' => 'magenta',
# '#FF69B4' => 'hotpink',
# '#FFB6C1' => 'lightpink',
# '#FFC0CB' => 'pink',
# '#DB7093' => 'palevioletred',
# '#C71585' => 'mediumvioletred',
# '#800080' => 'purple',
# '#8B008B' => 'darkmagenta',
# '#9370DB' => 'mediumpurple',
# '#8A2BE2' => 'blueviolet',
# '#4B0082' => 'indigo',
# '#9400D3' => 'darkviolet',
# '#9932CC' => 'darkorchid',
# '#BA55D3' => 'mediumorchid',
# '#DA70D6' => 'orchid',
# '#EE82EE' => 'violet',
# '#DDA0DD' => 'plum',
# '#D8BFD8' => 'thistle',
# '#E6E6FA' => 'lavender',
# '#F8F8FF' => 'ghostwhite',
# '#F0F8FF' => 'aliceblue',
# '#F5FFFA' => 'mintcream',
# '#F0FFF0' => 'honeydew',
# '#FAFAD2' => 'lightgoldenrodyellow',
# '#FFFACD' => 'lemonchiffon',
# '#FFF8DC' => 'cornsilk',
# '#FFFFE0' => 'lightyellow',
# '#FFFFF0' => 'ivory',
# '#FFFAF0' => 'floralwhite',
# '#FAF0E6' => 'linen',
# '#FDF5E6' => 'oldlace',
# '#FAEBD7' => 'antiquewhite',
# '#FFE4C4' => 'bisque',
# '#FFDAB9' => 'peachpuff',
# '#FFEFD5' => 'papayawhip',
# '#F5F5DC' => 'beige',
# '#FFF5EE' => 'seashell',
# '#FFF0F5' => 'lavenderblush',
# '#FFE4E1' => 'mistyrose',
# '#FFFAFA' => 'snow',
# '#FFFFFF' => 'white',
# '#F5F5F5' => 'whitesmoke',
# '#DCDCDC' => 'gainsboro',
# '#D3D3D3' => 'lightgrey',

# Maps of tag types
our %SELF_CLOSING = ( img => 1, br => 1 );

# Map that specifies tags to be renamed to a canonical name
our %EMPH_TAG = (
    b      => 'strong',
    i      => 'em',
    tt     => 'code',
    strong => 'strong',
    em     => 'em',
    code   => 'code',
);

# Named entities that we want to convert back to characters, rather
# than leaving them as HTML entities.
our @SAFE_ENTITIES = (
    qw(
      euro   iexcl  cent   pound  curren yen    brvbar sect
      uml    copy   ordf   laquo  not    shy    reg    macr
      deg    plusmn sup2   sup3   acute  micro  para   middot
      cedil  sup1   ordm   raquo  frac14 frac12 frac34 iquest
      Agrave Aacute Acirc  Atilde Auml   Aring  AElig  Ccedil
      Egrave Eacute Ecirc  Euml   Igrave Iacute Icirc  Iuml
      ETH    Ntilde Ograve Oacute Ocirc  Otilde Ouml   times
      Oslash Ugrave Uacute Ucirc  Uuml   Yacute THORN  szlig
      agrave aacute acirc  atilde auml   aring  aelig  ccedil
      egrave eacute ecirc  euml   igrave iacute icirc  iuml
      eth    ntilde ograve oacute ocirc  otilde ouml   divide
      oslash ugrave uacute ucirc  uuml   yacute thorn  yuml
      )
);

# Get a hash that maps the safe entities values to unicode characters
our $safe_entities;

sub safeEntities {
    unless ( defined $safe_entities ) {
        foreach my $entity (@SAFE_ENTITIES) {

            # Decode the entity name to unicode
            my $unicode = HTML::Entities::decode_entities("&$entity;");

            $safe_entities->{$entity} = $unicode;
        }
    }
    return $safe_entities;
}

our $encoded_nbsp;

# Given a unicode string, decode all entities in it that can be mapped
# to the current site encoding
sub decodeRepresentableEntities {

    # Expand entities
    HTML::Entities::decode_entities( $_[0] );

    unless ( defined $encoded_nbsp ) {
        $encoded_nbsp = '&nbsp;';
        HTML::Entities::decode_entities($encoded_nbsp);
        ASSERT( $encoded_nbsp ne '&nbsp;' ) if DEBUG;
    }

    # Replace expansion of &nbsp; with $WC::NBSP
    $_[0] =~ s/$encoded_nbsp/$WC::NBSP/g;
}

# DEBUG

# Encode any unprintable character in the string using #decimal;
sub encode_oddchars {
    my $text = shift;
    my $s    = "";
    for ( my $i = 0 ; $i < length($text) ; $i++ ) {
        my $ch = substr( $text, $i, 1 );
        if ( ord($ch) < 32 || ord($ch) > 127 ) {
            $s = $s . '#' . ord($ch) . ';';
        }
        else {
            $s .= $ch;
        }
    }
    return $s;
}

# Given a string that may contain special control characters, encode
# those characters using a leading % e.g. chr(14) -> %NBSP
sub encode_specials {
    my $string = shift;
    while ( my ( $k, $v ) = each %specials ) {
        my $c = chr($v);
        $string =~ s/$c/\%$k/g;
    }

    # Sweep up other unprintable chars
    return encode_oddchars($string);
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2015 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2005 ILOG http://www.ilog.fr

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
