# See bottom of file for license and copyright information
=begin TML

---+!! package Foswiki::UI

Coordinator of execution flow and service functions used by the UI packages

=cut

package Foswiki::UI;

use strict;

BEGIN {
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
        package => 'Foswiki::UI::Upload',
        function => 'attach',
        context => { attach => 1 },
    };
    $Foswiki::cfg{SwitchBoard}{changes} = {
        package => 'Foswiki::UI::Changes',
        function => 'changes',
        context => { changes => 1 },
    };
    $Foswiki::cfg{SwitchBoard}{edit} = {
        package => 'Foswiki::UI::Edit',
        function => 'edit',
        context => { edit => 1 },
    };
    $Foswiki::cfg{SwitchBoard}{login} = {
        package => undef,
        function => 'logon',
        context => { ( login => 1, logon => 1 ) },
    };
    $Foswiki::cfg{SwitchBoard}{logon} = {
        package => undef,
        function => 'logon',
        context => { ( login => 1, logon => 1 ) },
    };
    $Foswiki::cfg{SwitchBoard}{manage} = {
        package => 'Foswiki::UI::Manage',
        function => 'manage',
        context => { manage => 1 },
        allow => { POST => 1 },
    };
    $Foswiki::cfg{SwitchBoard}{oops} = {
        package => 'Foswiki::UI::Oops',
        function => 'oops_cgi',
        context => { oops => 1 },
    };
    $Foswiki::cfg{SwitchBoard}{preview} = {
        package => 'Foswiki::UI::Preview',
        function => 'preview',
        context => { preview => 1 },
    };
    $Foswiki::cfg{SwitchBoard}{rdiffauth} = {
        package => 'Foswiki::UI::RDiff',
        function => 'diff',
        context => { diff => 1 },
    };
    $Foswiki::cfg{SwitchBoard}{rdiff} = {
        package => 'Foswiki::UI::RDiff',
        function => 'diff',
        context => { diff => 1 },
    };
    $Foswiki::cfg{SwitchBoard}{register} = {
        package => 'Foswiki::UI::Register',
        function => 'register_cgi',
        context => { register => 1 },
        # method verify must allow GET; protect in Foswiki::UI::Register
        #allow => { POST => 1 },
    };
    $Foswiki::cfg{SwitchBoard}{rename} = {
        package => 'Foswiki::UI::Manage',
        function => 'rename',
        context => { rename => 1 },
        # Rename is 2 stage; protect in Foswiki::UI::Rename
        #allow => { POST => 1 },
    };
    $Foswiki::cfg{SwitchBoard}{resetpasswd} = {
        package => 'Foswiki::UI::Register',
        function => 'resetPassword',
        context => { resetpasswd => 1 },
        allow => { POST => 1 },
    };
    $Foswiki::cfg{SwitchBoard}{rest} = {
        package => 'Foswiki::UI::Rest',
        function => 'rest',
        context => { rest => 1 },
    };
    $Foswiki::cfg{SwitchBoard}{save} = {
        package => 'Foswiki::UI::Save',
        function => 'save',
        context => { save => 1 },
        allow => { POST => 1 },
    };
    $Foswiki::cfg{SwitchBoard}{search} = {
        package => 'Foswiki::UI::Search',
        function => 'search',
        context => { search => 1 },
    };
    $Foswiki::cfg{SwitchBoard}{statistics} = {
        package => 'Foswiki::UI::Statistics',
        function => 'statistics',
        context => { statistics => 1 },
    };
    $Foswiki::cfg{SwitchBoard}{upload} = {
        package => 'Foswiki::UI::Upload',
        function => 'upload',
        context => { upload => 1 },
        allow => { POST => 1 },
    };
    $Foswiki::cfg{SwitchBoard}{viewauth} = {
        package => 'Foswiki::UI::View',
        function => 'view',
        context => { view => 1 },
    };
    $Foswiki::cfg{SwitchBoard}{viewfile} = {
        package => 'Foswiki::UI::View',
        function => 'viewfile',
        context => { viewfile => 1 },
    };
    $Foswiki::cfg{SwitchBoard}{view} = {
        package => 'Foswiki::UI::View',
        function => 'view',
        context => { view => 1 },
    };
}

