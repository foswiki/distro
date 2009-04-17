use strict;

# tests for basic formatting

package FormattingTests;

use base qw( FoswikiFnTestCase );

use Foswiki;
use Error qw( :try );

sub new {
    my $self = shift()->SUPER::new( 'Formatting', @_ );
    return $self;
}

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();
    $this->{sup} = $this->{session}->getScriptUrl( 0, 'view' );
    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web}, 'H_',
        "BLEEGLE" );
    $topicObject->save();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        'Underscore_topic', "BLEEGLE" );
    $topicObject->save();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        $Foswiki::cfg{HomeTopicName}, "BLEEGLE" );
    $topicObject->save();
    $topicObject =
      Foswiki::Meta->new( $this->{session}, $this->{test_web},
        'Numeric1Wikiword', "BLEEGLE" );
    $topicObject->save();
    $Foswiki::cfg{AntiSpam}{RobotsAreWelcome} = 1;
    $Foswiki::cfg{AntiSpam}{EmailPadding}     = 'STUFFED';
    $Foswiki::cfg{AllowInlineScript}          = 1;
}

# This formats the text up to immediately before <nop>s are removed, so we
# can see the nops.
sub do_test {
    my ( $this, $expected, $actual ) = @_;
    my $session = $this->{session};

    $this->{test_topicObject}->expandMacros($actual);
    $actual = $this->{test_topicObject}->renderTML($actual);
    $this->assert_html_equals( $expected, $actual );
}

# current topic WikiWord
sub test_seflLinkingWikiword {
    my $this     = shift;
    my $expected = <<EXPECTED;
<a href="$this->{sup}/$this->{test_web}/$this->{test_topic}" class="foswikiCurrentTopicLink" >$this->{test_topic}</a>
EXPECTED

    my $actual = <<ACTUAL;
$this->{test_topic}
ACTUAL
    $this->do_test( $expected, $actual );
}

# WikiWord
sub test_simpleWikiword {
    my $this     = shift;
    my $expected = <<EXPECTED;
<a class="foswikiCurrentWebHomeLink" href="$this->{sup}/$this->{test_web}/$Foswiki::cfg{HomeTopicName}">$Foswiki::cfg{HomeTopicName}</a>
EXPECTED

    my $actual = <<ACTUAL;
$Foswiki::cfg{HomeTopicName}
ACTUAL
    $this->do_test( $expected, $actual );
}

# [[WikiWord]]
sub test_squabbedWikiword {
    my $this     = shift;
    my $expected = <<EXPECTED;
<a class="foswikiCurrentWebHomeLink" href="$this->{sup}/$this->{test_web}/$Foswiki::cfg{HomeTopicName}">$Foswiki::cfg{HomeTopicName}</a>
EXPECTED

    my $actual = <<ACTUAL;
[[$Foswiki::cfg{HomeTopicName}]]
ACTUAL
    $this->do_test( $expected, $actual );
}

# [[Web.WikiWord]]
sub test_squabbedWebWikiword {
    my $this     = shift;
    my $expected = <<EXPECTED;
<a href="$this->{sup}/$Foswiki::cfg{SystemWebName}/$Foswiki::cfg{HomeTopicName}">$Foswiki::cfg{SystemWebName}.$Foswiki::cfg{HomeTopicName}</a>
EXPECTED

    my $actual = <<ACTUAL;
[[$Foswiki::cfg{SystemWebName}.$Foswiki::cfg{HomeTopicName}]]
ACTUAL
    $this->do_test( $expected, $actual );
}

# [[Web.WikiWord][Alt TextAlt]]
sub test_squabbedWebWikiWordAltText {
    my $this     = shift;
    my $expected = <<EXPECTED;
<a href="$this->{sup}/$Foswiki::cfg{SystemWebName}/$Foswiki::cfg{HomeTopicName}">Alt <nop>TextAlt</a>
EXPECTED

    my $actual = <<ACTUAL;
[[$Foswiki::cfg{SystemWebName}.$Foswiki::cfg{HomeTopicName}][Alt TextAlt]]
ACTUAL
    $this->do_test( $expected, $actual );
}

