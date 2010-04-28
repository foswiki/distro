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

package Foswiki::Plugins::JQueryPlugin::FOSWIKI;
use strict;
use warnings;
use Foswiki::Func;
use Foswiki::Plugins::JQueryPlugin::Plugin;
our @ISA = qw( Foswiki::Plugins::JQueryPlugin::Plugin );

=begin TML

---+ package Foswiki::Plugins::JQueryPlugin::FOSWIKI

This is the perl stub for the jquery.foswiki plugin.

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
    name => 'Foswiki',
    version => '2.00',
    author => 'Michael Daum',
    homepage => 'http://foswiki.org/Extensions/JQueryPlugin',
    tags=>'JQTHEME, JQREQUIRE, JQICON, JQICONPATH, JQPLUGINS',
  ), $class);

  return $this;
}

=begin TML

---++ ClassMethod init( $this )

Initialize this plugin by adding the required static files to the html header

=cut


sub init {
  my $this = shift;

  return unless $this->SUPER::init();

  my $header= <<'HERE';

<meta name="foswiki.web" content="%WEB%" />
<meta name="foswiki.topic" content="%TOPIC%" />
<meta name="foswiki.scriptUrl" content="%SCRIPTURL%" />
<meta name="foswiki.scriptSuffix" content="%SCRIPTSUFFIX%" />
<meta name="foswiki.scriptUrlPath" content="%SCRIPTURLPATH%" />
<meta name="foswiki.pubUrl" content="%PUBURL%" />
<meta name="foswiki.pubUrlPath" content="%PUBURLPATH%" />
<meta name="foswiki.systemWebName" content="%SYSTEMWEB%" />
<meta name="foswiki.usersWebName" content="%USERSWEB%" />
<meta name="foswiki.wikiName" content="%WIKINAME%" />
<meta name="foswiki.loginName" content="%USERNAME%" />
<meta name="foswiki.wikiUserName" content="%WIKIUSERNAME%" />
<meta name="foswiki.serverTime" content="%SERVERTIME%" />
<meta name="foswiki.ImagePluginEnabled" content="%IF{"context ImagePluginEnabled" then="true" else="false"}%" />
<meta name="foswiki.MathModePluginEnabled" content="%IF{"context MathModePluginEnabled" then="true" else="false"}%" />
HERE

  my $js = 'jquery.foswiki';
  $js .= '.uncompressed' if $this->{debug};
  $js .= '.js?version='.$this->{version};

  my $footer = "<script src='%PUBURLPATH%/%SYSTEMWEB%/JQueryPlugin/plugins/foswiki/$js'></script>\n";

  Foswiki::Func::addToZone('head', 'JQUERYPLUGIN::FOSWIKI', $header, 'JQUERYPLUGIN');
  Foswiki::Func::addToZone('body', 'JQUERYPLUGIN::FOSWIKI', $footer, 'JQUERYPLUGIN');

}

1;
