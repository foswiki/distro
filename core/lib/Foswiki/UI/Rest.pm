# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::UI::Rest

UI delegate for REST interface

=cut

package Foswiki::UI::Rest;
use v5.14;

use Foswiki ();
use Try::Tiny;
use Foswiki::PageCache ();

use Foswiki::Class;
extends qw(Foswiki::UI);

our %restDispatch;

# Used by Plugin diagnostics to access all the registered handlers
sub getRegisteredHandlers {
    return \%restDispatch;
}

=begin TML

---++ StaticMethod registerRESTHandler( $subject, $verb, \&fn, %options )

Adds a function to the dispatch table of the REST interface
for a given subject. See System.CommandAndCGIScripts#rest for more info.

   * =$subject= - The subject under which the function will be registered.
   * =$verb= - The verb under which the function will be registered.
   * =\&fn= - Reference to the function.

The handler function must be of the form:
<verbatim>
sub handler($app, $subject, $verb, $response) -> $text
</verbatim>
where:
   * =$app= - a reference to the Foswiki application object
   * =$subject= - The invoked subject (may be ignored)
   * =$verb= - The invoked verb (may be ignored)
   * =$response= reference to the Foswiki::Response object that is used to compose a reply to the request

If the =redirectto= parameter is not present on the REST request, then the return
value from the handler is used to determine the endpoint for the
request. It can be:
   * =undef= - causes the core to assume the handler handled the complete
     request i.e. the core will not generate any response to the request
   * =text= - any other non-undef value will be written out as the content
     of an HTTP 200 response. Only the standard headers in the response are
     written.

Additional options are set in the =%options= hash. These options are important
to ensuring that requests to your handler can't be used in cross-scripting
attacks, or used for phishing.
   * =authenticate= - use this boolean option to require authentication for the
     handler. If this is set, then an authenticated session must be in place
     or the REST call will be rejected with a 401 (Unauthorized) status code.
     By default, rest handlers do *not* require authentication.
   * =validate= - use this boolean option to require validation of any requests
     made to this handler.
     By default, requests made to REST handlers are not validated.
   * =http_allow= use this option to specify the HTTP methods that can
     be used to invoke the handler.

=cut

sub registerRESTHandler {
    my ( $subject, $verb, $fnref, %options ) = @_;

    $restDispatch{$subject}{$verb} = {
        function => $fnref,
        %options
    };
}

