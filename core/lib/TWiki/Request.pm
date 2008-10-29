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
# http://search.cpan.org/~lds/CGI.pm-3.29/CGI.pm,
# http://search.cpan.org/author/ANDYA/CGI-Simple-1.103/lib/CGI/Simple.pm, and
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

---+!! package TWiki::Request

Class to encapsulate request data.

Fields:
   * =action= action requested (view, edit, save, ...)
   * =cookies= hashref whose keys are cookie names and values
               are CGI::Cookie objects
   * =headers= hashref whose keys are header name
   * =method= request method (GET, HEAD, POST)
   * =param= hashref of parameters, both query and body ones
   * =param_list= arrayref with parameter names in received order
   * =path_info= path_info of request (eg. /WebName/TopciName)
   * =remote_address= Client's IP address
   * =remote_user= Remote HTTP authenticated user
   * =secure= Boolean value about use of encryption
   * =server_port= Port that the webserver listens on
   * =uploads= hashref whose keys are parameter name of uploaded
               files
   * =uri= the request uri

=cut

package TWiki::Request;

use strict;
use Assert;
use Error;
use IO::File;
use CGI::Util qw(rearrange);

=begin twiki

---++ ClassMethod new([$initializer])

Constructs a TWiki::Request object.
   * =$initializer= - may be a filehandle or hashref.
      * If it's a filehandle, it'll be used to reload the TWiki::Request
        object. See =save= method. Note: Restore only parameters
      * It can be a hashref whose keys are parameter names. Values may be 
        arrayref's to multivalued parameters. Same note as above.

=cut

sub new {
    my ( $proto, $initializer ) = @_;

    my $this;

    my $class = ref($proto) || $proto;

    $this = {
        action         => '',
        cookies        => {},
        headers        => {},
        method         => undef,
        param          => {},
        param_list     => [],
        path_info      => '',
        remote_address => '',
        remote_user    => undef,
        secure         => 0,
        server_port    => undef,
        uploads        => {},
        uri            => '',
    };

    bless $this, $class;

    if ( ref($initializer) eq 'HASH' ) {
        while ( my ( $key, $value ) = each %$initializer ) {
            $this->param(
                -name  => $key,
                -value => ref($value) eq 'ARRAY' ? [@$value] : [$value]
            );
        }
    }
    elsif ( ref($initializer) && UNIVERSAL::isa($initializer, 'GLOB') ) {
        $this->load($initializer);
    }
    return $this;
}

=begin twiki

---++ ObjectMethod action() -> $action

Gets/Sets action requested (view, edit, save, ...)

=cut

sub action {
    return @_ == 1    ? 
      $_[0]->{action} : 
      ( $ENV{TWIKI_ACTION} = $_[0]->{action} = $_[1] );
}

=begin twiki

---++ ObjectMethod method( [ $method ] ) -> $method

Sets/Gets request method (GET, HEAD, POST).

=cut

sub method {
    return @_ == 1 ? $_[0]->{method} : ( $_[0]->{method} = $_[1] );
}

=begin twiki

---++ ObjectMethod pathInfo( [ $path ] ) -> $path

Sets/Gets request path info.

Called without parameters returns current pathInfo.

There is a =path_info()= alias for compatibility with CGI.

=cut

*path_info = \&pathInfo;

sub pathInfo {
    return @_ == 1 ? $_[0]->{path_info} : ( $_[0]->{path_info} = $_[1] );
}

=begin twiki

---++ ObjectMethod protocol() -> $protocol

Returns 'https' if secure connection. 'http' otherwise.

=cut

# SMELL : review this
sub protocol {
    return $_[0]->secure ? 'https' : 'http';
}

=begin twiki

---++ ObjectMethod uri( [$uri] ) -> $uri

Gets/Sets request uri.

=cut

sub uri {
    return @_ == 1 ? $_[0]->{uri} : ( $_[0]->{uri} = $_[1] );
}

