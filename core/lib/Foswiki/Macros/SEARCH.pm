# See bottom of file for license and copyright information
package Foswiki;

use strict;
use warnings;

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

sub SEARCH {
    my ( $this, $params, $topicObject ) = @_;

    # pass on all attrs, and add some more
    #$params->{_callback} = undef;
    $params->{baseweb}   = $topicObject->web;
    $params->{basetopic} = $topicObject->topic;
    $params->{search}    = $params->{_DEFAULT} if defined $params->{_DEFAULT};
    $params->{type}      = $this->{prefs}->getPreference('SEARCHVARDEFAULTTYPE')
      unless ( $params->{type} );

#TODO: this is a common default that should be extracted into a 'test, default and refine' parameters for all formatResult calls
    if ( defined( $params->{separator} ) ) {
        $params->{separator} =
          Foswiki::expandStandardEscapes( $params->{separator} );
    }

    # newline feature replaces newlines within each search result
    if ( defined( $params->{newline} ) ) {
        $params->{newline} =
          Foswiki::expandStandardEscapes( $params->{newline} );
    }

    my $s;
    try {
        $s = $this->search->searchWeb(%$params);
    }
    catch Error with {
        my $exception = shift;
        my $message;

        if (DEBUG) {
            $message = $exception->stringify();
        }
        else {
            $message = $exception->{-text};
            my @lines = split( /\n/, $message );
            $message = $lines[0];
            $message =~ s/ at .*? line \d+\.?$//;
        }

        # Block recursions kicked off by the text being repeated in the
        # error message
        $message =~ s/%([A-Z]*[{%])/%<nop>$1/g;
        $message =~ s/\n/<br \/>/g;
        $s = $this->inlineAlert( 'alerts', 'bad_search', $message );
    };
    return $s;
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
