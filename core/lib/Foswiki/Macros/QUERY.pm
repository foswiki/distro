# See bottom of file for license and copyright information
package Foswiki;

use strict;
use warnings;
use Foswiki::Serialise ();

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

our $evalParser;    # could share $ifParser from IF.pm

sub QUERY {
    my ( $this, $params, $topicObject ) = @_;
    my $result;
    my $expr = $params->{_DEFAULT};
    $expr = '' unless defined $expr;
    my $style = ucfirst( lc( $params->{style} || 'default' ) );
    if ( $style =~ m/[^a-zA-Z0-9_]/ ) {
        return "%RED%QUERY: invalid 'style' parameter passed%ENDCOLOR%";
    }
    $style = Foswiki::Sandbox::untaintUnchecked($style);

    # Config key queries don't need / care about topic versions.
    if ( $expr !~ m/^\{.*\}$/ ) {

        my $rev = $params->{rev};

       # FORMFIELD does its own caching.
       # Either the home-made cache there should go into Meta so that both
       # FORMFIELD and QUERY benefit, or the store should be made a lot smarter.

        if ( defined $rev && length($rev) ) {
            my $crev = $topicObject->getLoadedRev();
            if ( defined $crev && $crev != $rev ) {
                $topicObject =
                  Foswiki::Meta->load( $topicObject->session, $topicObject->web,
                    $topicObject->topic, $rev );
            }
        }
        elsif ( !$topicObject->latestIsLoaded() ) {

            # load latest rev
            $topicObject =
              Foswiki::Meta->load( $topicObject->session, $topicObject->web,
                $topicObject->topic );
        }
    }

    # Recursion block.
    $this->{evaluatingEval} ||= {};

    # Block after 5 levels.
    if (   $this->{evaluatingEval}->{$expr}
        && $this->{evaluatingEval}->{$expr} > 5 )
    {
        delete $this->{evaluatingEval}->{$expr};
        return '';
    }
    unless ($evalParser) {
        require Foswiki::Query::Parser;
        $evalParser = new Foswiki::Query::Parser();
    }

    $this->{evaluatingEval}->{$expr}++;
    try {
        my $node = $evalParser->parse($expr);
        $result = $node->evaluate( tom => $topicObject, data => $topicObject );
        $result = Foswiki::Serialise::serialise( $result, $style );
    }
    catch Foswiki::Infix::Error with {
        my $e = shift;
        $result =
          $this->inlineAlert( 'alerts', 'generic', 'QUERY{',
            $params->stringify(), '}:', $e->{-text} );
    }
    finally {
        delete $this->{evaluatingEval}->{$expr};
    };

    return $result;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2010 Foswiki Contributors. Foswiki Contributors
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
