# Copyright (C) 2005 ILOG http://www.ilog.fr
# and Foswiki Contributors. All Rights Reserved. Foswiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of the Foswiki distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.

# Tests for extensions to the two translators, TML to HTML and HTML to TML,
# that support editing using WYSIWYG HTML editors. The tests are designed
# so that the round trip can be verified in as many cases as possible.
# Readers are invited to add more testcases.
#
# The tests require FOSWIKI_LIBS to include a pointer to the lib
# directory of a Foswiki installation, so it can pick up the bits
# of Foswiki it needs to include.
#
package ExtendedTranslatorTests;
use base qw(TranslatorTests);

use strict;

require Foswiki::Plugins::WysiwygPlugin;
require Foswiki::Plugins::WysiwygPlugin::TML2HTML;
require Foswiki::Plugins::WysiwygPlugin::HTML2TML;

# Bits for test type
# Fields in test records:
my $TML2HTML  = 1 << 0;        # test tml => html
my $HTML2TML  = 1 << 1;        # test html => finaltml (default tml)
my $ROUNDTRIP = 1 << 2;        # test tml => => finaltml
my $CANNOTWYSIWYG = 1 << 3;    # test that notWysiwygEditable returns true
                               #   and make the ROUNDTRIP test expect failure

# Note: ROUNDTRIP is *not* the same as the combination of
# HTML2TML and TML2HTML. The HTML and TML comparisons are both
# somewhat "flexible". This is necessry because, for example,
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