use Error qw(:try);
use Assert;
use CGI ();

use Foswiki                         ();
use Foswiki::Request                ();
use Foswiki::Response               ();
use Foswiki::OopsException          ();
use Foswiki::EngineException        ();
use Foswiki::ValidationException    ();
use Foswiki::AccessControlException ();
use Foswiki::Validation             ();

# Used to lazily load UI handler modules
our %isInitialized = ();

sub TRACE_PASSTHRU {

    # Change to a 1 to trace passthrough
    0;
}

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
        $html .= CGI::h1('Not Found');
        $html .=
          CGI::p( "The requested URL "
              . $req->uri
              . " was not found on this server." );
        $html .= CGI::end_html();
        $res->print($html);
        return $res;
    }

    if (ref($dispatcher) eq 'ARRAY') {
        # Old-style array entry in switchboard from a plugin
        my @array = @$dispatcher;
        $dispatcher = {
            package  => $array[0],
            function => $array[1],
            context  => $array[2],
        };
    }

    if ( $dispatcher->{package} && !$isInitialized{$dispatcher->{package}} ) {
        eval qq(use $dispatcher->{package});
        die $@ if $@;
        $isInitialized{$dispatcher->{package}} = 1;
    }

    my $sub;
    $sub = $dispatcher->{package} . '::' if $dispatcher->{package};
    $sub .= $dispatcher->{function};

    # Get the params cache from the path
    my $cache = $req->param('foswiki_redirect_cache');

    # If the path specifies a cache path, use that. It's arbitrary
    # as to which takes precedence (param or path) because we should
    # never have both at once.
    my $path_info = $req->path_info();
    if ($path_info =~ s#/foswiki_redirect_cache/([a-f0-9]{32})##) {
        $cache = $1;
        $req->path_info( $path_info );
    }

    if ( defined $cache && $cache =~ /^([a-f0-9]{32})$/ ) {
        $cache = $1; # untaint;

        # Read cached post parameters
        my $passthruFilename =
          $Foswiki::cfg{WorkingDir} . '/tmp/passthru_' . $cache;
        if ( open( F, '<', $passthruFilename ) ) {
            local $/;
            if (TRACE_PASSTHRU) {
                print STDERR "Passthru: Loading cache for ", $req->url(),
                  '?', $req->query_string(), "\n";
                print STDERR <F>, "\n";
                close(F);
                open( F, '<' . $passthruFilename );
            }
            $req->load( \*F );
            close(F);
            unlink($passthruFilename);
            $req->delete('foswiki_redirect_cache');
            print STDERR "Passthru: Loaded and unlinked $passthruFilename\n"
              if TRACE_PASSTHRU;

            $req->method('POST');
        }
        else {
            print STDERR "Passthru: Could not find $passthruFilename\n"
              if TRACE_PASSTHRU;
        }
    }
    #print STDERR "INCOMING ".$req->method()." ".$req->url." -> ".$sub."\n";
    #print STDERR "Validation: ".($req->param('validation_key')||'no key')."\n";
    #require Data::Dumper;
    #print STDERR Data::Dumper->Dump([$req]);
    if ( UNIVERSAL::isa( $Foswiki::engine, 'Foswiki::Engine::CLI' ) ) {
        $dispatcher->{context}->{command_line} = 1;
    } elsif ( defined $req->method()
              && (
                ( defined $dispatcher->{allow}
                  && !$dispatcher->{allow}->{uc($req->method())} )
                ||
                ( defined $dispatcher->{deny}
                  && $dispatcher->{deny}->{uc($req->method())} )
              )
            ) {
        $res = new Foswiki::Response();
        $res->header( -type => 'text/html', -status => '405' );
        $res->print('Bad Request: '.uc($req->method()).' denied for '
                      .$req->action());
        return $res;
    }
    $res = _execute( $req, \&$sub, %{$dispatcher->{context}} );
    return $res;
}

