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

use strict;
use warnings;

use Error qw( :try );
use Foswiki::Func                              ();
use Foswiki::Contrib::JsonRpcContrib::Error    ();
use Foswiki::Contrib::JsonRpcContrib::Request  ();
use Foswiki::Contrib::JsonRpcContrib::Response ();

use constant TRACE => 0;    # toggle me

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
    print STDERR $_[0] . "\n";
    Foswiki::Func::writeDebug '- JsonRpcContrib::Server - ' . $_[0];
}

################################################################################
# constructor
sub new {
    my $class = shift;

    my $this = bless( {}, $class );

    return $this;
}

################################################################################
sub registerMethod {
    my ( $this, $namespace, $method, $fnref, $options ) = @_;

    writeDebug("registerMethod($namespace, $method, $fnref)") if TRACE;

    $this->{handler}{$namespace}{$method} = {
        function => $fnref,
        options  => $options
    };
}

################################################################################
sub dispatch {
    my ( $this, $session ) = @_;

    writeDebug("called dispatch") if TRACE;

    $Foswiki::Plugins::SESSION = $session;
    $this->{session} = $session;

    my $request = Foswiki::Func::getRequestObject();

    if ( $request->isa('Foswiki::Request::JSON') ) {
        if ( my $error = $request->jsonerror() ) {
            Foswiki::Contrib::JsonRpcContrib::Response->print(
                $session,
                code    => $error->{code},
                message => $error->{message}
            );
            return;
        }
    }
    else {
        try {
            $request = new Foswiki::Contrib::JsonRpcContrib::Request($session);
        }
        catch Foswiki::Contrib::JsonRpcContrib::Error with {
            my $error = shift;
            Foswiki::Contrib::JsonRpcContrib::Response->print(
                $session,
                code    => $error->{code},
                message => $error->{message}
            );
        };
    }
    return unless defined $request;

    # get handler for this namespace
    my $handler = $this->getHandler($request);
    unless ( defined $handler ) {
        Foswiki::Contrib::JsonRpcContrib::Response->print(
            $session,
            code    => -32601,
            message => "Invalid invocation - unknown handler for "
              . ( $request->namespace() || '' ) . "."
              . ( $request->method() || '' ),
            id => $request->id()
        );
        return;
    }

    # if there's login info, try and apply it
    my $userName = $request->param('username');
    if ($userName) {
        writeDebug("checking password for $userName") if TRACE;
        my $pass = $request->param('password') || '';
        unless ( $session->{users}->checkPassword( $userName, $pass ) ) {
            Foswiki::Contrib::JsonRpcContrib::Response->print(
                $session,
                code    => 401,
                message => "Access denied",
                id      => $request->id()
            );
            return;
        }

        my $cUID     = $session->{users}->getCanonicalUserID($userName);
        my $wikiName = $session->{users}->getWikiName($cUID);
        $session->{users}->getLoginManager()
          ->userLoggedIn( $userName, $wikiName );
    }

    # validate the request
    if ( $handler->{validate} ) {
        my $nonce = $request->param('validation_key');
        if (
            !defined($nonce)
            || !Foswiki::Validation::isValidNonce(
                $session->getCGISession(), $nonce
            )
          )
        {
            Foswiki::Contrib::JsonRpcContrib::Response->print(
                $session,
                code    => -32600,
                message => "Invalid validation code",
                id      => $request->id()
            );
            return;
        }
    }

    Foswiki::Func::writeEvent( 'jsonrpc',
        $request->namespace() . ' ' . $request->method() );

    # call
    my $code = 0;
    my $result;
    try {
        no strict 'refs';
        my $function = $handler->{function};
        writeDebug( "calling handler for "
              . $request->namespace . "."
              . $request->method )
          if TRACE;
        $result =
          &$function( $session, $request, $session->{response},
            $handler->{options} );
        use strict 'refs';
    }
    catch Foswiki::Contrib::JsonRpcContrib::Error with {
        my $error = shift;
        $result = $error->{message};
        $code   = $error->{code};
    }
    catch Error::Simple with {
        my $error = shift;
        $result = $error->{-text};
        $code   = 1;                 # unknown error
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
              $session->getScriptUrl( 1, 'view', $session->{webName},
                $redirectto );
        }
        $session->redirect($url);
    }
    else {
        Foswiki::Contrib::JsonRpcContrib::Response->print(
            $session,
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

    my $namespace = $request->namespace();
    return unless $namespace;

    my $method = $request->method();
    return unless $method;

    unless ( defined $this->{handler}{$namespace} ) {

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

    return unless defined $this->{handler}{$namespace};

    return $this->{handler}{$namespace}{$method};
}

1;

