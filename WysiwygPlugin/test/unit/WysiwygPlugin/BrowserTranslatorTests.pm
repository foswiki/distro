use strict;
use warnings;

package BrowserTranslatorTests;

use FoswikiSeleniumTestCase;
use TranslatorBase;
our @ISA = qw( FoswikiSeleniumTestCase TranslatorBase );

use BrowserEditorInterface;
use Foswiki::Func;
use Foswiki::Plugins::WysiwygPlugin::Handlers;

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
my $data = [
    {
        exec => $TranslatorBase::ROUNDTRIP | $TranslatorBase::HTML2TML |
          $TranslatorBase::TML2HTML,
        name => 'linkAtStart',
        tml  => 'LinkAtStart',
        html => '<p>'
          . $TranslatorBase::linkon
          . 'LinkAtStart'
          . $TranslatorBase::linkoff . '</p>',
    },
    {
        exec => $TranslatorBase::ROUNDTRIP,
        name => 'otherWebLinkAtStart',
        tml  => 'OtherWeb.LinkAtStart',
        html => $TranslatorBase::linkon
          . 'OtherWeb.LinkAtStart'
          . $TranslatorBase::linkoff,
    },
    {
        exec => $TranslatorBase::ROUNDTRIP,
        name => 'currentWebLinkAtStart',
        tml  => 'Current.LinkAtStart',
        html => $TranslatorBase::linkon
          . 'Current.LinkAtStart'
          . $TranslatorBase::linkoff,
        finaltml => 'Current.LinkAtStart',
    },
    {
        exec => $TranslatorBase::ROUNDTRIP,
        name => 'simpleParas',
        html => '1st paragraph<p />2nd paragraph',
        tml  => <<'HERE',
1st paragraph

2nd paragraph
HERE
    },
    {
        name => 'Item1798',
        exec => $TranslatorBase::ROUNDTRIP,
        tml  => <<HERE,
| [[LegacyTopic1]] | Main.SomeGuy |
%SEARCH{"legacy" nonoise="on" format="| [[\$topic]] | [[\$wikiname]] |"}%
HERE
        html => <<THERE,
<table cellspacing="1" cellpadding="0" border="1">
<tr><td><span class="WYSIWYG_LINK">[[LegacyTopic1]]</span></td><td><span class="WYSIWYG_LINK">Main.SomeGuy</span></td></tr>
</table>
<span class="WYSIWYG_PROTECTED">%SEARCH{"legacy" nonoise="on" format="| [[\$topic]] | [[\$wikiname]] |"}%</span>
THERE
    },
    {
        name => 'startOfParagraph',
        exec => $TranslatorBase::ROUNDTRIP,
        tml  => <<HERE,
%STARTINCLUDE%
---+ Foswiki Contribs

_Extensions to Foswiki that are not plugins_
%ENDINCLUDE%

%TOC%
HERE
    },
    {
        name => "ItemSVEN",
        exec => $TranslatorBase::TML2HTML | $TranslatorBase::ROUNDTRIP,
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
        name => 'Item4855',
        exec => $TranslatorBase::TML2HTML | $TranslatorBase::ROUNDTRIP,
        tml  => <<HERE,
| [[LegacyTopic1]] | Main.SomeGuy |
%TABLESEP%
%SEARCH{"legacy" nonoise="on" format="| [[\$topic]] | [[\$wikiname]] |"}%
HERE
        html => <<THERE,
<div class="foswikiTableAndMacros">
<table cellspacing="1" cellpadding="0" border="1"><tbody>
<tr><td><span class="WYSIWYG_LINK">[[LegacyTopic1]]</span></td><td><span class="WYSIWYG_LINK">Main.SomeGuy</span></td></tr>
</tbody></table>
<span class="WYSIWYG_PROTECTED"><br />%TABLESEP%</span>
<span class="WYSIWYG_PROTECTED"><br />%SEARCH{"legacy" nonoise="on" format="| [[\$topic]] | [[\$wikiname]] |"}%</span>
</div>
THERE
    },

    {    # Copied on 29 April 2010 from
           # http://merlin.lavrsen.dk/foswiki10/bin/view/Myweb/NewLineEatingTest
         # and then split into multiple tests to make analysing the result managable
        name => 'KennethsNewLineEatingTest1',
        exec => $TranslatorBase::ROUNDTRIP,
        tml  => <<HERE,
---++ This is a test topic where TMCE eats new lines in some cases

See Bugs.Item4705

Edit it in TMCE and save.

Repeat the edit and save many *times* and see the topic become a Goofy topic.
HERE
    },
    {
        name => 'KennethsNewLineEatingTest8',
        exec => $TranslatorBase::ROUNDTRIP,
        tml  => <<HERE,
<nop>
   * Set CHANGEHISTORY = | Text | Number | Text with another Twiki variable |    

| *Who* | *Rev* | *Description* |
| pre_capture | 1 | include images before first motion detect |
| post_capture | 2 | append images after last motion detect |
%CHANGEHISTORY%
HERE
    },
    {
        name => 'KennethsNewLineEatingTest2',
        exec => $TranslatorBase::ROUNDTRIP,
        tml  => <<HERE,
---+++ Some test headline.

Below is what could be an example of C code

<verbatim>
/* If Labeling enabled - locate center of largest labelgroup */
if (imgs->labelsize_max) {
    /* Locate largest labelgroup */
    for (y=0; y<height; y++) {
        for (x=0; x<width; x++) {
            if (*(labels++)&32768) {
                cent->x += x;
                cent->y += y;
                centc++;
            }
        }
    }
} else {
</verbatim>

---+++ And now an example with text and table
HERE
    },
    {
        name => 'KennethsNewLineEatingTest3',
        exec => $TranslatorBase::ROUNDTRIP,
        tml  => <<HERE,
These two options are defined like this

| *Option* | *Function* |
| pre_capture | include images before first motion detect |
| post_capture | append images after last motion detect |
and in the config code you find this

<verbatim>
{
    "pre_capture",
    "# Specifies the number of pre-captured (buffered) pictures from before motion\n"
    "# was detected that will be output at motion detection.\n"
    "# Recommended range: 0 to 5 (default: 0)\n"
    "# Do not use large values! Large values will cause Motion to skip video frames and\n"
    "# cause unsmooth mpegs. To smooth mpegs use larger values of post_capture instead.",
    CONF_OFFSET(pre_capture),
    copy_int,
    print_int
},
{
    "post_capture",
    "# Number of frames to capture after motion is no longer detected (default: 0)",
    CONF_OFFSET(post_capture),
    copy_int,
    print_int
},
</verbatim>
HERE
    },
    {
        name => 'KennethsNewLineEatingTest4',
        exec => $TranslatorBase::ROUNDTRIP,
        tml  => <<HERE,
---+++ More code right after headline

<verbatim>
char *mystrcpy(char *to, const char *from)
{
    /* free the memory used by the to string, if such memory exists,
     * and return a pointer to a freshly malloc()'d string with the
     * same value as from.
     */

    if (to != NULL) 
        free(to);

    return mystrdup(from);
}
</verbatim>
HERE
    },
    {
        name => 'KennethsNewLineEatingTest5',
        exec => 0,                           # fails $TranslatorBase::ROUNDTRIP,
        tml  => <<HERE,
---+++ Some stuff protected by literal

| This is a two row table |
| This is second row |
<literal>
<TABLE bgColor='yellow'>
<TBODY>
<TR>
<TD>
<UL>
<LI>TML bullet </li>
<LI>Another TML bullet </li>
<LI>Why not a 3rd one </li></ul></td></tr></tbody></table></literal>

---+++ Same but with text before
The text below is yellow <literal>
<TABLE bgColor='yellow'>
<TBODY>
<TR>
<TD>
<UL>
<LI>TML bullet </li>
<LI>Another TML bullet </li>
<LI>Why not a 3rd one </li></ul></td></tr></tbody></table></literal>
HERE
    },
    {
        name => 'KennethsNewLineEatingTest6',
        exec => 0,                           # fails $TranslatorBase::ROUNDTRIP,
        tml  => <<HERE,

---+++ Plain text

Some text

<verbatim>
Hej hej
</verbatim>

---+++ Example that failed in Item4705

Tralala

<literal><B>Some text</b> </literal>

Trala

Tralala

<literal><B>Some text</b> </literal>

Trala 
---
Tralala

<literal><B>Some text</b> </literal>

Trala 
---

Tralala lala

<literal><B>Some text</b> </literal>

Trala
HERE
    },
    {
        name => 'KennethsNewLineEatingTest7',
        exec => 0,                           # fails $TranslatorBase::ROUNDTRIP,
        tml  => <<HERE,

---+++ Literal after header

<literal><B>Some bold</b> </literal>

---+++ Literal after table

| *Table* | *Nice* |
| 23 | 45 |
| 56 | 52 |

<literal><B>Some bold</b> </literal>

---+++ Literal after bullet

   * Bullet 1 
   * Bullet 2 

<literal><B>Some bold</b> </literal>

-- Main.KennethLavrsen - 24 Sep 2007
HERE
    },
];

sub new {
    my $self = shift()->SUPER::new( 'BrowserTranslator', @_ );

    $self->{editor} = BrowserEditorInterface->new($self);

    return $self;
}

sub _init {
    my $this = shift;

    $this->{editor}->init();

    if ( not defined $this->{editor}->editorMode() ) {
        $this->{editor}
          ->openWysiwygEditor( $this->{test_web}, $this->{test_topic} );
    }
}

sub DESTROY {
    my $this = shift;

    $this->{editor}->finish();

    $this->SUPER::DESTROY if $this->can('SUPER::DESTROY');
}

sub compareTML_HTML {
    my ( $this, $args ) = @_;

    $this->_init();

    $this->{editor}->selectWikitextMode();
    $this->{editor}->setWikitextEditorContent( $args->{tml} );
    $this->{editor}->selectWysiwygMode();
    my $actualHtml = $this->{editor}->getWysiwygEditorContent();

#SMELL: Selenium on Firefox returns <br> instead of <br />, and similarly for <hr />
    $actualHtml =~ s{<([bh]r[^/>]*)>}{<$1 />}g;

    $actualHtml =~
      s/^<!--$Foswiki::Plugins::WysiwygPlugin::Handlers::SECRET_ID-->//go
      or $this->assert( 0, "HTML did not contain the secret ID\n$actualHtml" );
    $this->assert_html_equals( $args->{html}, $actualHtml );
}

sub compareNotWysiwygEditable {
    my ( $this, $args ) = @_;
    $this->assert( 0,
        ref($this) . "::compareNotWysiwygEditable not implemented" );
}

sub compareRoundTrip {
    my $this = shift;
    my $args = shift;

    $this->_init();

    $this->{editor}->selectWikitextMode();
    $this->{editor}->setWikitextEditorContent( $args->{tml} );
    $this->{editor}->selectWysiwygMode();
    my $actualHtml = $this->{editor}->getWysiwygEditorContent();

    #print STDERR "HTML [$actualHtml]\n";
    $this->{editor}->selectWikitextMode();
    my $actualTml = $this->{editor}->getWikitextEditorContent();

    $this->assert_tml_equals( $args->{finaltml} || $args->{tml},
        $actualTml, $args->{name} );
}

sub compareHTML_TML {
    my ( $this, $args ) = @_;

    $this->_init();

    $this->{editor}->selectWysiwygMode();
    $this->{editor}->setWysiwygEditorContent( $args->{html} );
    $this->{editor}->selectWikitextMode();
    my $actualTml = $this->{editor}->getWikitextEditorContent();

    $this->assert_tml_equals( $args->{tml}, $actualTml, $args->{name} );
}

BrowserTranslatorTests->gen_compare_tests( 'verify', $data );

1;

