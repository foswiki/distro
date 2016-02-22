# See bottom of file for license and copyright information

=begin TML

---+!! package Foswiki::Request

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

package Foswiki::Request;
use v5.14;

use CGI ();

use Assert;
use Try::Tiny;
use IO::File ();
use CGI::Util qw(rearrange);
use Time::HiRes ();

use Moo;
use namespace::clean;
extends qw(Foswiki::Object);

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

has action => (
    is      => 'rw',
    lazy    => 1,
    default => '',
    trigger => sub {
        my ( $this, $action ) = @_;

        # This will set base_action only the first time action would been set.
        $this->base_action;
        $ENV{FOSWIKI_ACTION} = $action;
    },
);
has base_action => (
    is        => 'ro',
    lazy      => 1,
    predicate => 1,

  # Lazy+ro makes base_action set only once – when action is set for the first
  # time. See action attribute trigger.
    default => sub { return $_[0]->action; },
);
has path_info      => ( is => 'rw', lazy => 1, default => '', );
has remote_address => ( is => 'rw', lazy => 1, default => '', );
has uri            => ( is => 'rw', lazy => 1, default => '', );
has cookies        => ( is => 'rw', lazy => 1, default => sub { {} }, );
has headers        => ( is => 'rw', lazy => 1, default => sub { {} }, );
has _param         => ( is => 'rw', lazy => 1, default => sub { {} }, );
has uploads => (
    is      => 'rw',
    lazy    => 1,
    default => sub { {} },
    isa     => Foswiki::Object::isaHASH( 'uploads', noUndef => 1 ),
);
has param_list => ( is => 'rw', lazy => 1, default => sub { [] }, );
has method => ( is => 'rw', );
has remote_user => ( is => 'rw', );
has server_port => ( is => 'rw', );
has secure      => ( is => 'rw', default => 0, );
has start_time => (    # start_time cannot be lazy, can it?
    is      => 'rw',
    default => sub { return [Time::HiRes::gettimeofday] },
);
has _initializer => ( is => 'ro', init_arg => "initializer", );

# Aliases are to be declared after all attribute handling methods are been
# created but before CGI methods gets imported via cgiRequest attribute
# handling.
*Delete        = \&delete;
*remote_addr   = \&remote_address;
*remoteAddress = \&remote_address;
*remoteUser    = \&remote_user;
*serverPort    = \&server_port;
*delete_all    = \&deleteAll;
*user_agent    = \&userAgent;

# cgiRequest attribute can be used directly but with `handles` property it
# simulates inheritance from CGI. Must be defined after all other attributes to
# avoid reimporting CGI methods which of same names as existing attributes.
has cgiRequest => (
    is      => 'ro',
    lazy    => 1,
    default => sub { return CGI->new; },
    handles => [
        grep { !( /^:/ || __PACKAGE__->can($_) ) }
        map { @{ $CGI::EXPORT_TAGS{$_} } } keys %CGI::EXPORT_TAGS
    ],
);

sub getTime {
    my $this     = shift;
    my $endTime  = [Time::HiRes::gettimeofday];
    my $timeDiff = Time::HiRes::tv_interval( $this->start_time, $endTime );
    return $timeDiff;
}

=begin TML

---++ ClassMethod new([initializer => $initializer])

Constructs a Foswiki::Request object.
   * =$initializer= - may be a filehandle or hashref.
      * If it's a filehandle, it'll be used to reload the Foswiki::Request
        object. See =save= method. Note: Restore only parameters
      * It can be a hashref whose keys are parameter names. Values may be 
        arrayref's to multivalued parameters. Same note as above.

=cut

sub BUILD {
    my $this = shift;
    if ( ref( $this->_initializer ) eq 'HASH' ) {
        while ( my ( $key, $value ) = each %{ $this->_initializer } ) {
            $this->multi_param(
                -name  => $key,
                -value => ref($value) eq 'ARRAY' ? [@$value] : [$value]
            );
        }
    }
    elsif ( ref( $this->_initializer )
        && UNIVERSAL::isa( $this->_initializer, 'GLOB' ) )
    {
        $this->load( $this->_initializer );
    }
}

=begin TML

---++ ObjectAttribute action([$action]) -> $action


Gets/Sets action requested (view, edit, save, ...)

=cut

=begin TML

---++ ObjectAttribute base_action() -> $action

Get the first action ever set in this request object. This remains
unchanged even if a request cache is unwrapped on to of this request.
The idea is that callers can always find out the action that initiated
the HTTP request. This is required for (for example) checking access
controls.

=cut

=begin TML

---++ ObjectAttribute method( [ $method ] ) -> $method

Sets/Gets request method (GET, HEAD, POST).

=cut

