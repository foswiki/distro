# See bottom of file for license and copyright information

=begin TML

---+!! package Foswiki::Request::Json

Class to encapsulate request data for REST requests.

The following fields are parsed from the path_info and/or query params
   * =
   * =web= the requested web.  Access using web method
   * =topic= the requested topic. Access using topic
   * =filename= the requested attachment filename

=cut

package Foswiki::Request::JSON;
use v5.14;

use Assert;
use Try::Tiny;
use Foswiki::Sandbox                        ();
use JSON                                    ();
use Foswiki::Contrib::JsonRpcContrib::Error ();
use Foswiki::Func                           ();
use Foswiki::Plugins                        ();
use CGI::Util qw(rearrange);

use Moo;
use namespace::clean;
extends qw(Foswiki::Request);

=begin TML

---++ ObjectAttribute json -> $JSON object

Returns the JSON object, or a new JSON object if wne has not already been created.
=cut

has json => (
    is      => 'rw',
    lazy    => 1,
    isa     => Foswiki::Object::isaCLASS( 'json', 'JSON' ),
    default => sub { return JSON->new },
);

=begin TML

---++ ObjectAttribute namespace ->$jsonNamespace

Gets the JSON namespace parsed from the query path.
This either returns a valid parsed namespace, or undef.

   * It does not filter out any illegal characters.
   * There is no default Namespace.

This is read only.

=cut

has namespace => (
    is      => 'rwp',
    lazy    => 1,
    clearer => 1,
    builder => '_establishNamespace',
);

=begin TML

---++ ObjectAttribute jsonerror( ) -> $error object

Used to defer errors detected during request processing that
are reported later.  

=cut

has jsonerror => (
    is        => 'rw',
    predicate => 1,
    isa       => Foswiki::Object::isaCLASS(
        'jsonerror', 'Foswiki::Contrib::JsonRpcContrib::Error'
    ),
);
has jsondata => (
    is        => 'rw',
    lazy      => 1,
    predicate => 1,
    isa       => Foswiki::Object::isaHASH( 'jsondata', noUndef => 1, ),
    clearer   => 1,
    builder   => '_establishJSON',
);

=begin TML
---++ ObjectAttribute jsonmethod

JSON specific method.

=cut

has jsonmethod => (
    is        => 'rw',
    clearer   => 1,
    predicate => 1,
    trigger   => 1,
    builder   => '_establishJSONMethod',
);

=begin TML
---++ ObjectMethod param( $key, $value ) -> $value

See Foswiki::Request for complete calling documentation.  This method extends the base param
method for *read only* access to the JSON data.  It is recommended to use the simpler
jsonparam method for read/write access to the JSON dtaa.

   * If called with a value (to write)  the data is written to the CGI request NOT to the JSON data.
   * If called with a key that does not exist in the JSON data, the SUPER::param() is called, to return the CGI query param.
   * If a key exists in both the CGI params, and the JSON params,  the CGI data will not be reachable.
   * If called with no parameters, the list of CGI params are returned, NOT the JSON parameters. Use params() to get the JSON parameters

=cut

around param => sub {
    my $orig = shift;
    my $this = shift;
    my @p    = @_;

    return $orig->($this) unless scalar @p;

    my ( $key, @value ) = rearrange( [ 'NAME', [qw(VALUE VALUES)] ], @p );

    # Intercept POSTDATA assignment, and process the JSON data
    if ( $key eq 'POSTDATA' && scalar @value ) {
        $this->clear_jsondata;
    }

    # If key doesn't exist in json data,  the fall back to CGI.
    return $this->jsondata->{params}{$key}
      if ( defined $this->jsondata->{params}{$key} );

    # Process
    return $orig->( $this, @p );
};

=begin TML

---+ Private methods
---++ private objectMethod _establishJSON( $string | @array ) ->  n/a

Used internally by the web(), topic(), Namespace and method  methods to trigger parsing of the url
and POST data, and sets object variables with the results.

=cut

sub _establishJSON {
    my $this = shift;

    $this->clear_jsonmethod;
    return $this->parseJSON( $this->app->engine->postData );
}

