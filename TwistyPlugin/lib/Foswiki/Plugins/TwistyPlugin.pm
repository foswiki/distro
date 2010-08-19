# See bottom of file for license and copyright information

=begin TML

---+ package TwistyPlugin

=cut

package Foswiki::Plugins::TwistyPlugin;

use Foswiki::Func ();
use CGI::Cookie   ();
use strict;
use warnings;

use vars qw( @modes $doneHeader $doneDefaults
  $prefMode $prefShowLink $prefHideLink $prefRemember);

our $VERSION = '$Rev$';

our $RELEASE = '1.6.2';
our $SHORTDESCRIPTION =
  'Twisty section Javascript library to open/close content dynamically';
our $NO_PREFS_IN_TOPIC = 1;

my $TWISTYPLUGIN_COOKIE_PREFIX  = "TwistyPlugin_";
my $TWISTYPLUGIN_CONTENT_HIDDEN = 0;
my $TWISTYPLUGIN_CONTENT_SHOWN  = 1;

#there is no need to document this.
sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 1.1 ) {
        Foswiki::Func::writeWarning(
            "Version mismatch between TwistyPlugin and Plugins.pm");
        return 0;
    }

    $doneDefaults = 0;
    $doneHeader   = 0;

    Foswiki::Plugins::JQueryPlugin::registerPlugin( 'twisty',
        'Foswiki::Plugins::TwistyPlugin::TWISTY' );
    Foswiki::Func::registerTagHandler( 'TWISTYSHOW',      \&_TWISTYSHOW );
    Foswiki::Func::registerTagHandler( 'TWISTYHIDE',      \&_TWISTYHIDE );
    Foswiki::Func::registerTagHandler( 'TWISTYBUTTON',    \&_TWISTYBUTTON );
    Foswiki::Func::registerTagHandler( 'TWISTY',          \&_TWISTY );
    Foswiki::Func::registerTagHandler( 'ENDTWISTY',       \&_ENDTWISTYTOGGLE );
    Foswiki::Func::registerTagHandler( 'TWISTYTOGGLE',    \&_TWISTYTOGGLE );
    Foswiki::Func::registerTagHandler( 'ENDTWISTYTOGGLE', \&_ENDTWISTYTOGGLE );

    return 1;
}

sub _setDefaults {
    return if $doneDefaults;
    $doneDefaults = 1;

    $prefMode =
         Foswiki::Func::getPreferencesValue('TWISTYMODE')
      || Foswiki::Func::getPluginPreferencesValue('TWISTYMODE')
      || 'span';
    $prefShowLink =
         Foswiki::Func::getPreferencesValue('TWISTYSHOWLINK')
      || Foswiki::Func::getPluginPreferencesValue('TWISTYSHOWLINK')
      || '%MAKETEXT{"More..."}%';
    $prefHideLink =
         Foswiki::Func::getPreferencesValue('TWISTYHIDELINK')
      || Foswiki::Func::getPluginPreferencesValue('TWISTYHIDELINK')
      || '%MAKETEXT{"Close"}%';
    $prefRemember =
         Foswiki::Func::getPreferencesValue('TWISTYREMEMBER')
      || Foswiki::Func::getPluginPreferencesValue('TWISTYREMEMBER')
      || '';

    return;
}

sub _addHeader {
    return if $doneHeader;
    $doneHeader = 1;

    if ( Foswiki::Func::getContext()->{JQueryPluginEnabled} ) {
        Foswiki::Plugins::JQueryPlugin::createPlugin('twisty');
    }
    else {
        my $header;
        Foswiki::Func::loadTemplate('twistyplugin');

        $header =
            Foswiki::Func::expandTemplate("TwistyPlugin/twisty")
          . Foswiki::Func::expandTemplate("TwistyPlugin/twisty.css");
        Foswiki::Func::expandCommonVariables($header);
    }

    return;
}

sub _TWISTYSHOW {
    my ( $session, $params, $theTopic, $theWeb ) = @_;
    _setDefaults();

    my $mode = $params->{'mode'} || $prefMode;
    my $btn = _twistyBtn( 'show', $session, $params, $theTopic, $theWeb );
    return Foswiki::Func::decodeFormatTokens(
        _wrapInButtonHtml( $btn, $mode ) );
}