sub rest {
    my $this = shift;

    my $app = $this->app;
    my $req = $app->request;
    my $res = $app->response;
    my $env = $app->env;
    my $err;

    # Referer is useful for logging REST request errors
    my $referer = ( defined $env->{HTTP_REFERER} ) ? $env->{HTTP_REFERER} : '';

    return
      if $app->satisfiedByCache( 'rest', $req->web, $req->topic );

    Foswiki::Func::writeDebug(
        "computing REST for " . $req->web . "." . $req->topic )
      if Foswiki::PageCache::TRACE();

    # Foswiki rest invocations are defined as having a subject (pluginName)
    # and verb (restHandler in that plugin). Make sure the path_info is
    # well-structured.
    if ( $req->invalidSubject || $req->invalidVerb ) {

        my $errDetail =
          $req->invalidSubject
          ? "subject " . $req->invalidSubject
          : "verb " . $req->invalidVerb;

        $res->header( -type => 'text/html', -status => '400' );
        $err =
            "ERROR: (400) Invalid REST invocation - "
          . $errDetail
          . " is malformed\n";
        $res->print($err);
        $app->logger->log( 'warning', "REST rejected: " . $err,
            " - $referer", );
        _listHandlers($res) if $app->inContext('command_line');
        Foswiki::EngineException->throw(
            status   => 400,
            reason   => $err,
            response => $res
        );
    }

    # Implicit untaint OK - validated later
    my ( $subject, $verb ) = ( $req->subject, $req->verb );
    if ( $req->invalidVerb() ) {

        $res->header( -type => 'text/html', -status => '400' );
        $err =
            "ERROR: (400) Invalid REST invocation - Verb: "
          . $req->invalidVerb()
          . " is malformed\n";
        $res->print($err);
        $app->logger->log( 'warning', "REST rejected: " . $err,
            " - $referer", );
        _listHandlers($res) if $app->inContext('command_line');
        throw Foswiki::EngineException( 400, $err, $res );
    }

    my $record = $restDispatch{$subject}{$verb};

    # Check we have this handler
    unless ($record) {

        $res->header( -type => 'text/html', -status => '404' );
        $err =
          'ERROR: (404) Invalid REST invocation - '
          . $req->pathInfo    # SMELL Insecure, must be encoded!
          . ' does not refer to a known handler';
        _listHandlers($res) if $app->inContext('command_line');
        $app->logger->log( 'warning', "REST rejected: " . $err,
            " - $referer", );
        Foswiki::EngineException->throw(
            status   => 404,
            reason   => $err,
            response => $res
        );
    }

    # SMELL: The SubscribePlugin abuses the topic= url param, passing
    # in an asterisk wildcard to requst subscription to all topics.
    # The plugin should use a subscribe_topic parameter rather than
    # abusing the system parsed topic parameter.

    #if ( $req->invalidTopic() ) {
    #    $res->header( -type => 'text/html', -status => '400' );
    #    $err =
    #        'ERROR: (400) Invalid REST invocation'
    #      . " - Invalid topic parameter "
    #      . $req->invalidTopic() . "\n";
    #    $res->print($err);
    #    $session->logger->log( 'warning', "REST rejected: " . $err,
    #        " - $referer", );
    #    throw Foswiki::EngineException( 400, $err, $res );
    #}

    if ( $req->invalidWeb() ) {
        $res->header( -type => 'text/html', -status => '400' );
        $err =
            'ERROR: (400) Invalid REST invocation'
          . " - Invalid topic parameter Web part: "
          . $req->invalidWeb() . "\n";
        $res->print($err);
        $app->logger->log( 'warning', "REST rejected: " . $err,
            " - $referer", );
        throw Foswiki::EngineException( 400, $err, $res );
    }

    # Log warnings if defaults are needed.
    if (   !defined $record->{http_allow}
        || !defined $record->{authenticate}
        || !defined $record->{validate} )
    {
        my $msg;
        if ( $app->cfg->data->{LegacyRESTSecurity} ) {
            $msg =
'WARNING: This REST handler does not specify http_allow, validate and/or authenticate.   LegacyRESTSecurity is enabled.  This handler may be insecure and should be examined:';
        }
        else {
            $msg =
'WARNING: This REST handler does not specify http_allow, validate and/or authenticate. Foswiki has chosen secure defaults:';
            $record->{http_allow} = 'POST' unless defined $record->{http_allow};
            $record->{authenticate} = 1 unless defined $record->{authenticate};
            $record->{validate}     = 1 unless defined $record->{validate};
        }
        $app->logger->log( 'warning', $msg, " $subject/$verb - $referer", );
    }

    # Check the method is allowed
    if ( $record->{http_allow} && defined $req->method() ) {
        unless ( $app->inContext('command_line') ) {
            my %allowed =
              map { $_ => 1 } split( /[,\s]+/, $record->{http_allow} );
            unless ( $allowed{ uc( $req->method() ) } ) {
                $res->header( -type => 'text/html', -status => '405' );
                $err =
                    'ERROR: (405) Bad Request: '
                  . uc( $req->method() )
                  . ' denied';
                $app->logger->log(
                    'warning',
                    "REST rejected: " . $err,
                    " $subject/$verb - $referer",
                );
                $res->print($err);
                Foswiki::EngineException->throw(
                    status   => 405,
                    reason   => $err,
                    response => $res
                );
            }
        }
    }

    # Check someone is logged in
    if ( $record->{authenticate} ) {

        # no need to exempt cli.  LoginManager sets authenticated correctly.
        unless ( $app->inContext('authenticated')
            || $app->cfg->data->{LoginManager} eq 'none' )
        {
            $res->header( -type => 'text/html', -status => '401' );
            $err =
              "ERROR: (401) "
              . $req->pathInfo    # SMELL Insecure, must be encoded!
              . " requires you to be logged in";
            $app->logger->log(
                'warning',
                "REST rejected: " . $err,
                " $subject/$verb - $referer"
            );
            $res->print($err);
            Foswiki::EngineException->throw(
                status   => 401,
                reason   => $err,
                response => $res
            );
        }
    }

    # Validate the request
    # SMELL: We can't use Foswiki::UI::checkValidationKey.
    # The common reoutine expires the key, but if we expired it,
    # then subsequent requests using the same code would have to be
    # interactively confirmed, which isn't really an option with
    # an XHR.  Also, the common routine throws a ValidationException
    # and we want a simple engine exception here.
    if (   $record->{validate}
        && $app->cfg->data->{Validation}{Method} ne 'none'
        && !$app->inContext('command_line')
        && uc( $req->method() eq 'POST' ) )
    {

        my $nonce = $req->param('validation_key');
        if (
            !defined($nonce)
            || !Foswiki::Validation::isValidNonce(
                $app->users->getCGISession(), $nonce
            )
          )
        {
            $res->header( -type => 'text/html', -status => '403' );
            $err = "ERROR: (403) Invalid validation code";
            $app->logger->log(
                'warning',
                "REST rejected: " . $err,
                " $subject/$verb - $referer"
            );
            $res->print($err);
            Foswiki::EngineException->throw(
                status   => 403,
                reason   => $err,
                response => $res
            );
        }
    }

    my $function = $record->{function};

    $app->logger->log(
        {
            level    => 'info',
            action   => 'rest',
            webTopic => $req->web . '.' . $req->topic,
            extra    => "$subject $verb",
        }
    );

    my $result;
    my $error = 0;

    try {
        $result = $function->( $app, $subject, $verb, $app->response );
    }
    catch {
        my $e = $_;

        # Note: we're *not* catching Error here, just Error::Simple
        # so we catch things like OopsException
        # SMELL Actually OopsException was inheriting from Error, not
        # Error::Simple. Not sure how to handle it here but would try to follow
        # the pre-Moo pattern.
        if (
            !ref($e)
            || (   !$e->isa('Foswiki::AccessControlException')
                && !$e->isa('Foswiki::OopsException') )
          )
        {
            $app->response->header(
                -status  => 500,
                -type    => 'text/plain',
                -charset => 'UTF-8'
            );
            $app->response->print( 'ERROR: (500) Internal server error - '
                  . ( ref($_) ? $_->stringify : $_ ) );
            $error = 1;
        }
        else {
            $e->rethrow;
        }
    };

    if ( !$error ) {

        # endpoint is now deprecated, but may still be
        # used by old rest handlers to redirect to an alternate topic.
        # Note that this might be better validated before dispatching
        # the rest handler however come handlers modify
        # the endPoint and validating it early fails.

        # endPoint still supported for compatibility
        my $target = $app->redirectto( scalar( $req->param('endPoint') ) );

        if ( defined($target) ) {
            $app->redirect($target);
        }
        else {
            if (   defined $req->param('redirectto')
                || defined $req->param('endPoint') )
            {
                $app->response->header(
                    -status  => 403,
                    -type    => 'text/plain',
                    -charset => 'UTF-8'
                );
                $app->response->print(
                        'ERROR: (403) Invalid REST invocation - '
                      . ' redirectto does not refer to a valid redirect target'
                );
                return;
            }
        }
    }

    if ($result) {

        # If the handler doesn't want to handle all the details of the
        # response, they can return a page here and get it 200'd
        $app->writeCompletePage($result);
    }

    # Otherwise it's assumed that the handler dealt with the response.
}

sub _listHandlers {
    $_[0]->print(
        "\nusage: ./rest /PluginName/restHandler param=value\n\n"
          . join( "\n",
            map { $_ . ' : ' . join( ' , ', keys( %{ $restDispatch{$_} } ) ) }
              keys(%restDispatch) )
          . "\n\n"
    );
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2016 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 1999-2007 Peter Thoeny, peter@thoeny.org
and TWiki Contributors. All Rights Reserved. TWiki Contributors
are listed in the AUTHORS file in the root of this distribution.
Based on parts of Ward Cunninghams original Wiki and JosWiki.
Copyright (C) 1998 Markus Peter - SPiN GmbH (warpi@spin.de)
Some changes by Dave Harris (drh@bhresearch.co.uk) incorporated

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
