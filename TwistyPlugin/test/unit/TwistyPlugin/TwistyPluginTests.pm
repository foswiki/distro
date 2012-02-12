# See bottom of file for license and copyright information
package TwistyPluginTests;
use strict;
use warnings;

# tests for basic formatting

use FoswikiFnTestCase();
our @ISA = qw( FoswikiFnTestCase );

use Foswiki();
use Error qw( :try );
my $TEST_WEB_NAME = 'TemporaryTwistyFormattingTestWeb';
my %mangledIDs;

sub new {
    my ( $class, @args ) = @_;
    my $self = $class->SUPER::new( 'TwistyFormatting', @args );

    return $self;
}

sub set_up {
    my $this = shift;

    %mangledIDs = ();
    $this->SUPER::set_up();

    return;
}

# This formats the text up to immediately before <nop>s are removed, so we
# can see the nops.
sub do_test {
    my ( $this, $expected, $actual, $web, $topic ) = @_;
    my $session   = $this->{session};
    my $webName   = $web || $this->{test_web};
    my $topicName = $topic || $this->{test_topic};
    my $actin     = $actual;

    $actual =
      Foswiki::Func::expandCommonVariables( $actual, $topicName, $webName );
    $actual = Foswiki::Func::renderText( $actual, $webName, $topicName );
    $actual =~
s/<(span|div)([^>]*?)(\d+?)(show|hide|toggle)([^>]*?)>/'<'.$1.$2._mangleID($3).$4.$5.'>'/ge;

    $this->assert_html_equals( $expected, $actual );

    return;
}

# Convert the random IDs into sequential ones, so that we have some hope of
# writing repeatable tests.
sub _mangleID {
    my ($id) = @_;
    my $mangledID = $mangledIDs{$id};

    if ( not defined $mangledID ) {
        $mangledID = scalar( keys(%mangledIDs) ) + 1;
        $mangledIDs{$id} = $mangledID;
    }

    return $mangledID;
}

sub test_TWISTY_mode_default {
    my $this = shift;

    my $source = <<'SOURCE';
%TWISTY{}%content%ENDTWISTY%
SOURCE

    my $expected =
'<div class="twistyPlugin foswikiMakeVisible"><span id="twistyIdTemporaryTwistyFormattingTestWebTwistyFormattingTestTopicTwistyFormatting1show" style="display:none" class="twistyTrigger foswikiUnvisited twistyInited"><a href="#" class=""><span class="foswikiLinkLabel foswikiUnvisited">More...</span></a></span><span id="twistyIdTemporaryTwistyFormattingTestWebTwistyFormattingTestTopicTwistyFormatting1hide" style="display:none" class="twistyTrigger foswikiUnvisited twistyInited"><a href="#" class=""><span class="foswikiLinkLabel foswikiUnvisited">Close</span></a></span></div><div class="twistyPlugin"><div id="twistyIdTemporaryTwistyFormattingTestWebTwistyFormattingTestTopicTwistyFormatting1toggle" style="" class="twistyContent twistyInited">content</div></div>';

    $this->do_test( $expected, $source );

    return;
}

sub test_TWISTY_mode_div {
    my $this = shift;

    my $source = <<'SOURCE';
%TWISTY{mode="div"}%div content%ENDTWISTY%
SOURCE

    my $expected = <<'EXPECTED';
<div class="twistyPlugin foswikiMakeVisible"><span id="twistyIdTemporaryTwistyFormattingTestWebTwistyFormattingTestTopicTwistyFormatting1show" style="display:none" class="twistyTrigger foswikiUnvisited twistyInited"><a href="#" class=""><span class="foswikiLinkLabel foswikiUnvisited">More...</span></a></span><span id="twistyIdTemporaryTwistyFormattingTestWebTwistyFormattingTestTopicTwistyFormatting1hide" style="display:none" class="twistyTrigger foswikiUnvisited twistyInited"><a href="#" class=""><span class="foswikiLinkLabel foswikiUnvisited">Close</span></a></span></div><div class="twistyPlugin"><div id="twistyIdTemporaryTwistyFormattingTestWebTwistyFormattingTestTopicTwistyFormatting1toggle" style="" class="twistyContent twistyInited">div content</div></div>
EXPECTED

    $this->do_test( $expected, $source );

    return;
}

