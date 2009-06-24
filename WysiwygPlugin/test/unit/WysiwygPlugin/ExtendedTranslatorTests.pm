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
use base qw(FoswikiTestCase);

use strict;

require Foswiki::Plugins::WysiwygPlugin;
require Foswiki::Plugins::WysiwygPlugin::TML2HTML;
require Foswiki::Plugins::WysiwygPlugin::HTML2TML;

# Bits for test type
# Fields in test records:
my $TML2HTML  = 1 << 0;    # test tml => html
my $HTML2TML  = 1 << 1;    # test html => finaltml (default tml)
my $ROUNDTRIP = 1 << 2;    # test tml => => finaltml

# Note: ROUNDTRIP is *not* the same as the combination of
# HTML2TML and TML2HTML. The HTML and TML comparisons are both
# somewhat "flexible". This is necessry because, for example,
# the nature of whitespace in the TML may change.
# ROUNDTRIP tests are intended to isolate gradual degradation
# of the TML, where TML -> HTML -> not quite TML -> HTML
# -> even worse TML, ad nauseum

# Bit mask for selected test types
my $mask = $TML2HTML | $HTML2TML | $ROUNDTRIP;

my $protecton  = '<span class="WYSIWYG_PROTECTED">';
my $linkon     = '<span class="WYSIWYG_LINK">';
my $protectoff = '</span>';
my $linkoff    = '</span>';
my $preoff     = '</span>';
my $nop        = "$protecton<nop>$protectoff";

# The following big table contains all the testcases. These are
# used to add a bunch of functions to the symbol table of this
# testcase, so they get picked up and run by TestRunner.

# Each testcase is a subhash with fields as follows:
# exec => $TML2HTML to test TML -> HTML, $HTML2TML to test HTML -> TML,
#   $ROUNDTRIP to test TML-> ->TML, all other bits are ignored.
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
        name  => 'CustomXmlTagWithAttributes',
        setup => sub {
            Foswiki::Plugins::WysiwygPlugin::addXMLTag( 'customtag',
                sub { 1 } );
        },
        html => '<p>'
          . $protecton
          . '&lt;customtag&nbsp;with="attributes"&gt;<br />&nbsp;&nbsp;formatting&nbsp;&gt;&nbsp;&nbsp;preserved<br />&lt;/customtag&gt;'
          . $protectoff . '</p>',
        tml => <<BLAH,
<customtag with="attributes">
  formatting >  preserved
</customtag>
BLAH
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
            *$fn = sub { my $this = shift; $this->compareTML_HTML($datum) };
            use strict 'refs';
        }
        if ( ( $mask & $datum->{exec} ) & $HTML2TML ) {
            my $fn = 'ExtendedTranslatorTests::testHTML2TML_' . $datum->{name};
            no strict 'refs';
            *$fn = sub { my $this = shift; $this->compareHTML_TML($datum) };
            use strict 'refs';
        }
        if ( ( $mask & $datum->{exec} ) & $ROUNDTRIP ) {
            my $fn = 'ExtendedTranslatorTests::testROUNDTRIP_' . $datum->{name};
            no strict 'refs';
            *$fn = sub { my $this = shift; $this->compareRoundTrip($datum) };
            use strict 'refs';
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
    $this->{session} = new Foswiki( undef, $query );
    $Foswiki::Plugins::SESSION = $this->{session};
}

sub normaliseEntities {
    my $text = shift;

    # Convert text entities to &# representation
    $text =~ s/(&\w+;)/'&#'.ord(HTML::Entities::decode_entities($1)).';'/ge;
    return $text;
}

sub compareTML_HTML {
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

    # Reset the extendable parts of WysiwygPlugin
    %Foswiki::Plugins::WysiwygPlugin::xmltag       = ();
    %Foswiki::Plugins::WysiwygPlugin::xmltagPlugin = ();

    # Test-specific setup
    if ( exists $args->{setup} ) {
        $args->{setup}->();
    }

    # convert to HTML
    my $txer = new Foswiki::Plugins::WysiwygPlugin::TML2HTML();
    my $tx   = $txer->convert(
        $tml,
        {
            web        => 'Current',
            topic      => 'TestTopic',
            getViewUrl => \&Foswiki::Plugins::WysiwygPlugin::getViewUrl,
            expandVarsInURL =>
              \&Foswiki::Plugins::WysiwygPlugin::expandVarsInURL,
            xmltag => \%Foswiki::Plugins::WysiwygPlugin::xmltag,
        }
    );

    # Test-specific cleanup
    if ( exists $args->{cleanup} ) {
        $args->{cleanup}->();
    }

    $this->assert_html_equals( $html, $tx );
}