=begin TML

---++ StaticMethod _execute($req, $sub, %initialContext) -> $res

Creates a Foswiki session object with %initalContext and calls
$sub method. Returns the Foswiki::Response object generated

=cut

sub _execute {
    my ( $req, $sub, %initialContext ) = @_;

    # DO NOT pass in $req->remoteUser here (even though it appears to be right)
    # because it may occlude the login manager.
    my $session = new Foswiki( undef, $req, \%initialContext );
    my $res = $session->{response};

    $res->pushHeader( 'X-FoswikiAction' => $req->action() );
    $res->pushHeader( 'X-FoswikiURI'    => $req->uri() );

    unless ( defined $session->{response}->status()
        && $session->{response}->status() =~ /^\s*3\d\d/ )
    {
        try {
            $session->{users}->{loginManager}->checkAccess();
            &$sub($session);
        }
        catch Foswiki::ValidationException with {
            my $e = shift;
            my $query = $session->{request};
            # Redirect with passthrough so we don't lose the
            # original query params. We use the login script for
            # validation because it already has the correct criteria
            # in httpd.conf for Apache login.
            my $url     = $session->getScriptUrl(
                0, 'login', $session->{webName}, $session->{topicName} );
            $query->param( -name => 'validate',
                           -value => 'validate' );
            $query->param( -name => 'origurl',
                           -value => $session->{request}->uri );
            # Pass the action that was invoked to get here so that an
            # appropriate message can be generated
            $query->param( -name => 'context',
                           -value => $e->{action} );
            $session->redirect( $url, 1 );    # with passthrough
        }
        catch Foswiki::AccessControlException with {
            my $e = shift;
            unless ( $session->{users}->{loginManager}->forceAuthentication() )
            {

                # Login manager did not want to authenticate, perhaps because
                # we are already authenticated.
                my $exception = new Foswiki::OopsException(
                    'accessdenied', status => 403,
                    web    => $e->{web},
                    topic  => $e->{topic},
                    def    => 'topic_access',
                    params => [ $e->{mode}, $e->{reason} ]
                );

                $exception->generate($session);
            }
        }
        catch Foswiki::OopsException with {
            shift->generate($session);
        }
        catch Error::Simple with {
            my $e = shift;
            $res = new Foswiki::Response;
            $res->header( -type => 'text/plain' );
            if (DEBUG) {

                # output the full message and stacktrace to the browser
                $res->print( $e->stringify() );
            }
            else {
                my $mess = $e->stringify();
                print STDERR $mess;
                $session->logger->log('warning',$mess);

                # tell the browser where to look for more help
                my $text =
'Foswiki detected an internal error - please check your Foswiki logs and webserver logs for more information.'
                  . "\n\n";
                $mess =~ s/ at .*$//s;

                # cut out pathnames from public announcement
                $mess =~ s#/[\w./]+#path#g;
                $text .= $mess;
                $res->print($text);
            }
        }
        catch Foswiki::EngineException with {
            my $e   = shift;
            my $res = $e->{response};
            unless ( defined $res ) {
                $res = new Foswiki::Response();
                $res->header( -type => 'text/html', -status => $e->{status} );
                my $html = CGI::start_html( $e->{status} . ' Bad Request' );
                $html .= CGI::h1('Bad Request');
                $html .= CGI::p( $e->{reason} );
                $html .= CGI::end_html();
                $res->print($html);
            }
            $Foswiki::engine->finalizeError($res);
            return $e->{status};
        }
        otherwise {
            $res = new Foswiki::Response;
            $res->header( -type => 'text/plain' );
            $res->print("Unspecified error");
        };
    }

    $session->finish();
    return $res;
}