sub parseJSON {
    my $this = shift;
    my $foo  = shift;
    my $data;

    my $jsondata = {};

    $data = ( ref($foo) eq 'ARRAY' ) ? shift @$foo : $foo;

    my $minimal = ($data) ? 0 : 1;
    $data ||= '{"jsonrpc":"2.0"}';    # Minimal setup

    $jsondata = $this->initFromString($data);

    # If the parse failed, give up here.
    return $jsondata if $this->jsonerror;

    # some basic checks if this is a proper json-rpc 2.0 request

    # must have a version tag
    if ( ( $jsondata->{jsonrpc} || '' ) ne "2.0" ) {
        $this->jsonerror(
            new Foswiki::Contrib::JsonRpcContrib::Error(
                code => -32600,
                text => "Invalid JSON-RPC request - must be jsonrpc: '2.0'",
            )
        );
    }

 # must have a json method
 # SMELL:  This error is suppressed for simple query param type json requests.
 # It's a processing order issue.  The method is there in the query path, but it
 # has not been parsed yet.
    $this->jsonerror(
        new Foswiki::Contrib::JsonRpcContrib::Error(
            code => -32600,
            text => "Invalid JSON-RPC request - no method"
        )
    ) unless $minimal || defined $jsondata->{method};

    # must not have any other keys other than these
    foreach my $key ( keys %{$jsondata} ) {
        $this->jsonerror(
            new Foswiki::Contrib::JsonRpcContrib::Error(
                code => -32600,
                text => "Invalid JSON-RPC request - unknown key $key"
            )
        ) unless $key =~ /^(jsonrpc|method|params|id)$/;
    }

    return $jsondata;
}

=begin TML
---++ private objectMethod initFromString() -> %jsondata 

Initializes the jsondata hash by processing the POSTDATA from the request.

=cut

sub initFromString {
    my ( $this, $data ) = @_;

    my $jsondata;

    # parse json-rpc request
    try {
        %{$jsondata} = ( %{ $this->json->decode($data) } );
    }
    catch {
        my $error = Foswiki::Exception::errorStr(
            Foswiki::Exception::Fatal->transmute( $_, 0 ) );
        $error =~ s/,? +at.*$//s;
        $this->jsonerror(
            new Foswiki::Contrib::JsonRpcContrib::Error(
                code => -32700,
                text => "Parse error - invalid json-rpc request: $error"
            )
        );
    };

    $jsondata->{params} ||= {};

    return $jsondata;
}

=begin TML

---++ private objectMethod _establishAttributes() ->  n/a

Used internally by the web() and topic() methods to trigger parsing of the JSON topic parameter
or the CGI topic parameer, and set object variables with the results.

=cut

around _establishAttributes => sub {
    my $orig = shift;
    my $this = shift;

    # Allow topic= query param to override the path.  By calling param, vs.
    # jsonparam(), the CGI param is used if the json request does not provide
    # a topic param.
    my $topicParam = $this->param('topic');

    my $parse = Foswiki::Request::parse($topicParam);

    # Item3270 - here's the appropriate place to enforce spec
    # http://develop.twiki.org/~twiki4/cgi-bin/view/Bugs/Item3270
    $parse->{topic} = ucfirst( $parse->{topic} )
      if ( defined $parse->{topic} );

    # SMELL.   This isn't working.  Test still fails with wrong web
    unless ( defined $parse->{web} ) {
        if ( defined $this->param('defaultweb') ) {
            $parse->{web} =
              Foswiki::Sandbox::untaint( $this->param('defaultweb'),
                \&Foswiki::Sandbox::validateWebName );
        }
    }

    # Note that Web can still be undefined.  Caller then determines if the
    # defaultweb query param, or the HomeWeb config parameter should be used.

    return $parse;
};

=begin TML
---++ objectMethod jsonparam( $key, $value ) -> $value

Read/write implementaion of a JSON specific param() method.
While param() will read data from the JSON object, this method
can both read and write.

=cut

