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

our %restDispatch;

=begin TML=

---++ StaticMethod registerRESTHandler( $subject, $verb, \&fn, %options )

Adds a function to the dispatch table of the REST interface
for a given subject. See System.CommandAndCGIScripts#rest for more info.

   * =$subject= - The subject under which the function will be registered.
   * =$verb= - The verb under which the function will be registered.
   * =\&fn= - Reference to the function.

The handler function must be of the form:
<verbatim>
sub handler(\%session, $subject, $verb) -> $text
</verbatim>
where:
   * =\%session= - a reference to the Foswiki session object (may be ignored)
   * =$subject= - The invoked subject (may be ignored)
   * =$verb= - The invoked verb (may be ignored)

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

=cut=

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

    # Must define topic param in the query to avoid plugins being
    # passed the path_info when the are initialised. We can't affect
    # the path_info, but we *can* persuade Foswiki to ignore it.
    my $topic = $req->param('topic');
    if ($topic) {
        unless ( $topic =~ /\.|\// ) {
            $res->header( -type => 'text/html', -status => '400' );
            $err = 'ERROR: (400) Invalid REST invocation'
              . " - Invalid topic parameter $topic\n";
            $res->print($err);
            throw Foswiki::EngineException( 400, $err, $res );
        }
    }
    else {

        # No topic specified, but we still have to set a topic to stop
        # plugins being passed the subject and verb in place of a topic.
        $session->{webName}   = $Foswiki::cfg{UsersWebName};
        $session->{topicName} = $Foswiki::cfg{HomeTopicName};
    }

    my $cache = $session->{cache};
    my $cachedPage;
    $cachedPage = $cache->getPage( $session->{webName}, $session->{topicName} )
      if $cache;

    if ($cachedPage) {
        print STDERR
          "found REST for $session->{webName}.$session->{topicName} in cache\n"
          if $Foswiki::cfg{Cache}{Debug};

        # render uncacheable areas
        my $text = $cachedPage->{text};
        $cache->renderDirtyAreas( \$text ) if $cachedPage->{isDirty};

        # set status
        my $status = $cachedPage->{status};
        if ( $status == 302 ) {
            $session->{response}->redirect( $cachedPage->{location} );
        }
        else {
            $session->{response}->status($status);
        }

        # set headers
        $session->generateHTTPHeaders( 'rest', $cachedPage->{contentType},
            $text, $cachedPage );

        # send it out
        $session->{response}->print($text);

        $session->logEvent( 'rest',
            $session->{webName} . '.' . $session->{topicName}, '(cached)' );

        return;
    }

    print STDERR
      "computing REST for $session->{webName}.$session->{topicName}\n"
      if $Foswiki::cfg{Cache}{Debug};

    # If there's login info, try and apply it
    my $login = $req->param('username');
    if ($login) {
        my $pass = $req->param('password');
        my $validation = $session->{users}->checkPassword( $login, $pass );
        unless ($validation) {
            $res->header( -type => 'text/html', -status => '401' );
            $err = "ERROR: (401) Can't login as $login";
            $res->print($err);
            throw Foswiki::EngineException( 401, $err, $res );
        }

        my $cUID     = $session->{users}->getCanonicalUserID($login);
        my $WikiName = $session->{users}->getWikiName($cUID);
        $session->{users}->getLoginManager()->userLoggedIn( $login, $WikiName );
    }

    # Check that the REST script is authorised under the standard
    # {AuthScripts} contract
    try {
        $session->getLoginManager()->checkAccess();
    }
    catch Error with {
        my $e = shift;
        $res->header( -type => 'text/html', -status => '401' );
        $err = "ERROR: (401) $e";
        $res->print($err);
        throw Foswiki::EngineException( 401, $err, $res );
    };

    my $pathInfo = $req->path_info();

    # Foswiki rest invocations are defined as having a subject (pluginName)
    # and verb (restHandler in that plugin). Make sure the path_info is
    # well-structured.
    unless ( $pathInfo =~ m#/(.*?)[./]([^/]*)# ) {

        $res->header( -type => 'text/html', -status => '400' );
        $err =
          "ERROR: (400) Invalid REST invocation - $pathInfo is malformed\n";
        $res->print($err);

        $res->print(
            "\nuseage: ./rest /PluginName/restHandler param=value\n\n" . join(
                "\n",
                map {
                    $_ . ' : '
                      . join( ' , ', keys( %{ $restDispatch{$_} } ) )
                  } keys(%restDispatch)
              )
              . "\n\n"
        ) if $session->inContext('command_line');

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
          . $pathInfo
          . ' does not refer to a known handler';
        $res->print($err);
        throw Foswiki::EngineException( 404, $err, $res );
    }

    # Check the method is allowed
    if ( $record->{http_allow} && defined $req->method() ) {
        my %allowed = map { $_ => 1 } split( /[,\s]+/, $record->{http_allow} );
        unless ( $allowed{ uc( $req->method() ) } ) {
            $res->header( -type => 'text/html', -status => '405' );
            $err =
              'ERROR: (405) Bad Request: ' . uc( $req->method() ) . ' denied';
            $res->print($err);
            throw Foswiki::EngineException( 404, $err, $res );
        }
    }

    # Check someone is logged in
    if ( $record->{authenticate} ) {
        unless ( $session->inContext('authenticated')
            || $Foswiki::cfg{LoginManager} eq 'none' )
        {
            $res->header( -type => 'text/html', -status => '401' );
            $err = "ERROR: (401) $pathInfo requires you to be logged in";
            $res->print($err);
            throw Foswiki::EngineException( 401, $err, $res );
        }
    }

    # Validate the request
    if ( $record->{validate} ) {
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
            $res->print($err);
            throw Foswiki::EngineException( 403, $err, $res );
        }

        # SMELL: Note we don't expire the validation code. If we expired it,
        # then subsequent requests using the same code would have to be
        # interactively confirmed, which isn't really an option with
        # an XHR.
    }

    $session->logEvent( 'rest',
        $session->{webName} . '.' . $session->{topicName} );

    no strict 'refs';
    my $function = $record->{function};
    my $result = &$function( $session, $subject, $verb, $session->{response} );
    use strict 'refs';

    # SMELL: does anyone use endPoint? I can't find any evidence of it.
    my $endPoint = $req->param('endPoint');
    if ( defined($endPoint) ) {
        my $nurl = $session->getScriptUrl( 1, 'view', '', $endPoint );
        $session->redirect($nurl);
    }
    elsif ($result) {

        # If the handler doesn't want to handle all the details of the
        # response, they can return a page here and get it 200'd
        $session->writeCompletePage($result);
    }

    # Otherwise it's assumed that the handler dealt with the response.
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
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
