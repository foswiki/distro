# See bottom of file for license and copyright information
package Foswiki::Plugins::WysiwygPlugin::Constants;

use strict;
use warnings;

use Encode;

# HTML elements that are strictly block type, as defined by
# http://www.htmlhelp.com/reference/html40/block.html.
# Block type elements do not require
# <br /> to be generated for newlines on the boundary - see WC::isInline.
our %ALWAYS_BLOCK = map { $_ => 1 }
  qw( ADDRESS BLOCKQUOTE CENTER DIR DIV DL FIELDSET FORM H1 H2 H3 H4 H5 H6
  HR ISINDEX MENU NOFRAMES NOSCRIPT OL P PRE TABLE UL );
our $ALWAYS_BLOCK_S = join( '|', keys %ALWAYS_BLOCK );

our $STARTWW  = qr/^|(?<=[ \t\n\(\!])|(?<=<p>)|(?<= <\/span>)/om;
our $ENDWW    = qr/$|(?=[ \t\n\,\.\;\:\!\?\)])|(?=<\/p>)|(?=<span\b[^>]*> )/om;
our $PROTOCOL = qr/^(file|ftp|gopher|https?|irc|news|nntp|telnet|mailto):/;

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

############ Encodings ###############

our $encoding;

sub encoding {
    unless ($encoding) {
        $encoding =
          Encode::resolve_alias( $Foswiki::cfg{Site}{CharSet} || 'iso-8859-1' );

        $encoding = 'windows-1252' if $encoding =~ /^iso-8859-1$/i;
    }
    return $encoding;
}

my $siteCharsetRepresentable;

# Convert characters (unicode codepoints) that cannot be represented in
# the site charset to entities. Prefer named entities to numeric entities.
sub convertNotRepresentabletoEntity {
    if ( encoding() =~ /^utf-?8/ ) {

        # UTF-8 can represent all characters, so no entities needed
    }
    else {
        unless ($siteCharsetRepresentable) {

            # Produce a string of unicode characters that contains all of the
            # characters representable in the site charset
            $siteCharsetRepresentable = '';
            for my $code ( 0 .. 255 ) {
                my $unicodeChar =
                  Encode::decode( encoding(), chr($code), Encode::FB_PERLQQ );
                if ( $unicodeChar =~ /^\\x/ ) {

                    # code is not valid, so skip it
                }
                else {

                    # Escape codes in the standard ASCII range, as necessary,
                    # to avoid special interpretation by perl
                    $unicodeChar = quotemeta($unicodeChar)
                      if ord($unicodeChar) <= 127;

                    $siteCharsetRepresentable .= $unicodeChar;
                }
            }
        }

        require HTML::Entities;
        $_[0] =
          HTML::Entities::encode_entities( $_[0],
            "^$siteCharsetRepresentable" );

# All characters that cannot be represented in the site charset are now encoded as entities
# Named entities are used if available, otherwise numeric entities,
# because named entities produce more readable TML
    }
}

# Named entities that we want to convert back to characters, rather
# than leaving them as HTML entities.
our @safeEntities = qw(
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
);

# Mapping from entity names to characters
our $safe_entities;

# Get a hash that maps the safe entities values to unicode characters
sub safeEntities {
    unless ($safe_entities) {
        foreach my $entity (@safeEntities) {

            # Decode the entity name to unicode
            my $unicode = HTML::Entities::decode_entities("&$entity;");

            $safe_entities->{"$entity"} = $unicode;
        }
    }
    return $safe_entities;
}

# Debug
sub chCodes {
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

# Allow the unit tests to force re-initialisation of
# %Foswiki::cfg-dependent cached data
sub reinitialiseForTesting {
    undef $encoding;
    undef $siteCharsetRepresentable;
}

# Create shorter alias for other modules
no strict 'refs';
*{'WC::'} = \*{'Foswiki::Plugins::WysiwygPlugin::Constants::'};

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
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