=begin twiki

---++ ObjectMethod queryString() -> $query_string

Returns query_string part of request uri, if any.

=query_string()= alias provided for compatibility with CGI.

=cut

*query_string = \&queryString;

sub queryString {
    my $this = shift;
    my @params;
    foreach my $name ( $this->param ) {
        my $key = TWiki::urlEncode($name);
        push @params,
          map { $key . "=" . TWiki::urlEncode(defined $_ ? $_ : '') } $this->param($name);
    }
    return join(';', @params);
}

=begin twiki

---++ ObjectMethod url( [-full     => 1,
                         -base     => 1,
                         -absolute => 1,
                         -relative => 1, 
                         -path     => 1, 
                         -query    => 1] ) -> $url

Returns many url info. 
   * If called without parameters or with -full => 1 returns full url, e.g. 
     http://twiki.org/cgi-bin/view
   * If called with -base => 1 returns base url, e.g. http://twiki.org
   * -absolute => 1 returns absolute action path, e.g. /cgi-bin/view
   * -relative => 1 returns relative action path, e.g. view
   * -path => 1, -query => 1 also includes path info and query string
     respectively

Reasonably compatible with CGI corresponding method. Doesn't support
-rewrite. See Item5914.

=cut

sub url {
    my ( $this, @p ) = @_;

    my ( $relative, $absolute, $full, $base, $path_info, $query ) = rearrange(
        [
            qw(RELATIVE ABSOLUTE FULL BASE), [qw(PATH PATH_INFO)],
            [qw(QUERY_STRING QUERY)],
        ],
        @p
    );
    my $url;
    $full++ if $base || !( $relative || $absolute );
    my $path = $this->pathInfo;
    my $name =
      defined $TWiki::cfg{ScriptUrlPaths}{ $this->action }
      ? $TWiki::cfg{ScriptUrlPaths}{ $this->action }
      : $TWiki::cfg{ScriptUrlPath} . '/' . $this->action;
    if ($full) {
        my $vh = $this->header('X-Forwarded-Host') || $this->header('Host');
        $url =
          $vh ? $this->protocol . '://' . $vh : $TWiki::cfg{DefaultUrlHost};
        return $url if $base;
        $url .= $name;
    }
    elsif ($relative) {
        ($url) = $name =~ m{([^/]+)$};
    }
    elsif ($absolute) {
        $url = $name;
    }
    $url .= $path if $path_info && defined $path;
    my $queryString = $this->queryString();
    $url .= '?' . $queryString if $query && $queryString;
    $url = '' unless defined $url;
    return $url;
}

=begin twiki

---++ ObjectMethod secure( [$secure] ) -> $secure

Gets/Sets connection's secure flag.

=cut

sub secure {
    return @_ == 1 ? $_[0]->{secure} : ( $_[0]->{secure} = $_[1] );
}

=begin twiki

---++ ObjectMethod remoteAddress( [$ip] ) -> $ip

Gets/Sets client IP address.

=remote_addr()= alias for compatibility with CGI.

=cut

*remote_addr = \&remoteAddress;

sub remoteAddress {
    return @_ == 1
      ? $_[0]->{remote_address}
      : ( $_[0]->{remote_address} = $_[1] );
}

=begin twiki

---++ ObjectMethod remoteUser( [$userName] ) -> $userName

Gets/Sets remote user's name.

=remote_user()= alias for compatibility with CGI.

=cut

*remote_user = \&remoteUser;

sub remoteUser {
    return @_ == 1 ? $_[0]->{remote_user} : ( $_[0]->{remote_user} = $_[1] );
}

=begin twiki

---++ ObjectMethod serverPort( [$userName] ) -> $userName

Gets/Sets server user's name.

=server_port()= alias for compatibility with CGI.

=cut

*server_port = \&serverPort;

