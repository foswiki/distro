# tests for basic formatting

package FormattingTests;
use strict;
use warnings;

use FoswikiFnTestCase();
our @ISA = qw( FoswikiFnTestCase );

use Foswiki();
use Foswiki::Func();
use Foswiki::Render();
use Benchmark qw( :hireswallclock);
use Error qw( :try );

sub TRACE { 0 }

my %link_tests = (
    ''           => { autolink => 0 },
    '#'          => { autolink => 0, fragment => undef },
    '#f'         => { autolink => 0, fragment => 'f' },
    '?'          => { autolink => 0, query => '' },
    '?q'         => { autolink => 0, query => 'q' },
    '?q=r'       => { autolink => 0, query => 'q=r' },
    '?q=r;s=t'   => { autolink => 0, query => 'q=r;s=t' },
    '?q=r&s=t'   => { autolink => 0, query => 'q=r&s=t' },
    '?#f'        => { query    => '', autolink => 0, fragment => 'f' },
    '?q#f'       => { query    => 'q', autolink => 0, fragment => 'f' },
    '?q=r#f'     => { query    => 'q=r', autolink => 0, fragment => 'f' },
    '?q=r;s=t#f' => { query    => 'q=r;s=t', autolink => 0, fragment => 'f' },
    '?q=r&s=t#f' => { query    => 'q=r&s=t', autolink => 0, fragment => 'f' },
    '&aa . &amp; bb#' =>
      { address => 'Aa.Bb', autolink => 0, fragment => undef },
    '&aa . &amp; bb#f' =>
      { address => 'Aa.Bb', autolink => 0, fragment => 'f' },
    '&aa . &amp; bb?'  => { address => 'Aa.Bb', autolink => 0, query => '' },
    '&aa . &amp; bb?q' => { address => 'Aa.Bb', autolink => 0, query => 'q' },
    '&aa . &amp; bb?q=r' =>
      { address => 'Aa.Bb', autolink => 0, query => 'q=r' },
    '&aa . &amp; bb?q=r;s=t' =>
      { address => 'Aa.Bb', autolink => 0, query => 'q=r;s=t' },
    '&aa . &amp; bb?q=r&s=t' =>
      { address => 'Aa.Bb', autolink => 0, query => 'q=r&s=t' },
    '&aa . &amp; bb?#f' =>
      { address => 'Aa.Bb', autolink => 0, query => '', fragment => 'f' },
    '&aa . &amp; bb?q#f' =>
      { address => 'Aa.Bb', autolink => 0, query => 'q', fragment => 'f' },
    '&aa . &amp; bb?q=r#f' =>
      { address => 'Aa.Bb', autolink => 0, query => 'q=r', fragment => 'f' },
    '&aa . &amp; bb?q=r;s=t#f' => {
        address  => 'Aa.Bb',
        autolink => 0,
        query    => 'q=r;s=t',
        fragment => 'f'
    },
    '&aa . &amp; bb?q=r&s=t#f' => {
        address  => 'Aa.Bb',
        autolink => 0,
        query    => 'q=r&s=t',
        fragment => 'f'
    },

    # Extra spacey
    ' a a ' =>
      { topic => 'AA', autolink => 0, relative => 'web', normal => undef },
    ' a a / b b ' =>
      { address => 'AA.BB', autolink => 0, relative => 0, normal => undef },
    ' a a . b b ' =>
      { address => 'AA.BB', autolink => 0, relative => 0, normal => undef },
    ' a a . b b / cc ' =>
      { address => 'AA/BB.Cc', autolink => 0, relative => 0, normal => undef },
    ' a a / b b . cc ' =>
      { address => 'AA/BB.Cc', autolink => 0, relative => 0, normal => undef },
    ' a a . b b . cc ' =>
      { address => 'AA.BB.Cc', autolink => 0, relative => 0, normal => undef },

    # Spacey
    ' aa ' =>
      { topic => 'Aa', autolink => 0, relative => 'web', normal => undef },
    ' aa / bb ' =>
      { address => 'Aa.Bb', autolink => 0, relative => 0, normal => undef },
    ' aa . bb ' =>
      { address => 'Aa.Bb', autolink => 0, relative => 0, normal => undef },
    ' aa . bb / cc ' =>
      { address => 'Aa/Bb.Cc', autolink => 0, relative => 0, normal => undef },
    ' aa / bb . cc ' =>
      { address => 'Aa/Bb.Cc', autolink => 0, relative => 0, normal => undef },
    ' aa . bb . cc ' =>
      { address => 'Aa.Bb.Cc', autolink => 0, relative => 0, normal => undef },

    #  Normalish
    'Aa' => { topic => 'Aa', autolink => 0, relative => 'web', normal => 1 },
    'Aa.Bb' =>
      { address => 'Aa.Bb', autolink => 1, relative => 0, normal => 1 },
    'Aa/Bb' =>
      { address => 'Aa.Bb', autolink => 0, relative => 0, normal => 0 },
    'Aa/Bb.Cc' =>
      { address => 'Aa/Bb.Cc', autolink => 0, relative => 0, normal => 1 },
    'Aa.Bb/Cc' =>
      { address => 'Aa/Bb.Cc', autolink => 0, relative => 0, normal => 0 },
    'Aa.Bb.Cc' =>
      { address => 'Aa/Bb.Cc', autolink => 1, relative => 0, normal => 0 },
    ' this (is). my! ?favourite=topic#ofcourse' => {
        address  => 'This(is).My!',
        autolink => 0,
        query    => 'favourite=topic',
        fragment => 'ofcourse',
        relative => 0,
        normal   => undef
    },
);

