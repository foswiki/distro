# See bottom of file for license and copyright information
package Foswiki;

use strict;
use warnings;

use Foswiki::Address ();
use Foswiki::Meta    ();

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

# See System.VarMETA
# Before calling, ensure the topicObject is loaded with the version of the
# topic you intend to display!
sub META {
    my ( $this, $params, $topicObject ) = @_;

    my $option = $params->{_DEFAULT} || '';
    if ( defined( $params->{topic} ) ) {
        my $addrObj = Foswiki::Address->new(
            web    => $topicObject->web,
            string => $params->{topic}
        );
        if ( !$addrObj->equiv($topicObject) ) {
            my $meta =
              new Foswiki::Meta( $this, $addrObj->web, $addrObj->topic );
            $topicObject = $meta;
        }
    }

    # make sure the topicObject is loaded
    my $loadedRev = $topicObject->getLoadedRev();
    $topicObject = $topicObject->load() unless defined $loadedRev;

    if ( $option eq 'form' ) {

        # META:FORM and META:FIELD
        return $topicObject->renderFormForDisplay();
    }
    elsif ( $option eq 'formfield' ) {

        # a formfield from within topic text
        return $topicObject->renderFormFieldForDisplay(
            $params->get('name'),
            Foswiki::isTrue( $params->{display} )
            ? '$value(display)'
            : '$value',
            $params
        );
    }
    elsif ( $option eq 'attachments' ) {

        # renders attachment tables
        return $this->attach->renderMetaData( $topicObject, $params );
    }
    elsif ( $option eq 'moved' ) {
        require Foswiki::Render::Moved;
        return Foswiki::Render::Moved::render( $this, $topicObject, $params );
    }
    elsif ( $option eq 'parent' ) {

        # Only parent parameter has the format option and should do std escapes
        require Foswiki::Render::Parent;
        return expandStandardEscapes(
            Foswiki::Render::Parent::render( $this, $topicObject, $params ) );
    }

    # return nothing if invalid parameter
    return '';
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
