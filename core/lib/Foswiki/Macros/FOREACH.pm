# See bottom of file for license and copyright information
package Foswiki;

use strict;
use warnings;

our $SEARCHTERMS = qr/\$(web|topic|parent|text|locked|date|isodate|rev|username|wikiname|wikiusername|createdate|createusername|createwikiname|createwikiusername|summary|changes|formname|formfield|pattern|count|ntopics|nhots|pager)\b/;

sub FOREACH {
    my ( $this, $params, $topicObject ) = @_;

    my @list = split( /,\s*/, $params->{_DEFAULT} || '' );
    my $s;
    
    #TODO: this is a common default that should be extracted into a 'test, default and refine' parameters for all formatResult calls
    if ( defined($params->{separator}) ) {
        $params->{separator} = Foswiki::expandStandardEscapes($params->{separator});
    }

    # If the format string contains any of the topic-specific format specifiers
    # then the list is treated as a list of topic names. Otherwise it is treated
    # as a list of strings.
    my $format = $params->{format};
    my $header = $params->{header} || '';
    my $footer = $params->{footer} || '';
    if ( !defined($format)
           || $format =~ /$SEARCHTERMS/o
             || $header =~ /$SEARCHTERMS/o
               || $footer =~ /$SEARCHTERMS/o ) {

        # Treat as list of topic names

        # pass on all attrs, and add some more
        #$params->{_callback} = undef;
        $params->{baseweb}   = $topicObject->web;
        $params->{basetopic} = $topicObject->topic;
        $params->{search}    = $params->{_DEFAULT}
          if defined $params->{_DEFAULT};
        $params->{type}  = $this->{prefs}->getPreference('SEARCHVARDEFAULTTYPE')
          unless ( $params->{type} );

        # TODO: change to $n some time.
        $params->{separator} = "\n" unless ( defined( $params->{separator} ) );
        
        #    $params->{header}      = ''  unless ( $params->{header} );
        #    $params->{footer}      = ''  unless ( $params->{footer} );

        # $params->{format} = '$topic'  unless ( defined($params->{format}) );
        try {

            #from Search::_makeTopicPattern (plus an added . to allow web.topic)
            my @topics = map {
                s/[^\*\_\-\+\.$Foswiki::regex{mixedAlphaNum}]//go;
                s/\*/\.\*/go;
                $_
            } @list;

            my $query;    #query node
            require Foswiki::Search::InfoCache;
            my $infoCache =
              new Foswiki::Search::InfoCache( $this, $params->{baseweb}, \@topics );
            my ( $ttopics, $searchResult, $tmplTail ) =
              $this->search->formatResults( $query, $infoCache, $params );
            $s = $searchResult;
        }
          catch Error::Simple with {
              my $message = (DEBUG) ? shift->stringify() : shift->{-text};

              # Block recursions kicked off by the text being repeated in the
              # error message
              $message =~ s/%([A-Z]*[{%])/%<nop>$1/g;
              $s = $this->inlineAlert( 'alerts', 'bad_search', $message );
          };
    } else {
        # Simple list of strings
        $format = '$item' unless ( $format );
        my $index = 1;
        my @items;
        foreach my $item (@list) {
            my $entry = $format;
            $entry =~ s/\$item(\(\))?/$item/g;
            $entry =~ s/\$index(\(\))?/$index/g;
            push( @items, $entry );
            $index++;
        }
        $s = join($params->{separator}, @items);
        $s = $params->{header} . $s if defined $params->{header};
        $s .= $params->{footer} if defined $params->{footer};
        $s = expandStandardEscapes( $s );
    }
    return $s;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
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
