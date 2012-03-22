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
    
    ($topicObject) = Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic} );
    $topicObject->text(<<'HERE');
   1 OkTopic
   2 [[OkATopic]]
   3 [[OkBTopic][Ok'Topic']]
   
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


    my ($topicObject) = Foswiki::Func::readTopic( $this->{test_web}, $this->{test_topic}  );
    my $linktooltipinfo = $topicObject->getPreference('LINKTOOLTIPINFO');
    $this->assert_str_equals('on', $linktooltipinfo);
    
    my $sessionlinktooltipinfo = $this->{session}->{prefs}->getPreference('LINKTOOLTIPINFO');
    $this->assert_str_equals('on', $sessionlinktooltipinfo);

    my $ex1 = Foswiki::Func::expandCommonVariables( $topicObject->text(), $topicObject->topic, $topicObject->web, $topicObject );
    my $rendered = Foswiki::Func::renderText( $topicObject->text(), $topicObject->web, $topicObject->topic );
    _cut_the_crap(\$rendered);
    $this->assert_str_equals(<<'EXPECTED', $rendered."\n");
 <ol>
<li> <a href="/foswiki/bin/view/TemporaryRenderTestsTestWebRenderTests/OkTopic" title="guest - DATE - TIME - r1.1: <nop>BLEEGLE blah/matchme.blah">OkTopic</a>
</li> <li> <a href="/foswiki/bin/view/TemporaryRenderTestsTestWebRenderTests/OkATopic" title="guest - DATE - TIME - r1.1: <nop>BLEEGLE dontmatchme.blah">OkATopic</a>
</li> <li> <a href="/foswiki/bin/view/TemporaryRenderTestsTestWebRenderTests/OkBTopic" title="guest - DATE - TIME - r1.1: <nop>BLEEGLE dont.matchmeblah">Ok'Topic'</a>
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
<li> <a href="/foswiki/bin/view/TemporaryRenderTestsTestWebRenderTests/OkTopic" title="guest - DATE - TIME - r1.1: <nop>BLEEGLE blah/matchme.blah">OkTopic</a>
</li> <li> <a href="/foswiki/bin/view/TemporaryRenderTestsTestWebRenderTests/OkATopic" title="guest - DATE - TIME - r1.1: <nop>BLEEGLE dontmatchme.blah">OkATopic</a>
</li> <li> <a href="/foswiki/bin/view/TemporaryRenderTestsTestWebRenderTests/OkBTopic" title="guest - DATE - TIME - r1.1: <nop>BLEEGLE dont.matchmeblah">Ok'Topic'</a>
</li></ol> 
<p></p> <ul>
<li> Set LINKTOOLTIPINFO = on
</li> <li> LINKTOOLTIPINFO is set to %LINKTOOLTIPINFO%
</li> <li> ATTACHFILESIZELIMIT = %ATTACHFILESIZELIMIT%
</li></ul> 
EXPECTED

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
</li></ol> 
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