sub serverPort {
    return @_ == 1 ? $_[0]->{server_port} : ( $_[0]->{server_port} = $_[1] );
}

=begin twiki

---++ ObjectMethod queryParam( [-name => $name, -value => $value             |
                                -name => $name, -values => [ $v1, $v2, ... ] |
                                $name, $v1, $v2, ...                         |
                                name, [ $v1, $v2, ... ]                     
                               ] ) -> @paramNames | @values | $firstValue

This methos is used by engines, during its prepare phase. Should not be used
anywhere else. Since bodyParam must exist and it has different semantics from
param method, this one exists for symmetry, and could be modified in the 
future, so it could be possible to get query and body parameters independently.

=cut

sub queryParam {
    my $this = shift;
    return undef if $this->method && $this->method eq 'POST';
    return $this->param(@_);
}

=begin twiki

---++ ObjectMethod bodyParam( [-name => $name, -value => $value             |
                               -name => $name, -values => [ $v1, $v2, ... ] |
                               $name, $v1, $v2, ...                         |
                               name, [ $v1, $v2, ... ]                     
                              ] ) -> @paramNames | @values | $firstValue

Adds parameters passed within request body. It keeps previous values,
but places new ones first. Should be called only by engines. Otherwise
use param() method.

=cut

sub bodyParam {
    my ( $this, @p ) = @_;
    
    my ( $key, @newValue ) = rearrange( [ 'NAME', [qw(VALUE VALUES)] ], @p );

    # If a parameter is defined at both query string and body, CGI.pm
    # places body values first, but all values are available. However, 
    # CGI::param replaces previous values with new ones whenever called, 
    # so we need to rescue old values and append them to the new ones. 
    # This way, this class behaves the same as CGI.pm and so does 'param' 
    # method.
    my @values = $this->param($key);
    if ( ref($newValue[0]) eq 'ARRAY' ) {
        unshift @values, @{$newValue[0]}
    }
    else {
        unshift @values, @newValue;
    }
    return $this->param($key, @values);
}
 
=begin twiki

---++ ObjectMethod param( [-name => $name, -value => $value             |
                           -name => $name, -values => [ $v1, $v2, ... ] |
                           $name, $v1, $v2, ...                         |
                           name, [ $v1, $v2, ... ]                     
                           ] ) -> @paramNames | @values | $firstValue

   * Called without parameters returns all parameter names
   * Called only with parameter name or with -name => 'name'
      * In list context returns all associated values (maybe empty list)
      * In scalar context returns first value (maybe undef)
   * Called with name and list of values or with 
     -name => 'name', -value => 'value' or -name => 'name', -values => [ ... ]
     sets parameter value

Resonably compatible with CGI.

=cut

sub param {
    my ( $this, @p ) = @_;

    my ( $key, @value ) = rearrange( [ 'NAME', [qw(VALUE VALUES)] ], @p );

    return @{ $this->{param_list} } unless $key;
    if ( defined $value[0] ) {
        push @{ $this->{param_list} }, $key
          unless exists $this->{param}{$key};
        $this->{param}{$key} =
          ref $value[0] eq 'ARRAY' ? $value[0] : [@value];
    }
    if ( defined $this->{param}{$key} ) {
        return wantarray
            ? @{ $this->{param}{$key} }
            : $this->{param}{$key}->[0];
    }
    else {
        return wantarray ? () : undef;
    }
}

=begin twiki

---++ ObjectMethod cookie($name [, $value, $path, $secure, $expires]) -> $value

   * If called  without parameters returns a list of cookie names.
   * If called only with =$name= parameter returns value of cookie 
     with that name or undef if it doesn't exist.
   * If called with defined $value and other  parameters returns a 
     CGI::Cookie  object  created  with those  parameters. Doesn't 
     store this new created cookie within request object. This way 
     for compatibility with CGI.

=cut

