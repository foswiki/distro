# See bottom of file for license and copyright information
package Foswiki;

use strict;
use warnings;

#our $SEARCHTERMS = qr/\$(web|topic|parent|text|locked|date|isodate|rev|username|wikiname|wikiusername|createdate|createusername|createwikiname|createwikiusername|summary|changes|formname|formfield|pattern|count|ntopics|nhots|pager)\b/;

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

sub FORMAT {
    my ( $this, $params, $topicObject ) = @_;
    my $list_str = defined $params->{_DEFAULT} ? $params->{_DEFAULT} : '';

    my @list = split( /,\s*/, $list_str );
    my $s;

    # TODO: this is a common default that should be extracted into a
    # 'test, default and refine' parameters for all formatResult calls
    # Note that for FORMAT we do not default adding \n after header when
    # separator is not defined. FORMAT is a new feature in 1.1 and does
    # not need the backward compatibility that SEARCH needed.
    $params->{separator} = '$n' unless ( defined( $params->{separator} ) );
    $params->{separator} =
      Foswiki::expandStandardEscapes( $params->{separator} );

    my $type = $params->{type} || 'topic';
    $type = 'topic'
      unless ( $type eq 'string' );    #only support special type 'string'

    # pass on all attrs, and add some more
    #$params->{_callback} = undef;
    $params->{baseweb}   = $topicObject->web;
    $params->{basetopic} = $topicObject->topic;
    $params->{search}    = $params->{_DEFAULT}
      if defined $params->{_DEFAULT};
    $params->{type} = $this->{prefs}->getPreference('SEARCHVARDEFAULTTYPE')
      unless ( $params->{type} );

    undef $params
      ->{limit}; #do not polute FORMAT with the per web legacy mess (the code would be horrid.)

    try {
        my $listIterator;

        if ( $type eq 'string' ) {
            require Foswiki::ListIterator;
            $listIterator = new Foswiki::ListIterator( \@list );
        }
        else {

            # from Search::_makeTopicPattern (plus an added . to
            # allow web.topic)
            my @topics = map {
                s/[^\*\_\-\+\.\/[:alnum:]]//g;
                s/\*/\.\*/g;
                $_
            } @list;

            require Foswiki::Search::InfoCache;
            $listIterator =
              new Foswiki::Search::InfoCache( $this, $params->{baseweb},
                \@topics );
        }
        my ( $ttopics, $searchResult, $tmplTail ) =
          $this->search->formatResults( undef, $listIterator, $params );
        $s = Foswiki::expandStandardEscapes($searchResult);
    }
    catch Error with {
        my $message = (DEBUG) ? shift->stringify() : shift->{-text};

        # Block recursions kicked off by the text being repeated in the
        # error message
        $message =~ s/%([A-Z]*[{%])/%<nop>$1/g;
        $s = $this->inlineAlert( 'alerts', 'bad_search', $message );
    };

    return $s;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2011 Foswiki Contributors. Foswiki Contributors
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