# Holds extra options to be passed to the TML2HTML convertor
my %extraTML2HTMLOptions;

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
# setup => reference to setup function for the test
# cleanup => reference to cleanup function for the test, which should
#   not be needed for most tests because this test harness re-initialises
#   the WysiwygPlugin before each test
# tml => source topic markup language
# html => expected html from expanding tml (not used in roundtrip tests)
# finaltml => optional expected tml from translating html. If not there,
#   will use tml. Only use where round-trip can't be closed because
#   we are testing deprecated syntax.
my $data = [
    {
        exec => $TML2HTML | $ROUNDTRIP,
        name => 'UnspecifiedCustomXmlTag',
        setup => sub {
            $extraTML2HTMLOptions{xmltag} = \%Foswiki::Plugins::WysiwygPlugin::xmltag;
        },
        html => '<p>'
          . $protecton
          . '&lt;customtag&gt;'
          . $protectoff
          . 'some &gt; text'
          . $protecton
          . '&lt;/customtag&gt;'
          . $protectoff . '</p>',
        tml      => '<customtag>some >  text</customtag>',
        finaltml => '<customtag>some &gt; text</customtag>',
    },
    {
        exec  => $TML2HTML | $ROUNDTRIP,
        name  => 'DisabledCustomXmlTag',
        setup => sub {
            $extraTML2HTMLOptions{xmltag} = \%Foswiki::Plugins::WysiwygPlugin::xmltag;
            Foswiki::Plugins::WysiwygPlugin::addXMLTag( 'customtag',
                sub { 0 } );
        },
        html => '<p>'
          . $protecton
          . '&lt;customtag&gt;'
          . $protectoff
          . 'some &gt; text'
          . $protecton
          . '&lt;/customtag&gt;'
          . $protectoff . '</p>',
        tml      => '<customtag>some >  text</customtag>',
        finaltml => '<customtag>some &gt; text</customtag>',
    },
    {
        exec  => $TML2HTML | $ROUNDTRIP,
        name  => 'CustomXmlTag',
        setup => sub {
            $extraTML2HTMLOptions{xmltag} = \%Foswiki::Plugins::WysiwygPlugin::xmltag;
            Foswiki::Plugins::WysiwygPlugin::addXMLTag( 'customtag',
                sub { 1 } );
        },
        html => '<p>'
          . $protecton
          . '&lt;customtag&gt;some&nbsp;&gt;&nbsp;&nbsp;text&lt;/customtag&gt;'
          . $protectoff . '</p>',
        tml => '<customtag>some >  text</customtag>',
    },
    {
        exec  => $TML2HTML | $ROUNDTRIP,
        name  => 'CustomXmlTagCallbackChangesText',
        setup => sub {
            $extraTML2HTMLOptions{xmltag} = \%Foswiki::Plugins::WysiwygPlugin::xmltag;
            Foswiki::Plugins::WysiwygPlugin::addXMLTag( 'customtag',
                sub { $_[0] =~ s/some/different/; return 1; } );
        },
        html => '<p>'
          . $protecton
          . '&lt;customtag&gt;different&nbsp;&gt;&nbsp;&nbsp;text&lt;/customtag&gt;'
          . $protectoff . '</p>',
        tml      => '<customtag>some >  text</customtag>',
        finaltml => '<customtag>different >  text</customtag>',
    },
    {
        exec  => $TML2HTML | $ROUNDTRIP,
        name  => 'CustomXmlTagDefaultCallback',
        setup => sub {
            $extraTML2HTMLOptions{xmltag} = \%Foswiki::Plugins::WysiwygPlugin::xmltag;
            Foswiki::Plugins::WysiwygPlugin::addXMLTag( 'customtag' );
        },
        html => '<p>'
          . $protecton
          . '&lt;customtag&gt;some&nbsp;&gt;&nbsp;&nbsp;text&lt;/customtag&gt;'
          . $protectoff . '</p>',
        tml => '<customtag>some >  text</customtag>',
    },
    {
        exec  => $TML2HTML | $ROUNDTRIP,
        name  => 'CustomXmlTagWithAttributes',
        setup => sub {
            $extraTML2HTMLOptions{xmltag} = \%Foswiki::Plugins::WysiwygPlugin::xmltag;
            Foswiki::Plugins::WysiwygPlugin::addXMLTag( 'customtag',
                sub { 1 } );
        },
        html => '<p>'
          . $protecton
          . '&lt;customtag&nbsp;with="attributes"&gt;<br />&nbsp;&nbsp;formatting&nbsp;&gt;&nbsp;&nbsp;preserved<br />&lt;/customtag&gt;'
          . $protectoff . '</p>',
        tml => <<'BLAH',
<customtag with="attributes">
  formatting >  preserved
</customtag>
BLAH
    },
    {
        exec  => $TML2HTML | $ROUNDTRIP,
        name  => 'NestedCustomXmlTagWithAttributes',
        setup => sub {
            $extraTML2HTMLOptions{xmltag} = \%Foswiki::Plugins::WysiwygPlugin::xmltag;
            Foswiki::Plugins::WysiwygPlugin::addXMLTag( 'customtag',
                sub { 1 } );
        },
        html => '<p>'
          . $protecton
          . '&lt;customtag&gt;<br />&nbsp;&nbsp;formatting&nbsp;&gt;&nbsp;&nbsp;preserved<br />'
          . '&nbsp;&nbsp;&nbsp;&nbsp;&lt;customtag&gt;<br />'
          . '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;banana&nbsp;&lt;&nbsp;cheese&nbsp;&lt;&lt;&nbsp;Elephant;<br />'
          . '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;this&amp;that<br />'
          . '&nbsp;&nbsp;&nbsp;&nbsp;&lt;/customtag&gt;<br />'
          . '&lt;/customtag&gt;'
          . $protectoff . '</p>',
        tml => <<'BLAH',
<customtag>
  formatting >  preserved
    <customtag>
        banana < cheese << Elephant;
        this&that
    </customtag>
</customtag>
BLAH
    },
    {
        exec => $CANNOTWYSIWYG,
        # Do not perform ROUNDTRIP on this TML, because ROUNDTRIP passes.
        # The problem with this TML is that the special handling of 
        # <verbatim> in the conversion to HTML messes up the contents 
        # of this custom XML  tag, so that the HTML is not representative 
        # of the TML in terms of intellectual content.
        name => 'VerbatimInsideDot',
        setup => sub {
            $extraTML2HTMLOptions{xmltag} = \%Foswiki::Plugins::WysiwygPlugin::xmltag;
            Foswiki::Plugins::WysiwygPlugin::addXMLTag( 'dot',
                sub { 1 } );
        },
        tml => <<'DOT',
<dot>
digraph G {
    open [label="<verbatim>"];
    content [label="Put arbitrary content here"];
    close [label="</verbatim>"];
    open -> content -> close;
}
</dot>
DOT
    },
    {
        exec => $TML2HTML | $ROUNDTRIP,
        name => 'CustomtagInsideSticky',
        setup => sub {
            $extraTML2HTMLOptions{xmltag} = \%Foswiki::Plugins::WysiwygPlugin::xmltag;
            Foswiki::Plugins::WysiwygPlugin::addXMLTag( 'customtag',
                sub { 1 } );
        },
        tml => "<sticky><customtag>this & that\n >   the other </customtag></sticky>",
        html => '<p>'
          . '<div class="WYSIWYG_STICKY">'
          . '&lt;customtag&gt;'
          . 'this&nbsp;&amp;&nbsp;that<br />&nbsp;&gt;&nbsp;&nbsp;&nbsp;the&nbsp;other&nbsp;'
          . '&lt;/customtag&gt;'
          . '</div>'
          . '</p>'
    },
    {
        exec => $ROUNDTRIP | $CANNOTWYSIWYG, #SMELL: fix this case
        name => 'StickyInsideCustomtag',
        setup => sub {
            $extraTML2HTMLOptions{xmltag} = \%Foswiki::Plugins::WysiwygPlugin::xmltag;
            Foswiki::Plugins::WysiwygPlugin::addXMLTag( 'customtag',
                sub { 1 } );
        },
        tml => "<customtag>this <sticky>& that\n >   the</sticky> other </customtag>",
        html => '<p>'
          . $protecton
          . '&lt;customtag&gt;'
          . 'this&nbsp;'
          . '<div class="WYSIWYG_STICKY">'
          . '&amp;&nbsp;that<br />&nbsp;&gt;&nbsp;&nbsp;&nbsp;the'
          . '</div>'
          . '&nbsp;other&nbsp;'
          . '&lt;/customtag&gt;'
          . $protectoff
          . '</p>'
    },
    {
        exec => $TML2HTML | $ROUNDTRIP,
        name => 'StickyInsideUnspecifiedCustomtag',
        setup => sub {
            $extraTML2HTMLOptions{xmltag} = \%Foswiki::Plugins::WysiwygPlugin::xmltag;
        },
        tml => "<customtag>this <sticky>& that\n >   the</sticky> other </customtag>",
        html => '<p>'
          . $protecton
          . '&lt;customtag&gt;'
          . $protectoff
          . 'this'
          . '<div class="WYSIWYG_STICKY">'
          . '&amp;&nbsp;that<br />&nbsp;&gt;&nbsp;&nbsp;&nbsp;the'
          . '</div>'
          . 'other'
          . $protecton
          . '&lt;/customtag&gt;'
          . $protectoff
          . '</p>'
    },
    {
        exec => $ROUNDTRIP,
        name => 'UnspecifiedCustomtagInsideSticky',
        setup => sub {
            $extraTML2HTMLOptions{xmltag} = \%Foswiki::Plugins::WysiwygPlugin::xmltag;
        },
        tml => "<sticky><customtag>this & that\n >   the other </customtag></sticky>"
    },
    {
        exec => $TML2HTML | $ROUNDTRIP,
        name => 'CustomtagInsideLiteral',
        setup => sub {
            $extraTML2HTMLOptions{xmltag} = \%Foswiki::Plugins::WysiwygPlugin::xmltag;
            Foswiki::Plugins::WysiwygPlugin::addXMLTag( 'customtag',
                sub { 1 } );
        },
        tml => '<literal><customtag>this & that >   the other </customtag></literal>',
        html => '<p>'
          . '<div class="WYSIWYG_LITERAL">'
          . '<customtag>this & that >   the other </customtag>'
          . '</div>'
          . '</p>'
    },
    {
        exec => $TML2HTML | $ROUNDTRIP,
        name => 'UnspecifiedCustomtagInsideLiteral',
        setup => sub {
            $extraTML2HTMLOptions{xmltag} = \%Foswiki::Plugins::WysiwygPlugin::xmltag;
        },
        tml => '<literal><customtag>this & that >   the other </customtag></literal>',
        html => '<p>'
          . '<div class="WYSIWYG_LITERAL">'
          . '<customtag>this & that >   the other </customtag>'
          . '</div>'
          . '</p>'
    },
    {
        exec => $ROUNDTRIP | $CANNOTWYSIWYG, #SMELL: Fix this case
        name => 'LiteralInsideCustomtag',
        setup => sub {
            $extraTML2HTMLOptions{xmltag} = \%Foswiki::Plugins::WysiwygPlugin::xmltag;
            Foswiki::Plugins::WysiwygPlugin::addXMLTag( 'customtag',
                sub { 1 } );
        },
        tml => '<customtag>this <literal>& that > the</literal> other </customtag>',
        html => '<p>'
          . '<div class="WYSIWYG_LITERAL">'
          . '<customtag>this & that > the other </customtag>'
          . '</div>'
          . '</p>'
    },
    {
        exec => $TML2HTML | $ROUNDTRIP,
        name => 'LiteralInsideUnspecifiedCustomtag',
        setup => sub {
            $extraTML2HTMLOptions{xmltag} = \%Foswiki::Plugins::WysiwygPlugin::xmltag;
        },
        tml => '<customtag>this <literal>& that > the</literal> other </customtag>',
        html => '<p>'
          . $protecton
          . '&lt;customtag&gt;'
          . $protectoff
          . 'this'
          . '<div class="WYSIWYG_LITERAL">'
          . '& that > the'
          . '</div>'
          .'other'
          . $protecton
          . '&lt;/customtag&gt;'
          . $protectoff
          . '</p>'
    },
    {
        # There will probably always be some markup that WysiwygPlugin cannot convert,
        # but it is not always easy to say what that markup is.
        # This test case checks the protection of unconvertable text
        # by using valid markup and forcing the conversion to fail.
        exec => $TML2HTML | $ROUNDTRIP,
        name => 'UnconvertableTextIsProtected',
        setup => sub {
            # Disable "dieOnError" to test the "protect unconvertable text" behaviour
            # which can be exercised via the REST handler
            $extraTML2HTMLOptions{dieOnError} = 0;

            # Override the standard expansion function to hack in an illegal character to force the conversion to fail
            $extraTML2HTMLOptions{expandVarsInURL} = sub { return "\0"; };
        },
        tml => '<img src="%PUBURLPATH%">',
        html => '<div class="WYSIWYG_PROTECTED">&lt;img&nbsp;src="%PUBURLPATH%"&gt;</div>'
    },
];

