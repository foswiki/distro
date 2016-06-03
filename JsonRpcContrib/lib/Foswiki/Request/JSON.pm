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
use strict;
use warnings;

use Foswiki::Request ();
our @ISA = ('Foswiki::Request');

use Assert;
use Error                                   ();
use Foswiki::Sandbox                        ();
use JSON                                    ();
use Foswiki::Contrib::JsonRpcContrib::Error ();
use Foswiki::Func                           ();
use Foswiki::Plugins                        ();
use CGI::Util qw(rearrange);

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

sub new {
    my ($class) = @_;

    # Initialize parent with $proto, $initializer
    my $this = $class->SUPER::new( $_[1], $_[2] );

    # Add few more attributes
    $this->{json}       = undef;    # JSON object
    $this->{_jsondata}  = undef;    # Anchors the posted JSON data
    $this->{_jsonerror} = undef
      ;  # Points to a Foswiki::Contrib::JsonRpcContrib::Error if error detected
    $this->{namespace} = undef;    # The JSON namespace
    bless $this, $class;

    return $this;
}

=begin TML

---+ Methods overriding Foswiki::Request
---++ ObjectMethod pathInfo( $value ) -> $pathInfo

Overides Foswiki::Request::pathInfo().  See Foswiki::Request for documentation.

This method parses the pathInfo for JSON requests.  It extracts the Namespace,
optional method from the path.  eg:  bin/jsonrpc/SomeNamespace/themethod

=cut

*path_info = \&pathInfo;

sub pathInfo {
    my ( $this, $pathInfo ) = @_;

    _writeDebug( "pathInfo entered " . Data::Dumper::Dumper( \$pathInfo ) )
      if Foswiki::Request::TRACE;

    return $_[0]->SUPER::pathInfo() if @_ == 1;

    my $decodedInfo = Foswiki::urlDecode($pathInfo);

# Foswiki JSON invocations are defined as having a Namespace (pluginName)
# and method (handler in that plugin). Namespace is set in the query path, method
# is provided in the json data.

    unless ( $decodedInfo =~ /^\/?([^\/\.]+)(?:[\/\.](.*))?$/ ) {
        $this->{_jsonerror} =
          new Foswiki::Contrib::JsonRpcContrib::Error( -32600,
            "Invalid Namespace / method" );
        return $this->SUPER::pathInfo( $_[1] );
    }

    my $namespace = $1;
    my $method    = $2;

    $this->{namespace} = $namespace;

    if ( defined $method ) {
        $this->jsonmethod($method);
    }

    return $this->SUPER::pathInfo( $_[1] );
}

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

sub param {
    my ( $this, @p ) = @_;

    return $this->SUPER::param() unless scalar @p;

    my ( $key, @value ) = rearrange( [ 'NAME', [qw(VALUE VALUES)] ], @p );

    # Intercept POSTDATA assignment, and process the JSON data
    if ( $key eq 'POSTDATA' && scalar @value ) {
        $this->_establishJSON( $value[0] );
    }

    # If key doesn't exist in json data,  the fall back to CGI.
    return $this->{_jsondata}{params}{$key}
      if ( defined $this->{_jsondata}{params}{$key} );

    # Process
    return $this->SUPER::param(@p);

}

=begin TML

---++ ObjectMethod method() ->$restMethod

Gets the JSON method recovered from the json request.
This either returns a valid parsed method, or undef.
Call SUPER::method() to access the http method.

   * It does not filter out any illegal characters.
   * There is no default Subject.

=cut

sub method {
    my ( $this, $value ) = @_;

    _writeDebug( "method entered " . Data::Dumper::Dumper( \$value ) )
      if Foswiki::Request::TRACE;

    if ( defined $value && !defined $this->{_jsondata} && lc($value) ne 'post' )
    {
        $this->{_jsonerror} =
          new Foswiki::Contrib::JsonRpcContrib::Error( -32600,
            "Method must be POST" );
    }

    # "write" - set the CGI method.
    if ( defined $value ) {
        return $this->SUPER::method($value);
    }

    unless ( defined $this->{_jsondata}{method} ) {
        return $this->SUPER::method($value);
    }

    return $this->{_jsondata}{method};
}

