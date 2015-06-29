# See bottom of file for license and copyright information

=begin TML

---+!! package Foswiki::UI

Coordinator of execution flow and service functions used by the UI packages

=cut

package Foswiki::UI;

use strict;
use warnings;

BEGIN {

    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }

    #Monitor::MARK("Start of BEGIN block in UI.pm");
    $Foswiki::cfg{SwitchBoard} ||= {};

    # package - perl package that contains the method for this request
    # function - name of the function in package
    # context - hash of context vars to define
    # allow - hash of HTTP methods to allow (all others are denied)
    # deny - hash of HTTP methods that are denied (all others are allowed)
    # 'deny' is not tested if 'allow' is defined

    # The switchboard can contain entries either as hashes or as arrays.
    # The array format specifies [0] package, [1] function, [2] context
    # and should be used when declaring scripts from plugins that must work
    # with Foswiki 1.0.0 and 1.0.4.

    $Foswiki::cfg{SwitchBoard}{attach} = {
        package  => 'Foswiki::UI::Attach',
        function => 'attach',
        context  => { attach => 1 },
    };
    $Foswiki::cfg{SwitchBoard}{changes} = {
        package  => 'Foswiki::UI::Changes',
        function => 'changes',
        context  => { changes => 1 },
    };
    $Foswiki::cfg{SwitchBoard}{configure} = {
        package  => 'Foswiki::UI::Configure',
        function => 'configure'
    };
    $Foswiki::cfg{SwitchBoard}{edit} = {
        package  => 'Foswiki::UI::Edit',
        function => 'edit',
        context  => { edit => 1 },
    };
    $Foswiki::cfg{SwitchBoard}{jsonrpc} = {
        package  => 'Foswiki::Contrib::JsonRpcContrib',
        function => 'dispatch',
        context  => { jsonrpc => 1 },
    };
    $Foswiki::cfg{SwitchBoard}{login} = {
        package  => undef,
        function => 'logon',
        context  => { ( login => 1, logon => 1 ) },
    };
    $Foswiki::cfg{SwitchBoard}{logon} = {
        package  => undef,
        function => 'logon',
        context  => { ( login => 1, logon => 1 ) },
    };
    $Foswiki::cfg{SwitchBoard}{manage} = {
        package  => 'Foswiki::UI::Manage',
        function => 'manage',
        context  => { manage => 1 },
        allow    => { POST => 1 },
    };
    $Foswiki::cfg{SwitchBoard}{oops} = {
        package  => 'Foswiki::UI::Oops',
        function => 'oops_cgi',
        context  => { oops => 1 },
    };
    $Foswiki::cfg{SwitchBoard}{preview} = {
        package  => 'Foswiki::UI::Preview',
        function => 'preview',
        context  => { preview => 1 },
    };
    $Foswiki::cfg{SwitchBoard}{previewauth} =
      $Foswiki::cfg{SwitchBoard}{preview};
    $Foswiki::cfg{SwitchBoard}{rdiff} = {
        package  => 'Foswiki::UI::RDiff',
        function => 'diff',
        context  => { diff => 1 },
    };
    $Foswiki::cfg{SwitchBoard}{rdiffauth} = $Foswiki::cfg{SwitchBoard}{rdiff};
    $Foswiki::cfg{SwitchBoard}{register}  = {
        package  => 'Foswiki::UI::Register',
        function => 'register_cgi',
        context  => { register => 1 },

        # method verify must allow GET; protect in Foswiki::UI::Register
        #allow => { POST => 1 },
    };
    $Foswiki::cfg{SwitchBoard}{rename} = {
        package  => 'Foswiki::UI::Rename',
        function => 'rename',
        context  => { rename => 1 },

        # Rename is 2 stage; protect in Foswiki::UI::Rename
        #allow => { POST => 1 },
    };
    $Foswiki::cfg{SwitchBoard}{resetpasswd} = {
        package  => 'Foswiki::UI::Passwords',
        function => 'resetPassword',
        context  => { resetpasswd => 1 },
        allow    => { POST => 1 },
    };
    $Foswiki::cfg{SwitchBoard}{rest} = {
        package  => 'Foswiki::UI::Rest',
        function => 'rest',
        context  => { rest => 1 },
    };
    $Foswiki::cfg{SwitchBoard}{restauth} = $Foswiki::cfg{SwitchBoard}{rest};
    $Foswiki::cfg{SwitchBoard}{save}     = {
        package  => 'Foswiki::UI::Save',
        function => 'save',
        context  => { save => 1 },
        allow    => { POST => 1 },
    };
    $Foswiki::cfg{SwitchBoard}{search} = {
        package  => 'Foswiki::UI::Search',
        function => 'search',
        context  => { search => 1 },
    };
    $Foswiki::cfg{SwitchBoard}{statistics} = {
        package  => 'Foswiki::UI::Statistics',
        function => 'statistics',
        context  => { statistics => 1 },
    };
    $Foswiki::cfg{SwitchBoard}{upload} = {
        package  => 'Foswiki::UI::Upload',
        function => 'upload',
        context  => { upload => 1 },
        allow    => { POST => 1 },
    };
    $Foswiki::cfg{SwitchBoard}{viewfile} = {
        package  => 'Foswiki::UI::Viewfile',
        function => 'viewfile',
        context  => { viewfile => 1 },
    };
    $Foswiki::cfg{SwitchBoard}{viewfileauth} =
      $Foswiki::cfg{SwitchBoard}{viewfile};
    $Foswiki::cfg{SwitchBoard}{view} = {
        package  => 'Foswiki::UI::View',
        function => 'view',
        context  => { view => 1 },
    };
    $Foswiki::cfg{SwitchBoard}{viewauth} = $Foswiki::cfg{SwitchBoard}{view};

    #Monitor::MARK("End of BEGIN block in UI.pm");
}

