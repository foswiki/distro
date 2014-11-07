# See bottom of file for license and copyright information
use strict;
use warnings;

package BrowserTranslatorTests;

use Encode;

use FoswikiSeleniumTestCase();
use TranslatorBase;
our @ISA = qw( FoswikiSeleniumTestCase TranslatorBase );

use BrowserEditorInterface();
use Foswiki::Func();
use Foswiki::Plugins::WysiwygPlugin::Handlers();
use Foswiki::Plugins::WysiwygPlugin::Constants();

# See TranslatorTests for details of how these tests work
my $data = [
    {
        exec => ROUNDTRIP | HTML2TML | TML2HTML,
        name => 'linkAtStart',
        tml  => 'LinkAtStart',
        html => '<p>' . $LINKON . 'LinkAtStart' . $LINKOFF . '</p>',
    },
    {
        exec => ROUNDTRIP,
        name => 'otherWebLinkAtStart',
        tml  => 'OtherWeb.LinkAtStart',
        html => $LINKON . 'OtherWeb.LinkAtStart' . $LINKOFF,
    },
    {
        exec     => ROUNDTRIP,
        name     => 'currentWebLinkAtStart',
        tml      => 'Current.LinkAtStart',
        html     => $LINKON . 'Current.LinkAtStart' . $LINKOFF,
        finaltml => 'Current.LinkAtStart',
    },
    {
        exec => ROUNDTRIP,
        name => 'simpleParas',
        html => '1st paragraph<p />2nd paragraph',
        tml  => <<'HERE',
1st paragraph

2nd paragraph
HERE
    },
    {
        name => 'Item1798',
        exec => ROUNDTRIP,
        tml  => <<'HERE',
| [[LegacyTopic1]] | Main.SomeGuy |
%SEARCH{"legacy" nonoise="on" format="| [[\$topic]] | [[\$wikiname]] |"}%
HERE
        html => <<'THERE',
<p class="foswikiDeleteMe">&nbsp;</p><table cellspacing="1" cellpadding="0" border="1">
<tr><td><span class="WYSIWYG_LINK">[[LegacyTopic1]]</span></td><td><span class="WYSIWYG_LINK">Main.SomeGuy</span></td></tr>
</table>
<span class="WYSIWYG_PROTECTED">%SEARCH{"legacy" nonoise="on" format="| [[\$topic]] | [[\$wikiname]] |"}%</span>
THERE
    },
    {
        name     => 'numericEntityWithoutName',
        exec     => ROUNDTRIP | CHARSETS,
        tml      => '&#9792;',
        finaltml => _siteCharsetIsUTF8() ? chr(9792) : '&#x2640;',
    },
    {
        name     => 'numericEntityWithName',
        exec     => ROUNDTRIP | CHARSETS,
        tml      => '&#945;',
        finaltml => '&alpha;',
    },

    # This test's finaltml is correct for ISO-8859-1 and ISO-8859-15,
    # but not necessarily any other charsets
    (
        (
            not $Foswiki::cfg{Site}{CharSet}
              or $Foswiki::cfg{Site}{CharSet} =~ /^iso-8859-15?$/i
        )
        ? {
            name     => 'safeNamedEntity',
            exec     => ROUNDTRIP | CHARSETS,
            tml      => '&Aring;',
            finaltml => chr(0xC5),
          }
        : ()
    ),

    {
        name => 'namedEntity',
        exec => ROUNDTRIP,
        tml  => '&alpha;',
    },
    {
        name => 'startOfParagraph',
        exec => ROUNDTRIP,
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
        exec => TML2HTML | ROUNDTRIP,
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
        name => 'literalNbsp',
        exec => ROUNDTRIP | CHARSETS | TML2HTML,
        tml  => <<HERE,
<literal>&nbsp;</literal>
HERE
        html => <<THERE,
<div class="WYSIWYG_LITERAL">&nbsp;</div>
THERE
    },
    {
        name => 'Item4855',
        exec => TML2HTML | ROUNDTRIP,
        tml  => <<HERE,
| [[LegacyTopic1]] | Main.SomeGuy |
%TABLESEP%
%SEARCH{"legacy" nonoise="on" format="| [[\$topic]] | [[\$wikiname]] |"}%
HERE
        html => <<THERE,
<p class="foswikiDeleteMe">&nbsp;</p><div class="foswikiTableAndMacros">
<table cellspacing="1" cellpadding="0" border="1"><tbody>
<tr><td><span class="WYSIWYG_LINK">[[LegacyTopic1]]</span></td><td><span class="WYSIWYG_LINK">Main.SomeGuy</span></td></tr>
</tbody></table>
<span class="WYSIWYG_PROTECTED"><br />%TABLESEP%</span>
<span class="WYSIWYG_PROTECTED"><br />%SEARCH{"legacy"&nbsp;nonoise="on"&nbsp;format="|&nbsp;[[\$topic]]&nbsp;|&nbsp;[[\$wikiname]]&nbsp;|"}%</span>
</div>
THERE
    },
    {
        exec => ROUNDTRIP,
        name => 'Item6068NewlinesInPre',
        tml  => <<'HERE',
<pre>
test
test
test
</pre>
HERE

        #SMELL: TMCE removes the newline after the <pre>
        finaltml => <<'HERE',
<pre>test
test
test
</pre>
HERE
    },
    {
        exec => ROUNDTRIP,
        name => 'Item6068NewlinesInPreInSticky',
        tml  => <<'HERE',
<sticky><pre>
test
test
test
</pre></sticky>
HERE
    },
    {
        name => "brTagInMacroFormat",
        exec => TML2HTML | HTML2TML | ROUNDTRIP,
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

    {    # Copied on 29 April 2010 from
           # http://merlin.lavrsen.dk/foswiki10/bin/view/Myweb/NewLineEatingTest
         # and then split into multiple tests to make analysing the result managable
        name => 'KennethsNewLineEatingTest1',
        exec => ROUNDTRIP,
        tml  => <<HERE,
---++ This is a test topic where TMCE eats new lines in some cases

See Bugs.Item4705

Edit it in TMCE and save.

Repeat the edit and save many *times* and see the topic become a Goofy topic.
HERE
    },
    {
        name => 'KennethsNewLineEatingTest8',
        exec => ROUNDTRIP,
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
        exec => ROUNDTRIP,
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
        exec => ROUNDTRIP,
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
        exec => ROUNDTRIP,
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
        name           => 'KennethsNewLineEatingTest5',
        exec           => ROUNDTRIP,
        expect_failure => 'TODO: Item2174 reintroducing Item5702?',
        tml            => <<HERE,
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
        name           => 'KennethsNewLineEatingTest6',
        exec           => ROUNDTRIP,
        expect_failure => 'TODO: Item2174 reintroducing Item5702?',
        tml            => <<HERE,

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
        name           => 'KennethsNewLineEatingTest7',
        exec           => ROUNDTRIP,
        expect_failure => 'TODO: Item2174 reintroducing Item5702?',
        tml            => <<HERE,

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

sub _siteCharsetIsUTF8 {
    undef $WC::encoding;
    return WC::site_encoding() =~ /^utf-?8/;
}

sub new {
    my $self = shift()->SUPER::new( 'BrowserTranslator', @_ );

    $self->{editor} = BrowserEditorInterface->new($self);
    BrowserTranslatorTests->gen_compare_tests($data);

    return $self;
}

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();

    Foswiki::Plugins::WysiwygPlugin::HTML2TML::WC::test_reset();
}

sub _init {
    my $this = shift;
    my %args = @_;

    if ( $args{expect_failure} ) {
        $this->expect_failure( $args{expect_failure} );
    }
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

# Item9170
sub verify_editSaveTopicWithUnnamedUnicodeEntity {
    my $this = shift;

    $this->{editor}->init();

    # Close the editor because this test uses a different topic
    if ( $this->{editor}->editorMode() ) {
        $this->{editor}->cancelEdit();
    }

    # \x{eb} is representable in 8-bit charsets.
    # In iso-8859-1 it is e-with-umluat, or &euml;
    # &#x2640 is a valid unicode character without a
    # common entity name
    my $testText     = "A \x{eb} B &#x2640; C";
    my $expectedText = $testText;
    if ( _siteCharsetIsUTF8() ) {
        $expectedText =~ s/\&\#x(\w+);/chr(hex($1))/ge;
        $testText     = Encode::encode_utf8($testText);
        $expectedText = Encode::encode_utf8($expectedText);
    }

    # Create the test topic
    my $topicName = $this->{test_topic} . "For9170";
    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, $topicName );
    $topicObject->text("Before${testText}After\n");
    $topicObject->save();
    $topicObject->finish();

    # Reload the topic and note the topic date
    ($topicObject) = Foswiki::Func::readTopic( $this->{test_web}, $topicName );
    my $topicinfo                = $topicObject->get('TOPICINFO');
    my $dateBeforeSaveFromEditor = $topicinfo->{date};
    $this->assert( $dateBeforeSaveFromEditor,
        "Date from topic info before saving from editor" );
    $topicObject->finish();

    # Open the test topic in the wysiwyg editor
    $this->{editor}->openWysiwygEditor( $this->{test_web}, $topicName );

    # Make sure the topic timestamp is different,
    # so that we can confirm that the save did write to the file
    sleep(1);

    # PH Commented this out below in Item11440, it causes Foswiki to redirect
    # back to the save oops "merged with new revision while you were
    # editing..." screen, rather than view as the tests expect.
    #
    ## Write rubbish over the topic, which will be overwritten on save
    #($topicObject) =
    #  Foswiki::Func::readTopic( $this->{test_web}, $topicName);
    #$topicObject->text("Rubbish");
    #
    #$topicObject->save();
    #$topicObject->finish();
    #undef $topicObject;

    # Save from the editor
    $this->{editor}->save();

    # Reload the topic and check that the content is as expected
    ($topicObject) = Foswiki::Func::readTopic( $this->{test_web}, $topicName );

    # Make sure the topic really was saved
    $topicinfo = $topicObject->get('TOPICINFO');
    my $dateAfterSaveFromEditor = $topicinfo->{date};
    $this->assert( $dateAfterSaveFromEditor,
        "Date from topic info after saving from editor" );
    $this->assert_num_not_equals( $dateBeforeSaveFromEditor,
        $dateAfterSaveFromEditor );

    my $text = $topicObject->text();
    $topicObject->finish();

    # Isolate the portion of interest
    $text =~ s/.*Before//ms or $this->assert( 0, $text );
    $text =~ s/After.*//ms  or $this->assert( 0, $text );

    # Showtime:
    for ( $expectedText, $text ) {
        s/([^\x20-\x7e])/sprintf "\\x{%X}", ord($1)/ge;
    }
    $this->assert_str_equals( $expectedText, $text );
}

sub compareTML_HTML {
    my ( $this, $args ) = @_;

    $this->_init( expect_failure => $args->{expect_failure} );

    $this->{editor}->selectWikitextMode();
    $this->{editor}->setWikitextEditorContent( $args->{tml} );
    $this->{editor}->selectWysiwygMode();
    my $actualHtml = $this->{editor}->getWysiwygEditorContent();

    # SMELL: Selenium on Firefox converts <p>&nbsp;</p> to <p><br></p>
    $actualHtml =~ s{<p((?: [^>]*)?)><br></p>}{<p$1>&nbsp;</p>}g;

    # SMELL: Selenium on Firefox returns <br> instead of <br />,
    # and similarly for <hr />
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

    $this->_init( expect_failure => $args->{expect_failure} );

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

    $this->_init( expect_failure => $args->{expect_failure} );

    $this->{editor}->selectWysiwygMode();
    $this->{editor}->setWysiwygEditorContent( $args->{html} );
    $this->{editor}->selectWikitextMode();
    my $actualTml = $this->{editor}->getWikitextEditorContent();

    $this->assert_tml_equals( $args->{tml}, $actualTml, $args->{name} );
}

# Item11440 - dummy test, do not remove. skip() is never called if list_tests()
# returns nothing (why bother skipping zero tests), and this is the case with
# the (default) empty $Foswiki::cfg{UnitTestContrib}{SeleniumRc}{Browsers}
#
# We would rather a bogus dummy test which gives a meaningful skip annotation
# in the result summary, than to silently skip a suite which contains zero tests
sub test_nothing {
    my ($this) = @_;

    return;
}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2012 Foswiki Contributors. Foswiki Contributors
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
