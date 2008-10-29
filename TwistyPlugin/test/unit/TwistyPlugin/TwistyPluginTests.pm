use strict;

# tests for basic formatting

package TwistyPluginTests;

use base qw( TWikiFnTestCase );

use TWiki;
use Error qw( :try );
my $TEST_WEB_NAME = 'TemporaryTwistyFormattingTestWeb';

sub new {
    my $self = shift()->SUPER::new('TwistyFormatting', @_);
    return $self;
}

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();
}

# This formats the text up to immediately before <nop>s are removed, so we
# can see the nops.
sub do_test {
    my ($this, $expected, $actual) = @_;
    my $session = $this->{twiki};
    my $webName = $this->{test_web};
    my $topicName = $this->{test_topic};

    $actual = $session->handleCommonTags( $actual, $webName, $topicName );
    $actual = $session->renderer->getRenderedVersion( $actual, $webName, $topicName );

    $this->assert_html_equals($expected, $actual);
}

sub test_TWISTY_mode_default {
    my $this = shift;

    my $source = <<SOURCE;
%TWISTY{}%content%ENDTWISTY%
SOURCE

    my $result = <<RESULT;
<span class="twistyPlugin twikiMakeVisibleInline">
 <span id="twistyIdTemporaryTwistyFormattingTestWebTwistyFormattingTestTopicTwistyFormatting1show" class="twistyTrigger twikiUnvisited twistyHidden twistyInited"><a href="#"><span class="twikiLinkLabel twikiUnvisited">More...</span></a> </span> <span id="twistyIdTemporaryTwistyFormattingTestWebTwistyFormattingTestTopicTwistyFormatting1hide" class="twistyTrigger twikiUnvisited twistyHidden twistyInited"><a href="#"><span class="twikiLinkLabel twikiUnvisited">Close</span></a> </span>  </span><!--/twistyPlugin twikiMakeVisibleInline--> <span class="twistyPlugin"><span id="twistyIdTemporaryTwistyFormattingTestWebTwistyFormattingTestTopicTwistyFormatting1toggle" class="twistyContent twikiMakeHidden twistyInited">content</span></span>
<!--/twistyPlugin-->
RESULT

    $this->do_test($result, $source);
}

sub test_TWISTY_mode_div {
    my $this = shift;

    my $source = <<SOURCE;
%TWISTY{mode="div"}%div content%ENDTWISTY%
SOURCE

    my $result = <<RESULT;
<div class="twistyPlugin twikiMakeVisibleInline">
 <span id="twistyIdTemporaryTwistyFormattingTestWebTwistyFormattingTestTopicTwistyFormatting1show" class="twistyTrigger twikiUnvisited twistyHidden twistyInited"><a href="#"><span class="twikiLinkLabel twikiUnvisited">More...</span></a> </span> <span id="twistyIdTemporaryTwistyFormattingTestWebTwistyFormattingTestTopicTwistyFormatting1hide" class="twistyTrigger twikiUnvisited twistyHidden twistyInited"><a href="#"><span class="twikiLinkLabel twikiUnvisited">Close</span></a> </span>  </div><!--/twistyPlugin twikiMakeVisibleInline--> <div class="twistyPlugin"><div id="twistyIdTemporaryTwistyFormattingTestWebTwistyFormattingTestTopicTwistyFormatting1toggle" class="twistyContent twikiMakeHidden twistyInited">div content</div></div>
<!--/twistyPlugin-->
RESULT

    $this->do_test($result, $source);
}

sub test_TWISTY_mode_default_with_id {
    my $this = shift;
    
    my $source = <<SOURCE;
%TWISTY{id="myid"}%content%ENDTWISTY%
SOURCE

    my $result = <<RESULT;
<span class="twistyPlugin twikiMakeVisibleInline">
 <span id="myidshow" class="twistyTrigger twikiUnvisited twistyHidden twistyInited"><a href="#"><span class="twikiLinkLabel twikiUnvisited">More...</span></a> </span> <span id="myidhide" class="twistyTrigger twikiUnvisited twistyHidden twistyInited"><a href="#"><span class="twikiLinkLabel twikiUnvisited">Close</span></a> </span>  </span><!--/twistyPlugin twikiMakeVisibleInline--> <span class="twistyPlugin"><span id="myidtoggle" class="twistyContent twikiMakeHidden twistyInited">content</span></span>
<!--/twistyPlugin-->
RESULT

    $this->do_test($result, $source);
}

