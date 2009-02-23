# See bottom of file for license and copyright information
=begin TML

---+!! package Foswiki::UI

Coordinator of execution flow and service functions used by the UI packages

=cut

package Foswiki::UI;
use strict;

BEGIN {
    $Foswiki::cfg{SwitchBoard} ||= {};
    $Foswiki::cfg{SwitchBoard}{attach} =
      [ 'Foswiki::UI::Upload', 'attach', { attach => 1 } ];
    $Foswiki::cfg{SwitchBoard}{changes} =
      [ 'Foswiki::UI::Changes', 'changes', { changes => 1 } ];
    $Foswiki::cfg{SwitchBoard}{edit} =
      [ 'Foswiki::UI::Edit', 'edit', { edit => 1 } ];
    $Foswiki::cfg{SwitchBoard}{login} =
      [ undef, 'logon', { ( login => 1, logon => 1 ) } ];
    $Foswiki::cfg{SwitchBoard}{logon} =
      [ undef, 'logon', { ( login => 1, logon => 1 ) } ];
    $Foswiki::cfg{SwitchBoard}{manage} =
      [ 'Foswiki::UI::Manage', 'manage', { manage => 1 } ];
    $Foswiki::cfg{SwitchBoard}{oops} =
      [ 'Foswiki::UI::Oops', 'oops_cgi', { oops => 1 } ];
    $Foswiki::cfg{SwitchBoard}{preview} =
      [ 'Foswiki::UI::Preview', 'preview', { preview => 1 } ];
    $Foswiki::cfg{SwitchBoard}{rdiffauth} =
      [ 'Foswiki::UI::RDiff', 'diff', { diff => 1 } ];
    $Foswiki::cfg{SwitchBoard}{rdiff} =
      [ 'Foswiki::UI::RDiff', 'diff', { diff => 1 } ];
    $Foswiki::cfg{SwitchBoard}{register} =
      [ 'Foswiki::UI::Register', 'register_cgi', { register => 1 } ];
    $Foswiki::cfg{SwitchBoard}{rename} =
      [ 'Foswiki::UI::Manage', 'rename', { rename => 1 } ];
    $Foswiki::cfg{SwitchBoard}{resetpasswd} =
      [ 'Foswiki::UI::Register', 'resetPassword', { resetpasswd => 1 } ];
    $Foswiki::cfg{SwitchBoard}{rest} =
      [ 'Foswiki::UI::Rest', 'rest', { rest => 1 } ];
    $Foswiki::cfg{SwitchBoard}{save} =
      [ 'Foswiki::UI::Save', 'save', { save => 1 } ];
    $Foswiki::cfg{SwitchBoard}{search} =
      [ 'Foswiki::UI::Search', 'search', { search => 1 } ];
    $Foswiki::cfg{SwitchBoard}{statistics} =
      [ 'Foswiki::UI::Statistics', 'statistics', { statistics => 1 } ];
    $Foswiki::cfg{SwitchBoard}{upload} =
      [ 'Foswiki::UI::Upload', 'upload', { upload => 1 } ];
    $Foswiki::cfg{SwitchBoard}{viewauth} =
      [ 'Foswiki::UI::View', 'view', { view => 1 } ];
    $Foswiki::cfg{SwitchBoard}{viewfile} =
      [ 'Foswiki::UI::View', 'viewfile', { viewfile => 1 } ];
    $Foswiki::cfg{SwitchBoard}{view} =
      [ 'Foswiki::UI::View', 'view', { view => 1 } ];
}

use Error qw(:try);
use Assert;

use Foswiki;
use Foswiki::Request;
use Foswiki::Response;
use Foswiki::OopsException;
use Foswiki::EngineException;
use CGI;

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
    unless ( defined $dispatcher && ref($dispatcher) eq 'ARRAY' ) {
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
    my ( $package, $function, $context ) = @$dispatcher;

    if ( $package && !$isInitialized{$package} ) {
        eval qq(use $package);
        die $@ if $@;
        $isInitialized{$package} = 1;
    }

    my $sub;
    $sub = $package . '::' if $package;
    $sub .= $function;

    if ( UNIVERSAL::isa( $Foswiki::engine, 'Foswiki::Engine::CLI' ) ) {
        $context->{command_line} = 1;
    }

    $res = execute( $req, \&$sub, %$context );
    return $res;
}

=begin TML

---++ StaticMethod execute($req, $sub, %initialContext) -> $res

Creates a Foswiki session object with %initalContext and calls
$sub method. Returns the Foswiki::Response object generated

=cut

sub execute {
    my ( $req, $sub, %initialContext ) = @_;

    my $cache = $req->param('foswiki_redirect_cache');

    # Never trust input data from a query. We will only accept
    # an MD5 32 character string
    if ( $cache && $cache =~ /^([a-f0-9]{32})$/ ) {
        $cache = $1;

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
        }
        else {
            print STDERR "Passthru: Could not find $passthruFilename\n"
              if TRACE_PASSTHRU;
        }
    }

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
    $session->{users}->{loginManager}->login( $session->{request}, $session );
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
        throw Foswiki::OopsException(
            'accessdenied', status => 403,
            def    => 'topic_access',
            web    => $web,
            topic  => $topic,
            params => [ $mode, $session->security->getReason() ]
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
    execute( Foswiki::Request->new(), \&$method, %context );
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
