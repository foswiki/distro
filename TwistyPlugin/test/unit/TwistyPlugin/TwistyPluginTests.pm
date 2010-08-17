# See bottom of file for license and copyright information
use strict;
use warnings;

# tests for basic formatting

package TwistyPluginTests;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use Foswiki;
use Error qw( :try );
my $TEST_WEB_NAME = 'TemporaryTwistyFormattingTestWeb';
my %mangledIDs;

sub new {
    my $self = shift()->SUPER::new( 'TwistyFormatting', @_ );
    return $self;
}

sub set_up {
    my $this = shift;

    %mangledIDs = ();
    $this->SUPER::set_up();
}

# This formats the text up to immediately before <nop>s are removed, so we
# can see the nops.
sub do_test {
    my ( $this, $expected, $actual, $web, $topic ) = @_;
    my $session   = $this->{session};
    my $webName   = $web || $this->{test_web};
    my $topicName = $topic || $this->{test_topic};

    $actual =
      Foswiki::Func::expandCommonVariables( $actual, $topicName, $webName );
    $actual = Foswiki::Func::renderText( $actual, $webName, $topicName );
    $actual =~ s/(\d+)(show|hide|toggle)/_mangleID($1).$2/ge;

    $this->assert_html_equals( $expected, $actual );
}

# Convert the random IDs into sequential ones, so that we have some hope of
# writing repeatable tests.
sub _mangleID {
    my ($id) = @_;
    my $mangledID = $mangledIDs{$id};

    if (not defined $mangledID) {
        $mangledID = scalar(keys(%mangledIDs)) + 1;
        $mangledIDs{$id} = $mangledID;
    }
    
    return $mangledID;
}

sub test_TWISTY_mode_default {
    my $this = shift;

    my $source = <<'SOURCE';
%TWISTY{}%content%ENDTWISTY%
SOURCE

    my $expected = '<span class="twistyPlugin foswikiMakeVisibleInline"><span id="twistyIdTemporaryTwistyFormattingTestWebTwistyFormattingTestTopicTwistyFormatting1show" class="twistyTrigger foswikiUnvisited twistyHidden twistyInited"><a href="#"><span class="foswikiLinkLabel foswikiUnvisited">More...</span></a></span><span id="twistyIdTemporaryTwistyFormattingTestWebTwistyFormattingTestTopicTwistyFormatting1hide" class="twistyTrigger foswikiUnvisited twistyHidden twistyInited"><a href="#"><span class="foswikiLinkLabel foswikiUnvisited">Close</span></a> </span></span><!--/twistyPlugin foswikiMakeVisibleInline--><span class="twistyPlugin"><span id="twistyIdTemporaryTwistyFormattingTestWebTwistyFormattingTestTopicTwistyFormatting1toggle" class="twistyContent foswikiMakeHidden twistyInited" style="display: none;">content</span></span><!--/twistyPlugin-->';

    $this->do_test( $expected, $source );
}

sub test_TWISTY_mode_div {
    my $this = shift;

    my $source = <<'SOURCE';
%TWISTY{mode="div"}%div content%ENDTWISTY%
SOURCE

    my $expected = <<'EXPECTED';
<div class="twistyPlugin foswikiMakeVisibleBlock"><span id="twistyIdTemporaryTwistyFormattingTestWebTwistyFormattingTestTopicTwistyFormatting1show" class="twistyTrigger foswikiUnvisited twistyHidden twistyInited"><a href="#"><span class="foswikiLinkLabel foswikiUnvisited">More...</span></a></span><span id="twistyIdTemporaryTwistyFormattingTestWebTwistyFormattingTestTopicTwistyFormatting1hide" class="twistyTrigger foswikiUnvisited twistyHidden twistyInited"><a href="#"><span class="foswikiLinkLabel foswikiUnvisited">Close</span></a> </span>  </div><!--/twistyPlugin foswikiMakeVisibleBlock--> <div class="twistyPlugin"><div id="twistyIdTemporaryTwistyFormattingTestWebTwistyFormattingTestTopicTwistyFormatting1toggle" class="twistyContent foswikiMakeHidden twistyInited" style="display: none;">div content</div></div><!--/twistyPlugin-->
EXPECTED

    $this->do_test( $expected, $source );
}

