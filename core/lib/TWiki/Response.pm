# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2007 Peter Thoeny, peter@thoeny.org
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# This module is based/inspired on Catalyst framework, and also CGI,
# CGI::Simple and HTTP::Headers modules. Refer to
#
# http://search.cpan.org/~mramberg/Catalyst-Runtime-5.7010/lib/Catalyst.pm,
# http://search.cpan.org/~lds/CGI.pm-3.29/CGI.pm and
# http://search.cpan.org/author/ANDYA/CGI-Simple-1.103/lib/CGI/Simple.pm
# http://search.cpan.org/~gaas/libwww-perl-5.808/lib/HTTP/Headers.pm
# 
# for credits and liscence details.
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

---+!! package TWiki::Response

Class to encapsulate response data.

Fields:
    * =status=  - response status
    * =headers= - hashref to response headers
    * =body=    - response body
    * =cookies= - hashref to response cookies

=cut

package TWiki::Response;
use strict;
use Assert;
use CGI::Util qw(rearrange expires);

=begin twiki

---++ ClassMethod new() -> $response

Constructs a TWiki::Response object.

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $this = {
        status  => undef,
        headers => {},
        body    => undef,
        charset => 'ISO-8859-1',
        cookies => [],
    };
    return bless $this, $class;
}

=begin twiki

---++ ObjectMethod status( $status ) -> $status

Gets/Sets response status.
   * =$status= is a three digit code, optionally followed by a status string

=cut

sub status {
    my ( $this, $status ) = @_;
    if ($status) {
        $this->{status} = $status =~ /^\d{3}/ ? $status : undef;
    }
    return $this->{status};
}

=begin twiki

---++ ObjectMethod charset([$charset]) -> $charset

Gets/Sets response charset. If not defined, defaults to ISO-8859-1, 
just like CGI.pm

=cut

sub charset {
    return @_ == 1 ? $_[0]->{charset} : ( $_[0]->{charset} = $_[1] );
}

=begin twiki

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

    # Ugly hack to avoid html escape in CGI::Util::rearrange
    local $CGI::Q = { escape => 0 };
    my ( $type, $status, $cookie, $charset, $expires, $attachment, @other ) = rearrange(
        [
            [ 'TYPE',   'CONTENT_TYPE', 'CONTENT-TYPE' ], 'STATUS',
            [ 'COOKIE', 'COOKIES' ],    'CHARSET', 'EXPIRES',
            'ATTACHMENT',
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
        $header = lc $header;
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
    $type .= "; charset=$charset"
        if $type ne ''
            and $type =~ m!^text/!
            and $type !~ /\bcharset\b/
            and $charset ne '';

    if ( $status ) {
        $this->{headers}->{Status} = $status;
        $this->status( $status );
    }
    # push all the cookies -- there may be several
    if ($cookie) {
        my @cookie =
          ref($cookie) && ref($cookie) eq 'ARRAY' ? @$cookie : ($cookie);
        $this->cookies( \@cookie );
    }
    $this->{headers}->{Expires} = expires( $expires, 'http' )
      if ( defined $expires );
    $this->{headers}->{Date} = expires( 0, 'http' )
      if defined $expires || $cookie;
    $this->{headers}->{'Content-Disposition'} =
      "attachment; filename=\"$attachment\""
      if $attachment;

    $this->{headers}->{'Content-Type'} = $type if $type ne '';
}

=begin twiki

---++ ObjectMethod headers( { ... } ) -> $headersHashRef

Gets/Sets all response headers. Keys are headers name and values
are scalars for single-valued headers or arrayref for multivalued ones.

=cut

sub headers {
    my ($this, $hdr) = @_;
    if ($hdr) {
        my %headers = ();
        while ( my ($key, $value) = each %$hdr ) {
            $key =~ s/(?:^|(?<=-))(.)([^-]*)/\u$1\L$2\E/g;
            $headers{$key} = $value;
        }
        $this->{headers} = \%headers;
    }
    return $this->{headers};
}

=begin twiki

---++ ObjectMethod getHeader( [ $name ] ) -> $value

If called without parameters returns all present header names,
otherwise returns a list (maybe with a single element) of values
associated with $name.

=cut

sub getHeader {
    my ( $this, $hdr ) = @_;
    return keys %{ $this->{headers} } unless $hdr;
    $hdr =~ s/(?:^|(?<=-))(.)([^-]*)/\u$1\L$2\E/g;
    my $value = $this->{headers}->{$hdr};
    return ref $value ? @$value : ( $value );
}

=begin twiki

---++ ObjectMethod deleteHeader($h1, $h2, ...)

Deletes headers whose names are passed.

=cut

sub deleteHeader {
    my $this = shift;
    foreach (@_) {
        ( my $hdr = $_ ) =~ s/(?:^|(?<=-))(.)([^-]*)/\u$1\L$2\E/g;
        delete $this->{headers}->{$hdr};
    }
}

=begin twiki

---++ ObjectMethod pushHeader( $name, $value )

Adds $value to list of values associated with header $name.

=cut

sub pushHeader {
    my ( $this, $hdr, $value ) = @_;

    $hdr =~ s/(?:^|(?<=-))(.)([^-]*)/\u$1\L$2\E/g;
    my $cur = $this->{headers}->{$hdr};
    if ( $cur ) {
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

=begin twiki

---++ ObjectMethod cookies( [ \@cookies ] ) -> @cookies

Gets/Sets response cookies. Parameter, if passed, *must* be an arrayref.

Elements may be CGI::Cookie objects or raw cookie strings.

=cut

sub cookies {
    return @_ == 1 ? @{ $_[0]->{cookies} } : @{ $_[0]->{cookies} = $_[1] };
}

=begin twiki

---++ ObjectMethod body( [ $body ] ) -> $body

Gets/Sets response body.

=cut

sub body {
    my ( $this, $body ) = @_;
    if ( defined $body ) {
        $this->{body} = $body;
        { 
            use bytes;
            $this->{headers}->{'Content-Length'} = length $body;
        }
    }
    return $this->{body};
}

=begin twiki

---++ ObjectMethod redirect( $uri, $status, $cookies |
                             -Location => $uri, 
                             -Status   => $status, 
                             -Cookies  => $cookies )

Populate object with redirect response headers.

=$uri= *must* be passed. Others are optional.

CGI Compatibility Note: It doesn't support -target or -nph

=cut

sub redirect {
    my ($this, @p) = @_;
    my ($url, $status, $cookies) = rearrange(
            [
                [ qw(LOCATION URL URI) ], 'STATUS', 
                [ qw(COOKIE COOKIES)   ],
            ],
            @p
    );
    
    return undef unless $url;
    return undef if ( $status && $status !~ /^\s*3\d\d.*/ );
    
    my @headers = (-Location => $url);
    push @headers, '-Status' => ( $status || '302 Found' );
    push @headers, '-Cookie' => $cookies if $cookies;
    $this->header(@headers);
}

1;
