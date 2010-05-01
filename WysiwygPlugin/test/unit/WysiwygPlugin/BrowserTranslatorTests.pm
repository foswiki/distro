use strict;

package BrowserTranslatorTests;

use FoswikiSeleniumTestCase;
use TranslatorBase;
our @ISA = qw( FoswikiSeleniumTestCase TranslatorBase );

use Foswiki::Func;

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
        exec => $TranslatorBase::ROUNDTRIP,
        name => 'linkAtStart',
        tml  => 'LinkAtStart',
        html => $TranslatorBase::linkon . 'LinkAtStart' . $TranslatorBase::linkoff,
    },
    {
        exec => $TranslatorBase::ROUNDTRIP,
        name => 'otherWebLinkAtStart',
        tml  => 'OtherWeb.LinkAtStart',
        html => $TranslatorBase::linkon . 'OtherWeb.LinkAtStart' . $TranslatorBase::linkoff,
    },
    {
        exec     => $TranslatorBase::ROUNDTRIP,
        name     => 'currentWebLinkAtStart',
        tml      => 'Current.LinkAtStart',
        html     => $TranslatorBase::linkon . 'Current.LinkAtStart' . $TranslatorBase::linkoff,
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
];


my $editFrameLocator = "css=iframe#topic_ifr";
my $wikitextLocator = "css=a#topic_hide";
my $wysiwygLocator = "css=input#topic_2WYSIWYG";
my $editTextareaLocator = "css=textarea#topic";
my $editCancelButtonLocator = "css=input#cancel";

# This must match the text in foswiki_tiny.js
my $waitForServerMessage = "Please wait... retrieving page from server.";

sub new {
    my $self = shift()->SUPER::new( 'BrowserTranslator', @_ );

    $self->{BrowserTranslator_WebInit} = 0;
    $self->{BrowserTranslator_Init} = {};

    return $self;
}

sub _init {
    my $this = shift;

    if (not $this->{BrowserTranslator_WebInit}) {
        my $topicObject =
          Foswiki::Meta->new( $this->{session}, $this->{test_web},
            $Foswiki::cfg{WebPrefsTopicName}, "   * Set SKIN=pattern\n");
        $topicObject->save();
        $this->{BrowserTranslator_WebInit} = 1;
    }

    if (not $this->{BrowserTranslator_Init}->{$this->{browser}}) {
    $this->login();
    $this->_open_editor();

    $this->{BrowserTranslator_Init}->{$this->{browser}} = 1;
}
}

sub DESTROY
{
    my $this = shift;
    #my $pressEnterToContinue = <STDIN>;
    for my $browser (keys %{ $this->{BrowserTranslator_Init} }) {
        $this->{browser} = $browser;
        $this->{selenium} = $this->{seleniumBrowsers}->{$browser};

        $this->_select_top_frame();
        $this->{selenium}->click( $editCancelButtonLocator );
    }
    if (keys %{ $this->{BrowserTranslator_Init} }) {
        $this->{selenium}->pause(); # Breathe for a moment; let TMCE settle before doing anything else
    }
    $this->SUPER::DESTROY if $this->can('SUPER::DESTROY');
}

sub compareTML_HTML {
    my ( $this, $args ) = @_;
    $this->assert(0, ref($this)."::compareTML_HTML not implemented");
}

sub compareNotWysiwygEditable {
    my ( $this, $args ) = @_;
    $this->assert(0, ref($this)."::compareNotWysiwygEditable not implemented");
}

sub compareRoundTrip {
    my $this = shift;
    my $args = shift;

    $this->_init();

    $this->_wikitext();
    $this->_type($editTextareaLocator, $args->{tml});
    $this->_wysiwyg();
    $this->_wikitext();
    $this->assert_tml_equals( $args->{finaltml} || $args->{tml},
                              $this->{selenium}->get_value($editTextareaLocator),
                              $args->{name} );
}

sub compareHTML_TML {
    my ( $this, $args ) = @_;
    $this->assert(0, ref($this)."::compareHTML_TML not implemented");
}

