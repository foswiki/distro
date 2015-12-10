# JSON-RPC for Foswiki
#
# Copyright (C) 2011-2015 Michael Daum http://michaeldaumconsulting.com
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

package Foswiki::Contrib::JsonRpcContrib::Request;

use strict;
use warnings;

use JSON                                    ();
use Encode                                  ();
use Foswiki::Contrib::JsonRpcContrib::Error ();
use Error qw( :try );
use Foswiki::Func    ();
use Foswiki::Plugins ();
use constant TRACE => 0;    # toggle me

###############################################################################
sub new {
    my ( $class, $session ) = @_;

    my $request = $session->{request};

    my $this = bless( {}, $class );

    # get json-rpc request object
    my $data = $request->param('POSTDATA');
    if ($data) {
        $data = toSiteCharSet($data);
    }
    else {

        # minimal setup
        $data = '{"jsonrpc":"2.0"}';
    }
    writeDebug("data=$data") if TRACE;
    $this->initFromString($data);

    # get namespace from path info, maybe separate a REST-like method as well
    my $namespace = $request->pathInfo();
    my $method;
    if ( $namespace =~ /^\/?([^\/]+)(?:\/(.*))?$/ ) {
        $namespace = $1;
        $method    = $2;
    }
    $this->namespace($namespace);
    writeDebug("namespace=$namespace") if TRACE;

    # override json-rpc params using url params
    foreach my $key ( $request->multi_param() ) {
        next if $key =~ /^(POSTDATA|method|id|jsonrpc)$/;  # these are different
        my @vals = map( toSiteCharSet($_), $request->multi_param($key) );
        if ( scalar(@vals) == 1 ) {
            $this->param( $key => $vals[0] )
              ;    # set json-rpc params using url params
        }
        else {
            $this->param( $key => \@vals )
              ;    # set json-rpc params using url params
        }
    }

    # copy id from url params to  json-rpc request if required
    my $id = $request->param('id') || $this->id();
    $this->id($id) if defined $id;

    # copy method to json-rpc request
    $method = $request->param('method') if defined $request->param("method");
    $this->method($method) if defined $method;

    # check that this is a http POST
    my $httpMethod = $request->method() || "jsonrpc";

    throw Foswiki::Contrib::JsonRpcContrib::Error( -32600,
        "Method must be POST" )
      unless $httpMethod =~ /post|jsonrpc/i;

    # some basic checks if this is a proper json-rpc 2.0 request

    # must have a version tag
    if ( ( $this->version() || '' ) ne "2.0" ) {
        throw Foswiki::Contrib::JsonRpcContrib::Error( -32600,
            "Invalid JSON-RPC request - must be jsonrpc: '2.0'" );
    }

    # must have a method
    throw Foswiki::Contrib::JsonRpcContrib::Error( -32600,
        "Invalid JSON-RPC request - no method" )
      unless defined $this->method();

    writeDebug( "method=" . $this->method() ) if TRACE;

    # must not have any other keys other than these
    foreach my $key ( keys %{ $this->{data} } ) {
        throw Foswiki::Contrib::JsonRpcContrib::Error( -32600,
            "Invalid JSON-RPC request - unknown key $key" )
          unless $key =~ /^(jsonrpc|method|params|id)$/;
    }

    return $this;
}

##############################################################################
sub initFromString {
    my ( $this, $data ) = @_;

    # parse json-rpc request
    eval { $this->{data} = $this->json->decode($data); };

    if ($@) {
        my $error = $@;
        $error =~ s/,? +at.*$//s;
        throw Foswiki::Contrib::JsonRpcContrib::Error( -32700,
            "Parse error - invalid json-rpc request: $error" );
    }

    $this->{data}{params} ||= {};

    return $this->{data};
}

##############################################################################
sub version {
    my ( $this, $value ) = @_;

    $this->{data}{jsonrpc} = $value if defined $value;
    return $this->{data}{jsonrpc};
}

##############################################################################
sub id {
    my ( $this, $value ) = @_;

    $this->{data}{id} = $value if defined $value;
    return $this->{data}{id};
}

##############################################################################
sub param {
    my ( $this, $key, $value ) = @_;

    return unless $key;

    $this->{data}{params}{$key} = $value if defined $value;
    return $this->{data}{params}{$key};
}

##############################################################################
sub params {
    return $_[0]->{data}{params};
}

##############################################################################
sub method {
    my ( $this, $value ) = @_;

    $this->{data}{method} = $value if defined $value;
    return $this->{data}{method};
}

##############################################################################
sub namespace {
    my ( $this, $value ) = @_;

    $this->{namespace} = $value if defined $value;
    return $this->{namespace};
}

##############################################################################
sub json {
    my $this = shift;

    unless ( defined $this->{json} ) {
        $this->{json} = new JSON;
    }

    return $this->{json};
}

################################################################################
# static
sub writeDebug {
    Foswiki::Func::writeDebug("- JsonRpcContrib::Request - $_[0]");
}

###############################################################################
sub toSiteCharSet {
    my $string = shift;

    return $string unless $string;

    # Convert to unicode if the core supports it
    return $string if $Foswiki::UNICODE;

    return $string
      if ( $Foswiki::cfg{Site}{CharSet} =~ /^utf-?8/i );

    # If the site charset is not utf-8, need to convert it
    # Leave this code using Encode:: - not used on UNICODE core.
    require Encode;
    return Encode::encode(
        $Foswiki::cfg{Site}{CharSet},
        Encode::decode_utf8($string),
        Encode::FB_PERLQQ
    );
}

1;
