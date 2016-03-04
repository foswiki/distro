# See bottom of file for license and copyright information
package Foswiki::Plugins::JQueryPlugin::BUTTON;
use strict;
use warnings;
use Foswiki::Plugins::JQueryPlugin::Plugin;
our @ISA = qw( Foswiki::Plugins::JQueryPlugin::Plugin );

=begin TML

---+ package Foswiki::Plugins::JQueryPlugin::BUTTON

This is the perl stub for the jquery.button plugin.

=cut

=begin TML

---++ ClassMethod new( $class, ... )

Constructor

=cut

sub new {
    my $class = shift;

    my $this = bless(
        $class->SUPER::new(
            name         => 'Button',
            version      => '2.0',
            author       => 'Michael Daum',
            homepage     => 'http://foswiki.org/Extensions/JQueryPlugin',
            tags         => 'BUTTON',
            css          => ['jquery.button.css'],
            javascript   => ['jquery.button.init.js'],
            dependencies => [ 'metadata', 'livequery', 'JQUERYPLUGIN::FORM' ],
        ),
        $class
    );

    return $this;
}

=begin TML

---++ ClassMethod handleBUTTON( $this, $params, $topic, $web ) -> $result

Tag handler for =%<nop>BUTTON%=. 

=cut

sub handleButton {
    my ( $this, $params, $theTopic, $theWeb ) = @_;

    my $theText =
         $params->{_DEFAULT}
      || $params->{value}
      || $params->{text}
      || '';
    my $theHref      = $params->{href} || '#';
    my $theOnClick   = $params->{onclick};
    my $theTitle     = $params->{title};
    my $theIconName  = $params->{icon} || '';
    my $theAccessKey = $params->{accesskey};
    my $theId        = $params->{id} || '';
    my $theClass     = $params->{class} || '';
    my $theStyle     = $params->{style} || '';
    my $theTarget    = $params->{target};
    my $theType      = $params->{type} || 'button';
    my $theAlign     = $params->{align};

    $theId = "id='$theId'" if $theId;
    $theClass =~ s/\b(simple|center)\b/'jqButton'.ucfirst($1)/ge;

    my $theIcon = '';

    if ($theIconName) {
        if ( $theIconName =~ /^fa-/ ) {
            Foswiki::Plugins::JQueryPlugin::Plugins::createPlugin(
                'fontawesome');
            $theIcon = "<i class='jqButtonIcon fa fa-fw $theIconName'></i>";
        }
        else {
            $theIcon = Foswiki::Plugins::JQueryPlugin::Plugins::getIconUrlPath(
                $theIconName);
            $theIcon =
"<span class='jqButtonIcon' style='background-image:url($theIcon)'></span>"
              if $theIcon;
        }
    }

    $theText = "<span class='jqButtonText'>$theText</span>"
      if defined $theText && $theText ne '';

    if ($theTarget) {
        if ( $theTarget =~ /^(http|\/).*$/ ) {
            $theHref = $theTarget;
        }
        else {
            my ( $web, $topic ) =
              Foswiki::Func::normalizeWebTopicName( $theWeb, $theTarget );
            $theHref = Foswiki::Func::getViewUrl( $web, $topic );
        }
    }

    if ($theAlign) {
        $theAlign = "foswikiRight"  if $theAlign eq 'right';
        $theAlign = "foswikiLeft"   if $theAlign eq 'left';
        $theAlign = "foswikiCenter" if $theAlign eq 'center';
    }

    my @class = ();
    push @class, 'jqButton';
    push @class, $theAlign if $theAlign;
    push @class, $theClass;

    if ( $theType eq 'submit' ) {
        push @class, 'jqSubmitButton';
    }
    if ( $theType eq 'save' ) {
        push @class, 'jqSaveButton';
    }
    if ( $theType eq 'reset' ) {
        push @class, 'jqResetButton';
        Foswiki::Plugins::JQueryPlugin::Plugins::createPlugin('Form');
    }
    if ( $theType eq 'clear' ) {
        push @class, 'jqClearButton';
        Foswiki::Plugins::JQueryPlugin::Plugins::createPlugin('Form');
    }

    if ($theOnClick) {
        $theOnClick =~ s/;$//;
        $theOnClick .= ";return false;" unless $theOnClick =~ /return false;?$/;
    }

    my $class = join( ' ', @class );

    my $result = "<a $theId class='$class' href='$theHref'";
    $result .= " accesskey='$theAccessKey' " if $theAccessKey;
    $result .= " title='$theTitle' "         if $theTitle;
    $result .= " style='$theStyle' "         if $theStyle;
    $result .= " onclick=\"$theOnClick\" "   if $theOnClick;

    $result .= ">$theIcon$theText</a>";
    $result .= "<input type='submit' style='display:none' />"
      if $theType eq 'submit';

    return $result;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2010-2016 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