=begin TML

---++ ObjectMethod pathInfo( [ $path ] ) -> $path

Sets/Gets request path info.

Called without parameters returns current pathInfo.

This is an alias to =path_info()= ObjectAttribute.

Note that the string returned is a *URL encoded byte string*
i.e. it will only contain characters -A-Za-z0-9_.~!*\'();:@&=+$,/?%#[]
If you intend to analyse it, you will probably have to
Foswiki::urlDecode it first.

=cut

*pathInfo = \&path_info;

=begin TML

---++ ObjectMethod protocol() -> $protocol

Returns 'https' if secure connection. 'http' otherwise.

=cut

# SMELL : review this
sub protocol {
    return $_[0]->secure ? 'https' : 'http';
}

=begin TML

---++ ObjectAttribute uri( [$uri] ) -> $uri

Gets/Sets request uri.

=cut

=begin TML

---++ ObjectMethod queryString() -> $query_string

Returns query_string part of request uri, if any.

=query_string()= alias provided for compatibility with CGI.

Note that the string returned is a *URL encoded byte string*
i.e. it will only contain characters -A-Za-z0-9_.~!*\'();:@&=+$,/?%#[]
If you intend to analyse it, you will probably have to
Foswiki::urlDecode it first.

=cut

*queryString = \&query_string;

sub query_string {
    my $this = shift;
    my @params;
    foreach my $name ( $this->param ) {
        my $key = Foswiki::urlEncode($name);
        push @params,
          map { $key . "=" . Foswiki::urlEncode( defined $_ ? $_ : '' ) }
          $this->param($name);
    }
    return join( ';', @params );
}

=begin TML

---++ ObjectMethod url( [-full     => 1,
                         -base     => 1,
                         -absolute => 1,
                         -relative => 1, 
                         -path     => 1, 
                         -query    => 1] ) -> $url

Returns many url info. 
   * If called without parameters or with -full => 1 returns full url, e.g. 
     http://mysite.net/view
   * If called with -base => 1 returns base url, e.g. http://foswiki.org
   * -absolute => 1 returns absolute action path, e.g. /cgi-bin/view
   * -relative => 1 returns relative action path, e.g. view
   * -path => 1, -query => 1 also includes path info and query string
     respectively

