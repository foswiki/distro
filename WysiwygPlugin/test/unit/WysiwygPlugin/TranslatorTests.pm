# Copyright (C) 2005 ILOG http://www.ilog.fr
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of the TWiki distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.

# tests for the two translators, TML to HTML and HTML to TML, that
# support editing using WYSIWYG HTML editors. The tests are designed
# so that the round trip can be verified in as many cases as possible.
# Readers are invited to add more testcases.
#
# The tests require TWIKI_LIBS to include a pointer to the lib
# directory of a TWiki installation, so it can pick up the bits
# of TWiki it needs to include.
#
package TranslatorTests;
use base qw(TWikiTestCase);

use strict;

require TWiki::Plugins::WysiwygPlugin;
require TWiki::Plugins::WysiwygPlugin::TML2HTML;
require TWiki::Plugins::WysiwygPlugin::HTML2TML;

# Bits for test type
                        # Fields in test records:
my $TML2HTML  = 1 << 0; # test tml => html
my $HTML2TML  = 1 << 1; # test html => finaltml (default tml)
my $ROUNDTRIP = 1 << 2; # test tml => => finaltml

# Bit mask for selected test types
my $mask = $TML2HTML | $HTML2TML | $ROUNDTRIP;

my $protecton = '<span class="WYSIWYG_PROTECTED">';
my $linkon = '<span class="WYSIWYG_LINK">';
my $protectoff = '</span>';
my $linkoff = '</span>';
my $preoff = '</span>';
my $nop = "$protecton<nop>$protectoff";

# The following big table contains all the testcases. These are
# used to add a bunch of functions to the symbol table of this
# testcase, so they get picked up and run by TestRunner.