# [[Url Alt TextAlt]]
sub test_squabbedUrlAltTextOldUndocumentedUse {
    my $this     = shift;
    my $expected = <<EXPECTED;
<a href="$this->{sup}/$Foswiki::cfg{SystemWebName}/$Foswiki::cfg{HomeTopicName}" target="_top">Alt <nop>TextAlt</a>
EXPECTED

    my $actual = <<ACTUAL;
[[$this->{sup}/$Foswiki::cfg{SystemWebName}/$Foswiki::cfg{HomeTopicName} Alt TextAlt]]
ACTUAL
    $this->do_test( $expected, $actual );
}

sub test_escapedWikiWord {
    my $this     = shift;
    my $expected = <<EXPECTED;
<nop>$Foswiki::cfg{HomeTopicName}
EXPECTED

    my $actual = <<ACTUAL;
!$Foswiki::cfg{HomeTopicName}
ACTUAL
    $this->do_test( $expected, $actual );
}

sub test_escapedSquab {
    my $this     = shift;
    my $expected = <<EXPECTED;
[<nop>[$Foswiki::cfg{SystemWebName}.$Foswiki::cfg{HomeTopicName}]]
EXPECTED

    my $actual = <<ACTUAL;
![[$Foswiki::cfg{SystemWebName}.$Foswiki::cfg{HomeTopicName}]]
ACTUAL
    $this->do_test( $expected, $actual );
}

sub test_noppedSquab {
    my $this     = shift;
    my $expected = <<EXPECTED;
[<nop>[$this->{test_web}.$Foswiki::cfg{HomeTopicName}]]
EXPECTED

    my $actual = <<ACTUAL;
[<nop>[$this->{test_web}.$Foswiki::cfg{HomeTopicName}]]
ACTUAL
    $this->do_test( $expected, $actual );
}

sub test_underscoreTopic {
    my $this     = shift;
    my $expected = <<EXPECTED;
Underscore_topic
EXPECTED

    my $actual = <<ACTUAL;
Underscore_topic
ACTUAL
    $this->do_test( $expected, $actual );
}

sub test_squabbedUnderscoreTopic {
    my $this     = shift;
    my $expected = <<EXPECTED;
<a href="$this->{sup}/$this->{test_web}/Underscore_topic">Underscore_topic</a>
EXPECTED

    my $actual = <<ACTUAL;
[[Underscore_topic]]
ACTUAL
    $this->do_test( $expected, $actual );
}

sub test_squabbedWebUnderscroe {
    my $this     = shift;
    my $expected = <<EXPECTED;
<a href="$this->{sup}/$this->{test_web}/Underscore_topic">$this->{test_web}.Underscore_topic</a>
EXPECTED

    my $actual = <<ACTUAL;
[[$this->{test_web}.Underscore_topic]]
ACTUAL
    $this->do_test( $expected, $actual );
}

sub test_squabbedWebUnderscoreAlt {
    my $this     = shift;
    my $expected = <<EXPECTED;
<a href="$this->{sup}/$this->{test_web}/Underscore_topic">topic</a>
EXPECTED

    my $actual = <<ACTUAL;
[[$this->{test_web}.Underscore_topic][topic]]
ACTUAL
    $this->do_test( $expected, $actual );
}

sub test_noppedUnderscore {
    my $this     = shift;
    my $expected = <<EXPECTED;
<nop>Underscore_topic
EXPECTED

    my $actual = <<ACTUAL;
!Underscore_topic
ACTUAL
    $this->do_test( $expected, $actual );
}

sub test_escapedSquabbedUnderscore {
    my $this     = shift;
    my $expected = <<EXPECTED;
[<nop>[$this->{test_web}.Underscore_topic]]
EXPECTED

    my $actual = <<ACTUAL;
![[$this->{test_web}.Underscore_topic]]
ACTUAL
    $this->do_test( $expected, $actual );
}

sub test_noppedSquabUnderscore {
    my $this     = shift;
    my $expected = <<EXPECTED;
[<nop>[$this->{test_web}.Underscore_topic]]
EXPECTED

    my $actual = <<ACTUAL;
[<nop>[$this->{test_web}.Underscore_topic]]
ACTUAL
    $this->do_test( $expected, $actual );
}

sub test_notATopic1 {
    my $this     = shift;
    my $expected = <<EXPECTED;
123_num
EXPECTED

    my $actual = <<ACTUAL;
123_num
ACTUAL
    $this->do_test( $expected, $actual );
}

