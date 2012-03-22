use strict;

package RenderTests;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use Foswiki;

sub set_up {
    my ($this) = shift;
    $this->SUPER::set_up(@_);

    my $timestamp = time();

    my ($topicObject) =
      Foswiki::Func::readTopic( $this->{test_web}, 'OkTopic' );
    $topicObject->text("BLEEGLE blah/matchme.blah");
    $topicObject->save( forcedate => $timestamp + 120 );
    $topicObject->finish();
    ($topicObject) = Foswiki::Func::readTopic( $this->{test_web}, 'OkATopic' );
    $topicObject->text("BLEEGLE dontmatchme.blah");
    $topicObject->save( forcedate => $timestamp + 240 );
    $topicObject->finish();
    ($topicObject) = Foswiki::Func::readTopic( $this->{test_web}, 'OkBTopic' );
    $topicObject->text("BLEEGLE dont.matchmeblah");
    $topicObject->save( forcedate => $timestamp + 480 );
    $topicObject->finish();
    
    ($topicObject) = Foswiki::Func::readTopic( $this->{test_web}, 'LunchLink' );
    $topicObject->text("BLEEGLE [[Lunch'Link]] dont.matchmeblah");
    $topicObject->save( forcedate => $timestamp + 480 );
    $topicObject->finish();

    ($topicObject) = Foswiki::Func::readTopic( $this->{test_web}, 'OneSingleQuote' );
    $topicObject->text("BLEEGLE [[OkBTopic][Lunch'nLearn]] dont.matchmeblah");
    $topicObject->save( forcedate => $timestamp + 480 );
    $topicObject->finish();

    ($topicObject) = Foswiki::Func::readTopic( $this->{test_web}, 'OneDoubleQuote' );
    $topicObject->text('BLEEGLE [[OkBTopic][Lunch"nLearn]] dont.matchmeblah');
    $topicObject->save( forcedate => $timestamp + 480 );
    $topicObject->finish();


    ($topicObject) = Foswiki::Func::readTopic( $this->{test_web}, 'SingleQuote' );
    $topicObject->text("BLEEGLE [[OkBTopic][Lunch'n'Learn]] dont.matchmeblah");
    $topicObject->save( forcedate => $timestamp + 480 );
    $topicObject->finish();

    ($topicObject) = Foswiki::Func::readTopic( $this->{test_web}, 'DoubleQuote' );
    $topicObject->text('BLEEGLE [[OkBTopic][Lunch"n"Learn]] dont.matchmeblah');
    $topicObject->save( forcedate => $timestamp + 480 );
    $topicObject->finish();


    ($topicObject) = Foswiki::Func::readTopic( $this->{test_web}, 'NoTopicLink' );
    $topicObject->text("BLEEGLE [[LunchNLearn][Lunch n Learn]] dont.matchmeblah");
    $topicObject->save( forcedate => $timestamp + 480 );
    $topicObject->finish();

    ($topicObject) = Foswiki::Func::readTopic( $this->{test_web}, 'QuoteNoTopicLink' );
    $topicObject->text("BLEEGLE [[LunchNLearn][Lunch'n'Learn]] dont.matchmeblah");
    $topicObject->save( forcedate => $timestamp + 480 );
    $topicObject->finish();


    
    ($topicObject) = Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );
    $topicObject->text(<<'HERE');
   1 OkTopic
   2 [[OkATopic]]
   3 [[OkBTopic][Ok'Topic']]
   4 LunchLink
   5 [[LunchLink][Lunch Link]]
   4 OneSingleQuote
   5 [[OneSingleQuote][1 Sinlke Q Link]]
   4 OneDoubleQuote
   5 [[OneDoubleQuote][1 double Q Link]]
   4 SingleQuote
   5 [[SingleQuote][Sinlke Q Link]]
   4 DoubleQuote
   5 [[DoubleQuote][double Q Link]]
   4 NoTopicLink
   5 [[NoTopicLink][no topic Link]]
   4 QuoteNoTopicLink
   5 [[QuoteNoTopicLink][no topic Link]]


   
   * Set LINKTOOLTIPINFO = on
   * LINKTOOLTIPINFO is set to %LINKTOOLTIPINFO%
   * ATTACHFILESIZELIMIT = %ATTACHFILESIZELIMIT%