sub test_TWISTY_mode_default_with_id {
    my $this = shift;

    my $source = <<'SOURCE';
%TWISTY{id="myid"}%content%ENDTWISTY%
SOURCE

    my $expected = <<'EXPECTED';
<div class="twistyPlugin foswikiMakeVisible"><span id="myid1show" style="display:none" class="twistyTrigger foswikiUnvisited twistyInited"><a href="#" class=""><span class="foswikiLinkLabel foswikiUnvisited">More...</span></a></span><span id="myid1hide" style="display:none" class="twistyTrigger foswikiUnvisited twistyInited"><a href="#" class=""><span class="foswikiLinkLabel foswikiUnvisited">Close</span></a></span></div><div class="twistyPlugin"><div id="myid1toggle" style="" class="twistyContent twistyInited">content</div></div>
EXPECTED

    $this->do_test( $expected, $source );

    return;
}

sub test_TWISTY_2_instances_with_id {
    my $this = shift;

    my $source = <<'SOURCE';
%TWISTY{id="myid"}%content one%ENDTWISTY%
%TWISTY{id="myid"}%content two%ENDTWISTY%
SOURCE

    my $expected = <<'EXPECTED';
<div class="twistyPlugin foswikiMakeVisible"><span id="myid1show" style="display:none" class="twistyTrigger foswikiUnvisited twistyInited"><a href="#" class=""><span class="foswikiLinkLabel foswikiUnvisited">More...</span></a></span><span id="myid1hide" style="display:none" class="twistyTrigger foswikiUnvisited twistyInited"><a href="#" class=""><span class="foswikiLinkLabel foswikiUnvisited">Close</span></a></span></div><div class="twistyPlugin"><div id="myid1toggle" style="" class="twistyContent twistyInited">content one</div></div>
<div class="twistyPlugin foswikiMakeVisible"><span id="myid2show" style="display:none" class="twistyTrigger foswikiUnvisited twistyInited"><a href="#" class=""><span class="foswikiLinkLabel foswikiUnvisited">More...</span></a></span><span id="myid2hide" style="display:none" class="twistyTrigger foswikiUnvisited twistyInited"><a href="#" class=""><span class="foswikiLinkLabel foswikiUnvisited">Close</span></a></span></div><div class="twistyPlugin"><div id="myid2toggle" style="" class="twistyContent twistyInited">content two</div></div>
EXPECTED

    $this->do_test( $expected, $source );

    return;
}

sub test_TWISTYSHOW {
    my $this = shift;

    my $source = <<'SOURCE';
%TWISTYSHOW{id="myid"}%%TWISTYHIDE{id="myid"}%%TWISTYTOGGLE{id="myid"}%toggle content%ENDTWISTYTOGGLE%
SOURCE

    my $expected = <<'EXPECTED';
<div class="twistyPlugin foswikiMakeVisible"><span id="myidshow" style="display:none" class="twistyTrigger foswikiUnvisited twistyInited"><a href="#" class=""><span class="foswikiLinkLabel foswikiUnvisited">More...</span></a></span></div><div class="twistyPlugin foswikiMakeVisible"><span id="myidhide" style="display:none" class="twistyTrigger foswikiUnvisited twistyInited"><a href="#" class=""><span class="foswikiLinkLabel foswikiUnvisited">Close</span></a></span></div><div class="twistyPlugin"><div id="myidtoggle" style="" class="twistyContent twistyInited">toggle content</div></div>
EXPECTED

    $this->do_test( $expected, $source );

    return;
}

sub test_TWISTYBUTTON {
    my $this = shift;

    my $source = <<'SOURCE';
%TWISTYBUTTON{id="myid" link="more"}%%TWISTYTOGGLE{id="myid"}%content%ENDTWISTYTOGGLE%
SOURCE

    my $expected = <<'EXPECTED';
<div class="twistyPlugin foswikiMakeVisible"><span id="myidshow" style="display:none" class="twistyTrigger foswikiUnvisited twistyInited"><a href="#" class=""><span class="foswikiLinkLabel foswikiUnvisited">more</span></a></span><span id="myidhide" style="display:none" class="twistyTrigger foswikiUnvisited twistyInited"><a href="#" class=""><span class="foswikiLinkLabel foswikiUnvisited">more</span></a></span></div><div class="twistyPlugin"><div id="myidtoggle" style="" class="twistyContent twistyInited">content</div></div>
EXPECTED

    $this->do_test( $expected, $source );

    return;
}