use Error qw(:try);
use Assert;
use CGI  ();
use JSON ();

use Foswiki                         ();
use Foswiki::Request                ();
use Foswiki::Response               ();
use Foswiki::Infix::Error           ();
use Foswiki::OopsException          ();
use Foswiki::EngineException        ();
use Foswiki::ValidationException    ();
use Foswiki::AccessControlException ();
use Foswiki::Validation             ();

# Used to lazily load UI handler modules
our %isInitialized = ();

use constant TRACE_REQUEST => 0;

=begin TML

---++ StaticMethod handleRequest($req) -> $res

Main coordinator of request-process-response cycle.

=cut

sub handleRequest {
    my $req = shift;

    my $res;

    my $dispatcher = $Foswiki::cfg{SwitchBoard}{ $req->action() };
    unless ( defined $dispatcher ) {
        $res = new Foswiki::Response();
        $res->header( -type => 'text/html', -status => '404' );
        my $html = CGI::start_html('404 Not Found');
        $html .= CGI::h1( {}, 'Not Found' );
        $html .= CGI::p( {},
                "The requested URL "
              . $req->uri
              . " was not found on this server." );
        $html .= CGI::end_html();
        $res->print($html);
        return $res;
    }

    if ( ref($dispatcher) eq 'ARRAY' ) {

        # Old-style array entry in switchboard from a plugin
        my @array = @$dispatcher;
        $dispatcher = {
            package  => $array[0],
            function => $array[1],
            context  => $array[2],
        };
    }

    if ( $dispatcher->{package} && !$isInitialized{ $dispatcher->{package} } ) {
        eval qq(use $dispatcher->{package});
        die Foswiki::encode_utf8($@) if $@;
        $isInitialized{ $dispatcher->{package} } = 1;
    }

    my $sub = '';
    $sub = $dispatcher->{package} . '::' if $dispatcher->{package};
    $sub .= $dispatcher->{function};

    # If the X-Foswiki-Tickle header is present, this request is an
    # attempt to verify that the requested function is available on
    # this Foswiki. Respond with the serialised dispatcher, and
    # finish the request.
    # Need to stringify since VERSION is a version object.
    if ( $req->header('X-Foswiki-Tickle') ) {
        my $data = {
            SCRIPT_NAME => $ENV{SCRIPT_NAME},
            VERSION     => $Foswiki::VERSION->stringify(),
            RELEASE     => $Foswiki::RELEASE,
        };
        my $res = new Foswiki::Response();
        $res->header( -type => 'application/json', -status => '200' );

        my $d = JSON->new->allow_nonref->encode($data);
        $res->print($d);
        return $res;
    }

    # Get the params cache from the path
    my $cache = $req->param('foswiki_redirect_cache');
    if ( defined $cache ) {
        $req->delete('foswiki_redirect_cache');
    }

    # If the path specifies a cache path, use that. It's arbitrary
    # as to which takes precedence (param or path) because we should
    # never have both at once.
    my $path_info = $req->path_info();
    if ( $path_info =~ s#/foswiki_redirect_cache/([a-f0-9]{32})## ) {
        $cache = $1;
        $req->path_info($path_info);
    }

    if ( defined $cache && $cache =~ m/^([a-f0-9]{32})$/ ) {
        require Foswiki::Request::Cache;

        # implicit untaint required, because $cache may be used in a filename.
        # Note that the cache serialises the method and path_info, which
        # will be restored.
        Foswiki::Request::Cache->new()->load( $1, $req );
    }

    if (TRACE_REQUEST) {
        print STDERR "INCOMING "
          . $req->method() . " "
          . $req->url . " -> "
          . $sub . "\n";
        print STDERR "validation_key: "
          . ( $req->param('validation_key') || 'no key' ) . "\n";

        #require Data::Dumper;
        #print STDERR Data::Dumper->Dump([$req]);
    }

    if ( UNIVERSAL::isa( $Foswiki::engine, 'Foswiki::Engine::CLI' ) ) {
        $dispatcher->{context}->{command_line} = 1;
    }
    elsif (
        defined $req->method()
        && (
            (
                defined $dispatcher->{allow}
                && !$dispatcher->{allow}->{ uc( $req->method() ) }
            )
            || ( defined $dispatcher->{deny}
                && $dispatcher->{deny}->{ uc( $req->method() ) } )
        )
      )
    {
        $res = new Foswiki::Response();
        $res->header( -type => 'text/html', -status => '405' );
        $res->print( '<H1>Bad Request:</H1>  The request method: '
              . uc( $req->method() )
              . ' is denied for the '
              . $req->action()
              . ' action.' );
        if ( uc( $req->method() ) eq 'GET' ) {
            $res->print( '<br/><br/>'
                  . 'The <tt><b>'
                  . $req->action()
                  . '</b></tt> script can only be called with the <tt>POST</tt> type method'
                  . '<br/><br/>'
                  . 'For example:<br/>'
                  . '&nbsp;&nbsp;&nbsp;<tt>&lt;form method="post" action="%SCRIPTURL{'
                  . $req->action()
                  . '}%/%WEB%/%TOPIC%"&gt;</tt><br/>'
                  . '<br/><br/>See <a href="http://foswiki.org/System/CommandAndCGIScripts#A_61'
                  . $req->action()
                  . '_61">System.CommandAndCGIScripts</a> for more information.'
            );
        }
        return $res;
    }
    $res = _execute( $req, \&$sub, %{ $dispatcher->{context} } );
    return $res;
}