sub test_TWISTY_mode_default_with_id {
    my $this = shift;

    my $source = <<'SOURCE';
%TWISTY{id="myid"}%content%ENDTWISTY%
SOURCE

    my $expected = <<'EXPECTED';
<span class="twistyPlugin foswikiMakeVisibleInline"><span id="myid1show" class="twistyTrigger foswikiUnvisited twistyHidden twistyInited"><a href="#"><span class="foswikiLinkLabel foswikiUnvisited">More...</span></a></span><span id="myid1hide" class="twistyTrigger foswikiUnvisited twistyHidden twistyInited"><a href="#"><span class="foswikiLinkLabel foswikiUnvisited">Close</span></a> </span></span><!--/twistyPlugin foswikiMakeVisibleInline--><span class="twistyPlugin"><span id="myid1toggle" class="twistyContent foswikiMakeHidden twistyInited" style="display: none;">content</span></span><!--/twistyPlugin-->
EXPECTED

    $this->do_test( $expected, $source );
}

sub test_TWISTY_2_instances_with_id {
    my $this = shift;

    my $source = <<'SOURCE';
%TWISTY{id="myid"}%content one%ENDTWISTY%
%TWISTY{id="myid"}%content two%ENDTWISTY%
SOURCE

    my $expected = <<'EXPECTED';
<span class="twistyPlugin foswikiMakeVisibleInline"><span id="myid1show" class="twistyTrigger foswikiUnvisited twistyHidden twistyInited"><a href="#"><span class="foswikiLinkLabel foswikiUnvisited">More...</span></a></span><span id="myid1hide" class="twistyTrigger foswikiUnvisited twistyHidden twistyInited"><a href="#"><span class="foswikiLinkLabel foswikiUnvisited">Close</span></a> </span></span><!--/twistyPlugin foswikiMakeVisibleInline--><span class="twistyPlugin"><span id="myid1toggle" class="twistyContent foswikiMakeHidden twistyInited" style="display: none;">content one</span></span><!--/twistyPlugin-->
<span class="twistyPlugin foswikiMakeVisibleInline"><span id="myid2show" class="twistyTrigger foswikiUnvisited twistyHidden twistyInited"><a href="#"><span class="foswikiLinkLabel foswikiUnvisited">More...</span></a></span><span id="myid2hide" class="twistyTrigger foswikiUnvisited twistyHidden twistyInited"><a href="#"><span class="foswikiLinkLabel foswikiUnvisited">Close</span></a> </span></span><!--/twistyPlugin foswikiMakeVisibleInline--><span class="twistyPlugin"><span id="myid2toggle" class="twistyContent foswikiMakeHidden twistyInited" style="display: none;">content two</span></span><!--/twistyPlugin-->
EXPECTED

    $this->do_test( $expected, $source );
}

sub test_TWISTYSHOW {
    my $this = shift;

    my $source = <<'SOURCE';
%TWISTYSHOW{id="myid"}%%TWISTYHIDE{id="myid"}%%TWISTYTOGGLE{id="myid"}%toggle content%ENDTWISTYTOGGLE%
SOURCE

    my $expected = <<'EXPECTED';
<span class="twistyPlugin foswikiMakeVisibleInline"><span id="myidshow" class="twistyTrigger foswikiUnvisited twistyHidden twistyInited"><a href="#"><span class="foswikiLinkLabel foswikiUnvisited">More...</span></a> </span> </span><!--/twistyPlugin foswikiMakeVisibleInline--><span class="twistyPlugin foswikiMakeVisibleInline"><span id="myidhide" class="twistyTrigger foswikiUnvisited twistyHidden twistyInited"><a href="#"><span class="foswikiLinkLabel foswikiUnvisited">Close</span></a> </span> </span><!--/twistyPlugin foswikiMakeVisibleInline--><span class="twistyPlugin"><span id="myidtoggle" class="twistyContent foswikiMakeHidden twistyInited" style="display: none;">toggle content</span></span><!--/twistyPlugin-->
EXPECTED

    $this->do_test( $expected, $source );
}

sub test_TWISTYBUTTON {
    my $this = shift;

    my $source = <<'SOURCE';
%TWISTYBUTTON{id="myid" link="more"}%%TWISTYTOGGLE{id="myid"}%content%ENDTWISTYTOGGLE%
SOURCE

    my $expected = <<'EXPECTED';
<span class="twistyPlugin foswikiMakeVisibleInline"><span id="myidshow" class="twistyTrigger foswikiUnvisited twistyHidden twistyInited"><a href="#"><span class="foswikiLinkLabel foswikiUnvisited">more</span></a></span><span id="myidhide" class="twistyTrigger foswikiUnvisited twistyHidden twistyInited"><a href="#"><span class="foswikiLinkLabel foswikiUnvisited">more</span></a> </span>  </span><!--/twistyPlugin foswikiMakeVisibleInline--><span class="twistyPlugin"><span id="myidtoggle" class="twistyContent foswikiMakeHidden twistyInited" style="display: none;">content</span></span><!--/twistyPlugin-->
EXPECTED

    $this->do_test( $expected, $source );
}

