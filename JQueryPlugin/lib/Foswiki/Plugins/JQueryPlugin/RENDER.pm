# See bottom of file for license and copyright information

package Foswiki::Plugins::JQueryPlugin::RENDER;
use v5.14;

use Moo;
extends qw( Foswiki::Plugins::JQueryPlugin::Plugin );

our %pluginParams = (
    name       => 'Render',
    version    => '0.9.73',
    author     => 'Boris Moore',
    homepage   => 'http://www.jsviews.com',
    javascript => [ 'jquery.render.js', 'jquery.template-loader.js' ],
);

=begin TML

---++ ClassMethod restTmpl( $app, $subject, $verb )

rest handler to load foswiki templates

=cut

sub restTmpl {
    my ( $this, $app, $subject, $verb ) = @_;

    my $result       = '';
    my $request      = Foswiki::Func::getRequestObject();
    my $load         = $request->param('load');
    my $name         = $request->param('name') || $load;
    my $web          = $app->request->web;
    my $topic        = $app->request->topic;
    my $contentType  = $request->param("contenttype");
    my $cacheControl = $request->param("cachecontrol");
    my $doRender =
      Foswiki::Func::isTrue( scalar( $request->param('render') ), 0 );

    $cacheControl = "max-age=28800" unless defined $cacheControl;

    $result = Foswiki::Func::loadTemplate($load) if defined $load;

    if ( defined $name ) {
        my $attrs = new Foswiki::Attrs($name);
        $result = $app->templates->tmplP($attrs);
    }

    $result = Foswiki::Func::expandCommonVariables( $result, $topic, $web )
      || '';
    $result = Foswiki::Func::renderText( $result, $web ) if $doRender;

    # Item13667: clean up html that could disturb jquery-ui
    $result =~ s/<!--[^\[<].*?-->//g;

    my $response = $app->response;

    if ( $result eq "" ) {
        $response->header( -status => 500 );
        $app->writeCompletePage(
            "ERROR: template '" . Foswiki::entityEncode($name) . "' not found",
            undef, $contentType
       );
    }
    else {
        $response->header( -"Cache-Control" => $cacheControl ) if $cacheControl;
        $app->writeCompletePage( $result, undef, $contentType );
    }

    return;
}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2010-2016 Foswiki Contributors. Foswiki Contributors

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.