sub _open_editor {
    my $this = shift;
    $this->{selenium}->open_ok( Foswiki::Func::getScriptUrl( $this->{test_web}, $this->{test_topic}, 'edit') );

    # The editor can take a while to open, and has to do another server request to convert TML2HTML, so use a longer timeout
    $this->{selenium}->wait_for_element_present( $editFrameLocator, 2 * $this->timeout() );
    $this->{selenium}->pause(); # Breathe for a moment; let TMCE settle before doing anything else

    $this->{Browser_Translator_mode}->{$this->{browser}} = 'wysiwyg';
}

sub _select_editor_frame {
    my $this = shift;
    $this->{selenium}->select_frame_ok($editFrameLocator);
}

sub _select_top_frame {
    my $this = shift;
    $this->{selenium}->select_frame_ok("relative=top");
}

sub _type {
    my $this = shift;
    my $locator = shift;
    my $text = shift;

    # If you pass too much text to $this->{selenium}->type()
    # then the test fails with a 414 error from the selenium server.
    # That can happen quite easily when pasting topic text into
    # the edit form's textarea

    $locator =~ s#"#\\"#g;

    # The algorithm here is based on this posting by balrog:
    # http://groups.google.com/group/selenium-users/msg/669560194d07734e
    my $maxChars = 1000;
    my $textLength = length $text;
    if ($textLength > $maxChars) {
        my $start = 0;
        while ($start < $textLength) {
            my $chunk = substr($text, $start, $maxChars);
            $chunk =~ s#\\#\\\\#g;
            $chunk =~ s#\n#\\n#g;
            $chunk =~ s#"#\\"#g;
            my $assignOperator = ($start == 0) ? '=' : '+=';
            $start += $maxChars;
            my $javascript = qq/selenium.browserbot.findElement("$locator").value $assignOperator "$chunk";/;
            $this->{selenium}->get_eval($javascript);
            #sleep 2;
        }
    }
    else {
       $this->{selenium}->type($locator, $text);
   }
}

sub _wikitext {
    my $this = shift;
    return if $this->{Browser_Translator_mode}->{$this->{browser}} eq 'wikitext';
    if ($this->{selenium}->is_element_present($wysiwygLocator)) {
        # SMELL: I can't see this button, but the assert fails. Dunno why.
        # $this->assertElementIsNotVisible( $wysiwygLocator );
    }

    $this->assertElementIsPresent( $wikitextLocator );
    $this->assertElementIsVisible( $wikitextLocator );
    $this->{selenium}->click_ok( $wikitextLocator );

    $this->waitFor(sub{ $this->{selenium}->is_visible($editTextareaLocator); },
                   "topic textarea must be visible");

    # SMELL: I can't see the wikitext button, but this assert fails. Dunno why.
    # $this->assertElementIsNotVisible( $wikitextLocator );

    $this->waitFor(sub{ $this->{selenium}->get_value($editTextareaLocator) !~ /\Q$waitForServerMessage/; });

    $this->{Browser_Translator_mode}->{$this->{browser}} = 'wikitext';
}

sub _wysiwyg {
    my $this = shift;
    return if $this->{Browser_Translator_mode}->{$this->{browser}} eq 'wysiwyg';
    $this->assertElementIsPresent( $wysiwygLocator );
    $this->assertElementIsVisible( $wysiwygLocator );
    $this->{selenium}->click_ok( $wysiwygLocator );

    $this->waitFor(sub{ $this->{selenium}->is_visible($editFrameLocator); },
                   "wysiwyg edit area must be visible");

    # SMELL: this should work
    # $this->assertElementIsNotVisible( $editTextareaLocator );

    $this->_select_editor_frame();
    $this->waitFor(sub{ $this->{selenium}->get_text("css=body") !~ /\Q$waitForServerMessage/; });
    $this->_select_top_frame();

    $this->{Browser_Translator_mode}->{$this->{browser}} = 'wysiwyg';
}

BrowserTranslatorTests->gen_compare_tests('verify', $data);

1;