sub jsonparam {
    my ( $this, $key, $value ) = @_;

    return unless defined $key;
    $this->jsondata->{params}{$key} = $value if defined $value;
    return $this->jsondata->{params}{$key};
}

=begin TML
---++ ObjectMethod version( $value ) -> $version 

Returns the version from the parsed JSON data.  If a value is provided,
the version string is replaced.

=cut

sub version {
    my ( $this, $value ) = @_;

    $this->jsondata->{jsonrpc} = $value if defined $value;
    return $this->jsondata->{jsonrpc} || '';
}

=begin TML
---++ ObjectMethod id( $value ) -> $id 

Returns the id from the parsed JSON data.   If a value is provided,
the id is replaced.

=cut

sub id {
    my ( $this, $value ) = @_;

    $this->jsondata->{id} = $value if defined $value;
    return $this->jsondata->{id} || '';
}

=begin TML
---++ ObjectMethod params() -> %params

Returns the parameters hash from the parsed JSON data.
=cut

sub params {
    return $_[0]->jsondata->{params};
}

=begin TML

---++ ObjectAttribute web

Gets the complete Web path parsed from the JSON request,
This either returns a valid parsed web path, or undef.

   * It does not filter out any illegal characters.
   * It does not set a default web.

This is read only.

=cut

#around _establishWeb => sub {
#    my $orig = shift;
#    my $this = shift;
#
#    return $this->_pathParsed->{web};
#};

=begin TML

---++ ObjectAttribute topic

Gets the complete topic name parsed from the JSON parms,
This either returns a valid parsed topic name, or undef.

   * It does not filter out any illegal characters.
   * It does not set a default topic.

This is read only.

=cut

#around _establishTopic => sub {
#    my $orig = shift;
#    my $this = shift;
#
#    return $this->_pathParsed->{topic};
#};

=begin TML

---++ ObjectMethod pathInfo( $value ) -> $pathInfo

Overides Foswiki::Request::pathInfo().  See Foswiki::Request for documentation.

This method parses the pathInfo for JSON requests.  It extracts the Namespace,
optional method from the path.  eg:  bin/jsonrpc/SomeNamespace/themethod

=cut

around _trigger_pathInfo => sub {
    my $orig       = shift;
    my $this       = shift;
    my ($pathInfo) = @_;

    $orig->( $this, @_ );

    $this->clear_namespace;
};

# `method` object attribute checker and builder.
# NOTE that method obtained from HTTP protocol gets overriden by JSON method
# value.
around _trigger_method => sub {
    my $orig    = shift;
    my $this    = shift;
    my ($value) = @_;

    if ( defined $value && $this->_has_jsondata && lc($value) ne 'post' ) {
        $this->jsonerror(
            new Foswiki::Contrib::JsonRpcContrib::Error(
                code => -32600,
                text => "Method must be POST, not " . $value
            )
        );
    }
};

sub _trigger_jsonmethod {
    my $this = shift;
    my ($value) = @_;
    $this->jsondata->{method} = $value;

    # SMELL method and jsonmethod must not be mixed up!
    #$this->method($value);
}

sub _establishJSONMethod {
    my $this = shift;
    return $this->jsondata->{method};
}

sub _establishNamespace {
    my $this = shift;

    my $decodedInfo = Foswiki::urlDecode( $this->pathInfo );

# Foswiki JSON invocations are defined as having a Namespace (pluginName)
# and method (handler in that plugin). Namespace is set in the query path, method
# is provided in the json data.

    unless ( $decodedInfo =~ /^\/?([^\/\.]+)(?:[\/\.](.*))?$/ ) {
        $this->jsonerror(
            new Foswiki::Contrib::JsonRpcContrib::Error(
                code => -32600,
                text => "Invalid Namespace / method FOO"
            )
        );
        return;
    }

    my $namespace = $1;
    my $method    = $2;

    if ( defined $method ) {
        $this->jsonmethod($method);
    }

    return $namespace;
}

# static
sub _writeDebug {
    print STDERR "- Foswiki::Request::JSON - $_[0]\n";
}

1;

__END__
Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2016 Foswiki Contributors. All Rights Reserved.
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


