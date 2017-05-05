# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::UI::Rest

UI delegate for REST interface

=cut

package Foswiki::UI::Rest;

use strict;
use warnings;
use Foswiki ();
use Error qw( :try );
use Foswiki::PageCache ();

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

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
sub handler(\%session, $subject, $verb, $response) -> $text
</verbatim>
where:
   * =\%session= - a reference to the Foswiki session object (may be ignored)
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
    my ( $session, %initialContext ) = @_;

    my $req = $session->{request};
    my $res = $session->{response};
    my $err;

    # Referer is useful for logging REST request errors
    my $referer = ( defined $ENV{HTTP_REFERER} ) ? $ENV{HTTP_REFERER} : '';

    # Must define topic param in the query to avoid plugins being
    # passed the path_info when the are initialised. We can't affect
    # the path_info, but we *can* persuade Foswiki to ignore it.
    my $topic = $req->param('topic');
    if ($topic) {
        unless ( $topic =~ m/\.|\// ) {
            $res->header( -type => 'text/html', -status => '400' );
            $err =
                'ERROR: (400) Invalid REST invocation'
              . " - Invalid topic parameter: "
              . Foswiki::entityEncode($topic) . "\n";
            $res->print($err);
            $session->logger->log( 'warning', "REST rejected: " . $err,
                " - $referer", );
            throw Foswiki::EngineException( 400, $err, $res );
        }
    }
    else {

        # No topic specified, but we still have to set a topic to stop
        # plugins being passed the subject and verb in place of a topic.
        Foswiki::Func::popTopicContext();
        Foswiki::Func::pushTopicContext( $Foswiki::cfg{UsersWebName},
            $Foswiki::cfg{HomeTopicName} );
    }

    return
      if $session->satisfiedByCache( 'rest', $session->{webName},
        $session->{topicName} );

    Foswiki::Func::writeDebug(
        "computing REST for $session->{webName}.$session->{topicName}")
      if Foswiki::PageCache::TRACE();

    my $pathInfo = Foswiki::urlDecode( $req->path_info() );

    # Foswiki rest invocations are defined as having a subject (pluginName)
    # and verb (restHandler in that plugin). Make sure the path_info is
    # well-structured.
    unless ( $pathInfo =~ m#/(.*?)[./]([^/]*)# ) {

        $res->header( -type => 'text/html', -status => '400' );
        $err =
            "ERROR: (400) Invalid REST invocation - "
          . Foswiki::urlEncode($pathInfo)
          . " is malformed\n";
        $res->print($err);
        $session->logger->log( 'warning', "REST rejected: " . $err,
            " - $referer", );
        _listHandlers($res) if $session->inContext('command_line');
        throw Foswiki::EngineException( 400, $err, $res );
    }

    # Implicit untaint OK - validated later
    my ( $subject, $verb ) = ( $1, $2 );

    my $record = $restDispatch{$subject}{$verb};

    # Check we have this handler
    unless ($record) {

        $res->header( -type => 'text/html', -status => '404' );
        $err =
            'ERROR: (404) Invalid REST invocation - '
          . Foswiki::urlEncode($pathInfo)
          . ' does not refer to a known handler';
        _listHandlers($res) if $session->inContext('command_line');
        $session->logger->log( 'warning', "REST rejected: " . $err,
            " - $referer", );
        $res->print($err);
        throw Foswiki::EngineException( 404, $err, $res );
    }

    # Log warnings if defaults are needed.
    if (   !defined $record->{http_allow}
        || !defined $record->{authenticate}
        || !defined $record->{validate} )
    {
        my $msg;
        if ( $Foswiki::cfg{LegacyRESTSecurity} ) {
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
        $session->logger->log( 'warning', $msg, " $subject/$verb - $referer", );
    }

    # Check the method is allowed
    if ( $record->{http_allow} && defined $req->method() ) {
        unless ( $session->inContext('command_line') ) {
            my %allowed =
              map { $_ => 1 } split( /[,\s]+/, $record->{http_allow} );
            unless ( $allowed{ uc( $req->method() ) } ) {
                $res->header( -type => 'text/html', -status => '405' );
                $err =
                    'ERROR: (405) Bad Request: '
                  . uc( $req->method() )
                  . ' denied';
                $session->logger->log(
                    'warning',
                    "REST rejected: " . $err,
                    " $subject/$verb - $referer",
                );
                $res->print($err);
                throw Foswiki::EngineException( 405, $err, $res );
            }
        }
    }

    # Check someone is logged in
    if ( $record->{authenticate} ) {

        # no need to exempt cli.  LoginManager sets authenticated correctly.
        unless ( $session->inContext('authenticated')
            || $Foswiki::cfg{LoginManager} eq 'none' )
        {
            $res->header( -type => 'text/html', -status => '401' );
            $err = "ERROR: (401) $pathInfo requires you to be logged in";
            $session->logger->log(
                'warning',
                "REST rejected: " . $err,
                " $subject/$verb - $referer"
            );
            $res->print($err);
            throw Foswiki::EngineException( 401, $err, $res );
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
        && $Foswiki::cfg{Validation}{Method} ne 'none'
        && !$session->inContext('command_line')
        && uc( $req->method() eq 'POST' ) )
    {

        my $nonce = $req->param('validation_key');
        if (
            !defined($nonce)
            || !Foswiki::Validation::isValidNonce(
                $session->getCGISession(), $nonce
            )
          )
        {
            $res->header( -type => 'text/html', -status => '403' );
            $err = "ERROR: (403) Invalid validation code";
            $session->logger->log(
                'warning',
                "REST rejected: " . $err,
                " $subject/$verb - $referer"
            );
            $res->print($err);
            throw Foswiki::EngineException( 403, $err, $res );
        }
    }

    my $function = $record->{function};

    $session->logger->log(
        {
            level    => 'info',
            action   => 'rest',
            webTopic => $session->{webName} . '.' . $session->{topicName},
            extra    => "$subject $verb",
        }
    );

    my $result;
    my $error = 0;

    try {
        no strict 'refs';
        $result = &$function( $session, $subject, $verb, $session->{response} );
        use strict 'refs';
    }
    catch Error::Simple with {

        # Note: we're *not* catching Error here, just Error::Simple
        # so we catch things like OopsException
        $session->{response}->header(
            -status  => 500,
            -type    => 'text/plain',
            -charset => 'UTF-8'
        );
        $session->{response}->print(
            'ERROR: (500) Internal server error - ' . shift->stringify() );
        $error = 1;
    };

    if ( !$error ) {

        # endpoint is now deprecated, but may still be
        # used by old rest handlers to redirect to an alternate topic.
        # Note that this might be better validated before dispatching
        # the rest handler however come handlers modify
        # the endPoint and validating it early fails.

        # endPoint still supported for compatibility
        my $target = $session->redirectto( scalar( $req->param('endPoint') ) );

        if ( defined($target) ) {
            $session->redirect($target);
        }
        else {
            if (   defined $req->param('redirectto')
                || defined $req->param('endPoint') )
            {
                $session->{response}->header(
                    -status  => 403,
                    -type    => 'text/plain',
                    -charset => 'UTF-8'
                );
                $session->{response}
                  ->print( 'ERROR: (403) Invalid REST invocation - '
                      . ' redirectto does not refer to a valid redirect target'
                  );
                return;
            }
        }
    }

    if ($result) {

        # If the handler doesn't want to handle all the details of the
        # response, they can return a page here and get it 200'd
        $session->writeCompletePage($result);
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

Copyright (C) 2008-2012 Foswiki Contributors. Foswiki Contributors
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