HERE
    $topicObject->save( forcedate => $timestamp + 480 );
    $topicObject->finish();
    
    #give us a new session so the prefs are re-loaded
    my $query = Unit::Request->new('');
    $query->path_info("/$this->{test_web}/$this->{test_topic}");
    $this->createNewFoswikiSession( undef, $query );
    #need to be in view script context for tooltips to be processed.
    Foswiki::Func::getContext()->{view} = 1;

}

sub tear_down {
    my $this = shift;    # the Test::Unit::TestCase object

    $this->SUPER::tear_down(@_);
    # Remove fixtures created in set_up
    # Do *not* leave fixtures lying around!
    # See EmptyTests for an example
}

sub test_TOOLTIPS_on {
    my $this = shift;

    my $expected = <<'HERE';
 <ol>
<li> <a href="/foswiki/bin/view/TemporaryRenderTestsTestWebRenderTests/OkTopic" title="guest - DATE - TIME - r1.1: &#60;nop&#62;BLEEGLE blah/matchme.blah">OkTopic</a>
</li> <li> <a href="/foswiki/bin/view/TemporaryRenderTestsTestWebRenderTests/OkATopic" title="guest - DATE - TIME - r1.1: &#60;nop&#62;BLEEGLE dontmatchme.blah">OkATopic</a>
</li> <li> <a href="/foswiki/bin/view/TemporaryRenderTestsTestWebRenderTests/OkBTopic" title="guest - DATE - TIME - r1.1: &#60;nop&#62;BLEEGLE dont.matchmeblah">Ok'Topic'</a>
</li> <li> <a href="/foswiki/bin/view/TemporaryRenderTestsTestWebRenderTests/LunchLink" title="guest - DATE - TIME - r1.1: &#60;nop&#62;BLEEGLE Lunch&#39;Link dont.matchmeblah">LunchLink</a>
</li> <li> <a href="/foswiki/bin/view/TemporaryRenderTestsTestWebRenderTests/LunchLink" title="guest - DATE - TIME - r1.1: &#60;nop&#62;BLEEGLE Lunch&#39;Link dont.matchmeblah">Lunch <nop>Link</a>
</li> <li> <a href="/foswiki/bin/view/TemporaryRenderTestsTestWebRenderTests/OneSingleQuote" title="guest - DATE - TIME - r1.1: &#60;nop&#62;BLEEGLE Lunch&#39;nLearn dont.matchmeblah">OneSingleQuote</a>
</li> <li> <a href="/foswiki/bin/view/TemporaryRenderTestsTestWebRenderTests/OneSingleQuote" title="guest - DATE - TIME - r1.1: &#60;nop&#62;BLEEGLE Lunch&#39;nLearn dont.matchmeblah">1 <nop>Sinlke <nop>Q <nop>Link</a>
</li> <li> <a href="/foswiki/bin/view/TemporaryRenderTestsTestWebRenderTests/OneDoubleQuote" title="guest - DATE - TIME - r1.1: &#60;nop&#62;BLEEGLE Lunch&#34;nLearn dont.matchmeblah">OneDoubleQuote</a>
</li> <li> <a href="/foswiki/bin/view/TemporaryRenderTestsTestWebRenderTests/OneDoubleQuote" title="guest - DATE - TIME - r1.1: &#60;nop&#62;BLEEGLE Lunch&#34;nLearn dont.matchmeblah">1 double <nop>Q <nop>Link</a>
</li> <li> <a href="/foswiki/bin/view/TemporaryRenderTestsTestWebRenderTests/SingleQuote" title="guest - DATE - TIME - r1.1: &#60;nop&#62;BLEEGLE Lunch&#39;n&#39;Learn dont.matchmeblah">SingleQuote</a>
</li> <li> <a href="/foswiki/bin/view/TemporaryRenderTestsTestWebRenderTests/SingleQuote" title="guest - DATE - TIME - r1.1: &#60;nop&#62;BLEEGLE Lunch&#39;n&#39;Learn dont.matchmeblah">Sinlke <nop>Q <nop>Link</a>
</li> <li> <a href="/foswiki/bin/view/TemporaryRenderTestsTestWebRenderTests/DoubleQuote" title="guest - DATE - TIME - r1.1: &#60;nop&#62;BLEEGLE Lunch&#34;n&#34;Learn dont.matchmeblah">DoubleQuote</a>
</li> <li> <a href="/foswiki/bin/view/TemporaryRenderTestsTestWebRenderTests/DoubleQuote" title="guest - DATE - TIME - r1.1: &#60;nop&#62;BLEEGLE Lunch&#34;n&#34;Learn dont.matchmeblah">double <nop>Q <nop>Link</a>
</li> <li> <a href="/foswiki/bin/view/TemporaryRenderTestsTestWebRenderTests/NoTopicLink" title="guest - DATE - TIME - r1.1: &#60;nop&#62;BLEEGLE Lunch n Learn dont.matchmeblah">NoTopicLink</a>
</li> <li> <a href="/foswiki/bin/view/TemporaryRenderTestsTestWebRenderTests/NoTopicLink" title="guest - DATE - TIME - r1.1: &#60;nop&#62;BLEEGLE Lunch n Learn dont.matchmeblah">no topic <nop>Link</a>
</li> <li> <a href="/foswiki/bin/view/TemporaryRenderTestsTestWebRenderTests/QuoteNoTopicLink" title="guest - DATE - TIME - r1.1: &#60;nop&#62;BLEEGLE Lunch&#39;n&#39;Learn dont.matchmeblah">QuoteNoTopicLink</a>
</li> <li> <a href="/foswiki/bin/view/TemporaryRenderTestsTestWebRenderTests/QuoteNoTopicLink" title="guest - DATE - TIME - r1.1: &#60;nop&#62;BLEEGLE Lunch&#39;n&#39;Learn dont.matchmeblah">no topic <nop>Link</a>
</li></ol> 
<p></p>
<p></p>
<p></p> <ul>
<li> Set LINKTOOLTIPINFO = on
</li> <li> LINKTOOLTIPINFO is set to %LINKTOOLTIPINFO%
</li> <li> ATTACHFILESIZELIMIT = %ATTACHFILESIZELIMIT%
</li></ul> 
HERE

    my ($topicObject) = Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic}  );
    my $linktooltipinfo = $topicObject->getPreference('LINKTOOLTIPINFO');
    $this->assert_str_equals('on', $linktooltipinfo);
    
    my $sessionlinktooltipinfo = $this->{session}->{prefs}->getPreference('LINKTOOLTIPINFO');
    $this->assert_str_equals('on', $sessionlinktooltipinfo);

    my $ex1 = Foswiki::Func::expandCommonVariables( $topicObject->text(), $topicObject->topic, $topicObject->web, $topicObject );
    my $rendered = Foswiki::Func::renderText( $topicObject->text(), $topicObject->web, $topicObject->topic );
    _cut_the_crap(\$rendered);
    $this->assert_str_equals($expected, $rendered."\n");

    my $tml = $topicObject->renderTML($topicObject->text());
    _cut_the_crap(\$tml);
    $this->assert_str_equals($expected, $tml."\n");

}