=begin TML

---++ StaticMethod logon($session)

Handler to "logon" action.
   * =$session= is a Foswiki session object

=cut

sub logon {
    my $session = shift;
    if (($session->{request}->param('validate') ||'') eq 'validate'
          # Force login if not recognisably authenticated
          && $session->inContext('authenticated')) {
        Foswiki::Validation::validate( $session );
    } else {
        $session->{users}->{loginManager}->login(
            $session->{request}, $session );
    }
}

=begin TML

---++ StaticMethod checkWebExists( $session, $web, $topic, $op )

Check if the web exists. If it doesn't, will throw an oops exception.
 $op is the user operation being performed.

=cut

sub checkWebExists {
    my ( $session, $webName, $topic, $op ) = @_;
    ASSERT( $session->isa('Foswiki') ) if DEBUG;

    unless ( $session->{store}->webExists($webName) ) {
        throw Foswiki::OopsException(
            'accessdenied', status => 403,
            def    => 'no_such_web',
            web    => $webName,
            topic  => $topic,
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
    my ( $session, $webName, $topic, $op ) = @_;
    ASSERT( $session->isa('Foswiki') ) if DEBUG;

    unless ( $session->{store}->topicExists( $webName, $topic ) ) {
        throw Foswiki::OopsException(
            'accessdenied', status => 403,
            def    => 'no_such_topic',
            web    => $webName,
            topic  => $topic,
            params => [$op]
        );
    }
}

=pod TML

---++ StaticMethod checkAccess( $web, $topic, $mode, $user )

Check if the given mode of access by the given user to the given
web.topic is permissible, throwing a Foswiki::OopsException if not.

=cut

sub checkAccess {
    my ( $session, $web, $topic, $mode, $user ) = @_;
    ASSERT( $session->isa('Foswiki') ) if DEBUG;

    unless (
        $session->security->checkAccessPermission(
            $mode, $user, undef, undef, $topic, $web
        )
      )
    {
        throw Foswiki::AccessControlException(
            $mode, $session->{user},
            $web, $topic,
            $session->security->getReason()
        );
    }
}

=begin TML

---++ StaticMethod readTemplateTopic( $session, $theTopicName ) -> ( $meta, $text )

Read a topic from the Foswiki web, or if that fails from the current
web.

=cut

sub readTemplateTopic {
    my ( $session, $theTopicName ) = @_;
    ASSERT( $session->isa('Foswiki') ) if DEBUG;

    my $web = $Foswiki::cfg{SystemWebName};
    if ( $session->{store}->topicExists( $session->{webName}, $theTopicName ) )
    {

        # try to read from current web, if found
        $web = $session->{webName};
    }
    return $session->{store}
      ->readTopic( $session->{user}, $web, $theTopicName, undef );
}

=pod TML

---++ StaticMethod checkValidationKey( $session )

Check the validation key for the given action. Throws an exception
if the validation key isn't valid (handled in _execute(), above)

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
    if ( defined($nonce) ) {

        # Expire the nonce. If the user tries to use it again, they will
        # be prompted.
        Foswiki::Validation::expireValidationKeys(
            $session->getCGISession(),
            $Foswiki::cfg{Validation}{ExpireKeyOnUse} ? $nonce : undef );
    }
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
    _execute( Foswiki::Request->new(), \&$method, %context );
}

1;
__DATA__
# Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008-2009 Foswiki Contributors. Foswiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
#
# Copyright (C) 1999-2007 Peter Thoeny, peter@thoeny.org
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# Copyright (C) 2005 Martin at Cleaver.org
# Copyright (C) 2005-2007 TWiki Contributors
#
# and also based/inspired on Catalyst framework, whose Author is
# Sebastian Riedel. Refer to
#
# http://search.cpan.org/~mramberg/Catalyst-Runtime-5.7010/lib/Catalyst.pm
#
# for more credit and liscence details.
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