sub cookie {
    eval { require CGI::Cookie; 1 } or throw Error::Simple($@);
    my ( $this, @p ) = @_;
    my ( $name, $value, $path, $secure, $expires ) =
      rearrange( [ 'NAME', [qw(VALUE VALUES)], 'PATH', 'SECURE', 'EXPIRES' ],
        @p );
    unless ( defined $value ) {
        return keys %{ $this->{cookies} } unless $name;
        return () unless $this->{cookies}{$name};
        return $this->{cookies}{$name}->value if defined $name && $name ne '';
    }
    return undef unless defined $name && $name ne '';
    return new CGI::Cookie(
        -name    => $name,
        -value   => $value,
        -path    => $path || '/',
        -secure  => $secure || $this->secure,
        -expires => $expires || abs( $TWiki::cfg{Sessions}{ExpireAfter} )
    );
}

=begin twiki

ObjectMethod cookies( \%cookies ) -> $hashref

Gets/Sets cookies hashref. Keys are cookie names
and values CGI::Cookie objects.

=cut

sub cookies {
    return @_ == 1 ? $_[0]->{cookies} : ( $_[0]->{cookies} = $_[1] );
}

=begin twiki

---++ ObjectMethod delete( @paramNames )

Deletes parameters from request.

=Delete()= alias provided for compatibility with CGI

=cut

*Delete = \&delete;

sub delete {
    my $this = shift;
    foreach my $p (@_) {
        next unless exists $this->{param}{$p};
        if ( my $upload = $this->{uploads}{$this->param($p)} ) {
            $upload->finish;
            CORE::delete $this->{uploads}{$this->param($p)};
        }
        CORE::delete $this->{param}{$p};
        @{ $this->{param_list} } = grep { $_ ne $p } @{ $this->{param_list} };
    }
}

=begin twiki

---++ ObjectMethod deleteAll()

Deletes all parameter name and value(s).

=delete_all()= alias provided for compatibility with CGI.

=cut

*delete_all = \&deleteAll;

sub deleteAll {
    my $this = shift;
    $this->delete( $this->param() );
}

=begin twiki

---++ ObjectMethod header([-name => $name, -value  => $value            |
                           -name => $name, -values => [ $v1, $v2, ... ] |
                           $name, $v1, $v2, ...                         |
                           name, [ $v1, $v2, ... ]                     
                           ] ) -> @paramNames | @values | $firstValue

Gets/Sets a header field:
   * Called without parameters returns all header field names
   * Called only with header field name or with -name => 'name'
      * In list context returns all associated values (maybe empty list)
      * In scalar context returns the first value (maybe undef)
   * Called with name and list of values or with 
     -name => 'name', -value => 'value' or -name => 'name', -values => [ ... ]
     sets header field value

*Not compatible with CGI*, since CGI correspondent is a 
response write method. CGI scripts obtain headers from %ENV
or =http= method. %ENV is not available and must be replaced
by calls to this and other methods of this class. =http= is
provided for compatibility, but is deprecated. Use this one
instead.

Calls to CGI =header= method must be replaced by calls to
TWiki::Response =header= method.

=cut

sub header {
    my ( $this, @p ) = @_;
    my ( $key, @value ) = rearrange( [ 'NAME', [qw(VALUE VALUES)] ], @p );

    return keys %{ $this->{headers} } unless $key;
    $key =~ tr/_/-/;
    $key = lc $key;

    if ( defined $value[0] ) {
        $this->{headers}{$key} =
          ref $value[0] eq 'ARRAY' ? $value[0] : [@value];
    }
    if ( defined $this->{headers}{$key} ) {
        return wantarray
          ? @{ $this->{headers}{$key} }
          : $this->{headers}{$key}->[0];
    }
    else {
        return wantarray ? () : undef;
    }
}

=begin twiki

---++ ObjectMethod save( $fh )

Saves object state to filehandle. Object may be loaded latter
passing $fh to new constructor or by calling load().

=cut