#IMO this is extremely unhelpful to users, but it _is_ how it works.
sub test_TOOLTIPS_on_space {
    my $this = shift;
    
    
    my ($topicObject) = Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );
    $topicObject->text(<<'HERE');
   1 OkTopic
   2 [[OkATopic]]
   3 [[OkBTopic][Ok'Topic']]
   
   * Set LINKTOOLTIPINFO = on 
   * LINKTOOLTIPINFO is set to %LINKTOOLTIPINFO%
   * ATTACHFILESIZELIMIT = %ATTACHFILESIZELIMIT%
HERE
    $topicObject->save( );
    $topicObject->finish();
    
    #give us a new session so the prefs are re-loaded
    my $query = Unit::Request->new('');
    $query->path_info("/$this->{test_web}/$this->{test_topic}");
    $this->createNewFoswikiSession( undef, $query );
    #need to be in view script context for tooltips to be processed.
    Foswiki::Func::getContext()->{view} = 1;


    ($topicObject) = Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic}  );
    my $linktooltipinfo = $topicObject->getPreference('LINKTOOLTIPINFO');
    $this->assert_str_equals('on ', $linktooltipinfo);
    
    my $sessionlinktooltipinfo = $this->{session}->{prefs}->getPreference('LINKTOOLTIPINFO');
    $this->assert_str_equals('on ', $sessionlinktooltipinfo);

    my $ex1 = Foswiki::Func::expandCommonVariables( $topicObject->text(), $topicObject->topic, $topicObject->web, $topicObject );
    my $rendered = Foswiki::Func::renderText( $topicObject->text(), $topicObject->web, $topicObject->topic );
    _cut_the_crap(\$rendered);
    $this->assert_str_equals(<<'EXPECTED', $rendered."\n");
 <ol>
