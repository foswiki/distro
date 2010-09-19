# See bottom of file for license and copyright information

use strict;
use warnings;
use Foswiki::Func;

package Foswiki::Plugins::SlideShowPlugin::SlideShow;

use vars qw( $imgRoot $installWeb );

my $commentLabel = '';
my $hideComments = 0;
my $addedHead    = 0;

=pod

=cut

sub init {
    $installWeb = shift;
    $imgRoot    = '%PUBURLPATH%/' . $installWeb . '/SlideShowPlugin';
    $commentLabel =
      Foswiki::Func::getPreferencesValue('SLIDESHOWPLUGIN_COMMENTS_LABEL')
      || 'Comments';
    $hideComments =
      Foswiki::Func::isTrue(
        Foswiki::Func::getPreferencesValue('SLIDESHOWPLUGIN_HIDECOMMENTS')
          || '' );
}

=pod

=cut

sub handler {
    my ( $text, $theTopic, $theWeb ) = @_;

    my $textPre  = '';
    my $textPost = '';
    my $args     = '';
    if ( $text =~ /^(.*)%SLIDESHOWSTART%(.*)$/s ) {
        $textPre = $1;
        $text    = $2;
    }
    elsif ( $text =~ /^(.*)%SLIDESHOWSTART{(.*?)}%(.*)$/s ) {
        $textPre = $1;
        $args    = $2;
        $text    = $3;
    }
    if ( $text =~ /^(.*)%SLIDESHOWEND%(.*)$/s ) {
        $text     = $1;
        $textPost = $2;
    }

    # Make sure we don't end up back in the handler again
    # SMELL: there should be a better block
    $text =~ s/%SLIDESHOW/%<nop>SLIDESHOW/g;

    my $query = Foswiki::Func::getCgiQuery();

    # Build query string based on existingURL parameters
    my $queryParams = '?slideshow=on;template=viewslideshow';
    foreach my $name ( $query->param ) {
        next
          if ( $name =~
            /(text|keywords|web|topic|slideshow|skin|cover|template|\#)/ );
        $queryParams .= ';' . $name . '=' . urlEncode( $query->param($name) );
    }

    if ( $query && $query->param('slideshow') ) {

        # in presentation mode
        # do not write the topic text when in slideshow mode

        _addHeader();
        my $tmplText = readTmplText( $theWeb, $args );
        trimSpaces($tmplText);

        # do not show toolbar when template already has page controls
        my $hasNavigationInTemplate = 0;
        $hasNavigationInTemplate = 1
          if $tmplText =~
m/%(SLIDENAV|SLIDENAVALL|SLIDENAVFIRST|SLIDENAVPREV|SLIDENAVNEXT|SLIDENAVLAST)%/;

        my $slideMax = 0;

        if ( $text =~ /(.*?[\n\r])\-\-\-+(\++)\!* (.*)/s ) {

            $text = $3;
            my $level = $2;
            $level =~ s/\+/\\\+/go;
            my @slides = split( /[\n\r]\-\-\-+$level\!* /, $text );
            $text = '';

            my $slideNum = 1;
            $slideMax = @slides;
            my @titles = ();
            foreach (@slides) {
                next unless /^([^\n\r]*)(.*)$/s;

                my $slideTitle = $1;
                my $slideText  = renderSlidePane(
                    $tmplText,    $slideTitle,
                    $2,           $level,
                    $slideNum,    $slideMax,
                    $queryParams, $theWeb,
                    $theTopic,    not $hasNavigationInTemplate
                );

                push( @titles, $slideTitle );

                $text .= $slideText;
                $slideNum++;
            }

            $text =~
s/%TOC(?:\{.*?\})*%/renderSlideToc( $theWeb, $theTopic, $queryParams, @titles )/geo;
        }

        my $toolbar = '';
        if ( !$hasNavigationInTemplate ) {
            $toolbar = htmlGlobalNav( $theWeb, $theTopic );
            $toolbar =~ s/%SLIDEMAX%/$slideMax/go;
        }

        $textPre =
            '%JQREQUIRE{"CYCLE,EASING,CHILI"}%' 
          . $toolbar
          . '<div class="slideshow">';
        $textPost = '</div>';

        $text = "$textPre\n$text\n";
        $text .= $textPost;
    }
    else {

        # in normal topic view mode
        if ( $text =~ /[\n\r]\-\-\-+(\++)/s ) {
            my $level = $1;
            $level =~ s/\+/\\\+/go;

            # add slide number to heading
            my $slideNum = 1;
            $text =~
s/([\n\r]\-\-\-+$level\!*) ([^\n\r]+)/"$1 Slide " . $slideNum++ . ": $2"/ges;
        }
        $text =
            "$textPre \n#StartPresentation\n"
          . renderSlideNav( $theWeb, $theTopic, 1, 1, "s", $queryParams )
          . "\n$text $textPost";
    }

    return $text;
}

=pod

=cut

sub renderSlidePane {
    my (
        $text,     $title,    $body,        $level,
        $slideNum, $slideMax, $queryParams, $theWeb,
        $theTopic, $hasTopControls
    ) = @_;

    $text = renderSlideContents( $text, $title, $body, $level );
    $text =
      renderNavigation( $text, $slideNum, $slideMax, $queryParams, $theWeb,
        $theTopic );
    $text = renderPageIndicator( $text, $slideNum, $slideMax );

    my $class =
      $hasTopControls
      ? 'slideshowPane slideshowHasTopControls'
      : 'slideshowPane';
    $text = "<div class='$class'>$text</div>";

    return $text;
}

=pod

=cut

sub renderSlideContents {
    my ( $text, $title, $body, $level ) = @_;

    $title ||= '';
    $body  ||= '';

    # comment
    my $slideComment = '';
    if ( $body =~ s/(\-\-\-+\+$level+\!*\s*$commentLabel.*)//is ) {
        $slideComment = $1 if !$hideComments;
    }
    $text =~ s/%SLIDECOMMENT%/$slideComment/go;

    # content
    $text =~ s/%SLIDETITLE%/$title/go;
    $text =~ s/%SLIDETEXT%/$body/go;

    return $text;
}

=pod

=cut

sub renderNavigation {
    my ( $text, $slideNum, $slideMax, $queryParams, $theWeb, $theTopic ) = @_;

    # navigation
    $text =~ s/%SLIDENAV%/renderSlideNav(
		$theWeb, $theTopic, $slideNum, $slideMax, "fpn", $queryParams )/geo;
    $text =~ s/%SLIDENAVALL%/renderSlideNav(
		$theWeb, $theTopic, $slideNum, $slideMax, "flpn", $queryParams )/geo;
    $text =~ s/%SLIDENAVFIRST%/renderSlideNav(
		$theWeb, $theTopic, $slideNum, $slideMax, "f", $queryParams )/geo;
    $text =~ s/%SLIDENAVPREV%/renderSlideNav(
		$theWeb, $theTopic, $slideNum, $slideMax, "p", $queryParams )/geo;
    $text =~ s/%SLIDENAVNEXT%/renderSlideNav(
		$theWeb, $theTopic, $slideNum, $slideMax, "n", $queryParams )/geo;
    $text =~ s/%SLIDENAVLAST%/renderSlideNav(
		$theWeb, $theTopic, $slideNum, $slideMax, "l", $queryParams )/geo;

    return $text;
}

=pod

=cut

sub renderPageIndicator {
    my ( $text, $slideNum, $slideMax ) = @_;

    $text =~ s/%SLIDENUM%/$slideNum/go;
    $text =~ s/%SLIDEMAX%/$slideMax/go;

    return $text;
}

=pod

=cut

sub renderSlideNav {
    my ( $theWeb, $theTopic, $theNum, $theMax, $theButtons, $qstring ) = @_;
    my $prev    = $theNum - 1 || 1;
    my $next    = $theNum + 1;
    my $text    = '';
    my $viewUrl = Foswiki::Func::getViewUrl( $theWeb, $theTopic );

    # format buttons
    $theButtons =~ s/f/%BUTTON_FIRST%/;
    $theButtons =~ s/l/%BUTTON_LAST%/;
    $theButtons =~ s/p/%BUTTON_PREVIOUS%/;
    $theButtons =~ s/n/%BUTTON_NEXT%/;
    $theButtons =~ s/s/%BUTTON_START%/;
    $theButtons =~ s/e/%BUTTON_END%/;

    # f
    $theButtons =~
s/%BUTTON_FIRST%/htmlButton('First', "$viewUrl$qstring#1", 'first.gif', 'First slide')/e;

    # l
    $theButtons =~
s/%BUTTON_LAST%/htmlButton('Last', "$viewUrl$qstring#$theMax", 'last.gif', 'Last slide')/e;

    # p
    $theButtons =~
s/%BUTTON_PREVIOUS%/htmlButton('Previous', "$viewUrl$qstring#$prev", 'prev.gif', 'Previous slide')/e;

    # n
    $theButtons =~
s/%BUTTON_NEXT%/htmlButton('Next', "$viewUrl$qstring#$next", 'next.gif', 'Next slide')/e;

    # s
    $theButtons =~
s/%BUTTON_START%/htmlButton('Start', "$viewUrl$qstring#1", 'startpres.gif', 'Start presentation')/e;

    # e
    my $anchor = 'StartPresentation';
    $theButtons =~
s/%BUTTON_END%/htmlButton('End', "$viewUrl#$theMax", 'endpres.gif', 'End presentation')/e;

    $text .= $theButtons;

    return "<span class='slideshowControls'>$text</span>";
}

=pod

=cut

sub htmlButton {
    my ( $id, $url, $imgName, $label ) = @_;

    my $button = '';
    $button .=
"<a href='$url' class='slideshowControlButton slideshow$id'><img src='$imgRoot/$imgName' border='0' alt='$label' \/><\/a>";

    return $button;
}

sub htmlGlobalNav {
    my ( $web, $topic ) = @_;

    return "<div class='slideshowToolbar'>
	<div class='slideshowToolbarContents'>
		<div class='slideshowFirstLast'>
			<a href='#' class='slideshowBtn slideshowBtnFirst' title='First slide'></a><a href='#' class='slideshowBtn slideshowBtnLast' title='Last slide'></a>
		</div>
		<div class='slideshowPrevNext'>
			<a href='#' class='slideshowBtn slideshowBtnPrevious' title='Previous slide'></a><a href='#' class='slideshowBtn slideshowBtnNext' title='Next slide'></a>
			<div class='slideshowJump'>
				<div class='slideshowJumpInput'>
					<input type='text' class='slideshowJumpInputField' size='4' />
				</div>
				<input type='text' class='slideshowJumpSlideMax' size='6' disabled='disabled' value='/ %SLIDEMAX%' />
			</div>
		</div>
		<a href='%SCRIPTURL{view}%/$web/$topic' class='slideshowBtn slideshowBtnStop' title='Stop slideshow'></a>
	</div>
</div>";
}

=pod

=cut

sub renderSlideToc {
    my ( $theWeb, $theTopic, $params, @theTitles ) = @_;

    my $slideNum = 1;
    my $text     = '';
    my $viewUrl  = Foswiki::Func::getViewUrl( $theWeb, $theTopic );
    foreach (@theTitles) {
        $text .= "\t\* ";
        $text .= "<a href=\"$viewUrl$params#$slideNum\">";
        $text .= " $_ </a>\n";
        $slideNum++;
    }
    return "<div class='slideshowToc'>
$text
</div>";
}

sub readTmplText {
    my ( $theWeb, $theArgs ) = @_;

    my $tmplTopic = Foswiki::Func::extractNameValuePair( $theArgs, "template" );
    unless ($tmplTopic) {
        $theWeb = $installWeb;
        $tmplTopic =
          Foswiki::Func::getPreferencesValue("SLIDESHOWPLUGIN_TEMPLATE")
          || "SlideShowPlugin";
    }
    if ( $tmplTopic =~ /^([^\.]+)\.(.*)$/o ) {
        $theWeb    = $1;
        $tmplTopic = $2;
    }
    my ( $meta, $text ) = Foswiki::Func::readTopic( $theWeb, $tmplTopic );

    # remove everything before %STARTINCLUDE% and after %STOPINCLUDE%
    $text =~ s/.*?%STARTINCLUDE%//os;
    $text =~ s/%STOPINCLUDE%.*//os;

    unless ($text) {
        $text = htmlAlert(
            "$installWeb.SlideShowPlugin Error:",
            "Slide template topic <nop>$theWeb.$tmplTopic not found or empty!"
              . "%SLIDETITLE%\n\n%SLIDETEXT%"
        );
    }
    elsif ( $text =~ /%SLIDETITLE%/ && $text =~ /%SLIDETEXT%/ ) {

        # assume that format is OK
    }
    else {
        $text = htmlAlert(
            "$installWeb.SlideShowPlugin Error:",
            "Missing =%<nop>SLIDETITLE%= or =%<nop>SLIDETEXT%= in "
              . "slide template topic $theWeb.$tmplTopic.\n\n"
              . "%SLIDETITLE%\n\n%SLIDETEXT%"
        );
    }
    $text =~ s/%WEB%/$theWeb/go;
    $text =~ s/%TOPIC%/$tmplTopic/go;
    $text =~ s/%ATTACHURL%/%PUBURL%\/$theWeb\/$tmplTopic/go;
    return $text;
}

sub htmlAlert {
    my ( $alertMessage, $message ) = @_;

    return
"<div class='foswikiNotification'><h2 class='foswikiAlert'> $alertMessage </h2><p> $message </p></div>";

}

=pod

=cut

sub urlEncode {
    my $text = shift;
    $text =~ s/([^0-9a-zA-Z-_.:~!*'()\/%])/'%'.sprintf('%02x',ord($1))/ge;
    $text =~ s/\%20/+/g;
    return $text;
}

=pod

Add CSS and Javascript to head.

=cut

sub _addHeader {

    return if $addedHead;
    my $cssHeader = <<'EOCSS';
<style type='text/css' media='all'>
@import url('%PUBURL%/%SYSTEMWEB%/SlideShowPlugin/slideshow.css');
</style>
EOCSS
    Foswiki::Func::addToZone( 'head', 'SLIDESHOWPLUGIN/css', $cssHeader );

    my $jsHeader = <<'EOJS';
<script type='text/javascript' src='%PUBURL%/%SYSTEMWEB%/SlideShowPlugin/slideshow.js'></script>
EOJS
    Foswiki::Func::addToZone( 'script', 'SLIDESHOWPLUGIN/js', $jsHeader,
        'CYCLE,EASING,CHILI' );

    $addedHead = 1;
}

sub trimSpaces {

    #my $text = $_[0]

    $_[0] =~ s/^[[:space:]]+//s;    # trim at start
    $_[0] =~ s/[[:space:]]+$//s;    # trim at end
}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2002-2007 Peter Thoeny, peter@thoeny.org
Copyright (C) 2008-2010 Eugen Mayer, Arthur Clemens, Foswiki Contributors

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