=begin TML

---+ Private methods
---++ private objectMethod _establishJSON( $string | @array ) ->  n/a

Used internally by the web(), topic(), Namespace and method  methods to trigger parsing of the url
and POST data, and sets object variables with the results.

=cut

sub _establishJSON {
    my $this = shift;
    my $foo  = shift;
    my $data;

    # if already initialized, no need to repeat
    return if ( defined $this->{_jsondata}{jsonrpc} );

    $data = ( ref($foo) eq 'ARRAY' ) ? shift @$foo : $foo;

    $data ||= '{"jsonrpc":"2.0"}';    # Minimal setup
    _writeDebug("data=$data") if Foswiki::Request::TRACE;

    $this->initFromString($data);

    # some basic checks if this is a proper json-rpc 2.0 request

    # must have a version tag
    if ( ( $this->version() || '' ) ne "2.0" ) {
        $this->{_jsonerror} =
          new Foswiki::Contrib::JsonRpcContrib::Error( -32600,
            "Invalid JSON-RPC request - must be jsonrpc: '2.0'" );
    }

    # must have a json method
    $this->{_jsonerror} =
      new Foswiki::Contrib::JsonRpcContrib::Error( -32600,
        "Invalid JSON-RPC request - no method" )
      unless defined $this->jsonmethod();

    _writeDebug( "jsonmethod=" . ( $this->jsonmethod() || 'undef' ) )
      if Foswiki::Request::TRACE;

    # must not have any other keys other than these
    foreach my $key ( keys %{ $this->{_jsondata} } ) {
        $this->{_jsonerror} =
          new Foswiki::Contrib::JsonRpcContrib::Error( -32600,
            "Invalid JSON-RPC request - unknown key $key" )
          unless $key =~ /^(jsonrpc|method|params|id)$/;
    }

}

=begin TML
---++ private objectMethod initFromString() -> %jsondata 

Initializes the {_jsondata} hash by processing the POSTDATA from the request.

=cut

sub initFromString {
    my ( $this, $data ) = @_;

    _writeDebug("initFromString\n$data") if Foswiki::Request::TRACE;

    # parse json-rpc request
    eval {
        %{ $this->{_jsondata} } =
          ( %{ $this->{_jsondata} }, %{ $this->json->decode($data) } );
    };
    _writeDebug(
        "after jsondata=" . Data::Dumper::Dumper( $this->{_jsondata} ) );

    if ($@) {
        my $error = $@;
        $error =~ s/,? +at.*$//s;
        $this->{_jsonerror} =
          new Foswiki::Contrib::JsonRpcContrib::Error( -32700,
            "Parse error - invalid json-rpc request: $error" );
    }

    $this->{_jsondata}{params} ||= {};

    return $this->{_jsondata};
}

=begin TML

---++ private objectMethod _establishAddress() ->  n/a

Used internally by the web() and topic() methods to trigger parsing of the JSON topic parameter
or the CGI topic parameer, and set object variables with the results.

=cut

sub _establishAddress {
    my $this = shift;

    # Allow topic= query param to override the path.  By calling param, vs.
    # jsonparam(), the CGI param is used if the json request does not provide
    # a topic param.
    my $topicParam = $this->param('topic');

    my $parse = Foswiki::Request::parse($topicParam);

    # Item3270 - here's the appropriate place to enforce spec
    # http://develop.twiki.org/~twiki4/cgi-bin/view/Bugs/Item3270
    $this->{topic} = ucfirst( $parse->{topic} )
      if ( defined $parse->{topic} );

    # Note that Web can still be undefined.  Caller then determines if the
    # defaultweb query param, or the HomeWeb config parameter should be used.

    $this->{web}          = $parse->{web};
    $this->{invalidWeb}   = $parse->{invalidWeb};
    $this->{invalidTopic} = $parse->{invalidTopic};
    $this->{_pathParsed}  = 1;
}

