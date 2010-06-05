# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2002-2007 Peter Thoeny, peter@thoeny.org
# Copyright (C) 2008-2009 Eugen Mayer, Arthur Clemens, Foswiki Contributors
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html
#
# As per the GPL, removal of this notice is prohibited.

use strict;
use warnings;
use Foswiki::Func;

package Foswiki::Plugins::SlideShowPlugin::SlideShow;

use vars qw( $imgRoot $installWeb );

sub init {
    $installWeb = shift;
    $imgRoot    = '%PUBURLPATH%/' . $installWeb . '/SlideShowPlugin';
}

sub handler {
    my ( $text, $theTopic, $theWeb ) = @_;

    my $textPre  = "";
    my $textPost = "";
    my $args     = "";
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
    my $queryParams = '?slideshow=on;cover=slideshow';
    foreach my $name ( $query->param ) {
        next
          if ( $name =~ /(text|keywords|web|topic|slideshow|skin|cover|\#)/ );
        $queryParams .= ';' . $name . '=' . urlEncode( $query->param($name) );
    }

    if ( $query && $query->param('slideshow') ) {

        # in presentation mode

        # do not write the topic text when in slideshow mode
        $textPre  = '';
        $textPost = '';

        $textPre .= "\n#StartPresentation\n";
        $textPre .=
          renderSlideNav( $theWeb, $theTopic, 1, 1, "e", $queryParams );

        my $slideMax = 0;

        if ( $text =~ /(.*?[\n\r])\-\-\-+(\++)\!* (.*)/s ) {
            $textPre .= $1;
            $text = $3;
            my $level = $2;
            $level =~ s/\+/\\\+/go;
            my @slides = split( /[\n\r]\-\-\-+$level\!* /, $text );
            $text = "";

            my $hideComments = Foswiki::Func::isTrue(
                Foswiki::Func::getPreferencesValue(
                    'SLIDESHOWPLUGIN_HIDECOMMENTS')
                  || ''
            );

            my $commentLabel = Foswiki::Func::getPreferencesValue(
                'SLIDESHOWPLUGIN_COMMENTS_LABEL')
              || 'Comments';

            my $tmplText     = readTmplText( $theWeb, $args );
            my $slideText    = "";
            my $slideTitle   = "";
            my $slideBody    = "";
            my $slideComment = "";
            my $slideNum     = 1;
            $slideMax = @slides;
            my @titles = ();
            foreach (@slides) {
                next unless /^([^\n\r]*)(.*)$/s;
                $slideTitle = $1 || '';
                $slideBody  = $2 || '';
                $slideComment = '';
                if ( $slideBody =~
                    s/(\-\-\-+\+$level+\!*\s*$commentLabel.*)//is )
                {
                    $slideComment = $1 if !$hideComments;
                }
                push( @titles, $slideTitle );
                $slideText = $tmplText;
                $slideText =~ s/%SLIDETITLE%/$slideTitle/go;
                $slideText =~ s/%SLIDETEXT%/$slideBody/go;
                $slideText =~ s/%SLIDENUM%/$slideNum/go;
                $slideText =~ s/%SLIDEMAX%/$slideMax/go;
                $slideText =~ s/%SLIDENAV%/renderSlideNav(
                    $theWeb, $theTopic, $slideNum, $slideMax, "fpn", $queryParams )/geo;
                $slideText =~ s/%SLIDENAVALL%/renderSlideNav(
                    $theWeb, $theTopic, $slideNum, $slideMax, "flpn", $queryParams )/geo;
                $slideText =~ s/%SLIDENAVFIRST%/renderSlideNav(
                    $theWeb, $theTopic, $slideNum, $slideMax, "f", $queryParams )/geo;
                $slideText =~ s/%SLIDENAVPREV%/renderSlideNav(
                    $theWeb, $theTopic, $slideNum, $slideMax, "p", $queryParams )/geo;
                $slideText =~ s/%SLIDENAVNEXT%/renderSlideNav(
                    $theWeb, $theTopic, $slideNum, $slideMax, "n", $queryParams )/geo;
                $slideText =~ s/%SLIDENAVLAST%/renderSlideNav(
                    $theWeb, $theTopic, $slideNum, $slideMax, "l", $queryParams )/geo;
                $slideText =
                    "<div class='slideshowPane' id='GoSlide"
                  . $slideNum
                  . "'>$slideText</div>";
                $text .= "\n#AGoSlide$slideNum\n$slideText";

                $slideComment = $slideComment ? "\n$slideComment\n" : '';
                $text =~ s/%SLIDECOMMENT%/$slideComment/gs;

                $slideNum++;
            }
            $text =~
s/%TOC(?:\{.*?\})*%/renderSlideToc( $theWeb, $theTopic, $queryParams, @titles )/geo;
            $text .= "\n#GoSlide$slideNum\n";
        }

        $text = "$textPre\n$text\n";
        $text .= renderSlideNav( $theWeb, $theTopic, $slideMax + 1,
            $slideMax, "f p e", $queryParams );
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

sub renderSlideNav {
    my ( $theWeb, $theTopic, $theNum, $theMax, $theButtons, $qstring ) = @_;
    my $prev    = $theNum - 1 || 1;
    my $next    = $theNum + 1;
    my $text    = "<span class='slideshowControls'>";
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
s/%BUTTON_FIRST%/htmlButton('First', "$viewUrl$qstring#GoSlide1", 'first.gif', 'First slide')/e;

    # l
    $theButtons =~
s/%BUTTON_LAST%/htmlButton('Last', "$viewUrl$qstring#GoSlide$theMax", 'last.gif', 'Last slide')/e;

    # p
    $theButtons =~
s/%BUTTON_PREVIOUS%/htmlButton('Previous', "$viewUrl$qstring#GoSlide$prev", 'prev.gif', 'Previous slide')/e;

    # n
    $theButtons =~
s/%BUTTON_NEXT%/htmlButton('Next', "$viewUrl$qstring#GoSlide$next", 'next.gif', 'Next slide')/e;

    # s
    $theButtons =~
s/%BUTTON_START%/htmlButton('Start', "$viewUrl$qstring#GoSlide1", 'startpres.gif', 'Start presentation')/e;

    # e
    my $anchor = 'StartPresentation';
    $theButtons =~
s/%BUTTON_END%/htmlButton('End', "$viewUrl#$anchor", 'endpres.gif', 'End presentation')/e;

    $text .= $theButtons;

    $text .= '</span>';
    return $text;
}

sub htmlButton {
    my ( $id, $url, $imgName, $label ) = @_;

    my $button = '';
    $button .=
"<a href='$url' class='slideshowControlButton slideshow$id'><img src='$imgRoot/$imgName' border='0' alt='$label' \/><\/a>";

    return $button;
}

sub renderSlideToc {
    my ( $theWeb, $theTopic, $params, @theTitles ) = @_;

    my $slideNum = 1;
    my $text     = '';
    my $viewUrl  = Foswiki::Func::getViewUrl( $theWeb, $theTopic );
    foreach (@theTitles) {
        $text .= "\t\* ";
        $text .= "<a href=\"$viewUrl$params#GoSlide$slideNum\">";
        $text .= " $_ </a>\n";
        $slideNum++;
    }
    return $text;
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

sub urlEncode {
    my $text = shift;
    $text =~ s/([^0-9a-zA-Z-_.:~!*'()\/%])/'%'.sprintf('%02x',ord($1))/ge;
    $text =~ s/\%20/+/g;
    return $text;
}

1;