sub test_TWISTY_with_icons {
    my $this            = shift;
    my $pubUrlSystemWeb = Foswiki::Func::getPubUrlPath() . '/System';

    my $source = <<'SOURCE';
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

    my $expected = <<'EXPECTED1';
<div class="twistyPlugin foswikiMakeVisible"><span id="twistyIdTemporaryTwistyFormattingTestWebTwistyFormattingTestTopicTwistyFormatting1show" style="display:none" class="twistyTrigger foswikiUnvisited twistyInited"><a href="#" class=""><img src="
EXPECTED1

    $expected .= "$pubUrlSystemWeb/DocumentGraphics/toggleopen-small.png";

    $expected .= <<'EXPECTED2';
" alt="" border="0" /><span class="foswikiLinkLabel foswikiUnvisited">Show...</span></a></span><span id="twistyIdTemporaryTwistyFormattingTestWebTwistyFormattingTestTopicTwistyFormatting1hide" style="display:none" class="twistyTrigger foswikiUnvisited twistyInited"><a href="#" class=""><img src="
EXPECTED2

    $expected .= "$pubUrlSystemWeb/DocumentGraphics/toggleclose-small.png";

    $expected .= <<'EXPECTED3';
" alt="" border="0" /><span class="foswikiLinkLabel foswikiUnvisited">Hide</span></a></span>  </div><div class="twistyPlugin"><div id="twistyIdTemporaryTwistyFormattingTestWebTwistyFormattingTestTopicTwistyFormatting1toggle" style="" class="twistyContent twistyInited">
content with icons
</div></div>
EXPECTED3

    # fix introduced linebreaks
    $expected =~ s/src="\n/src="/go;

    $this->do_test( $expected, $source );

    return;
}

sub test_TWISTY_remember {
    my $this = shift;

    my $source_off = <<'SOURCE_OFF';
%TWISTY{
showlink="Show..."
hidelink="Hide"
remember="off"
}%
my twisty content
%ENDTWISTY%
SOURCE_OFF

    my $result_off = <<'RESULT_OFF';
<div class="twistyPlugin foswikiMakeVisible"><span id="twistyIdTemporaryTwistyFormattingTestWebTwistyFormattingTestTopicTwistyFormatting1show" style="display:none" class="twistyForgetSetting twistyTrigger foswikiUnvisited twistyInited"><a href="#" class=""><span class="foswikiLinkLabel foswikiUnvisited">Show...</span></a></span><span id="twistyIdTemporaryTwistyFormattingTestWebTwistyFormattingTestTopicTwistyFormatting1hide" style="display:none" class="twistyForgetSetting twistyTrigger foswikiUnvisited twistyInited"><a href="#" class=""><span class="foswikiLinkLabel foswikiUnvisited">Hide</span></a></span></div><div class="twistyPlugin"><div id="twistyIdTemporaryTwistyFormattingTestWebTwistyFormattingTestTopicTwistyFormatting1toggle" style="" class="twistyForgetSetting twistyContent twistyInited">
my twisty content
</div></div>
RESULT_OFF

    #    $this->do_test( $result_off, $source_off );

    my $source = <<'SOURCE';
%TWISTY{
showlink="Show..."
hidelink="Hide"
remember="on"
}%
my twisty content
%ENDTWISTY%
SOURCE

    my $expected = <<'EXPECTED';
<div class="twistyPlugin foswikiMakeVisible"><span id="twistyIdTemporaryTwistyFormattingTestWebTwistyFormattingTestTopicTwistyFormatting2show" style="display:none" class="twistyRememberSetting twistyTrigger foswikiUnvisited twistyInited"><a href="#" class=""><span class="foswikiLinkLabel foswikiUnvisited">Show...</span></a></span><span id="twistyIdTemporaryTwistyFormattingTestWebTwistyFormattingTestTopicTwistyFormatting2hide" style="display:none" class="twistyRememberSetting twistyTrigger foswikiUnvisited twistyInited"><a href="#" class=""><span class="foswikiLinkLabel foswikiUnvisited">Hide</span></a></span></div><div class="twistyPlugin"><div id="twistyIdTemporaryTwistyFormattingTestWebTwistyFormattingTestTopicTwistyFormatting2toggle" style="" class="twistyRememberSetting twistyContent twistyInited">
my twisty content
</div></div>
EXPECTED

    $this->do_test( $result_off . $expected, $source_off . $source );

    return;
}

