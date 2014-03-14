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

#| $web | web and  |
#| $topic | topic to display the name for |
#| $formatString | format string (like in search) |
sub REVINFO {
    my ( $this, $params, $topicObject ) = @_;
    my $format = $params->{_DEFAULT} || $params->{format};
    my $web    = $params->{web}      || $topicObject->web;
    my $topic  = $params->{topic}    || $topicObject->topic;
    my $cgiQuery = $this->{request};
    my $cgiRev   = '';
    $cgiRev = $cgiQuery->param('rev') if ($cgiQuery);
    my $rev = Foswiki::Store::cleanUpRevID( $params->{rev} || $cgiRev || '' );

    ( $web, $topic ) = $this->normalizeWebTopicName( $web, $topic );
    my $loadedRev = $topicObject->getLoadedRev();
    if (   $web ne $topicObject->web
        || $topic ne $topicObject->topic
        || !defined($loadedRev)
        || $loadedRev ne $rev )
    {
        $topicObject = Foswiki::Meta->new( $this, $web, $topic );

        # haveAccess will try to load the object on the fly, so make sure
        # it is loaded if rev is defined
        $topicObject = $topicObject->load($rev) if ($rev);
        unless ( $topicObject->haveAccess('VIEW') ) {
            return $this->inlineAlert( 'alerts', 'access_denied', $web,
                $topic );
        }
    }

    return $this->renderer->renderRevisionInfo( $topicObject, $rev, $format );
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
