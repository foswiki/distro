# See bottom of file for license and copyright information
package Foswiki::Plugins::SlideShowPlugin::SlideShow;

use strict;
use warnings;

use Foswiki::Func ();

sub new {
    my ( $class, $params ) = @_;

    return bless( {}, $class );
}

sub init {
    my ( $this, $args, $web, $topic ) = @_;

    $this->{web}   = $web;
    $this->{topic} = $topic;

    $this->{hideComments} =
      Foswiki::Func::isTrue(
        Foswiki::Func::getPreferencesValue('SLIDESHOWPLUGIN_HIDECOMMENTS')
          || '' );

    $this->{commentLabel} =
      Foswiki::Func::getPreferencesValue('SLIDESHOWPLUGIN_COMMENTS_LABEL')
      || 'Comments';

    $this->{defaultTemplateTopic} =
      Foswiki::Func::getPreferencesValue("SLIDESHOWPLUGIN_TEMPLATE")
      || "SlideShowPlugin";

    my %params = Foswiki::Func::extractParameters($args);
    $this->{params} = \%params;

    my $request = Foswiki::Func::getRequestObject();
    $this->{queryString} = $request->queryString;

    my @params;
    foreach my $name ( $request->param ) {
        next if $name =~ /\b(slideshow|cover)\b/;

        my $key = _urlEncode($name);
        push @params,
          map { $key . "=" . _urlEncode( defined $_ ? $_ : '' ) }
          $request->param($name);
    }

    $this->{queryString} = join( ';', @params );
    $this->{slideTemplate} = $this->readSlideTemplate;

    return $this;
}

sub renderSlideShow {
    my ( $this, $text, $topic, $web ) = @_;

    # parse out slideshow text
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
    $text =~ s/%SLIDESHOW/%<nop>SLIDESHOW/g;

    $this->init( $args, $web, $topic, $text );

    # Make sure we don't end up back in the handler again
    # SMELL: there should be a better block

    my $query = Foswiki::Func::getCgiQuery();
    if ( $query && Foswiki::Func::isTrue( $query->param('slideshow') ) ) {

        # in presentation mode

        # do not write the topic text when in slideshow mode
        $textPre  = '';
        $textPost = '';

        $textPre .= "\n#StartPresentation\n";

        #        $textPre .=
        #          $this->renderSlideNav( 1, 1, "e" );

        my $slideMax = 0;

        if ( $text =~ /(.*?[\n\r])\-\-\-+(\++)\!* (.*)/s ) {
            $textPre .= $1;
            $text = $3;
            my $level = $2;
            $level =~ s/\+/\\\+/go;
            my @slides = split( /[\n\r]\-\-\-+$level\!* /, $text );
            $text = "";

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
                    s/(\-\-\-+\+$level+\!*\s*$this->{commentLabel}.*)//is )
                {
                    $slideComment = $1 unless $this->{hideComments};
                }
                push( @titles, $slideTitle );
                my $isLastClass =
                  ( $slideNum >= $slideMax ) ? ' slideShowLastSlide' : '';
                my $isFirstClass =
                  ( $slideNum == 1 ) ? ' slideShowFirstSlide' : '';
                $slideText = $this->{slideTemplate};
                $slideText =~ s/%SLIDETITLE%/$slideTitle/go;
                $slideText =~ s/%SLIDETEXT%/$slideBody/go;
                $slideText =~ s/%SLIDENUM%/$slideNum/go;
                $slideText =~ s/%SLIDEMAX%/$slideMax/go;
                $slideText =~ s/%SLIDENAV%/$this->renderSlideNav(
                    $slideNum, $slideMax, "fpn" )/geo;
                $slideText =~ s/%SLIDENAVALL%/$this->renderSlideNav(
                    $slideNum, $slideMax, "fpnlx" )/geo;
                $slideText =~ s/%SLIDENAVFIRST%/$this->renderSlideNav(
                    $slideNum, $slideMax, "f" )/geo;
                $slideText =~ s/%SLIDENAVPREV%/$this->renderSlideNav(
                    $slideNum, $slideMax, "p" )/geo;
                $slideText =~ s/%SLIDENAVNEXT%/$this->renderSlideNav(
                    $slideNum, $slideMax, "n" )/geo;
                $slideText =~ s/%SLIDENAVLAST%/$this->renderSlideNav(
                    $slideNum, $slideMax, "l" )/geo;
                $slideText =
"<div class='slideShowPane$isFirstClass$isLastClass' id='GoSlide"
                  . $slideNum
                  . "'>$slideText</div>";
                $text .= "\n#AGoSlide$slideNum\n$slideText";

                $slideComment = $slideComment ? "\n$slideComment\n" : '';
                $text =~ s/%SLIDECOMMENT%/$slideComment/gs;
                $text .= "%BR%\n\n" x 20;
                $slideNum++;
            }
            $text =~ s/%TOC(?:\{.*?\})*%/$this->renderSlideToc( @titles )/geo;
            $text .= "\n#GoSlide$slideNum\n";
        }

        $text = "<div class='slideShow'>\n$textPre\n$text\n";
        $text .= $textPost . "\n</div>\n";

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
          . $this->renderSlideNav( 1, 1, "s" )
          . "\n$text $textPost";
    }

    return $text;
}