<li> <a href="/foswiki/bin/view/TemporaryRenderTestsTestWebRenderTests/OkTopic" title="on ">OkTopic</a>
</li> <li> <a href="/foswiki/bin/view/TemporaryRenderTestsTestWebRenderTests/OkATopic" title="on ">OkATopic</a>
</li> <li> <a href="/foswiki/bin/view/TemporaryRenderTestsTestWebRenderTests/OkBTopic" title="on ">Ok'Topic'</a>
</li></ol> 
<p></p> <ul>
<li> Set LINKTOOLTIPINFO = on 
</li> <li> LINKTOOLTIPINFO is set to %LINKTOOLTIPINFO%
</li> <li> ATTACHFILESIZELIMIT = %ATTACHFILESIZELIMIT%
</li></ul> 
EXPECTED

    my $tml = $topicObject->renderTML($topicObject->text());
    _cut_the_crap(\$tml);
    $this->assert_str_equals(<<'EXPECTED', $tml."\n");
 <ol>
<li> <a href="/foswiki/bin/view/TemporaryRenderTestsTestWebRenderTests/OkTopic" title="on ">OkTopic</a>
</li> <li> <a href="/foswiki/bin/view/TemporaryRenderTestsTestWebRenderTests/OkATopic" title="on ">OkATopic</a>
</li> <li> <a href="/foswiki/bin/view/TemporaryRenderTestsTestWebRenderTests/OkBTopic" title="on ">Ok'Topic'</a>
</li></ol> 
<p></p> <ul>
<li> Set LINKTOOLTIPINFO = on 
</li> <li> LINKTOOLTIPINFO is set to %LINKTOOLTIPINFO%
</li> <li> ATTACHFILESIZELIMIT = %ATTACHFILESIZELIMIT%
</li></ul> 
EXPECTED

}

#this will render the text as with the context as Main.WebHome
#so settings will not come from the test_topic.
sub test_TOOLTIPS_other_topic_context {
    my $this = shift;

    $this->createNewFoswikiSession( );
    #need to be in view script context for tooltips to be processed.
    Foswiki::Func::getContext()->{view} = 1;

    my ($topicObject) = Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic}  );
    my $linktooltipinfo = $topicObject->getPreference('LINKTOOLTIPINFO');
    $this->assert_str_equals('on', $linktooltipinfo);
    
    my $sessionlinktooltipinfo = $this->{session}->{prefs}->getPreference('LINKTOOLTIPINFO');
    $this->assert_str_equals('off', $sessionlinktooltipinfo);

    my $ex1 = Foswiki::Func::expandCommonVariables( $topicObject->text(), $topicObject->topic, $topicObject->web, $topicObject );
    my $rendered = Foswiki::Func::renderText( $topicObject->text(), $topicObject->web, $topicObject->topic );