sub save {
    my ( $this, $fh ) = @_;
    local ( $\, $, ) = ( '', '' );
    foreach my $name ( $this->param ) {
        my $key = TWiki::urlEncode($name);
        foreach my $value ($this->param($name)) {
            $value = '' unless defined $value;
            print $fh $key, "=", TWiki::urlEncode($value), "\n"
        }
    }
    print $fh "=\n";
}

=begin twiki

---++ ObjectMethod load( $fh )

Loads object state from filehandle, probably created with
a previous save().

=cut

sub load {
    my ($this, $file) = @_;
    my %param = ();
    my @plist = ();
    local $/ = "\n";
    while (<$file>) {
        chomp;
        last if /^=/;
        my ( $key, $value ) =
          map { defined $_ ? TWiki::urlDecode($_) : $_ } split /=/;
        if ( exists $param{$key} ) {
            push @{ $param{$key} }, $value;
        }
        else {
            push @plist, $key;
            $param{$key} = [$value];
        }
    }
    foreach my $key (@plist) {
        $this->param( -name => $key, -value => $param{$key} );
    }
}

=begin twiki

---++ ObjectMethod upload( $name ) -> $handle

Called with file name parameter returns an open filehandle
to uploaded file.

=cut

sub upload {
    my ( $this, $name ) = @_;
    my $upload = $this->{uploads}{$this->param($name)};
    return defined $upload ? $upload->handle : undef;
}

=begin twiki

---++ ObjectMethod uploadInfo( $fname ) -> $headers

Returns a hashref to information about uploaded 
files as sent by browser.

=cut

sub uploadInfo {
    return $_[0]->{uploads}{ $_[1] }->uploadInfo;
}

=begin twiki

---++ ObjectMethod tmpFileName( $fname ) -> $tmpFileName

Returns the name of temporarly created file to store uploaded $fname.

$fname may be obtained by calling =param()= with form field name.

=cut

sub tmpFileName {
    my ( $this, $fname ) = @_;
    return $this->{uploads}{$fname}
      ? $this->{uploads}{$fname}->tmpFileName
      : undef;
}

=begin twiki

---++ ObjectMethod uploads( [ \%uploads ] ) -> $hashref

Gets/Sets request uploads field. Keys are uploaded file names,
as sent by browser, and values are TWiki::Request::Upload objects.

=cut

sub uploads {
    return @_ == 1 ? $_[0]->{uploads} : ( $_[0]->{uploads} = $_[1] );
}

# ======== possible accessors =======
# auth_type
# content_length
# content_type

=begin twiki

---++ ObjectMethod http( [$header] ) -> $value DEPRECATED

Called without parameters returns a list of all available header filed names.

Given a field name returns value associated.

http('HTTP_USER_AGENT'); http('User-Agent') and http('User_Agent') 
are equivalent.

Please, use =header()= instead. Present only for compatibility with CGI.

=cut

sub http {
    my ($this, $p) = @_;
    if ( defined $p ) {
        $p =~ s/^https?[_-]//i;
        return $this->header( $p );
    }
    return $this->header();
}

=begin twiki

---++ ObjectMethod https( [$name] ) -> $value || $secure DEPRECATED

Similar to =http()= method above. Called with no parameters returns
secure flag.

Please, use =header()= and =secure()= instead. 
Present only for compatibility with CGI.

=cut

sub https {
    my ( $this, $p ) = @_;
    return !defined $p || $p =~ /^https$/i ? $this->secure : $this->http($p);
}

=begin twiki

---++ ObjectMethod userAgent() -> $userAgent;

Convenience method to get User-Agent string.

=user_agent()= alias provided for compatibility with CGI.

=cut

*user_agent = \&userAgent;

sub userAgent { shift->header('User-Agent') };

=begin twiki

---++ ObjectMethod referer()

Convenience method to get Referer uri.

=cut

sub referer   { shift->header('Referer')    };

1;