sub test_TWISTY_escaped_variable {
    my $this = shift;
    my $pubUrlSystemWeb =
      Foswiki::Func::getPubUrlPath() . '/' . $Foswiki::cfg{SystemWebName};

    my $source = <<'SOURCE';
%TWISTY{link="$percntY$percnt" mode="span"}%content%ENDTWISTY%
SOURCE

    my $expected = <<'EXPECTED1';
<span class="twistyPlugin foswikiMakeVisible"><span id="twistyIdTemporaryTwistyFormattingTestWebTwistyFormattingTestTopicTwistyFormatting1show" style="display:none" class="twistyTrigger foswikiUnvisited twistyInited"><a href="#" class=""><span class="foswikiLinkLabel foswikiUnvisited"><img src="
EXPECTED1

    $expected .= "$pubUrlSystemWeb/DocumentGraphics/choice-yes.png";

    $expected .= <<'EXPECTED2';
" alt="DONE" title="DONE" width="16" height="16" /></span></a></span><span id="twistyIdTemporaryTwistyFormattingTestWebTwistyFormattingTestTopicTwistyFormatting1hide" style="display:none" class="twistyTrigger foswikiUnvisited twistyInited"><a href="#" class=""><span class="foswikiLinkLabel foswikiUnvisited"><img src="
EXPECTED2

    $expected .= "$pubUrlSystemWeb/DocumentGraphics/choice-yes.png";

    $expected .= <<'EXPECTED3';
" alt="DONE" title="DONE" width="16" height="16" /></span></a></span></span><span class="twistyPlugin"><span id="twistyIdTemporaryTwistyFormattingTestWebTwistyFormattingTestTopicTwistyFormatting1toggle" style="" class="twistyContent twistyInited">content</span></span>
EXPECTED3

    # fix introduced linebreaks
    $expected =~ s/src="\n/src="/go;

    $this->do_test( $expected, $source );

    return;
}

sub test_TWISTY_param_linkclass {
    my $this = shift;

    my $source = <<'SOURCE';
%TWISTY{link="open" linkclass="foswikiButton" mode="div"}%contents%ENDTWISTY%
SOURCE

    my $expected = <<'EXPECTED';
<div class="twistyPlugin foswikiMakeVisible"><span id="twistyIdTemporaryTwistyFormattingTestWebTwistyFormattingTestTopicTwistyFormatting1show" style="display:none" class="twistyTrigger foswikiUnvisited twistyInited"><a href="#" class="foswikiButton"><span class="foswikiLinkLabel foswikiUnvisited">open</span></a></span><span id="twistyIdTemporaryTwistyFormattingTestWebTwistyFormattingTestTopicTwistyFormatting1hide" style="display:none" class="twistyTrigger foswikiUnvisited twistyInited"><a href="#" class="foswikiButton"><span class="foswikiLinkLabel foswikiUnvisited">open</span></a></span></div><div class="twistyPlugin"><div id="twistyIdTemporaryTwistyFormattingTestWebTwistyFormattingTestTopicTwistyFormatting1toggle" style="" class="twistyContent twistyInited">
contents
</div></div>
EXPECTED

    $this->do_test( $expected, $source );

    return;
}

