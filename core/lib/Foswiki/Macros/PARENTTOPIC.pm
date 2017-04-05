# See bottom of file for license and copyright information
package Foswiki;

use strict;
use warnings;

use Foswiki::Meta ();
use Foswiki::Func ();
use Foswiki::Render::Parent;

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

sub PARENTTOPIC {
    my ( $this, $params, $topicObject ) = @_;

    if ( defined( $params->{topic} ) ) {
        my ( $nweb, $ntopic ) =
          Foswiki::Func::normalizeWebTopicName( $topicObject->web,
            $params->{topic} );
        if ( $nweb ne $topicObject->web || $ntopic ne $topicObject->topic ) {
            my $meta = Foswiki::Meta->load( $this, $nweb, $ntopic );
            $topicObject = $meta;
        }
    }

    # make sure the topicObject is loaded
    my $loadedRev = $topicObject->getLoadedRev();
    $topicObject = $topicObject->load() unless defined $loadedRev;

    $params->{dontrecurse} = ( Foswiki::isTrue( $params->{recurse} ) ) ? 0 : 1;

    return expandStandardEscapes(
        Foswiki::Render::Parent::render( $this, $topicObject, $params ) );

}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2017 Foswiki Contributors. Foswiki Contributors
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
