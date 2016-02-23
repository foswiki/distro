# See bottom of file for license and copyright information
package Foswiki::Plugins::JQueryPlugin::POPUPWINDOW;
use strict;
use warnings;
use Foswiki::Plugins::JQueryPlugin::Plugin;
our @ISA = qw( Foswiki::Plugins::JQueryPlugin::Plugin );
use Foswiki::Func;

=begin TML

---+ package Foswiki::Plugins::JQueryPlugin::POPUPWINDOW

This is the perl stub for the jquery.popupwindow plugin.

=cut

=begin TML

---++ ClassMethod new( $class, ... )

Constructor

=cut

sub new {
    my $class = shift;

    my $this = bless(
        $class->SUPER::new(
            name     => 'PopUpWindow',
            version  => '1.0.1',
            author   => 'Arthur Clemens',
            homepage => 'http://foswiki.org/Extensions/JQueryPopUpWindow',
            tags     => 'POPUPWINDOW',
            javascript =>
              [ 'jquery.popupwindow.js', 'jquery.popupwindow.init.js' ],
            dependencies => ['livequery'],
        ),
        $class
    );

    return $this;
}

=begin TML

---++ ClassMethod handlePopUpWindow( $this, $params, $topic, $web ) -> $result

Tag handler for =%<nop>POPUPWINDOW%=. 

=cut

sub handlePopUpWindow {
    my ( $this, $params, $theTopic, $theWeb ) = @_;

    my $LINK_STUB =
      '<a href=\'$URL\' class=\'jqPopUpWindow\' rel=\'$OPTIONS\'>$LABEL</a>';
    my $OPTIONS_STUB =
'width:$WIDTH,height:$HEIGHT,toolbar:$TOOLBAR,scrollbars:$SCROLLBARS,status:$STATUS,resizable:$RESIZABLE,menubar:$MENUBAR,createnew:$CREATENEW,center:$CENTER';

    my $topic =
         $params->{_DEFAULT}
      || $params->{topic}
      || $theTopic;
    my @queryParts;

    if ($topic) {

        # get query string
        if ( $topic =~ s/\?(.*)// ) {
            push( @queryParts, $1 );
        }
    }

    my $web      = $params->{web}      || $theWeb;
    my $url      = $params->{url}      || undef;
    my $label    = $params->{label}    || $url || $topic;
    my $template = $params->{template} || 'viewplain';

    if ( !$url ) {

        # link to Foswiki topic
        my ( $normalizedWeb, $normalizedTopic ) =
          Foswiki::Func::normalizeWebTopicName( $web, $topic );
        $url = Foswiki::Func::getViewUrl( $normalizedWeb, $normalizedTopic );
        push( @queryParts, "template=$template" ) if defined $template;
        $url .= '?' . join( ';', @queryParts ) if scalar(@queryParts);
    }

    my $width  = $params->{width}  || '600';
    my $height = $params->{height} || '480';
    my $toolbar    = $params->{toolbar};
    my $scrollbars = $params->{scrollbars} || '1';
    my $status     = $params->{status};
    my $location   = $params->{location} || '0';
    my $resizable  = $params->{resizable};
    my $left       = $params->{left};
    my $top        = $params->{top};
    my $menubar    = $params->{menubar};
    my $createnew  = $params->{createnew};
    my $center     = $params->{center};

    my @options = ();
    push( @options, "width:$width" )           if defined $width;
    push( @options, "height:$height" )         if defined $height;
    push( @options, "toolbar:$toolbar" )       if defined $toolbar;
    push( @options, "scrollbars:$scrollbars" ) if defined $scrollbars;
    push( @options, "status:$status" )         if defined $status;
    push( @options, "location:$location" )     if defined $location;
    push( @options, "resizable:$resizable" )   if defined $resizable;
    push( @options, "left:$left" )             if defined $left;
    push( @options, "top:$top" )               if defined $top;
    push( @options, "menubar:$menubar" )       if defined $menubar;
    push( @options, "createnew:$createnew" )   if defined $createnew;
    push( @options, "center:$center" )         if defined $center;

    # use ';' instead of ',' to be able to use inside MAKETEXT args
    my $optionsStr = join( ';', @options );

    my $result = $LINK_STUB;
    $result =~ s/\$URL/$url/;
    $result =~ s/\$LABEL/$label/;
    $result =~ s/\$OPTIONS/$optionsStr/;

    $result =~ s/"/'/go;

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

Copyright (C) 2010 Arthur Clemens http://visiblearea.com

popupwindow jquery plugin: http://rip747.github.com/popupwindow/ (MIT License)

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
