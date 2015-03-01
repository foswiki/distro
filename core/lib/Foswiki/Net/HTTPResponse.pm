# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Net::HTTPResponse

Fakeup of HTTP::Response for use when LWP is not available. Only implements
a small subset of the HTTP::Response methods:
| =code()= |
| =message()= |
| =header($field)= |
| =content()= |
| =is_error()= |
| =is_redirect()= |

See the documentation of HTTP::Response for information about the methods.

=cut

package Foswiki::Net::HTTPResponse;

use strict;
use warnings;
use Assert;

sub new {
    my ( $class, $message ) = @_;
    return bless(
        {
            code    => 400,        # BAD REQUEST
            message => $message,
            headers => {},
        },
        $class
    );
}

sub parse {
    my ( $class, $text ) = @_;
    my $this = new( $class, 'Incomplete headers' );

    # Separate the headers from the downloaded file.
    # Headers are delimited from content by \r\n\r\n / Hex \x0d\x0a\x0d\x0a
    my $CRLF = "\015\012";    # "\r\n" is not portable
    $text =~ s/^(.*?)$CRLF$CRLF//s;
    my $httpHeader = $1;      # untaint is OK, checked below
    $this->{content} = $text;

    $httpHeader =~ s/$CRLF/\n/gs;
    $httpHeader =~ s/\r/\n/gs;
    if ( $httpHeader =~ s/^HTTP\/[\d.]+\s(\d+)\s([^$CRLF]*)//s ) {
        $this->{code} = $1;
        $this->{message} = TAINT( $2 || '' );
    }
    while ( $httpHeader =~ s/^(\S*):\s*(.*)$//m ) {

        # implicit untaint is OK for header names,
        # but values need to be retainted
        $this->{headers}->{ lc($1) } = TAINT($2);
    }
    if ( $httpHeader =~ m/\S/ ) {
        $this->{code}    = 400;
        $this->{message} = "Unparseable headers in response: $httpHeader";
    }
    return $this;
}

sub code {
    return shift->{code};
}

sub message {
    return shift->{message};
}

sub header {
    my ( $this, $h ) = @_;
    return $this->{headers}->{$h};
}

sub content {
    return shift->{content};
}

sub is_error {
    my $this = shift;
    return $this->{code} >= 400;
}

sub is_redirect {
    my $this = shift;
    return $this->{code} >= 300 && $this->{code} < 400;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2007 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root
of this distribution. NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
