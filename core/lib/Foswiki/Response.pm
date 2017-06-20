# See bottom of file for license and copyright information

=begin TML

---+!! package Foswiki::Response

Class to encapsulate response data.

Fields:
    * =status=  - response status
    * =headers= - hashref to response headers
    * =body=    - response body
    * =cookies= - hashref to response cookies

=cut

package Foswiki::Response;

use strict;
use warnings;
use Assert;

use CGI::Util ();

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

=begin TML

---++ ClassMethod new() -> $response

Constructs a Foswiki::Response object.

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $this  = {

#status needs to default to 'unset' so the web server can set the status to whatever it needs (think basic auth, or other magics)
        status           => undef,
        headers          => {},
        body             => undef,
        charset          => 'utf-8',
        cookies          => [],
        outputHasStarted => 0,
    };

    return bless $this, $class;
}

=begin TML

---++ ObjectMethod status( $status ) -> $status

Gets/Sets response status.
   * =$status= is a three digit code, optionally followed by a status string

=cut

sub status {
    my ( $this, $status ) = @_;
    if ($status) {
        ASSERT( !$this->{outputHasStarted}, 'Too late to change status' )
          if DEBUG;
        $this->{status} = $status =~ m/^\d{3}/ ? $status : undef;
    }
    return $this->{status};
}

=begin TML

---++ ObjectMethod charset([$charset]) -> $charset

Gets/Sets response charset. If not defined, defaults to ISO-8859-1, 
just like CGI.pm

=cut

sub charset {
    return @_ == 1 ? $_[0]->{charset} : ( $_[0]->{charset} = $_[1] );
}

=begin TML

---++ ObjectMethod header(-type       => $type,
                          -status     => $status,
                          -cookie     => $cookie || \@cookies,
                          -attachment => $attachName,
                          -charset    => $charset,
                          -expires    => $expires,
                          -HeaderN    => ValueN )

Sets response header. Resonably compatible with CGI. 
Doesn't support -nph, -target and -p3p.

=cut

sub header {
    my ( $this, @p ) = @_;
    my (@header);

    ASSERT( !$this->{outputHasStarted}, 'Too late to change headers' ) if DEBUG;

    # Ugly hack to avoid html escape in CGI::Util::rearrange
    local $CGI::Q = { escape => 0 };

    # SMELL: CGI::Util is documented as not having any public subroutines
    my ( $type, $status, $cookie, $charset, $expires, @other ) =
      CGI::Util::rearrange(
        [
            [ 'TYPE',   'CONTENT_TYPE', 'CONTENT-TYPE' ], 'STATUS',
            [ 'COOKIE', 'COOKIES' ],    'CHARSET',
            'EXPIRES',
        ],
        @p
      );

    if ( defined $charset ) {
        $this->charset($charset);
    }
    else {
        $charset = $this->charset;
    }

    foreach (@other) {

        # Don't use \s because of perl bug 21951
        next unless my ( $header, $value ) = /([^ \r\n\t=]+)=\"?(.+?)\"?$/;

        $header = lc($header);
        $header =~ s/\b(\w)/\u$1/g;
        if ( exists $this->{headers}->{$header} ) {
            if ( ref $this->{headers}->{$header} ) {
                push @{ $this->{headers}->{$header} }, $value;
            }
            else {
                $this->{headers}->{$header} =
                  [ $this->{headers}->{$header}, $value ];
            }
        }
        else {
            $this->{headers}->{$header} = $value;
        }
    }

    $type ||= 'text/html' unless defined($type);
    $charset ||= 'utf-8';

    $type .= "; charset=$charset"
      if $type ne ''
      and $type =~ m!^text/!
      and $type !~ /\bcharset\b/
      and $charset ne '';

    if ($status) {
        $this->{headers}->{Status} = $status;
        $this->status($status);
    }

    # push all the cookies -- there may be several
    if ($cookie) {
        my @cookies = ref($cookie) eq 'ARRAY' ? @$cookie : ($cookie);
        $this->cookies( \@cookies );
    }
    $this->{headers}->{Expires} = CGI::Util::expires( $expires, 'http' )
      if ( defined $expires );
    $this->{headers}->{Date} = CGI::Util::expires( 0, 'http' )
      if defined $expires || $cookie;

    $this->{headers}->{'Content-Type'} = $type if $type ne '';
}

=begin TML

---++ ObjectMethod headers( { ... } ) -> $headersHashRef

Gets/Sets all response headers. Keys are headers name and values
are scalars for single-valued headers or arrayref for multivalued ones.

=cut

