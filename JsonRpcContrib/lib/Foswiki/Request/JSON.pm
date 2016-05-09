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
    $this->{_jsondata}  = undef;
    $this->{_jsonerror} = undef;
    bless $this, $class;

    return $this;
}

##############################################################################
#

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

sub param {
    my ( $this, @p ) = @_;

    my ( $key, @value ) = rearrange( [ 'NAME', [qw(VALUE VALUES)] ], @p );

  # param() - just return the list of param names
  # (This has nothing to do with JSON,  but is needed for Request compatibility)
    return @{ $this->{param_list} } unless defined $key;

    # Intercept POSTDATA assignment, and process the JSON data
    if ( $key eq 'POSTDATA' && scalar @value ) {
        $this->_establishJSON( $value[0] );
    }

    return unless defined $key;

    # SMELL:  JSON version is read-only
    #$this->{data}{params}{$key} = $value if defined $value;

    # If key doesn't exist in json data,  the fall back to CGI.
    return $this->{data}{params}{$key}
      if ( defined $this->{data}{params}{$key} );

    # Process
    return $this->SUPER::param(@p);

}

=begin TML

---++ private objectMethod _establishJSON() ->  n/a

Used internally by the web(), topic(), Namespace and method  methods to trigger parsing of the url
and POST data, and sets object variables with the results.

=cut

sub _establishJSON {
    my $this = shift;
    my $foo  = shift;
    my $data;    # = shift;

    # if already initialized, no need to repeat
    return if ( defined $this->{_jsondata} );

    $data = ( ref($foo) eq 'ARRAY' ) ? shift @$foo : $foo;

    $data ||= '{"jsonrpc":"2.0"}';    # Minimal setup
    writeDebug("data=$data") if Foswiki::Request::TRACE;

    $this->initFromString($data);

    my $pathInfo = Foswiki::urlDecode( $this->path_info() );

# Foswiki JSON invocations are defined as having a Namespace (pluginName)
# and method (handler in that plugin). Namespace is set in the query path, method
# is provided in the json data.

    unless ( $pathInfo =~ /^\/?([^\/\.]+)(?:[\/\.](.*))?$/ ) {
        $this->{invalidNamespace} = Foswiki::urlEncode($pathInfo);
        die "invalid namespace";
    }

    my $namespace = $1;

    $this->{namespace} = $namespace;

    # check that this is a http POST
    my $httpMethod = $this->SUPER::method() || 'jsonrpc';
    $this->{_jsonerror} =
      new Foswiki::Contrib::JsonRpcContrib::Error( -32600,
        "Method must be POST" )
      unless $httpMethod =~ /post|jsonrpc/i;

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
      unless defined $this->method();

    writeDebug( "method=" . $this->{_jsondata}{method} )
      if Foswiki::Request::TRACE;

    # must not have any other keys other than these
    foreach my $key ( keys %{ $this->{_jsondata} } ) {
        $this->{_jsonerror} =
          new Foswiki::Contrib::JsonRpcContrib::Error( -32600,
            "Invalid JSON-RPC request - unknown key $key" )
          unless $key =~ /^(jsonrpc|method|params|id)$/;
    }

}

##############################################################################
sub initFromString {
    my ( $this, $data ) = @_;

    # parse json-rpc request
    eval { $this->{_jsondata} = $this->json->decode($data); };

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

sub jsonerror {
    return $_[0]->{_jsonerror};
}

##############################################################################
sub json {
    my $this = shift;

    unless ( defined $this->{json} ) {
        $this->{json} = new JSON;
    }

    return $this->{json};
}

##############################################################################
sub version {
    my ( $this, $value ) = @_;

    $this->{_jsondata}{jsonrpc} = $value if defined $value;
    return $this->{_jsondata}{jsonrpc} || '';
}

##############################################################################
sub id {
    my ( $this, $value ) = @_;

    $this->{_jsondata}{id} = $value if defined $value;
    return $this->{_jsondata}{id} || '';
}

##############################################################################
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
    my $this = shift;

    print STDERR "Request->namespace() returns "
      . ( $this->{namespace} || 'undef' ) . "\n"
      if Foswiki::Request::TRACE;
    return $this->{namespace};

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

    if ( defined $value && !defined $this->{_jsondata} && lc($value) ne 'post' )
    {
        $this->{_jsonerror} =
          new Foswiki::Contrib::JsonRpcContrib::Error( -32600,
            "Method must be POST" );
    }

    unless ( defined $this->{_jsondata} ) {
        return $this->SUPER::method($value);
    }

    $this->{_jsondata}{method} = $value if defined $value;
    return $this->{_jsondata}{method};
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

    print STDERR "Request->web() returns " . ( $this->{web} || 'undef' ) . "\n"
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

    print STDERR "Request->topic() returns "
      . ( $this->{topic} || 'undef' ) . "\n"
      if Foswiki::Request::TRACE;
    return $this->{topic};

}

=begin TML

---++ ObjectMethod invalidWeb() -> "Invalid path component

Returns the bad part of the path, or the entire bad path, depending upon
the parsing process.  Returns undef when the requested web is valid.

   * It does not filter out or encode any illegal characters. Use caution when returning this string to the UI.

This is read only.

=cut

sub invalidWeb {
    my $this = shift;
    return $this->{invalidWeb};
}

=begin TML

---++ ObjectMethod invalidTopic() -> "Invalid requested topic"

Returns the invalid topic name, when the parser is able to identify it as a topic.
Returns undef when the requested topic is valid.

   * It does not filter out or encode any illegal characters. Use caution when returning this string to the UI.

This is read only.

=cut

sub invalidTopic {
    my $this = shift;
    return $this->{invalidTopic};
}

=begin TML

---++ private objectMethod _establishAddress() ->  n/a

Used internally by the web() and topic() methods to trigger parsing of the url and/or topic= parameter
and set object variables with the results.

=cut

sub _establishAddress {
    my $this = shift;

    # Allow topic= query param to override the path
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


