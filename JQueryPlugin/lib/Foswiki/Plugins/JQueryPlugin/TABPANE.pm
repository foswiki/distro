# See bottom of file for license and copyright information
package Foswiki::Plugins::JQueryPlugin::TABPANE;
use strict;
use warnings;

use Foswiki::Func                          ();
use Foswiki::Plugins::JQueryPlugin::Plugin ();
our @ISA = qw( Foswiki::Plugins::JQueryPlugin::Plugin );

=begin TML

---+ package Foswiki::Plugins::JQueryPlugin::TABPABNE

This is the perl stub for the jquery.tabpane plugin.

=cut

=begin TML

---++ ClassMethod new( $class, ... )

Constructor

=cut

sub new {
    my $class = shift;

    my $this = bless(
        $class->SUPER::new(
            name         => 'Tabpane',
            version      => '2.00',
            author       => 'Michael Daum',
            homepage     => 'http://foswiki.org/Extensions/JQueryPlugin',
            tags         => 'TABPABNE, ENDTABPANE, TAB, ENDTAB',
            css          => ['jquery.tabpane.css'],
            javascript   => ['jquery.tabpane.js'],
            dependencies => [ 'livequery', 'easing' ],
        ),
        $class
    );

    return $this;
}

=begin TML

---++ ClassMethod handleTabPane( $this, $params, $topic, $web ) -> $result

Tag handler for =%<nop>TABPANE%=. 

=cut

sub handleTabPane {
    my ( $this, $params, $theTopic, $theWeb ) = @_;

    my $select        = $params->{select}        || 1;
    my $autoMaxExpand = $params->{automaxexpand} || 'off';
    my $minHeight     = $params->{minheight}     || 230;
    my $animate       = $params->{animate}       || 'off';
    my $class         = $params->{class}         || 'jqTabPaneDefault';

    $class =~ s/\b([a-z]+)\b/'jqTabPane'.ucfirst($1)/ge;

    $autoMaxExpand = ( $autoMaxExpand eq 'on' ) ? 'true' : 'false';
    $animate       = ( $animate       eq 'on' ) ? 'true' : 'false';

    if ( Foswiki::Func::getContext()->{static} ) {
        $class .= " jqInitedTabpane jqStatic";
    }

    return
"<div class='jqTabPane $class' data-select='$select' data-auto-max-expand='$autoMaxExpand' data-animate='$animate' data-min-height='$minHeight'>";
}

=begin TML

---++ ClassMethod handleTab( $this, $params, $topic, $web ) -> $result

Tag handler for =%<nop>TAB%=. 

=cut

sub handleTab {
    my ( $this, $params, $theTopic, $theWeb ) = @_;

    my $theName          = $params->{_DEFAULT}  || $params->{name} || 'Tab';
    my $beforeHandler    = $params->{before}    || '';
    my $afterHandler     = $params->{after}     || '';
    my $afterLoadHandler = $params->{afterload} || '';
    my $url              = $params->{url}       || '';
    my $container        = $params->{container} || '';
    my $tabClass         = $params->{id}        || '';
    my $height           = $params->{height};
    my $width            = $params->{width};

    my $rand  = Foswiki::Plugins::JQueryPlugin::Plugins::getRandom();
    my $tabId = "jqTab$rand";

    my @callbacks = ();
    my @html5Data = ();

    if ($beforeHandler) {
        my $fnName = "beforeHandler$rand";
        push @callbacks,
          "function $fnName(oldTabId, newTabId) {$beforeHandler}";
        push @html5Data, "data-before-handler=\"$fnName\"";
    }
    if ($afterHandler) {
        my $fnName = "afterHandler$rand";
        push @callbacks, "function $fnName(oldTabId, newTabId) {$afterHandler}";
        push @html5Data, "data-after-handler=\"$fnName\"";
    }
    if ($afterLoadHandler) {
        my $fnName = "afterLoadHandler$rand";
        push @callbacks,
          "function $fnName(oldTabId, newTabId) {$afterLoadHandler}";
        push @html5Data, "data-after-load-handler=\"$fnName\"";
    }

    if ($container) {
        push @html5Data, "data-container=\"$container\"";
    }
    if ($url) {
        push @html5Data, "data-url=\"$url\"";
        $tabClass .= ' jqAjaxTab';
    }
    my $html5Data = scalar(@html5Data) ? ' ' . join( ' ', @html5Data ) : '';

    my $style = '';
    $style .= "height:$height;" if defined $height;
    $style .= "width:$width;"   if defined $width;
    $style = "style='$style'" if $style;

    return
        "<literal><script type='text/javascript'>"
      . ( join( "\n", @callbacks ) )
      . "</script></literal>\n"
      . "<div id='$tabId' class='$tabClass jqTab'$html5Data style='display:none'>\n<h2 class='jqTabLabel'>$theName</h2>\n<div class='jqTabContents' $style>";
}

=begin TML

---++ ClassMethod handleEndTab( $this, $params, $topic, $web ) -> $result

Tag handler for =%<nop>ENDTAB%=. 

=cut

sub handleEndTab {
    return "</div></div><!-- //ENDTAB -->";
}

=begin TML

---++ ClassMethod handleEndTabPan ( $this, $params, $topic, $web ) -> $result

Tag handler for =%<nop>ENDTABPANE%=. 

=cut

sub handleEndTabPane {
    return "</div><!-- //ENDTABPANE -->";
}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2010-2016 Foswiki Contributors. Foswiki Contributors
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
