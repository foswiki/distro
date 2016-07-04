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

package Foswiki::Contrib::JsonRpcContrib::Server;
use v5.14;

use Try::Tiny;
use Foswiki::Func                              ();
use Foswiki::Contrib::JsonRpcContrib::Error    ();
use Foswiki::Contrib::JsonRpcContrib::Response ();

use Moo;
use namespace::clean;
extends qw(Foswiki::Object);
with qw(Foswiki::AppObject);

use constant TRACE => 0;    # toggle me

has handler => ( is => 'rw', lazy => 1, default => sub { {} }, );

# Error codes for json-rpc response
# -32700: Parse error - Invalid JSON was received by the server.
# -32600: Invalid Request - The JSON sent is not a valid Request object.
# -32601: Method not found - The method does not exist / is not available.
# -32602: Invalid params - Invalid method parameter(s).
# -32603: Internal error - Internal JSON-RPC error.
# -32099 to -32000: Server error - Reserved for implementation-defined server-errors.
# 0: ok
# 1: unknown error
# 401: access denied
# 404: topic not found

################################################################################
# static
sub writeDebug {
    Foswiki::Func::writeDebug '- JsonRpcContrib::Server - ' . $_[0];
}

################################################################################
sub registerMethod {
    my ( $this, $namespace, $method, $fnref, $options ) = @_;

    writeDebug("registerMethod($namespace, $method, $fnref)") if TRACE;

    $this->handler->{$namespace}{$method} = {
        function => $fnref,
        options  => $options
    };
}

################################################################################
sub dispatch {
    my $this = shift;
    my ($ui) = @_;

    my $app = $ui->app;

    writeDebug("called dispatch") if TRACE;

    my $request = $app->request;

    if ( my $error = $request->jsonerror ) {
        Foswiki::Contrib::JsonRpcContrib::Response->print(
            $app,
            code    => $error->code,
            message => $error->message,
        );
        return;
    }

    # get topic parameter and set the location overriding any
    #  other value derived from the namespace param
    my $topic = $request->param('topic')
      || $Foswiki::cfg{HomeTopicName};
    my ( $jsrpcWeb, $jsrpcTopic ) =
      Foswiki::Func::normalizeWebTopicName( $Foswiki::cfg{UsersWebName},
        $topic );
    $app->request->web($jsrpcWeb);
    $app->request->topic($jsrpcTopic);
    writeDebug("topic=$topic") if TRACE;

    # get handler for this namespace
    my $handler = $this->getHandler($request);
    unless ( defined $handler ) {
        Foswiki::Contrib::JsonRpcContrib::Response->print(
            $app,
            code    => -32601,
            message => "Invalid invocation - unknown handler for "
              . $request->namespace . "."
              . $request->jsonmethod,
            id => $request->id
        );
        return;
    }

    # if there's login info, try and apply it
    my $userName = $request->param('username');
    if ($userName) {
        writeDebug("checking password for $userName") if TRACE;
        my $pass = $request->param('password') || '';
        unless ( $app->users->checkPassword( $userName, $pass ) ) {
            Foswiki::Contrib::JsonRpcContrib::Response->print(
                $app,
                code    => 401,
                message => "Access denied",
                id      => $request->id()
            );
            return;
        }

        my $cUID     = $app->users->getCanonicalUserID($userName);
        my $wikiName = $app->users->getWikiName($cUID);
        $app->users->getLoginManager()->userLoggedIn( $userName, $wikiName );
    }

    # validate the request
    if ( $handler->{validate} ) {
        my $nonce = $request->param('validation_key');
        if (
            !defined($nonce)
            || !Foswiki::Validation::isValidNonce(
                $app->users->getCGISession(), $nonce
            )
          )
        {
            Foswiki::Contrib::JsonRpcContrib::Response->print(
                $app,
                code    => -32600,
                message => "Invalid validation code",
                id      => $request->id()
            );
            return;
        }
    }

    Foswiki::Func::writeEvent( 'jsonrpc',
        $request->namespace() . ' ' . $request->jsonmethod );

    # call
    my $code = 0;
    my $result;
    try {
        no strict 'refs';
        my $function = $handler->{function};
        writeDebug( "calling handler for "
              . $request->namespace . "."
              . $request->jsonmethod )
          if TRACE;
        $result =
          &$function( $app, $request, $app->response, $handler->{options} );
        use strict 'refs';
    }
    catch {
        my $error  = $_;
        my $logStr = '';
        if ( ref($error) ) {
            if ( $error->isa('Foswiki::Contrib::JsonRpcContrib::Error') ) {
                $code = $error->code;
            }
            else {
                $code = 1;    # Unknown error
            }
            if ( $error->isa('Foswiki::Exception') ) {
                $result = $error->text;
                $logStr = $error->stringify;
            }
            else {
                $logStr = $result = $error->stringify;
            }

        }
        else {
            $logStr = $result = $error;
            $code = 1;
        }
        $app->logger->log(
            {
                level => 'error',
                extra => [$logStr],
            }
        );
    };

    # finally
    my $redirectto = $request->param('redirectto');
    if ( $code == 0 && defined $redirectto ) {
        my $url;
        if ( $redirectto =~ /^https?:/ ) {
            $url = $redirectto;
        }
        else {
            $url =
              $app->cfg->getScriptUrl( 1, 'view', $app->request->web,
                $redirectto );
        }
        $app->redirect($url);
    }
    else {
        Foswiki::Contrib::JsonRpcContrib::Response->print(
            $app,
            code    => $code,
            message => $result,
            id      => $request->id()
        );
    }

    return;
}

################################################################################
sub getHandler {
    my ( $this, $request ) = @_;

    my $namespace = $request->namespace;
    return unless $namespace;

    my $method = $request->jsonmethod;
    return unless $method;

    unless ( defined $this->handler->{$namespace} ) {

        # lazy register handler
        if (   defined $Foswiki::cfg{JsonRpcContrib}{Handler}
            && defined $Foswiki::cfg{JsonRpcContrib}{Handler}{$namespace}
            && defined $Foswiki::cfg{JsonRpcContrib}{Handler}{$namespace}
            {$method} )
        {

            my $def =
              $Foswiki::cfg{JsonRpcContrib}{Handler}{$namespace}{$method};

            writeDebug("compiling $def->{package} for $namespace.$method")
              if TRACE;
            eval qq(use $def->{package});

            # disable on error
            if ($@) {
                print STDERR "JsonRPC handler compile error: $@\n";
                $Foswiki::cfg{JsonRpcContrib}{Handler}{$namespace}{$method} =
                  undef;
                return;
            }

            my $sub = $def->{package} . "::" . $def->{function};
            $this->registerMethod( $namespace, $method, \&$sub,
                $def->{options} );
        }
    }

    return unless defined $this->handler->{$namespace};

    return $this->handler->{$namespace}{$method};
}

1;