=begin TML

---++ StaticMethod _execute($req, $sub, %initialContext) -> $res

Creates a Foswiki session object with %initalContext and calls
$sub method. Returns the Foswiki::Response object.

=cut

sub _execute {
    my ( $req, $sub, %initialContext ) = @_;

    my $session;
    my $res;

    # If we get a known exception from new Foswiki(), then it must have
    # come from one of the plugin methods which are called at this
    # time (initPlugin, earlyInitPlugin for example). The
    # setup of the Foswiki object is pretty much complete; we can safely
    # recover it from $Foswiki::Plugins::SESSION and clean it up.
    # Error::Simple and EngineException indicate something more
    # basic, however, that we can't easily clean up.
    # Exception handling note: We need a session and a response for
    # cleanup; depending on where the exception was raised, the session
    # may have to be grabbed from $Foswiki::Plugins. Exception handlers
    # need to be careful about using the response from the session, as
    # it may already be polluted with non-exception-related crud.
    try {

        # DO NOT pass in $req->remoteUser here (even though may seem
        # to be right) because it may occlude the login manager.
        # Exception is when running in CLI environment.

        $session = new Foswiki(
            ( defined $ENV{GATEWAY_INTERFACE} || defined $ENV{MOD_PERL} )
            ? undef
            : $req->remoteUser(),
            $req, \%initialContext
        );

        $res = $session->{response};

        unless ( defined $res->status() && $res->status() =~ m/^\s*3\d\d/ ) {
            $session->getLoginManager()->checkAccess();
            &$sub($session);
        }
    }
    catch Foswiki::ValidationException with {
        my $e = shift;

        $session ||= $Foswiki::Plugins::SESSION;
        $res = $session->{response} if $session;
        $res ||= new Foswiki::Response();

        my $query = $session->{request};

        # Cache the original query, so we can complete if if it is
        # confirmed
        require Foswiki::Request::Cache;
        my $uid = Foswiki::Request::Cache->new()->save($query);

        print STDERR "ValidationException: redirect with $uid\n"
          if DEBUG;

        # We use the login script for validation because it already
        # has the correct criteria in httpd.conf for Apache login.
        # URL is absolute as required by
        # http://tools.ietf.org/html/rfc2616#section-14.30
        my $url = $session->getScriptUrl(
            1,                   'login',
            $session->{webName}, $session->{topicName},
            foswikiloginaction   => 'validate',
            foswikioriginalquery => $uid
        );

        $session->redirect($url);    # no passthrough
    }
    catch Foswiki::AccessControlException with {
        my $e = shift;

        $session ||= $Foswiki::Plugins::SESSION;
        $res = $session->{response} if $session;
        $res ||= new Foswiki::Response();

        unless ( $session->getLoginManager()->forceAuthentication() ) {

            # Login manager did not want to authenticate, perhaps because
            # we are already authenticated.
            my $exception = new Foswiki::OopsException(
                'accessdenied',
                status => 403,
                web    => $e->{web},
                topic  => $e->{topic},
                def    => 'topic_access',
                params => [ $e->{mode}, $e->{reason} ]
            );

            $exception->generate($session);
        }
    }
    catch Foswiki::OopsException with {
        my $e = shift;

        $session ||= $Foswiki::Plugins::SESSION;
        $res = $session->{response} if $session;
        $res ||= new Foswiki::Response();

        $e->generate($session);
    }
    catch Foswiki::EngineException with {
        my $e = shift;
        $session ||= $Foswiki::Plugins::SESSION;
        $res = $e->{response};

        # Note: do *not* use the response from the session; see notes above
        unless ( defined $res ) {
            $res = new Foswiki::Response();
            $res->header( -type => 'text/html', -status => $e->{status} );
            my $html = CGI::start_html( $e->{status} . ' Bad Request' );
            $html .= CGI::h1( {}, 'Bad Request' );
            $html .= CGI::p( {}, $e->{reason} );
            $html .= CGI::end_html();
            $res->print( Foswiki::encode_utf8($html) );
        }
        $Foswiki::engine->finalizeError( $res, $session->{request} );
    }
    catch Error with {

        # Most usually a 'die'
        my $e = shift;

        $session ||= $Foswiki::Plugins::SESSION;
        $res = $session->{response} if $session;
        $res ||= new Foswiki::Response();

        $res->header( -type => 'text/plain', -status => '500' )
          unless $res->outputHasStarted();
        if (DEBUG) {

            # output the full message and stacktrace to the browser
            $res->print( Foswiki::encode_utf8( $e->stringify() ) );
        }
        else {
            my $mess = $e->stringify();
            print STDERR $mess;
            $session->logger->log( 'warning', $mess ) if $session;

            # tell the browser where to look for more help
            my $text =
'Foswiki detected an internal error - please check your Foswiki logs and webserver logs for more information.'
              . "\n\n";
            $mess =~ s/ at .*$//s;

            # cut out pathnames from public announcement
            $mess =~ s#/[\w./]+#path#g unless DEBUG;
            $text .= $mess;
            $res->print( Foswiki::encode_utf8($text) );
        }
    }
    otherwise {

        # Aargh! Should never get here
        my $e = shift;
        $res = new Foswiki::Response;
        $res->header( -type => 'text/plain' );
        $res->print("Unspecified internal error\n\n");
        if (DEBUG) {
            eval "require Data::Dumper";
            $res->print( Data::Dumper::Dumper( \$e ) );
        }
    };
    $session->finish() if $session;
    return $res;
}

