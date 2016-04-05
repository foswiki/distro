# See bottom of file for license and copyright information

package Foswiki::App;
use v5.14;

use constant TRACE_REQUEST => 0;

use Cwd;
use Try::Tiny;
use Foswiki::Config ();

use Moo;
use namespace::clean;
extends qw(Foswiki::Object);

=begin TML

---+!! Class Foswiki::App

The core class of the project responsible for low-level and code glue
functionality.

=cut

has cfg => (
    is      => 'rw',
    lazy    => 1,
    default => \&_readConfig,
    isa => Foswiki::Object::isaCLASS( 'cfg', 'Foswiki::Config', noUndef => 1, ),
);
has env => (
    is       => 'rw',
    required => 1,
);
has engine => (
    is      => 'rw',
    lazy    => 1,
    default => \&_prepareEngine,
    isa =>
      Foswiki::Object::isaCLASS( 'engine', 'Foswiki::Engine', noUndef => 1, ),
);
has request => (
    is      => 'rw',
    lazy    => 1,
    default => \&_prepareRequest,
    isa =>
      Foswiki::Object::isaCLASS( 'request', 'Foswiki::Request', noUndef => 1, ),
);
has response => (
    is      => 'rw',
    lazy    => 1,
    default => sub { new Foswiki::Response },
    isa     => Foswiki::Object::isaCLASS(
        'response', 'Foswiki::Response', noUndef => 1,
    ),
);
has macros => (
    is      => 'rw',
    lazy    => 1,
    default => sub { return $_[0]->create('Foswiki::Macros'); },
    isa =>
      Foswiki::Object::isaCLASS( 'macros', 'Foswiki::Macros', noUndef => 1, ),
);
has context => (
    is      => 'rw',
    lazy    => 1,
    clearer => 1,
    default => sub { {} },
);
has ui => (
    is      => 'rw',
    lazy    => 1,
    default => sub {
        return $_[0]->create('Foswiki::UI');
    },
);
has _dispatcherObject => (
    is  => 'rw',
    isa => Foswiki::Object::isaCLASS(
        '_dispatcherObject', 'Foswiki::Object', noUndef => 1
    ),
);
has _dispatcherMethod  => ( is => 'rw', );
has _dispatcherContext => ( is => 'rw', );

# App-local $Foswiki::system_message.
has system_message => ( is => 'rw', );

=begin TML

---++ ClassMethod new([%parameters])

The following keys could be defined in =%parameters= hash:

|*Key*|*Type*|*Description*|
|=env=|hashref|Environment hash such as shell environment or PSGI env| 

=cut

around BUILDARGS => sub {
    my $orig   = shift;
    my $class  = shift;
    my %params = @_;

    return $orig->( $class, %params );
};

sub BUILD {
    my $this   = shift;
    my $params = shift;

    $Foswiki::app = $this;

    my $cfg = $this->cfg;
    if ( $cfg->data->{Store}{overrideUmask} && $cfg->data->{OS} ne 'WINDOWS' ) {

# Note: The addition of zero is required to force dirPermission and filePermission
# to be numeric.   Without the additition, certain values of the permissions cause
# runtime errors about illegal characters in subtraction.   "and" with 777 to prevent
# sticky-bits from breaking the umask.
        my $oldUmask = umask(
            (
                oct(777) - (
                    (
                        $cfg->data->{Store}{dirPermission} + 0 |
                          $cfg->data->{Store}{filePermission} + 0
                    )
                ) & oct(777)
            )
        );

#my $umask = sprintf('%04o', umask() );
#$oldUmask = sprintf('%04o', $oldUmask );
#my $dirPerm = sprintf('%04o', $Foswiki::cfg{Store}{dirPermission}+0 );
#my $filePerm = sprintf('%04o', $Foswiki::cfg{Store}{filePermission}+0 );
#print STDERR " ENGINE changes $oldUmask to  $umask  from $dirPerm and $filePerm \n";
    }

    unless ( defined $this->engine ) {
        Foswiki::Exception::Fatal->throw( text => "Cannot initialize engine" );
    }

    unless ( $this->cfg->data->{isVALID} ) {
        $this->cfg->bootstrap;
    }
}