#    $this->assert_str_equals(<<'EXPECTED', $rendered);
#EXPECTED

    my $tml = $topicObject->renderTML($topicObject->text());
    $this->assert_str_equals(<<'EXPECTED', $tml."\n");
 <ol>
<li> <a href="http://your.domain.com/foswiki/bin/view/TemporaryRenderTestsTestWebRenderTests/OkTopic">OkTopic</a>
</li> <li> <a href="http://your.domain.com/foswiki/bin/view/TemporaryRenderTestsTestWebRenderTests/OkATopic">OkATopic</a>
</li> <li> <a href="http://your.domain.com/foswiki/bin/view/TemporaryRenderTestsTestWebRenderTests/OkBTopic">Ok'Topic'</a>
</li> <li> <a href="http://your.domain.com/foswiki/bin/view/TemporaryRenderTestsTestWebRenderTests/LunchLink">LunchLink</a>
</li> <li> <a href="http://your.domain.com/foswiki/bin/view/TemporaryRenderTestsTestWebRenderTests/LunchLink">Lunch <nop>Link</a>
</li> <li> <a href="http://your.domain.com/foswiki/bin/view/TemporaryRenderTestsTestWebRenderTests/OneSingleQuote">OneSingleQuote</a>
</li> <li> <a href="http://your.domain.com/foswiki/bin/view/TemporaryRenderTestsTestWebRenderTests/OneSingleQuote">1 <nop>Sinlke <nop>Q <nop>Link</a>
</li> <li> <a href="http://your.domain.com/foswiki/bin/view/TemporaryRenderTestsTestWebRenderTests/OneDoubleQuote">OneDoubleQuote</a>
</li> <li> <a href="http://your.domain.com/foswiki/bin/view/TemporaryRenderTestsTestWebRenderTests/OneDoubleQuote">1 double <nop>Q <nop>Link</a>
</li> <li> <a href="http://your.domain.com/foswiki/bin/view/TemporaryRenderTestsTestWebRenderTests/SingleQuote">SingleQuote</a>
</li> <li> <a href="http://your.domain.com/foswiki/bin/view/TemporaryRenderTestsTestWebRenderTests/SingleQuote">Sinlke <nop>Q <nop>Link</a>
</li> <li> <a href="http://your.domain.com/foswiki/bin/view/TemporaryRenderTestsTestWebRenderTests/DoubleQuote">DoubleQuote</a>
</li> <li> <a href="http://your.domain.com/foswiki/bin/view/TemporaryRenderTestsTestWebRenderTests/DoubleQuote">double <nop>Q <nop>Link</a>
</li> <li> <a href="http://your.domain.com/foswiki/bin/view/TemporaryRenderTestsTestWebRenderTests/NoTopicLink">NoTopicLink</a>
</li> <li> <a href="http://your.domain.com/foswiki/bin/view/TemporaryRenderTestsTestWebRenderTests/NoTopicLink">no topic <nop>Link</a>
</li> <li> <a href="http://your.domain.com/foswiki/bin/view/TemporaryRenderTestsTestWebRenderTests/QuoteNoTopicLink">QuoteNoTopicLink</a>
</li> <li> <a href="http://your.domain.com/foswiki/bin/view/TemporaryRenderTestsTestWebRenderTests/QuoteNoTopicLink">no topic <nop>Link</a>
</li></ol> 
<p></p>
<p></p>
<p></p> <ul>
<li> Set TemporaryRenderTestsTestWebRenderTests.LINKTOOLTIPINFO = on
</li> <li> TemporaryRenderTestsTestWebRenderTests.LINKTOOLTIPINFO is set to %LINKTOOLTIPINFO%
</li> <li> TemporaryRenderTestsTestWebRenderTests.ATTACHFILESIZELIMIT = %ATTACHFILESIZELIMIT%
</li></ul> 
EXPECTED

}

sub _cut_the_crap {
    #from Fn_SEARCH::cut_the_crap
        ${$_[0]} =~ s/\d\d:\d\d( \(\w+\))?/TIME/g;
        ${$_[0]} =~ s/\d{2} \w{3} \d{4}/DATE/g;
}

1;