sub test_TWISTYSHOW {
    my $this = shift;
    
    my $source = <<SOURCE;
%TWISTYSHOW{id="myid"}%%TWISTYHIDE{id="myid"}%%TWISTYTOGGLE{id="myid"}%toggle content%ENDTWISTYTOGGLE%
SOURCE

    my $result = <<RESULT;
<span class="twistyPlugin twikiMakeVisibleInline">
<span id="myidshow" class="twistyTrigger twikiUnvisited twistyHidden twistyInited"><a href="#"><span class="twikiLinkLabel twikiUnvisited">More...</span></a> </span> </span><!--/twistyPlugin twikiMakeVisibleInline--><span class="twistyPlugin twikiMakeVisibleInline">
<span id="myidhide" class="twistyTrigger twikiUnvisited twistyHidden twistyInited"><a href="#"><span class="twikiLinkLabel twikiUnvisited">Close</span></a> </span> </span><!--/twistyPlugin twikiMakeVisibleInline--><span class="twistyPlugin"><span id="myidtoggle" class="twistyContent twikiMakeHidden twistyInited">toggle content</span></span>
<!--/twistyPlugin-->
RESULT

    $this->do_test($result, $source);
}

sub test_TWISTYBUTTON {
    my $this = shift;
    
    my $source = <<SOURCE;
%TWISTYBUTTON{id="myid" link="more"}%%TWISTYTOGGLE{id="myid"}%content%ENDTWISTYTOGGLE%
SOURCE

    my $result = <<RESULT;
<span class="twistyPlugin twikiMakeVisibleInline">
 <span id="myidshow" class="twistyTrigger twikiUnvisited twistyHidden twistyInited"><a href="#"><span class="twikiLinkLabel twikiUnvisited">more</span></a> </span> <span id="myidhide" class="twistyTrigger twikiUnvisited twistyHidden twistyInited"><a href="#"><span class="twikiLinkLabel twikiUnvisited">more</span></a> </span>  </span><!--/twistyPlugin twikiMakeVisibleInline--><span class="twistyPlugin"><span id="myidtoggle" class="twistyContent twikiMakeHidden twistyInited">content</span></span>
<!--/twistyPlugin-->
RESULT

    $this->do_test($result, $source);
}

sub test_TWISTY_with_icons {
    my $this = shift;
    my $pubUrlTWikiWeb = TWiki::Func::getPubUrlPath() . '/TWiki';

    my $source = <<SOURCE;
%TWISTY{
mode="div"
showlink="Show..."
hidelink="Hide"
showimgleft="%ICONURLPATH{toggleopen-small}%"
hideimgleft="%ICONURLPATH{toggleclose-small}%"
}%
content with icons
%ENDTWISTY%
SOURCE

    my $result = <<RESULT1;
<div class="twistyPlugin twikiMakeVisibleInline">
 <span id="twistyIdTemporaryTwistyFormattingTestWebTwistyFormattingTestTopicTwistyFormatting1show" class="twistyTrigger twikiUnvisited twistyHidden twistyInited"><a href="#"><img src="
RESULT1
 
     $result .= "$pubUrlTWikiWeb/TWikiDocGraphics/toggleopen-small.gif";
     
$result .= <<RESULT2;
" border="0" alt="" /><span class="twikiLinkLabel twikiUnvisited">Show...</span></a> </span> <span id="twistyIdTemporaryTwistyFormattingTestWebTwistyFormattingTestTopicTwistyFormatting1hide" class="twistyTrigger twikiUnvisited twistyHidden twistyInited"><a href="#"><img src="
RESULT2

     $result .= "$pubUrlTWikiWeb/TWikiDocGraphics/toggleclose-small.gif";

$result .= <<RESULT3;
" border="0" alt="" /><span class="twikiLinkLabel twikiUnvisited">Hide</span></a> </span>  </div><!--/twistyPlugin twikiMakeVisibleInline--> <div class="twistyPlugin"><div id="twistyIdTemporaryTwistyFormattingTestWebTwistyFormattingTestTopicTwistyFormatting1toggle" class="twistyContent twikiMakeHidden twistyInited">
content with icons
</div></div>
<!--/twistyPlugin-->
RESULT3

    # fix introduced linebreaks
    $result =~ s/src="\n/src="/go;
    
    $this->do_test($result, $source);
}

