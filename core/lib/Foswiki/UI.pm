# See bottom of file for license and copyright information

=begin TML

---+!! package Foswiki::UI

Coordinator of execution flow and service functions used by the UI packages

=cut

package Foswiki::UI;
use v5.14;

use Try::Tiny;
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
use Foswiki::Exception              ();
use Foswiki::Request::Cache         ();

use Moo;
use namespace::clean;
extends qw(Foswiki::Object);
with qw(Foswiki::AppObject);

# Used to lazily load UI handler modules
#has isInitialized => ( is => 'rw', lazy => 1, default => sub { {} }, );

use constant TRACE_REQUEST => 0;

=begin TML

---++ ObjectMethod handleRequest -> $res

Main coordinator of request-process-response cycle.

=cut

sub _deprecated_handleRequest {
    my $this = shift;
    my $app  = $this->app;
    my $req  = $app->request;

    my $res;

    my $dispatcher = $app->cfg->data->{SwitchBoard}{ $req->action() };
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

    if ( $dispatcher->{package}
        && !$this->isInitialized->{ $dispatcher->{package} } )
    {
        eval qq(use $dispatcher->{package});
        die Foswiki::encode_utf8($@) if $@;
        $this->isInitialized->{ $dispatcher->{package} } = 1;
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
    $res = $this->_execute( \&$sub, %{ $dispatcher->{context} } );
    return $res;
}

=begin TML

---++ ObjectMethod _execute($sub, %initialContext) -> $res

Creates a Foswiki session object with %initalContext and calls
$sub method. Returns the Foswiki::Response object.

=cut

sub _execute {
    my $this = shift;
    my ( $req, $sub, %initialContext ) = @_;

    my $app = $this->app;

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

        $app = new Foswiki(
            ( defined $ENV{GATEWAY_INTERFACE} || defined $ENV{MOD_PERL} )
            ? undef
            : $req->remoteUser(),
            $req, \%initialContext
        );

        $res = $app->response;

        unless ( defined $res->status() && $res->status() =~ m/^\s*3\d\d/ ) {
            $app->getLoginManager()->checkAccess();
            &$sub($app);
        }
    }
    catch {
        my $e = $_;
        if ( $e->isa('Foswiki::ValidationException') ) {

            $app ||= $Foswiki::Plugins::SESSION;
            $res = $app->response if $app;
            $res ||= new Foswiki::Response();

            my $query = $app->request;

            # Cache the original query, so we can complete if if it is
            # confirmed
            my $uid = Foswiki::Request::Cache->new()->save($query);

            print STDERR "ValidationException: redirect with $uid\n"
              if DEBUG;

            # We use the login script for validation because it already
            # has the correct criteria in httpd.conf for Apache login.
            # URL is absolute as required by
            # http://tools.ietf.org/html/rfc2616#section-14.30
            my $url = $app->cfg->getScriptUrl(
                1,             'login',
                $app->webName, $app->topicName,
                foswikiloginaction   => 'validate',
                foswikioriginalquery => $uid
            );

            $app->redirect($url);    # no passthrough
        }
        elsif ( $e->isa('Foswiki::AccessControlException') ) {
            $app ||= $Foswiki::Plugins::SESSION;
            $res = $app->response if $app;
            $res ||= new Foswiki::Response();

            unless ( $app->getLoginManager()->forceAuthentication() ) {

                # Login manager did not want to authenticate, perhaps because
                # we are already authenticated.
                my $exception = new Foswiki::OopsException(
                    'accessdenied',
                    status => 403,
                    web    => $e->web,
                    topic  => $e->topic,
                    def    => 'topic_access',
                    params => [ $e->mode, $e->reason ]
                );

                $exception->generate($app);
            }
        }
        elsif ( $e->isa('Foswiki::OopsException') ) {

            $app ||= $Foswiki::Plugins::SESSION;
            $res = $app->response if $app;
            $res ||= new Foswiki::Response();

            $e->generate($app);
        }
        elsif ( $e->isa('Foswiki::EngineException') ) {
            $app ||= $Foswiki::Plugins::SESSION;
            $res = $e->response;

            # Note: do *not* use the response from the session; see notes above
            unless ( defined $res ) {
                $res = new Foswiki::Response();
                $res->header(
                    -type   => 'text/html',
                    -status => $e->status
                );
                my $html = CGI::start_html( $e->status . ' Bad Request' );
                $html .= CGI::h1( {}, 'Bad Request' );
                $html .= CGI::p( {}, $e->reason );
                $html .= CGI::end_html();
                $res->print( Foswiki::encode_utf8($html) );
            }
            $Foswiki::engine->finalizeError( $res, $app->request );
        }
        elsif ( $e->isa('Foswiki::Exception') or $e->isa('Error') ) {

            # Most usually a 'die'

            $app ||= $Foswiki::Plugins::SESSION;
            $res = $app->response if $app;
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
                $app->logger->log( 'warning', $mess ) if $app;

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
        else {

            # Aargh! Should never get here
            $res = new Foswiki::Response;
            $res->header( -type => 'text/plain' );
            $res->print("Unspecified internal error\n\n");
            if (DEBUG) {
                eval "require Data::Dumper";
                $res->print( Data::Dumper::Dumper( \$e ) );
            }
        }
    };
    undef $app;
    return $res;
}

=begin TML

---++ StaticMethod logon($app)

Handler for "logon" action.
   * =$app= is a Foswiki session object

=cut

sub logon {
    my $this = shift;
    my $app  = $this->app;
    my $req  = $app->request;

    if ( defined $Foswiki::cfg{LoginManager}
        && $Foswiki::cfg{LoginManager} eq 'none' )
    {
        throw Foswiki::OopsException(
            template => 'attention',
            status   => 500,
            def      => 'login_disabled',
        );
    }

    my $action = $req->param('foswikiloginaction');
    $req->delete('foswikiloginaction');

    if ( defined $action && $action eq 'validate' ) {
        Foswiki::Validation::validate($app);
    }
    else {
        $app->users->loginManager->login;
    }
}

=begin TML

---++ ObjectMethod checkWebExists( $web [, $op] )

Check if the web exists. If it doesn't, will throw an oops exception.

 $op is the user operation being performed. $app->request->action is used if $op
 is undef.

=cut

sub checkWebExists {
    my $this = shift;
    my ( $webName, $op ) = @_;

    my $app = $this->app;
    $op //= $app->request->action;

    if ( $app->request->invalidWeb ) {
        throw Foswiki::OopsException(
            'accessdenied',
            status => 404,
            def    => 'bad_web_name',
            web    => $webName,
            topic  => $Foswiki::cfg{WebPrefsTopicName},
            params => [ $op, $app->request->invalidWeb ]
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

    unless ( $app->store->webExists($webName) ) {
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

---++ ObjectMethod topicExists( $web, $topic [, $op] ) => boolean

Check if the given topic exists, throwing an OopsException if it doesn't. $op is
the user operation being performed. $app->request->action is used if $op is
undef.

=cut

sub checkTopicExists {
    my $this = shift;
    my ( $web, $topic, $op ) = @_;

    my $app = $this->app;
    $op //= $app->request->action;

    if ( $app->request->invalidTopic ) {
        throw Foswiki::OopsException(
            'accessdenied',
            status => 404,
            def    => 'invalid_topic_name',
            web    => $web,
            topic  => $topic,
            params => [ $op, $app->request->invalidTopic ]
        );
    }

    unless ( $app->topicExists( $web, $topic ) ) {
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

---++ ObjectMethod checkAccess( $mode, $topicObject )

Check if the given mode of access by the given user to the given
web.topic is permissible, throwing a Foswiki::AccessControlException if not.

=cut

sub checkAccess {
    my $this = shift;
    my ( $mode, $topicObject ) = @_;

    my $app = $this->app;

    unless ( $topicObject->haveAccess($mode) ) {
        throw Foswiki::AccessControlException( $mode, $app->user,
            $topicObject->web, $topicObject->topic, $Foswiki::Meta::reason );
    }
}

=begin TML

---++ ObjectMethod checkValidationKey

Check the validation key for the given action. Throws an exception
if the validation key isn't valid (handled in _execute(), above)
   * =$app= - the current session object

See Foswiki::Validation for more information.

=cut

sub checkValidationKey {
    my $this = shift;

    my $app = $this->app;

    # If validation is disabled, do nothing
    return if ( $Foswiki::cfg{Validation}{Method} eq 'none' );

    # No point in command-line mode
    return if $app->inContext('command_line');

    # Check the nonce before we do anything else
    my $nonce = $app->request->param('validation_key');
    $app->request->delete('validation_key');
    if (   !defined($nonce)
        || !Foswiki::Validation::isValidNonce( $app->getCGISession(), $nonce ) )
    {
        throw Foswiki::ValidationException( $app->request->action() );
    }
    if ( defined($nonce) && !$app->request->param('preserve_vk') ) {

        # Expire the nonce. If the user tries to use it again, they will
        # be prompted. Note that if preserve_vk is provided we don't
        # expire the nonce - this is to support browsers that don't
        # implement FormData in javascript (such as IE8)
        Foswiki::Validation::expireValidationKeys( $app->getCGISession(),
            $Foswiki::cfg{Validation}{ExpireKeyOnUse} ? $nonce : undef );

        # Write a new validation code into the response
        my $context =
          $app->request->url( -full => 1, -path => 1, -query => 1 ) . time();
        my $cgis = $app->getCGISession();
        if ($cgis) {
            my $nonce =
              Foswiki::Validation::generateValidationKey( $cgis, $context, 1 );
            $app->response->pushHeader( 'X-Foswiki-Validation' => $nonce );
        }
    }
    $app->request->delete('preserve_vk');
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

sub _deprecated_run {
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
