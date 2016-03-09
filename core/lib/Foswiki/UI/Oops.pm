# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::UI::Oops

UI delegate for oops function

=cut

package Foswiki::UI::Oops;

use strict;
use warnings;
use Assert;

use Foswiki ();

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

=begin TML

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

=begin TML

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

    # Foswikitask:Item885: web and topic are required to have values
    $web ||= $session->{webName};

    # If web name is completely missing, it may have contained
    # illegal characters
    $web ||= '';

    $topic ||= $session->{topicName};

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

            # Don't accept internal render tokens in parameters
            #$param =~ s/[\x00-\x03]//g;
            push( @params, $param );
            $n++;
        }
    }

    $tmplName ||= 'oops';

    # Item5324: Filter to block XSS
    $tmplName =~ s/$Foswiki::regex{webTopicInvalidCharRegex}//g;

    # Do not pass on the template parameter otherwise continuation won't work
    $query->delete('template');

    my $tmplData = $session->templates->readTemplate( $tmplName, no_oops => 1 );

    if ( !defined($tmplData) ) {

        # Can't throw an OopsException here, cos we'd just recurse. Build
        # an error page from scratch,
        $tmplData =
            CGI::start_html()
          . CGI::h1( {}, 'Foswiki Installation Error' )
          . <<MESSAGE . CGI::end_html();
Template "$tmplName" not found.
<p />
Check the configuration settings for {TemplateDir} and {TemplatePath}.
MESSAGE
    }
    else {
        if ( defined $def ) {

            # if a def is specified, instantiate that def
            my $blah = $session->templates->expandTemplate($def);
            $tmplData =~ s/%INSTANTIATE%/$blah/;
        }

        # Warning: do NOT attempt to instantiate a topic object with
        # a null or bogus web name!
        my $topicObject =
          Foswiki::Meta->new( $session, $web || $Foswiki::cfg{SystemWebName},
            $topic );
        $tmplData = $topicObject->expandMacros($tmplData);
        $n        = 1;
        foreach my $param (@params) {

            # Entity-encode, to block any potential HTML payload
            $param = Foswiki::entityEncode($param);
            $tmplData =~ s/%PARAM$n%/$param/g;
            $n++;
        }

        # Suppress missing params
        $tmplData =~ s/%PARAM\d+%//g;
        $tmplData = $topicObject->expandMacros($tmplData);
        $tmplData = $topicObject->renderTML($tmplData);
    }

    $session->writeCompletePage($tmplData);
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 1999-2007 Peter Thoeny, peter@thoeny.org
and TWiki Contributors. All Rights Reserved. TWiki Contributors
are listed in the AUTHORS file in the root of this distribution.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
