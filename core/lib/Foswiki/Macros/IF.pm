# See bottom of file for license and copyright information
package Foswiki::Macros::IF;
use v5.14;

use Foswiki;
use Foswiki::If::Parser ();
use Try::Tiny;

use Moo;
use namespace::clean;
extends qw(Foswiki::Object);
with qw(Foswiki::Macro);

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

has ifParser => (
    is      => 'rw',
    lazy    => 1,
    default => sub { return Foswiki::If::Parser->new; },
);
has evaluating_if => (
    is      => 'rw',
    default => sub { {} },
);

sub expand {
    my ( $this, $params, $topicObject ) = @_;

    my $session = $this->session;

    my $texpr = $params->{_DEFAULT};
    $texpr = '' unless defined $texpr;
    my $expr;
    my $result;

    # Block after 5 levels.
    if (   $this->evaluating_if->{$texpr}
        && $this->evaluating_if->{$texpr} > 5 )
    {
        delete $this->evaluating_if->{$texpr};
        return '';
    }
    $this->evaluating_if->{$texpr}++;
    try {
        $expr = $this->ifParser->parse($texpr);
        if ( $expr->evaluate( tom => $topicObject, data => $topicObject ) ) {
            $params->{then} = '' unless defined $params->{then};
            $result = Foswiki::expandStandardEscapes( $params->{then} );
        }
        else {
            $params->{else} = '' unless defined $params->{else};
            $result = Foswiki::expandStandardEscapes( $params->{else} );
        }
    }
    catch {
        if ( $_->isa('Foswiki::Infix::Error') ) {
            $result =
              $session->inlineAlert( 'alerts', 'generic', 'IF{',
                $params->stringify(), '}:', $_->text );
        }
        else {
            $_->throw;
        }
    }
    finally {
        delete $this->evaluating_if->{$texpr};
    };
    return $result;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2009 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 1999-2007 Peter Thoeny, peter@thoeny.org
and TWiki Contributors. All Rights Reserved. TWiki Contributors
are listed in the AUTHORS file in the root of this distribution.
Based on parts of Ward Cunninghams original Wiki and JosWiki.
Copyright (C) 1998 Markus Peter - SPiN GmbH (warpi@spin.de)
Some changes by Dave Harris (drh@bhresearch.co.uk) incorporated

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