sub compareRoundTrip {
    my ( $this, $args ) = @_;
    my $page =
      $this->{session}->getScriptUrl( 1, 'view', 'Current', 'TestTopic' );
    $page =~ s/\/Current\/TestTopic.*$//;

    my $tml = $args->{tml} || '';
    $tml =~ s/%!page!%/$page/g;

    # Reset the extendable parts of WysiwygPlugin
    %Foswiki::Plugins::WysiwygPlugin::xmltag       = ();
    %Foswiki::Plugins::WysiwygPlugin::xmltagPlugin = ();

    # Test-specific setup
    if ( exists $args->{setup} ) {
        $args->{setup}->();
    }

    # convert to HTML
    my $txer = new Foswiki::Plugins::WysiwygPlugin::TML2HTML();
    my $html = $txer->convert(
        $tml,
        {
            web        => 'Current',
            topic      => 'TestTopic',
            getViewUrl => \&Foswiki::Plugins::WysiwygPlugin::getViewUrl,
            expandVarsInURL =>
              \&Foswiki::Plugins::WysiwygPlugin::expandVarsInURL,
            xmltag => \%Foswiki::Plugins::WysiwygPlugin::xmltag,
        }
    );

    # convert back to TML
    $txer = new Foswiki::Plugins::WysiwygPlugin::HTML2TML();
    my $tx = $txer->convert(
        $html,
        {
            web          => 'Current',
            topic        => 'TestTopic',
            convertImage => \&convertImage,
            rewriteURL   => \&Foswiki::Plugins::WysiwygPlugin::postConvertURL,
        }
    );

    # Test-specific cleanup
    if ( exists $args->{cleanup} ) {
        $args->{cleanup}->();
    }

    my $finaltml = $args->{finaltml} || $tml;
    $finaltml =~ s/%!page!%/$page/g;
    $this->_assert_tml_equals( $finaltml, $tx, $args->{name} );
}

sub compareHTML_TML {
    my ( $this, $args ) = @_;

    my $page =
      $this->{session}->getScriptUrl( 1, 'view', 'Current', 'TestTopic' );
    $page =~ s/\/Current\/TestTopic.*$//;
    my $html = $args->{html} || '';
    $html =~ s/%!page!%/$page/g;
    my $tml = $args->{tml} || '';
    $tml =~ s/%!page!%/$page/g;
    my $finaltml = $args->{finaltml} || $tml;
    $finaltml =~ s/%!page!%/$page/g;

    # Reset the extendable parts of WysiwygPlugin
    %Foswiki::Plugins::WysiwygPlugin::xmltag       = ();
    %Foswiki::Plugins::WysiwygPlugin::xmltagPlugin = ();

    # Test-specific setup
    if ( exists $args->{setup} ) {
        $args->{setup}->();
    }

    # convert to TML
    my $txer = new Foswiki::Plugins::WysiwygPlugin::HTML2TML();
    my $tx   = $txer->convert(
        $html,
        {
            web          => 'Current',
            topic        => 'TestTopic',
            convertImage => \&convertImage,
            rewriteURL   => \&Foswiki::Plugins::WysiwygPlugin::postConvertURL,
        }
    );

    # Test-specific cleanup
    if ( exists $args->{cleanup} ) {
        $args->{cleanup}->();
    }

    $this->_assert_tml_equals( $finaltml, $tx, $args->{name} );
}

sub encode {
    my $s = shift;

    # used for debugging odd chars
    #    $s =~ s/([\000-\037])/'#'.ord($1)/ge;
    return $s;
}

sub _assert_tml_equals {
    my ( $this, $expected, $actual, $name ) = @_;
    $expected ||= '';
    $actual   ||= '';
    $actual   =~ s/\n$//s;
    $expected =~ s/\n$//s;
    unless ( $expected eq $actual ) {
        my $expl =
            "==$name== Expected TML:\n"
          . encode($expected)
          . "\n==$name== Actual TML:\n"
          . encode($actual)
          . "\n==$name==\n";
        my $i = 0;
        while ( $i < length($expected) && $i < length($actual) ) {
            my $e = substr( $expected, $i, 1 );
            my $a = substr( $actual,   $i, 1 );
            if ( $a ne $e ) {
                $expl .= "<<==== HERE actual ";
                $expl .= ord($a) . " != expected " . ord($e) . "\n";
                last;
            }
            $expl .= $a;
            $i++;
        }
        $this->assert( 0, $expl . "\n" );
    }
}

sub convertImage {
    my $url = shift;

    if ( $url eq "test_image" ) {
        return '%TRANSLATEDIMAGE%';
    }
}

gen_compare_tests();

1;
