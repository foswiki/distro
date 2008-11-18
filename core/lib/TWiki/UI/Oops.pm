# Module of Foswiki - The Free Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 1999-2007 Peter Thoeny, peter@thoeny.org
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.

=begin twiki

---+ package TWiki::UI::Oops

UI delegate for oops function

=cut

package TWiki::UI::Oops;

use strict;
use Assert;

require TWiki;

=pod

---++ StaticMethod oops_cgi($session)

=oops= command handler.
This method is designed to be invoked via the =UI::run= method.
CGI parameters:
| =template= | name of template to use |
| =paramN= | Parameter for expansion of template |
%PARAMn% tags will be expanded in the template using the 'paramN'
values in the query.

=cut

sub oops_cgi {
    my $session = shift;
    my $topic   = $session->{topicName};
    my $web     = $session->{webName};
    my $query   = $session->{request};

    oops( $session, $web, $topic, $query, 0 );
}

=pod

---++ StaticMethod oops($session, $web, $topic, $query, $keep)

The body of an oops script call, abstracted out so it can be called for
the case where an oops is required, but all the parameters in the query
must be saved for passing on to another URL invoked from a form in
the template. If $keep is defined, it must be a reference to a hash
(usually an oopsexception) that defines the parameters to the
script (template, def etc). In this case, all the parameters in
the =$query= are added as hiddens into the expanded template.

=cut

sub oops {
    my ( $session, $web, $topic, $query, $keep ) = @_;

    my $tmplName;
    my $def;
    my @params;
    my $n = 1;

    if ($keep) {

        # Use oops parameters from the keep hash instead
        $tmplName = $keep->{template};
        $def      = $keep->{def};
        if ( ref( $keep->{params} ) eq 'ARRAY' ) {
            foreach my $p ( @{ $keep->{params} } ) {
                push( @params, $p );
                $n++;
            }
        }
        elsif ( defined $keep->{params} ) {
            push( @params, $keep->{params} );
        }
    }
    else {
        $tmplName = $query->param('template');
        $def      = $query->param('def');
        while ( defined( my $param = $query->param( 'param' . $n ) ) ) {
            push( @params, $param );
            $n++;
        }
    }
    $tmplName ||= 'oops';

    # Item5324: Filter out < and > to block XSS
    $tmplName =~ tr/<>//d;

    # Do not pass on the template parameter otherwise continuation won't work
    $query->delete('template');

    my $skin = $session->getSkin();

    my $tmplData = $session->templates->readTemplate( $tmplName, $skin );

    if ( !$tmplData ) {
        $tmplData =
            CGI::start_html()
          . CGI::h1('TWiki Installation Error')
          . 'Template "'
          . $tmplName
          . '" not found.'
          . CGI::p()
          . 'Check the configuration settings for {TemplateDir} and {TemplatePath}.'
          . CGI::end_html();
    }
    else {
        if ( defined $def ) {

            # if a def is specified, instantiate that def
            my $blah = $session->templates->expandTemplate($def);
            $tmplData =~ s/%INSTANTIATE%/$blah/;
        }
        $tmplData = $session->handleCommonTags( $tmplData, $web, $topic );
        $n = 1;
        foreach my $param (@params) {

            # Entity-encode, to block any potential HTML payload
            $param = TWiki::entityEncode($param);
            $tmplData =~ s/%PARAM$n%/$param/g;
            $n++;
        }
        $tmplData =~ s/%(PARAM\d+)%/
          CGI::span({class=>'twikiAlert'},"MISSING $1 ")/ge if DEBUG;
        $tmplData = $session->handleCommonTags( $tmplData, $web, $topic );
        $tmplData =
          $session->renderer->getRenderedVersion( $tmplData, $web, $topic );
    }

    $session->writeCompletePage($tmplData);
}

1;