=begin TML

---++ StaticMethod run([%parameters])

Starts application, prepares and initiates request processing. The following
keys could be defined in =%parameters= hash:

|*Key*|*Type*|*Description*|
|=env=|hashref|Environment hash such as shell environment or PSGI env| 

=cut

sub run {
    my $class  = shift;
    my %params = @_;

    # Do nice in shared code environment, localize ALL request-related globals.
    local %Foswiki::app;
    local %Foswiki::cfg;
    local %TWiki::cfg;

    my $app;

    # We use shell environment by default. PSGI would supply its own env
    # hashref.
    $params{env} //= \%ENV;

    # Use current working dir for fetching the initial setlib.cfg
    $params{env}{PWD} //= getcwd;

    try {
        $app = Foswiki::App->new(%params);
        $app->handleRequest;
    }
    catch {
        my $e = $_;

        unless ( ref($e) && $e->isa('Foswiki::Exception') ) {
            $e = Foswiki::Exception->transmute($e);
        }

        # Low-level report of errors to user.
        if ( defined $app && defined $app->engine ) {

            # TODO Send error output to user using the initialized engine.
            $app->engine->write( $e->stringify );
        }
        else {
            # Propagade the error using the most primitive way.
            die( ref($e) ? $e->stringify : $e );
        }
    };
}

