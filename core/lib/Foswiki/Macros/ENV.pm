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

sub ENV {
    my ( $this, $params ) = @_;

    my $key = $params->{_DEFAULT};
    return ''
      unless $key
      && defined $Foswiki::cfg{AccessibleENV}
      && $key =~ m/$Foswiki::cfg{AccessibleENV}/;
    my $val;
    if ( $key =~ m/^HTTPS?_(\w+)/ ) {
        $val = $this->{request}->header($1);
    }
    elsif ( $key eq 'REQUEST_METHOD' ) {
        $val = $this->{request}->method;
    }
    elsif ( $key eq 'REMOTE_USER' ) {
        $val = $this->{request}->remoteUser;
    }
    elsif ( $key eq 'REMOTE_ADDR' ) {
        $val = $this->{request}->remoteAddress;
    }
    elsif ( $key eq 'PATH_INFO' ) {
        $val = $ENV{$key};
        if ( $val && $val =~ m/['"]/g ) {
            $val = substr( $val, 0, ( ( pos $val ) - 1 ) );
        }
    }
    else {

        # TSA SMELL: Foswiki::Request doesn't support
        # SERVER_\w+, REMOTE_HOST and REMOTE_IDENT.
        # Use %ENV as fallback, but for ones above
        # wil probably not behave as expected if
        # running with non-CGI engine.
        $val = $ENV{$key};
    }
    return defined $val ? $val : 'not set';
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