=begin TML

---+ JSON specific request methods 
---++ objectMethod json() -> $JSON object

Returns the JSON object, or a new JSON object if wne has not already been created.
=cut

sub json {
    my $this = shift;

    unless ( defined $this->{json} ) {
        $this->{json} = new JSON;
    }

    return $this->{json};
}

=begin TML

---++ objectMethod jsonerror( ) -> $error object

Used to defer errors detected during request processing that
are reported later.  

=cut

sub jsonerror {

    return $_[0]->{_jsonerror};
}

=begin TML
---++ objectMethod jsonparam( $key, $value ) -> $value

Read/write implementaion of a JSON specific param() method.
While param() will read data from the JSON object, this method
can both read and write.

=cut

sub jsonparam {
    my ( $this, $key, $value ) = @_;

    return unless defined $key;
    $this->{_jsondata}{params}{$key} = $value if defined $value;
    return $this->{_jsondata}{params}{$key};
}

=begin TML
---++ objectMethod jsonmethod( $value ) -> $method

Read/write implementaion of a JSON specific method() method.
While method() will read data from the JSON object, this method
can both read and write.

=cut

sub jsonmethod {
    my ( $this, $value ) = @_;

    _writeDebug(
        "jsonmethod entered (this=$this)" . Data::Dumper::Dumper( \$value ) )
      if Foswiki::Request::TRACE;

    $this->{_jsondata}{method} = $value if defined $value;
    return $this->{_jsondata}{method};
}

=begin TML
---++ ObjectMethod version( $value ) -> $version 

Returns the version from the parsed JSON data.  If a value is provided,
the version string is replaced.

=cut

sub version {
    my ( $this, $value ) = @_;

    $this->{_jsondata}{jsonrpc} = $value if defined $value;
    return $this->{_jsondata}{jsonrpc} || '';
}

=begin TML
---++ ObjectMethod id( $value ) -> $id 

Returns the id from the parsed JSON data.   If a value is provided,
the id is replaced.

=cut

sub id {
    my ( $this, $value ) = @_;

    $this->{_jsondata}{id} = $value if defined $value;
    return $this->{_jsondata}{id} || '';
}

=begin TML
---++ ObjectMethod params() -> %params

Returns the parameters hash from the parsed JSON data.
=cut

sub params {
    return $_[0]->{_jsondata}{params};
}

=begin TML

---++ ObjectMethod namespace() ->$jsonNamespace

Gets the JSON namespace parsed from the query path.
This either returns a valid parsed namespace, or undef.

   * It does not filter out any illegal characters.
   * There is no default Namespace.

This is read only.

=cut

sub namespace {
    my ( $this, $value ) = @_;

    $this->{namespace} = $value if defined $value;
    return $this->{namespace};
}

=begin TML

---++ ObjectMethod web() -> $baseweb

Gets the complete Web path parsed from the JSON request,
This either returns a valid parsed web path, or undef.

   * It does not filter out any illegal characters.
   * It does not set a default web.

This is read only.

=cut

sub web {
    my $this = shift;

    unless ( $this->{_pathParsed} ) {
        $this->_establishAddress();
    }

    _writeDebug( "Request->web() returns " . ( $this->{web} || 'undef' ) )
      if Foswiki::Request::TRACE;
    return $this->{web};

}

=begin TML

---++ ObjectMethod topic() -> $basetopic

Gets the complete topic name parsed from the JSON parms,
This either returns a valid parsed topic name, or undef.

   * It does not filter out any illegal characters.
   * It does not set a default topic.

This is read only.

=cut

sub topic {
    my $this = shift;

    unless ( $this->{_pathParsed} ) {
        $this->_establishAddress();
    }

    _writeDebug( "Request->topic() returns " . ( $this->{topic} || 'undef' ) )
      if Foswiki::Request::TRACE;
    return $this->{topic};

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


