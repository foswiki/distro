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

# $https flag set when HTTPS macro is requested.

sub HTTP {
    my ( $this, $params, $topicObject ) = @_;
    my $res;
    my $req = _validateRequest( $params->{_DEFAULT} );

    my $https = ( substr( ( caller() )[1], -8 ) eq "HTTPS.pm" );

    if ($https) {
        return ''
          unless (
            !defined $req      # Requesting secure flag
            || length($req)    # or requesting a specific header
          );
        $res = $this->{request}->https($req);
    }
    else {
        return ''
          unless (
            defined $req       # Specifc header requested
            && length($req)    # and passed validation
          );
        $res = $this->{request}->http($req);
    }
    $res = '' unless defined($res);
    return $res;
}

sub _validateRequest {

    # Permit undef - used by HTTPS variant
    return $_[0] unless defined $_[0];

    # Nothing allowed if AccessibleHeaders is not defined
    return '' unless ( scalar @{ $Foswiki::cfg{AccessibleHeaders} } );

    foreach my $hdr ( @{ $Foswiki::cfg{AccessibleHeaders} } ) {
        return $hdr if ( lc( $_[0] ) eq lc($hdr) );
    }

    # Nothing matched, return empty.
    return '';
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2015 Foswiki Contributors. Foswiki Contributors
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