sub test_notATopic2 {
    my $this     = shift;
    my $expected = <<EXPECTED;
H_
EXPECTED

    my $actual = <<ACTUAL;
H_
ACTUAL
    $this->do_test( $expected, $actual );
}

sub test_squabbedUS {
    my $this     = shift;
    my $expected = <<EXPECTED;
<a href="$this->{sup}/$this->{test_web}/H_">H_</a>
EXPECTED

    my $actual = <<ACTUAL;
[[H_]]
ACTUAL
    $this->do_test( $expected, $actual );
}

# The following four test cases correspond to cases 1,3,6,7 from
# Item3063.  Cases 2 is already done, 4 is equivalent to 3, and 5
# always failed and won't work right now.
#
# Case 1: Link to an existing page
sub test_wikiWordInsideSquabbedLink {
    my $this     = shift;
    my $expected = <<EXPECTED;
<a href="$this->{sup}/System/WebRssBase">System.WebRss <nop>Base</a>
EXPECTED

    my $actual = <<ACTUAL;
[[System.WebRss Base]]
ACTUAL
    $this->do_test( $expected, $actual );
}

# Case 3: WikiWord (existence doesn't matter) in a text for an
# external link
sub test_wikiWordInsideHttpLink {
    my $this     = shift;
    my $expected = <<EXPECTED;
<a href="http://google.com/" target="_top">There is a <nop>WikiWord inside an external link</a>
EXPECTED

    my $actual = <<ACTUAL;
[[http://google.com/][There is a WikiWord inside an external link]]
ACTUAL
    $this->do_test( $expected, $actual );
}

# Case 6: WikiWord (existence doesn't matter) in a text for an
# file link (more or less equivalent to case 3, but so what...)
sub test_wikiWordInsideFileLink {
    my $this     = shift;
    my $expected = <<EXPECTED;
<a href="file://tmp/pam.gif" target="_top">There is a <nop>WikiWord inside a file: link</a>
EXPECTED

    my $actual = <<ACTUAL;
[[file://tmp/pam.gif][There is a WikiWord inside a file: link]]
ACTUAL
    $this->do_test( $expected, $actual );
}

# Case 7: WikiWord (existence doesn't matter) in a text for an
# mailto link (with exception of stuffing equivalent to case 3)
sub test_wikiWordInsideMailto {
    my $this     = shift;
    my $expected = <<EXPECTED;
<a href="mailto&#58;foo&#64;barSTUFFED&#46;com">There is a <nop>WikiWord inside a mailto link</a>
EXPECTED

    my $actual = <<'ACTUAL';
[[mailto:foo@bar.com][There is a WikiWord inside a mailto link]]
ACTUAL
    $this->do_test( $expected, $actual );
}

# Case x - in the spirit of 3063: WikiWord (existence doesn't matter)
# in a text for a link beginning with '/'
sub test_wikiWordInsideRelative {
    my $this     = shift;
    my $expected = <<EXPECTED;
<a href="/somewhere/on/this/host" target="_top">There is a <nop>WikiWord inside a relative link</a>
EXPECTED

    my $actual = <<'ACTUAL';
[[/somewhere/on/this/host][There is a WikiWord inside a relative link]]
ACTUAL
    $this->do_test( $expected, $actual );
}

# End of Testcases from Item3063

# Numeric1Wikiword
sub test_numericWikiWord {
    my $this     = shift;
    my $expected = <<EXPECTED;
<a href="$this->{sup}/$this->{test_web}/Numeric1Wikiword">Numeric1Wikiword</a>
EXPECTED

    my $actual = <<ACTUAL;
Numeric1Wikiword
ACTUAL
    $this->do_test( $expected, $actual );
}

# Numeric1nowikiword
sub test_numericNoWikiWord {
    my $this     = shift;
    my $expected = <<EXPECTED;
Numeric1nowikiword
EXPECTED

    my $actual = <<ACTUAL;
Numeric1nowikiword
ACTUAL
    $this->do_test( $expected, $actual );
}

sub test_emmedWords {
    my $this     = shift;
    my $expected = <<EXPECTED;
<em>your words</em>
EXPECTED

    my $actual = <<ACTUAL;
_your words_
ACTUAL
    $this->do_test( $expected, $actual );
}

sub test_strongEmmedWords {
    my $this     = shift;
    my $expected = <<EXPECTED;
<strong><em>your words</em></strong>
EXPECTED

    my $actual = <<ACTUAL;
__your words__
ACTUAL
    $this->do_test( $expected, $actual );
}

sub test_mixedUpTopicNameAndEm {
    my $this     = shift;
    my $expected = <<EXPECTED;
<em>text with H</em> link_
EXPECTED

    my $actual = <<ACTUAL;
_text with H_ link_
ACTUAL
    $this->do_test( $expected, $actual );
}

sub test_mixedUpEmAndTopicName {
    my $this     = shift;
    my $expected = <<EXPECTED;
<strong><em>text with H_ link</em></strong>
EXPECTED

    my $actual = <<ACTUAL;
__text with H_ link__
ACTUAL
    $this->do_test( $expected, $actual );
}

sub test_squabbedEmmedTopic {
    my $this     = shift;
    my $expected = <<EXPECTED;
<em>text with <a href="$this->{sup}/$this->{test_web}/H_">H_</a> link</em>
EXPECTED

    my $actual = <<ACTUAL;
_text with [[H_]] link_
ACTUAL
    $this->do_test( $expected, $actual );
}

sub test_codedScrote {
    my $this     = shift;
    my $expected = <<EXPECTED;
<code>_your words_</code>
EXPECTED

    my $actual = <<ACTUAL;
=_your words_=
ACTUAL
    $this->do_test( $expected, $actual );
}

sub test_noppedScrote {
    my $this     = shift;
    my $expected = <<EXPECTED;
<code>your words_</code>
EXPECTED

    my $actual = <<ACTUAL;
 =your words_=
ACTUAL
    $this->do_test( $expected, $actual );
}

sub test_verboWords {
    my $this     = shift;
    my $expected = <<EXPECTED;
<pre>
your words
</pre>
EXPECTED

    my $actual = <<ACTUAL;
<verbatim>
your words
</verbatim>
ACTUAL
    $this->do_test( $expected, $actual );
}

sub test_Item3757 {
    my $this     = shift;
    my $expected = <<EXPECTED;
<textarea>
your words

some other
</textarea>
EXPECTED

    my $actual = <<ACTUAL;
<textarea>
your words

some other
</textarea>
ACTUAL
    $this->do_test( $expected, $actual );
}

sub test_Item3431 {
    my $this = shift;

    my $expected = <<EXPECTED;
<pre>
&lt;literal&gt;
your words
&lt;/literal&gt;
</pre>
EXPECTED

    my $actual = <<ACTUAL;
<verbatim>
<literal>
your words
</literal>
</verbatim>
ACTUAL
    $this->do_test( $expected, $actual );
}

sub test_Item3431a {
    my $this = shift;
    $Foswiki::cfg{AllowInlineScript} = 1;
    my $expected = <<EXPECTED;
<script>
your words
</script>
EXPECTED

    my $actual = <<ACTUAL;
<script>
your words
</script>
ACTUAL
    $this->do_test( $expected, $actual );

    $Foswiki::cfg{AllowInlineScript} = 0;
    $expected = <<EXPECTED;
<!-- <script> is not allowed on this site -->
EXPECTED
    $this->do_test( $expected, $actual );

    $actual = <<ACTUAL;
<literal>
your words
</literal>
ACTUAL
    $expected = <<EXPECTED;
<!-- <literal> is not allowed on this site -->
EXPECTED
    $this->do_test( $expected, $actual );

}

sub test_USInHeader {
    my $this     = shift;

    $Foswiki::cfg{RequireCompatibleAnchors} = 0;

    my $expected = <<EXPECTED;
<nop><h3><a name="ATest_32with_32link_32in_32header:_32Underscore_95topic"></a>Test with link in header: Underscore_topic</h3>
EXPECTED

    my $actual = <<ACTUAL;
---+++ Test with link in header: Underscore_topic
ACTUAL
    $this->do_test( $expected, $actual );
}

sub test_mailWithoutMailto {
    my $this = shift;
    $Foswiki::cfg{AntiSpam}{HideUserDetails} = 0;
    my $expected = <<EXPECTED;
<a href="mailto:pitiful\@exampleSTUFFED.com">mailto:pitiful\@exampleSTUFFED.com</a>
EXPECTED

    my $actual = <<ACTUAL;
mailto:pitiful\@example.com
ACTUAL
    $this->do_test( $expected, $actual );
}

sub test_protocols {
    my $this = shift;
    $Foswiki::cfg{AntiSpam}{HideUserDetails} = 0;
    my %urls = (
        'file://fnurfle'                         => 0,
        'ftp://bleem@snot.grumph:flibble'        => 0,
        'gopher://go.for.it/'                    => 0,
        'http://flim.flam.example.com/path:8080' => 0,
        'http://some.host/with/WikiName'         => 0,
        'https://flim.flam.example.com/path'     => 0,
        'irc://irc.com/'                         => 0,
        'mailto:pitiful@example.com' =>
'<a href="mailto:pitiful@exampleSTUFFED.com">mailto:pitiful@exampleSTUFFED.com</a>',
        'mailto:pitiful@example.com.au' =>
'<a href="mailto:pitiful@exampleSTUFFED.com.au">mailto:pitiful@exampleSTUFFED.com.au</a>',
        'mailto:pitiful@server.example.com.au' =>
'<a href="mailto:pitiful@serverSTUFFED.example.com.au">mailto:pitiful@serverSTUFFED.example.com.au</a>',
        'news:b52.on.moon'        => 0,
        'nntp:slobba.dobba'       => 0,
        'telnet://some.address:5' => 0,
    );

    foreach my $url ( keys %urls ) {
        my $expected = $urls{$url} || <<EXPECTED;
<a href="$url" target="_top">$url</a>
EXPECTED

        # URL in text
        my $actual = <<ACTUAL;
$url
ACTUAL
        $this->do_test( $expected, $actual );

        # URL in squabs
        $actual = <<ACTUAL;
[[$url]]
ACTUAL
        $this->do_test( $expected, $actual );
    }

    # mailto URL in double squabs
    $Foswiki::cfg{AntiSpam}{HideUserDetails} = 0;
    my $expected = <<EXPECTED;
<a href="mailto:flip\@exampleSTUFFED.com">Oh smeg</a>
EXPECTED
    my $actual = <<ACTUAL;
[[mailto:flip\@example.com][Oh smeg]]
ACTUAL
    $this->do_test( $expected, $actual );

    $expected = <<EXPECTED;
<a href="mailto:flip\@exampleSTUFFED.com.au">mailto:flip\@exampleSTUFFED.com.au</a>
EXPECTED
    $actual = <<ACTUAL;
mailto:flip\@example.com.au
ACTUAL
    $this->do_test( $expected, $actual );

    $expected = <<EXPECTED;
<a href="mailto:flip\@exampleSTUFFED.com.au">flip\@exampleSTUFFED.com.au</a>
EXPECTED
    $actual = <<ACTUAL;
flip\@example.com.au
ACTUAL
    $this->do_test( $expected, $actual );

    $Foswiki::cfg{AntiSpam}{HideUserDetails} = 1;
    $expected = <<EXPECTED;
<a href="mailto:flip\@exampleSTUFFED.com">Oh smeg</a>
EXPECTED
    $actual = <<ACTUAL;
[[mailto:flip\@example.com][Oh smeg]]
ACTUAL
    $this->do_test( $expected, $actual );
}

sub test_4067_entities {
    my $this     = shift;
    my $actual   = "&#131; &#x005A; &#X004E; &amp;";
    my $expected = $actual;
    $this->do_test( $expected, $actual );
}

sub test_externalLinkWithSpacedUrl {
    my $this     = shift;
    my $expected = <<EXPECTED;
<a href="http://foswiki.org/Some\%20File\%20WikiWord\%20And\%20Spaces.txt" target="_top">topic</a>
EXPECTED

    my $actual = <<ACTUAL;
[[http://foswiki.org/Some File WikiWord And Spaces.txt ][topic]]
ACTUAL
    $this->do_test( $expected, $actual );
}

sub test_internalLinkWithSpacedUrl {
    my $this     = shift;
    my $expected = <<EXPECTED;
<a class="foswikiCurrentWebHomeLink" href="$this->{sup}/$this->{test_web}/WebHome">topic</a>
EXPECTED

    my $actual = <<ACTUAL;
[[Web Home][topic]]
ACTUAL
    $this->do_test( $expected, $actual );
}

1;