sub test_twistyInSubWeb {
    my $this = shift;
    $this->{session}->finish();
    $this->{session} = Foswiki->new();

    my $testWebSubWebPath = $this->{test_web} . '/SubWeb';
    my $webObject         = $this->populateNewWeb($testWebSubWebPath);
    $webObject->finish();
    my $testTopic = 'TwistyTestTopic';
    my $source    = <<'SOURCE';
%TWISTY{
showlink="Show..."
hidelink="Hide"
remember="on"
mode="span"
}%
my twisty content
%ENDTWISTY%
SOURCE

    my ($topicObject) =
      Foswiki::Func::readTopic( $testWebSubWebPath, $testTopic );
    $topicObject->text($source);

    $topicObject->save();
    $topicObject->finish();

    my $expected = <<'EXPECTED';
<span class="twistyPlugin foswikiMakeVisible"><span id="twistyIdTemporaryTwistyFormattingTestWebTwistyFormattingsubwebSubWebTwistyTestTopic1show" style="display:none" class="twistyRememberSetting twistyTrigger foswikiUnvisited twistyInited"><a href="#" class=""><span class="foswikiLinkLabel foswikiUnvisited">Show...</span></a></span><span id="twistyIdTemporaryTwistyFormattingTestWebTwistyFormattingsubwebSubWebTwistyTestTopic1hide" style="display:none" class="twistyRememberSetting twistyTrigger foswikiUnvisited twistyInited"><a href="#" class=""><span class="foswikiLinkLabel foswikiUnvisited">Hide</span></a></span></span><span class="twistyPlugin"><span id="twistyIdTemporaryTwistyFormattingTestWebTwistyFormattingsubwebSubWebTwistyTestTopic1toggle" style="" class="twistyRememberSetting twistyContent twistyInited">
my twisty content
</span></span>
EXPECTED

    $this->do_test( $expected, $source, $testWebSubWebPath, $testTopic );

    return;
}

# Test that the JSToHideID is only emitted if the twisty's start state is
# hidden
sub test_TWISTY_start_show {
    my $this = shift;

    my $source = <<'SOURCE';
%TWISTY{start="show" mode="div"}%contents%ENDTWISTY%
SOURCE

    my $expected = <<'EXPECTED';
<div class="twistyPlugin foswikiMakeVisible"><span id="twistyIdTemporaryTwistyFormattingTestWebTwistyFormattingTestTopicTwistyFormatting1show" style="display:none" class="twistyStartShow twistyTrigger foswikiUnvisited twistyInited1"><a href="#" class=""><span class="foswikiLinkLabel foswikiUnvisited">More...</span></a></span><span id="twistyIdTemporaryTwistyFormattingTestWebTwistyFormattingTestTopicTwistyFormatting1hide" style="" class="twistyStartShow twistyTrigger foswikiUnvisited twistyInited1"><a href="#" class=""><span class="foswikiLinkLabel foswikiUnvisited">Close</span></a></span></div><div class="twistyPlugin"><div id="twistyIdTemporaryTwistyFormattingTestWebTwistyFormattingTestTopicTwistyFormatting1toggle" style="" class="twistyStartShow twistyContent twistyInited1">contents</div></div>
EXPECTED

    $this->do_test( $expected, $source );

    return;
}

# Test that the JSToHideID is only emitted once
sub test_TWISTY_two_start_hidden {
    my $this = shift;

    my $source = <<'SOURCE';
%TWISTY{id="myid1" start="hide" mode="span"}%content one%ENDTWISTY%
%TWISTY{id="myid2" start="hide" mode="span"}%content two%ENDTWISTY%
SOURCE

    my $expected = <<'EXPECTED';
<span class="twistyPlugin foswikiMakeVisible"><span id="myid1show" style="" class="twistyStartHide twistyTrigger foswikiUnvisited twistyInited0"><a href="#" class=""><span class="foswikiLinkLabel foswikiUnvisited">More...</span></a></span><span id="myid1hide" style="display:none" class="twistyStartHide twistyTrigger foswikiUnvisited twistyInited0"><a href="#" class=""><span class="foswikiLinkLabel foswikiUnvisited">Close</span></a></span></span><span class="twistyPlugin"><span id="myid1toggle" style="" class="twistyStartHide twistyContent twistyInited0">content one</span></span>
<span class="twistyPlugin foswikiMakeVisible"><span id="myid2show" style="" class="twistyStartHide twistyTrigger foswikiUnvisited twistyInited0"><a href="#" class=""><span class="foswikiLinkLabel foswikiUnvisited">More...</span></a></span><span id="myid2hide" style="display:none" class="twistyStartHide twistyTrigger foswikiUnvisited twistyInited0"><a href="#" class=""><span class="foswikiLinkLabel foswikiUnvisited">Close</span></a></span></span><span class="twistyPlugin"><span id="myid2toggle" style="" class="twistyStartHide twistyContent twistyInited0">content two</span></span>
EXPECTED

    $this->do_test( $expected, $source );

    return;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
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