sub test_TWISTY_with_icons {
    my $this           = shift;
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
<div class="twistyPlugin foswikiMakeVisibleBlock"><span id="twistyIdTemporaryTwistyFormattingTestWebTwistyFormattingTestTopicTwistyFormatting1show" class="twistyTrigger foswikiUnvisited twistyHidden twistyInited"><a href="#"><img src="
EXPECTED1

    $expected .= "$pubUrlSystemWeb/DocumentGraphics/toggleopen-small.png";

    $expected .= <<'EXPECTED2';
" border="0" alt="" /><span class="foswikiLinkLabel foswikiUnvisited">Show...</span></a></span><span id="twistyIdTemporaryTwistyFormattingTestWebTwistyFormattingTestTopicTwistyFormatting1hide" class="twistyTrigger foswikiUnvisited twistyHidden twistyInited"><a href="#"><img src="
EXPECTED2

    $expected .= "$pubUrlSystemWeb/DocumentGraphics/toggleclose-small.png";

    $expected .= <<'EXPECTED3';
" border="0" alt="" /><span class="foswikiLinkLabel foswikiUnvisited">Hide</span></a> </span>  </div><!--/twistyPlugin foswikiMakeVisibleBlock--> <div class="twistyPlugin"><div id="twistyIdTemporaryTwistyFormattingTestWebTwistyFormattingTestTopicTwistyFormatting1toggle" class="twistyContent foswikiMakeHidden twistyInited" style="display: none;">
content with icons
</div></div><!--/twistyPlugin-->
EXPECTED3

    # fix introduced linebreaks
    $expected =~ s/src="\n/src="/go;

    $this->do_test( $expected, $source );
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
<span class="twistyPlugin foswikiMakeVisibleInline"><span id="twistyIdTemporaryTwistyFormattingTestWebTwistyFormattingTestTopicTwistyFormatting1show" class="twistyForgetSetting twistyTrigger foswikiUnvisited twistyHidden twistyInited"><a href="#"><span class="foswikiLinkLabel foswikiUnvisited">Show...</span></a></span><span id="twistyIdTemporaryTwistyFormattingTestWebTwistyFormattingTestTopicTwistyFormatting1hide" class="twistyForgetSetting twistyTrigger foswikiUnvisited twistyHidden twistyInited"><a href="#"><span class="foswikiLinkLabel foswikiUnvisited">Hide</span></a> </span></span><!--/twistyPlugin foswikiMakeVisibleInline--><span class="twistyPlugin"><span id="twistyIdTemporaryTwistyFormattingTestWebTwistyFormattingTestTopicTwistyFormatting1toggle" class="twistyForgetSetting twistyContent foswikiMakeHidden twistyInited" style="display: none;">
my twisty content
</span></span><!--/twistyPlugin-->
RESULT_OFF

    $this->do_test( $result_off, $source_off );

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
<span class="twistyPlugin foswikiMakeVisibleInline"><span id="twistyIdTemporaryTwistyFormattingTestWebTwistyFormattingTestTopicTwistyFormatting2show" class="twistyRememberSetting twistyTrigger foswikiUnvisited twistyHidden twistyInited"><a href="#"><span class="foswikiLinkLabel foswikiUnvisited">Show...</span></a></span><span id="twistyIdTemporaryTwistyFormattingTestWebTwistyFormattingTestTopicTwistyFormatting2hide" class="twistyRememberSetting twistyTrigger foswikiUnvisited twistyHidden twistyInited"><a href="#"><span class="foswikiLinkLabel foswikiUnvisited">Hide</span></a> </span></span><!--/twistyPlugin foswikiMakeVisibleInline--><span class="twistyPlugin"><span id="twistyIdTemporaryTwistyFormattingTestWebTwistyFormattingTestTopicTwistyFormatting2toggle" class="twistyRememberSetting twistyContent foswikiMakeHidden twistyInited" style="display: none;">
my twisty content
</span></span><!--/twistyPlugin-->
EXPECTED

    $this->do_test( $expected, $source );
}

