# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/
# 
# Copyright (C) 2006-2010 Michael Daum, http://michaeldaumconsulting.com
# 
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. 
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html

package Foswiki::Plugins::JQueryPlugin::TOGGLE;
use strict;
use warnings;
use Foswiki::Plugins::JQueryPlugin::Plugin;
our @ISA = qw( Foswiki::Plugins::JQueryPlugin::Plugin );

=begin TML

---+ package Foswiki::Plugins::JQueryPlugin::TOGGLE

This is the perl stub for the jquery.toggle plugin.

=cut

=begin TML

---++ ClassMethod new( $class, $session, ... )

Constructor

=cut

sub new {
  my $class = shift;
  my $session = shift || $Foswiki::Plugins::SESSION;

  my $this = bless($class->SUPER::new( 
    $session,
    name => 'Toggle',
    version => '0.6',
    author => 'Michael Daum',
    homepage => 'http://michaeldaumconsulting.com',
    tags => 'TOGGLE',
    javascript => ['jquery.toggle.init.js'],
  ), $class);

  return $this;
}

=begin TML

---++ ClassMethod handleToggle( $this, $params, $topic, $web ) -> $result

Tag handler for =%<nop>TOGGLE%=. 

=cut

sub handleToggle {
  my ($this, $params, $theTopic, $theWeb) = @_;

  my $theText = $params->{_DEFAULT} || $params->{text} || 'Button';
  my $theBackground = $params->{bg};
  my $theForeground = $params->{fg};
  my $theStyle = $params->{style};
  my $theTitle = $params->{title} || '';
  my $theTarget = $params->{target};
  my $theEffect = $params->{effect} || 'toggle';

  my $style = '';
  $style .= "background-color:$theBackground;" if $theBackground;
  $style .= "color:$theForeground;" if $theForeground;
  $style .= $theStyle if $theStyle;
  $style = "style='$style'" if $style;

  my $showEffect;
  my $hideEffect;
  if ($theEffect eq 'fade') {
    $showEffect = $hideEffect = "animate({height:'toggle', opacity:'toggle'},'fast')";
  } elsif ($theEffect eq 'slide') {
    $showEffect = $hideEffect = "slideToggle('fast')";
  } elsif ($theEffect eq 'ease') {
    $showEffect = $hideEffect = "slideToggle({duration:400, easing:'easeInOutQuad'})";
  } elsif ($theEffect eq 'elastic') {
    $showEffect = "slideToggle({duration:300, easing:'easeInQuad'})";
    $hideEffect = "slideToggle({duration:1000, easing:'easeOutElastic'})";
  } elsif ($theEffect eq 'bounce') {
    $showEffect = "slideUp({ duration:300, easing:'easeInQuad'})";
    $hideEffect = "slideDown({ duration:500, easing:'easeOutBounce'})";
  } else {
    $showEffect = $hideEffect = "toggle()";
  }
  my $cmd = "function() {\$('$theTarget').each(function() {\$(this).is(':visible')?\$(this).$showEffect:\$(this).$hideEffect;});return false;}";
  my $toggleId = "jqToggle".Foswiki::Plugins::JQueryPlugin::Plugins::getRandom();

  Foswiki::Func::addToZone("head", "JQUERYPLUGIN::TOGGLE::$toggleId", <<"HERE", 'JQUERYPLUGIN::TOGGLE');
<meta name="foswiki.jquery.toggle.$toggleId" content="{id:'$toggleId', onclick:$cmd}" />
HERE

  return
   "<a id='$toggleId' href='#' title='".$theTitle."' ".$style.'>'.
   "<span>".
   Foswiki::Plugins::JQueryPlugin::Plugins::expandVariables($theText).'</span></a>';
}


1;