Note that the path and query components are returned as a *URL encoded byte string*
You will most likely need to Foswiki::urlDecode it for use.

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
    my $name;

    ## See Foswiki.spec for the difference between ScriptUrlPath and ScriptUrlPaths
    if ( defined $Foswiki::cfg{ScriptUrlPaths}{ $this->action } ) {

     # When this is set, it is the complete script path including prefix/suffix.
        $name = $Foswiki::cfg{ScriptUrlPaths}{ $this->action };
    }
    else {
        $name = $Foswiki::cfg{ScriptUrlPath} . '/' . $this->action;

        # Don't add suffix if no script is used.
        $name .= $Foswiki::cfg{ScriptSuffix} if $name;
    }
    $name =~ s(//+)(/)g;
    if ($full) {
        my $vh = $this->header('X-Forwarded-Host') || $this->header('Host');
        $url =
          $vh ? $this->protocol . '://' . $vh : $Foswiki::cfg{DefaultUrlHost};
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

=begin TML

---++ ObjectAttribute secure( [$secure] ) -> $secure

Gets/Sets connection's secure flag.

=cut

=begin TML

---++ ObjectMethod remoteAddress( [$ip] ) -> $ip

Gets/Sets client IP address. Alias to ObjectAttribute =remote_address=.

=remote_addr()= alias for compatibility with CGI.

=cut

=begin TML

---++ ObjectMethod remoteUser( [$userName] ) -> $userName

Gets/Sets remote user's name. Alias to CGI-compatible ObjectAttribute
=remote_user=.

=cut

=begin TML

---++ ObjectMethod serverPort( [$userName] ) -> $userName

Gets/Sets server user's name. Alias to CGI-compatible ObjectAttribute
=server_port=.

=cut

=begin TML

---++ ObjectMethod queryParam( [-name => $name, -value => $value             |
                                -name => $name, -values => [ $v1, $v2, ... ] |
                                $name, $v1, $v2, ...                         |
                                name, [ $v1, $v2, ... ]                     
                               ] ) -> @paramNames | @values | $firstValue

This method is used by engines, during its prepare phase. Should not be used
anywhere else. Since bodyParam must exist and it has different semantics from
param method, this one exists for symmetry, and could be modified in the 
future, so it could be possible to get query and body parameters independently.

=cut

sub queryParam {
    my $this = shift;
    return if $this->method && $this->method eq 'POST';
    return $this->param(@_);
}

=begin TML

---++ ObjectMethod bodyParam( [-name => $name, -value => $value             |
                               -name => $name, -values => [ $v1, $v2, ... ] |
                               $name, $v1, $v2, ...                         |
                               name, [ $v1, $v2, ... ]                     
                              ] ) -> @paramNames | @values | $firstValue

Adds parameters passed within request body to the object.  Should be called
only by engines. Otherwise use param() method.

=cut

sub bodyParam {
    my $this = shift;
    return $this->param(@_);
}

=begin TML

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
   * Returns parameter values as UTF-8 encoded binary strings

Resonably compatible with CGI.

*NOTE* this method will assert if it is called in a list context. A list
context might be:
   * in a list of parameters e.g. =my_function( $query->param( ...=
   * assigning to a list e.g. =my @l = $query->param(...=
   * in a loop condition e.g. =foreach ($query->param(...=

The following are *scalar* contexts:
   * =defined($query->param( ...= is OK
   * =lc($query->param( ...= is OK
   * =... if ( $query->param( ...= is OK

In a list context, you should call =multi_param= (fully compatible) to
retrieve list parameters.

=cut

sub multi_param {

    my @list_of_params = param(@_);
    return @list_of_params;
}

sub param {
    my ( $this, @p ) = @_;

    my ( $key, @value ) = rearrange( [ 'NAME', [qw(VALUE VALUES)] ], @p );

    # param() - just return the list of param names
    return @{ $this->param_list } unless defined $key;

# list context can be dangerous so warn:
# http://blog.gerv.net/2014.10/new-class-of-vulnerability-in-perl-web-applications
    if ( DEBUG && wantarray ) {
        my ( $package, $filename, $line ) = caller;
        if ( $package ne 'Foswiki::Request' ) {
            ASSERT( 0,
"Foswiki::Request::param called in list context from package $package, $filename line $line, declare as scalar, or call multi_param. "
            );
        }
    }

    if ( defined $value[0] ) {
        push @{ $this->param_list }, $key
          unless exists $this->_param->{$key};
        $this->_param->{$key} = ref $value[0] eq 'ARRAY' ? $value[0] : [@value];
    }
    if ( defined $this->_param->{$key} ) {
        return wantarray
          ? @{ $this->_param->{$key} }
          : $this->_param->{$key}->[0];
    }
    else {
        return wantarray ? () : undef;
    }
}

=begin TML

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
        return keys %{ $this->cookies } unless $name;
        return () unless $this->cookies->{$name};
        return $this->cookies->{$name}->value if defined $name && $name ne '';
    }
    return unless defined $name && $name ne '';
    return new CGI::Cookie(
        -name    => $name,
        -value   => $value,
        -path    => $path || '/',
        -secure  => $secure || $this->secure,
        -expires => $expires || abs( $Foswiki::cfg{Sessions}{ExpireAfter} )
    );
}

=begin TML

ObjectAttribute cookies( \%cookies ) -> $hashref

Gets/Sets cookies hashref. Keys are cookie names
and values CGI::Cookie objects.

=cut

=begin TML

---++ ObjectMethod delete( @paramNames )

Deletes parameters from request.

=Delete()= alias provided for compatibility with CGI

=cut

sub delete {
    my $this = shift;
    foreach my $p (@_) {
        next unless exists $this->_param->{$p};
        if ( my $upload = $this->uploads->{ $this->param($p) } ) {
            $upload->finish;
            CORE::delete $this->uploads->{ $this->param($p) };
        }
        CORE::delete $this->_param->{$p};
        @{ $this->param_list } = grep { $_ ne $p } @{ $this->param_list };
    }
}

=begin TML

---++ ObjectMethod deleteAll()

Deletes all parameter name and value(s).

=delete_all()= alias provided for compatibility with CGI.

=cut

sub deleteAll {
    my $this = shift;
    $this->delete( $this->param() );
}

=begin TML

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
Foswiki::Response =header= method.

=cut

sub header {
    my ( $this, @p ) = @_;
    my ( $key, @value ) = rearrange( [ 'NAME', [qw(VALUE VALUES)] ], @p );

    return keys %{ $this->headers } unless $key;
    $key =~ tr/_/-/;
    $key = lc($key);

    if ( defined $value[0] ) {
        $this->headers->{$key} =
          ref $value[0] eq 'ARRAY' ? $value[0] : [@value];
    }
    if ( defined $this->headers->{$key} ) {
        return wantarray
          ? @{ $this->headers->{$key} }
          : $this->headers->{$key}->[0];
    }
    else {
        return wantarray ? () : undef;
    }
}

=begin TML

---++ ObjectMethod save( $fh )

Saves object state to filehandle. Object may be loaded later
passing $fh to new constructor or by calling load().

=cut

sub save {
    my ( $this, $fh ) = @_;
    local ( $\, $, ) = ( '', '' );
    foreach my $name ( $this->param ) {
        foreach my $value ( $this->param($name) ) {
            $value = '' unless defined $value;
            next if $name eq '' && $value eq '';    # Item12371
            print $fh Foswiki::urlEncode($name), '=',
              Foswiki::urlEncode($value), "\n";
        }
    }
    print $fh "=\n";
}

=begin TML

---++ ObjectMethod load( $fh )

Loads object state from filehandle, probably created with
a previous save().

=cut

sub load {
    my ( $this, $file ) = @_;
    my %param = ();
    my @plist = ();
    local $/ = "\n";
    while (<$file>) {
        chomp;
        last if /^=$/;
        my ( $key, $value ) =
          map { defined $_ ? Foswiki::urlDecode($_) : $_ } split /=/;

        # Item12956: Split returns only a single entry in array for null values.
        # save sets null values to '',  so load needs to restore '', not undef
        $value = '' unless defined $value;
        if ( exists $param{$key} ) {
            push @{ $param{$key} }, $value;
        }
        else {
            push @plist, $key;
            $param{$key} = [$value];
        }
    }
    foreach my $key (@plist) {
        $this->multi_param( -name => $key, -value => $param{$key} );
    }
}

=begin TML

---++ ObjectMethod upload( $name ) -> $handle

Called with file name parameter returns an open filehandle
to uploaded file.

=cut

sub upload {
    my ( $this, $name ) = @_;
    my $upload = $this->uploads->{ $this->param($name) };
    return defined $upload ? $upload->handle : undef;
}

=begin TML

---++ ObjectMethod uploadInfo( $fname ) -> $headers

Returns a hashref to information about uploaded 
files as sent by browser.

=cut

sub uploadInfo {
    return $_[0]->uploads->{ $_[1] }->uploadInfo;
}

=begin TML

---++ ObjectMethod tmpFileName( $fname ) -> $tmpFileName

Returns the name of temporarly created file to store uploaded $fname.

$fname may be obtained by calling =param()= with form field name.

=cut

sub tmpFileName {
    my ( $this, $fname ) = @_;
    return $this->uploads->{$fname}
      ? $this->uploads->{$fname}->tmpFileName
      : undef;
}

=begin TML

---++ ObjectAttribute uploads( [ \%uploads ] ) -> $hashref

Gets/Sets request uploads field. Keys are uploaded file names,
as sent by browser, and values are Foswiki::Request::Upload objects.

=cut

# ======== possible accessors =======
# auth_type
# content_length
# content_type

=begin TML

---++ ObjectMethod http( [$header] ) -> $value DEPRECATED

Called without parameters returns a list of all available header filed names.

Given a field name returns value associated.

http('HTTP_USER_AGENT'); http('User-Agent') and http('User_Agent') 
are equivalent.

Please, use =header()= instead. Present only for compatibility with CGI.

=cut

sub http {
    my ( $this, $p ) = @_;
    if ( defined $p ) {
        $p =~ s/^https?[_-]//i;
        return $this->header($p);
    }
    return $this->header();
}

=begin TML

---++ ObjectMethod https( [$name] ) -> $value || $secure DEPRECATED

Similar to =http()= method above. Called with no parameters returns
secure flag.

Please, use =header()= and =secure()= instead. 
Present only for compatibility with CGI.

=cut

sub https {
    my ( $this, $p ) = @_;
    return !defined $p || $p =~ m/^https$/i ? $this->secure : $this->http($p);
}

=begin TML

---++ ObjectMethod userAgent() -> $userAgent;

Convenience method to get User-Agent string.

=user_agent()= alias provided for compatibility with CGI.

=cut

sub userAgent { shift->header('User-Agent') }

=begin TML

---++ ObjectMethod referer()

Convenience method to get Referer uri.

=cut

sub referer { shift->header('Referer') }

1;
__END__

Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2009 Foswiki Contributors. All Rights Reserved.
Foswiki Contributors are listed in the AUTHORS file in the root of this
distribution. NOTE: Please extend that file, not this notice.

This module is based/inspired on Catalyst framework, and also CGI,
CGI::Simple and HTTP::Headers modules. Refer to
http://search.cpan.org/~mramberg/Catalyst-Runtime-5.7010/lib/Catalyst.pm,
http://search.cpan.org/~lds/CGI.pm-3.29/CGI.pm,
http://search.cpan.org/author/ANDYA/CGI-Simple-1.103/lib/CGI/Simple.pm, and
http://search.cpan.org/~gaas/libwww-perl-5.808/lib/HTTP/Headers.pm
for full credits and license details.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
