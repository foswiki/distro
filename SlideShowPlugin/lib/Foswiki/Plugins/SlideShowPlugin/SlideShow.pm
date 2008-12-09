# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2002-2007 Peter Thoeny, peter@thoeny.org
# Copyright (C) 2008 Foswiki Contributors
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
use Foswiki::Func;

package Foswiki::Plugins::SlideShowPlugin::SlideShow;

use vars qw( $imgRoot $installWeb );

# =========================
sub init
{
    $installWeb = shift;
    $imgRoot = '%PUBURLPATH%/'.$installWeb.'/SlideShowPlugin';
}

# =========================
sub handler
{
    my( $text, $theTopic, $theWeb ) = @_;

    my $textPre = "";
    my $textPost = "";
    my $args = "";
    if( $text =~ /^(.*)%SLIDESHOWSTART%(.*)$/s ) {
        $textPre = $1;
        $text = $2;
    } elsif( $text =~ /^(.*)%SLIDESHOWSTART{(.*?)}%(.*)$/s ) {
        $textPre = $1;
        $args = $2;
        $text = $3;
    }
    if( $text =~ /^(.*)%SLIDESHOWEND%(.*)$/s ) {
        $text = $1;
        $textPost = $2;
    }

    # Make sure we don't end up back in the handler again
    # SMELL: there should be a better block
    $text =~ s/%SLIDESHOW/%<nop>SLIDESHOW/g;

    my $query = Foswiki::Func::getCgiQuery();

    # Build query string based on existingURL parameters
    my $qparams = '?slideshow=on;skin=print';
    foreach my $name ( $query->param ) {
        next if ( $name =~ /(text|keywords|web|topic|slideshow|skin|\#)/ );
        $qparams .= ';' . $name . '=' . urlEncode( $query->param($name) );
    }

    if( $query && $query->param( 'slideshow' ) ) {
        # in presentation mode

        $textPre .= "\n#StartPresentation\n";
        $textPre .= renderSlideNav( $theWeb, $theTopic, 1, 1, "e", $qparams );

        my $slideMax = 0;

        if( $text =~ /(.*?[\n\r])\-\-\-+(\++)\!* (.*)/s ) {
            $textPre .= $1;
            $text = $3;
            my $level = $2;
            $level =~ s/\+/\\\+/go;
            my @slides = split( /[\n\r]\-\-\-+$level\!* /, $text );
            $text = "";

            my $hideComments = Foswiki::Func::getPreferencesValue( 'SLIDESHOWPLUGIN_HIDECOMMENTS' ) || '';

            my $tmplText = readTmplText( $theWeb, $args );
            my $slideText = "";
            my $slideTitle = "";
            my $slideBody = "";
            my $slideComment = "";
            my $slideNum = 1;
            $slideMax = @slides;
            my @titles = ();
            foreach( @slides ) {
                next unless /^([^\n\r]*)(.*)$/s;
                $slideTitle = $1 || '';
                $slideBody  = $2 || '';
                $slideComment = '';
                if( $hideComments && $slideBody =~ s/(\-\-\-+\+$level+\!*\s*Comments.*)//is ) {
                    $slideComment = $1;
                }
                push( @titles, $slideTitle );
                $slideText = $tmplText;
                $slideText =~ s/%SLIDETITLE%/$slideTitle/go;
                $slideText =~ s/%SLIDETEXT%/$slideBody/go;
                $slideText =~ s/%SLIDENUM%/$slideNum/go;
                $slideText =~ s/%SLIDEMAX%/$slideMax/go;
                $slideText =~ s/%SLIDENAV%/renderSlideNav(
                    $theWeb, $theTopic, $slideNum, $slideMax, "f p n", $qparams )/geo;
                $slideText =~ s/%SLIDENAVALL%/renderSlideNav(
                    $theWeb, $theTopic, $slideNum, $slideMax, "f p n l", $qparams )/geo;
                $slideText =~ s/%SLIDENAVFIRST%/renderSlideNav(
                    $theWeb, $theTopic, $slideNum, $slideMax, "f", $qparams )/geo;
                $slideText =~ s/%SLIDENAVPREV%/renderSlideNav(
                    $theWeb, $theTopic, $slideNum, $slideMax, "p", $qparams )/geo;
                $slideText =~ s/%SLIDENAVNEXT%/renderSlideNav(
                    $theWeb, $theTopic, $slideNum, $slideMax, "n", $qparams )/geo;
                $slideText =~ s/%SLIDENAVLAST%/renderSlideNav(
                    $theWeb, $theTopic, $slideNum, $slideMax, "l", $qparams )/geo;
                $text .= "\n\n-----\n#GoSlide$slideNum\n$slideText";
                unless( $text =~ s/%SLIDECOMMENT%/\n$slideComment\n/go ) {
                    $text .= "\n$slideComment\n\n" if( $slideComment );
                }
                $text .= "%BR%\n\n" x 20;
                $slideNum++;
            }
            $text =~ s/%TOC(?:\{.*?\})*%/renderSlideToc( $theWeb, $theTopic, @titles )/geo;
            $text .= "\n#GoSlide$slideNum\n%BR%\n";
        }

        $text = "$textPre\n$text\n";
        $text .= renderSlideNav( $theWeb, $theTopic, $slideMax + 1, $slideMax, "f p e", $qparams );
        $text .= "\n";
        $text .= "%BR%\n\n" x 30;
        $text =~ s/%BR%/<br \/>/go;
        $text .= $textPost;

    } else {
        # in normal topic view mode
        if( $text =~ /[\n\r]\-\-\-+(\++)/s ) {
            my $level = $1;
            $level =~ s/\+/\\\+/go;
            # add slide number to heading
            my $slideNum = 1;
            $text =~ s/([\n\r]\-\-\-+$level\!*) ([^\n\r]+)/"$1 Slide " . $slideNum++ . ": $2"/ges;
        }
        $text = "$textPre \n#StartPresentation\n"
              . renderSlideNav( $theWeb, $theTopic, 1, 1, "s", $qparams )
              . "\n$text $textPost";
    }

    return $text;
}

# =========================
sub renderSlideNav
{
    my( $theWeb, $theTopic, $theNum, $theMax, $theButtons, $qstring ) = @_;
    my $prev = $theNum - 1 || 1;
    my $next = $theNum + 1;
    my $text = '<span style="white-space: nowrap">';
    my $viewUrl = Foswiki::Func::getViewUrl($theWeb, $theTopic);
    if( $theButtons =~ /f/ ) {
        # first slide button
        if( $theButtons =~ / f/ ) {
            $text .= "&nbsp;";
        }
        $text .= "<a href=\"$viewUrl$qstring#GoSlide1\">"
               . "<img src=\"$imgRoot/first.gif\" border=\"0\""
               . " alt=\"First slide\" /></a>";
    }
    if( $theButtons =~ /p/ ) {
        # previous slide button
        if( $theButtons =~ / p/ ) {
            $text .= "&nbsp;";
        }
        $text .= "<a href=\"$viewUrl$qstring#GoSlide$prev\">"
               . "<img src=\"$imgRoot/prev.gif\" border=\"0\""
               . " alt=\"Previous\" /></a>";
    }
    if( $theButtons =~ /n/ ) {
        # next slide button
        if( $theButtons =~ / n/ ) {
            $text .= "&nbsp;";
        }
        $text .= "<a href=\"$viewUrl$qstring#GoSlide$next\">"
               . "<img src=\"$imgRoot/next.gif\" border=\"0\""
               . " alt=\"Next\" /></a>";
    }
    if( $theButtons =~ /l/ ) {
        # last slide button
        if( $theButtons =~ / l/ ) {
            $text .= "&nbsp;";
        }
        $text .= "<a href=\"$viewUrl$qstring#GoSlide$theMax\">"
               . "<img src=\"$imgRoot/last.gif\" border=\"0\""
               . " alt=\"Last slide\" /></a>";
    }
    if( $theButtons =~ /e/ ) {
        # end slideshow button
        if( $theButtons =~ / e/ ) {
            $text .= "&nbsp;";
        }
        $text .= "<a href=\"$viewUrl\">"
               . "<img src=\"$imgRoot/endpres.gif\" border=\"0\""
               . " alt=\"End Presentation\" /></a>";
    }
    if( $theButtons =~ /s/ ) {
        # start slideshow button
        if( $theButtons =~ / s/ ) {
            $text .= "&nbsp;";
        }
        $text .= "<a href=\"$viewUrl$qstring#GoSlide1\">"
               . "<img src=\"$imgRoot/startpres.gif\" border=\"0\""
               . " alt=\"Start Presentation\" /></a>";
    }
    $text .= '</span>';
    return $text;
}

# =========================
sub renderSlideToc
{
    my( $theWeb, $theTopic, @theTitles ) = @_;

    my $slideNum = 1;
    my $text = '';
    my $viewUrl = Foswiki::Func::getViewUrl($theWeb, $theTopic);
    foreach( @theTitles ) {
        $text .= "\t\* ";
        $text .= "<a href=\"$viewUrl?slideshow=on&amp;skin=print#GoSlide$slideNum\">";
        $text .= " $_ </a>\n";
        $slideNum++;
    }
    return $text;
}

# =========================
sub readTmplText
{
    my( $theWeb, $theArgs ) = @_;

    my $tmplTopic =  Foswiki::Func::extractNameValuePair( $theArgs, "template" );
    unless( $tmplTopic ) {
        $theWeb = $installWeb;
        $tmplTopic =  Foswiki::Func::getPreferencesValue( "SLIDESHOWPLUGIN_TEMPLATE" )
                   || "SlideShowPlugin";
    }
    if( $tmplTopic =~ /^([^\.]+)\.(.*)$/o ) {
        $theWeb = $1;
        $tmplTopic = $2;
    }
    my( $meta, $text ) = Foswiki::Func::readTopic( $theWeb, $tmplTopic );
    # remove everything before %STARTINCLUDE% and after %STOPINCLUDE%
    $text =~ s/.*?%STARTINCLUDE%//os;
    $text =~ s/%STOPINCLUDE%.*//os;

    unless( $text ) {
        $text = "<font color=\"red\"> $installWeb.SlideShowPlugin Error: </font>"
              . "Slide template topic <nop>$theWeb.$tmplTopic not found or empty!\n\n"
              . "%SLIDETITLE%\n\n%SLIDETEXT%\n\n";
    } elsif( $text =~ /%SLIDETITLE%/ && $text =~ /%SLIDETEXT%/ ) {
        # assume that format is OK
    } else {
        $text = "<font color=\"red\"> $installWeb.SlideShowPlugin Error: </font>"
              . "Missing =%<nop>SLIDETITLE%= or =%<nop>SLIDETEXT%= in "
              . "slide template topic $theWeb.$tmplTopic.\n\n"
              . "%SLIDETITLE%\n\n%SLIDETEXT%\n\n";
    }
    $text =~ s/%WEB%/$theWeb/go;
    $text =~ s/%TOPIC%/$tmplTopic/go;
    $text =~ s/%ATTACHURL%/%PUBURL%\/$theWeb\/$tmplTopic/go;
    return $text;
}

# =========================
sub urlEncode
{
    my $text = shift;
    $text =~ s/([^0-9a-zA-Z-_.:~!*'()\/%])/'%'.sprintf('%02x',ord($1))/ge;
    $text =~ s/\%20/+/g;
    return $text;
}

1;
