# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2004 Crawford Currie, http://c-dot.co.uk
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at 
# http://www.gnu.org/copyleft/gpl.html
#
package Foswiki::Plugins::TestFixturePlugin::CleanHTML;

use HTML::Parser;

@Foswiki::Plugins::TestFixturePlugin::CleanHTML::ISA = ( 'HTML::Parser' );

my %entMap =
  (
      nbsp=>160, iexcl=>161, cent=>162, pound=>163, curren=>164, yen=>165,
      brvbar=>166, sect=>167, uml=>168, copy=>169, ordf=>170, laquo=>171,
      not=>172, shy=>173, reg=>174, macr=>175, deg=>176, plusmn=>177,
      sup2=>178, sup3=>179, acute=>180, micro=>181, para=>182, middot=>183,
      cedil=>184, sup1=>185, ordm=>186, raquo=>187, frac14=>188,
      frac12=>189, frac34=>190, iquest=>191, Agrave=>192, Aacute=>193,
      Acirc=>194, Atilde=>195, Auml=>196, Aring=>197, AElig=>198,
      Ccedil=>199, Egrave=>200, Eacute=>201, Ecirc=>202, Euml=>203,
      Igrave=>204, Iacute=>205, Icirc=>206, Iuml=>207, ETH=>208,
      Ntilde=>209, Ograve=>210, Oacute=>211, Ocirc=>212, Otilde=>213,
      Ouml=>214, times=>215, Oslash=>216, Ugrave=>217, Uacute=>218,
      Ucirc=>219, Uuml=>220, Yacute=>221, THORN=>222, szlig=>223,
      agrave=>224, aacute=>225, acirc=>226, atilde=>227, auml=>228,
      aring=>229, aelig=>230, ccedil=>231, egrave=>232, eacute=>233,
      ecirc=>234, euml=>235, igrave=>236, iacute=>237, icirc=>238,
      iuml=>239, eth=>240, ntilde=>241, ograve=>242, oacute=>243,
      ocirc=>244, otilde=>245, ouml=>246, divide=>247, oslash=>248,
      ugrave=>249, uacute=>250, ucirc=>251, uuml=>252, yacute=>253,
      thorn=>254, yuml=>255, fnof=>402, Alpha=>913, Beta=>914, Gamma=>915,
      Delta=>916, Epsilon=>917, Zeta=>918, Eta=>919, Theta=>920, Iota=>921,
      Kappa=>922, Lambda=>923, Mu=>924, Nu=>925, Xi=>926, Omicron=>927,
      Pi=>928, Rho=>929, Sigma=>931, Tau=>932, Upsilon=>933, Phi=>934,
      Chi=>935, Psi=>936, Omega=>937, alpha=>945, beta=>946, gamma=>947,
      delta=>948, epsilon=>949, zeta=>950, eta=>951, theta=>952, iota=>953,
      kappa=>954, lambda=>955, mu=>956, nu=>957, xi=>958, omicron=>959,
      pi=>960, rho=>961, sigmaf=>962, sigma=>963, tau=>964, upsilon=>965,
      phi=>966, chi=>967, psi=>968, omega=>969, thetasym=>977, upsih=>978,
      piv=>982, bull=>8226, hellip=>8230, prime=>8242, Prime=>8243,
      oline=>8254, frasl=>8260, weierp=>8472, image=>8465, real=>8476,
      trade=>8482, alefsym=>8501, larr=>8592, uarr=>8593, rarr=>8594,
      darr=>8595, harr=>8596, crarr=>8629, lArr=>8656, uArr=>8657,
      rArr=>8658, dArr=>8659, hArr=>8660, forall=>8704, part=>8706,
      exist=>8707, empty=>8709, nabla=>8711, isin=>8712, notin=>8713,
      ni=>8715, prod=>8719, sum=>8721, minus=>8722, lowast=>8727,
      radic=>8730, prop=>8733, infin=>8734, ang=>8736, and=>8743, or=>8744,
      cap=>8745, cup=>8746, int=>8747, there4=>8756, sim=>8764, cong=>8773,
      asymp=>8776, ne=>8800, equiv=>8801, le=>8804, ge=>8805, sub=>8834,
      sup=>8835, nsub=>8836, sube=>8838, supe=>8839, oplus=>8853,
      otimes=>8855, perp=>8869, sdot=>8901, lceil=>8968, rceil=>8969,
      lfloor=>8970, rfloor=>8971, lang=>9001, rang=>9002, loz=>9674,
      spades=>9824, clubs=>9827, hearts=>9829, diams=>9830, quot=>34,
      amp=>38, lt=>60, gt=>62, OElig=>338, oelig=>339, Scaron=>352,
      scaron=>353, Yuml=>376, circ=>710, tilde=>732, ensp=>8194,
      emsp=>8195, thinsp=>8201, zwnj=>8204, zwj=>8205, lrm=>8206,
      rlm=>8207, ndash=>8211, mdash=>8212, lsquo=>8216, rsquo=>8217,
      sbquo=>8218, ldquo=>8220, rdquo=>8221, bdquo=>8222, dagger=>8224,
      Dagger=>8225, permil=>8240, lsaquo=>8249, rsaquo=>8250, euro=>8364,
  );

