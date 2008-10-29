#package TWiki::Plugins::WysiwygPlugin::Constants;
# Use s simpler-named namespace for constants to improve code readability
package WC;

use strict;

our (%ALWAYS_BLOCK, $ALWAYS_BLOCK_S, $STARTWW, $ENDWW, $PROTOCOL);

# HTML elements that are strictly block type, as defined by
# http://www.htmlhelp.com/reference/html40/block.html.
# Block type elements do not require
# <br /> to be generated for newlines on the boundary - see WC::isInline.
%ALWAYS_BLOCK = map { $_ => 1 }
  qw( ADDRESS BLOCKQUOTE CENTER DIR DIV DL FIELDSET FORM H1 H2 H3 H4 H5 H6
      HR ISINDEX MENU NOFRAMES NOSCRIPT OL P PRE TABLE UL );
$ALWAYS_BLOCK_S = join('|', keys %ALWAYS_BLOCK);

$STARTWW  = qr/^|(?<=[ \t\n\(\!])/om;
$ENDWW    = qr/$|(?=[ \t\n\,\.\;\:\!\?\)])/om;
$PROTOCOL = qr/^(file|ftp|gopher|https?|irc|news|nntp|telnet|mailto):/;

our (%KNOWN_COLOUR);

# Colours with colour settings in TWikiPreferences. WTF does TWiki see
# fit to *redefine* the standard colors? e.g. ORANGE below is *not* orange.
# For goodness sakes!
%KNOWN_COLOUR = (
    BLACK => 'BLACK',
    '#000000' => 'BLACK',
    MAROON => 'MAROON',
    '#800000' => 'MAROON',
    PURPLE => 'PURPLE',
    '#800080' => 'PURPLE',
    PINK => 'PINK',
    '#FF00FF' => 'PINK',
    RED => 'RED',
    '#FF0000' => 'RED',
    ORANGE => 'ORANGE',
    '#FF6600' => 'ORANGE',
    '#FFA500' => 'ORANGE', # HTML standard
    YELLOW => 'YELLOW',
    '#FFFF00' => 'YELLOW',
    LIME => 'LIME',
    '#00FF00' => 'LIME',
    AQUA => 'AQUA',
    AQUAMARINE => 'AQUA',
    '#00FFFF' => 'AQUA',
    GREEN => 'GREEN',
    '#008000' => 'GREEN',
    OLIVE => 'OLIVE',
    '#808000' => 'OLIVE',
    BROWN => 'BROWN',
    '#996633' => 'BROWN',
    '#A52A2A' => 'BROWN', # HTML standard
    NAVY => 'NAVY',
    '#000080' => 'NAVY',
    TEAL => 'TEAL',
    '#008080' => 'TEAL',
    BLUE => 'BLUE',
    '#0000FF' => 'BLUE',
    GRAY => 'GRAY',
    '#808080' => 'GRAY',
    SILVER => 'SILVER',
    '#C0C0C0' => 'SILVER',
    WHITE => 'WHITE',
    '#FFFFFF' => 'WHITE',
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

# Mapping high-bit characters from unicode back to iso-8859-1
# (a.k.a Windows 1252 a.k.a "ANSI") - http://www.alanwood.net/demos/ansi.html
our %unicode2HighBit = (
	chr(8364) => chr(128),	chr(8218) => chr(130),  chr(402)  => chr(131),
	chr(8222) => chr(132),	chr(8230) => chr(133),	chr(8224) => chr(134),
	chr(8225) => chr(135),  chr(710)  => chr(136),	chr(8240) => chr(137),
    chr(352)  => chr(138),	chr(8249) => chr(139),  chr(338)  => chr(140),
    chr(381)  => chr(142),	chr(8216) => chr(145),	chr(8217) => chr(146),
	chr(8220) => chr(147),	chr(8221) => chr(148),	chr(8226) => chr(149),
	chr(8211) => chr(150),	chr(8212) => chr(151),  chr(732)  => chr(152),
	chr(8482) => chr(153),  chr(353)  => chr(154),	chr(8250) => chr(155),
    chr(339)  => chr(156),  chr(382)  => chr(158),  chr(376)  => chr(159),
);

# Reverse mapping
our %highBit2Unicode = map { $unicode2HighBit{$_} => $_ } keys %unicode2HighBit;

our $unicode2HighBitChars = join('', keys %unicode2HighBit);
our $highBit2UnicodeChars = join('', keys %highBit2Unicode);
our $encoding;

sub encoding {
    unless ($encoding) {
        $encoding = Encode::resolve_alias(
            $TWiki::cfg{Site}{CharSet} || 'iso-8859-1');
    }
    return $encoding;
}

# Map selected unicode characters back to high-bit chars if
# iso-8859-1 is selected. This is required because the same characters
# have different code points in unicode and iso-8859-1. For example,
# &euro; is 128 in iso-8859-1 and 8364 in unicode.
sub mapUnicode2HighBit {
    if (encoding() eq 'iso-8859-1') {
        # Map unicode back to iso-8859 high-bit chars
        $_[0] =~ s/([$unicode2HighBitChars])/$unicode2HighBit{$1}/ge;
    }
}

# Map selected high-bit chars to unicode if
# iso-8859-1 is selected.
sub mapHighBit2Unicode {
    if (encoding() eq 'iso-8859-1') {
        # Map unicode back to iso-8859 high-bit chars
        $_[0] =~ s/([$highBit2UnicodeChars])/$highBit2Unicode{$1}/ge;
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
    egrave eacute ecirc  uml    igrave iacute icirc  iuml
    eth    ntilde ograve oacute ocirc  otilde ouml   divide
    oslash ugrave uacute ucirc  uuml   yacute thorn  yuml
);

# Mapping from entity names to characters
our $safe_entities;

# Get a hash that maps the safe entities values to characters
# in the site charset.
sub safeEntities {
    unless ($safe_entities) {
        foreach my $entity (@safeEntities) {
            # Decode the entity name to unicode
            my $unicode = HTML::Entities::decode_entities("&$entity;");
            # Map unicode back to iso-8859 high-bit chars if required
            mapUnicode2HighBit($unicode);
            $safe_entities->{$entity} = Encode::encode(encoding(), $unicode);
        }
    }
    return $safe_entities;
}

# Debug
sub chCodes {
    my $text = shift;
    my $s = "";
    for (my $i = 0; $i < length($text); $i++) {
        my $ch = substr($text, $i, 1);
        if (ord($ch) < 32 || ord($ch) > 127) {
            $s = $s . '#' . ord($ch) . ';';
        } else {
            $s .= $ch;
        }
    }
    return $s;
}

1;