# in       - input to renderTML
# out      - renderTML output
# out11316 - renderTML prior to Item11316 (orig. empty <p></p> tag behaviour)
my %sanity_tests = (
    para_no_NLs               => { in => 'Foo',        out => 'Foo' },
    para_NL_end               => { in => "Foo\n",      out => 'Foo' },
    para_NL_begin             => { in => "\nFoo",      out => "\nFoo" },
    para_NL_between           => { in => "Foo\nBar",   out => "Foo\nBar" },
    para_NL_between_and_end   => { in => "Foo\nBar\n", out => "Foo\nBar" },
    para_NL_between_and_begin => { in => "\nFoo\nBar", out => "\nFoo\nBar" },
    para_NLs_wrap =>
      { in => "\nFoo\n", out => '<p>Foo</p>', out_11316 => "\nFoo" },
    para_NLs_wrap_and_begin =>
      { in => "\n\nFoo\n", out => '<p>Foo</p>', out_11316 => "\n<p></p>\nFoo" },
    para_NLs_wrap_and_begin2 => {
        in        => "\n\n\nFoo\n",
        out       => '<p>Foo</p>',
        out_11316 => "\n<p></p>\n<p></p>\nFoo"
    },
    para_NLs_wrap_and_end =>
      { in => "\nFoo\n\n", out => '<p>Foo</p>', out_11316 => "\nFoo" },
    para_NLs_wrap_and_end2 => {
        in        => "\nFoo\n\n\n",
        out       => '<p>Foo</p>',
        out_11316 => "\nFoo\n<p></p>"
    },
    para_NLs_wrap_and_end3 => {
        in        => "\nFoo\n\n\n\n",
        out       => '<p>Foo</p>',
        out_11316 => "\nFoo\n<p></p>\n<p></p>"
    },
    para_2NL_between => {
        in        => "Foo\n\nBar",
        out       => "<p>Foo</p>\n<p>Bar</p>",
        out_11316 => "Foo\n<p></p>\nBar"
    },
    para_2NL_between_and_begin => {
        in        => "\nFoo\n\nBar",
        out       => "<p>Foo</p>\n<p>Bar</p>",
        out_11316 => "\nFoo\n<p></p>\nBar"
    },
    para_2NL_between_and_end => {
        in        => "Foo\n\nBar\n",
        out       => "<p>Foo</p>\n<p>Bar</p>",
        out_11316 => "Foo\n<p></p>\nBar"
    },
    para_2NL_between_and_wrap => {
        in        => "\nFoo\n\nBar\n",
        out       => "<p>Foo</p>\n<p>Bar</p>",
        out_11316 => "\nFoo\n<p></p>\nBar"
    },
    para_2NL_between_and_wrap_and_begin => {
        in        => "\n\nFoo\n\nBar\n",
        out       => "<p>Foo</p>\n<p>Bar</p>",
        out_11316 => "\n<p></p>\nFoo\n<p></p>\nBar"
    },
    para_2NL_between_and_wrap_and_begin2 => {
        in        => "\n\n\nFoo\n\nBar\n",
        out       => "<p>Foo</p>\n<p>Bar</p>",
        out_11316 => "\n<p></p>\n<p></p>\nFoo\n<p></p>\nBar"
    },
);

sub new {
    my ( $class, @args ) = @_;
    my $this = $class->SUPER::new( 'Formatting', @args );

    $this->_gen_sanity_tests();

    return $this;
}

sub skip {
    my ( $this, $test ) = @_;

    return $this->SUPER::skip_test_if(
        $test,
        {
            condition => { with_dep => 'Foswiki,<,1.2' },
            tests     => {
                'FormattingTests::test_lists' =>
                  'Post-Foswiki 1.1.x TML syntax',
            }
        }
    );
}

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();
    $this->{sup} = $this->{session}->getScriptUrl( 0, 'view' );
    my ($topicObject) = Foswiki::Func::readTopic( $this->{test_web}, 'H_' );
    $topicObject->text("BLEEGLE");
    $topicObject->save();
    $topicObject->finish();
    ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, 'Underscore_topic' );
    $topicObject->text("BLEEGLE");
    $topicObject->save();
    $topicObject->finish();
    ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web},
        $Foswiki::cfg{HomeTopicName} );
    $topicObject->text("BLEEGLE");
    $topicObject->save();
    $topicObject->finish();
    ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, 'Numeric1Wikiword' );
    $topicObject->text("BLEEGLE");
    $topicObject->save();
    $Foswiki::cfg{AntiSpam}{RobotsAreWelcome} = 1;
    $Foswiki::cfg{AntiSpam}{EmailPadding}     = 'STUFFED';
    $Foswiki::cfg{AntiSpam}{EntityEncode}     = 1;
    $Foswiki::cfg{AllowInlineScript}          = 1;
    $topicObject->finish();
}

sub tear_down {
    my $this = shift;

    $this->removeWebFixture( $this->{session}, 'Aa' )
      if ( Foswiki::Func::webExists('Aa') );
    $this->removeWebFixture( $this->{session}, 'AA' )
      if ( Foswiki::Func::webExists('AA') );
    $this->removeWebFixture( $this->{session}, 'This(is)' )
      if ( Foswiki::Func::webExists('This(is)') );
    $this->SUPER::tear_down();
}

sub loadExtraConfig {
    my $this = shift;
    $this->SUPER::loadExtraConfig();

    $Foswiki::cfg{Plugins}{TablePlugin}{Enabled}      = 0;
    $Foswiki::cfg{Plugins}{RenderListPlugin}{Enabled} = 0;
}

sub _gen_sanity_tests {
    my $this = shift;

    while ( my ( $test, $params ) = each %sanity_tests ) {
        my $fn       = __PACKAGE__ . '::test_' . $test;
        my $input    = $params->{in};
        my $expected = $params->{out};

        if ( exists $params->{out_11316} && !defined $Foswiki::Render::VERSION )
        {
            $expected = $params->{out_11316};
        }

        no strict 'refs';
        *{$fn} = sub {
            my $this   = shift;
            my $result = $this->{test_topicObject}->renderTML($input);

            $this->assert_str_equals( $expected, $result );
        };
        use strict 'refs';
    }
}

