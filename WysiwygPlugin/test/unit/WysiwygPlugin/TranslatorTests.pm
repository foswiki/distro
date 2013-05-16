# See bottom of file for license and copyright information

# tests for the two translators, TML to HTML and HTML to TML, that
# support editing using WYSIWYG HTML editors. The tests are designed
# so that the round trip can be verified in as many cases as possible.
# Readers are invited to add more testcases.
#
# The tests require FOSWIKI_LIBS to include a pointer to the lib
# directory of a Foswiki installation, so it can pick up the bits
# of Foswiki it needs to include.
#
package TranslatorTests;
use FoswikiTestCase;
use TranslatorBase;
our @ISA = qw( FoswikiTestCase TranslatorBase );

use strict;
use warnings;

require Foswiki::Plugins::WysiwygPlugin;
require Foswiki::Plugins::WysiwygPlugin::TML2HTML;
require Foswiki::Plugins::WysiwygPlugin::HTML2TML;

# Bits for test type
# Fields in test records:
my $TML2HTML      = 1 << 0;    # test tml => html
my $HTML2TML      = 1 << 1;    # test html => finaltml (default tml)
my $ROUNDTRIP     = 1 << 2;    # test tml => => finaltml
my $CANNOTWYSIWYG = 1 << 3;    # test that notWysiwygEditable returns true
                               #   and make the ROUNDTRIP test expect failure

# Note: ROUNDTRIP is *not* the same as the combination of
# HTML2TML and TML2HTML. The HTML and TML comparisons are both
# somewhat "flexible". This is necessary because, for example,
# the nature of whitespace in the TML may change.
# ROUNDTRIP tests are intended to isolate gradual degradation
# of the TML, where TML -> HTML -> not quite TML -> HTML
# -> even worse TML, ad nauseum
#
# CANNOTWYSIWYG should normally be used in conjunction with ROUNDTRIP
# to ensure that notWysiwygEditable is consistent with this plugin's
# ROUNDTRIP capabilities.
#
# CANNOTWYSIWYG and ROUNDTRIP used together document the failure cases,
# i.e. they indicate TML that WysiwygPlugin cannot properly translate
# to HTML and back. When WysiwygPlugin is modified to support these
# cases, CANNOTWYSIWYG should be removed from each corresponding
# test case and nonWysiwygEditable should be updated so that the TML
# is "WysiwygEditable".
#
# Use CANNOTWYSIWYG without ROUNDTRIP *only* with an appropriate
# explanation. For example:
#   Can't ROUNDTRIP this TML because perl on the SMURF platform
#   automagically replaces all instances of 'blue' with 'beautiful'.

# Bit mask for selected test types
my $mask = $TML2HTML | $HTML2TML | $ROUNDTRIP | $CANNOTWYSIWYG;

my $protecton  = '<span class="WYSIWYG_PROTECTED">';
my $linkon     = '<span class="WYSIWYG_LINK">';
my $protectoff = '</span>';
my $linkoff    = '</span>';
my $preoff     = '</span>';
my $nop        = "$protecton<nop>$protectoff";
my $deleteme   = '<p class="foswikiDeleteMe">&nbsp;</p>';

my $trailingSpace = ' ';

# The following big table contains all the testcases. These are
# used to add a bunch of functions to the symbol table of this
# testcase, so they get picked up and run by TestRunner.