sub gen_compare_tests {
    my %picked = map { $_ => 1 } @_;
    for ( my $i = 0 ; $i < scalar(@$data) ; $i++ ) {
        my $datum = $data->[$i];
        if ( scalar(@_) ) {
            next unless ( $picked{ $datum->{name} } );
        }
        if ( ( $mask & $datum->{exec} ) & $TML2HTML ) {
            my $fn = 'ExtendedTranslatorTests::testTML2HTML_' . $datum->{name};
            no strict 'refs';
            *$fn = sub { 
                my $this = shift; 
                $this->testSpecificSetup($datum); 
                $this->compareTML_HTML($datum); 
                $this->testSpecificCleanup($datum);
            };
            use strict 'refs';
        }
        if ( ( $mask & $datum->{exec} ) & $HTML2TML ) {
            my $fn = 'ExtendedTranslatorTests::testHTML2TML_' . $datum->{name};
            no strict 'refs';
            *$fn = sub { 
                my $this = shift;
                $this->testSpecificSetup($datum); 
                $this->compareHTML_TML($datum);
                $this->testSpecificCleanup($datum);
            };
            use strict 'refs';
        }
        if ( ( $mask & $datum->{exec} ) & $ROUNDTRIP ) {
            my $fn = 'ExtendedTranslatorTests::testROUNDTRIP_' . $datum->{name};
            no strict 'refs';
            *$fn = sub {
                my $this = shift;
                $this->testSpecificSetup($datum); 
                $this->compareRoundTrip($datum);
                $this->testSpecificCleanup($datum);
            };
            use strict 'refs';
        }
        if ( ( $mask & $datum->{exec} ) & $CANNOTWYSIWYG ) {
            my $fn = 'TranslatorTests::testCANNOTWYSIWYG_' . $datum->{name};
            no strict 'refs';
            *$fn = sub { 
                my $this = shift;
                $this->testSpecificSetup($datum); 
                $this->compareNotWysiwygEditable($datum);
                $this->testSpecificCleanup($datum);
            };
            use strict 'refs';
        }
    }
}

sub testSpecificSetup {
    my ( $this, $args ) = @_;
    # Reset the extendable parts of WysiwygPlugin
    %Foswiki::Plugins::WysiwygPlugin::xmltag       = ();
    %Foswiki::Plugins::WysiwygPlugin::xmltagPlugin = ();

    %extraTML2HTMLOptions = ();

    # Test-specific setup
    if ( exists $args->{setup} ) {
        $args->{setup}->($this);
    }
}

sub testSpecificCleanup {
    my ( $this, $args ) = @_;
    if ( exists $args->{cleanup} ) {
        $args->{cleanup}->($this);
    }
}

sub TML_HTMLconverterOptions
{
    my $this = shift;
    my $options = $this->SUPER::TML_HTMLconverterOptions(@_);
    for my $extraOptionName (keys %extraTML2HTMLOptions) {
        $options->{$extraOptionName} = $extraTML2HTMLOptions{$extraOptionName};
    }
    return $options;
}

gen_compare_tests();

1;