sub _TWISTYHIDE {
    my ( $session, $params, $theTopic, $theWeb ) = @_;
    _setDefaults();
    my $mode = $params->{'mode'} || $prefMode;
    my $btn = _twistyBtn( 'hide', $session, $params, $theTopic, $theWeb );
    return Foswiki::Func::decodeFormatTokens(
        _wrapInButtonHtml( $btn, $mode ) );
}

sub _TWISTYBUTTON {
    my ( $session, $params, $theTopic, $theWeb ) = @_;
    _setDefaults();

    my $mode = $params->{'mode'} || $prefMode;
    my $btnShow = _twistyBtn( 'show', $session, $params, $theTopic, $theWeb );
    my $btnHide = _twistyBtn( 'hide', $session, $params, $theTopic, $theWeb );
    my $prefix = $params->{'prefix'} || '';
    my $suffix = $params->{'suffix'} || '';
    my $btn    = $prefix . $btnShow . $btnHide . $suffix;
    return Foswiki::Func::decodeFormatTokens(
        _wrapInButtonHtml( $btn, $mode ) );
}

sub _TWISTY {
    my ( $session, $params, $theTopic, $theWeb ) = @_;

    _addHeader();
    my $id = $params->{'id'};
    if ( !defined $id || $id eq '' ) {
        $params->{'id'} = _createId( $params->{'id'}, $theWeb, $theTopic );
    }
    $params->{'id'} .= int( rand(10000) ) + 1;
    return _TWISTYBUTTON( $session, $params, $theTopic, $theWeb )
      . _TWISTYTOGGLE( $session, $params, $theTopic, $theWeb );
}

sub _TWISTYTOGGLE {
    my ( $session, $params, $theTopic, $theWeb ) = @_;
    my $id = $params->{'id'};
    if ( !defined $id || $id eq '' ) {
        return '';
    }
    _setDefaults();
    my $idTag = $id . 'toggle';
    my $mode = $params->{'mode'} || $prefMode;
    unshift @modes, $mode;

    my $isTrigger = 0;
    my $cookieState = _readCookie( $session, $idTag );
    my @propList =
      _createHtmlProperties( undef, $idTag, $mode, $params, $isTrigger,
        $cookieState );
    my $props = @propList ? " " . join( " ", @propList ) : '';
    my $modeTag = '<' . $mode . $props . '>';
    return Foswiki::Func::decodeFormatTokens(
        _wrapInContentHtmlOpen($mode) . $modeTag );
}

sub _ENDTWISTYTOGGLE {
    my ( $session, $params, $theTopic, $theWeb ) = @_;
    my $mode = shift @modes;

    return
"<span class='foswikiAlert'>woops, ordering error: got an ENDTWISTY before seeing a TWISTY</span>"
      unless $mode;

    my $modeTag = ($mode) ? '</' . $mode . '>' : '';
    return $modeTag . _wrapInContentHtmlClose($mode);
}

sub _createId {
    my ( $inRawId, $inWeb, $inTopic ) = @_;

    my $id;
    if ($inRawId) {
        $id = $inRawId;
    }
    else {
        $id = "$inWeb$inTopic";
    }
    $id =~ s/\//subweb/go;
    return "twistyId$id";
}