# Each testcase is a subhash with fields as follows:
# exec => $TML2HTML to test TML -> HTML, $HTML2TML to test HTML -> TML,
#   $ROUNDTRIP to test TML-> ->TML, $CANNOTWYSIWYG to test
#   notWysiwygEditable, all other bits are ignored.
#   They may be OR'd togoether to perform multiple tests.
#   For example: $TML2HTML | $HTML2TML to test both
#   TML -> HTML and HTML -> TML
# name => identifier (used to compose the testcase function name)
# tml => source topic meta-language
# html => expected html from expanding tml (not used in roundtrip tests)
# finaltml => optional expected tml from translating html. If not there,
# will use tml. Only use where round-trip can't be closed because
# we are testing deprecated syntax.
# pref => 'VARIABLE=setting'  A single preference setting will be applied
# when the test is initialized. Used in the %COLOR% tests to set older versions
# of color encoding;  font, style or class.
my $data = [
    {
        exec => $TML2HTML | $HTML2TML,
        name => 'Pling',
        tml  => 'Move !ItTest/site/ToWeb5 leaving web5 as !MySQL host',
        html => <<HERE,
<p>
Move !ItTest/site/ToWeb5 leaving web5 as !MySQL host
</p>
HERE
    },
    {
        exec => $ROUNDTRIP,
        name => 'linkAtStart',
        tml  => 'LinkAtStart',
        html => $linkon . 'LinkAtStart' . $linkoff,
    },
    {
        exec => $ROUNDTRIP,
        name => 'otherWebLinkAtStart',
        tml  => 'OtherWeb.LinkAtStart',
        html => $linkon . 'OtherWeb.LinkAtStart' . $linkoff,
    },
    {
        exec => $ROUNDTRIP,
        name => 'currentWebLinkAtStart',
        tml  => 'Current.LinkAtStart',
        html => $linkon . 'Current.LinkAtStart' . $linkoff,
    },
    {
        exec => $ROUNDTRIP,
        name => 'simpleParas',
        html => '1st paragraph<p />2nd paragraph',
        tml  => <<'HERE',
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
        tml  => '*Bold*
'
    },
    {
        exec => $ROUNDTRIP,
        name => 'strongLink',
        html => <<HERE,
<b>reminded about${linkon}http://www.koders.com${linkoff}</b>
HERE
        tml => '*reminded about http://www.koders.com*',
    },
    {
        exec => $ROUNDTRIP,
        name => 'simpleItalic',
        html => '<i>Italic</i>',
        tml  => '_Italic_',
    },
    {
        exec => $ROUNDTRIP,
        name => 'boldItalic',
        html => '<b><i>Bold italic</i></b>',
        tml  => '__Bold italic__',
    },
    {
        exec => $ROUNDTRIP,
        name => 'simpleCode',
        html => '<code>Code</code>',
        tml  => '=Code='
    },
    {
        name => 'codeInParentheses',
        exec => $TML2HTML | $ROUNDTRIP,
        tml  => "start (='^'=) to end",
        html => <<'BLAH',
<p>
start (<span class="WYSIWYG_TT"> '^' </span>) to end
</p>
BLAH
    },
    {
        exec => $TML2HTML | $HTML2TML,
        name => 'codeToFromHtml',
        html => <<'BLAH',
<p>
<span class="WYSIWYG_TT">&Alpha; Code</span>
</p>
BLAH
        tml => '=&Alpha; Code='
    },
    {
        exec => $ROUNDTRIP,
        name => 'strongCode',
        html => '<b><code>Bold Code</code></b>',
        tml  => '==Bold Code=='
    },
    {
        exec => $TML2HTML | $HTML2TML,
        name => 'bToFromHtml',
        html => '<p><b>Bold</b></p>',
        tml  => '*Bold*'
    },
    {
        exec => $TML2HTML | $HTML2TML,
        name => 'strongCodeToFromHtml',
        html => <<'BLAH',
<p>
<b><span class="WYSIWYG_TT">Code</span></b>
</p>
BLAH
        tml => '==Code=='
    },
    {
        exec => $HTML2TML,
        name => 'spanWithTtClassWithStrong',
        html => <<'BLAH',
<p>
<span class="WYSIWYG_TT"><strong>Code</strong></span>
</p>
BLAH
        tml => '==Code=='
    },
    {
        exec => $HTML2TML,
        name => 'strongWithSpanWithTtClass',
        html => <<'BLAH',
<p>
<strong><span class="WYSIWYG_TT">Code</span></strong>
</p>
BLAH
        tml => '==Code=='
    },
    {
        exec => $HTML2TML,
        name => 'strongWithTtClass',
        html => <<'BLAH',
<p>
<strong class="WYSIWYG_TT">Code</strong>
</p>
BLAH
        tml => '==Code=='
    },
    {
        exec => $HTML2TML | $ROUNDTRIP,
        name => 'strongWithTtAndColorClasses',
        html => <<'BLAH',
<p>
<strong class="WYSIWYG_TT WYSIWYG_COLOR" style="color:#FF0000;">Code</strong>
</p>
BLAH
        tml => '*%RED% =Code= %ENDCOLOR%*'
    },
    {
        exec => $HTML2TML,
        name => 'bWithTtClass',
        html => "<p>\n<b class=\"WYSIWYG_TT\">Code</b>\n</p>",
        tml  => '==Code=='
    },
    {
        exec => $HTML2TML,
        name => 'ttClassInTable',
        html => '<table><tr><td class="WYSIWYG_TT">Code</td></tr></table>',
        tml  => '| =Code= |'
    },
    {
        exec => $HTML2TML,
        name => 'ttClassAndPInTable',
        html =>
          '<table><tr><td class="WYSIWYG_TT"><p>Code</p></td></tr></table>',
        tml => '| =Code= |'
    },
    {
        exec => $HTML2TML,
        name => 'ttClassPInTable',
        html =>
          '<table><tr><td><p class="WYSIWYG_TT">Code</p></td></tr></table>',
        tml => '| =Code= |'
    },
    {
        exec => $TML2HTML | $ROUNDTRIP,
        name => 'Item11925_spuriousTT3',
        tml  => <<'HERE',
   * %IF{"%CALC{"$EXISTS(%TOPIC%Checklist)"}% " then= '[[%TOPIC%Checklist][Checklist]]' else= ' <form name="new" action="%SCRIPTURLPATH{"edit"}%/%WEB%/">
<input type="hidden" name="topic" value="%TOPIC%Checklist"  />
<input type="hidden" name="templatetopic" value="BracketTestTopicTemplate" />
<input type="hidden" name="onlywikiname" value="on" />
<input type="hidden" name="onlynewtopic" value="on" /> 
<input type="submit"  class="foswikiSubmit"  value="Create" />
</form> Checklist' "}%
HERE
        html => <<'HERE',
<ul>
<li> <span class="WYSIWYG_PROTECTED">%IF{&#34;%CALC{&#34;$EXISTS(%TOPIC%Checklist)&#34;}%&nbsp;&#34;&nbsp;then=&nbsp;&#39;[[%TOPIC%Checklist][Checklist]]&#39;&nbsp;else=&nbsp;&#39;&nbsp;&#60;form&nbsp;name=&#34;new&#34;&nbsp;action=&#34;%SCRIPTURLPATH{&#34;edit&#34;}%/%WEB%/&#34;&#62;<br />&#60;input&nbsp;type=&#34;hidden&#34;&nbsp;name=&#34;topic&#34;&nbsp;value=&#34;%TOPIC%Checklist&#34;&nbsp;&nbsp;/&#62;<br />&#60;input&nbsp;type=&#34;hidden&#34;&nbsp;name=&#34;templatetopic&#34;&nbsp;value=&#34;BracketTestTopicTemplate&#34;&nbsp;/&#62;<br />&#60;input&nbsp;type=&#34;hidden&#34;&nbsp;name=&#34;onlywikiname&#34;&nbsp;value=&#34;on&#34;&nbsp;/&#62;<br />&#60;input&nbsp;type=&#34;hidden&#34;&nbsp;name=&#34;onlynewtopic&#34;&nbsp;value=&#34;on&#34;&nbsp;/&#62;&nbsp;<br />&#60;input&nbsp;type=&#34;submit&#34;&nbsp;&nbsp;class=&#34;foswikiSubmit&#34;&nbsp;&nbsp;value=&#34;Create&#34;&nbsp;/&#62;<br />&#60;/form&#62;&nbsp;Checklist&#39;&nbsp;&#34;}%</span>
</li>
</ul>
HERE
    },
    {
        exec => $TML2HTML | $ROUNDTRIP,
        name => 'tmlInTable',
        html => <<"BLAH",
$deleteme<table cellspacing="1" cellpadding="0" border="1">
<tr><td> <span class="WYSIWYG_TT">Code</span> </td></tr>
<tr><td> <span class="WYSIWYG_TT">code</span> at start</td></tr>
<tr><td>ends with <span class="WYSIWYG_TT">code</span> </td></tr>

<tr><td> <b><span class="WYSIWYG_TT">Code</span></b> </td></tr>
<tr><td> <b><span class="WYSIWYG_TT">code</span></b> at start</td></tr>
<tr><td>ends with <b><span class="WYSIWYG_TT">code</span></b> </td></tr>

<tr><td> <i>Emphasis</i> </td></tr>
<tr><td> <i>emphasis</i> at start</td></tr>
<tr><td>ends with <i>emphasis</i> </td></tr>

<tr><td> <b><i>Emphasis</i></b> </td></tr>
<tr><td> <b><i>emphasis</i></b> at start</td></tr>
<tr><td>ends with <b><i>emphasis</i></b> </td></tr>

<tr><td> <b>bold</b> at start</td></tr>
<tr><td>ends with <b>bold</b> </td></tr>
</table>
BLAH
        tml => <<'BLAH',
| =Code= |
| =code= at start |
| ends with =code= |
| ==Code== |
| ==code== at start |
| ends with ==code== |
| _Emphasis_ |
| _emphasis_ at start |
| ends with _emphasis_ |
| __Emphasis__ |
| __emphasis__ at start |
| ends with __emphasis__ |
| *bold* at start |
| ends with *bold* |
BLAH
    },
    {
        exec => $HTML2TML,
        name => 'pInTable',
        html => <<'HTML',
<table>
<tr><td><p>X Y</p></td></tr>
<tr><td> <p>X Y</p> </td></tr>
<tr><td>X<p> Y</p></td></tr>
<tr><td><p>X</p><p>Y</p></td></tr>
</table>
HTML
        tml => <<'TML',
| X Y |
| X Y |
| X<p> Y</p> |
| <p>X</p><p>Y</p> |
TML
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
        exec => $TML2HTML | $HTML2TML | $ROUNDTRIP,
        name => 'embeddedBR_Item11859',
        tml  => <<'HERE',
Line 1<br>Line 2<br />
Line 3
HERE
        finaltml => <<'HERE',
Line 1<br />Line 2<br />
Line 3
HERE
        html => <<'HERE',
<p>Line 1<br>Line 2<br /><span style="{encoded:'n'}" class="WYSIWYG_HIDDENWHITESPACE">&nbsp;</span>Line 3
</p>
HERE
    },
    {
        exec => $TML2HTML | $HTML2TML | $ROUNDTRIP,
        name => 'hiddenVerbatim',
        tml  => <<'HERE',
<verbatim class="foswikiHidden">
hidden verbatim
</verbatim>
HERE
        html => <<"HERE",
$deleteme<p><pre class=\"foswikiHidden TMLverbatim\"><br />hidden&nbsp;verbatim<br /></pre>
</p>
HERE
    },
    {

        # SMELL: This test will fail if run through TMCE Editor.
        # TMCE removes the surrounding <p>..</p> tags which
        # looses the whitespace, and the tags are merged by HTML2TML.
        exec => $TML2HTML | $HTML2TML | $ROUNDTRIP,
        name => 'consecutiveVerbatim',
        tml  => <<'HERE',
<verbatim>
verbatim 1
</verbatim>

<verbatim>
verbatim 2
</verbatim>
HERE
        html => <<"HERE",
$deleteme<p><pre class=\"TMLverbatim\"><br />verbatim&nbsp;1<br /></pre>
</p>
<p><pre class=\"TMLverbatim\"><br />verbatim&nbsp;2<br /></pre>
</p>
HERE
    },
    {
        exec => $ROUNDTRIP | $TML2HTML | $HTML2TML,
        name => 'preserveClass',
        html => <<"HERE",
$deleteme<p><pre class=\"foswikiHidden TMLverbatim\"><br />Verbatim&nbsp;1<br />Line&nbsp;2<br />Line&nbsp;3</pre> <pre class=\"html tml TMLverbatim\"><br />Verbatim&nbsp;2<br /><br /></pre><span style=\"{encoded:'n'}\" class=\"WYSIWYG_HIDDENWHITESPACE\">&nbsp;</span><pre class=\"tml html TMLverbatim\"><br /><br />Verbatim&nbsp;3</pre>
</p>
HERE
        tml => <<'HERE',
<verbatim class="foswikiHidden">
Verbatim 1
Line 2
Line 3</verbatim> <verbatim class="html tml">
Verbatim 2

</verbatim>
<verbatim class="tml html">

Verbatim 3</verbatim>
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
        html =>
'<pre class="TMLverbatim"><br />Before&nbsp;&amp;nbsp;&nbsp;After<br /></pre>',
        tml => '<verbatim>
Before &nbsp; After
</verbatim>',
    },
    {
        exec => $ROUNDTRIP | $TML2HTML,
        name => 'simpleHR',
        html =>
'<hr class="TMLhr"/><hr class="TMLhr" style="{numdashes:7}"/><p>--</p>',
        tml => <<'HERE',
---
-------
--

HERE
        finaltml => <<'HERE',
---
-------

--
HERE
    },

    {
        exec => $ROUNDTRIP,
        name => 'centering',
        html => <<'HERE',
<center>Center Text</center><br /> <div style="text-align:center">TEST Centered text.</div> 

Not Centered

<div align="center">TEST Centered text.</div>
HERE
        tml => <<'HERE',
<center>Center Text</center><br /> <div style="text-align:center">TEST Centered text.</div> 

Not Centered

<div align="center">TEST Centered text.</div>
HERE
        finaltml => <<'HERE',
<center>Center Text</center><br /> <div style="text-align:center">TEST Centered text.</div>

Not Centered

<div align="center">TEST Centered text.</div>
HERE
    },

    {
        exec => $ROUNDTRIP,
        name => 'simpleBullList',
        html => 'Before<ul><li>bullet item</li></ul>After',
        tml  => <<'HERE',
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
        exec => $TML2HTML | $ROUNDTRIP,
        name => 'orderedList_Item1341',
        html => <<'HERE',
<ol><li>Sushi</li><li>Banana</li></ol><p class="WYSIWYG_NBNL"/>
<ol><li type="A">Sushi</li><li type="A">Banana</li></ol><p class="WYSIWYG_NBNL"/>
<ol><li type="i">Sushi</li><li type="i">Banana</li></ol><p class="WYSIWYG_NBNL"/>
<ol><li type="I">Sushi</li><li type="I">Banana</li></ol><p class="WYSIWYG_NBNL"/>
<ol><li>Sushi</li><li type="A">Sushi</li><li type="i">Sushi</li></ol>
HERE
        tml => <<'HERE',
   1 Sushi
   1 Banana

   A. Sushi
   A. Banana

   i. Sushi
   i. Banana

   I. Sushi
   I. Banana

   1 Sushi
   A. Sushi
   i. Sushi
HERE
    },
    {
        name => 'emptyListItems_Item2605',
        exec => $TML2HTML | $ROUNDTRIP,
        tml  => <<'TML',
   *
   * alpha
   *
   * beta
   *

   1
   2 charlie
   3 

   i. angel
   i.
blah
TML
        html => <<'HTML',
<ul><li>&nbsp;</li><li>alpha</li><li>&nbsp;</li><li>beta</li><li>&nbsp;</li></ul>
<p class="WYSIWYG_NBNL"/>
<ol><li>&nbsp;</li><li>charlie</li><li>&nbsp;</li></ol>
<p class="WYSIWYG_NBNL"/>
<ol><li type="i">angel</li><li type="i">&nbsp;</li></ol>
<p>blah</p>
HTML
        finaltml => <<"TML",
   *$trailingSpace
   * alpha
   *$trailingSpace
   * beta
   *$trailingSpace

   1$trailingSpace
   1 charlie
   1$trailingSpace

   i. angel
   i.$trailingSpace
blah
TML
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
        exec => $ROUNDTRIP | $TML2HTML | $HTML2TML,
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
        name => 'indentColon',
        html => <<'HERE',
<p>Grim
<div class='foswikiIndent'>
 Snowy
 <div class='foswikiIndent'>
  Slushy
  <div class='foswikiIndent'>
   Rainy
  </div>
 </div>
 <div class='foswikiIndent'>
  Dry
 </div>
</div>
<div class='foswikiIndent'>
 Sunny
</div>
<span class=WYSIWYG_HIDDENWHITESPACE style={encoded:'n'}>
</span>Pleasant
</p>
HERE
        tml => <<'HERE',
Grim
   : Snowy
      : Slushy
         : Rainy
      : Dry
   : Sunny
Pleasant
HERE
        finaltml => <<'HERE',
Grim
   : Snowy
      : Slushy
         : Rainy
      : Dry
   : Sunny
Pleasant
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
        exec => 0,    # disabled because of Kupu problems handling colspans
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
        exec => $TML2HTML | $HTML2TML | $ROUNDTRIP,
        name => 'centeredTableItem5955',
        html => <<"HTML",
$deleteme
<table align="center" border="0"><tbody><tr><td> asdf</td><td>dddd <br /></td></tr><tr><td> next one empty<br /></td><td> </td></tr></tbody></table>
HTML
        tml => <<'TML',
<table align="center" border="0"><tbody><tr><td> asdf</td><td>dddd <br /></td></tr><tr><td> next one empty<br /></td><td> </td></tr></tbody></table>
TML
    },
    {
        exec => $TML2HTML | $ROUNDTRIP,
        name => 'literalTableFirst',
        html => <<"HTML",                 # SMELL: not valid HTML
$deleteme<p>
<div class="WYSIWYG_LITERAL"><table border='0'><tbody><tr><td> asdf</td></tr></tbody></table></div>
</p>
HTML
        tml => <<'TML',
<literal><table border='0'><tbody><tr><td> asdf</td></tr></tbody></table></literal>
TML
    },
    {
        exec     => $TML2HTML | $ROUNDTRIP,
        name     => 'escapedWikiword',
        html     => '<p>!SunOS</p>',
        tml      => '!SunOS',
        finaltml => '!SunOS',
    },
    {
        exec => $TML2HTML | $ROUNDTRIP,
        name => 'noppedWikiword',
        html => <<HERE,
<p><span class="WYSIWYG_PROTECTED">&#60;nop&#62;</span>SunOS
</p>
HERE
        tml      => '<nop>SunOS',
        finaltml => '<nop>SunOS',
    },
    {
        exec => $HTML2TML,
        name => 'noppedPara',
        html => "${nop}BeFore ${nop}SunOS ${nop}AfTer",
        tml  => '<nop>BeFore <nop>SunOS <nop>AfTer',
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
        exec => $HTML2TML | $TML2HTML | $ROUNDTRIP,
        name => 'setNOAUTOLINK',
        pref => 'NOAUTOLINK=1',
        tml  => <<'HERE',
RedHat & SuSE
HERE
        html => <<'HERE',
<p>RedHat & SuSE
</p>
HERE
    },
    {
        exec => $HTML2TML | $TML2HTML | $ROUNDTRIP,
        name => 'noAutoLunk',
        html => <<'HERE',
<p><span class="WYSIWYG_PROTECTED">&#60;noautolink&#62;</span><span style="{encoded:'n'}" class="WYSIWYG_HIDDENWHITESPACE">&nbsp;</span>RedHat & SuSE<span style="{encoded:'n'}" class="WYSIWYG_HIDDENWHITESPACE">&nbsp;</span><span class="WYSIWYG_PROTECTED">&#60;/noautolink&#62;</span>
</p>
HERE
        tml => <<'HERE',
<noautolink>
RedHat & SuSE
</noautolink>
HERE
    },
    {
        exec => $ROUNDTRIP | $TML2HTML | $HTML2TML,
        name => 'nestedDiv_Item11872',
        tml  => <<HERE,
<div class="foswikiHelp">
<div class="jqTreeview">
   * list
      * item
      * item
      * item
</div>
</div>
HERE
        html => <<HERE,
$deleteme<div class="foswikiHelp TMLhtml">
<span style="{encoded:'n'}" class="WYSIWYG_HIDDENWHITESPACE">&nbsp;</span><div class="jqTreeview TMLhtml">
<ul>
<li> list
<ul>
<li> item
</li>
<li> item
</li>
<li> item
</li>
</ul>
</li>
</ul><span style="{encoded:'n'}" class="WYSIWYG_HIDDENWHITESPACE">&nbsp;</span></div><span style="{encoded:'n'}" class="WYSIWYG_HIDDENWHITESPACE">&nbsp;</span></div>
HERE
    },
    {
        exec => $ROUNDTRIP | $TML2HTML | $HTML2TML,
        name => 'jqTreeview_Item11872',
        tml  => <<HERE,
<div class="jqTreeview">
   * list
      * item
      * item
      * item
</div>
blah
HERE
        html => <<HERE,
$deleteme<div class="jqTreeview TMLhtml">
<ul>
<li> list
<ul>
<li> item
</li>
<li> item
</li>
<li> item
</li>
</ul>
</li>
</ul><span style="{encoded:'n'}" class="WYSIWYG_HIDDENWHITESPACE">&nbsp;</span></div>
<p>blah
</p>
HERE
        finaltml => <<'HERE',
<div class="jqTreeview">
   * list
      * item
      * item
      * item
</div>

blah
HERE
    },
    {
        exec => $ROUNDTRIP,
        name => 'mailtoLink',
        html => <<HERE,
$linkon\[[mailto:a\@z.com][Mail]]${linkoff} $linkon\[[mailto:?subject=Hi][Hi]]${linkoff}
HERE
        tml      => '[[mailto:a@z.com][Mail]] [[mailto:?subject=Hi][Hi]]',
        finaltml => <<'HERE',
[[mailto:a@z.com][Mail]] [[mailto:?subject=Hi][Hi]]
HERE
    },

    {
        exec => $ROUNDTRIP | $TML2HTML,
        name => 'corruptedTable_Item11915',
        tml  => <<'HERE',
|  A | B |
|  A1 | B1 %BR%\
        C1  |
|  A2 | B2 |
HERE
        html => <<'HERE',
<p class="foswikiDeleteMe">&nbsp;</p><table cellspacing="1" cellpadding="0" border="1">
<tr><td style="text-align: right" class="align-right"> A </td><td> B </td></tr>
<tr><td style="text-align: right" class="align-right"> A1 </td><td style="text-align: left" class="align-left"> B1 <span class="WYSIWYG_PROTECTED">%BR%</span><span style="{encoded:'bn'}" class="WYSIWYG_HIDDENWHITESPACE">&nbsp;</span>        C1 </td></tr>
<tr><td style="text-align: right" class="align-right"> A2 </td><td> B2 </td></tr>
</table>
HERE
        finaltml => <<'HERE',
|  A | B |
|  A1 | B1 %BR%\
C1  |
|  A2 | B2 |
HERE
    },

    {
        exec => $ROUNDTRIP | $TML2HTML,
        name => 'corruptedLinks_Item11906',
        tml  => <<'HERE',
   * [[%WIKIUSERNAME%][My home page]]
   * [[%SCRIPTURL{search}%/%BASEWEB%/?search=%WIKINAME%;order=modified;limit=50;reverse=on][My %BASEWEB% activities]]

<a class="foswikiSmallish" href="%SCRIPTURLPATH{"edit"}%/%WEB%/%TOPIC%?t=%GM%NOP%TIME{"$epoch"}%">edit</a>
HERE
        html => <<'HERE',
<ul>
<li> <a class="TMLlink" href="%WIKIUSERNAME%">My home page</a>
</li>
<li> <a class="TMLlink" href="%SCRIPTURL{search}%/%BASEWEB%/?search=%WIKINAME%;order=modified;limit=50;reverse=on">My <span class="WYSIWYG_PROTECTED WYSIWYG_PROTECTED">%BASEWEB%</span> activities</a>
</li>
</ul>
<p class='WYSIWYG_NBNL'><span class="WYSIWYG_PROTECTED">&#60;a&nbsp;class=&#34;foswikiSmallish&#34;&nbsp;href=&#34;%SCRIPTURLPATH{&#34;edit&#34;}%/%WEB%/%TOPIC%?t=%GM%NOP%TIME{&#34;$epoch&#34;}%&#34;&#62;edit&#60;/a&#62;</span>
</p>
HERE
    },

    # SMELL: No idea why we decode links,  but verify that it works anyway.
    #    {
    #        exec => $ROUNDTRIP | $TML2HTML | $HTML2TML,
    #        name => 'decodeWebTopic_Item11814',
    #        tml  => <<'HERE',
    #<a href="Main.WebHom%65">hi</a>
    #HERE
    #        html => <<'HERE',
    #<p><a href="Main.WebHom%65">hi</a>
    #</p>
    #HERE
    #        finaltml => <<'HERE',
    #[[Main.WebHome][hi]]
    #HERE
    #    },
    {
        exec => $ROUNDTRIP | $TML2HTML | $HTML2TML,
        name => 'mailtoLink_Item11814',
        tml  => <<'HERE',
<a href="mailto:a@example.org?subject=Hi&body=Hi%21%0A%0ABye%21">hi</a>
HERE
        html => <<'HERE',
<p><a href="mailto:a@example.org?subject=Hi&body=Hi%21%0A%0ABye%21">hi</a>
</p>
HERE
        finaltml => <<'HERE',
[[mailto:a@example.org?subject=Hi&body=Hi%21%0A%0ABye%21][hi]]
HERE
    },
    {
        exec => $ROUNDTRIP | $TML2HTML | $HTML2TML,
        name => 'obsoleteSquabLink',
        tml  => <<'HERE',
[[https://example.com Link *text* here]]
HERE
        html => <<'HERE',
<p><a class='TMLlink' href="https://example.com">Link <b>text</b> here</a>
</p>
HERE
        finaltml => <<'HERE',
[[https://example.com][Link *text* here]]
HERE
    },
    {
        exec => $ROUNDTRIP | $TML2HTML | $HTML2TML,
        name => 'mailtoLink_Item11814b',
        tml  => <<'HERE',
<a href="mailto:a@example.org?subject=Hi[joe]&body=Hi%21%0A%0ABye%21">hi</a>
HERE
        html => <<'HERE',
<p><a href="mailto:a@example.org?subject=Hi[joe]&body=Hi%21%0A%0ABye%21">hi</a>
</p>
HERE
        finaltml => <<'HERE',
[[mailto:a@example.org?subject=Hi%5Bjoe%5D&body=Hi%21%0A%0ABye%21][hi]]
HERE
    },
    {
        exec => $ROUNDTRIP | $TML2HTML | $HTML2TML,
        name => 'protect_glue',
        tml  => <<'HERE',
%~~ SEARCH{
~~~ search="META:FORM.*?ApplicationForm" 
~~~ topic="XYZ*" nosearch="on" nototal="on" regex="on" noheader="on" 
~~~ excludetopic="%TOPIC%"
~~~ }%
HERE
        html => <<'HERE',
<p><span class="WYSIWYG_PROTECTED">%~~&nbsp;SEARCH{<br />~~~&nbsp;search=&#34;META:FORM.*?ApplicationForm&#34;&nbsp;<br />~~~&nbsp;topic=&#34;XYZ*&#34;&nbsp;nosearch=&#34;on&#34;&nbsp;nototal=&#34;on&#34;&nbsp;regex=&#34;on&#34;&nbsp;noheader=&#34;on&#34;&nbsp;<br />~~~&nbsp;excludetopic=&#34;%TOPIC%&#34;<br />~~~&nbsp;}%</span>
</p>
HERE
    },
    {
        exec => $ROUNDTRIP,
        name => 'mailtoLink2',
        html => ' a@z.com ',
        tml  => 'a@z.com',
    },
    {
        exec => $TML2HTML | $ROUNDTRIP,
        name => 'variousWikiWords',
        html => <<"XXX",
<p><a data-wikiword="WebPreferences" href="WebPreferences">WebPreferences</a>
</p>
<p><span class="WYSIWYG_PROTECTED"><br />%MAINWEB%</span>.WikiUsers
</p>
<p><a data-wikiword="CompleteAndUtterNothing" href="CompleteAndUtterNothing">CompleteAndUtterNothing</a>
</p>
<p><a data-wikiword="LinkBox" href="LinkBox">LinkBox</a> <a data-wikiword="LinkBoxs" href="LinkBoxs">LinkBoxs</a> <a data-wikiword="LinkBoxies" href="LinkBoxies">LinkBoxies</a> <a data-wikiword="LinkBoxess" href="LinkBoxess">LinkBoxess</a> <a data-wikiword="LinkBoxesses" href="LinkBoxesses">LinkBoxesses</a> <a data-wikiword="LinkBoxes" href="LinkBoxes">LinkBoxes</a>
</p>
XXX
        tml => <<'YYY',
WebPreferences

%MAINWEB%.WikiUsers

CompleteAndUtterNothing

LinkBox LinkBoxs LinkBoxies LinkBoxess LinkBoxesses LinkBoxes
YYY
    },
    {
        exec => $HTML2TML | $ROUNDTRIP,
        name => 'variousWikiWordsNopped',
        html =>
"${nop}${linkon}WebPreferences${linkoff} %${nop}MAINWEB%.WikiUsers ${nop}CompleteAndUtterNothing",
        tml =>
'<nop>WebPreferences %<nop>MAINWEB%.WikiUsers <nop>CompleteAndUtterNothing',
    },
    {
        exec => $HTML2TML,
        name => 'squabsWithVars1',
        html => <<HERE,
${linkon}[[wiki syntax]]$linkoff$linkon\[[%MAINWEB%.Wiki users]]${linkoff}
escaped:
[${nop}[wiki syntax]]
HERE
        tml => <<'EVERYWHERE',
[[wiki syntax]][[%MAINWEB%.Wiki users]] escaped: [<nop>[wiki syntax]]
EVERYWHERE
    },
    {
        exec => $TML2HTML | $ROUNDTRIP,
        name => 'noautolinkBlock',
        html => <<HERE,
<p><span class="WYSIWYG_PROTECTED">&#60;noautolink&#62;</span><span style="{encoded:'n'}" class="WYSIWYG_HIDDENWHITESPACE">&nbsp;</span>WebHome<span style="{encoded:'n'}" class="WYSIWYG_HIDDENWHITESPACE">&nbsp;</span><span class="WYSIWYG_PROTECTED">&#60;/noautolink&#62;</span><span style="{encoded:'n'}" class="WYSIWYG_HIDDENWHITESPACE">&nbsp;</span><a data-wikiword="LinkingTopic" href="LinkingTopic">LinkingTopic</a>
</p>
HERE
        tml => <<'EVERYWHERE',
<noautolink>
WebHome
</noautolink>
LinkingTopic
EVERYWHERE
    },
    {

        # Item12278 Sync Wikiword to link
        exec => $TML2HTML | $ROUNDTRIP,
        name => 'syncWikiwordToLink',
        html => <<HERE,
<p><a class='TMLlink' data-wikiword='WebHome' href="WebHome">WebHome</a>
<span style="{encoded:'n'}" class="WYSIWYG_HIDDENWHITESPACE">&nbsp;</span>
<a class='TMLlink' data-wikiword='WebHome' href="WebHome">WebHome</a>
<span style="{encoded:'n'}" class="WYSIWYG_HIDDENWHITESPACE">&nbsp;</span>
<a class='TMLlink' data-wikiword='WebHome#Anchor' href="WebHome#Anchor">WebHome#Anchor</a>
<span style="{encoded:'n'}" class="WYSIWYG_HIDDENWHITESPACE">&nbsp;</span>
<a class='TMLlink' data-wikiword='WebHome#Anchor' href="WebHome#Anchor">WebHome#Anchor</a>
<span style="{encoded:'n'}" class="WYSIWYG_HIDDENWHITESPACE">&nbsp;</span>
<a class='TMLlink' href="WebHome">HomeTopic</a>
<span style="{encoded:'n'}" class="WYSIWYG_HIDDENWHITESPACE">&nbsp;</span>
<span class=WYSIWYG_LINK>[[Web Home]]</span>
<span style="{encoded:'n'}" class="WYSIWYG_HIDDENWHITESPACE">&nbsp;</span>
<a data-wikiword='WebHome' href="WebHome">WebHome</a>
<span style="{encoded:'n'}" class="WYSIWYG_HIDDENWHITESPACE">&nbsp;</span>
<a data-wikiword='WebHome#Anchor' href="WebHome#Anchor">WebHome#Anchor</a>
<span style="{encoded:'n'}" class="WYSIWYG_HIDDENWHITESPACE">&nbsp;</span>
<a data-wikiword='System.WebHome' href="System.WebHome">System.WebHome</a>
<span style="{encoded:'n'}" class="WYSIWYG_HIDDENWHITESPACE">&nbsp;</span>
<a data-wikiword='System.WebHome#Anchor' href="System.WebHome#Anchor">System.WebHome#Anchor</a>
</p>
HERE
        tml => <<"EVERYWHERE",
[[WebHome]]
[[WebHome][WebHome]]
[[WebHome#Anchor]]
[[WebHome#Anchor][WebHome#Anchor]]
[[WebHome][HomeTopic]]
[[Web Home]]
WebHome
WebHome#Anchor
System.WebHome
System.WebHome#Anchor
EVERYWHERE
        finaltml => <<'EVERYWHERE',
[[WebHome]]
[[WebHome]]
[[WebHome#Anchor]]
[[WebHome#Anchor]]
[[WebHome][HomeTopic]]
[[Web Home]]
WebHome
WebHome#Anchor
System.WebHome
System.WebHome#Anchor
EVERYWHERE
    },
    {

        # Item12278 Sync Wikiword to link
        exec => $HTML2TML,
        name => 'synclinkToWikiword',
        html => <<HERE,
<p><a class='TMLlink' data-wikiword='WebHome' href="WebHome">WebChanges</a>
<span style="{encoded:'n'}" class="WYSIWYG_HIDDENWHITESPACE">&nbsp;</span>
<a class='TMLlink' data-wikiword='WebHome' href="WebHome">WebRss</a>
<span style="{encoded:'n'}" class="WYSIWYG_HIDDENWHITESPACE">&nbsp;</span>
<a class='TMLlink' data-wikiword='WebHome#Anchor' href="WebHome#Anchor">WebHome#Anchor_2</a>
<span style="{encoded:'n'}" class="WYSIWYG_HIDDENWHITESPACE">&nbsp;</span>
<a class='TMLlink' data-wikiword='WebHome#Anchor' href="WebHome#Anchor_2">WebHome#Anchor</a>
<span style="{encoded:'n'}" class="WYSIWYG_HIDDENWHITESPACE">&nbsp;</span>
<a class='TMLlink' href="WebHome">HomeTopic</a>
<span style="{encoded:'n'}" class="WYSIWYG_HIDDENWHITESPACE">&nbsp;</span>
<a data-wikiword='WebHome' href="WebHome">WebChanges</a>
<span style="{encoded:'n'}" class="WYSIWYG_HIDDENWHITESPACE">&nbsp;</span>
<a data-wikiword='WebHome#Anchor' href="WebHome#Anchor">WebRss#Blah</a>
<span style="{encoded:'n'}" class="WYSIWYG_HIDDENWHITESPACE">&nbsp;</span>
<a data-wikiword='System.WebHome' href="System.WebHome">System.WebRss</a>
<span style="{encoded:'n'}" class="WYSIWYG_HIDDENWHITESPACE">&nbsp;</span>
<a data-wikiword='System.WebHome#Anchor' href="System.WebHome#Anchor">System.WebHome#Anchor2</a>
<span style="{encoded:'n'}" class="WYSIWYG_HIDDENWHITESPACE">&nbsp;</span>
<a class='TMLlink' data-wikiword='WebHome' href="WebRss">WebChanges</a>
</p>
HERE
        tml => <<'EVERYWHERE',
[[WebChanges]]
[[WebRss]]
[[WebHome#Anchor_2]]
[[WebHome#Anchor_2][WebHome#Anchor]]
[[WebHome][HomeTopic]]
WebChanges
WebRss#Blah
System.WebRss
System.WebHome#Anchor2
[[WebRss][WebChanges]]
EVERYWHERE
    },
    {

        # Item12043: Preserve all squabs in noautolink.
        exec => $TML2HTML | $ROUNDTRIP,
        name => 'noautolinkSquabBlock',
        html => <<HERE,
<p>
<span class="WYSIWYG_PROTECTED">&#60;noautolink&#62;</span>
<span style="{encoded:'n'}" class="WYSIWYG_HIDDENWHITESPACE">&nbsp;</span>
<a class='TMLlink' data-wikiword='WebHome' href="WebHome">WebHome</a>
<span style="{encoded:'n'}" class="WYSIWYG_HIDDENWHITESPACE">&nbsp;</span>
<a class='TMLlink' data-wikiword='WebHome' href="WebHome">WebHome</a>
<span style="{encoded:'n'}" class="WYSIWYG_HIDDENWHITESPACE">&nbsp;</span>
<a class='TMLlink' href="WebHome">HomeTopic</a>
<span style="{encoded:'n'}" class="WYSIWYG_HIDDENWHITESPACE">&nbsp;</span>
<span class="WYSIWYG_PROTECTED">&#60;/noautolink&#62;</span>
<span style="{encoded:'n'}" class="WYSIWYG_HIDDENWHITESPACE">&nbsp;</span>
<a data-wikiword="LinkingTopic" href="LinkingTopic">LinkingTopic</a>
</p>
HERE
        tml => <<'EVERYWHERE',
<noautolink>
[[WebHome]]
[[WebHome][WebHome]]
[[WebHome][HomeTopic]]
</noautolink>
LinkingTopic
EVERYWHERE
        finaltml => <<'EVERYWHERE',
<noautolink>
[[WebHome]]
[[WebHome]]
[[WebHome][HomeTopic]]
</noautolink>
LinkingTopic
EVERYWHERE
    },
    {
        exec => $ROUNDTRIP | $TML2HTML | $HTML2TML,
        name => 'squabsWithVars2',
        html => <<HERE,
<p><span class="WYSIWYG_LINK">[[wiki syntax]]</span><span class="WYSIWYG_LINK">[[%MAINWEB%.Wiki users]]</span><span style="{encoded:'n'}" class="WYSIWYG_HIDDENWHITESPACE">&nbsp;</span>escaped:<span style="{encoded:'n'}" class="WYSIWYG_HIDDENWHITESPACE">&nbsp;</span>!<span class="WYSIWYG_LINK">[[wiki syntax]]</span>
</p>
HERE
        tml => <<'THERE',
[[wiki syntax]][[%MAINWEB%.Wiki users]]
escaped:
![[wiki syntax]]
THERE
    },
    {
        exec => $ROUNDTRIP,
        name => 'squabsWithWikiWordsAndLink',
        html => $linkon
          . '[[WikiSyntax][syntax]]'
          . $linkoff . ' '
          . $linkon
          . '[[http://gnu.org][GNU]]'
          . $linkoff . ' '
          . $linkon
          . '[[http://xml.org][XML]]'
          . $linkoff,
        tml =>
'[[WikiSyntax][syntax]] [[http://gnu.org][GNU]] [[http://xml.org][XML]]',
    },
    {
        exec => $ROUNDTRIP,
        name => 'squabWithAnchor',
        html => ${linkon} . 'FleegleHorn#TrumpetHack' . ${linkoff},
        tml  => 'FleegleHorn#TrumpetHack',
    },
    {
        exec => $ROUNDTRIP,
        name => 'plingedVarOne',
        html => '!<span class="WYSIWYG_PROTECTED">%MAINWEB%</span>nowt',
        tml  => '!%MAINWEB%nowt',
    },
    {
        exec => $ROUNDTRIP,
        name => 'plingedVarTwo',
        html => 'nowt!<span class="WYSIWYG_PROTECTED">%MAINWEB%</span>',
        tml  => 'nowt!%MAINWEB%',
    },
    {
        exec => $ROUNDTRIP,
        name => 'headerly',
        html =>
"<h1 class='notoc'><span class='WYSIWYG_PROTECTED'>%TOPIC%</span></h1>",
        tml      => '---+!!%TOPIC%',
        finaltml => '---+!! %TOPIC%',
    },
    {
        exec => $ROUNDTRIP,
        name => 'WEBvar',
        html => "${protecton}%WEB%${protectoff}",
        tml  => '%WEB%',
    },
    {
        exec => $ROUNDTRIP,
        name => 'ICONvar1',
        html => "${protecton}%ICON{}%${protectoff}",
        tml  => '%ICON{}%',
    },
    {
        exec => $ROUNDTRIP,
        name => 'ICONvar2',
        html => "${protecton}%ICON{&#34;&#34;}%${protectoff}",
        tml  => '%ICON{""}%',
    },
    {
        exec => $ROUNDTRIP,
        name => 'ICONvar3',
        html => "${protecton}%ICON{&#34;Fleegle&#34;}%${protectoff}",
        tml  => '%ICON{"Fleegle"}%'
    },
    {
        exec => $ROUNDTRIP,
        name => 'URLENCODEvar',
        html => "${protecton}%URLENCODE{&#34;&#34;}%${protectoff}",
        tml  => '%URLENCODE{""}%',
    },
    {
        exec => $ROUNDTRIP,
        name => 'ENCODEvar',
        html => "${protecton}%ENCODE{&#34;&#34;}%${protectoff}",
        tml  => '%ENCODE{""}%',
    },
    {
        exec => $ROUNDTRIP,
        name => 'INTURLENCODEvar',
        html => "${protecton}%INTURLENCODE{&#34;&#34;}%${protectoff}",
        tml  => '%INTURLENCODE{""}%',
    },
    {
        exec => $ROUNDTRIP,
        name => 'USERSWEBvar',
        html => "${protecton}%MAINWEB%${protectoff}",
        tml  => '%MAINWEB%',
    },
    {
        exec => $ROUNDTRIP,
        name => 'SYSTEMWEBvar',
        html => "${protecton}%SYSTEMWEB%${protectoff}",
        tml  => '%SYSTEMWEB%',
    },
    {
        exec => $ROUNDTRIP,
        name => 'HOMETOPICvar',
        html => "${protecton}%HOMETOPIC%${protectoff}",
        tml  => '%HOMETOPIC%',
    },
    {
        exec => $ROUNDTRIP,
        name => 'WIKIUSERSTOPICvar',
        html => $protecton . '%WIKIUSERSTOPIC%' . $protectoff,
        tml  => '%WIKIUSERSTOPIC%',
    },
    {
        exec => $ROUNDTRIP,
        name => 'WIKIPREFSTOPICvar',
        html => $protecton . '%WIKIPREFSTOPIC%' . $protectoff,
        tml  => '%WIKIPREFSTOPIC%',
    },
    {
        exec => $ROUNDTRIP,
        name => 'WEBPREFSTOPICvar',
        html => $protecton . '%WEBPREFSTOPIC%' . $protectoff,
        tml  => '%WEBPREFSTOPIC%',
    },
    {
        exec => $ROUNDTRIP,
        name => 'NOTIFYTOPICvar',
        html => $protecton . '%NOTIFYTOPIC%' . $protectoff,
        tml  => '%NOTIFYTOPIC%',
    },
    {
        exec => $ROUNDTRIP,
        name => 'STATISTICSTOPICvar',
        html => $protecton . '%STATISTICSTOPIC%' . $protectoff,
        tml  => '%STATISTICSTOPIC%',
    },
    {
        exec => $ROUNDTRIP,
        name => 'STARTINCLUDEvar',
        html => $protecton . '%STARTINCLUDE%' . $protectoff,
        tml  => '%STARTINCLUDE%',
    },
    {
        exec => $ROUNDTRIP,
        name => 'STOPINCLUDEvar',
        html => $protecton . '%STOPINCLUDE%' . $protectoff,
        tml  => '%STOPINCLUDE%',
    },
    {
        exec => $ROUNDTRIP,
        name => 'SECTIONvar',
        html => $protecton . '%SECTION{&#34;&#34;}%' . $protectoff,
        tml  => '%SECTION{""}%',
    },
    {
        exec => $ROUNDTRIP,
        name => 'ENDSECTIONvar',
        html => $protecton . '%ENDSECTION%' . $protectoff,
        tml  => '%ENDSECTION%',
    },
    {
        exec => $ROUNDTRIP,
        name => 'FORMFIELDvar1',
        html => $protecton
          . '%FORMFIELD{&#34;&#34;&nbsp;topic=&#34;&#34;&nbsp;alttext=&#34;&#34;&nbsp;default=&#34;&#34;&nbsp;format=&#34;$value&#34;}%'
          . $protectoff,
        tml => '%FORMFIELD{"" topic="" alttext="" default="" format="$value"}%',
    },
    {
        exec => $ROUNDTRIP,
        name => 'FORMFIELDvar2',
        html => $protecton
          . '%FORMFIELD{&#34;TopicClassification&#34;&nbsp;topic=&#34;&#34;&nbsp;alttext=&#34;&#34;&nbsp;default=&#34;&#34;&nbsp;format=&#34;$value&#34;}%'
          . $protectoff,
        tml =>
'%FORMFIELD{"TopicClassification" topic="" alttext="" default="" format="$value"}%',
    },
    {
        exec => $ROUNDTRIP,
        name => 'SPACEDTOPICvar',
        html => $protecton . '%SPACEDTOPIC%' . $protectoff,
        tml  => '%SPACEDTOPIC%',
    },
    {
        exec => $ROUNDTRIP,
        name => 'RELATIVETOPICPATHvar1',
        html => $protecton . '%RELATIVETOPICPATH{}%' . $protectoff,
        tml  => '%RELATIVETOPICPATH{}%',
    },
    {
        exec => $ROUNDTRIP,
        name => 'RELATIVETOPICPATHvar2',
        html => $protecton . '%RELATIVETOPICPATH{Sausage}%' . $protectoff,
        tml  => '%RELATIVETOPICPATH{Sausage}%',
    },
    {
        exec => $ROUNDTRIP,
        name => 'RELATIVETOPICPATHvar3',
        html => $protecton
          . '%RELATIVETOPICPATH{&#34;Chips&#34;}%'
          . $protectoff,
        tml => '%RELATIVETOPICPATH{"Chips"}%',
    },
    {
        exec => $ROUNDTRIP,
        name => 'SCRIPTNAMEvar',
        html => $protecton . '%SCRIPTNAME%' . $protectoff,
        tml  => '%SCRIPTNAME%',
    },
    {
        exec => $HTML2TML,
        name => 'nestedVerbatim1',
        html => 'Outside
 <span class="TMLverbatim"><br />&nbsp;Inside<br />&nbsp;</span> Outside',
        tml => 'Outside <verbatim>
 Inside
 </verbatim> Outside',
    },
    {
        exec => $ROUNDTRIP,
        name => 'nestedVerbatim2',
        html => 'Outside
 <span class="TMLverbatim"><br />Inside<br /></span>Outside',
        tml => 'Outside
 <verbatim>
 Inside
 </verbatim>
 Outside',
    },
    {
        exec => $TML2HTML | $ROUNDTRIP,
        name => 'verbatimWithNbsp1554',
        html => $deleteme . '<p><pre class="TMLverbatim">&amp;nbsp;</pre></p>',
        tml  => "<verbatim>&nbsp;</verbatim>"
    },
    {
        exec => $TML2HTML | $ROUNDTRIP,
        name => 'Item6068NewlinesInPre',
        tml  => <<'HERE',
<pre>
test
test
test
</pre>
HERE
        html => <<"HERE",
$deleteme<p>
<pre>
test
test
test
</pre>
</p>
HERE
    },
    {
        exec => $TML2HTML | $ROUNDTRIP,
        name => 'nestedPre',
        html => '<p>
Outside <pre class="foswikiAlert TMLverbatim"><br />&nbsp;&nbsp;Inside<br />&nbsp;&nbsp;</pre> Outside </p>',
        tml => 'Outside <verbatim class="foswikiAlert">
  Inside
  </verbatim> Outside',
    },
    {
        name => 'verbatimWithClassForJqChili',
        exec => $ROUNDTRIP,
        tml  => <<'HERE',
<verbatim class="tml">
%STARTSECTION{"formfield"}%%FORMFIELD{
  "%URLPARAM{"formfield" default="does not exist"}%"
  topic="%URLPARAM{"source" default="does not exist"}%"
}%%ENDSECTION{"formfield"}%
</verbatim>
HERE
    },
    {
        exec => $ROUNDTRIP,
        name => 'nestedIndentedVerbatim',
        html =>
'Outside<span class="TMLverbatim"><br />Inside<br />&nbsp;&nbsp;&nbsp;</span>Outside',
        tml => 'Outside
    <verbatim>
 Inside
    </verbatim>
 Outside
 ',
        finaltml => 'Outside
    <verbatim>
 Inside
    </verbatim>
 Outside',
    },
    {
        exec => $ROUNDTRIP,
        name => 'nestedIndentedPre1',
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
    },
    {
        exec => $HTML2TML,
        name => 'nestedIndentedPre2',
        html => 'Outside
 <pre>
 Inside

Snide
 </pre>
 Outside',
        tml => 'Outside <pre>
 Inside

Snide
 </pre> Outside',
    },
    {
        exec => $HTML2TML,
        name => 'classifiedPre',
        html => 'Outside
 <pre class="foswikiAlert">
 Inside
 </pre>
 Outside',
        tml => 'Outside <pre class="foswikiAlert">
 Inside
 </pre> Outside',
    },
    {
        exec => $HTML2TML,
        name => 'indentedPre1',
        html => 'Outside<pre>
 Inside
    </pre> Outside',
        tml => 'Outside<pre>
 Inside
    </pre> Outside',
    },
    {
        exec => $ROUNDTRIP,
        name => 'indentedPre2',
        html => 'Outside<pre>
Inside
</pre>Outside',
        tml => 'Outside
    <pre>
 Inside
    </pre>
 Outside',
    },
    {
        exec => $TML2HTML | $ROUNDTRIP,
        name => 'NAL1',
        html => '<p>Outside
 <span class="WYSIWYG_PROTECTED">&lt;noautolink&gt;</span>
 Inside
 <span class="WYSIWYG_PROTECTED">&lt;/noautolink&gt;</span>
 Outside</p>',
        tml => 'Outside <noautolink> Inside </noautolink> Outside',
    },
    {
        exec => $TML2HTML | $ROUNDTRIP,
        name => 'NAL2',
        html => '<p>Outside'
          . encodedWhitespace('ns1')
          . '<span class="WYSIWYG_PROTECTED">&lt;noautolink&gt;</span>'
          . encodedWhitespace('ns1')
          . 'Inside'
          . encodedWhitespace('ns1')
          . '<span class="WYSIWYG_PROTECTED">&lt;/noautolink&gt;</span>'
          . encodedWhitespace('ns1')
          . 'Outside</p>',
        tml => 'Outside
 <noautolink>
 Inside
 </noautolink>
 Outside',
    },
    {
        exec => $HTML2TML,
        name => 'classifiedNAL1',
        html => '<p>Outside
<span class="WYSIWYG_PROTECTED">&lt;noautolink&nbsp;class="foswikiAlert"&gt;</span></p>
  <ul>
   <li> Inside </li>
  </ul>
<p><span class="WYSIWYG_PROTECTED">&lt;/noautolink&gt;</span>
 Outside
 </p>',
        tml => 'Outside <noautolink class="foswikiAlert">
   * Inside
</noautolink> Outside',
    },
    {
        exec => $TML2HTML | $ROUNDTRIP,
        name => 'classifiedNAL2',
        html => '<p>Outside'
          . encodedWhitespace('n')
          . '<span class="WYSIWYG_PROTECTED">&lt;noautolink&nbsp;class="foswikiAlert"&gt;</span></p>
  <ul>
   <li> Inside </li>
  </ul>
<p><span class="WYSIWYG_PROTECTED">&lt;/noautolink&gt;</span>'
          . encodedWhitespace('ns1') . 'Outside
 </p>',
        tml => 'Outside
<noautolink class="foswikiAlert">
   * Inside
</noautolink>
 Outside',
    },
    {
        exec => $HTML2TML,
        name => 'indentedNAL1',
        html => 'Outside
 <span class="WYSIWYG_PROTECTED">&lt;noautolink&gt;</span>
 Inside
 <span class="WYSIWYG_PROTECTED">&lt;/noautolink&gt;</span>
 Outside
 ',
        tml => 'Outside <noautolink> Inside </noautolink> Outside',
    },
    {
        exec => $ROUNDTRIP,
        name => 'indentedNAL2',
        tml  => 'Outside
    <noautolink>
 Inside
    </noautolink>
 Outside
 ',
        finaltml => 'Outside
    <noautolink>
 Inside
    </noautolink>
 Outside',
    },
    {
        exec => $ROUNDTRIP,
        name => 'linkInHeader',
        html =>
          "<h3 class=\"TML\"> Test with${linkon}LinkInHeader${linkoff}</h3>",
        tml => '---+++ Test with LinkInHeader',
    },
    {
        exec => $HTML2TML,
        name => 'inlineBreaks',
        html => 'Zadoc<br />The<br />Priest',
        tml  => 'Zadoc<br />The<br />Priest',
    },
    {
        exec => $HTML2TML,
        name => 'doctype',
        html =>
'<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">',
        tml => '',
    },
    {
        exec => $HTML2TML,
        name => 'head',
        html => '<head> ignore me </head>',
        tml  => '',
    },
    {
        exec => $HTML2TML,
        name => 'htmlAndBody',
        html => '<html> good <body>good </body></html>',
        tml  => 'good good',
    },
    {
        exec => $HTML2TML,
        name => 'kupuTable',
        html =>
'<table cellspacing="0" cellpadding="8" border="1" class="plain" _moz_resizing="true">
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
        name => "images",
        html => '<img src="test_image" />',
        tml  => '%TRANSLATEDIMAGE%',
    },
    {
        exec => $ROUNDTRIP,
        name => "WikiTagsInHTMLParam",
        html => "${linkon}[[%!page!%/Burble/Barf][Burble]]${linkoff}",
        tml  => '[[Burble.Barf][Burble]]',
    },
    {
        exec => $HTML2TML,
        name => "emptySpans",
        html => <<HERE,
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
        tml  => '[[Sandbox.WebHome][this]]',
    },
    {
        exec => $ROUNDTRIP,
        name => 'anchoredLink',
        tml  => '[[FAQ.NetworkInternet#Pomona_Network][Test Link]]',
        html =>
"${linkon}[[FAQ.NetworkInternet#Pomona_Network][Test Link]]${linkoff}",
    },
    {
        exec => $TML2HTML | $ROUNDTRIP,
        name => 'tableWithColSpans',
        html => '<p>abcd
</p>
<table cellspacing="1" cellpadding="0" border="1">
<tr><td colspan="2">efg</td><td>&nbsp;</td></tr>
<tr><td colspan="3"></td></tr></table>
<p>hijk</p>',
        tml => 'abcd
| efg || |
||||
hijk',
        finaltml => 'abcd
| efg || |
| |||
hijk',
    },
    {
        exec => $ROUNDTRIP | $HTML2TML | $TML2HTML,
        name => 'variableInIMGtag',
        html =>
"<p><img src='$Foswiki::cfg{PubUrlPath}/Current/TestTopic/T-logo-16x16.gif' /></p>",
        tml      => '<img src="%ATTACHURLPATH%/T-logo-16x16.gif" />',
        finaltml => '<img src="%ATTACHURLPATH%/T-logo-16x16.gif" />',
    },
    {
        exec => $ROUNDTRIP | $HTML2TML | $TML2HTML,
        name => 'Item9973_cp1251',

        # SMELL: Actually, CharSet isn't used, but this test does fail on
        # Foswikirev:10077, whereas it passes with the Item9973 checkins
        # applied. I've left it here anticipating that more weird cases might
        # use such a parameter (no utf8 test cases yet, for example)
        # \xc9 isn't valid utf8 - so the character must be encoded (for now)
        # when the site charset is utf8
        CharSet => 'cp1251',
        topic   => "Test" . (
            ( $Foswiki::cfg{Site}{CharSet} || '' ) =~ /utf-?8/i
            ? Encode::encode( 'utf8', "\x0419" )    # same as cp1251's 0xc9
            : "\xc9"
        ),
        html => "<p><img src='$Foswiki::cfg{PubUrlPath}/Current/Test"
          . (
            ( $Foswiki::cfg{Site}{CharSet} || '' ) =~ /utf-?8/i
            ? Encode::encode( 'utf8', "\x0419" )
            : "\xc9"
          )
          . "/T-logo-16x16.gif' /></p>",
        tml      => '<img src="%ATTACHURLPATH%/T-logo-16x16.gif" />',
        finaltml => '<img src="%ATTACHURLPATH%/T-logo-16x16.gif" />',
    },
    {
        exec => $TML2HTML | $HTML2TML | $ROUNDTRIP,
        name => 'setCommand',
        tml  => <<HERE,
   * Set FLIBBLE = <break> <cake/>
     </break>
   * %FLIBBLE%
   * Set Other=stuff
   <sticky><font color="blue"> *|B|* </font></sticky>
   <!-- hidden -->
   http://google.com/#q=foswiki
   %FOO% WikiWord [[some link]]
   <img src="http://mysite.org/logo.png" alt="Alternate text" />
   <verbatim class="tml">%H%<!--?--></verbatim>
   <literal><font color="blue"> *|B|* </font></literal>
   <mytag attr="value">my content</mytag>
   <sticky> block </sticky>
   <pre>
     123
    456
   </pre>
      * Set FLEEGLE = easy gum
HERE
        html => '<ul>'
          . '<li> Set FLIBBLE =<span class="WYSIWYG_PROTECTED">&nbsp;&#60;break&#62;&nbsp;&#60;cake/&#62;<br />'
          . '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&#60;/break&#62;</span></li>'
          . '<li><span class="WYSIWYG_PROTECTED">%FLIBBLE%</span></li>'
          . '<li> Set Other=<span class="WYSIWYG_PROTECTED">stuff<br />'
          . '&nbsp;&nbsp;&nbsp;&lt;sticky&gt;&#60;font&nbsp;color="blue"&#62;&nbsp;*|B|*&nbsp;&#60;/font&#62;&lt;/sticky&gt;<br />'
          . '&nbsp;&nbsp;&nbsp;&lt;!--&nbsp;hidden&nbsp;--&gt;<br />'
          . '&nbsp;&nbsp;&nbsp;http://google.com/#q=foswiki<br />'
          . '&nbsp;&nbsp;&nbsp;%FOO%&nbsp;WikiWord&nbsp;[[some&nbsp;link]]<br />'
          . '&nbsp;&nbsp;&nbsp;&lt;img&nbsp;src=&quot;http://mysite.org/logo.png&quot;&nbsp;alt=&quot;Alternate&nbsp;text&quot;&nbsp;/&gt;<br />'
          . '&nbsp;&nbsp;&nbsp;&lt;verbatim&nbsp;class=&quot;tml&quot;&gt;%H%&lt;!--?--&gt;&lt;/verbatim&gt;<br />'
          . '&nbsp;&nbsp;&nbsp;&lt;literal&gt;&lt;font&nbsp;color="blue"&gt;&nbsp;*|B|*&nbsp;&lt;/font&gt;&lt;/literal&gt;<br />'
          . '&nbsp;&nbsp;&nbsp;&lt;mytag&nbsp;attr="value"&gt;my&nbsp;content&lt;/mytag&gt;<br />'
          . '&nbsp;&nbsp;&nbsp;&lt;sticky&gt;&nbsp;block&nbsp;&lt;/sticky&gt;<br />'
          . '&nbsp;&nbsp;&nbsp;&lt;pre&gt;<br />'
          . '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;123<br />'
          . '&nbsp;&nbsp;&nbsp;&nbsp;456<br />'
          . '&nbsp;&nbsp;&nbsp;&lt;/pre&gt;'
          . '</span>'
          . '<ul><li>Set FLEEGLE =<span class="WYSIWYG_PROTECTED">&nbsp;easy&nbsp;gum</span></li></ul></li></ul>',
    },
    {
        exec => $HTML2TML,
        name => 'tinyMCESetCommand',
        tml  => <<HERE,
Before

   * Set FLIBBLE = phlegm
After
HERE
        html =>
'Before<p class="WYSIWYG_PROTECTED">&nbsp;&nbsp; * Set FLIBBLE = phlegm</p>After',
    },
    {
        exec => $ROUNDTRIP,
        name => 'twikiWebSnarf',
        html => '<a href="%SYSTEMWEB%.TopicName">bah</a>',
        tml  => '[[%SYSTEMWEB%.TopicName][bah]]',
    },
    {
        exec => $ROUNDTRIP,
        name => 'mainWebSnarf',
        html => '<a href="%MAINWEB%.TopicName>bah</a>',
        html => "${linkon}\[[%MAINWEB%.TopicName][bah]]$linkoff",
        tml  => '[[%MAINWEB%.TopicName][bah]]',
    },
    {
        exec => $ROUNDTRIP,
        name => 'mainFormWithVars',
        html => $protecton
          . '<form&nbsp;action=&#34;%SCRIPTURLPATH%/search%SCRIPTSUFFIX%/%INTURLENCODE{&#34;%WEB%&#34;}%/&#34;>'
          . $protectoff,
        tml =>
'<form action="%SCRIPTURLPATH%/search%SCRIPTSUFFIX%/%INTURLENCODE{"%WEB%"}%/">',
    },
    {
        exec => $ROUNDTRIP,
        name => "Item871",
        tml  => "[[Test]] Entry [[TestPage][Test Page]]\n",
        html =>
"${linkon}[[Test]]${linkoff} Entry ${linkon}[[TestPage][Test Page]]${linkoff}",
    },
    {
        exec => 0,
        name => "Item863",
        tml  => <<EOE,
||1| 2 |  3 | 4  ||
EOE
        html     => '<table cellpadding="0" border="1" cellspacing="1">',
        finaltml => <<EOE,
EOE
    },
    {
        exec => $ROUNDTRIP,
        name => 'Item945',
        html => $protecton
          . '%SEARCH{&#34;ReqNo&#34;&nbsp;scope=&#34;topic&#34;&nbsp;regex=&#34;on&#34;&nbsp;nosearch=&#34;on&#34;&nbsp;nototal=&#34;on&#34;&nbsp;casesensitive=&#34;on&#34;&nbsp;format=&#34;$percntCALC{$IF($NOT($FIND(%TOPIC%,$formfield(ReqParents))),&nbsp;&#60;nop&#62;,&nbsp;[[$topic]]&nbsp;-&nbsp;$formfield(ReqShortDescript)&nbsp;%BR%&nbsp;)}$percnt&#34;}%'
          . $protectoff,
        tml =>
'%SEARCH{"ReqNo" scope="topic" regex="on" nosearch="on" nototal="on" casesensitive="on" format="$percntCALC{$IF($NOT($FIND(%TOPIC%,$formfield(ReqParents))), <nop>, [[$topic]] - $formfield(ReqShortDescript) %BR% )}$percnt"}%',
    },
    {
        exec => $ROUNDTRIP,
        name => "WebAndTopic",
        tml =>
"Current.TestTopic Sandbox.TestTopic [[Current.TestTopic]] [[Sandbox.TestTopic]]",
        html => <<HERE,
${linkon}Current.TestTopic${linkoff}
${linkon}Sandbox.TestTopic${linkoff}
${linkon}\[[Current.TestTopic]]${linkoff}
${linkon}\[[Sandbox.TestTopic]]${linkoff}
HERE
    },
    {
        exec     => $ROUNDTRIP,
        name     => 'Item1140',
        html     => '<img src="%!page!%/T-logo-16x16.gif" />',
        tml      => '<img src="%!page!%/T-logo-16x16.gif" />',
        finaltml => '<img src=\'%SCRIPTURL{"view"}%/T-logo-16x16.gif\' />',
    },
    {
        exec => $ROUNDTRIP,
        name => 'Item1175',
        tml  => '[[WebCTPasswords][Resetting a WebCT Password]]',
        html =>
          "${linkon}[[WebCTPasswords][Resetting a WebCT Password]]${linkoff}",
    },
    {
        exec => $ROUNDTRIP,
        name => 'Item1259',
        html =>
"Spleem$protecton&#60;!--<br />&nbsp;&nbsp;&nbsp;*&nbsp;Set&nbsp;SPOG&nbsp;=&nbsp;dreep<br />--&#62;${protectoff}Splom",
        tml => "Spleem<!--\n   * Set SPOG = dreep\n-->Splom",
    },
    {
        exec => $ROUNDTRIP,
        name => 'Item1317',
        tml  => '%<nop>DISPLAYTIME{"$hou:$min"}%',
        html => "%${nop}DISPLAYTIME\{\"\$hou:\$min\"}%",
    },
    {
        exec => $ROUNDTRIP,
        name => 'Item4410',
        tml  => <<'HERE',
   * x
| Y |
HERE
        html =>
'<ul><li>x</li></ul><table cellspacing="1" cellpadding="0" border="1"><tr><td>Y</td></tr></table>',
    },
    {
        exec => $ROUNDTRIP,
        name => 'Item4426',
        tml  => <<'HERE',
   * x
   *
   * y
HERE
        html => '<ul>
<li>x
</li><li></li><li>y
</li></ul>',
        finaltml => <<"HERE",
   * x
   *$trailingSpace
   * y
HERE
    },
    {
        exec => $HTML2TML | $ROUNDTRIP,
        name => 'Item3735',
        tml  => "fred *%WIKINAME%* fred",
        html => "<p>fred <b>$protecton%WIKINAME%$protectoff</b> fred</p>",
    },
    {
        exec => $TML2HTML | $ROUNDTRIP,
        name => 'Item2352',
        tml  => '%Foo%',
        html => "<p>" . $protecton . '%Foo%' . $protectoff . "</p>"
    },
    {
        exec => $ROUNDTRIP,
        name => 'brInProtectedRegion',
        html => $protecton
          . "&#60;!--Fred<br />Jo&nbsp;e<br />Sam--&#62;"
          . $protectoff,
        tml => "<!--Fred\nJo e\nSam-->",
    },
    {
        exec     => $HTML2TML,
        name     => 'whatTheF',
        html     => 'what<p></p>thef',
        finaltml => "what\n\nthef",
    },
    {
        exec => $ROUNDTRIP,
        name => 'whatTheFur',
        html => 'what<p />thef',
        tml  => "what\n\nthef",
    },
    {
        exec => $HTML2TML | $ROUNDTRIP,
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
Paraone'
          . encodedWhitespace('n') . 'Paratwo
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
        finaltml => 'Paraone
Paratwo

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
        tml  => '   * list
Paraone',
        html => '<ul><li>list</li></ul>Paraone',
    },
    {
        name => 'blankLineAndParaAfterList',
        exec => $TML2HTML | $ROUNDTRIP,
        tml  => '   * list

Paraone',
        html => '<ul><li>list'
          . '</li></ul><p class="WYSIWYG_NBNL">Paraone</p>',
    },
    {
        name => 'blankLineAndParaWithLeadingSpacesAfterList',
        exec => $ROUNDTRIP,
        tml  => <<'TML',
   * list

     Paraone
TML
    },
    {
        name => 'brInText',
        exec => $HTML2TML,
        tml  => 'pilf<br />flip',
        html => 'pilf<br>flip',
    },
    {
        name => 'brInSource',
        exec => $TML2HTML | $ROUNDTRIP,
        tml  => 'pilf<br />flip',
        html => '<p>
pilf<br />flip
</p>',
    },
    {
        name => 'advBlockquote',
        exec => $TML2HTML | $ROUNDTRIP,
        tml  => <<HERE,
<blockquote style="margin-top: 0px; margin-right: 0px; margin-bottom: 0px; margin-left: 40px; border-width: initial; border-color: initial; border-image: initial; border-style: none; padding: 0px">
blah
blah

blah
</blockquote>
HERE
        html => <<HERE,
<p class="foswikiDeleteMe">&nbsp;</p><blockquote style="margin-top: 0px; margin-right: 0px; margin-bottom: 0px; margin-left: 40px; border-width: initial; border-color: initial; border-image: initial; border-style: none; padding: 0px"><p class="foswikiDeleteMe"><span style="{encoded:'n'}" class="WYSIWYG_HIDDENWHITESPACE">&nbsp;</span>blah<span style="{encoded:'n'}" class="WYSIWYG_HIDDENWHITESPACE">&nbsp;</span>blah
<p class='WYSIWYG_NBNL'>blah
</p></p></blockquote>
HERE
    },
    {
        name => 'Item4481',
        exec => $TML2HTML | $ROUNDTRIP,
        tml  => '<blockquote>pilf<br />flip</blockquote>',
        html =>
"$deleteme<blockquote><p class=\"foswikiDeleteMe\">pilf<br />flip</p></blockquote>",
    },
    {

# If Wysiwyg user "splits" a foswikiDeleteMe paragraph, then only the first
# paragraph should actually be deleted.  Subsequent paragraphs should be preserved.
        name => 'blockquoteSplitPara',
        exec => $HTML2TML,
        tml  => <<HERE,
<blockquote>para1

para2

para3
</blockquote>
HERE
        html =>
"$deleteme<blockquote><p class=\"foswikiDeleteMe\">para1</p><p class=\"foswikiDeleteMe\">para2</p><p class=\"foswikiDeleteMe\">para3</p></blockquote>",
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
#<<<
# SMELL:  Removed by Item11859.  This issue does not appear to happen
# in recent TInyMCE releases  (Tested 3.4.9)
#    {
#        exec => $HTML2TML,
#        name => 'losethatdamnBR',
#        html => <<'JUNK',
#TinyMCE sticks in a BR where it isn't wanted before a P<br>
#<p>
#We should only have a P.
#</p>
#JUNK
#        tml => <<JUNX,
#TinyMCE sticks in a BR where it isn't wanted before a P
#
#We should only have a P.
#JUNX
#    },
#>>>
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
        exec => $TML2HTML | $ROUNDTRIP,
        name => 'Item4550',
        tml  => <<FGFG,
---+ A
<section>
---++ B
C
</section>
X
FGFG
        html => '<h1 class="TML">  A </h1>
<p><span class="WYSIWYG_PROTECTED">&lt;section&gt;</span></p>
<h2 class="TML">  B </h2>
<p>C'
          . encodedWhitespace('n')
          . '<span class="WYSIWYG_PROTECTED">&lt;/section&gt;</span>'
          . encodedWhitespace('n') . 'X</p>
',
        finaltml => <<FGFG,
---+ A

<section>
---++ B

C
</section>
X
FGFG
    },
    {
        exec => $HTML2TML,
        name => 'Item4588',
        tml  => <<XYZ,
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
    },
    {
        exec => $ROUNDTRIP,
        name => "Item4615",
        tml  => 'ABC<br /> _DEF_',
        html => 'ABC<br /><i>DEF</i>',
    },
    {
        exec => $TML2HTML | $HTML2TML,
        name => 'Item4700',
        tml  => <<EXPT,
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
        html => <<"HEXPT",
$deleteme<table cellspacing="1" cellpadding="0" border="1">
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
        tml  => <<EXPT,
| ex | per | iment |
| exper | iment ||
| expe || riment |
| | exper | iment |
EXPT
        html => <<"HEXPT",
$deleteme<table cellspacing="1" cellpadding="0" border="1">
<tr><td>ex</td><td>per</td><td>iment</td></tr>
<tr><td>exper</td><td colspan="2">iment</td></tr>
<tr><td colspan="2">expe</td><td>riment</td></tr>
<tr><td></td><td>exper</td><td>iment</td></tr>
</table>
HEXPT
    },
    {
        exec => $TML2HTML | $ROUNDTRIP,
        name => 'RowSpan1',
        tml  => <<EXPT,
| A | B |
| C | ^ |
EXPT
        html => <<"HEXPT",
$deleteme<table border="1" cellpadding="0" cellspacing="1">
<tr><td>A</td><td rowspan="2">B</td></tr>
<tr><td>C</td></tr>
</table>
HEXPT
    },
    {
        exec => $TML2HTML | $ROUNDTRIP,
        name => 'RowSpan2',
        tml  => <<EXPT,
| A | B |
| ^ | C |
EXPT
        html => <<"HEXPT",
$deleteme<table border="1" cellpadding="0" cellspacing="1">
<tr><td rowspan="2">A</td><td>B</td></tr>
<tr><td>C</td></tr>
</table>
HEXPT
    },
    {
        exec => $TML2HTML | $ROUNDTRIP,
        name => 'RowSpan3',
        tml  => <<EXPT,
| A | B | X |
| ^ | ^ | C |
EXPT
        html => <<"HEXPT",
$deleteme<table border="1" cellpadding="0" cellspacing="1">
<tr><td rowspan="2">A</td><td rowspan="2">B</td><td>X</td></tr>
<tr><td>C</td></tr>
</table>
HEXPT
    },
    {
        exec => $TML2HTML | $ROUNDTRIP,
        name => 'RowSpan4',
        tml  => <<EXPT,
| A | B | X |
| ^ | ^ | C |
| M | ^ | ^ |
EXPT
        html => <<"HEXPT",
$deleteme<table border="1" cellpadding="0" cellspacing="1">
<tr><td rowspan="2">A</td><td rowspan="3">B</td><td>X</td></tr>
<tr><td rowspan="2">C</td></tr>
<tr><td>M</td></tr>
</table>
HEXPT
    },
    {
        exec => $TML2HTML | $ROUNDTRIP,
        name => 'RowSpan5',
        tml  => <<EXPT,
| A | B | X |
| ^ | ^ | C |
| M | ^ |
EXPT
        html => <<"HEXPT",
$deleteme<table border="1" cellpadding="0" cellspacing="1">
<tr><td rowspan="2">A</td><td rowspan="3">B</td><td>X</td></tr>
<tr><td>C</td></tr>
<tr><td>M</td></tr>
</table>
HEXPT
        DISABLEDfinaltml => <<FEXPT,
| A | B | X |
| ^ | ^ | C |
| M | ^ | |
FEXPT
    },
    {
        exec => $TML2HTML | $ROUNDTRIP,
        name => 'mergedRowsAndColumnsCentre',
        tml  => <<EXPT,
| A1 | A2 | A3 | A4 |
| B1 | X || B4 |
| C1 | ^ | C4 |
| D1 | D2 | D3 | D4 |
EXPT
        html => <<"HEXPT",
$deleteme<table border="1" cellpadding="0" cellspacing="1">
<tr><td>A1</td><td>A2</td><td>A3</td><td>A4</td></tr>
<tr><td>B1</td><td rowspan="2" colspan="2">X</td><td>B4</td></tr>
<tr><td>C1</td><td>C4</td></tr>
<tr><td>D1</td><td>D2</td><td>D3</td><td>D4</td></tr>
</table>
HEXPT
    },
    {
        exec => $TML2HTML | $ROUNDTRIP,
        name => 'mergedRowsAndColumnsTopLeft',
        tml  => <<EXPT,
| X || A3 |
| ^ | B3 |
| C1 | C2 | C3 |
EXPT
        html => <<"HEXPT",
$deleteme<table border="1" cellpadding="0" cellspacing="1">
<tr><td rowspan="2" colspan="2">X</td><td>A3</td></tr>
<tr><td>B3</td></tr>
<tr><td>C1</td><td>C2</td><td>C3</td></tr>
</table>
HEXPT
    },
    {
        exec => $TML2HTML | $ROUNDTRIP,
        name => 'mergedRowsAndColumnsTopRight',
        tml  => <<EXPT,
| A1 | X ||
| B1 | ^ |
| C1 | C2 | C3 |
EXPT
        html => <<"HEXPT",
$deleteme<table border="1" cellpadding="0" cellspacing="1">
<tr><td>A1</td><td rowspan="2" colspan="2">X</td></tr>
<tr><td>B1</td></tr>
<tr><td>C1</td><td>C2</td><td>C3</td></tr>
</table>
HEXPT
    },
    {
        exec => $TML2HTML | $ROUNDTRIP,
        name => 'mergedRowsAndColumnsBottomLeft',
        tml  => <<EXPT,
| A1 | A2 | A3 |
| X || B3 |
| ^ | C3 |
EXPT
        html => <<"HEXPT",
$deleteme<table border="1" cellpadding="0" cellspacing="1">
<tr><td>A1</td><td>A2</td><td>A3</td></tr>
<tr><td rowspan="2" colspan="2">X</td><td>B3</td></tr>
<tr><td>C3</td></tr>
</table>
HEXPT
    },
    {
        exec => $TML2HTML | $ROUNDTRIP,
        name => 'mergedRowsAndColumnsBottomRight',
        tml  => <<EXPT,
| A1 | A2 | A3 |
| B1 | X ||
| C1 | ^ |
EXPT
        html => <<"HEXPT",
$deleteme<table border="1" cellpadding="0" cellspacing="1">
<tr><td>A1</td><td>A2</td><td>A3</td></tr>
<tr><td>B1</td><td rowspan="2" colspan="2">X</td></tr>
<tr><td>C1</td></tr>
</table>
HEXPT
    },
    {
        exec => $TML2HTML | $ROUNDTRIP,
        name => 'notAlwaysRowSpan',
        tml  => <<EXPT,
| ^ | B |
| ^ | <nop>^ |
EXPT
        html => <<"HEXPT",
$deleteme<table border="1" cellpadding="0" cellspacing="1">
<tr><td rowspan="2">^</td><td>B</td></tr>
<tr><td>$protecton&lt;nop&gt;$protectoff^</td></tr>
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
        tml  => <<SPACED,
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
        tml  => <<GLUED,
<sticky><font color="blue"> *|B|* </font>

<!-- hidden -->
http://google.com/#q=foswiki
%FOO% WikiWord [[some link]]
   * Set bar=baz
<img src="%!page!%/logo.png" alt="Alternate text" />

<verbatim class="tml">%H%<!--?--></verbatim>
<literal><font color="blue"> *|B|* </font></literal>
<mytag attr="value">my content</mytag>

nested <sticky> block </sticky>

<pre>
  123
 456
</pre></sticky>
GLUED
        html => $deleteme . '<p>'
          . '<div class="WYSIWYG_STICKY">&#60;font&nbsp;color="blue"&#62;&nbsp;*|B|*&nbsp;&#60;/font&#62;<br />'
          . '<br />'
          . '&lt;!--&nbsp;hidden&nbsp;--&gt;<br />'
          . 'http://google.com/#q=foswiki<br />'
          . '%FOO%&nbsp;WikiWord&nbsp;[[some&nbsp;link]]<br />'
          . '&nbsp;&nbsp;&nbsp;*&nbsp;Set&nbsp;bar=baz<br />'
          . '&lt;img&nbsp;src=&quot;%!page!%/logo.png&quot;&nbsp;alt=&quot;Alternate&nbsp;text&quot;&nbsp;/&gt;<br />'
          . '<br />'
          . '&lt;verbatim&nbsp;class=&quot;tml&quot;&gt;%H%&lt;!--?--&gt;&lt;/verbatim&gt;<br />'
          . '&lt;literal&gt;&lt;font&nbsp;color="blue"&gt;&nbsp;*|B|*&nbsp;&lt;/font&gt;&lt;/literal&gt;<br />'
          . '&lt;mytag&nbsp;attr="value"&gt;my&nbsp;content&lt;/mytag&gt;<br />'
          . '<br />'
          . 'nested&nbsp;&lt;sticky&gt;&nbsp;block&nbsp;&lt;/sticky&gt;<br />'
          . '<br />'
          . '&lt;pre&gt;<br />'
          . '&nbsp;&nbsp;123<br />'
          . '&nbsp;456<br />'
          . '&lt;/pre&gt;</div>' . '</p>'
    },
    {
        exec => $TML2HTML | $ROUNDTRIP | $HTML2TML,
        name => 'verbatim',
        tml  => <<GLUED,
<verbatim><font color="blue"> *|B|* </font>

<!-- hidden -->
http://google.com/#q=foswiki
%FOO% WikiWord [[some link]]
   * Set bar=baz
<img src="http://mysite.org/logo.png" alt="Alternate text" />

nested <verbatim class="tml">%H%<!--?--></verbatim>
<literal><font color="blue"> *|B|* </font></literal>
<mytag attr="value">my content</mytag>

<sticky> block </sticky>

<pre>
  123
 456
</pre></verbatim>
GLUED
        html => "$deleteme<p>"
          . '<pre class="TMLverbatim">&#60;font&nbsp;color="blue"&#62;&nbsp;*|B|*&nbsp;&#60;/font&#62;<br />'
          . '<br />'
          . '&lt;!--&nbsp;hidden&nbsp;--&gt;<br />'
          . 'http://google.com/#q=foswiki<br />'
          . '%FOO%&nbsp;WikiWord&nbsp;[[some&nbsp;link]]<br />'
          . '&nbsp;&nbsp;&nbsp;*&nbsp;Set&nbsp;bar=baz<br />'
          . '&lt;img&nbsp;src=&quot;http://mysite.org/logo.png&quot;&nbsp;alt=&quot;Alternate&nbsp;text&quot;&nbsp;/&gt;<br />'
          . '<br />'
          . 'nested&nbsp;&lt;verbatim&nbsp;class=&quot;tml&quot;&gt;%H%&lt;!--?--&gt;&lt;/verbatim&gt;<br />'
          . '&lt;literal&gt;&lt;font&nbsp;color="blue"&gt;&nbsp;*|B|*&nbsp;&lt;/font&gt;&lt;/literal&gt;<br />'
          . '&lt;mytag&nbsp;attr="value"&gt;my&nbsp;content&lt;/mytag&gt;<br />'
          . '<br />'
          . '&lt;sticky&gt;&nbsp;block&nbsp;&lt;/sticky&gt;<br />'
          . '<br />'
          . '&lt;pre&gt;<br />'
          . '&nbsp;&nbsp;123<br />'
          . '&nbsp;456<br />'
          . '&lt;/pre&gt;</pre>' . '</p>'
    },
    {
        exec => $TML2HTML | $HTML2TML | $ROUNDTRIP,
        name => 'comment',
        tml  => <<GLUED,
<!--<font color="blue"> *|B|* </font>

http://google.com/#q=foswiki
%FOO% WikiWord [[some link]]
   * Set bar=baz
<img src="%!page!%/logo.png" alt="Alternate text" />

<verbatim class="tml">%H%<!--?--></verbatim>
<literal><font color="blue"> *|B|* </font></literal>
<mytag attr="value">my content</mytag>

<sticky> block </sticky>

<pre>
  123
 456
</pre>-->
GLUED
        html => '<p>'
          . $protecton
          . '&lt;!--&#60;font&nbsp;color="blue"&#62;&nbsp;*|B|*&nbsp;&#60;/font&#62;<br />'
          . '<br />'
          . 'http://google.com/#q=foswiki<br />'
          . '%FOO%&nbsp;WikiWord&nbsp;[[some&nbsp;link]]<br />'
          . '&nbsp;&nbsp;&nbsp;*&nbsp;Set&nbsp;bar=baz<br />'
          . '&lt;img&nbsp;src=&quot;%!page!%/logo.png&quot;&nbsp;alt=&quot;Alternate&nbsp;text&quot;&nbsp;/&gt;<br />'
          . '<br />'
          . '&lt;verbatim&nbsp;class=&quot;tml&quot;&gt;%H%&lt;!--?--&gt;&lt;/verbatim&gt;<br />'
          . '&lt;literal&gt;&lt;font&nbsp;color="blue"&gt;&nbsp;*|B|*&nbsp;&lt;/font&gt;&lt;/literal&gt;<br />'
          . '&lt;mytag&nbsp;attr="value"&gt;my&nbsp;content&lt;/mytag&gt;<br />'
          . '<br />'
          . '&lt;sticky&gt;&nbsp;block&nbsp;&lt;/sticky&gt;<br />'
          . '<br />'
          . '&lt;pre&gt;<br />'
          . '&nbsp;&nbsp;123<br />'
          . '&nbsp;456<br />'
          . '&lt;/pre&gt;--&gt;'
          . $protectoff . '</p>',
    },
    {

        # SMELL: The macro, the *Set value and the comment
        #        should be in WYSIWYG_PROTECTED spans
        #        but HTML2TML doesn't yet cater for that
        # So this test captures current (long-standing) behaviour,
        # but the behaviour isn't really correct
        exec => $TML2HTML | $HTML2TML | $ROUNDTRIP,
        name => 'literal',
        tml  => <<'HERE',
<literal>
<font color="blue"> *|B|* </font>
http://google.com/#q=foswiki WikiWord [[some link]]
%FOO{"<b>html in macro param</b>"}% <!-- hidden -->
<pre>
  123
 456
</pre>
   * Set bar=baz
<mytag attr="value">my content</mytag>
</literal>
HERE
        html => <<"HERE",
$deleteme<p>
<div class="WYSIWYG_LITERAL">
<font color="blue"> *|B|* </font>
http://google.com/#q=foswiki WikiWord [[some link]]
%FOO{"<b>html in macro param</b>"}% <!-- hidden -->
<pre>
  123
 456
</pre>
   * Set bar=baz
<mytag attr="value">my content</mytag>
</div>
</p>
HERE
        finaltml => <<'HERE',
<literal>
<font color='blue'> *|B|* </font>
http://google.com/#q=foswiki WikiWord [[some link]]
%FOO{"<b>html in macro param</b>"}% <!-- hidden -->
<pre>
  123
 456
</pre>
   * Set bar=baz
<mytag attr='value'>my content</mytag>
</literal>
HERE
    },
    {
        exec => $HTML2TML,
        name => 'mergeStickyItem1667',
        html => <<'BLAH',
<div class="WYSIWYG_STICKY">Line 1</div>
<div class="WYSIWYG_STICKY">Line 2</div>
BLAH
        tml => "<sticky>Line 1\nLine 2</sticky>"
    },
    {
        exec => $HTML2TML | $ROUNDTRIP,
        name => 'separateStickyRegions',
        html => <<'BLAH',
<div class="WYSIWYG_STICKY">Oranges</div>
<p></p>
<div class="WYSIWYG_STICKY">Apples</div>
BLAH
        tml => "<sticky>Oranges</sticky>\n\n<sticky>Apples</sticky>"
    },
    {
        exec => $ROUNDTRIP,
        name => 'verbatimInsideLiteralItem1980',
        tml  => <<'GLUED',
<literal><font color="blue"> *|B|*<verbatim>%H%</verbatim> </font></literal>
GLUED
    },
    {
        exec => $ROUNDTRIP,
        name => 'stickyInsideLiteral',
        tml  => <<'GLUED',
<literal><sticky><font color="blue"> *|B|* </font></sticky/></literal>
GLUED
    },
    {
        exec => $TML2HTML | $HTML2TML | $ROUNDTRIP,
        name => 'selfClosingTagsInsideLiteral',
        html => <<HTML,
$deleteme<p>
<div class="WYSIWYG_LITERAL">X<br />Y<img alt='' src='foo' /></div>
</p>
HTML
        tml => <<'GLUED',
<literal>X<br />Y<img alt='' src='foo' /></literal>
GLUED
    },
    {
        exec => $TML2HTML | $HTML2TML | $ROUNDTRIP,
        name => 'protectedByAttributes',
        html => <<'HTML',
<p>
<br id="foo" />
</p>
HTML
        tml => <<'TML',
<br id="foo" />
TML
    },
    {
        exec => $TML2HTML | $HTML2TML | $ROUNDTRIP,
        name => 'entityWithNoNameInsideSticky',
        tml  => <<'GLUED',
<sticky>&#9792;</sticky>
GLUED
        html => <<"STUCK"
$deleteme<p>
<div class=\"WYSIWYG_STICKY\">&#38;&#35;9792;</div>
</p>
STUCK
    },
    {
        exec => $TML2HTML | $HTML2TML | $ROUNDTRIP,
        name => 'dontOverEncodeProtectedContent',
        tml  => '%MACRO{"<foo>"}%',
        html => "<p>$protecton%MACRO{\"&lt;foo&gt;\"}%$protectoff</p>",
    },
    {
        exec => $TML2HTML | $ROUNDTRIP,
        name => 'Item4705_B',
        tml  => <<SPACED,
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
        tml  => <<SPACED,
   1 One item
     spanning several lines
   1 And another item
 with one space
No more
SPACED
        html => '<ol>
<li> One item'
          . encodedWhitespace('ns5') . 'spanning several lines

</li> <li> And another item'
          . encodedWhitespace('ns1') . 'with one space
</li></ol> 
<p>No more</p>
',
    },
    {
        exec => $ROUNDTRIP,
        name => 'Item4789',
        tml  => "%EDITTABLE{}%\n| 1 | 2 |\n| 3 | 4 |",
    },

    {
        exec => $ROUNDTRIP,
        name => 'ProtectAndSurvive',
        tml =>
'<ul type="compact">Fred</ul><h1 align="right">HAH</h1><ol onclick="burp">Joe</ol>',
    },
    {
        name => 'Item4855',
        exec => $ROUNDTRIP | $TML2HTML,
        tml  => <<HERE,
| [[LegacyTopic1]] | Main.SomeGuy |
%TABLESEP%
%SEARCH{"legacy" nonoise="on" format="| [[\$topic]] | [[\$wikiname]] |"}%
HERE
        html => <<"THERE",
$deleteme<div class="foswikiTableAndMacros">
<table cellspacing="1" cellpadding="0" border="1">
<tr><td><a class='TMLlink' data-wikiword='LegacyTopic1' href="LegacyTopic1">LegacyTopic1</a></td><td><a data-wikiword="Main.SomeGuy" href="Main.SomeGuy">Main.SomeGuy</a></td></tr>
</table>
<span class="WYSIWYG_PROTECTED"><br />%TABLESEP%</span>
<span class="WYSIWYG_PROTECTED"><br />%SEARCH{"legacy"&nbsp;nonoise="on"&nbsp;format="|&nbsp;[[\$topic]]&nbsp;|&nbsp;[[\$wikiname]]&nbsp;|"}%</span>
</div>
THERE
    },
    {
        name => 'Item1798',
        exec => $ROUNDTRIP | $TML2HTML,
        tml  => <<HERE,
| [[LegacyTopic1]] | Main.SomeGuy |
%SEARCH{"legacy" nonoise="on" format="| [[\$topic]] | [[\$wikiname]] |"}%
HERE
        html => <<"THERE",
$deleteme<div class="foswikiTableAndMacros">
<table cellspacing="1" cellpadding="0" border="1">
<tr><td><a class='TMLlink' data-wikiword='LegacyTopic1' href="LegacyTopic1">LegacyTopic1</a></td><td><a data-wikiword="Main.SomeGuy" href="Main.SomeGuy">Main.SomeGuy</a></td></tr>
</table>
<span class="WYSIWYG_PROTECTED"><br />%SEARCH{"legacy"&nbsp;nonoise="on"&nbsp;format="|&nbsp;[[\$topic]]&nbsp;|&nbsp;[[\$wikiname]]&nbsp;|"}%</span>
</div>
THERE
    },
    {
        name => 'linkInTable',
        exec => $ROUNDTRIP | $TML2HTML,
        tml  => <<HERE,
| Main.SomeGuy |
| - Main.SomeGuy - |
Main.SomeGuy
HERE
        html => <<"THERE",
$deleteme<table cellspacing="1" cellpadding="0" border="1">
<tr><td><a data-wikiword="Main.SomeGuy" href="Main.SomeGuy">Main.SomeGuy</a></td></tr>
<tr><td> - <a data-wikiword="Main.SomeGuy" href="Main.SomeGuy">Main.SomeGuy</a> - </td></tr>
</table>
<p>
<a data-wikiword="Main.SomeGuy" href="Main.SomeGuy">Main.SomeGuy</a>
</p>
THERE
    },
    {
        name => 'Item11890',
        exec => $TML2HTML | $ROUNDTRIP,
        tml  => <<'BLAH',
Blah
<a href="%SCRIPTURLPATH{"edit"}%/%WEB%/%TOPIC%?t=%GM%NOP%TIME{"$epoch"}%">edit</a>
Blah
<a href="blah.com" qwerty='oops'>Unsupported attr</a>
<a href='blah.com' target="_blank">Target supported</a>
<a href=blah.com target=_blank>Space delimited</a>
BLAH
        html => '<p>
Blah'
          . encodedWhitespace('n')
          . '<span class="WYSIWYG_PROTECTED">&#60;a&nbsp;href=&#34;%SCRIPTURLPATH{&#34;edit&#34;}%/%WEB%/%TOPIC%?t=%GM%NOP%TIME{&#34;$epoch&#34;}%&#34;&#62;edit&#60;/a&#62;</span>'
          . encodedWhitespace('n') . 'Blah'
          . encodedWhitespace('n')
          . '<span class="WYSIWYG_PROTECTED">&#60;a&nbsp;href=&#34;blah.com&#34;&nbsp;qwerty=&#39;oops&#39;&#62;</span>Unsupported attr<span class="WYSIWYG_PROTECTED">&#60;/a&#62;</span>'
          . encodedWhitespace('n')
          . '<a href=\'blah.com\' target="_blank">Target supported</a>'
          . encodedWhitespace('n')
          . '<a href=blah.com target=_blank>Space delimited</a>' . '
</p>
',
        finaltml => <<'HERE',
Blah
<a href="%SCRIPTURLPATH{"edit"}%/%WEB%/%TOPIC%?t=%GM%NOP%TIME{"$epoch"}%">edit</a>
Blah
<a href="blah.com" qwerty='oops'>Unsupported attr</a>
<a href="blah.com" target="_blank">Target supported</a>
<a href="blah.com" target="_blank">Space delimited</a>
HERE
    },
    {
        name => 'Item4871',
        exec => $TML2HTML | $ROUNDTRIP,
        tml  => <<'BLAH',
Blah
<a href="%SCRIPTURLPATH{"edit"}%/%WEB%/%TOPIC%?t=%GM%NOP%TIME{"$epoch"}%">edit</a>
Blah
BLAH
        html => '<p>
Blah'
          . encodedWhitespace('n')
          . '<span class="WYSIWYG_PROTECTED">&#60;a&nbsp;href=&#34;%SCRIPTURLPATH{&#34;edit&#34;}%/%WEB%/%TOPIC%?t=%GM%NOP%TIME{&#34;$epoch&#34;}%&#34;&#62;edit&#60;/a&#62;</span>'
          . encodedWhitespace('n') . 'Blah
</p>
',
    },

    {
        name => 'Item1396_MacrosRemainSticky',
        exec => $TML2HTML | $HTML2TML | $ROUNDTRIP,
        tml  => <<'BLAH',
[[%ATTACHURL%/LinkEditingInWysiwyg-4.patch][LinkEditingInWysiwyg-4.patch]]
BLAH
        finaltml => <<'BLAH',
[[%ATTACHURL%/LinkEditingInWysiwyg-4.patch][LinkEditingInWysiwyg-4.patch]]
BLAH
        html => <<'BLAH',
<p><a class="TMLlink" href="%ATTACHURL%/LinkEditingInWysiwyg-4.patch">LinkEditingInWysiwyg-4.patch</a> 
</p>
BLAH
    },
    {
        name => 'Item1396_TitleRemainSticky',
        exec => $TML2HTML | $HTML2TML | $ROUNDTRIP,
        tml  => <<'BLAH',
<a href="http://some.website.org/" target="_blank" title="Test">Another html link</a>
BLAH
        finaltml => <<'BLAH',
<a href="http://some.website.org/" target="_blank" title="Test">Another html link</a>
BLAH
        html => <<'BLAH',
<p><a href="http://some.website.org/" target="_blank" title="Test">Another html link</a>
</p>
BLAH
    },
    {
        name => 'Item1396_MarkupInLinkText',
        exec => $TML2HTML | $HTML2TML | $ROUNDTRIP,
        tml  => <<'BLAH',
[[Main/WebHome][=A *BOLD* WebHome=]]
BLAH
        finaltml => <<'BLAH',
[[Main/WebHome][ =A *BOLD* WebHome= ]]
BLAH
        html => <<'BLAH',
<p><a class="TMLlink" href="Main/WebHome"><span class="WYSIWYG_TT">A <b>BOLD</b> WebHome</span></a>
</p>
BLAH
    },
    {
        name => 'Item11784_114_ColorMarkup',
        exec => $TML2HTML | $HTML2TML | $ROUNDTRIP,
        pref => 'RED=<font color="#ff0000">',
        tml  => <<'BLAH',
=A %RED%Red text%ENDCOLOR%
BLAH
        finaltml => <<'BLAH',
=A %RED%Red text%ENDCOLOR%
BLAH
        html => <<'BLAH',
<p>=A <span class='WYSIWYG_COLOR' style='color:#ff0000'>Red text</span>
</p>
BLAH
    },
    {
        name => 'Item11784_115_ColorMarkup',
        exec => $TML2HTML | $HTML2TML | $ROUNDTRIP,
        pref => 'RED=<span class="foswikiRedFG">',
        tml  => <<'BLAH',
=A %RED%Red text%ENDCOLOR%
BLAH
        finaltml => <<'BLAH',
=A %RED%Red text%ENDCOLOR%
BLAH
        html => <<'BLAH',
<p>=A <span class='WYSIWYG_COLOR' style='color:Red'>Red text</span>
</p>
BLAH
    },
    {
        name => 'Item11784_Default_ColorMarkup',
        exec => $TML2HTML | $HTML2TML | $ROUNDTRIP,
        tml  => <<'BLAH',
=A %RED%Red text%ENDCOLOR%
BLAH
        finaltml => <<'BLAH',
=A %RED%Red text%ENDCOLOR%
BLAH
        html => <<'BLAH',
<p>=A <span class='WYSIWYG_COLOR' style='color:Red'>Red text</span>
</p>
BLAH
    },
    {
        name => 'Item11784_ColorsInLinktext',
        exec => $TML2HTML | $HTML2TML | $ROUNDTRIP,
        tml  => <<'BLAH',
[[Main/WebHome][=A %RED%Red text%ENDCOLOR% WebHome=]]
BLAH
        finaltml => <<'BLAH',
[[Main/WebHome][ =A %RED%Red text%ENDCOLOR% WebHome= ]]
BLAH
        html => <<'BLAH',
<p><a class="TMLlink" href="Main/WebHome"><span class="WYSIWYG_TT">A <span class='WYSIWYG_COLOR' style='color:Red'>Red text</span> WebHome</span></a>
</p>
BLAH
    },
    {
        name => 'Item4903',
        exec => $TML2HTML | $ROUNDTRIP,
        tml  => <<'BLAH',
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
        tml  => 'the =complete= table',
    },
    {
        name => "alternateCodeStyleTagsToTML",        # Item2259
        exec => $HTML2TML,
        html => '<kbd>kbd</kbd> <samp>samp</samp>',
        tml  => '=kbd= =samp=',
    },
    {
        name => "flattenDfnVarBig",                               # Item2259
        exec => $HTML2TML,
        html => '<dfn>dfn</dfn> <var>var</var> <big>big</big>',
        tml  => 'dfn var big',
    },
    {
        name => "preserveSmallCite",                              # Item2259
        exec => $TML2HTML | $ROUNDTRIP,
        tml  => <<'BLAH',
<small>small</small> <cite>cite</cite>
BLAH
        html => <<'BLAH',
<p>
<small>small</small> <cite>cite</cite>
</p>
BLAH
    },
    {
        exec => $HTML2TML,
        name => 'strongWithColorClass',
        html => <<'BLAH',
<p>
<strong class="WYSIWYG_COLOR" style="color:#FF0000;">Strong red</strong>
</p>
BLAH
        tml => '*%RED%Strong red%ENDCOLOR%*'
    },
    {
        exec => $HTML2TML | $ROUNDTRIP,
        name => 'colorClassInTable',
        html => <<"BLAH",
$deleteme<table>
<tr><th class="WYSIWYG_COLOR" style="color:#FF0000;">Red Heading</th></tr>
<tr><td class="WYSIWYG_COLOR" style="color:#FF0000;">Red herring</td></tr>
</table>
BLAH
        tml => <<'BLAH',
| *%RED%Red Heading%ENDCOLOR%* |
| %RED%Red herring%ENDCOLOR% |
BLAH
    },
    {
        exec => $HTML2TML | $ROUNDTRIP,
        name => 'colorAndTtClassInTable',
        html => <<"BLAH",
$deleteme<table>
<tr><th class="WYSIWYG_COLOR WYSIWYG_TT" style="color:#FF0000;">Redder code</th></tr>
<tr><td class="WYSIWYG_COLOR WYSIWYG_TT" style="color:#FF0000;">Red code</td></tr>
</table>
BLAH
        tml => <<'BLAH',
| *%RED% =Redder code= %ENDCOLOR%* |
| %RED% =Red code= %ENDCOLOR% |
BLAH
    },
    {
        name => 'fontconv',
        exec => $HTML2TML,
        html => <<HERE,
<font color="red" class="WYSIWYG_COLOR">red</font>
<font style="color:green">green</font>
<font style="border:1;color:blue">blue</font>
<font class="WYSIWYG_COLOR" style="border:1;color:yellow">yellow</font>
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
        tml  => <<HERE,
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
        exec => $TML2HTML | $HTML2TML | $ROUNDTRIP,
        html => <<HERE,
<p class="foswikiDeleteMe">&nbsp;</p><table border="0"><tbody><tr><td>
<h2 class="TML">  Argh </h2>
<ul>
<li> Ergh 
</li>
</ul>
</td><td> </td></tr><tr><td> </td><td> </td></tr></tbody></table>
HERE
        tml => <<'HERE',
<table border="0"><tbody><tr><td>
---++ Argh
   * Ergh 
</td><td> </td></tr><tr><td> </td><td> </td></tr></tbody></table>
HERE
        finaltml => <<'HERE',
<table border="0"><tbody><tr><td>
---++ Argh
   * Ergh 
</td><td> </td></tr><tr><td> </td><td> </td></tr></tbody></table>
HERE
    },
    {
        name => 'Item5132',
        exec => $TML2HTML,
        html => <<HERE,
<h1 class="TML">  Title<img src="art1.jpg"> </img> </h1>
<p>Peace in earth, and goodwill to all worms</p>
HERE
        tml => <<HERE,
---+ Title<img src="art1.jpg"></img>
Peace in earth, and goodwill to all worms
HERE
    },
    {
        name => 'Item5179',
        exec => $TML2HTML | $HTML2TML,
        tml  => <<HERE,
<smeg>
<verbatim>
<img src="ball&co<ck>s">&><"
</verbatim>
&&gt;&lt;"
HERE
        html => '<p>
<span class="WYSIWYG_PROTECTED">&#60;smeg&#62;</span>'
          . encodedWhitespace('n')
          . '<pre class="TMLverbatim"><br />&#60;img&nbsp;src=&#34;ball&#38;co&#60;ck&#62;s&#34;&#62;&#38;&#62;&#60;&#34;<br /></pre>'
          . encodedWhitespace('n')
          . '&&gt;&lt;"
</p>
',
    },
    {
        name => "Item5337",
        exec => $TML2HTML | $ROUNDTRIP,
        tml  => <<HERE,
<pre>
hello
there
</pre>
HERE
        html => <<HERE,
$deleteme<p>
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
        tml  => <<HERE,
   * A
B
HERE
    },
    {
        name => "Item5961",
        exec => $HTML2TML | $ROUNDTRIP,
        html =>
' <strong>zero</strong> <strong>on</strong>e t<strong>w</strong>o t<strong>re</strong>',
        tml =>
'*zero* <strong>on</strong>e t<strong>w</strong>o t<strong>re</strong>',
    },
    {
        name => "Item6089",
        exec => $TML2HTML,
        tml  => <<'ZIS',
<verbatim>
line1\
line2
</verbatim>
ZIS
        html => <<"ZAT",
$deleteme<p><pre class=\"TMLverbatim\"><br />line1\\<br />line2<br /></pre>
</p>
ZAT
    },
    {
        name => "Item2222",
        exec => $ROUNDTRIP,
        tml  => '<!-- <sticky></sticky> -->',
    },
    {
        name => "ItemSVEN",
        exec => $TML2HTML | $ROUNDTRIP,
        tml  => <<'HERE',
---

%SEARCH{search="Sven"}%
HERE
        html => <<'HERE',
<hr class="TMLhr" />
<p class="WYSIWYG_NBNL">
<span class="WYSIWYG_PROTECTED"><br />%SEARCH{search=&#34;Sven&#34;}%</span>
</p>
HERE
    },
    {
        name => "ItemSVEN2",
        exec => $TML2HTML | $ROUNDTRIP,
        tml  => <<'HERE',
---
%SEARCH{search="Sven"}%
HERE
        finaltml => <<'HERE',
---

%SEARCH{search="Sven"}%
HERE
        html => <<'HERE',
<hr class="TMLhr" />
<p>
<span class="WYSIWYG_PROTECTED"><br />%SEARCH{search=&#34;Sven&#34;}%</span>
</p>
HERE
    },
    {
        name => "brTagInMacroFormat",
        exec => $TML2HTML | $HTML2TML | $ROUNDTRIP,
        tml  => <<'HERE',
%JQPLUGINS{"scrollto"
  format="
    Homepage: $homepage <br />
    Author(s): $author <br />
    Version: $version
  "
}%
HERE
        html => <<'HERE',
<p><span class="WYSIWYG_PROTECTED">%JQPLUGINS{"scrollto"<br />&nbsp;&nbsp;format="<br />&nbsp;&nbsp;&nbsp;&nbsp;Homepage:&nbsp;$homepage&nbsp;&lt;br&nbsp;/&gt;<br />&nbsp;&nbsp;&nbsp;&nbsp;Author(s):&nbsp;$author&nbsp;&lt;br&nbsp;/&gt;<br />&nbsp;&nbsp;&nbsp;&nbsp;Version:&nbsp;$version<br />&nbsp;&nbsp;"<br />}%</span></p>
HERE
    },
    {
        name => "stuffInMacro",
        exec => $TML2HTML | $ROUNDTRIP,
        tml  => <<'HERE',
%MACRO{"
a%ANOTHER%
<verbatim>V</verbatim>
<sticky>S</sticky>
<literal>L</literal>
<pre>P</pre>
<!--C-->
   * Set foo=bar
http://google.com/#q=foswiki
WikiWord [[some link]]
<mytag attr="value">my content</mytag>
<img src="http://mysite.org/logo.png" alt="Alternate text" />
"}%
HERE
        html => '<p>'
          . '<span class="WYSIWYG_PROTECTED">'
          . '%MACRO{"<br />'
          . 'a%ANOTHER%<br />'
          . '&lt;verbatim&gt;V&lt;/verbatim&gt;<br />'
          . '&lt;sticky&gt;S&lt;/sticky&gt;<br />'
          . '&lt;literal&gt;L&lt;/literal&gt;<br />'
          . '&lt;pre&gt;P&lt;/pre&gt;<br />'
          . '&lt;!--C--&gt;<br />'
          . '&nbsp;&nbsp;&nbsp;*&nbsp;Set&nbsp;foo=bar<br />'
          . 'http://google.com/#q=foswiki<br />'
          . 'WikiWord&nbsp;[[some&nbsp;link]]<br />'
          . '&lt;mytag&nbsp;attr="value"&gt;my&nbsp;content&lt;/mytag&gt;<br />'
          . '&lt;img&nbsp;src=&quot;http://mysite.org/logo.png&quot;&nbsp;alt=&quot;Alternate&nbsp;text&quot;&nbsp;/&gt;<br />'
          . '"}%'
          . '</span>' . '</p>'
    },
    {
        name => "whitespaceEncoding",
        exec => $TML2HTML | $ROUNDTRIP,
        tml  => <<'HERE',
a  a
 b
   * c
     d
e
HERE
        html => '<p>' . 'a'
          . encodedWhitespace('s2') . 'a'
          . encodedWhitespace('ns1') . 'b' . '</p>'
          . '<ul><li>' . 'c'
          . encodedWhitespace('ns5') . 'd'
          . '</li></ul>' . '<p>' . 'e' . '</p>',
    },
    {
        name => "failsTML2HTML",
        exec => 0,                 #$TML2HTML | $HTML2TML | $ROUNDTRIP,
        tml  => <<'HERE',
%MACRO{"
%ANOTHERMACRO%"}%
HERE
        html => <<'HERE',
<p><span class="WYSIWYG_PROTECTED">%MACRO{"<br />%ANOTHERMACRO%"}%</span></p>
HERE
    },
    {
        name => 'Item11378_del_ins_and_strike',
        exec => $HTML2TML,
        html => <<HTML,
yes <del>no</del> YES <strike>NO</strike> <ins>yes</ins> no
HTML
        tml => <<TML
yes <del>no</del> YES <strike>NO</strike> <ins>yes</ins> no
TML
    },
    {
        name => "Item11440",
        exec => $HTML2TML | $TML2HTML | $ROUNDTRIP,
        tml  => <<'HERE',
<pre><b>this will
disappear.</b>
 and
 <b>this will be surrounded by stars</b>
</pre>

<code><pre>This will disappear,
leaving an empty pre-tag</pre></code>

<pre><code>As will
this.</code></pre>
HERE
        html => <<"HERE",
$deleteme<p>
<pre><b>this will
disappear.</b>
 and
 <b>this will be surrounded by stars</b>
</pre>
</p>
<p>
<code><pre>This will disappear,
leaving an empty pre-tag</pre></code>
</p>
<p>
<pre><code>As will
this.</code></pre>
</p>
HERE
    },
    {
        exec => $TML2HTML | $ROUNDTRIP,
        name => 'ttTableNewlineCorruptionItem11312',
        tml  => <<'HERE',
<table border="1" cellpadding="0" cellspacing="1"> 
   <tbody> 
      <tr> 
         <td>A</td> 
         <td>B
         
            C
         </td>  
         <td>D</td> 
      </tr>   
   </tbody> 
</table>
HERE
        html => <<'HERE',
<p class="foswikiDeleteMe">&nbsp;</p><table border="1" cellpadding="0" cellspacing="1"> <span style="{encoded:'ns3'}" class="WYSIWYG_HIDDENWHITESPACE">&nbsp;</span><tbody> <span style="{encoded:'ns6'}" class="WYSIWYG_HIDDENWHITESPACE">&nbsp;</span><tr> <span style="{encoded:'ns9'}" class="WYSIWYG_HIDDENWHITESPACE">&nbsp;</span><td>A</td> <span style="{encoded:'ns9'}" class="WYSIWYG_HIDDENWHITESPACE">&nbsp;</span><td>B
<p></p><span style="{encoded:'ns12'}" class="WYSIWYG_HIDDENWHITESPACE">&nbsp;</span>C<span style="{encoded:'ns9'}" class="WYSIWYG_HIDDENWHITESPACE">&nbsp;</span></td><span style="{encoded:'s2'}" class="WYSIWYG_HIDDENWHITESPACE">&nbsp;</span><span style="{encoded:'ns9'}" class="WYSIWYG_HIDDENWHITESPACE">&nbsp;</span><td>D</td> <span style="{encoded:'ns6'}" class="WYSIWYG_HIDDENWHITESPACE">&nbsp;</span></tr><span style="{encoded:'s3'}" class="WYSIWYG_HIDDENWHITESPACE">&nbsp;</span><span style="{encoded:'ns3'}" class="WYSIWYG_HIDDENWHITESPACE">&nbsp;</span></tbody> 
</table>
HERE
        finaltml => <<'HERE'
<table border="1" cellpadding="0" cellspacing="1">
   <tbody>
      <tr>
         <td>A</td>
         <td>B

            C
         </td>  
         <td>D</td>
      </tr>   
   </tbody> </table>
HERE
    },
    {
        exec => $TML2HTML,
        name => 'protectScriptFromWysiwyg_Item11603',
        tml  => <<'HERE',
<script option="blah">
  * Some script stuff
  <p>
  *ToBeIgnored*
</script>
HERE
        html => <<'HERE'
<p><span class="WYSIWYG_PROTECTED">&#60;script&nbsp;option=&#34;blah&#34;&#62;<br />&nbsp;&nbsp;*&nbsp;Some&nbsp;script&nbsp;stuff<br />&nbsp;&nbsp;&#60;p&#62;<br />&nbsp;&nbsp;*ToBeIgnored*<br />&#60;/script&#62;</span>
</p>
HERE
    },
    {
        exec => $TML2HTML | $ROUNDTRIP,
        name => 'protectStyleFromWysiwyg_Item11603',
        tml  => <<'HERE',
<style type="text/css">
.pics  {  
 width:232px;
 height:272px;
 padding:0;  
 margin:0;
 text-align:center;
}
</style>
HERE
        html => <<'HERE'
<p><span class="WYSIWYG_PROTECTED">&#60;style&nbsp;type=&#34;text/css&#34;&#62;<br />.pics&nbsp;&nbsp;{&nbsp;&nbsp;<br />&nbsp;width:232px;<br />&nbsp;height:272px;<br />&nbsp;padding:0;&nbsp;&nbsp;<br />&nbsp;margin:0;<br />&nbsp;text-align:center;<br />}<br />&#60;/style&#62;</span>
</p>
HERE
    },
    {
        exec => $TML2HTML,
        name => 'protectAnchorsFromWrap_Item10125',
        tml  => <<'HERE',
---++ Accepted
TBD
#ApprovedTerm
---++ Approved
blah
HERE
        html => <<'HERE'
<h2 class="TML">  Accepted  </h2>
<p>TBD <span style="{encoded:'n'}" class="WYSIWYG_HIDDENWHITESPACE">&nbsp;</span><span class="WYSIWYG_PROTECTED"><br />#ApprovedTerm</span> 
</p>
<h2 class="TML">  Approved  </h2>
<p>blah</p>
HERE
    },
    {
        exec => $TML2HTML | $ROUNDTRIP,
        name => 'protectHtmlHeadingsInTables_Item9259',
        tml  => <<'HERE',
<table> <tbody> 
<tr> <td> <h3> b </h3> </td> </tr> 
</tbody> </table>
HERE
        html => <<'HERE',
<p class="foswikiDeleteMe">&nbsp;</p><table> <tbody> <span style="{encoded:'n'}" class="WYSIWYG_HIDDENWHITESPACE">&nbsp;</span><tr> <td> <h3> b </h3> </td> </tr> 
</tbody> </table>
HERE
        finaltml => <<'HERE'
<table> <tbody>
<tr> <td>
---+++ b
</td> </tr> </tbody> </table>
HERE
    },
    {

# Unmatched ( in regex; marked by <-- HERE in m/\
# .^V%N%^W^V%ICON{connections}%^W  ==I change text== ( <-- HERE == $/ at /usr/local/ww
# w/foswiki/lib/Foswiki/Plugins/WysiwygPlugin/HTML2TML/Node.pm line 1456.
#  at /usr/local/www/foswiki/lib/Foswiki/Plugins/WysiwygPlugin/HTML2TML/Node.pm line 1456
        name => "regexQuotingProblem_Item12011",
        exec => $TML2HTML | $HTML2TML | $ROUNDTRIP,
        tml  => <<'HERE',
%N%
%ICON{connections}%
  ==I change text== (
HERE
        html => <<'HERE',
<p><span class="WYSIWYG_PROTECTED">%N%</span><span class="WYSIWYG_PROTECTED"><br />%ICON{connections}%</span><span style="{encoded:'ns2'}" class="WYSIWYG_HIDDENWHITESPACE">&nbsp;</span>==I change text== (
</p>
HERE
    },
];

sub encodedWhitespace {
    my $encoded = shift;
    return
        '<span class="WYSIWYG_HIDDENWHITESPACE" style="{encoded:'
      . "'$encoded'"
      . '}">&nbsp;</span>';
}

# Run from BEGIN
sub gen_file_tests {
    foreach my $d (@INC) {
        if ( -d "$d/test_html" && $d =~ /WysiwygPlugin/ ) {
            opendir( D, "$d/test_html" ) or die;
            foreach my $file ( grep { /^.*\.html$/i } readdir D ) {
                $file =~ s/\.html$//;
                my $test = { name => $file };
                open( F, '<', "$d/test_html/$file.html" );
                undef $/;
                $test->{html} = <F>;
                close(F);
                next unless -e "$d/result_tml/$file.txt";
                open( F, '<', "$d/result_tml/$file.txt" );
                undef $/;
                $test->{finaltml} = <F>;
                close(F);
                my $fn = 'TranslatorTests::test_HTML2TML_FILE_' . $test->{name};
                no strict 'refs';
                *$fn = sub { shift->compareHTML_TML($test) };
                use strict 'refs';
            }
            last;
        }
    }
}

sub set_up {
    my $this = shift;
    $this->SUPER::set_up(@_);
    $Foswiki::cfg{Plugins}{WysiwygPlugin}{Enabled} = 1;

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
    $this->{session}->finish() if ( defined( $this->{session} ) );
    $this->{session} = new Foswiki( undef, $query );
    $Foswiki::Plugins::SESSION = $this->{session};
}

sub normaliseEntities {
    my $text = shift;

    # Convert text entities to &# representation
    $text =~ s/(&\w+;)/'&#'.ord(HTML::Entities::decode_entities($1)).';'/ge;
    return $text;
}

sub TML_HTMLconverterOptions {
    my ( $this, %overrides ) = @_;
    return {
        web          => 'Current',
        topic        => 'TestTopic',
        convertImage => \&convertImage,
        rewriteURL   => \&Foswiki::Plugins::WysiwygPlugin::postConvertURL,
        expandVarsInURL =>
          \&Foswiki::Plugins::WysiwygPlugin::Handlers::expandVarsInURL,
        dieOnError => 1,
        %overrides
    };
}

sub compareTML_HTML {
    my ( $this, $args ) = @_;
    my ( $web, $topic ) =
      ( $args->{web} || 'Current', $args->{topic} || 'TestTopic' );

    my $page = $this->{session}->getScriptUrl( 1, 'view', $web, $topic );
    $page =~ s/\/$web\/$topic.*$//;
    my $html = $args->{html} || '';
    $html =~ s/%!page!%/$page/g;
    my $finaltml = $args->{finaltml} || '';
    $finaltml =~ s/%!page!%/$page/g;
    my $tml = $args->{tml} || '';
    $tml =~ s/%!page!%/$page/g;

    my $pref = $args->{pref} || '';
    if ($pref) {
        my ( $name, $value ) = split( '=', $pref, 2 );
        Foswiki::Func::setPreferencesValue( $name, $value );
    }

    my $notEditable = Foswiki::Plugins::WysiwygPlugin::notWysiwygEditable($tml);
    $this->assert( !$notEditable, $notEditable );

    my $txer = new Foswiki::Plugins::WysiwygPlugin::TML2HTML();
    my $tx =
      $txer->convert( $tml,
        $this->TML_HTMLconverterOptions( web => $web, topic => $topic ) );

    $this->assert_html_equals( $html, $tx );

    # Item10171: Ensure &#160; works the same as &nbsp;
    my $tml160  = convertNbspTo160($tml);
    my $html160 = convertNbspTo160($html);
    if ( $html160 ne $html or $tml160 ne $tml ) {
        $tx =
          $txer->convert( $tml160,
            $this->TML_HTMLconverterOptions( web => $web, topic => $topic ) );

        $this->assert_html_equals( $html160, $tx );
    }
}

sub compareNotWysiwygEditable {
    my ( $this, $args ) = @_;

    my $page =
      $this->{session}->getScriptUrl( 1, 'view', 'Current', 'TestTopic' );
    $page =~ s/\/Current\/TestTopic.*$//;
    my $html = $args->{html} || '';
    $html =~ s/%!page!%/$page/g;
    my $finaltml = $args->{finaltml} || '';
    $finaltml =~ s/%!page!%/$page/g;
    my $tml = $args->{tml} || '';
    $tml =~ s/%!page!%/$page/g;

    my $notEditable =
      Foswiki::Plugins::WysiwygPlugin::notWysiwygEditable( $tml, '' );
    $this->assert( $notEditable,
        "This TML should not be wysiwyg-editable: $tml" );
}

sub compareRoundTrip {
    my ( $this, $args ) = @_;
    my ( $web, $topic ) =
      ( $args->{web} || 'Current', $args->{topic} || 'TestTopic' );

    my $page = $this->{session}->getScriptUrl( 1, 'view', $web, $topic );
    $page =~ s/\/$web\/$topic.*$//;

    my $tml = $args->{tml} || '';
    $tml =~ s/%!page!%/$page/g;

    my $pref = $args->{pref} || '';
    if ($pref) {
        my ( $name, $value ) = split( '=', $pref, 2 );
        Foswiki::Func::setPreferencesValue( $name, $value );
    }

    my $txer = new Foswiki::Plugins::WysiwygPlugin::TML2HTML();

    # This conversion can throw an exception.
    # This might be expected if $args->{exec} also has $CANNOTWYSIWYG set
    my $html = eval {
        $txer->convert( $tml,
            $this->TML_HTMLconverterOptions( web => $web, topic => $topic ) );
    };
    $html = $@ if $@;

    $txer = new Foswiki::Plugins::WysiwygPlugin::HTML2TML();
    my $tx =
      $txer->convert( $html,
        $this->HTML_TMLconverterOptions( web => $web, topic => $topic ) );
    my $finaltml = $args->{finaltml} || $tml;
    $finaltml =~ s/%!page!%/$page/g;

    my $notEditable =
      Foswiki::Plugins::WysiwygPlugin::notWysiwygEditable( $tml, '' );
    if ( ( $mask & $args->{exec} ) & $CANNOTWYSIWYG ) {
        $this->assert( $notEditable,
            "This TML should not be wysiwyg-editable: $tml" );

     # Expect that roundtrip is not possible if notWysiwygEditable returns true.
     # notWysiwygEditable should not return false for anything that *can* be
     # roundtripped.
        $this->assert_tml_not_equals( $finaltml, $tx, $args->{name} );
    }
    else {
        $this->assert_tml_equals( $finaltml, $tx, $args->{name} );
        if ( $html =~ /WYSIWYG_WARNING/ ) {

            # The HTML contains a warning message saying that this TML
            # cannot be edited as HTML, and all of the TML is protected
            # as if the whole topic were in a <sticky> block
        }
        else {

            # This TML really is editable in the WYSIWYG editor
            $this->assert( !$notEditable,
"$args->{name} TML is wysiwyg-editable, but notWysiwygEditable() reports: $notEditable"
            );
        }
    }

}

sub HTML_TMLconverterOptions {
    my ( $this, %overrides ) = @_;
    return {
        web          => 'Current',
        topic        => 'TestTopic',
        convertImage => \&convertImage,
        rewriteURL   => \&Foswiki::Plugins::WysiwygPlugin::postConvertURL,
        %overrides
    };
}

sub compareHTML_TML {
    my ( $this, $args ) = @_;
    my ( $web, $topic ) =
      ( $args->{web} || 'Current', $args->{topic} || 'TestTopic' );

    my $page = $this->{session}->getScriptUrl( 1, 'view', $web, $topic );
    $page =~ s/\/$web\/$topic.*$//;
    my $html = $args->{html} || '';
    $html =~ s/%!page!%/$page/g;
    my $tml = $args->{tml} || '';
    $tml =~ s/%!page!%/$page/g;
    my $finaltml = $args->{finaltml} || $tml;
    $finaltml =~ s/%!page!%/$page/g;

    my $pref = $args->{pref} || '';
    if ($pref) {
        my ( $name, $value ) = split( '=', $pref, 2 );
        Foswiki::Func::setPreferencesValue( $name, $value );
    }

    my $txer = new Foswiki::Plugins::WysiwygPlugin::HTML2TML();
    my $tx =
      $txer->convert( $html,
        $this->HTML_TMLconverterOptions( web => $web, topic => $topic ) );
    $this->assert_tml_equals( $finaltml, $tx, $args->{name} );

    # Item10171: Ensure &#160; works the same as &nbsp;
    my $html160     = convertNbspTo160($html);
    my $finaltml160 = convertNbspTo160($finaltml);
    if ( $html160 ne $html or $finaltml160 ne $finaltml ) {
        $tx =
          $txer->convert( $html160,
            $this->HTML_TMLconverterOptions( web => $web, topic => $topic ) );
        $this->assert_tml_equals( $finaltml160, $tx,
            $args->{name} . ' nbsp as #160' );
    }
}

sub convertNbspTo160 {
    my ($text) = @_;

    $text =~
      s/(<verbatim[^>]*>)(.*?)(<\/verbatim>)/$1 . escapeNbsp($2) . $3/gemxs;
    $text =~ s/\&nbsp;/\&#160;/g;
    $text =~ s/\&\0nbsp;/&nbsp;/g;

    return $text;
}

sub escapeNbsp {
    my ($text) = @_;

    $text =~ s/\&nbsp;/\&\0nbsp;/g;

    return $text;
}

sub convertImage {
    my $url = shift;

    if ( $url eq "test_image" ) {
        return '%TRANSLATEDIMAGE%';
    }
}

#TranslatorTests->gen_compare_tests( 'test', [ grep { $_->{name} eq 'Item4855' } @$data ] );
TranslatorTests->gen_compare_tests( 'test', $data );

#gen_file_tests();

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
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