sub new {
    my( $class ) = @_;

    my $this = new HTML::Parser( start_h => [\&_openTag, 'self,tagname,attr' ],
                                 end_h => [\&_closeTag, 'self,tagname'],
                                 default_h => [\&_text, 'self,text,is_cdata']);

    $this->xml_mode( 1 );
    $this->unbroken_text( 1 );

    return bless( $this, $class );
}

sub convert {
    my( $this, $text ) = @_;

    $this->{items} = ();
    $this->{last_was_text} = 0;
    $this->parse( $text );
    $this->eof();
    return \@{$this->{items}};
}

sub _openTag {
    my( $this, $tag, $attrs ) = @_;
    my $a = join(' ', map { $_.'='.$attrs->{$_} } sort keys %$attrs);
    $a = ' '.$a if $a =~ /\S/;
    $this->{last_was_text} = 0;
    push( @{$this->{items}}, '<'.$tag.$a.'>' );
}

sub _closeTag {
    my( $this, $tag ) = @_;

    $this->{last_was_text} = 0;
    push( @{$this->{items}}, '</'.$tag.'>' );
}

sub _text {
    my( $this, $text, $cdata ) = @_;
    my $sep = '';

    unless( $is_cdata ) {
        $text =~ s/^\s*(.*?)\s*$/$1/;
        $text =~ s/\s+/ /g;
        # normalise entities
        $text =~ s/&(\w+);/&#$entMap{$1};/g;
        return unless $text =~ /\S/;
        $sep = ' ';
    }

    if( $this->{last_was_text} ) {
        push(@{$this->{items}}, pop(@{$this->{items}}).$sep.$text );
    } else {
        push( @{$this->{items}}, $text );
    }
    $this->{last_was_text} = 1;
}

package Foswiki::Plugins::TestFixturePlugin::HTMLDiffer;

# Module for comparing two blocks of HTML to see if
# they would render to the same thing.

use Algorithm::Diff;

my $cleaner = new Foswiki::Plugins::TestFixturePlugin::CleanHTML();

sub _tidy {
    my $a = shift;
    $a =~ s/&/&amp;/g;
    $a =~ s/</&lt;/g;
    $a =~ s/>/&gt;/g;
    return $a;
}

sub _rexeq {
    my ( $a, $b ) = @_;
    my @res = ();
    while ( $a =~ s/\@REX\((.*?)\)/"RRRREX".scalar(@res)."XERRRR"/e ) {
        push( @res, $1 );
    }
    # escape regular expression chars
    $a = quotemeta($a);
    $a =~ s/\\\@DATE/[0-3]\\d [JFMASOND][aepuco][nbrylgptvc] [12][09]\\d\\d/g;
    $a =~ s/\\\@TIME/[012]\\d:[0-5]\\d/g;
    my $wikiword = '[A-Z]+[a-z]+[A-Z]+\w+';
    $a =~ s/\\\@WIKIWORD/$wikiword/g;
    $a =~ s/\\\@URLPARAMS/[A-Za-z0-9=%;]*/g;
    my $satWord = '<a [^>]*class="twikiLink"[^>]*>'.$wikiword.'</a>';
    my $unsatWord = '<span [^>]*class="foswikiNewLink"[^>]*>'.$wikiword.'<a [^>]*><sup>\?</sup></a
</span>';
    $a =~ s/RRRREX(\d+)XERRRR/$res[$1]/g;
    $a =~ s!/!\/!g;
    return $b =~ /^$a$/;
}

sub diff {
    my ( $expected, $actual, $opts ) = @_;
    my $failed = 0;
    my $rex = ( $opts->{options} =~ /\brex\b/ );
    my $okset = "";
    my $reporter = $opts->{reporter};

    my $e = $cleaner->convert( $expected );
    my $a = $cleaner->convert( $actual );
    my $diffs = Algorithm::Diff::sdiff( $e, $a );
    foreach my $diff ( @$diffs ) {
        my $a = $diff->[1] || '';
        $a =~ s/^\s+//;
        $a =~ s/\s+$//s;
        my $b = $diff->[2] || '';
        $b =~ s/^\s+//;
        $b =~ s/\s+$//s;
        my $ok = 0;

        if ( $diff->[0] eq 'u' || $a eq $b ||
            $rex && _rexeq( $a, $b )) {
            $ok = 1;
        }
        $a = _tidy( $a );
        $b = _tidy( $b );
        if ( $ok ) {
            $okset .= $a.' ';
        } else {
            if( $okset ) {
                if( $reporter) {
                    &$reporter(1, $okset, undef, $opts);
                }
                $okset = "";
            }
            if( $reporter ) {
                &$reporter(0, $a, $b, $opts);
            }
            $failed = 1;
        }
    }
    return '' unless $failed;
    if( $okset && $reporter ) {
        &$reporter(1, $okset, undef, $opts);
    }
    return $failed;
}