sub renderSlideNav {
    my ( $this, $current, $max, $theButtons ) = @_;

    my $prev = $current - 1 || 1;
    my $next = $current + 1;
    $next = $max if $next > $max;

    my $viewUrl = Foswiki::Func::getViewUrl( $this->{web}, $this->{topic} );
    my $queryString = '?' . 'slideshow=on;cover=slideshow';
    $queryString .= ';' . $this->{queryString} if $this->{queryString};

    # format buttons
    $theButtons =~ s/f/%BUTTON_FIRST%/;
    $theButtons =~ s/l/%BUTTON_LAST%/;
    $theButtons =~ s/p/%BUTTON_PREV%/;
    $theButtons =~ s/n/%BUTTON_NEXT%/;
    $theButtons =~ s/s/%BUTTON_START%/;
    $theButtons =~ s/e/%BUTTON_END%/;
    $theButtons =~ s/x/%BUTTON_EXIT%/;

    $theButtons =~ s/%BUTTON_FIRST%/%TMPL:P{"BUTTON_FIRST" %params%}%/g;
    $theButtons =~ s/%BUTTON_LAST%/%TMPL:P{"BUTTON_LAST" %params%}%/g;
    $theButtons =~ s/%BUTTON_PREV%/%TMPL:P{"BUTTON_PREV" %params%}%/g;
    $theButtons =~ s/%BUTTON_NEXT%/%TMPL:P{"BUTTON_NEXT" %params%}%/g;
    $theButtons =~ s/%BUTTON_EXIT%/%TMPL:P{"BUTTON_EXIT" %params%}%/g;
    $theButtons =~ s/%BUTTON_EXIT%/%TMPL:P{"BUTTON_EXIT" %params%}%/g;
    $theButtons =~
s/%BUTTON_START%/%BUTTON{"%MAKETEXT{"Start presentation"}%" class="slideShowStart" href="$viewUrl$queryString#GoSlide1" icon="image"}%/g;

    $theButtons =~
s/%params%/max="$max" next="$next" prev="$prev" viewurl="$viewUrl" querystring="$queryString"/g;

    print STDERR "theButtons=$theButtons\n";

    my $text = "<span class='slideShowControls'>";
    $text .= $theButtons;
    $text .= '</span>';
    return $text;
}

sub renderSlideToc {
    my ( $this, $params, @theTitles ) = @_;

    my $slideNum = 1;
    my $text     = '';
    my $viewUrl  = Foswiki::Func::getViewUrl( $this->{web}, $this->{topic} );
    foreach (@theTitles) {
        $text .= "\t\* ";
        $text .= "<a href=\"$viewUrl$params#GoSlide$slideNum\">";
        $text .= " $_ </a>\n";
        $slideNum++;
    }
    return $text;
}

sub readSlideTemplate {
    my $this = shift;

    my ( $web, $topic ) = Foswiki::Func::normalizeWebTopicName( $this->{web},
        $this->{params}{template} || $this->{defaultTemplateTopic} );

    my ( $meta, $text ) = Foswiki::Func::readTopic( $web, $topic );

    # remove everything before %STARTINCLUDE% and after %STOPINCLUDE%
    unless ($text) {
        return _htmlAlert( "%SYSTEMWEB%.SlideShowPlugin Error:",
            "Slide template topic <nop>$web.$topic not found or empty!" );
    }

    $text =~ s/.*?%STARTINCLUDE%//s;
    $text =~ s/%STOPINCLUDE%.*//s;

    unless ( $text =~ /%SLIDETITLE%/ && $text =~ /%SLIDETEXT%/ ) {
        return _htmlAlert(
            "%SYSTEMWEB%.SlideShowPlugin Error:",
            "Missing =%<nop>SLIDETITLE%= or =%<nop>SLIDETEXT%= in "
              . "slide template topic [[$web.$topic]].\n\n"
        );
    }

    # SMELL: these override system vars..sort of reproduces INCLUDE
    $text =~ s/%WEB%/$web/go;
    $text =~ s/%TOPIC%/$topic/go;
    $text =~ s/%ATTACHURL%/%PUBURL%\/$web\/$topic/go;

    return $text;
}

sub _htmlAlert {
    my ( $alertMessage, $message ) = @_;

    return
"<div class='foswikiNotification'><h2 class='foswikiAlert'> $alertMessage </h2><p> $message </p></div>";

}

sub _urlEncode {
    my $text = shift;
    $text =~ s/([^0-9a-zA-Z-_.:~!*'()\/%])/'%'.sprintf('%02x',ord($1))/ge;
    $text =~ s/\%20/+/g;
    return $text;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2014 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2002-2007 Peter Thoeny, peter@thoeny.org
Copyright (C) 2008-2009 Eugen Mayer, Arthur Clemens, Foswiki Contributors

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