sub test_TWISTY_remember {
    my $this = shift;
    
    my $source_off = <<SOURCE_OFF;
%TWISTY{
showlink="Show..."
hidelink="Hide"
remember="off"
}%
my twisty content
%ENDTWISTY%
SOURCE_OFF

    my $result_off = <<RESULT_OFF;
<span class="twistyPlugin twikiMakeVisibleInline">
 <span id="twistyIdTemporaryTwistyFormattingTestWebTwistyFormattingTestTopicTwistyFormatting1show" class="twistyForgetSetting twistyTrigger twikiUnvisited twistyHidden twistyInited"><a href="#"><span class="twikiLinkLabel twikiUnvisited">Show...</span></a> </span> <span id="twistyIdTemporaryTwistyFormattingTestWebTwistyFormattingTestTopicTwistyFormatting1hide" class="twistyForgetSetting twistyTrigger twikiUnvisited twistyHidden twistyInited"><a href="#"><span class="twikiLinkLabel twikiUnvisited">Hide</span></a> </span>  </span><!--/twistyPlugin twikiMakeVisibleInline--> <span class="twistyPlugin"><span id="twistyIdTemporaryTwistyFormattingTestWebTwistyFormattingTestTopicTwistyFormatting1toggle" class="twistyForgetSetting twistyContent twikiMakeHidden twistyInited">
my twisty content
</span></span>
<!--/twistyPlugin-->
RESULT_OFF

    $this->do_test($result_off, $source_off);
    
    my $source = <<SOURCE;
%TWISTY{
showlink="Show..."
hidelink="Hide"
remember="on"
}%
my twisty content
%ENDTWISTY%
SOURCE

    my $result = <<RESULT;
<span class="twistyPlugin twikiMakeVisibleInline">
 <span id="twistyIdTemporaryTwistyFormattingTestWebTwistyFormattingTestTopicTwistyFormatting2show" class="twistyRememberSetting twistyTrigger twikiUnvisited twistyHidden twistyInited"><a href="#"><span class="twikiLinkLabel twikiUnvisited">Show...</span></a> </span> <span id="twistyIdTemporaryTwistyFormattingTestWebTwistyFormattingTestTopicTwistyFormatting2hide" class="twistyRememberSetting twistyTrigger twikiUnvisited twistyHidden twistyInited"><a href="#"><span class="twikiLinkLabel twikiUnvisited">Hide</span></a> </span>  </span><!--/twistyPlugin twikiMakeVisibleInline--> <span class="twistyPlugin"><span id="twistyIdTemporaryTwistyFormattingTestWebTwistyFormattingTestTopicTwistyFormatting2toggle" class="twistyRememberSetting twistyContent twikiMakeHidden twistyInited">
my twisty content
</span></span>
<!--/twistyPlugin-->
RESULT

    $this->do_test($result, $source);
}

sub test_TWISTY_escaped_variable {
    my $this = shift;
    my $pubUrlTWikiWeb = TWiki::Func::getPubUrlPath() . '/TWiki';

    my $source = <<SOURCE;
%TWISTY{link="\$percntY\$percnt"}%content%ENDTWISTY%
SOURCE

    my $result = <<RESULT1;
<span class="twistyPlugin twikiMakeVisibleInline">
 <span id="twistyIdTemporaryTwistyFormattingTestWebTwistyFormattingTestTopicTwistyFormatting1show" class="twistyTrigger twikiUnvisited twistyHidden twistyInited"><a href="#"><span class="twikiLinkLabel twikiUnvisited"><img src="
RESULT1

    $result .= "$pubUrlTWikiWeb/TWikiDocGraphics/choice-yes.gif";

    $result .= <<RESULT2;
" alt="DONE" title="DONE" width="16" height="16" border="0" /></span></a> </span> <span id="twistyIdTemporaryTwistyFormattingTestWebTwistyFormattingTestTopicTwistyFormatting1hide" class="twistyTrigger twikiUnvisited twistyHidden twistyInited"><a href="#"><span class="twikiLinkLabel twikiUnvisited"><img src="
RESULT2

    $result .= "$pubUrlTWikiWeb/TWikiDocGraphics/choice-yes.gif";

    $result .= <<RESULT3;
" alt="DONE" title="DONE" width="16" height="16" border="0" /></span></a> </span>  </span><!--/twistyPlugin twikiMakeVisibleInline--> <span class="twistyPlugin"><span id="twistyIdTemporaryTwistyFormattingTestWebTwistyFormattingTestTopicTwistyFormatting1toggle" class="twistyContent twikiMakeHidden twistyInited">content</span></span>
<!--/twistyPlugin-->
RESULT3

    # fix introduced linebreaks
    $result =~ s/src="\n/src="/go;
    
    $this->do_test($result, $source);
}

1;