=begin TML

---++ StaticMethod logon($session)

Handler for "logon" action.
   * =$session= is a Foswiki session object

=cut

sub logon {
    my $session = shift;

    if ( defined $Foswiki::cfg{LoginManager}
        && $Foswiki::cfg{LoginManager} eq 'none' )
    {
        throw Foswiki::OopsException(
            'attention',
            status => 500,
            def    => 'login_disabled',
        );
    }

    my $action = $session->{request}->param('foswikiloginaction');
    $session->{request}->delete('foswikiloginaction');

    if ( defined $action && $action eq 'validate' ) {
        Foswiki::Validation::validate($session);
    }
    else {
        $session->getLoginManager()->login( $session->{request}, $session );
    }
}

=begin TML

---++ StaticMethod checkWebExists( $session, $web, $op )

Check if the web exists. If it doesn't, will throw an oops exception.
 $op is the user operation being performed.

=cut

sub checkWebExists {
    my ( $session, $webName, $op ) = @_;
    ASSERT( $session->isa('Foswiki') ) if DEBUG;

    if ( $session->{invalidWeb} ) {
        throw Foswiki::OopsException(
            'accessdenied',
            status => 404,
            def    => 'bad_web_name',
            web    => $webName,
            topic  => $Foswiki::cfg{WebPrefsTopicName},
            params => [ $op, $session->{invalidWeb} ]
        );
    }
    unless ($webName) {
        throw Foswiki::OopsException(
            'accessdenied',
            status => 404,
            def    => 'bad_web_name',
            web    => $webName,
            topic  => $Foswiki::cfg{WebPrefsTopicName},
            params => [$op]
        );
    }

    unless ( $session->webExists($webName) ) {
        throw Foswiki::OopsException(
            'accessdenied',
            status => 404,
            def    => 'no_such_web',
            web    => $webName,
            topic  => $Foswiki::cfg{WebPrefsTopicName},
            params => [$op]
        );
    }
}

