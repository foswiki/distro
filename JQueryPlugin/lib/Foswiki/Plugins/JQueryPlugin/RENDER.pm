# See bottom of file for license and copyright information

package Foswiki::Plugins::JQueryPlugin::RENDER;
use strict;
use warnings;

use Foswiki                                ();
use Foswiki::Plugins::JQueryPlugin::Plugin ();
our @ISA = qw( Foswiki::Plugins::JQueryPlugin::Plugin );

sub new {
    my $class = shift;
    my $session = shift || $Foswiki::Plugins::SESSION;

    my $this = bless(
        $class->SUPER::new(
            $session,
            name       => 'Render',
            version    => '0.9.83',
            author     => 'Boris Moore',
            homepage   => 'http://www.jsviews.com',
            javascript => [ 'jquery.render.js', 'jquery.template-loader.js' ],
        ),
        $class
    );

    return $this;
}

=begin TML

---++ ClassMethod restTmpl( $session, $subject, $verb )

rest handler to load foswiki templates

=cut

sub restTmpl {
    my ( $this, $session, $subject, $verb ) = @_;

    my $result       = '';
    my $request      = Foswiki::Func::getRequestObject();
    my $load         = $request->param('load');
    my $name         = $request->param('name') || $load;
    my $web          = $session->{webName};
    my $topic        = $session->{topicName};
    my $contentType  = $request->param("contenttype");
    my $cacheControl = $request->param("cachecontrol");
    my $doRender =
      Foswiki::Func::isTrue( scalar( $request->param('render') ), 0 );

    $cacheControl = "max-age=28800" unless defined $cacheControl;

    $result = Foswiki::Func::loadTemplate($load) if defined $load;

    if ( defined $name ) {
        my $attrs = new Foswiki::Attrs($name);
        $result = $session->templates->tmplP($attrs);
    }

    $result = Foswiki::Func::expandCommonVariables( $result, $topic, $web )
      || '';
    $result = Foswiki::Func::renderText( $result, $web ) if $doRender;

    # Item13667: clean up html that could disturb jquery-ui
    $result =~ s/<!--[^\[<].*?-->//g;

    my $response = $session->{response};

    if ( $result eq "" ) {
        $response->header( -status => 500 );
        $session->writeCompletePage(
            "ERROR: template '" . Foswiki::entityEncode($name) . "' not found",
            undef, $contentType
        );
    }
    else {
        $response->header( -"Cache-Control" => $cacheControl ) if $cacheControl;
        $session->writeCompletePage( $result, undef, $contentType );
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


