# See bottom of file for license and copyright information
package Foswiki;

use strict;
use warnings;

sub FOREACH {
    my ( $this, $params, $topicObject ) = @_;

    # pass on all attrs, and add some more
    #$params->{_callback} = undef;
    $params->{baseweb}   = $topicObject->web;
    $params->{basetopic} = $topicObject->topic;
    $params->{search}    = $params->{_DEFAULT} if defined $params->{_DEFAULT};
    $params->{type}      = $this->{prefs}->getPreference('SEARCHVARDEFAULTTYPE')
      unless ( $params->{type} );

  #    $params->{format}      = '$topic'  unless ( defined($params->{format}) );
  #TODO: change to $n some time.
    $params->{separator} = "\n" unless ( defined( $params->{separator} ) );

    #    $params->{header}      = ''  unless ( $params->{header} );
    #    $params->{footer}      = ''  unless ( $params->{footer} );
    my $s;
    try {
        my $topicString = $params->{_DEFAULT} || '';

        #from Search::_makeTopicPattern (plus an added . to allow web.topic)
        my @topics = map {
            s/[^\*\_\-\+\.$Foswiki::regex{mixedAlphaNum}]//go;
            s/\*/\.\*/go;
            $_
          }
          split( /,\s*/, $topicString );

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
    return $s;
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
