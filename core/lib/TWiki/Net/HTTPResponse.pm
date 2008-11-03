# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2007 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.

=pod

---+ package TWiki::Net::HTTPResponse

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

package TWiki::Net::HTTPResponse;

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

    $text =~ s/\r\n/\n/gs;
    $text =~ s/\r/\n/gs;
    $text =~ s/^(.*?)\n\n//s;
    my $httpHeader = $1;
    $this->{content} = $text;
    if ( $httpHeader =~ s/^HTTP\/[\d.]+\s(\d+)\d\d\s(.*)$// ) {
        $this->{code}    = $1;
        $this->{message} = $2;
    }
    $httpHeader = "\n$httpHeader\n";
    foreach my $header ( split( /\n(?=![ \t])/, $httpHeader ) ) {
        if ( $header =~ /^.*?: (.*)$/s ) {
            $this->{headers}->{ lc($1) } = $2;
        }
        else {
            $this->{code}    = 400;
            $this->{message} = "Unparseable header in response: $header";
        }
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