sub _twistyBtn {
    my ( $twistyControlState, $session, $params, $theTopic, $theWeb ) = @_;

    _addHeader();

    # not used yet:
    #my $triangle_right = '&#9658;';
    #my $triangle_down = '&#9660;';

    my $id = $params->{'id'};
    if ( !defined $id || $id eq '' ) {
        return '';
    }
    my $idTag;
    if ($twistyControlState) {
        $idTag = $id . $twistyControlState;
    }
    else {
        $idTag = '';
    }

    my $defaultLink =
      ( $twistyControlState eq 'show' ) ? $prefShowLink : $prefHideLink;

    # link="" takes precedence over showlink="" and hidelink=""
    my $link = $params->{'link'};

    if ( !defined $link ) {

        # if 'link' is not set, try 'showlink' / 'hidelink'
        $link = $params->{ $twistyControlState . 'link' };
    }
    if ( !defined $link ) {
        $link = $defaultLink || '';
    }
    my $linkClass = $params->{'linkclass'} ? " $params->{'linkclass'}" : '';
    my $img =
         $params->{ $twistyControlState . 'img' }
      || $params->{'img'}
      || '';
    my $imgright =
         $params->{ $twistyControlState . 'imgright' }
      || $params->{'imgright'}
      || '';
    my $imgleft =
         $params->{ $twistyControlState . 'imgleft' }
      || $params->{'imgleft'}
      || '';
    $img      =~ s/['\"]//go;
    $imgright =~ s/['\"]//go;
    $imgleft  =~ s/['\"]//go;
    my $imgTag =
      ( $img ne '' ) ? '<img src="' . $img . '" border="0" alt="" />' : '';
    my $imgRightTag =
      ( $imgright ne '' )
      ? '<img src="' . $imgright . '" border="0" alt="" />'
      : '';
    my $imgLeftTag =
      ( $imgleft ne '' )
      ? '<img src="' . $imgleft . '" border="0" alt="" />'
      : '';

    my $imgLinkTag =
        '<a href="#">'
      . $imgLeftTag
      . '<span class="foswikiLinkLabel foswikiUnvisited'
      . $linkClass . '">'
      . $link
      . '</span>'
      . $imgTag
      . $imgRightTag . '</a>';

    my $isTrigger = 1;
    my $props     = '';

    if ( $idTag && $params ) {
        my $cookieState = _readCookie( $session, $idTag );
        my @propList =
          _createHtmlProperties( $twistyControlState, $idTag, undef, $params,
            $isTrigger, $cookieState );
        $props = @propList ? " " . join( " ", @propList ) : '';
    }
    my $triggerTag = '<span' . $props . '>' . $imgLinkTag . '</span>';
    return $triggerTag;
}

sub _createHtmlProperties {
    my ( $twistyControlState, $idTag, $mode, $params, $isTrigger, $cookie ) =
      @_;
    my $class      = $params->{'class'}      || '';
    my $firststart = $params->{'firststart'} || '';
    my $firstStartHidden;
    $firstStartHidden = 1 if ( $firststart eq 'hide' );
    my $firstStartShown;
    $firstStartShown = 1 if ( $firststart eq 'show' );
    my $cookieShow;
    $cookieShow = 1 if defined $cookie && $cookie == 1;
    my $cookieHide;
    $cookieHide = 1 if defined $cookie && $cookie == 0;
    my $start = $params->{start} || '';
    my $startHidden;
    $startHidden = 1 if ( $start eq 'hide' );
    my $startShown;
    $startShown = 1 if ( $start eq 'show' );
    my @propList = ();

    _setDefaults();
    my $remember = $params->{'remember'} || $prefRemember;
    my $noscript = $params->{'noscript'} || '';
    my $noscriptHide;
    $noscriptHide = 1 if ( $noscript eq 'hide' );
    $mode ||= $prefMode;

    my @classList = ();
    push( @classList, $class ) if $class && !$isTrigger;
    push( @classList, 'twistyRememberSetting' ) if ( $remember eq 'on' );
    push( @classList, 'twistyForgetSetting' )   if ( $remember eq 'off' );
    push( @classList, 'twistyStartHide' )       if $startHidden;
    push( @classList, 'twistyStartShow' )       if $startShown;
    push( @classList, 'twistyFirstStartHide' )  if $firstStartHidden;
    push( @classList, 'twistyFirstStartShow' )  if $firstStartShown;

    # Mimic the rules in twist.js, function _update()
    my $state = '';
    $state = $TWISTYPLUGIN_CONTENT_HIDDEN if $firstStartHidden;
    $state = $TWISTYPLUGIN_CONTENT_SHOWN  if $firstStartShown;

    # cookie setting may override  firstStartHidden and firstStartShown
    $state = $TWISTYPLUGIN_CONTENT_HIDDEN if $cookieHide;
    $state = $TWISTYPLUGIN_CONTENT_SHOWN  if $cookieShow;

    # startHidden and startShown may override cookie
    $state = $TWISTYPLUGIN_CONTENT_HIDDEN if $startHidden;
    $state = $TWISTYPLUGIN_CONTENT_SHOWN  if $startShown;

    # assume trigger should be hidden
    # unless explicitly said otherwise
    my $shouldHideTrigger = 1;
    if ($isTrigger) {
        push( @classList, 'twistyTrigger foswikiUnvisited' );

        if (   $state eq $TWISTYPLUGIN_CONTENT_SHOWN
            && $twistyControlState eq 'hide' )
        {
            $shouldHideTrigger = 0;
        }
        if (   $state eq $TWISTYPLUGIN_CONTENT_HIDDEN
            && $twistyControlState eq 'show' )
        {
            $shouldHideTrigger = 0;
        }
        push( @classList, 'twistyHidden' ) if $shouldHideTrigger;
    }

    # assume content should be hidden
    # unless explicitly said otherwise
    if ( !$isTrigger ) {
        push( @classList, 'twistyContent' );

        if ( not( $state eq $TWISTYPLUGIN_CONTENT_SHOWN ) ) {
            push( @propList,  'style="display: none;"' );
            push( @classList, 'foswikiMakeHidden' );
        }
    }

    # deprecated
    # should be done by Foswiki template scripts instead
    if ( !$isTrigger && $noscriptHide ) {
        if ( $mode eq 'div' ) {
            push( @classList, 'foswikiMakeVisibleBlock' );
        }
        else {
            push( @classList, 'foswikiMakeVisibleInline' );
        }
    }

    # let javascript know we have set the state already
    push( @classList, 'twistyInited' . $state );

    push( @propList, 'id="' . $idTag . '"' );
    my $classListString = join( " ", @classList );
    push( @propList, 'class="' . $classListString . '"' );
    return @propList;
}

=begin TML

Reads a setting from the FOSWIKIPREF cookie.
Returns:
   * 1 if the cookie has been set (meaning: show content)
   * 0 if the cookie is '0' (meaning: hide content)
   * undef if no cookie has been set

=cut

sub _readCookie {
    my ( $session, $idTag ) = @_;

    return '' if !$idTag;

    # which state do we use?
    my $cgi    = CGI->new();
    my $cookie = $cgi->cookie('FOSWIKIPREF');
    my $tag    = $idTag;
    $tag =~ s/^(.*)(hide|show|toggle)$/$1/go;
    my $key = $TWISTYPLUGIN_COOKIE_PREFIX . $tag;

    return unless ( defined($key) && defined($cookie) );

    my $value = '';
    if ( $cookie =~ m/\b$key\=(.+?)\b/gi ) {
        $value = $1;
    }

    return if $value eq '';
    return ( $value eq '1' ) ? 1 : 0;
}

sub _wrapInButtonHtml {
    my ( $text, $mode ) = @_;
    return _wrapInContainerHideIfNoJavascripOpen($mode) . $text
      . _wrapInContainerDivIfNoJavascripClose($mode);
}

sub _wrapInContentHtmlOpen {
    my ($mode) = @_;
    return "<$mode class=\"twistyPlugin\">";
}

sub _wrapInContentHtmlClose {
    my ($mode) = @_;
    return "</$mode><!--/twistyPlugin-->";
}

sub _wrapInContainerHideIfNoJavascripOpen {
    my ($mode) = @_;
    my $inlineOrBlock = ( $mode eq 'div' ) ? 'Block' : 'Inline';
    return
        '<' 
      . $mode
      . ' class="twistyPlugin foswikiMakeVisible'
      . $inlineOrBlock . '">';
}

sub _wrapInContainerDivIfNoJavascripClose {
    my ($mode) = @_;
    my $inlineOrBlock = ( $mode eq 'div' ) ? 'Block' : 'Inline';
    return
        '</' 
      . $mode
      . '><!--/twistyPlugin foswikiMakeVisible'
      . $inlineOrBlock . '-->';
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) Michael Daum
Copyright (C) Arthur Clemens, arthur@visiblearea.com
Copyright (C) Rafael Alvarez, soronthar@sourceforge.net

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