# Each testcase is a subhash with fields as follows:
# exec => 1 to test TML -> HTML, 2 to test HTML -> TML, 3 to
# test both, anything else to skin the test.
# name => identifier (used to compose the testcase function name)
# tml => source TWiki meta-language
# html => expected html from expanding tml
# finaltml => optional expected tml from translating html. If not there,
# will use tml. Only use where round-trip can't be closed because
# we are testing deprecated syntax.
my $data =
  [
      {
          exec => $TML2HTML | $HTML2TML,
          name => 'Pling',
          tml => 'Move !ItTest/site/ToWeb5 leaving web5 as !MySQL host',
          html => <<HERE,
<p>
Move !<span class="WYSIWYG_LINK">ItTest</span>/site/ToWeb5 leaving web5 as !<span class="WYSIWYG_LINK">MySQL</span> host
</p>
HERE
          finaltml => <<'HERE',
Move !ItTest/site/ToWeb5 leaving web5 as !MySQL host
HERE
      },
      {
          exec => $ROUNDTRIP,
          name => 'linkAtStart',
          tml => 'LinkAtStart',
          html => $linkon.'LinkAtStart'.$linkoff,
      },
      {
          exec => $ROUNDTRIP,
          name => 'otherWebLinkAtStart',
          tml => 'OtherWeb.LinkAtStart',
          html => $linkon.'OtherWeb.LinkAtStart'.$linkoff,
      },
      {
          exec => $ROUNDTRIP,
          name => 'currentWebLinkAtStart',
          tml => 'Current.LinkAtStart',
          html => $linkon.'Current.LinkAtStart'.$linkoff,
          finaltml => 'Current.LinkAtStart',
      },
      {
          exec => $ROUNDTRIP,
          name => 'simpleParas',
          html => '1st paragraph<p />2nd paragraph',
          tml => <<'HERE',
1st paragraph

2nd paragraph
HERE
      },
      {
          exec => $ROUNDTRIP,
          name => 'headings',
          html => <<'HERE',
<h2 class="TML"> Sushi</h2><h3 class="TML"> Maguro</h3>
HERE
          tml => <<'HERE',
---++ Sushi
---+++ Maguro
HERE
      },
      {
          exec => $ROUNDTRIP,
          name => 'simpleStrong',
          html => '<b>Bold</b>',
          tml => '*Bold*
'
         },
      {
          exec => $ROUNDTRIP,
          name => 'strongLink',
          html => <<HERE,
<b>reminded about${linkon}http://www.koders.com${linkoff}</b>
HERE
          tml => '*reminded about http://www.koders.com*',
          finaltml => '*reminded about http://www.koders.com*',
      },
      {
          exec => $ROUNDTRIP,
          name => 'simpleItalic',
          html => '<i>Italic</i>',
          tml => '_Italic_',
      },
      {
          exec => $ROUNDTRIP,
          name => 'boldItalic',
          html => '<b><i>Bold italic</i></b>',
          tml => '__Bold italic__',
      },
      {
          exec => $ROUNDTRIP,
          name => 'simpleCode',
          html => '<code>Code</code>',
          tml => '=Code='
         },
      {
          exec => $ROUNDTRIP,
          name => 'strongCode',
          html => '<b><code>Bold Code</code></b>',
          tml => '==Bold Code=='
         },
      {
          exec => $ROUNDTRIP,
          name => 'mixtureOfFormats',
          html => <<'HERE',
<p><i>this</i><i>should</i><i>italicise</i><i>each</i><i>word</i><p /><b>and</b><b>this</b><b>should</b><b>embolden</b><b>each</b><b>word</b></p><p><i>mixing</i><b>them</b><i>should</i><b>work</b></p>
HERE
          tml => <<'HERE',
_this_ _should_ _italicise_ _each_ _word_

*and* *this* *should* *embolden* *each* *word*

_mixing_ *them* _should_ *work*
HERE
      },
      {
          exec => $ROUNDTRIP,
          name => 'simpleVerbatim',
          html => <<'HERE',
<span class="TMLverbatim"><br />&#60;verbatim&#62;<br />Description<br />&#60;/verbatim&#62;<br /><br /><br />class&nbsp;CatAnimal&nbsp;{<br />&nbsp;&nbsp;void&nbsp;purr()&nbsp;{<br />&nbsp;&nbsp;&nbsp;&nbsp;code&nbsp;&#60;here&#62;<br />&nbsp;&nbsp;}<br />}<br /></span>
HERE
          tml => <<'HERE',
<verbatim>
<verbatim>
Description
</verbatim>


class CatAnimal {
  void purr() {
    code <here>
  }
}
</verbatim>
HERE
      },
      {
          exec => $HTML2TML,
          name => 'spanVerbatim',
          html => <<'HERE',
<span class="TMLverbatim">
Oh....<br />&nbsp;&nbsp;&nbsp;my....<br />&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;gaaaaaawd!
</span>
HERE
          tml => <<'HERE',
<verbatim>
Oh....
   my....
      gaaaaaawd!
</verbatim>
HERE
      },
      {
          exec => $HTML2TML,
          name => 'pVerbatim',
          html => <<'HERE',
<p class="TMLverbatim">
Oh....<br />&nbsp;&nbsp;&nbsp;my....<br />&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;gaaaaaawd!
</p>
HERE
          tml => <<'HERE',
<verbatim>
Oh....
   my....
      gaaaaaawd!
</verbatim>
HERE
      },
      {
          exec => $HTML2TML,
          name => 'Item5165',
          html => '<pre class="TMLverbatim"><br />Before&nbsp;&amp;nbsp;&nbsp;After<br /></pre>',
          tml => '<verbatim>
Before &nbsp; After
</verbatim>',
      },
      {
          exec => $ROUNDTRIP,
          name => 'simpleHR',
          html => '<hr class="TMLhr"/><hr class="TMLhr"/>--',
          tml => <<'HERE',
---
-------
--

HERE
          finaltml => <<'HERE',
---
---
--
HERE
      },
      {
          exec => $ROUNDTRIP,
          name => 'simpleBullList',
          html => 'Before<ul><li>bullet item</li></ul>After',
          tml => <<'HERE',
Before
   * bullet item
After
HERE
      },
      {
          exec => $ROUNDTRIP,
          name => 'multiLevelBullList',
          html => <<'HERE',
X
<ul><li>level 1
<ul><li>level 2</li></ul></li></ul>
HERE
          tml => <<'HERE',
X
   * level 1
      * level 2

HERE
          finaltml => <<'HERE',
X
   * level 1
      * level 2
HERE
      },
      {
          exec => $ROUNDTRIP,
          name => 'orderedList',
          html => <<'HERE',
<ol><li>Sushi</li></ol><p /><ol>
<li type="A">Sushi</li></ol><p />
<ol><li type="i">Sushi</li></ol><p />
<ol><li>Sushi</li><li type="A">Sushi</li><li type="i">Sushi</li></ol>
HERE
          tml => <<'HERE',
   1 Sushi

   A. Sushi

   i. Sushi

   1 Sushi
   A. Sushi
   i. Sushi
HERE
      },
      {
          exec => $ROUNDTRIP,
          name => 'mixedList',
          html => <<"HERE",
<ol><li>Things</li><li>Stuff
<ul><li>Banana Stuff</li><li>Other</li><li></li></ul></li><li>Something</li><li>kello$protecton&lt;br&nbsp;/&gt;${protectoff}hitty</li></ol>
HERE
          tml => <<'HERE',
   1 Things
   1 Stuff
      * Banana Stuff
      * Other
      * 
   1 Something
   1 kello<br />hitty
HERE
      },
      {
          exec => $ROUNDTRIP,
          name => 'definitionList',
          html => <<'HERE',
<dl> <dt> Sushi
</dt><dd>Japan</dd><dt>Dim Sum</dt><dd>S. F.</dd><dt>Sauerkraut</dt><dd>Germany</dd></dl>
<ul><li>Fennel</li></ul>
HERE
          tml => <<'HERE',
   $ Sushi: Japan
   $ Dim Sum: S. F.
   Sauerkraut: Germany
   * Fennel
HERE
          finaltml => <<'HERE',
   $ Sushi: Japan
   $ Dim Sum: S. F.
   $ Sauerkraut: Germany
   * Fennel
HERE
      },
      {
          exec => $ROUNDTRIP,
          name => 'simpleTable',
          html => <<'HERE',
Before
<table border="1" cellpadding="0" cellspacing="1"><tr><td><b>L</b></td><td><b>C</b></td><td><b>R</b></td></tr><tr><td> A2</td><td style="text-align: center" class="align-center"> 2</td><td style="text-align: right" class="align-right"> 2</td></tr><tr><td> A3</td><td style="text-align: center" class="align-center"> 3</td><td style="text-align: left" class="align-left"> 3</td></tr><tr><td> A4-6</td><td> four</td><td> four</td></tr><tr><td>^</td><td> five</td><td> five</td></tr></table><p /><table border="1" cellpadding="0" cellspacing="1"><tr><td>^</td><td> six</td><td> six</td></tr></table>
After
HERE
          tml => <<'HERE',
Before
| *L* | *C* | *R* |
| A2 |  2  |  2 |
| A3 |  3  | 3  |
| A4-6 | four | four |
|^| five | five |

|^| six | six |
After

HERE
          finaltml => <<'HERE',
Before
| *L* | *C* | *R* |
| A2 |  2  |  2 |
| A3 |  3  | 3  |
| A4-6 | four | four |
| ^ | five | five |

| ^ | six | six |
After
HERE
      },
      {
          exec => 0,# disabled because of Kupu problems handling colspans
          name => 'tableWithSpans',
          html => <<'HERE',
<table border="1" cellpadding="0" cellspacing="1"><tr><td><b> L </b></td><td><b> C </b></td><td><b> R </b></td></tr><tr><td> A2 </td><td class="align-center" style="text-align: center">  2  </td><td class="align-right" style="text-align: right">  2 </td></tr><tr><td> A3 </td><td class="align-center" style="text-align: center">  3  </td><td class="align-left" style="text-align: left">  3  </td></tr><tr><td colspan="3"> multi span </td></tr><tr><td> A4-6 </td><td> four </td><td> four </td></tr><tr><td>^</td><td> five</td><td>five </td></tr></table><p /><table border="1" cellpadding="0" cellspacing="1"><tr><td>^</td><td>six</td><td>six</td></tr></table>
HERE
          tml => <<'HERE',

| *L* | *C* | *R* |
| A2 |  2  |  2 |
| A3 |  3  | 3  |
| multi span |||
| A4-6 | four | four |
|^| five|five |

|^| six | six |

HERE
          finaltml => <<'HERE',

| *L* |*C* |*R* |
| A2 |  2  |  2 |
| A3 |  3  | 3  |
| multi span |||
| A4-6 | four | four |
|^| five|five |

|^|six|six|
HERE
      },
      {
          exec => $TML2HTML | $ROUNDTRIP,
          name => 'noppedWikiword',
          html => '<p>!<span class="WYSIWYG_LINK">SunOS</span></p>',
          tml => '!SunOS',
          finaltml => '!SunOS',
      },
      {
          exec => $HTML2TML,
          name => 'noppedPara',
          html => "${nop}BeFore ${nop}SunOS ${nop}AfTer",
          tml => '<nop>BeFore <nop>SunOS <nop>AfTer',
      },
      {
          exec => $HTML2TML,
          name => 'noppedVariable',
          html => <<HERE,
%${nop}MAINWEB%</nop>
HERE
          tml => '%<nop>MAINWEB%'
         },
      {
          exec => $HTML2TML,#|$TML2HTML|$ROUNDTRIP,
          name => 'noAutoLunk',
          html => <<'HERE',
<p>
<span class="WYSIWYG_PROTECTED">&lt;noautolink&gt;</span>
<span class="WYSIWYG_LINK">RedHat</span> & <span class="WYSIWYG_LINK">SuSE</span>
<span class="WYSIWYG_PROTECTED">&lt;/noautolink&gt;</span>
</p>
HERE
          tml => <<'HERE',
<noautolink>
RedHat & SuSE
</noautolink>
HERE
          finaltml => <<'HERE',
<noautolink> RedHat & SuSE </noautolink>
HERE
      },
      {
          exec => $ROUNDTRIP,
          name => 'mailtoLink',
          html => <<HERE,
$linkon\[[mailto:a\@z.com][Mail]]${linkoff} $linkon\[[mailto:?subject=Hi][Hi]]${linkoff}
HERE
          tml => '[[mailto:a@z.com][Mail]] [[mailto:?subject=Hi][Hi]]',
          finaltml => <<'HERE',
[[mailto:a@z.com][Mail]] [[mailto:?subject=Hi][Hi]]
HERE
      },
      {
          exec => $ROUNDTRIP,
          name => 'mailtoLink2',
          html => ' a@z.com ',
          tml => 'a@z.com',
      },
      {
          exec => $TML2HTML|$ROUNDTRIP,
          name => 'variousWikiWords',
          html => "<p>${linkon}WebPreferences${linkoff}</p><p>$protecton<br />%MAINWEB%$protectoff.TWikiUsers</p><p>${linkon}CompleteAndUtterNothing${linkoff}</p><p>${linkon}LinkBox$linkoff${linkon}LinkBoxs${linkoff}${linkon}LinkBoxies${linkoff}${linkon}LinkBoxess${linkoff}${linkon}LinkBoxesses${linkoff}${linkon}LinkBoxes${linkoff}</p>",
          tml => <<'YYY',
WebPreferences

%MAINWEB%.TWikiUsers

CompleteAndUtterNothing

LinkBox LinkBoxs LinkBoxies LinkBoxess LinkBoxesses LinkBoxes
YYY
      },
      {
          exec => $HTML2TML | $ROUNDTRIP,
          name => 'variousWikiWordsNopped',
          html => "${nop}${linkon}WebPreferences${linkoff} %${nop}MAINWEB%.TWikiUsers ${nop}CompleteAndUtterNothing",
          tml => '<nop>WebPreferences %<nop>MAINWEB%.TWikiUsers <nop>CompleteAndUtterNothing',
      },
      {
          exec => $ROUNDTRIP,
          name => 'squabsWithVars',
          html => <<HERE,
${linkon}[[wiki syntax]]$linkoff$linkon\[[%MAINWEB%.TWiki users]]${linkoff}
escaped:
[<nop>[wiki syntax]]
HERE
          tml => <<'THERE',
[[wiki syntax]][[%MAINWEB%.TWiki users]]
escaped:
![[wiki syntax]]
THERE
          finaltml => <<'EVERYWHERE',
[[wiki syntax]][[%MAINWEB%.TWiki users]] escaped: ![[wiki syntax]]
EVERYWHERE
      },
      {
          exec => $ROUNDTRIP,
          name => 'squabsWithWikiWordsAndLink',
          html => $linkon.'[[WikiSyntax][syntax]]'.$linkoff.' '.$linkon
            .'[[http://gnu.org][GNU]]'.$linkoff.' '.$linkon
              .'[[http://xml.org][XML]]'.$linkoff,
          tml => '[[WikiSyntax][syntax]] [[http://gnu.org][GNU]] [[http://xml.org][XML]]',
      },
      {
          exec => $ROUNDTRIP,
          name => 'squabWithAnchor',
          html => ${linkon}.'FleegleHorn#TrumpetHack'.${linkoff},
          tml => 'FleegleHorn#TrumpetHack',
      },
      {
          exec => $ROUNDTRIP,
          name => 'plingedVarOne',
          html => '!<span class="WYSIWYG_PROTECTED">%MAINWEB%</span>nowt',
          tml => '!%MAINWEB%nowt',
          finaltml => '!%MAINWEB%nowt',
      },
      {
          exec => $ROUNDTRIP,
          name => 'plingedVarTwo',
          html => 'nowt!<span class="WYSIWYG_PROTECTED">%MAINWEB%</span>',
          tml => 'nowt!%MAINWEB%',
          finaltml => 'nowt!%MAINWEB%',
      },
      {
          exec => $ROUNDTRIP,
          name => 'headerly',
          html => "<h1 class='notoc'><span class='WYSIWYG_PROTECTED'>%TOPIC%</span></h1>",
          tml => '---+!!%TOPIC%',
          finaltml => '---+!! %TOPIC%',
      },
      {
          exec => $ROUNDTRIP,
          name => 'WEBvar',
          html => "${protecton}%WEB%${protectoff}",
          tml => '%WEB%',
      },
      {
          exec => $ROUNDTRIP,
          name => 'ICONvar1',
          html => "${protecton}%ICON{}%${protectoff}",
          tml => '%ICON{}%',
      },
      {
          exec => $ROUNDTRIP,
          name => 'ICONvar2',
          html => "${protecton}%ICON{&#34;&#34;}%${protectoff}",
          tml => '%ICON{""}%',
      },
      {
          exec => $ROUNDTRIP,
          name => 'ICONvar3',
          html => "${protecton}%ICON{&#34;Fleegle&#34;}%${protectoff}",
          tml => '%ICON{"Fleegle"}%'
         },
      {
          exec => $ROUNDTRIP,
          name => 'URLENCODEvar',
          html => "${protecton}%URLENCODE{&#34;&#34;}%${protectoff}",
          tml => '%URLENCODE{""}%',
      },
      {
          exec => $ROUNDTRIP,
          name => 'ENCODEvar',
          html => "${protecton}%ENCODE{&#34;&#34;}%${protectoff}",
          tml => '%ENCODE{""}%',
      },
      {
          exec => $ROUNDTRIP,
          name => 'INTURLENCODEvar',
          html => "${protecton}%INTURLENCODE{&#34;&#34;}%${protectoff}",
          tml => '%INTURLENCODE{""}%',
      },
      {
          exec => $ROUNDTRIP,
          name => 'USERSWEBvar',
          html => "${protecton}%MAINWEB%${protectoff}",
          tml => '%MAINWEB%',
      },
      {
          exec => $ROUNDTRIP,
          name => 'SYSTEMWEBvar',
          html => "${protecton}%TWIKIWEB%${protectoff}",
          tml => '%TWIKIWEB%',
      },
      {
          exec => $ROUNDTRIP,
          name => 'HOMETOPICvar',
          html => "${protecton}%HOMETOPIC%${protectoff}",
          tml => '%HOMETOPIC%',
      },
      {
          exec => $ROUNDTRIP,
          name => 'WIKIUSERSTOPICvar',
          html => $protecton.'%WIKIUSERSTOPIC%'.$protectoff,
          tml => '%WIKIUSERSTOPIC%',
      },
      {
          exec => $ROUNDTRIP,
          name => 'WIKIPREFSTOPICvar',
          html => $protecton.'%WIKIPREFSTOPIC%'.$protectoff,
          tml => '%WIKIPREFSTOPIC%',
      },
      {
          exec => $ROUNDTRIP,
          name => 'WEBPREFSTOPICvar',
          html => $protecton.'%WEBPREFSTOPIC%'.$protectoff,
          tml => '%WEBPREFSTOPIC%',
      },
      {
          exec => $ROUNDTRIP,
          name => 'NOTIFYTOPICvar',
          html => $protecton.'%NOTIFYTOPIC%'.$protectoff,
          tml => '%NOTIFYTOPIC%',
      },
      {
          exec => $ROUNDTRIP,
          name => 'STATISTICSTOPICvar',
          html => $protecton.'%STATISTICSTOPIC%'.$protectoff,
          tml => '%STATISTICSTOPIC%',
      },
      {
          exec => $ROUNDTRIP,
          name => 'STARTINCLUDEvar',
          html => $protecton.'%STARTINCLUDE%'.$protectoff,
          tml => '%STARTINCLUDE%',
      },
      {
          exec => $ROUNDTRIP,
          name => 'STOPINCLUDEvar',
          html => $protecton.'%STOPINCLUDE%'.$protectoff,
          tml => '%STOPINCLUDE%',
      },
      {
          exec => $ROUNDTRIP,
          name => 'SECTIONvar',
          html => $protecton.'%SECTION{&#34;&#34;}%'.$protectoff,
          tml => '%SECTION{""}%',
      },
      {
          exec => $ROUNDTRIP,
          name => 'ENDSECTIONvar',
          html => $protecton.'%ENDSECTION%'.$protectoff,
          tml => '%ENDSECTION%',
      },
      {
          exec => $ROUNDTRIP,
          name => 'FORMFIELDvar1',
          html => $protecton.'%FORMFIELD{&#34;&#34;&nbsp;topic=&#34;&#34;&nbsp;alttext=&#34;&#34;&nbsp;default=&#34;&#34;&nbsp;format=&#34;$value&#34;}%'.$protectoff,
          tml => '%FORMFIELD{"" topic="" alttext="" default="" format="$value"}%',
      },
      {
          exec => $ROUNDTRIP,
          name => 'FORMFIELDvar2',
          html => $protecton.'%FORMFIELD{&#34;TopicClassification&#34;&nbsp;topic=&#34;&#34;&nbsp;alttext=&#34;&#34;&nbsp;default=&#34;&#34;&nbsp;format=&#34;$value&#34;}%'.$protectoff,
          tml => '%FORMFIELD{"TopicClassification" topic="" alttext="" default="" format="$value"}%',
      },
      {
          exec => $ROUNDTRIP,
          name => 'SPACEDTOPICvar',
          html => $protecton.'%SPACEDTOPIC%'.$protectoff,
          tml => '%SPACEDTOPIC%',
      },
      {
          exec => $ROUNDTRIP,
          name => 'RELATIVETOPICPATHvar1',
          html => $protecton.'%RELATIVETOPICPATH{}%'.$protectoff,
          tml => '%RELATIVETOPICPATH{}%',
      },
      {
          exec => $ROUNDTRIP,
          name => 'RELATIVETOPICPATHvar2',
          html => $protecton.'%RELATIVETOPICPATH{Sausage}%'.$protectoff,
          tml => '%RELATIVETOPICPATH{Sausage}%',
      },
      {
          exec => $ROUNDTRIP,
          name => 'RELATIVETOPICPATHvar3',
          html => $protecton.'%RELATIVETOPICPATH{&#34;Chips&#34;}%'.$protectoff,
          tml => '%RELATIVETOPICPATH{"Chips"}%',
      },
      {
          exec => $ROUNDTRIP,
          name => 'SCRIPTNAMEvar',
          html => $protecton.'%SCRIPTNAME%'.$protectoff,
          tml => '%SCRIPTNAME%',
      },
      {
          exec => $ROUNDTRIP,
          name => 'nestedVerbatim',
          html => 'Outside
 <span class="TMLverbatim"><br />Inside<br /></span>Outside',
          tml => 'Outside
 <verbatim>
 Inside
 </verbatim>
 Outside',
          finaltml => 'Outside <verbatim>
 Inside
 </verbatim> Outside',
      },
      {
          exec => $TML2HTML | $ROUNDTRIP,
          name => 'nestedPre',
          html => '<p>
Outside <pre class="twikiAlert TMLverbatim"><br />&nbsp;&nbsp;Inside<br />&nbsp;&nbsp;</pre> Outside </p>',
          tml => 'Outside <verbatim class="twikiAlert">
  Inside
  </verbatim> Outside',
      },
      {
          exec => $ROUNDTRIP,
          name => 'nestedIndentedVerbatim',
          html => 'Outside<span class="TMLverbatim"><br />Inside<br />&nbsp;&nbsp;&nbsp;</span>Outside',
          tml => 'Outside
    <verbatim>
 Inside
    </verbatim>
 Outside
 ',
          finaltml => 'Outside <verbatim>
 Inside
    </verbatim> Outside',
      },
      {
          exec => $ROUNDTRIP | $HTML2TML,
          name => 'nestedIndentedPre',
          html => 'Outside
 <pre>
 Inside

Snide
 </pre>
 Outside',
          tml => 'Outside
 <pre>
 Inside

Snide
 </pre>
Outside',
          finaltml => 'Outside <pre>
 Inside

Snide
 </pre> Outside',
      },
      {
          exec => $HTML2TML,
          name => 'classifiedPre',
          html => 'Outside
 <pre class="twikiAlert">
 Inside
 </pre>
 Outside',
          tml => 'Outside <pre class="twikiAlert">
 Inside
 </pre> Outside',
      },
      {
          exec => $ROUNDTRIP,
          name => 'indentedPre',
          html => 'Outside<pre>
Inside
</pre>Outside',
          tml => 'Outside
    <pre>
 Inside
    </pre>
 Outside',
          finaltml => 'Outside <pre>
 Inside
    </pre> Outside',
      },
      {
          exec => $TML2HTML|$ROUNDTRIP,
          name => 'NAL',
          html => '<p>Outside
 <span class="WYSIWYG_PROTECTED">&lt;noautolink&gt;</span>
 Inside
 <span class="WYSIWYG_PROTECTED">&lt;/noautolink&gt;</span>
 Outside</p>',
          tml => 'Outside
 <noautolink>
 Inside
 </noautolink>
 Outside',
          finaltml => 'Outside <noautolink> Inside </noautolink> Outside',
      },
      {
          exec => $TML2HTML|$ROUNDTRIP,
          name => 'classifiedNAL',
          html => '<p>Outside
<span class="WYSIWYG_PROTECTED">&lt;noautolink&nbsp;class="twikiAlert"&gt;</span></p>
  <ul>
   <li> Inside </li>
  </ul>
<span class="WYSIWYG_PROTECTED">&lt;/noautolink&gt;</span>
 Outside
 ',
          tml => 'Outside
<noautolink class="twikiAlert">
   * Inside
</noautolink>
 Outside',
          finaltml => 'Outside <noautolink class="twikiAlert">
   * Inside
</noautolink> Outside',
      },
      {
          exec => $ROUNDTRIP,
          name => 'indentedNAL',
          html => 'Outside
 <span class="WYSIWYG_PROTECTED">&lt;noautolink&gt;</span>
 Inside
 <span class="WYSIWYG_PROTECTED">&lt;/noautolink&gt;</span>
 Outside
 ',
          tml => 'Outside
    <noautolink>
 Inside
    </noautolink>
 Outside
 ',
          finaltml => 'Outside <noautolink> Inside </noautolink> Outside',
      },
      {
          exec => $ROUNDTRIP,
          name => 'linkInHeader',
          html => "<h3 class=\"TML\"> Test with${linkon}LinkInHeader${linkoff}</h3>",
          tml => '---+++ Test with LinkInHeader',
      },
      {
          exec => $HTML2TML,
          name => 'inlineBreaks',
          html => 'Zadoc<br />The<br />Priest',
          finaltml => 'Zadoc<br />The<br />Priest',
      },
      {
          exec => $HTML2TML,
          name => 'doctype',
          html => '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">',
          tml => '',
      },
      {
          exec => $HTML2TML,
          name => 'head',
          html => '<head> ignore me </head>',
          tml => '',
      },
      {
          exec => $HTML2TML,
          name => 'htmlAndBody',
          html => '<html> good <body>good </body></html>',
          tml => 'good good',
      },
      {
          exec => $HTML2TML,
          name => 'kupuTable',
          html => '<table cellspacing="0" cellpadding="8" border="1" class="plain" _moz_resizing="true">
<tbody>
<tr>a0<td>a1</td><td>a2</td><td>a3</td></tr>
<tr>b0<td colspan="2">b1</td><td>b3</td></tr>
<tr>c0<td>c1</td><td>c2</td><td>c3</td></tr>
</tbody>
</table>',
          tml => '| a1 | a2 | a3 |
| b1 || b3 |
| c1 | c2 | c3 |
',
      },
      {
          exec => $ROUNDTRIP,
          name=>"images",
          html=>'<img src="test_image" />',
          tml => '%TRANSLATEDIMAGE%',
      },
      {
          exec => $ROUNDTRIP,
          name=>"TWikiTagsInHTMLParam",
          html=>"${linkon}[[%!page!%/Burble/Barf][Burble]]${linkoff}",
          tml => '[[%!page!%/Burble/Barf][Burble]]',
      },
      {
          exec => $HTML2TML,
          name=>"emptySpans",
          html=> <<HERE,
1 <span class="arfle"></span>
2 <span lang="jp"></span>
3 <span></span>
4 <span style="chanel">francais</span>
5 <span class="fr">francais</span>
HERE
          tml => <<HERE,
1 2 3 4 <span style="chanel">francais</span> 5 francais
HERE
      },
      {
          exec => $ROUNDTRIP,
          name => 'linkToOtherWeb',
          html => "${linkon}[[Sandbox.WebHome][this]]${linkoff}",
          tml => '[[Sandbox.WebHome][this]]',
      },
      {
          exec => $ROUNDTRIP,
          name => 'anchoredLink',
          tml => '[[FAQ.NetworkInternet#Pomona_Network][Test Link]]',
          html => "${linkon}[[FAQ.NetworkInternet#Pomona_Network][Test Link]]${linkoff}",
      },
      {
          exec => $TML2HTML | $ROUNDTRIP,
          name => 'tableWithColSpans',
          html => '<p>abcd
</p>
<table cellspacing="1" cellpadding="0" border="1">
<tr><td colspan="2">efg</td><td>&nbsp;</td></tr>
<tr><td colspan="3"></td></tr></table>
hijk',
          tml  => 'abcd
| efg || |
||||
hijk',
          finaltml  => 'abcd
| efg || |
| |||
hijk',
      },
      {
          exec => $ROUNDTRIP,
          name => 'variableInIMGtag',
          html => '<img src="/MAIN/pub/Current/TestTopic/T-logo-16x16.gif" />',
          tml  => '<img src="%ATTACHURLPATH%/T-logo-16x16.gif" />',
          finaltml => '<img src="%ATTACHURLPATH%/T-logo-16x16.gif" />',
      },
      {
          exec => $TML2HTML|$HTML2TML|$ROUNDTRIP,
          name => 'setCommand',
          tml => <<HERE,
   * Set FLIBBLE = <break> <cake/>
     </break>
   * %FLIBBLE%
      * Set FLEEGLE = easy gum
HERE
          html => '<ul>
<li> Set FLIBBLE =<span class="WYSIWYG_PROTECTED">&nbsp;&#60;break&#62;&nbsp;&#60;cake/&#62;<br />&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&#60;/break&#62;</span></li><li><span class="WYSIWYG_PROTECTED">%FLIBBLE%</span><ul><li>Set FLEEGLE =<span class="WYSIWYG_PROTECTED">&nbsp;easy&nbsp;gum</span></li></ul></li></ul>',
},
      {
          exec => $HTML2TML,
          name => 'tinyMCESetCommand',
          tml => <<HERE,
Before

   * Set FLIBBLE = phlegm
After
HERE
          html => 'Before<p class="WYSIWYG_PROTECTED">&nbsp;&nbsp; * Set FLIBBLE = phlegm</p>After',
      },
      {
          exec => $ROUNDTRIP,
          name => 'twikiWebSnarf',
          html => $linkon.'[[%TWIKIWEB%.TopicName][bah]]'.$linkoff,
          tml  => '[[%TWIKIWEB%.TopicName][bah]]',
      },
      {
          exec => $ROUNDTRIP,
          name => 'mainWebSnarf',
          html => "${linkon}\[[%MAINWEB%.TopicName][bah]]$linkoff",
          tml  => '[[%MAINWEB%.TopicName][bah]]',
      },
      {
          exec => $ROUNDTRIP,
          name => 'mainFormWithVars',
          html => $protecton.'<form&nbsp;action=&#34;%SCRIPTURLPATH%/search%SCRIPTSUFFIX%/%INTURLENCODE{&#34;%WEB%&#34;}%/&#34;>'.$protectoff,
          tml  => '<form action="%SCRIPTURLPATH%/search%SCRIPTSUFFIX%/%INTURLENCODE{"%WEB%"}%/">',
      },
      {
          exec => $ROUNDTRIP,
          name => "Item871",
          tml => "[[Test]] Entry [[TestPage][Test Page]]\n",
          html => "${linkon}[[Test]]${linkoff} Entry ${linkon}[[TestPage][Test Page]]${linkoff}",
      },
      {
          exec => 0,
          name => "Item863",
          tml => <<EOE,
||1| 2 |  3 | 4  ||
EOE
          html => '<table cellpadding="0" border="1" cellspacing="1">',
          finaltml => <<EOE,
EOE
      },
      {
          exec => $ROUNDTRIP,
          name => 'Item945',
          html => $protecton.'%SEARCH{&#34;ReqNo&#34;&nbsp;scope=&#34;topic&#34;&nbsp;regex=&#34;on&#34;&nbsp;nosearch=&#34;on&#34;&nbsp;nototal=&#34;on&#34;&nbsp;casesensitive=&#34;on&#34;&nbsp;format=&#34;$percntCALC{$IF($NOT($FIND(%TOPIC%,$formfield(ReqParents))),&nbsp;&#60;nop&#62;,&nbsp;[[$topic]]&nbsp;-&nbsp;$formfield(ReqShortDescript)&nbsp;%BR%&nbsp;)}$percnt&#34;}%'.$protectoff,
          tml  => '%SEARCH{"ReqNo" scope="topic" regex="on" nosearch="on" nototal="on" casesensitive="on" format="$percntCALC{$IF($NOT($FIND(%TOPIC%,$formfield(ReqParents))), <nop>, [[$topic]] - $formfield(ReqShortDescript) %BR% )}$percnt"}%',
      },
      {
          exec => $ROUNDTRIP,
          name => "WebAndTopic",
          tml => "Current.TestTopic Sandbox.TestTopic [[Current.TestTopic]] [[Sandbox.TestTopic]]",
          html => <<HERE,
${linkon}Current.TestTopic${linkoff}
${linkon}Sandbox.TestTopic${linkoff}
${linkon}\[[Current.TestTopic]]${linkoff}
${linkon}\[[Sandbox.TestTopic]]${linkoff}
HERE
          finaltml => <<HERE,
Current.TestTopic Sandbox.TestTopic [[Current.TestTopic]] [[Sandbox.TestTopic]]
HERE
      },
      {
          exec => $ROUNDTRIP,
          name => 'Item1140',
          html => '<img src="%!page!%/T-logo-16x16.gif" />',
          tml  => '<img src="%!page!%/T-logo-16x16.gif" />',
          finaltml => '<img src=\'%SCRIPTURL{"view"}%/T-logo-16x16.gif\' />',
      },
      {
          exec => $ROUNDTRIP,
          name => 'Item1175',
          tml => '[[WebCTPasswords][Resetting a WebCT Password]]',
          html => "${linkon}[[WebCTPasswords][Resetting a WebCT Password]]${linkoff}",
          finaltml => '[[WebCTPasswords][Resetting a WebCT Password]]',
      },
      {
          exec => $ROUNDTRIP,
          name => 'Item1259',
          html => "Spleem$protecton&#60;!--<br />&nbsp;&nbsp;&nbsp;*&nbsp;Set&nbsp;SPOG&nbsp;=&nbsp;dreep<br />--&#62;${protectoff}Splom",
          tml => "Spleem<!--\n   * Set SPOG = dreep\n-->Splom",
      },
      {
          exec => $ROUNDTRIP,
          name => 'Item1317',
          tml => '%<nop>DISPLAYTIME{"$hou:$min"}%',
          html => "%${nop}DISPLAYTIME\{\"\$hou:\$min\"}%",
      },
      {
          exec => $ROUNDTRIP,
          name => 'Item4410',
          tml => <<'HERE',
   * x
| Y |
HERE
          html => '<ul><li>x</li></ul><table cellspacing="1" cellpadding="0" border="1"><tr><td>Y</td></tr></table>',
      },
      {
          exec => $ROUNDTRIP,
          name => 'Item4426',
          tml => <<'HERE',
   * x
   *
   * y
HERE
          html => '<ul>
<li>x
</li><li></li><li>y
</li></ul>',
          finaltml => <<'HERE',
   * x
   * 
   * y
HERE
      },
      {
          exec => $HTML2TML|$ROUNDTRIP,
          name => 'Item3735',
          tml => "fred *%WIKINAME%* fred",
          html => "<p>fred <b>$protecton%WIKINAME%$protectoff</b> fred</p>",
      },
      {
          exec => $ROUNDTRIP,
          name => 'brInProtectedRegion',
          html => $protecton."&#60;!--Fred<br />Jo&nbsp;e<br />Sam--&#62;".$protectoff,
          tml => "<!--Fred\nJo e\nSam-->",
      },
      {
          exec => $HTML2TML,
          name => 'whatTheF',
          html => 'what<p></p>thef',
          finaltml => "what\n\nthef",
      },
      {
          exec => $ROUNDTRIP,
          name => 'whatTheFur',
          html => 'what<p />thef',
          tml => "what\n\nthef",
      },
      {
          exec => $HTML2TML,# | $ROUNDTRIP,
          name => 'Item4435',
          html => <<HTML,
<ul>
<li> Clean up toolbar 
</li>
<li> Test tools 
</li>
</ul>
Garbles Bargles Smargles
<p>
Flame grilled
</p>
<p>
-- <span class="WYSIWYG_LINK">Main.JohnSilver</span> - 05 Aug 2007
</p>
<p>
Extra spaces???
</p>
<p>
<span class="WYSIWYG_PROTECTED">%COMMENT%</span>
</p>
HTML
          tml => <<TML,
   * Clean up toolbar 
   * Test tools 
Garbles Bargles Smargles

Flame grilled

-- Main.JohnSilver - 05 Aug 2007

Extra spaces???

%COMMENT%
TML
      },
      {
          name => 'paraConversions1',
          exec => $TML2HTML | $HTML2TML | $ROUNDTRIP,
          html => '<p>
Paraone
Paratwo
</p>
<p>
Parathree
</p>
<p></p>
<p>
Parafour
</p>',
          tml => 'Paraone
Paratwo

Parathree


Parafour',
          finaltml => 'Paraone Paratwo

Parathree

Parafour',
      },
      {
          name => 'paraConversionsTinyMCE',
          exec => $HTML2TML,
          html => 'Paraone
Paratwo
<p>&nbsp;</p>
Parathree
<p>&nbsp;</p>
<p>&nbsp;</p>
Parafour',
          tml => 'Paraone
Paratwo

Parathree

Parafour',
          finaltml => 'Paraone Paratwo

Parathree

Parafour',
      },
      {
          name => 'paraAfterList',
          exec => $HTML2TML | $ROUNDTRIP,
          tml => '   * list
Paraone',
          html => '<ul><li>list</li></ul>Paraone',
      },
      {
          name => 'brInText',
          exec => $HTML2TML,
          tml => 'pilf<br />flip',
          html => 'pilf<br>flip',
      },
      {
          name => 'brInSource',
          exec => $TML2HTML | $ROUNDTRIP,
          tml => 'pilf<br />flip',
          html => '<p>
pilf<br />flip
</p>',
      },
      {
          name => 'Item4481',
          exec => $TML2HTML | $ROUNDTRIP,
          tml => '<blockquote>pilf<br />flip</blockquote>',
          html => '<p><blockquote>pilf<br />flip</blockquote></p>',
      },
      {
          exec => $ROUNDTRIP,
          name => 'wtf',
          html => <<"HERE",
<ol><li>w$protecton&lt;br&nbsp;/&gt;${protectoff}g</li></ol>
HERE
          tml => <<'HERE',
   1 w<br />g
HERE
      },
      {
          exec => $ROUNDTRIP | $HTML2TML,
          name => 'blah',
          html => '<ul>
<li> Prevent
<ul>
<li> Set NOAUTOLINK =<span class="WYSIWYG_PROTECTED"></span>
</li>
</ul>
</li>
<li> The <code><span class="WYSIWYG_PROTECTED">&lt;noautolink&gt;</span>...<span class="WYSIWYG_PROTECTED">&lt;/noautolink&gt;</span></code> syntax
</li>
</ul>
',
          tml => '   * Prevent
      * Set NOAUTOLINK =
   * The <code><noautolink>...</noautolink></code> syntax
',
          finaltml => '   * Prevent
      * Set NOAUTOLINK =
   * The =<noautolink>...</noautolink>= syntax
',
      },
      {
          exec => $HTML2TML,
          name => 'losethatdamnBR',
          html => <<'JUNK',
TinyMCE sticks in a BR where it isn't wanted before a P<br>
<p>
We should only have a P.
</p>
JUNK
          tml => <<JUNX,
TinyMCE sticks in a BR where it isn't wanted before a P

We should only have a P.
JUNX
      },
      {
          exec => $HTML2TML,
          name => 'tableInnaBun',
          html => <<'JUNK',
<ul>
<li> List item</li><li><table><tbody><tr><td>&nbsp;11</td><td>&nbsp;21</td></tr><tr><td>12&nbsp;</td><td>&nbsp;22</td></tr></tbody></table></li><li>crap</li>
</ul>
JUNK
          tml => <<JUNX,
   * List item
   * <table><tbody><tr><td> 11</td><td> 21</td></tr><tr><td>12 </td><td> 22</td></tr></tbody></table>
   * crap
JUNX
      },
      {
          exec => $HTML2TML,
          name => 'Item4560',
          html => <<JUNSK,
Here is some text. Here a new line of text.
<p>
If you edit this page with TMCE, then save it, this line will become part of the previous paragraph.
</p>
JUNSK
          tml => <<JUNSX,
Here is some text. Here a new line of text.

If you edit this page with TMCE, then save it, this line will become part of the previous paragraph.
JUNSX
      },
      {
          exec => $TML2HTML,
          name => 'Item4550',
          tml => <<FGFG,
---+ A
<section>
---++ B
C
</section>
X
FGFG
          html =>'<h1 class="TML">  A </h1>
<span class="WYSIWYG_PROTECTED">&lt;section&gt;</span>
<h2 class="TML">  B </h2>
C
<span class="WYSIWYG_PROTECTED">&lt;/section&gt;</span>
X
',
      },
      {
          exec => $HTML2TML,
          name => 'Item4588',
          tml => <<XYZ,
A <i> *here* </i>A B <b> _here_ </b>B C __here__ C D <b> <i>here</i></b>D E <b><i>here</i></b>E F <i> <b>here</b></i>F
XYZ
# This was:
# A __here__ A B __here__ B C __here__ C D __here__ D E __here__ E F __here__ F
# before the fix for Item5961, but that's clearly wrong; the spaces should
# break the emphasis.
          html => <<XWYZ,
A <i><b>here</b> </i>A
B <b><i>here</i> </b>B
C <b><i>here</i></b> C
D <b> <i>here</i></b>D
E  <b><i>here</i></b>E
F <i> <b>here</b></i>F
XWYZ
          final_tml => <<ZYX,
ZYX
      },
      {
          exec => $ROUNDTRIP,
          name => "Item4615",
          tml => 'ABC<br /> _DEF_',
          html => 'ABC<br /><i>DEF</i>',
      },
      {
          exec => $TML2HTML | $HTML2TML,
          name => 'Item4700',
          tml => <<EXPT,
| ex | per | iment |
| exper | iment ||
| expe || riment |
|| exper | iment |
EXPT
          finaltml => <<EXPT,
| ex | per | iment |
| exper | iment ||
| expe || riment |
| | exper | iment |
EXPT
          html => <<HEXPT,
<table cellspacing="1" cellpadding="0" border="1">
<tr><td>ex</td><td>per</td><td>iment</td></tr>
<tr><td>exper</td><td colspan="2">iment</td></tr>
<tr><td colspan="2">expe</td><td>riment</td></tr>
<tr><td></td><td>exper</td><td>iment</td></tr>
</table>
HEXPT
      },
      {
          exec => $ROUNDTRIP,
          name => 'Item4700_2',
          tml => <<EXPT,
| ex | per | iment |
| exper | iment ||
| expe || riment |
| | exper | iment |
EXPT
          html => <<HEXPT,
<table cellspacing="1" cellpadding="0" border="1">
<tr><td>ex</td><td>per</td><td>iment</td></tr>
<tr><td>exper</td><td colspan="2">iment</td></tr>
<tr><td colspan="2">expe</td><td>riment</td></tr>
<tr><td></td><td>exper</td><td>iment</td></tr>
</table>
HEXPT
      },
      {
          exec => $HTML2TML | $ROUNDTRIP,
          name => 'collapse',
          html => <<COLLAPSE,
blah<pre class="TMLverbatim">flub</pre> <pre class="TMLverbatim">wheep</pre> <pre class="TMLverbatim">spit</pre>blah
COLLAPSE
          tml => <<ESPALLOC,
blah<verbatim>flub
wheep
spit</verbatim>blah
ESPALLOC
      },
      {
          exec => $TML2HTML | $ROUNDTRIP,
          name => 'Item4705_A',
          tml => <<SPACED,
A

<literal><b>B</b> </literal>

C
SPACED
          html => <<DECAPS,
<p>
A
</p>
<p>
<div class="WYSIWYG_LITERAL"><b>B</b> </div>
</p>
<p>
C
</p>
DECAPS
      },
      {
          exec => $TML2HTML | $ROUNDTRIP | $HTML2TML,
          name => 'sticky',
          tml => <<GLUED,
<sticky><font color="blue"> *|B|* </font></sticky>
GLUED
          html => '<p>
<div class="WYSIWYG_STICKY">&#60;font color="blue"&#62; *|B|* &#60;/font&#62;</div>
</p>
'
      },
      {
          exec => $TML2HTML,
          name => 'Item4705_B',
          tml => <<SPACED,
A

<verbatim>B</verbatim>

C
SPACED
          html => <<DECAPS,
<p>
A
</p>
<p>
<pre class="TMLverbatim">B</pre>
</p>
<p>
C
</p>
DECAPS
      },
      {
          exec => $TML2HTML,
          name => 'Item4763',
          tml => <<SPACED,
   1 One item
     spanning several lines
   1 And another item
 with one space
No more
SPACED
          html => <<DECAPS,
<ol>
<li> One item     spanning several lines

</li> <li> And another item with one space
</li></ol> 
No more
DECAPS
      },
      {
          exec => $ROUNDTRIP,
          name => 'Item4789',
          tml => "%EDITTABLE{}%\n| 1 | 2 |\n| 3 | 4 |",
      },
      {
          exec => $ROUNDTRIP,
          name => 'ProtectAndSurvive',
          tml => '<ul type="compact">Fred</ul><h1 align="right">HAH</h1><ol onclick="burp">Joe</ol>',
      },
      {
          name => 'Item4855',
          exec => $TML2HTML,
          tml => <<HERE,
| [[LegacyTopic1]] | Main.SomeGuy |
%TABLESEP%
%SEARCH{"legacy" nonoise="on" format="| [[\$topic]] | [[\$wikiname]] |"}%
HERE
          html => <<THERE,
<table cellspacing="1" cellpadding="0" border="1">
<tr><td><span class="WYSIWYG_LINK">[[LegacyTopic1]]</span></td><td>Main.SomeGuy</td></tr>
</table>
<span class="WYSIWYG_PROTECTED"><br />%TABLESEP%</span>
<span class="WYSIWYG_PROTECTED"><br />%SEARCH{"legacy" nonoise="on" format="| [[\$topic]] | [[\$wikiname]] |"}%</span>
THERE
      },
      {
          name => 'Item4871',
          exec => $TML2HTML,
          tml => <<'BLAH',
Blah
<a href="%SCRIPTURLPATH{"edit"}%/%WEB%/%TOPIC%?t=%GM%NOP%TIME{"$epoch"}%">edit</a>
Blah
BLAH
          html => <<'BLAH',
<p>
Blah
<span class="WYSIWYG_PROTECTED">&#60;a&nbsp;href=&#34;%SCRIPTURLPATH{&#34;edit&#34;}%/%WEB%/%TOPIC%?t=%GM%NOP%TIME{&#34;$epoch&#34;}%&#34;&#62;</span>edit<span
class="WYSIWYG_PROTECTED">&#60;/a&#62;</span>
Blah
</p>
BLAH
      },
      {
          name => 'Item4903',
          exec => $TML2HTML | $ROUNDTRIP,
          tml => <<'BLAH',
%IF{"X!=Y" then="z"}%
BLAH
          html => <<'BLAH',
<p>
<span class="WYSIWYG_PROTECTED">
%IF{&#34;X!=Y&#34;&nbsp;then=&#34;z&#34;}%
</span>
</p>
BLAH
      },
      {
          name => "Confused",
          exec => $HTML2TML,
          html => 'the <tt><tt>co</tt>mple<code>te</code></tt> table',
          tml => 'the =complete= table',
      },
      {
          name => 'fontconv',
          exec => $HTML2TML,
          html => <<HERE,
<font color="red" class="WYSIWYG_COLOUR">red</font>
<font style="color:green">green</font>
<font style="border:1;color:blue">blue</font>
<font class="WYSIWYG_COLOUR" style="border:1;color:yellow">yellow</font>
<font color="brown">brown</font>
HERE
          tml => <<HERE,
%RED%red%ENDCOLOR% %GREEN%green%ENDCOLOR% <font style="border:1;color:blue">blue</font> %YELLOW%yellow%ENDCOLOR% %BROWN%brown%ENDCOLOR%
HERE
      },
      {
          name => 'Item4974',
          exec => $HTML2TML,
          html => '<pre class="TMLverbatim">U<br></pre><p>L</p>',
          tml => <<HERE,
<verbatim>U
</verbatim>

L
HERE
      },
      {
          name => 'Item4969',
          exec => $HTML2TML,
          html => <<HERE,
<table cellspacing="1" cellpadding="0" border="1">
<tr><td>table element with a <hr /> horizontal rule</td></tr>
</table>
Mad Fish
HERE
          tml => '| table element with a <hr /> horizontal rule |
Mad Fish',
      },
      {
          name => 'Item5076',
          exec => $HTML2TML,
          html => <<HERE,
<table border="0"><tbody><tr><td><h2>Argh</h2><ul><li>Ergh&nbsp;</li></ul></td><td>&nbsp;</td></tr><tr><td>&nbsp;</td><td>&nbsp;</td></tr></tbody></table>
HERE
          tml => '<table border="0"><tbody><tr><td>
---++ Argh
   * Ergh 
</td><td> </td></tr><tr><td> </td><td> </td></tr></tbody></table>',
      },
      {
          name => 'Item5132',
          exec => $TML2HTML,
          html => <<HERE,
<h1 class="TML">  Title<img src="art1.jpg"> </img> </h1>
Peace in earth, and goodwill to all worms
HERE
            tml => <<HERE,
---+ Title<img src="art1.jpg"></img>
Peace in earth, and goodwill to all worms
HERE
      },
      {
          name => 'Item5179',
          exec => $TML2HTML | $HTML2TML,
          tml => <<HERE,
<smeg>
<verbatim>
<img src="ball&co<ck>s">&><"
</verbatim>
&&gt;&lt;"
HERE
          html => <<HERE,
<p>
<span class="WYSIWYG_PROTECTED">&#60;smeg&#62;</span>
<pre class="TMLverbatim"><br />&#60;img&nbsp;src=&#34;ball&#38;co&#60;ck&#62;s&#34;&#62;&#38;&#62;&#60;&#34;<br /></pre>
&&gt;&lt;"
</p>
HERE
          finaltml => <<HERE,
<smeg> <verbatim>
<img src="ball&co<ck>s">&><"
</verbatim> &&gt;&lt;"
HERE
      },
      {
          name => "Item5337",
          exec => $TML2HTML | $ROUNDTRIP,
          tml => <<HERE,
<pre>
hello
there
</pre>
HERE
          finaltml => <<HERE,
<pre>
hello
there
</pre>
HERE
          html => <<HERE,
<p>
<pre>
hello
there
</pre>
</p>
HERE
      },
      {
          name => 'Item5664',
          exec => $HTML2TML | $ROUNDTRIP,
          html => '<ul> <li> A </li> </ul> B',
          tml => <<HERE,
   * A
B
HERE
      },
      {
          name => "Item5961",
          exec => $HTML2TML | $ROUNDTRIP,
          html => 'o<strong>n</strong>e',
          html => ' <strong>zero</strong> <strong>on</strong>e t<strong>w</strong>o t<strong>re</strong>',
          tml => '*zero* <strong>on</strong>e t<strong>w</strong>o t<strong>re</strong>',
      },
      {
          name => "Item6089",
          exec => $TML2HTML,
          tml => <<'ZIS',
<verbatim>
line1\
line2
</verbatim>
ZIS
          html => <<'ZAT',
<p>
<pre class="TMLverbatim"><br />line1\<br />line2<br /></pre>
</p>
ZAT
      },
     ];

sub gen_compare_tests {
    my %picked = map { $_ => 1 } @_;
    for (my $i = 0; $i < scalar(@$data); $i++) {
        my $datum = $data->[$i];
        if (scalar(@_)) {
            next unless( $picked{$datum->{name}} );
        }
        if (($mask & $datum->{exec}) & $TML2HTML) {
            my $fn = 'TranslatorTests::testTML2HTML_'.$datum->{name};
            no strict 'refs';
            *$fn = sub { my $this = shift; $this->compareTML_HTML( $datum ) };
            use strict 'refs';
        }
        if (($mask & $datum->{exec}) & $HTML2TML) {
            my $fn = 'TranslatorTests::testHTML2TML_'.$datum->{name};
            no strict 'refs';
            *$fn = sub { my $this = shift; $this->compareHTML_TML( $datum ) };
            use strict 'refs';
        }
        if (($mask & $datum->{exec}) & $ROUNDTRIP) {
            my $fn = 'TranslatorTests::testROUNDTRIP_'.$datum->{name};
            no strict 'refs';
            *$fn = sub { my $this = shift; $this->compareRoundTrip( $datum ) };
            use strict 'refs';
        }
    }
}

# Run from BEGIN
sub gen_file_tests {
    foreach my $d (@INC) {
        if (-d "$d/test_html" && $d =~ /WysiwygPlugin/) {
            opendir( D, "$d/test_html" ) or die;
            foreach my $file (grep { /^.*\.html$/i } readdir D ) {
                $file =~ s/\.html$//;
                my $test = { name => $file };
                open(F, "<$d/test_html/$file.html");
                undef $/;
                $test->{html} = <F>;
                close(F);
                next unless -e "$d/result_tml/$file.txt";
                open(F, "<$d/result_tml/$file.txt");
                undef $/;
                $test->{finaltml} = <F>;
                close(F);
                my $fn = 'TranslatorTests::test_HTML2TML_FILE_'.$test->{name};
                no strict 'refs';
                *$fn = sub { shift->compareHTML_TML( $test ) };
                use strict 'refs';
            }
            last;
        }
    }
}

sub set_up {
    my $this = shift;
    $this->SUPER::set_up(@_);
    $TWiki::cfg{Plugins}{WysiwygPlugin}{Enabled} = 1;

    my $query;
    eval {
        require Unit::Request;
        require Unit::Response;
        $query = new Unit::Request("");
    };
    if ($@) {
        $query = new CGI("");
    }
    $query->path_info("/Current/TestTopic");
    $this->{twiki} = new TWiki(undef, $query);
    $TWiki::Plugins::SESSION = $this->{twiki};
}

use HTML::Diff;

sub normaliseEntities {
    my $text = shift;
    # Convert text entities to &# representation
    $text =~ s/(&\w+;)/'&#'.ord(HTML::Entities::decode_entities($1)).';'/ge;
    return $text;
}

sub compareTML_HTML {
    my ( $this, $args ) = @_;

    my $page = $this->{twiki}->getScriptUrl(1, 'view', 'Current', 'TestTopic');
    $page =~ s/\/Current\/TestTopic.*$//;
    my $html = $args->{html}||''; $html =~ s/%!page!%/$page/g;
    my $finaltml = $args->{finaltml}||''; $finaltml =~ s/%!page!%/$page/g;
    my $tml = $args->{tml}||''; $tml =~ s/%!page!%/$page/g;

    my $txer = new TWiki::Plugins::WysiwygPlugin::TML2HTML();
    my $tx = $txer->convert(
        $tml,
        {
            web => 'Current', topic => 'TestTopic',
            getViewUrl => \&TWiki::Plugins::WysiwygPlugin::getViewUrl,
            expandVarsInURL => \&TWiki::Plugins::WysiwygPlugin::expandVarsInURL,
        });

    $this->assert_html_equals($html, $tx);
}

sub compareRoundTrip {
    my ( $this, $args ) = @_;
    my $page = $this->{twiki}->getScriptUrl(1, 'view', 'Current', 'TestTopic');
    $page =~ s/\/Current\/TestTopic.*$//;

    my $tml = $args->{tml}||'';
    $tml =~ s/%!page!%/$page/g;

    my $txer = new TWiki::Plugins::WysiwygPlugin::TML2HTML();
    my $html = $txer->convert(
        $tml,
        {
            web => 'Current', topic => 'TestTopic',
            getViewUrl => \&TWiki::Plugins::WysiwygPlugin::getViewUrl,
            expandVarsInURL => \&TWiki::Plugins::WysiwygPlugin::expandVarsInURL,
        });

    $txer = new TWiki::Plugins::WysiwygPlugin::HTML2TML();
    my $tx = $txer->convert(
        $html,
        {
            web => 'Current', topic => 'TestTopic',
            convertImage => \&convertImage,
            rewriteURL => \&TWiki::Plugins::WysiwygPlugin::postConvertURL,
        });
    my $finaltml = $args->{finaltml} || $tml;
    $finaltml =~ s/%!page!%/$page/g;
    $this->_assert_tml_equals($finaltml, $tx, $args->{name});
}

sub compareHTML_TML {
    my ( $this, $args ) = @_;

    my $page = $this->{twiki}->getScriptUrl(1, 'view', 'Current', 'TestTopic');
    $page =~ s/\/Current\/TestTopic.*$//;
    my $html = $args->{html}||'';
    $html =~ s/%!page!%/$page/g;
    my $tml = $args->{tml}||'';
    $tml =~ s/%!page!%/$page/g;
    my $finaltml = $args->{finaltml} || $tml;
    $finaltml =~ s/%!page!%/$page/g;

    my $txer = new TWiki::Plugins::WysiwygPlugin::HTML2TML();
    my $tx = $txer->convert(
        $html,
        {
            web => 'Current', topic => 'TestTopic',
            convertImage => \&convertImage,
            rewriteURL => \&TWiki::Plugins::WysiwygPlugin::postConvertURL,
        });
    $this->_assert_tml_equals($finaltml, $tx, $args->{name});
}

sub encode {
    my $s = shift;
    # used for debugging odd chars
    #    $s =~ s/([\000-\037])/'#'.ord($1)/ge;
    return $s;
}

sub _assert_tml_equals {
    my( $this, $expected, $actual, $name ) = @_;
    $expected ||= '';
    $actual ||= '';
    $actual =~ s/\n$//s;
    $expected =~ s/\n$//s;
    unless( $expected eq $actual ) {
        my $expl =
            "==$name== Expected TML:\n".encode($expected).
                "\n==$name== Actual TML:\n".encode($actual).
                      "\n==$name==\n";
        my $i = 0;
        while( $i < length($expected) && $i < length($actual)) {
            my $e = substr($expected,$i,1);
            my $a = substr($actual,$i,1);
            if( $a ne $e) {
                $expl .= "<<==== HERE actual ";
                $expl .= ord($a)." != expected ".ord($e)."\n";
                last;
            }
            $expl .= $a;
            $i++;
        }
        $this->assert(0, $expl."\n");
    }
}

sub convertImage {
    my $url = shift;

    if ($url eq "test_image") {
        return '%TRANSLATEDIMAGE%';
    }
}

gen_compare_tests();
#gen_file_tests();

1;