sub test_TWISTY_escaped_variable {
    my $this           = shift;
    my $pubUrlSystemWeb = Foswiki::Func::getPubUrlPath() . '/' . $Foswiki::cfg{SystemWebName};

    my $source = <<'SOURCE';
%TWISTY{link="$percntY$percnt"}%content%ENDTWISTY%
SOURCE

    my $expected = <<'EXPECTED1';
<span class="twistyPlugin foswikiMakeVisibleInline"><span id="twistyIdTemporaryTwistyFormattingTestWebTwistyFormattingTestTopicTwistyFormatting1show" class="twistyTrigger foswikiUnvisited twistyHidden twistyInited"><a href="#"><span class="foswikiLinkLabel foswikiUnvisited"><img src="
EXPECTED1

    $expected .= "$pubUrlSystemWeb/DocumentGraphics/choice-yes.png";

    $expected .= <<'EXPECTED2';
" alt="DONE" title="DONE" width="16" height="16" border="0" /></span></a></span><span id="twistyIdTemporaryTwistyFormattingTestWebTwistyFormattingTestTopicTwistyFormatting1hide" class="twistyTrigger foswikiUnvisited twistyHidden twistyInited"><a href="#"><span class="foswikiLinkLabel foswikiUnvisited"><img src="
EXPECTED2

    $expected .= "$pubUrlSystemWeb/DocumentGraphics/choice-yes.png";

    $expected .= <<'EXPECTED3';
" alt="DONE" title="DONE" width="16" height="16" border="0" /></span></a> </span></span><!--/twistyPlugin foswikiMakeVisibleInline--><span class="twistyPlugin"><span id="twistyIdTemporaryTwistyFormattingTestWebTwistyFormattingTestTopicTwistyFormatting1toggle" class="twistyContent foswikiMakeHidden twistyInited" style="display: none;">content</span></span><!--/twistyPlugin-->
EXPECTED3

    # fix introduced linebreaks
    $expected =~ s/src="\n/src="/go;

    $this->do_test( $expected, $source );
}

sub test_TWISTY_param_linkclass {
    my $this = shift;

    my $source = <<'SOURCE';
%TWISTY{link="open" linkclass="foswikiButton" mode="div"}%contents%ENDTWISTY%
SOURCE

    my $expected = <<'EXPECTED';
<div class="twistyPlugin foswikiMakeVisibleBlock"><span id="twistyIdTemporaryTwistyFormattingTestWebTwistyFormattingTestTopicTwistyFormatting1show" class="twistyTrigger foswikiUnvisited twistyHidden twistyInited"><a href="#"><span class="foswikiLinkLabel foswikiUnvisited foswikiButton">open</span></a></span><span id="twistyIdTemporaryTwistyFormattingTestWebTwistyFormattingTestTopicTwistyFormatting1hide" class="twistyTrigger foswikiUnvisited twistyHidden twistyInited"><a href="#"><span class="foswikiLinkLabel foswikiUnvisited foswikiButton">open</span></a></span></div><!--/twistyPlugin foswikiMakeVisibleBlock--><div class="twistyPlugin"><div id="twistyIdTemporaryTwistyFormattingTestWebTwistyFormattingTestTopicTwistyFormatting1toggle" class="twistyContent foswikiMakeHidden twistyInited" style="display: none;">
contents
</div></div><!--/twistyPlugin-->
EXPECTED

    $this->do_test( $expected, $source );
}

sub test_twistyInSubWeb {
    my $this = shift;
    $this->{session}->finish();
    $this->{session} = new Foswiki();

    my $testWebSubWebPath = $this->{test_web} . '/SubWeb';
    my $webObject = Foswiki::Meta->new( $this->{session}, $testWebSubWebPath );
    $webObject->populateNewWeb();
    my $testTopic         = 'TwistyTestTopic';
    my $source            = <<'SOURCE';
%TWISTY{
showlink="Show..."
hidelink="Hide"
remember="on"
}%
my twisty content
%ENDTWISTY%
SOURCE

    my $topicObject =
      Foswiki::Meta->new( $this->{session}, $testWebSubWebPath, $testTopic,
        $source );

    $topicObject->save();

    my $expected = <<'EXPECTED';
<span class="twistyPlugin foswikiMakeVisibleInline"><span id="twistyIdTemporaryTwistyFormattingTestWebTwistyFormattingsubwebSubWebTwistyTestTopic1show" class="twistyRememberSetting twistyTrigger foswikiUnvisited twistyHidden twistyInited"><a href="#"><span class="foswikiLinkLabel foswikiUnvisited">Show...</span></a></span><span id="twistyIdTemporaryTwistyFormattingTestWebTwistyFormattingsubwebSubWebTwistyTestTopic1hide" class="twistyRememberSetting twistyTrigger foswikiUnvisited twistyHidden twistyInited"><a href="#"><span class="foswikiLinkLabel foswikiUnvisited">Hide</span></a></span></span><!--/twistyPlugin foswikiMakeVisibleInline--><span class="twistyPlugin"><span id="twistyIdTemporaryTwistyFormattingTestWebTwistyFormattingsubwebSubWebTwistyTestTopic1toggle" class="twistyRememberSetting twistyContent foswikiMakeHidden twistyInited" style="display: none;">
my twisty content
</span></span><!--/twistyPlugin-->
EXPECTED

    $this->do_test( $expected, $source, $testWebSubWebPath, $testTopic );
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