sub headers {
    my ( $this, $hdr ) = @_;
    if ($hdr) {
        ASSERT( !$this->{outputHasStarted}, 'Too late to change headers' )
          if DEBUG;
        my %headers = ();
        while ( my ( $key, $value ) = each %$hdr ) {
            $key =~ s/(?:^|(?<=-))(.)([^-]*)/\u$1\L$2\E/g;
            $headers{$key} = $value;
        }
        $headers{Expires} = CGI::Util::expires( $headers{Expires}, 'http' )
          if defined $headers{Expires};
        $headers{Date} = CGI::Util::expires( 0, 'http' )
          if defined $headers{'Set-Cookie'} || defined $headers{Expires};
        if ( defined $headers{'Set-Cookie'} ) {
            my @cookies =
              ref( $headers{'Set-Cookie'} ) eq 'ARRAY'
              ? @{ $headers{'Set-Cookie'} }
              : ( $headers{'Set-Cookie'} );
            $this->cookies( \@cookies );
        }
        $this->status( $headers{Status} ) if defined $headers{Status};
        $this->{headers} = \%headers;
    }
    return $this->{headers};
}

=begin TML

---++ ObjectMethod getHeader( [ $name ] ) -> $value

If called without parameters returns all present header names,
otherwise returns a list (maybe with a single element) of values
associated with $name.

=cut

sub getHeader {
    my ( $this, $hdr ) = @_;
    return keys %{ $this->{headers} } unless $hdr;
    $hdr =~ s/(?:^|(?<=-))(.)([^-]*)/\u$1\L$2\E/g;
    if ( exists $this->{headers}->{$hdr} ) {
        my $value = $this->{headers}->{$hdr};
        return ref $value ? @$value : ($value);
    }
    else {
        return;
    }
}

=begin TML

---++ ObjectMethod setDefaultHeaders( { $name => $value, ... } )

Sets the header corresponding to the key => value pairs passed in the
hash, if the key doesn't already exist, otherwise does nothing.
This ensures some default values are entered, but they can be overridden
by plugins or other parts in the code.

=cut

sub setDefaultHeaders {
    my ( $this, $hopt ) = @_;
    return unless $hopt && keys %$hopt;
    while ( my ( $hdr, $value ) = each %$hopt ) {
        $hdr =~ s/(?:^|(?<=-))(.)([^-]*)/\u$1\L$2\E/g;
        unless ( exists $this->{headers}->{$hdr} ) {
            if ( $hdr eq 'Status' ) {
                $this->status($value);
            }
            elsif ( $hdr eq 'Expires' ) {
                $value = CGI::Util::expires( $value, 'http' );
            }
            elsif ( $hdr eq 'Set-Cookie' ) {
                my @cookies = ref($value) eq 'ARRAY' ? @$value : ($value);
                $this->cookies( \@cookies );
            }
            $this->{headers}->{$hdr} = $value;
        }
    }
    $this->{headers}{Date} = CGI::Util::expires( 0, 'http' )
      if !exists $this->{headers}{Date}
      && ( defined $this->{headers}{Expires}
        || defined $this->{headers}{'Set-Cookie'} );
}

=begin TML

---++ ObjectMethod printHeaders()

Return a string of all headers, encoded as UTF8 and separated by CRLF

=cut

sub printHeaders {
    my ($this) = shift;
    my $CRLF   = "\x0D\x0A";
    my $hdr    = '';

    # make sure we always generate a status for the response
    $this->{headers}->{Status} = $this->status()
      if ( $this->status() && !defined( $this->headers->{Status} ) );
    foreach my $header ( keys %{ $this->{headers} } ) {
        $hdr .= $header . ': ' . Foswiki::encode_utf8($_) . $CRLF
          foreach $this->getHeader($header);
    }
    $hdr .= $CRLF;
    return $hdr;
}

=begin TML

---++ ObjectMethod deleteHeader($h1, $h2, ...)

Deletes headers whose names are passed.

=cut

sub deleteHeader {
    my $this = shift;

    ASSERT( !$this->{outputHasStarted}, 'Too late to change headers' ) if DEBUG;

    foreach (@_) {
        ( my $hdr = $_ ) =~ s/(?:^|(?<=-))(.)([^-]*)/\u$1\L$2\E/g;
        delete $this->{headers}->{$hdr};
    }
}

=begin TML

---++ ObjectMethod pushHeader( $name, $value )

Adds $value to list of values associated with header $name.

=cut