sub handleRequest {
    my $this = shift;

    my $req = $this->request;

    try {
        $this->_prepareDispatcher;
        $this->_checkTickle;

        # Get the params cache from the path
        my $cache = $req->param('foswiki_redirect_cache');
        if ( defined $cache ) {
            $req->delete('foswiki_redirect_cache');
        }

        # If the path specifies a cache path, use that. It's arbitrary
        # as to which takes precedence (param or path) because we should
        # never have both at once.
        my $path_info = $req->pathInfo;
        if ( $path_info =~ s#/foswiki_redirect_cache/([a-f0-9]{32})## ) {
            $cache = $1;
            $req->pathInfo($path_info);
        }

        if ( defined $cache && $cache =~ m/^([a-f0-9]{32})$/ ) {

          # implicit untaint required, because $cache may be used in a filename.
          # Note that the cache serialises the method and path_info, which
          # will be restored.
            Foswiki::Request::Cache->new->load( $1, $req );
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

        # XXX TODO vrurg – Continue from here...
        if ( UNIVERSAL::isa( $Foswiki::engine, 'Foswiki::Engine::CLI' ) ) {
            $this->_dispatcherContext->{command_line} = 1;
        }
        elsif (
            defined $req->method
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

        #my $res = Foswiki::UI::handleRequest( $this->request );
    }
    catch {
        my $e = $_;
    }
    finally {
        # Whatever happens at this stage we shall be able to reply with a valid
        # HTTP response using valid HTML.
        $this->engine->finalize( $res, $this->request );
    };
}

=begin TML

--++ ObjectMethod create($className, %initArgs)

Similar to =Foswiki::AppObject::create()= method but for the =Foswiki::App=
itself.

=cut

sub create {
    my $this  = shift;
    my $class = shift;

    #Foswiki::load_class($class);

    unless ( $class->isa('Foswiki::AppObject') ) {
        Foswiki::Exception::Fatal->throw(
            text => "Class $class is not a Foswiki::AppObject descendant." );
    }

    return $class->new( app => $this, @_ );
}

=begin TML

---++ ObjectMethod enterContext( $id, $val )

Add the context id $id into the set of active contexts. The $val
can be anything you like, but should always evaluate to boolean
TRUE.

An example of the use of contexts is in the use of tag
expansion. The commonTagsHandler in plugins is called every
time tags need to be expanded, and the context of that expansion
is signalled by the expanding module using a context id. So the
forms module adds the context id "form" before invoking common
tags expansion.

Contexts are not just useful for tag expansion; they are also
relevant when rendering.

Contexts are intended for use mainly by plugins. Core modules can
use $session->inContext( $id ) to determine if a context is active.

=cut

sub enterContext {
    my ( $this, $id, $val ) = @_;
    $val ||= 1;
    $this->context->{$id} = $val;
}

=begin TML

---++ ObjectMethod leaveContext( $id )

Remove the context id $id from the set of active contexts.
(see =enterContext= for more information on contexts)

=cut

sub leaveContext {
    my ( $this, $id ) = @_;
    my $res = $this->context->{$id};
    delete $this->context->{$id};
    return $res;
}

=begin TML

---++ ObjectMethod inContext( $id )

Return the value for the given context id
(see =enterContext= for more information on contexts)

=cut

sub inContext {
    my ( $this, $id ) = @_;
    return $this->context->{$id};
}

sub _prepareEngine {
    my $this = shift;
    my $env  = $this->env;
    my $engine;

    # Foswiki::Engine has to determine what environment are we run within and
    # return an object of corresponding class.
    $engine = Foswiki::Engine::start( env => $env, app => $this, );

    return $engine;
}

# The request attribute default method.
sub _prepareRequest {
    my $this    = shift;
    my $request = $this->engine->prepare;

    # The following is preferable form of Request creation. The request
    # constructor will then initialize itself using $app->engine as the source
    # of information about the environment we're running under.

    # my $request = Foswiki::Request->prepare(app => $this);
    return $request;
}

sub _readConfig {
    my $this = shift;
    my $cfg = $this->create( 'Foswiki::Config', env => $this->env );
    return $cfg;
}

# Determines what dispatcher to use for the action requested.
sub _prepareDispatcher {
    my $this = shift;
    my $req  = $this->request;

    my $dispatcher = $app->cfg->data->{SwitchBoard}{ $req->action };
    unless ( defined $dispatcher ) {
        $res = $this->response;
        $res->header( -type => 'text/html', -status => '404' );
        my $html = CGI::start_html('404 Not Found');
        $html .= CGI::h1( {}, 'Not Found' );
        $html .= CGI::p( {},
                "The requested URL "
              . $req->uri
              . " was not found on this server." );
        $html .= CGI::end_html();
        $res->print($html);
        Foswiki::Exception::HTTPResponse->throw( status => 404, );
    }

    # SMELL Shouldn't it be deprecated?
    if ( ref($dispatcher) eq 'ARRAY' ) {

        # Old-style array entry in switchboard from a plugin
        my @array = @$dispatcher;
        $dispatcher = {
            package  => $array[0],
            function => $array[1],
            context  => $array[2],
        };
    }

    $dispatcher->{package} //= 'Foswiki::UI';
    $this->_dispatcherObject( $this->create( $dispatcher->{package} ) );
    $this->_dispatcherMethod( $dispatcher->{method}
          || $dispatcher->{function} );
    $this->_dispatcherContext( $dispatcher->{context} );
}

# If the X-Foswiki-Tickle header is present, this request is an attempt to
# verify that the requested function is available on this Foswiki. Respond with
# the serialised dispatcher, and finish the request. Need to stringify since
# VERSION is a version object.
sub _checkTickle {
    my $this = shift;
    my $req  = $this->request;

    if ( $req->header('X-Foswiki-Tickle') ) {
        my $res  = $this->response;
        my $data = {
            SCRIPT_NAME => $ENV{SCRIPT_NAME},
            VERSION     => $Foswiki::VERSION->stringify(),
            RELEASE     => $Foswiki::RELEASE,
        };
        $res->header( -type => 'application/json', -status => '200' );

        my $d = JSON->new->allow_nonref->encode($data);
        $res->print($d);
        Foswiki::Exception::HTTPResponse->throw;
    }
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