# This formats the text up to immediately before <nop>s are removed, so we
# can see the nops.
sub do_test {
    my ( $this, $expected, $actual, $noHtml ) = @_;
    my $session = $this->{session};

    $this->{test_topicObject}->expandMacros($actual);
    $actual = $this->{test_topicObject}->renderTML($actual);
    if ($noHtml) {
        $this->assert_equals( $expected, $actual );
    }
    else {
        $this->assert_html_equals( $expected, $actual );
    }
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

# Item8694
sub test_Item8694 {
    my $this = shift;

# Need to exlude formatting markup from acceptable topic names for some of these tests to work
    my $saveNameFilter = $Foswiki::cfg{NameFilter};
    $Foswiki::cfg{NameFilter} = '[\\s\\*?~^\\$@%`"\'_=&;|<>\\[\\]\\x00-\\x1f]';

    my $expected = <<EXPECTED;
<a href="$this->{sup}/$this->{test_web}/$Foswiki::cfg{HomeTopicName}" class="foswikiCurrentWebHomeLink"><strong>Web</strong> <nop>Home</a>
<a href="$this->{sup}/$this->{test_web}/$Foswiki::cfg{HomeTopicName}" class="foswikiCurrentWebHomeLink">Web <strong>Home</strong></a>
<a href="$this->{sup}/$this->{test_web}/$Foswiki::cfg{HomeTopicName}" class="foswikiCurrentWebHomeLink"><code>Web</code> <strong>Home</strong></a>
<a href="$this->{sup}/$this->{test_web}/$Foswiki::cfg{HomeTopicName}" class="foswikiCurrentWebHomeLink"><em>Web</em> <code><b>Home</b></code></a>
<a href="$this->{sup}/$this->{test_web}/$Foswiki::cfg{HomeTopicName}" class="foswikiCurrentWebHomeLink"><em>Novus <nop>Foo</em></a>
<a href="$this->{sup}/$this->{test_web}/$Foswiki::cfg{HomeTopicName}" class="foswikiCurrentWebHomeLink"><em>Web <nop>Home</em></a>
<a href="$this->{sup}/$this->{test_web}/$Foswiki::cfg{HomeTopicName}" class="foswikiCurrentWebHomeLink"><code><b>Web <nop>Home</b></code></a>
<a href="$this->{sup}/$this->{test_web}/$Foswiki::cfg{HomeTopicName}" class="foswikiCurrentWebHomeLink"><em>Novus <nop>Foo</em> (<nop>Some <nop>Author, 2000)</a>
EXPECTED

    my $actual = <<ACTUAL;
[[*Web* Home]]
[[Web *Home*]]
[[WebHome][=Web= *Home*]]
[[WebHome][_Web_ ==Home==]]
[[WebHome][_Novus Foo_]]
[[_Web Home_]]
[[==Web Home==]]
[[WebHome][_Novus Foo_ (Some Author, 2000)]]
ACTUAL
    $this->do_test( $expected, $actual );
    $Foswiki::cfg{NameFilter} = $saveNameFilter;
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

    # [[WikiWord#anchor]]
    $expected = <<EXPECTED;
<a class="foswikiCurrentWebHomeLink" href="$this->{sup}/$this->{test_web}/$Foswiki::cfg{HomeTopicName}#anchor">$Foswiki::cfg{HomeTopicName}#anchor</a>
EXPECTED
    $actual = <<ACTUAL;
[[$Foswiki::cfg{HomeTopicName}#anchor]]
ACTUAL
    $this->do_test( $expected, $actual );

    # [[WikiWord?param=data]]
    $expected = <<EXPECTED;
<a class="foswikiCurrentWebHomeLink" href="$this->{sup}/$this->{test_web}/$Foswiki::cfg{HomeTopicName}?param=data">$Foswiki::cfg{HomeTopicName}</a>
EXPECTED
    $actual = <<ACTUAL;
[[$Foswiki::cfg{HomeTopicName}?param=data]]
ACTUAL
    $this->do_test( $expected, $actual );

    # [[WikiWord?param=data#anchor]]
    $expected = <<EXPECTED;
<a class="foswikiCurrentWebHomeLink" href="$this->{sup}/$this->{test_web}/$Foswiki::cfg{HomeTopicName}?param=data#anchor">$Foswiki::cfg{HomeTopicName}</a>
EXPECTED
    $actual = <<ACTUAL;
[[$Foswiki::cfg{HomeTopicName}?param=data#anchor]]
ACTUAL
    $this->do_test( $expected, $actual );

    # [[WikiWord#anchor?param=data]]
    $expected = <<EXPECTED;
<a class="foswikiCurrentWebHomeLink" href="$this->{sup}/$this->{test_web}/$Foswiki::cfg{HomeTopicName}?param=data#anchor">$Foswiki::cfg{HomeTopicName}</a>
EXPECTED
    $actual = <<ACTUAL;
[[$Foswiki::cfg{HomeTopicName}?param=data#anchor]]
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

    # [[Web.WikiWord#anchor]]
    $expected = <<EXPECTED;
<a href="$this->{sup}/$Foswiki::cfg{SystemWebName}/$Foswiki::cfg{HomeTopicName}#anchor">$Foswiki::cfg{SystemWebName}.$Foswiki::cfg{HomeTopicName}#anchor</a>
EXPECTED

    $actual = <<ACTUAL;
[[$Foswiki::cfg{SystemWebName}.$Foswiki::cfg{HomeTopicName}#anchor]]
ACTUAL
    $this->do_test( $expected, $actual );

    # [[Web.WikiWord?param=data]]
    $expected = <<EXPECTED;
<a class="foswikiCurrentWebHomeLink" href="$this->{sup}/$this->{test_web}/$Foswiki::cfg{HomeTopicName}?param=data">$Foswiki::cfg{HomeTopicName}</a>
EXPECTED

    $actual = <<ACTUAL;
[[$Foswiki::cfg{HomeTopicName}?param=data]]
ACTUAL
    $this->do_test( $expected, $actual );

    # [[Web.WikiWord?param=data#anchor]]
    $expected = <<EXPECTED;
<a href="$this->{sup}/$Foswiki::cfg{SystemWebName}/$Foswiki::cfg{HomeTopicName}?param=data#anchor">$Foswiki::cfg{SystemWebName}.$Foswiki::cfg{HomeTopicName}</a>
EXPECTED

    $actual = <<ACTUAL;
[[$Foswiki::cfg{SystemWebName}.$Foswiki::cfg{HomeTopicName}?param=data#anchor]]
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

# [[mailtoUrl Alt TextAlt]]
sub test_squabbedMailtoUrlAltTextOldUndocumentedUse {
    my $this     = shift;
    my $expected = <<EXPECTED;
<a href="mailto&#58;user&#64;exampleSTUFFED&#46;com">Alt <nop>TextAlt</a>
EXPECTED

    my $actual = <<ACTUAL;
[[mailto:user\@example.com Alt TextAlt]]
ACTUAL
    chomp $expected;
    $this->do_test( $expected, $actual, 1 );
}

# [[mailtoUrl?with params]]
sub test_squabbedMailtoUrlWithSpaces {
    my $this     = shift;
    my $expected = <<EXPECTED;
<a href="mailto&#58;user&#64;exampleSTUFFED&#46;com&#63;subject&#61;asdf&#59;&#32;asdf&amp;body&#61;asdf">mailto&#58;user&#64;exampleSTUFFED&#46;com&#63;subject&#61;asdf&#59;&#32;asdf&amp;body&#61;asdf</a>
EXPECTED

    my $actual = <<ACTUAL;
[[mailto:user\@example.com?subject=asdf; asdf&body=asdf]]
ACTUAL
    chomp $expected;
    $this->do_test( $expected, $actual, 1 );
}

# [[mailtoUrl?with params][Link text]]
sub test_squabbedMailtoUrlWithSpacesLinkText {
    my $this     = shift;
    my $expected = <<EXPECTED;
<a href="mailto&#58;user&#64;exampleSTUFFED&#46;com&#63;subject&#61;asdf&#59;&#32;asdf&#63;&amp;body&#61;asdf">Link text</a>
EXPECTED

    my $actual = <<ACTUAL;
[[mailto:user\@example.com?subject=asdf; asdf?&body=asdf][Link text]]
ACTUAL
    chomp $expected;
    $this->do_test( $expected, $actual, 1 );
}

# [[mailtoUrl?with parms]]
#  - The only entities that should be encoded are & and spaces
sub test_squabbedMailtoUrlWithSpacesNotEncoded {
    my $this = shift;
    $Foswiki::cfg{AntiSpam}{EntityEncode} = 0;
    my $expected = <<EXPECTED;
<a href="mailto:user\@exampleSTUFFED.com?subject=asdf;%20asdf&amp;body=asdf">mailto:user\@exampleSTUFFED.com?subject=asdf; asdf&amp;body=asdf</a>
EXPECTED

    my $actual = <<ACTUAL;
[[mailto:user\@example.com?subject=asdf; asdf&body=asdf]]
ACTUAL
    chomp $expected;
    $this->do_test( $expected, $actual, 1 );
}

# [[Web.WikiWord]]
sub test_squabbedWebWikiword_params {
    my $this     = shift;
    my $expected = <<EXPECTED;
<a href="$this->{sup}/$Foswiki::cfg{SystemWebName}/$Foswiki::cfg{HomeTopicName}?param=data">$Foswiki::cfg{SystemWebName}.$Foswiki::cfg{HomeTopicName}</a>
EXPECTED

    my $actual = <<ACTUAL;
[[$Foswiki::cfg{SystemWebName}.$Foswiki::cfg{HomeTopicName}?param=data]]
ACTUAL
    $this->do_test( $expected, $actual );
}

# [[Web.WikiWord][Alt TextAlt]]
sub test_squabbedWebWikiWordAltText_params {
    my $this     = shift;
    my $expected = <<EXPECTED;
<a href="$this->{sup}/$Foswiki::cfg{SystemWebName}/$Foswiki::cfg{HomeTopicName}?param=data">Alt <nop>TextAlt</a>
EXPECTED

    my $actual = <<ACTUAL;
[[$Foswiki::cfg{SystemWebName}.$Foswiki::cfg{HomeTopicName}?param=data][Alt TextAlt]]
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

#for eg, SEARCH{format="!$web.!$topic"} - just to show it won't work.
sub test_escapedWikiWord_withDotBang {
    my $this     = shift;
    my $expected = <<EXPECTED;
<nop>$Foswiki::cfg{SystemWebName}.!$Foswiki::cfg{HomeTopicName}
EXPECTED

    my $actual = <<ACTUAL;
!$Foswiki::cfg{SystemWebName}.!$Foswiki::cfg{HomeTopicName}
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

# Item2367 - explicit links inside the text string of a squab
sub test_explicitLinkInsideSquabbedLink {
    my $this     = shift;
    my $expected = <<EXPECTED;
<a href="$this->{sup}/System/WebRss">blah http<nop>://foswiki.org blah</a>
EXPECTED

    my $actual = <<ACTUAL;
[[System.WebRss][blah http://foswiki.org blah]]
ACTUAL
    $this->do_test( $expected, $actual );

    $expected = <<EXPECTED;
<a href="http://foswiki.org" target="_top">blah http<nop>://foswiki.org blah</a>
EXPECTED

    $actual = <<ACTUAL;
[[http://foswiki.org][blah http://foswiki.org blah]]
ACTUAL
    $this->do_test( $expected, $actual );

    $expected = <<EXPECTED;
<a href="http://foswiki.org" target="_top">http://foswiki.org</a>
EXPECTED

    $actual = <<ACTUAL;
[[http://foswiki.org]]
ACTUAL
    $this->do_test( $expected, $actual );
}

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
<!-- <script> is not allowed on this site - denied by deprecated {AllowInlineScript} setting -->
EXPECTED
    $this->do_test( $expected, $actual );

    $actual = <<ACTUAL;
<literal>
your words
</literal>
ACTUAL
    $expected = <<EXPECTED;
<!-- <literal> is not allowed on this site - denied by deprecated {AllowInlineScript} setting -->
EXPECTED
    $this->do_test( $expected, $actual );

}

sub test_USInHeader {
    my $this = shift;

    $Foswiki::cfg{RequireCompatibleAnchors} = 0;

    my $expected = <<EXPECTED;
<nop><h3><a name="Test_with_link_in_header:_Underscore_topic"></a>Test with link in header: Underscore_topic</h3>
EXPECTED

    my $actual = <<ACTUAL;
---+++ Test with link in header: Underscore_topic
ACTUAL
    $this->do_test( $expected, $actual );
}

sub test_mailWithoutMailto {
    my $this = shift;
    $Foswiki::cfg{AntiSpam}{HideUserDetails} = 0;
    $Foswiki::cfg{AntiSpam}{EntityEncode}    = 0;
    my %urls = (

        # All of these should result in links generated
        '1 mailto:pitiful@example.com' =>
'1 <a href="mailto:pitiful@exampleSTUFFED.com">mailto:pitiful@exampleSTUFFED.com</a>',
        '2 At endSentence@some.museum.' =>
'2 At <a href="mailto:endSentence@someSTUFFED.museum">endSentence@someSTUFFED.museum</a>.',
        '3 byIP@[192.168.1.10]' =>
          '3 <a href="mailto:byIP@[192.168.1.10]">byIP@[192.168.1.10]</a>',
        '4 "Some Name"@blah.com' =>
'4 <a href="mailto:%22Some%20Name%22@blahSTUFFED.com">"Some Name"@blahSTUFFED.com</a>',
        '5 _somename@example.com' =>
'5 <a href="mailto:_somename@exampleSTUFFED.com">_somename@exampleSTUFFED.com</a>',
        '6 mailto:_somename@example.com _italics_' =>
'6 <a href="mailto:_somename@exampleSTUFFED.com">mailto:_somename@exampleSTUFFED.com</a> <em>italics</em>',
        '7 $A12345@example.com' =>
'7 <a href="mailto:$A12345@exampleSTUFFED.com">$A12345@exampleSTUFFED.com</a>',
        '8 def!xyz%abc@example.com' =>
'8 <a href="mailto:def!xyz%25abc@exampleSTUFFED.com">def!xyz%abc@exampleSTUFFED.com</a>',
        '9 customer/department=shipping@example.com' =>
'9 <a href="mailto:customer/department%3Dshipping@exampleSTUFFED.com">customer/department=shipping@exampleSTUFFED.com</a>',
        '10 user+mailbox@example.com' =>
'10 <a href="mailto:user+mailbox@exampleSTUFFED.com">user+mailbox@exampleSTUFFED.com</a>',
        '11 "colon:name"@blah.com' =>
'11 <a href="mailto:%22colon:name%22@blahSTUFFED.com">"colon:name"@blahSTUFFED.com</a>',
        '12 "Folding White
Space"@blah.com' =>
'12 <a href="mailto:%22Folding%20White%20Space%22@blahSTUFFED.com">"Folding White
Space"@blahSTUFFED.com</a>',

        # Total exactly 254
'1111111.2222222.3333333.4444444.5555555.6666666.7777777.8888888@1111111.2222222.3333333.4444444.5555555.6666666.7777777.888888881111111.2222222.3333333.4444444.5555555.6666666.7777777.888888881111111.2222222.3333333.4444444.5555555.6666666.7777777.88.com'
          => '<a href="mailto:1111111.2222222.3333333.4444444.5555555.6666666.7777777.8888888@1111111STUFFED.2222222.3333333.4444444.5555555.6666666.7777777.888888881111111.2222222.3333333.4444444.5555555.6666666.7777777.888888881111111.2222222.3333333.4444444.5555555.6666666.7777777.88.com">1111111.2222222.3333333.4444444.5555555.6666666.7777777.8888888@1111111STUFFED.2222222.3333333.4444444.5555555.6666666.7777777.888888881111111.2222222.3333333.4444444.5555555.6666666.7777777.888888881111111.2222222.3333333.4444444.5555555.6666666.7777777.88.com</a>',

        # None of these should create links!
        '14 badIP@[192.1.1]'          => '14 badIP@[192.1.1]',
        '15 badIP2@[1923.1.1.1]'      => '15 badIP2@[1923.1.1.1]',
        '16 double..dot@@example.com' => '16 double..dot@@example.com',
        '17 double.dot@@example..com' => '17 double.dot@@example..com',
        '18 doubleAT@@example.com'    => '18 doubleAT@@example.com',
        '19 badname.@[192.168.1.10]'  => '19 badname.@[192.168.1.10]',
        '20 .badname@[192.168.1.10]'  => '20 .badname@[192.168.1.10]',
        '21 badTLD@example.porn'      => '21 badTLD@example.porn',
        '22 noTLD@home'               => '22 noTLD@home',
        '23 blah@.nospam.asdf.com'    => '23 blah@.nospam.asdf.com',
        '24 !user@example.com'        => '24 <nop>user@example.com',
        '25 <nop>user@example.com'    => '25 <nop>user@example.com',

        # Total exceeds 254
'26 1111111.2222222.3333333.4444444.5555555.6666666.7777777.8888888@1111111.2222222.3333333.4444444.5555555.6666666.7777777.888888881111111.2222222.3333333.4444444.5555555.6666666.7777777.888888881111111.2222222.3333333.4444444.5555555.6666666.7777777.888.com'
          => '26 1111111.2222222.3333333.4444444.5555555.6666666.7777777.8888888@1111111.2222222.3333333.4444444.5555555.6666666.7777777.888888881111111.2222222.3333333.4444444.5555555.6666666.7777777.888888881111111.2222222.3333333.4444444.5555555.6666666.7777777.888.com',

        # Left side exceeds 64
'27 1111111.2222222.3333333.4444444.5555555.6666666.7777777.88888888X@blah.com'
          => '27 1111111.2222222.3333333.4444444.5555555.6666666.7777777.88888888X@blah.com',

        # non-ASCII characters not supported per RFC.
        '28 René.Descartes@example.com' => '28 René.Descartes@example.com',

        # : is a special character
        '29 colon:name@blah.com' => '29 colon:name@blah.com',

# technically valid - but Foswiki doesn't support individually quoted characters
        '30 Ali\"TheBrain\"Baba@example.com' =>
          '30 Ali\"TheBrain\"Baba@example.com',

        # technically valid - but Foswiki doesn't support nested quoted strings
        '31 "Ali"TheBrain"Baba"@example.com' =>
          '31 "Ali"TheBrain"Baba"@example.com',
        '32 Numeric1Wikiword@example.com' =>
'32 <a href="mailto:Numeric1Wikiword@exampleSTUFFED.com">Numeric1Wikiword@exampleSTUFFED.com</a>',
'33 [[mailto:test@example.tom][Text with test@example.com shouldnt link]]'
          => '33 <a href="mailto:test@exampleSTUFFED.tom">Text with <nop>test@exampleSTUFFED.com shouldnt link</a>',
    );

    foreach my $url ( keys %urls ) {
        my $expected = $urls{$url};

        # URL in text
        my $actual = <<ACTUAL;
$url
ACTUAL

        #print STDERR "EXPECTED $expected from $actual\n";
        $this->do_test( $expected, $actual );
    }

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

sub test_internalLinkSpacedText_Item8713 {
    my $this = shift;

    my $editURI = $this->{session}->getScriptUrl( 0, 'edit' );

    my $expected = <<EXPECTED;
<span class="foswikiNewLink">discuss 'wiki': philosophy vs. technology<a href="$editURI/DiscussWiki:PhilosophyVs/Technology?topicparent=TemporaryFormattingTestWebFormatting.TestTopicFormatting" rel="nofollow" title="Create this topic">?</a></span>
EXPECTED

    my $actual = <<ACTUAL;
[[discuss 'wiki': philosophy vs. technology]]
ACTUAL
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

sub test_externalLinkWithSpacedQuery {
    my $this     = shift;
    my $expected = <<EXPECTED;
<a href="http://foswiki.org/Some\%20Spaces.txt?query=blah%20blah&another=blah%20blah;andlast" target="_top">topic</a>
EXPECTED

    my $actual = <<ACTUAL;
[[http://foswiki.org/Some Spaces.txt?query=blah blah&another=blah blah;andlast][topic]]
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

sub test_render_PlainText {
    my $this = shift;

#TODO: these test should move to a proper testing of Render.pm - will happen during
#extractFormat feature
    $this->assert_str_equals(
        'Apache is the well known web server.',
        $this->{session}->renderer->TML2PlainText(
'Apache is the [[http://www.apache.org/httpd/][well known web server]].'
        )
    );

    #test a few others to try to not break things
    $this->assert_str_equals(
        'Apache is the well known web server.',
        $this->{session}->{renderer}->TML2PlainText(
'Apache is the [[http://www.apache.org/httpd/ well known web server]].'
        )
    );
    $this->assert_str_equals(
        'Apache is the well known web server.',
        $this->{session}->{renderer}->TML2PlainText(
            'Apache is the [[ApacheServer][well known web server]].')
    );

    #SMELL: an unexpected result :/
    $this->assert_str_equals( 'Apache is the   well known web server  .',
        $this->{session}->{renderer}
          ->TML2PlainText('Apache is the [[well known web server]].') );
    $this->assert_str_equals( 'Apache is the well known web server.',
        $this->{session}->{renderer}
          ->TML2PlainText('Apache is the well known web server.') );

    #non formatting uses of formatting markup
    $this->assert_str_equals(
        'Apache 2*3 is the well known web server.',
        $this->{session}->{renderer}->TML2PlainText(
            'Apache 2*3 is the [[ApacheServer][well known web server]].')
    );
    $this->assert_str_equals(
        'Apache 2=3 is the well known web server.',
        $this->{session}->{renderer}->TML2PlainText(
            'Apache 2=3 is the [[ApacheServer][well known web server]].')
    );

    $this->assert_str_equals(
        'Apache 1_1 is the well known web server.',
        $this->{session}->{renderer}->TML2PlainText(
            'Apache 1_1 is the [[ApacheServer][well known web server]].')
    );

#    $this->assert_str_equals(
#        'Apache 1_1 is the %SEARCH{"one" section="two"}% well known web server.',
#        $this->{session}->{renderer}->TML2PlainText(
#            'Apache 1_1 is the %SEARCH{"one" section="two"}% [[ApacheServer][well known web server]].')
#    );
#formatting uses of formatting markup
    $this->assert_str_equals(
        'Apache 2.3 is the well known web server.',
        $this->{session}->{renderer}->TML2PlainText(
            'Apache *2.3* is the [[ApacheServer][well known web server]].')
    );

    $this->assert_str_equals(
        'Apache 1.1 is the well known web server.',
        $this->{session}->{renderer}->TML2PlainText(
            '__Apache 1.1__ is the [[ApacheServer][well known web server]].')
    );

#    $this->assert_str_equals(
#        'Apache 1_1 _is_ the %INCLUDE{"one" section="two"}% well known web server.',
#        $this->{session}->{renderer}->TML2PlainText(
#            'Apache 1_1 is the %INCLUDE{"one" section="two"}% [[ApacheServer][well known web server]].')
#    );
}

# Test mixes of :, * and 1 lists
# SMELL: extend to dl's, and make it more thorough!
sub test_lists {
    my $this     = shift;
    my $expected = <<EXPECTED;
<div class='foswikiIndent'> Para
</div> <div class='foswikiIndent'> Para
</div> <div class='foswikiIndent'> Para
</div>
<p></p><div class='foswikiIndent'> Para
</div> <ul>
<li> Bullet

</li>  </ul><div class='foswikiIndent'> Para
</div>
<p></p><div class='foswikiIndent'> Para
</div> <ol>
<li> Number
</li>  </ol><div class='foswikiIndent'> Para
</div>
<p></p><div class='foswikiIndent'> Para<div class='foswikiIndent'> Para

</div>
</div> <div class='foswikiIndent'> Para
</div>
<p></p><div class='foswikiIndent'> Para<div class='foswikiIndent'> Para<div class='foswikiIndent'> Para
</div>
</div>
</div>
<p></p>
None<div class='foswikiIndent'> Para <ul>

<li> Bullet
</li>  </ul><div class='foswikiIndent'> Slushy<div class='foswikiIndent'> Rainy
</div>
</div> <div class='foswikiIndent'> Dry
</div> <ul>
<li> Warm
</li></ul> 
</div> <div class='foswikiIndent'> Sunny

</div>
Pleasant
EXPECTED
    my $actual = <<ACTUAL;
   : Para
   : Para
   : Para

   : Para
   * Bullet
   : Para

   : Para
   1 Number
   : Para

   : Para
      : Para
   : Para

   : Para
      : Para
         : Para

None
   : Para
      * Bullet
      : Slushy
         : Rainy
      : Dry
      * Warm
   : Sunny
Pleasant
ACTUAL
    $this->do_test( $expected, $actual );
}

sub test_tableTerminatesList {
    my $this = shift;

    my $expected = <<EXPECTED;
 <ul>
<li> List item
</li></ul>
<table cellspacing="0" cellpadding="0" class="foswikiTable" border="1"><tbody><tr ><td>  a  </td>
<td>  b  </td>
</tr><tr ><td>  2  </td>
<td>  3  </td>
</tr><tr ><td>  ok  </td>
<td>  bad  </td>
</tr></tbody></table>
EXPECTED
    my $actual = <<ACTUAL;
   * List item
| a | b |
| 2 | 3 |
| ok | bad |
ACTUAL
    $this->do_test( $expected, $actual );
}

sub test_simpleTable {
    my $this = shift;

    my $expected = <<EXPECTED;
<table cellspacing="0" cellpadding="0" class="foswikiTable" border="1"><tbody><tr ><td>  a  </td>
<td>  b  </td>
</tr><tr ><td>  2  </td>
<td>  3  </td>
</tr><tr ><td>  ok  </td>
<td>  bad  </td>
</tr></tbody></table>
EXPECTED
    my $actual = <<ACTUAL;
| a | b |
| 2 | 3 |
| ok | bad |
ACTUAL
    $this->do_test( $expected, $actual );
}

sub test_tableHeadRow {
    my $this = shift;

    # SMELL: <th><strong> is redundant -  <th> implies centered and bold.
    my $expected = <<EXPECTED;
<table cellspacing="0" cellpadding="0" class="foswikiTable" border="1"><thead><tr ><th><strong> a </strong></th>
<th><strong> b </strong></th>
</tr></thead><tbody><tr ><td>  2  </td>
<td>  3  </td>
</tr><tr ><td>  ok  </td>
<td>  bad  </td>
</tr></tbody></table>
EXPECTED
    my $actual = <<ACTUAL;
| *a* | *b* |
| 2 | 3 |
| ok | bad |
ACTUAL
    $this->do_test( $expected, $actual );
}

sub test_tableEmbeddedHead {
    my $this = shift;

  # SMELL: <th><strong> is redundant -  <th> implies centered and bold.
  # Also should a row using *bold* markup that is neither a header or footer row
  # be emitted with <th> markup rather than <td>?
    my $expected = <<EXPECTED;
<table cellspacing="0" cellpadding="0" class="foswikiTable" border="1"><tbody><tr ><td>  a  </td>
<td>  b  </td>
</tr><tr ><th><strong>  2  </strong></th>
<th><strong>  3  </strong></th>
</tr><tr ><td>  ok  </td>
<td>  bad  </td>
</tr></tbody></table>
EXPECTED
    my $actual = <<ACTUAL;
| a | b |
| *2* | *3* |
| ok | bad |
ACTUAL
    $this->do_test( $expected, $actual );
}

sub test_tableSingleBoldCell {
    my $this = shift;

 # SMELL: <th><strong> is redundant -  <th> implies centered and bold.
 # Also should a cell using *bold* markup that is neither a header or footer row
 # be emitted with <th> markup rather than <td>?
    my $expected = <<EXPECTED;
<table cellspacing="0" cellpadding="0" class="foswikiTable" border="1"><tbody><tr ><td>  a  </td>
<td>  b  </td>
</tr><tr ><th><strong>  2  </strong></th>
<td>  3  </td>
</tr><tr ><td>  ok  </td>
<td>  bad  </td>
</tr></tbody></table>
EXPECTED
    my $actual = <<ACTUAL;
| a | b |
| *2* | 3 |
| ok | bad |
ACTUAL
    $this->do_test( $expected, $actual );
}

sub test_tableFootRow {
    my $this = shift;

    my $expected = <<EXPECTED;
<table cellspacing="0" cellpadding="0" class="foswikiTable" border="1">
<tfoot><tr ><th><strong>  ok  </strong></th>
<th><strong>  bad  </strong></th>
</tr></tfoot><tbody><tr ><td> a </td>
<td> b </td>
</tr><tr ><td>  2  </td>
<td>  3  </td>
</tr></tbody></table>
EXPECTED
    my $actual = <<ACTUAL;
| a | b |
| 2 | 3 |
| *ok* | *bad* |
ACTUAL
    $this->do_test( $expected, $actual );
}

sub test_tableHeadFoot {
    my $this = shift;

    my $expected = <<EXPECTED;
<table cellspacing="0" cellpadding="0" class="foswikiTable" border="1"><thead><tr ><th><strong> a </strong></th>
</tr><tr ><th><strong> b </strong></th>
</tr></thead><tfoot><tr ><th><strong> ok </strong></th>
</tr><tr ><th><strong> bad </strong></th>
</tr></tfoot><tbody><tr ><td>  2  </td>
</tr><tr ><td>  3  </td>
</tr></tbody></table>
EXPECTED
    my $actual = <<ACTUAL;
| *a* |
| *b* |
| 2 |
| 3 |
| *ok* |
| *bad* |
ACTUAL
    $this->do_test( $expected, $actual );
}

sub test_externalLinkWithImageUrl {
    my $this     = shift;
    my $expected = <<"EXPECTED";
<a href="$this->{sup}/$this->{test_web}/$this->{test_topic}" class="foswikiCurrentTopicLink" >
<img alt="foswiki-logo.gif" src="http://foswiki.org/pub/System/ProjectLogos/foswiki-logo.gif" />
</a>
EXPECTED

    my $actual = <<"ACTUAL";
[[$this->{test_topic}][ http://foswiki.org/pub/System/ProjectLogos/foswiki-logo.gif ]]
ACTUAL
    $this->do_test( $expected, $actual );
}

sub test_externalLinkWithEscapedImageUrl {
    my $this     = shift;
    my $expected = <<"EXPECTED";
<a href="$this->{sup}/$this->{test_web}/$this->{test_topic}" class="foswikiCurrentTopicLink" >
http<nop>://<nop>foswiki.org/pub/System/ProjectLogos/foswiki-logo.gif
</a>
EXPECTED

    my $actual = <<"ACTUAL";
[[$this->{test_topic}][ http://<nop>foswiki.org/pub/System/ProjectLogos/foswiki-logo.gif ]]
ACTUAL
    $this->do_test( $expected, $actual );

    # <nop> at the beginning
    $expected = <<"EXPECTED";
<a href="$this->{sup}/$this->{test_web}/$this->{test_topic}" class="foswikiCurrentTopicLink" >
<nop>http<nop>://foswiki.org/pub/System/ProjectLogos/foswiki-logo.gif
</a>
EXPECTED

    $actual = <<"ACTUAL";
[[$this->{test_topic}][<nop>http://foswiki.org/pub/System/ProjectLogos/foswiki-logo.gif]]
ACTUAL
    $this->do_test( $expected, $actual );

    # ! at the beginning
    $expected = <<"EXPECTED";
<a href="$this->{sup}/$this->{test_web}/$this->{test_topic}" class="foswikiCurrentTopicLink" >
!http<nop>://foswiki.org/pub/System/ProjectLogos/foswiki-logo.gif
</a>
EXPECTED

    $actual = <<"ACTUAL";
[[$this->{test_topic}][!http://foswiki.org/pub/System/ProjectLogos/foswiki-logo.gif]]
ACTUAL
    $this->do_test( $expected, $actual );
}

sub test_externalLinkWithImageNotUrl {
    my $this     = shift;
    my $expected = <<'EXPECTED';
<a href="http://foswiki.org/pub/System/ProjectLogos/foswiki-logo.gif" target="_top">foswiki-logo.gif</a>
EXPECTED

    my $actual = <<'ACTUAL';
[[ http://foswiki.org/pub/System/ProjectLogos/foswiki-logo.gif ][foswiki-logo.gif]]
ACTUAL
    $this->do_test( $expected, $actual );
}

sub _create_topic {
    my ( $this, $web, $topic ) = @_;
    my ($topicObject) = Foswiki::Func::readTopic( $web, $topic );

    $topicObject->save();
    $topicObject->finish();

    return;
}

sub _create_link_test_fixtures {
    my $this = shift;

    $this->_create_topic( $this->{test_web}, 'Aa' );
    $this->_create_topic( $this->{test_web}, 'AA' );
    $this->createNewFoswikiSession( $Foswiki::cfg{AdminUserLogin} );
    Foswiki::Func::createWeb('Aa');
    $this->_create_topic( 'Aa', 'Bb' );
    Foswiki::Func::createWeb('AA');
    $this->_create_topic( 'AA', 'Bb' );

    # Legacy behaviour - [[ aa . bb ]] -> AA.BB :(
    $this->_create_topic( 'AA', 'BB' );
    Foswiki::Func::createWeb('Aa/Bb');
    $this->_create_topic( 'Aa/Bb', 'Cc' );
    Foswiki::Func::createWeb('Aa/bb');
    $this->_create_topic( 'Aa/bb', 'Cc' );
    Foswiki::Func::createWeb('AA/BB');
    $this->_create_topic( 'AA/BB', 'Cc' );
    Foswiki::Func::createWeb('This(is)');
    $this->_create_topic( 'This(is)', 'My!' );

    return;
}

sub _remove_link_test_fixtures {
    my $this = shift;

    $this->removeWebFixture( $this->{session}, 'Aa' );
    $this->removeWebFixture( $this->{session}, 'AA' );
    $this->removeWebFixture( $this->{session}, 'This(is)' );

    return;
}

sub _time_link_tests {
    my $this = shift;
    my @keys = sort( keys %link_tests );

    foreach my $linktext (@keys) {
        my $tml       = "[[$linktext]]";
        my $benchmark = timeit(
            200,
            sub {
                $this->{test_topicObject}->renderTML($tml);
            }
        );
        print "$tml:\n" . timestr($benchmark) . "\n";
    }

    return;
}

sub test_timing_link_tests_exist {
    my $this = shift;

    $this->_create_link_test_fixtures();
    $this->_time_link_tests();
    $this->_remove_link_test_fixtures();

    return;
}

sub test_timing_link_tests_missing {
    my $this = shift;

    $this->_time_link_tests();

    return;
}

# I'd use URI::Encode::uri_unescape(), but ... that's not in core
sub _uri_unescape {
    my ( $this, $text ) = @_;

    $text =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;

    return $text;
}

sub _check_rendered_linktext {
    my ( $this, $linktext, $expected ) = @_;
    my $editpath      = Foswiki::Func::getScriptUrlPath( undef, undef, 'edit' );
    my $editpathregex = qr/^.*\Q$editpath\E\/([^"]*)/;
    my $viewpath      = Foswiki::Func::getScriptUrlPath( undef, undef, 'view' );
    my $viewpathregex = qr/^.*\Q$viewpath\E\/([^"]*)/;
    my $html          = $this->{test_topicObject}->renderTML("[[$linktext]]");
    my $expectedAddress;
    my $expectedAddrObj;
    my $addrObj;
    my $part;

    require HTML::Entities;
    print "[[$linktext]]\n\t$html\n" if TRACE;
    $this->assert( $html !~ $editpathregex,
        "[[$linktext]] doesn't exist (rendered as newLink: $html)" );
    $this->assert_matches( $viewpathregex, $html );
    $html =~ $viewpathregex;
    $part = $1;
    $part = HTML::Entities::decode_entities($part);
    $part = $this->_uri_unescape($part);
    $part =~ /^([^?#]*)(\?([^#]*))?(#(.*))?$/;
    my ( $address, $query, $fragment ) = ( $1, $3, $5 );

    if ( defined $expected->{address} ) {
        $expectedAddress = $expected->{address};
    }
    elsif ( defined $expected->{topic} ) {
        $expectedAddress = "$this->{test_web}.$expected->{topic}";
    }
    else {
        $expectedAddress = "$this->{test_web}.$this->{test_topic}";
    }
    my ( $actualWeb, $actualTopic ) =
      Foswiki::Func::normalizeWebTopicName( $this->{test_web}, $address );
    my ( $expectedWeb, $expectedTopic ) =
      Foswiki::Func::normalizeWebTopicName( $this->{test_web},
        $expectedAddress );
    print "\tfrag: "
      . ( defined $fragment ? $fragment : 'undef' )
      . ",\tquery: "
      . ( defined $query ? $query : 'undef' )
      . ",\taddr: "
      . ( defined $address ? $address : 'undef' ) . "\n"
      if TRACE;
    $this->assert_str_equals( "$expectedWeb.$expectedTopic",
        "$actualWeb.$actualTopic", "address mismatch checking [[$linktext]]" );
    $this->assert_deep_equals( $expected->{query}, $query,
        "query mismatch checking [[$linktext]]" );
    $this->assert_deep_equals( $expected->{fragment}, $fragment,
        "fragment mismatch checkin [[$linktext]]" );

    return;
}

# Confirm that our test data matches up with the renderer's [[link]] behaviour
# These tests were expected to be pass prior to re-working Foswiki link handling
# See Item11356 Foswiki:Development.ImplementingLinkProposals
sub test_sanity_link_tests {
    my $this = shift;

    $this->_create_link_test_fixtures();
    while ( my ( $linktext, $expected ) = each %link_tests ) {

        if ($linktext) {
            $this->_check_rendered_linktext( $linktext, $expected );
        }
    }
    $this->_remove_link_test_fixtures();

    return;
}

sub test_ampersand_querystring {
    my ($this) = shift;

    $this->_check_rendered_linktext(
        "$this->{test_topic}?q=r&s=t",
        {
            address => "$this->{test_topic}",
            query   => 'q=r&s=t'
        }
    );

    return;
}

1;