sub defaultReporter {
    my($code, $a, $b, $opts) = @_;

    if( $code) {
        $opts->{result} .= $a;
    } else {
        $opts->{result} .= "\n- $a\n+ $b\n";
    }
}

sub _tagSame {
    my( $a, $b ) = @_;

    return 0 unless ($a =~ /^\s*<\/?(\w+)\s+(.*?)>\s*$/i);
    my $tag = $1;
    my $pa = $2;
    return 0 unless $b =~  /^\s*<\/?$tag\s+(.*?)>\s*$/i;
    my $pb = $1;
    return _paramsSame($pa, $pb);
}

sub _paramsSame {
    my( $a, $b) = @_;
    return 1 if ($a eq $b);
    while( $a =~ s/^\s*([a-zA-Z]+)=["'](.*?)["']// ) {
        my( $x, $y) = ($1, $2);
        $y =~ s/(\W)/\\$1/g;
        return 0 unless $b =~ s/\b${x}=["']${y}["']//;
    }
    $a =~ s/^\s*//;
    $b =~ s/^\s*//;
    return $b eq $a;
}

# escape regular expression chars in string
sub unregex {
  my ($re) = @_;
  $re =~ s/\\/\\\\/go;
  $re =~ s/\./\\./go;
  $re =~ s/\?/\\?/go;
  $re =~ s/\*/\\*/go;
  $re =~ s/\+/\\+/go;
  $re =~ s/\(/\\(/go;
  $re =~ s/\)/\\)/go;
  $re =~ s/\[/\\[/go;
  $re =~ s/\]/\\]/go;
  $re =~ s/\^/\\^/go;
  $re =~ s/\$/\\\$/go;
  $re =~ s/\@/\\\@/go;
  $re =~ s/\|/\\|/go;
  return $re;
}

my $htmltags = 
qr/A|ABBR|ACRONYM|ADDRESS|APPLET|AREA|B|BASE|BASEFONT|BDO|BIG|BLOCKQUOTE|BODY|BR|BUTTON|CAPTION|CENTER|CITE|CODE|COL|COLGROUP|DD|DEL|DFN|DIR|DIV|DL|DT|EM|FIELDSET|FONT|FORM|FRAME|FRAMESET|H1|H2|H3|H4|H5|H6|HEAD|HR|HTML|I|IFRAME|IMG|INPUT|INS|ISINDEX|KBD|LABEL|LEGEND|LI|LINK|MAP|MENU|META|NOFRAMES|NOSCRIPT|OBJECT|OL|OPTGROUP|OPTION|P|PARAM|PRE|Q|S|SAMP|SCRIPT|SELECT|SMALL|SPAN|STRIKE|STRONG|STYLE|SUB|SUP|TABLE|TBODY|TD|TEXTAREA|TFOOT|TH|THEAD|TITLE|TR|TT|U|UL|VAR/i;

# 'free' the format of html. REs can be embedded by encasing them in {* *}
sub _html2RE {
  my ($re) = @_;

  # Lift out REs protected by {* *}
  my $i = 0;
  my %prot;
  while ( $re =~ s/{\*(.*?)\*}/PROTECTED$i/) {
      $prot{$i} = $1;
      $i++;
  }
  $re = unregex($re);
  # Open tags
  $re =~ s/(<($htmltags).*?>)/&_openTag($1)/geo;

  # close tags lower case (XHTML)
  $re =~ s/(<\/$htmltags>)/&_closeTag($1)/geo;

  # Turn whitespace into \s+
  $re =~ s/\s+/\\s+/go;

  # Collapse space sequences
  $re =~ s/\\s\*\\s([*+])/\\s$1/g;
  $re =~ s/\\s([*+])\\s\*/\\s$1/g;
  $re =~ s/\\s\+\\s\+/\\s+/g;

  while ($re =~ s/PROTECTED(\d+)/$prot{$1}/g) {
  }

  return $re;
}

sub _openTag {
    my $tag = shift;

    # make open tag and param names lower case (XHTML compatibility)
    $tag =~ s/(<\w+)\b/&_lower($1)/e;
    $tag =~ s/\/>$/\\s*\/>/;
    $tag =~ s/\s([a-zA-Z]+)=/&_tagParam($1)/ge;

    return "\\s*$tag\\s*";
}

sub _closeTag {
    my $tag = lc(shift);

    return "\\s*$tag\\s*";
}

sub _tagParam {
    return lc("\\s+$_[0]\\s*=\\s*");
}

sub _lower {
    return lc($_[0]);
}

# Return true if the HTML in $a contains $e somewhere in it
sub html_matches {
  my ($e, $a ) = @_;

  my $re = _html2RE($e);
  return ($a =~ s/$re//s);
}

1;