sub pushHeader {
    my ( $this, $hdr, $value ) = @_;

    ASSERT( !$this->{outputHasStarted}, 'Too late to change headers' ) if DEBUG;

    $hdr =~ s/(?:^|(?<=-))(.)([^-]*)/\u$1\L$2\E/g;
    my $cur = $this->{headers}->{$hdr};
    if ($cur) {
        if ( ref $cur ) {
            push @{ $this->{headers}->{$hdr} }, $value;
        }
        else {
            $this->{headers}->{$hdr} = [ $cur, $value ];
        }
    }
    else {
        $this->{headers}->{$hdr} = $value;
    }
}

=begin TML

---++ ObjectMethod cookies( [ \@cookies ] ) -> @cookies

Gets/Sets response cookies. Parameter, if passed, *must* be an arrayref.

Elements may be CGI::Cookie objects or raw cookie strings.

WARNING: cookies set this way are *not* passed in redirects.

=cut

sub cookies {
    return @_ == 1 ? @{ $_[0]->{cookies} } : @{ $_[0]->{cookies} = $_[1] };
}

=begin TML

---++ ObjectMethod body( [ $body ] ) -> $body

Gets/Sets response body. Note that =$body= must be a byte string.
Replaces the entire body; if you want to generate the body incrementally,
use =print= instead.

Note that the =$body= returned is a byte string (utf8 encoded if =print=
was used to create it)

=cut

sub body {
    my ( $this, $body ) = @_;
    if ( defined $body ) {
        $this->{headers}->{'Content-Length'} = length($body);
        $this->{body} = $body;
    }
    return $this->{body};
}

=begin TML

---++ ObjectMethod redirect( $uri, $status, $cookies |
                             -Location => $uri, 
                             -Status   => $status, 
                             -Cookies  => $cookies )

Populate object with redirect response headers.

=$uri= *must* be passed. Others are optional.

CGI Compatibility Note: It doesn't support -target or -nph

=cut

sub redirect {
    my ( $this, @p ) = @_;
    ASSERT( !$this->{outputHasStarted}, 'Too late to redirect' ) if DEBUG;
    my ( $url, $status, $cookies ) = CGI::Util::rearrange(
        [ [qw(LOCATION URL URI)], 'STATUS', [qw(COOKIE COOKIES)], ], @p );

    return unless $url;

    $status = 302 unless $status;
    ASSERT(
        $status =~ m/^30\d( [^\r\n]*)?$/,
        "Not a valid redirect status: '$status'"
    ) if DEBUG;
    return if ( $status && $status !~ /^\s*3\d\d.*/ );

# Per https://tools.ietf.org/html/rfc3875#section-6.2.2, if the CGI script returns
# a local path, it must not provide any other headers, such as cookies. So make sure
# the location is an absolute location.
    unless ( $url =~ m{^https?://}i ) {
        my $base =
          ( $Foswiki::cfg{ForceDefaultUrlHost} )
          ? $Foswiki::cfg{DefaultUrlHost}
          : $Foswiki::Plugins::SESSION->{request}->url( base => 1, full => 1 );
        $url = $base . $url;
    }

    my @headers = ( -Location => $url );
    push @headers, '-Status' => $status;
    push @headers, '-Cookie' => $cookies if $cookies;
    $this->header(@headers);
}

=begin TML

---++ ObjectMethod print(...)

Add text content to the end of the body. Content may be unicode.
Use $response->body() to output un-encoded byte strings / binary data

=cut

sub print {
    my $this = shift;
    $this->{body} = '' unless defined $this->{body};
    $this->body( $this->{body} . Foswiki::encode_utf8( join( '', @_ ) ) );
}

=begin TML

---++ ObjectMethod outputHasStarted([$boolean])

Get/set the output-has-started flag. This is used by the Foswiki::Engine
to separate header and body output. Once output has started, the headers
cannot be changed (though the body can be modified)

=cut

sub outputHasStarted {
    my ( $this, $flag ) = @_;
    $this->{outputHasStarted} = $flag if defined $flag;
    return $this->{outputHasStarted};
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 1999-2007 Peter Thoeny, peter@thoeny.org
and TWiki Contributors. All Rights Reserved. TWiki Contributors
are listed in the AUTHORS file in the root of this distribution.

This module is based/inspired on Catalyst framework, and also CGI,
CGI::Simple and HTTP::Headers modules. Refer to
http://search.cpan.org/~mramberg/Catalyst-Runtime-5.7010/lib/Catalyst.pm,
http://search.cpan.org/~lds/CGI.pm-3.29/CGI.pm and
http://search.cpan.org/author/ANDYA/CGI-Simple-1.103/lib/CGI/Simple.pm
http://search.cpan.org/~gaas/libwww-perl-5.808/lib/HTTP/Headers.pm
for credits and liscence details.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