=begin TML

---++ StaticMethod topicExists( $session, $web, $topic, $op ) => boolean

Check if the given topic exists, throwing an OopsException
if it doesn't. $op is the user operation being performed.

=cut

sub checkTopicExists {
    my ( $session, $web, $topic, $op ) = @_;
    ASSERT( $session->isa('Foswiki') ) if DEBUG;

    if ( $session->{invalidTopic} ) {
        throw Foswiki::OopsException(
            'accessdenied',
            status => 404,
            def    => 'invalid_topic_name',
            web    => $web,
            topic  => $topic,
            params => [ $op, $session->{invalidTopic} ]
        );
    }

    unless ( $session->topicExists( $web, $topic ) ) {
        throw Foswiki::OopsException(
            'accessdenied',
            status => 404,
            def    => 'no_such_topic',
            web    => $web,
            topic  => $topic,
            params => [$op]
        );
    }
}

=begin TML

---++ StaticMethod checkAccess( $session, $mode, $topicObject )

Check if the given mode of access by the given user to the given
web.topic is permissible, throwing a Foswiki::AccessControlException if not.

=cut

sub checkAccess {
    my ( $session, $mode, $topicObject ) = @_;
    ASSERT( $session->isa('Foswiki') ) if DEBUG;

    unless ( $topicObject->haveAccess($mode) ) {
        throw Foswiki::AccessControlException( $mode, $session->{user},
            $topicObject->web, $topicObject->topic, $Foswiki::Meta::reason );
    }
}

=begin TML

---++ StaticMethod checkValidationKey( $session )

Check the validation key for the given action. Throws an exception
if the validation key isn't valid (handled in _execute(), above)
   * =$session= - the current session object

See Foswiki::Validation for more information.

=cut

sub checkValidationKey {
    my ($session) = @_;

    # If validation is disabled, do nothing
    return if ( $Foswiki::cfg{Validation}{Method} eq 'none' );

    # No point in command-line mode
    return if $session->inContext('command_line');

    # Check the nonce before we do anything else
    my $nonce = $session->{request}->param('validation_key');
    $session->{request}->delete('validation_key');
    if ( !defined($nonce)
        || !Foswiki::Validation::isValidNonce( $session->getCGISession(),
            $nonce ) )
    {
        throw Foswiki::ValidationException( $session->{request}->action() );
    }
    if ( defined($nonce) && !$session->{request}->param('preserve_vk') ) {

        # Expire the nonce. If the user tries to use it again, they will
        # be prompted. Note that if preserve_vk is provided we don't
        # expire the nonce - this is to support browsers that don't
        # implement FormData in javascript (such as IE8)
        Foswiki::Validation::expireValidationKeys( $session->getCGISession(),
            $Foswiki::cfg{Validation}{ExpireKeyOnUse} ? $nonce : undef );

        # Write a new validation code into the response
        my $context =
          $session->{request}->url( -full => 1, -path => 1, -query => 1 )
          . time();
        my $cgis = $session->getCGISession();
        if ($cgis) {
            my $nonce =
              Foswiki::Validation::generateValidationKey( $cgis, $context, 1 );
            $session->{response}
              ->pushHeader( 'X-Foswiki-Validation' => $nonce );
        }
    }
    $session->{request}->delete('preserve_vk');
}

=begin TML

---++ StaticMethod run( $method, %context )

Supported for bin scripts that were written for Foswiki < 1.0. The parameters
are a function reference to the UI method to call and initial context.

In Foswiki >= 1.0 it should be replaced by a Config.spec entry such as:

# **PERL H**
# Bin script registration - do not modify
$Foswiki::cfg{SwitchBoard}{publish} = [ "Foswiki::Contrib::Publish", "publish", { publishing => 1 } ];

=cut

sub run {
    my ( $method, %context ) = @_;

    if ( UNIVERSAL::isa( $Foswiki::engine, 'Foswiki::Engine::CLI' ) ) {
        $context{command_line} = 1;
    }
    _execute( Foswiki::Request->new(), $method, %context );
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
Copyright (C) 2005 Martin at Cleaver.org
Copyright (C) 2005-2007 TWiki Contributors

and also based/inspired on Catalyst framework, whose Author is
Sebastian Riedel. Refer to
http://search.cpan.org/~mramberg/Catalyst-Runtime-5.7010/lib/Catalyst.pm
for more credit and liscence details.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
