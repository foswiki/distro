# See bottom of file for license and copyright information

=begin TML

---+!! Class Foswiki::App

The core class of the project responsible for low-level and code glue
functionality.

=cut

package Foswiki::App;
use v5.14;

use constant TRACE_REQUEST => 0;

use Assert;
use Cwd;
use Try::Tiny;
use Storable qw(dclone);
use Foswiki qw(%regex);

# SMELL CGI is only used for generating a simple error page using HTML tags
# shortcut functions. Must be replaced with something more reasonable.
use CGI ();
use Compress::Zlib;
use Foswiki::Engine;
use Foswiki::Templates;
use Foswiki::Exception;
use Foswiki::Sandbox;
use Foswiki::WebFilter;
use Foswiki::Time;
use Foswiki qw(load_package load_class isTrue);

use Foswiki::Class qw(callbacks);
use namespace::clean;
extends qw(Foswiki::Object);

callback_names qw(handleRequestException postConfig);

has access => (
    is        => 'ro',
    lazy      => 1,
    clearer   => 1,
    predicate => 1,
    isa =>
      Foswiki::Object::isaCLASS( 'access', 'Foswiki::Access', noUndef => 1, ),
    default => sub {
        my $this        = shift;
        my $accessClass = $this->cfg->data->{AccessControl}
          || 'Foswiki::Access::TopicACLAccess';
        return $this->create($accessClass);
    },
);
has attach => (
    is        => 'ro',
    lazy      => 1,
    clearer   => 1,
    predicate => 1,
    default   => sub { $_[0]->create('Foswiki::Attach'); },
);
has cache => (
    is        => 'rw',
    lazy      => 1,
    clearer   => 1,
    predicate => 1,
    default   => sub {
        my $this = shift;
        my $cfg  = $this->cfg;
        if (   $cfg->data->{Cache}{Enabled}
            && $cfg->data->{Cache}{Implementation} )
        {
            load_class( $cfg->data->{Cache}{Implementation} );
            ASSERT( !$@, $@ ) if DEBUG;
            return $this->create( $cfg->data->{Cache}{Implementation} );
        }
        return undef;
    },
);

=begin TML
---++ ObjectAttribute cfg

This attribute stores application configuration object - a =Foswiki::Config=
instance.

=cut

has cfg => (
    is      => 'rw',
    lazy    => 1,
    builder => '_prepareConfig',
    isa => Foswiki::Object::isaCLASS( 'cfg', 'Foswiki::Config', noUndef => 1, ),
);
has env => (
    is       => 'rw',
    required => 1,
);
has forms => (
    is      => 'ro',
    lazy    => 1,
    clearer => 1,
    default => sub { {} },
);
has logger => (
    is        => 'ro',
    lazy      => 1,
    clearer   => 1,
    predicate => 1,
    default   => sub {
        my $this        = shift;
        my $cfg         = $this->cfg;
        my $loggerClass = 'Foswiki::Logger';
        if ( $cfg->data->{Log}{Implementation} ne 'none' ) {
            $loggerClass = $cfg->data->{Log}{Implementation};
        }
        return $this->create($loggerClass);
    },
);
has engine => (
    is        => 'rw',
    lazy      => 1,
    predicate => 1,
    builder   => '_prepareEngine',
    isa =>
      Foswiki::Object::isaCLASS( 'engine', 'Foswiki::Engine', noUndef => 1, ),
);

# Heap is to be used for data persistent over session lifetime.
# Usage: $sessiom->heap->{key} = <your data>;
has heap => (
    is      => 'rw',
    clearer => 1,
    lazy    => 1,
    default => sub { {} },
);
has i18n => (
    is        => 'ro',
    lazy      => 1,
    clearer   => 1,
    predicate => 1,
    default   => sub {

        # language information; must be loaded after
        # *all possible preferences sources* are available
        $_[0]->create('Foswiki::I18N');
    },
);
has net => (
    is        => 'ro',
    lazy      => 1,
    clearer   => 1,
    predicate => 1,
    default   => sub { return $_[0]->create('Foswiki::Net'); },
);
has plugins => (
    is        => 'rw',
    lazy      => 1,
    clearer   => 1,
    predicate => 1,
    default   => sub { return $_[0]->create('Foswiki::Plugins'); },
);
has prefs => (
    is        => 'ro',
    lazy      => 1,
    predicate => 1,
    clearer   => 1,
    builder   => '_preparePrefs',
);
has renderer => (
    is        => 'ro',
    lazy      => 1,
    clearer   => 1,
    predicate => 1,
    default   => sub {
        return $_[0]->create('Foswiki::Render');
    },
);
has request => (
    is      => 'rw',
    lazy    => 1,
    builder => '_prepareRequest',
    isa =>
      Foswiki::Object::isaCLASS( 'request', 'Foswiki::Request', noUndef => 1, ),
);
has response => (
    is      => 'rw',
    lazy    => 1,
    clearer => 1,
    default => sub { $_[0]->create('Foswiki::Response') },
    isa     => Foswiki::Object::isaCLASS(
        'response', 'Foswiki::Response', noUndef => 1,
    ),
);
has search => (
    is        => 'ro',
    lazy      => 1,
    clearer   => 1,
    predicate => 1,
    default   => sub {
        return $_[0]->create('Foswiki::Search');
    },
);
has store => (
    is        => 'rw',
    lazy      => 1,
    clearer   => 1,
    predicate => 1,
    isa =>
      Foswiki::Object::isaCLASS( 'store', 'Foswiki::Store', noUndef => 1, ),
    default => sub {
        my $storeClass = $Foswiki::cfg{Store}{Implementation}
          || 'Foswiki::Store::PlainFile';
        ASSERT( $storeClass, "Foswiki::store base class is not defined" )
          if DEBUG;
        return $_[0]->create($storeClass);
    },
);
has templates => (
    is        => 'ro',
    lazy      => 1,
    predicate => 1,
    clearer   => 1,
    default   => sub { return $_[0]->create('Foswiki::Templates'); },
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
    builder => '_prepareContext',
);
has ui => (
    is      => 'rw',
    lazy    => 1,
    default => sub {
        return $_[0]->create('Foswiki::UI');
    },
);
has remoteUser => (
    is        => 'rw',
    lazy      => 1,
    clearer   => 1,
    predicate => 1,
    default   => sub {
        my $this = shift;
        return $this->users->loadSession( $this->engine->user );
    },
);
has user => (
    is        => 'rw',
    clearer   => 1,
    predicate => 1,
);
has users => (
    is        => 'rw',
    lazy      => 1,
    predicate => 1,
    clearer   => 1,
    default   => sub { return $_[0]->create('Foswiki::Users'); },
);
has zones => (
    is        => 'ro',
    lazy      => 1,
    clearer   => 1,
    predicate => 1,
    default   => sub { return $_[0]->create('Foswiki::Render::Zones'); },
);
has _dispatcherAttrs => (
    is  => 'rw',
    isa => Foswiki::Object::isaHASH( '_dispatcherAttrs', noUndef => 1 ),
);

# List of system messages to be displayed to user. Could be used to display non-critical errors or important warnings.
has system_messages => (
    is      => 'rw',
    lazy    => 1,
    clearer => 1,
    default => sub { [] },
    isa     => Foswiki::Object::isaARRAY( 'system_messages', noUndef => 1, ),
);

has inUnitTestMode => (
    is      => 'rw',
    lazy    => 1,
    default => sub {
        my $this   = shift;
        my $inTest = $Foswiki::inUnitTestMode
          || ( $this->has_engine && ref( $this->engine ) =~ /::Test$/ );
        return $inTest;
    },
);

=begin TML

---++ ClassMethod new([%parameters])

The following keys could be defined in =%parameters= hash:

|*Key*|*Type*|*Description*|
|=env=|hashref|Environment hash such as shell environment or PSGI env| 

=cut

sub BUILD {
    my $this   = shift;
    my $params = shift;

    $Foswiki::app = $this;

    unless ( $this->cfg->data->{isVALID} ) {
        $this->cfg->bootstrapSystemSettings;
    }

    my $cfgData = $this->cfg->data;

    if ( $cfgData->{Store}{overrideUmask} && $cfgData->{OS} ne 'WINDOWS' ) {

# Note: The addition of zero is required to force dirPermission and filePermission
# to be numeric.   Without the additition, certain values of the permissions cause
# runtime errors about illegal characters in subtraction.   "and" with 777 to prevent
# sticky-bits from breaking the umask.
        my $oldUmask = umask(
            (
                oct(777) - (
                    (
                        $cfgData->{Store}{dirPermission} + 0 |
                          $cfgData->{Store}{filePermission} + 0
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

    # Enforce some shell environment variables.
    # SMELL Would it be tolerated in PSGI?
    $CGI::TMPDIRECTORY = $ENV{TMPDIR} = $ENV{TEMP} = $ENV{TMP} =
      $this->cfg->data->{TempfileDir};

    # Make %ENV safer, preventing hijack of the search path. The
    # environment is set per-query, so this can't be done in a BEGIN.
    # This MUST be done before any external programs are run via Sandbox.
    # or it will fail with taint errors.  See Item13237
    if ( defined $cfgData->{SafeEnvPath} ) {
        $ENV{PATH} = $cfgData->{SafeEnvPath};
    }
    else {
# Default $ENV{PATH} must be untainted because
# Foswiki may be run with the -T flag.
# SMELL: how can we validate the PATH?
# Configure now warns, suppress the broadcast warning.
#        $this->systemMessage(
#"Unsafe shell variable PATH is used, consider setting SafeEnvPath configuration parameter."
#        );
        $ENV{PATH} = Foswiki::Sandbox::untaintUnchecked( $ENV{PATH} );
    }
    delete @ENV{qw( IFS CDPATH ENV BASH_ENV )};

# TODO It's not clear yet as how to deal with logger configuration - see Foswiki::BUILDARGS().

    unless ( defined $this->engine ) {
        Foswiki::Exception::Fatal->throw( text => "Cannot initialize engine" );
    }

    $this->_prepareDispatcher;
    $this->_checkBootstrapStage2;

    # Override user to be admin if no configuration exists.
    # Do this really early, so that later changes in isBOOTSTRAPPING can't
    # change Foswiki's behavior.
    if ( $cfgData->{isBOOTSTRAPPING} ) {
        $this->engine->user('admin');
    }
    else {
        my $plogin = $this->plugins->load;
        $this->engine->user($plogin) if $plogin;
    }

    $this->user( $this->users->initialiseUser( $this->remoteUser ) );

    # Read preferences which may depend on user being authenticated.
    $this->_readPrefs;
}

sub DEMOLISH {
    my $this = shift;
    my ($in_global) = @_;

    # Clean up sessions before we finish.
    if ( 0 && DEBUG ) {
        if ($in_global) {
            say STDERR ">>>>";
            say STDERR Carp::longmess( ref($this) . '::DEMOLISH' );
            say STDERR "Object from ", $this->{__orig_file}, ":",
              $this->{__orig_line};
            say STDERR $this->{__orig_stack};
            say STDERR "<<<<";
            require Devel::MAT::Dumper;
        }
        else {
            say STDERR ref($this) . '::DEMOLISH';
            say STDERR "Object from ", $this->{__orig_file}, ":",
              $this->{__orig_line};
            say STDERR $this->{__orig_stack};
        }
    }
    $this->users->loginManager->complete;

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
    local $Foswiki::app;
    local %Foswiki::cfg;

    # Before localizing shell environment we need to preserve and restore it.
    local %ENV = %ENV;

    my ( $app, $rc );

    # We use shell environment by default. PSGI would supply its own env
    # hashref. Because PSGI env is not the same as shell env we would need to
    # avoid any side effects related to situations when changes to the env
    # hashref are gettin' translated back onto the shell env.
    $params{env} //= dclone( \%ENV );

    # Use current working dir for fetching the initial setlib.cfg
    $params{env}{PWD} //= getcwd;

    try {
        local $SIG{__DIE__} = sub {

            # Somehow overriding of __DIE__ clashes with remote perl debugger in
            # Komodo unless we die again instantly.
            die $_[0] if (caller)[0] =~ /^DB::/;
            Foswiki::Exception::Fatal->rethrow( $_[0] );
        };
        local $SIG{__WARN__} = sub {
            Foswiki::Exception::Fatal->rethrow( $_[0] );
          }
          if DEBUG;

        $app = $class->new(%params);
        $rc  = $app->handleRequest;
    }
    catch {
        my $e = Foswiki::Exception::Fatal->transmute( $_, 0 );

        if ( defined $app && defined $app->logger ) {
            $app->logger->log( 'error', $e->stringify, );
        }

        my $errStr = Foswiki::Exception::errorStr($e);

        # Low-level report of errors to user.
        if ( defined $app && $app->has_engine ) {

            $errStr = '<pre>' . Foswiki::entityEncode($errStr) . '</pre>';

            # Send error output to user using the initialized engine.
            $rc = $app->engine->finalizeReturn(
                [
                    500,
                    [
                        'Content-Type'   => 'text/html; charset=utf-8',
                        'Content-Length' => length($errStr),
                    ],
                    [$errStr]
                ]
            );
        }
        else {
            # Propagade the error using the most primitive way.
            die $errStr;
        }
    };
    return $rc;
}

sub handleRequest {
    my $this = shift;

    my $req = $this->request;
    my $res = $this->response;
    my $rc;

    try {
        $this->_checkTickle;
        $this->_checkReqCache;

        if (TRACE_REQUEST) {
            print STDERR "INCOMING "
              . $req->method() . " "
              . $req->url . " -> "
              . $this->_dispatcherAttrs->{method} . "\n";
            print STDERR "validation_key: "
              . ( $req->param('validation_key') || 'no key' ) . "\n";

            #require Data::Dumper;
            #print STDERR Data::Dumper->Dump([$req]);
        }

        $this->_checkActionAccess;

        # Set both isadmin and authenticated contexts. If the current user is
        # admin, then they either authenticated, or we are in bootstrap.
        if ( $this->users->isAdmin( $this->user ) ) {
            $this->context->{authenticated} = 1;
            $this->context->{isadmin}       = 1;
        }

        # Finish plugin initialization - register handlers
        $this->plugins->enable();

        my $method = $this->_dispatcherAttrs->{method};
        $this->ui->$method;
    }
    catch {
        my $e = Foswiki::Exception::Fatal->transmute( $_, 0 );

        $this->callback( 'handleRequestException', { exception => $e, } );

        # SMELL TODO At this stage we shall be able to display any exception in
        # a pretty HTMLized way if engine is HTTPCompliant. Rethrowing of an
        # exception is just a temporary stub.
        if ( $e->isa('Foswiki::AccessControlException') ) {

            unless ( $this->users->getLoginManager->forceAuthentication ) {

                # Login manager did not want to authenticate, perhaps because
                # we are already authenticated.
                my $exception = $this->create(
                    'Foswiki::OopsException',
                    template => 'accessdenied',
                    status   => 403,
                    web      => $e->web,
                    topic    => $e->topic,
                    def      => 'topic_access',
                    params   => [ $e->mode, $e->reason ]
                );

                $exception->generate;
            }
        }
        elsif ( $e->isa('Foswiki::OopsException') ) {
            $e->generate;
        }
        elsif ( $e->isa('Foswiki::EngineException') ) {
            $res->header( -type => 'text/html', );
            $res->status( $e->status );
            my $html = CGI::start_html( $e->status . ' Bad Request' );
            $html .= CGI::h1( {}, 'Bad Request' );
            $html .= CGI::p( {}, $e->reason );
            $html .= CGI::end_html();
            $res->print( Foswiki::encode_utf8($html) );
        }
        else {
            Foswiki::Exception::Fatal->rethrow($e);
        }
    };

    my $return = $res->as_array;
    $res->outputHasStarted(1);
    $rc = $this->engine->finalizeReturn($return);

    # Clean up sessions before we finish.
    # SMELL Not sure if it really belongs here but being called in DEMOLISH()
    # it fails because users attribute gets destroyed by the time.
    $this->users->loginManager->complete;

    return $rc;
}

=begin TML

--++ ObjectMethod create($className, %initArgs)

Creates a new object of class =$className=. If the class does =Foswiki::App=
role then constructor gets called with =app= key pointing to the Foswiki::App
object.

This method loads class module automatically.

=cut

sub create {
    my $this  = shift;
    my $class = shift;

    $class = ref($class) if ref($class);

    Foswiki::load_class($class);

    my $object;
    if ( $class->does('Foswiki::AppObject') ) {
        $object = $class->new( app => $this, @_ );
    }
    else {
        $object = $class->new(@_);
    }
    return $object;
}

=begin TML

---++ ObjectMethod deepWebList($filter, $web) -> @list

Deep list subwebs of the named web. $filter is a =Foswiki::WebFilter=
object that is used to filter the list. The listing of subwebs is
dependent on $Foswiki::cfg{EnableHierarchicalWebs} being true.

Webs are returned as absolute web pathnames.

=cut

sub deepWebList {
    my ( $this, $filter, $rootWeb ) = @_;
    my @list;
    my $webObject = $this->create( 'Foswiki::Meta', web => $rootWeb );
    my $it = $webObject->eachWeb( $this->cfg->data->{EnableHierarchicalWebs} );
    return $it->all() unless $filter;
    while ( $it->hasNext() ) {
        my $w = $rootWeb || '';
        $w .= '/' if $w;
        $w .= $it->next();
        if ( $filter->ok( $this, $w ) ) {
            push( @list, $w );
        }
    }
    return @list;
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

=begin TML

---++ ObjectMethod inlineAlert($template, $def, ... ) -> $string

Format an error for inline inclusion in rendered output. The message string
is obtained from the template 'oops'.$template, and the DEF $def is
selected. The parameters (...) are used to populate %PARAM1%..%PARAMn%

=cut

sub inlineAlert {
    my $this     = shift;
    my $template = shift;
    my $def      = shift;

    my $req = $this->request;

    # web and topic can be anything; they are not used
    my $topicObject = $this->create(
        'Foswiki::Meta',
        web   => $req->web,
        topic => $req->topic,
    );
    my $text = $this->templates->readTemplate( 'oops' . $template );
    if ($text) {
        my $blah = $this->templates->expandTemplate($def);
        $text =~ s/%INSTANTIATE%/$blah/;

        $text = $topicObject->expandMacros($text);
        my $n = 1;
        while ( defined( my $param = shift ) ) {
            $text =~ s/%PARAM$n%/$param/g;
            $n++;
        }

        # Suppress missing params
        $text =~ s/%PARAM\d+%//g;

        # Suppress missing params
        $text =~ s/%PARAM\d+%//g;
    }
    else {

        # Error in the template system.
        $text = $topicObject->renderTML(<<MESSAGE);
---+ Foswiki Installation Error
Template 'oops$template' not found or returned no text, expanding $def.

Check your configuration settings for {TemplateDir} and {TemplatePath}
or check for syntax errors in templates,  or a missing TMPL:END.
MESSAGE
    }

    return $text;
}

=begin TML

---++ ObjectMethod redirect( $url, $passthrough, $status )

   * $url - url or topic to redirect to
   * $passthrough - (optional) parameter to pass through current query
     parameters (see below)
   * $status - HTTP status code (30x) to redirect with. Defaults to 302.

Redirects the request to =$url=, *unless*
   1 It is overridden by a plugin declaring a =redirectCgiQueryHandler=
     (a dangerous, deprecated handler!)
   1 =$session->{request}= is =undef=
Thus a redirect is only generated when in a CGI context.

Normally this method will ignore parameters to the current query. Sometimes,
for example when redirecting to a login page during authentication (and then
again from the login page to the original requested URL), you want to make
sure all parameters are passed on, and for this $passthrough should be set to
true. In this case it will pass all parameters that were passed to the
current query on to the redirect target. If the request_method for the
current query was GET, then all parameters will be passed by encoding them
in the URL (after ?). If the request_method was POST, then there is a risk the
URL would be too big for the receiver, so it caches the form data and passes
over a cache reference in the redirect GET.

NOTE: Passthrough is only meaningful if the redirect target is on the same
server.

=cut

sub redirect {
    my $this = shift;
    my ( $url, $passthru, $status ) = @_;
    ASSERT( defined $url ) if DEBUG;

    my $req = $this->request;

    ( $url, my $anchor ) = Foswiki::splitAnchorFromUrl($url);

    if ( $passthru && defined $req->method() ) {
        my $existing = '';
        if ( $url =~ s/\?(.*)$// ) {
            $existing = $1;    # implicit untaint OK; recombined later
        }
        if ( uc( $req->method() ) eq 'POST' ) {

            # Redirecting from a post to a get
            my $cache = $req->cacheQuery;
            if ($cache) {
                if ( $url eq '/' ) {
                    $url = $this->cfg->getScriptUrl( 1, 'view' );
                }
                $url .= $cache;
            }
        }
        else {

            # Redirecting a get to a get; no need to use passthru
            if ( $req->query_string() ) {
                $url .= '?' . $req->query_string();
            }
            if ($existing) {
                if ( $url =~ m/\?/ ) {
                    $url .= ';';
                }
                else {
                    $url .= '?';
                }
                $url .= $existing;
            }
        }
    }

    # prevent phishing by only allowing redirect to configured host
    # do this check as late as possible to catch _any_ last minute hacks
    # TODO: this should really use URI
    if ( !Foswiki::_isRedirectSafe($url) ) {

        # goto oops if URL is trying to take us somewhere dangerous
        $url = $this->cfg->getScriptUrl(
            1, 'oops',
            $this->request->web   || $Foswiki::cfg{UsersWebName},
            $this->request->topic || $Foswiki::cfg{HomeTopicName},
            template => 'oopsredirectdenied',
            def      => 'redirect_denied',
            param1   => "$url",
            param2   => "$Foswiki::cfg{DefaultUrlHost}",
        );
    }

    $url .= $anchor if $anchor;

    # Dangerous, deprecated handler! Might work, probably won't.
    return
      if (
        $this->plugins->dispatch(
            'redirectCgiQueryHandler', $this->response, $url
        )
      );

    $url = $this->users->getLoginManager->rewriteRedirectUrl($url);

    # Foswiki::Response::redirect doesn't automatically pass on the cookies
    # for us, so we have to do it explicitly; otherwise the session cookie
    # won't get passed on.
    $this->response->redirect(
        -url     => $url,
        -cookies => $this->response->cookies,
        -status  => $status,
    );
}

=begin TML

---++ ObjectMethod redirectto($url) -> $url

If the CGI parameter 'redirectto' is present on the query, then will validate
that it is a legal redirection target (url or topic name). If 'redirectto'
is not present on the query, performs the same steps on $url.

Returns undef if the target is not valid, and the target URL otherwise.

=cut

sub redirectto {
    my ( $this, $url ) = @_;

    my $req         = $this->request;
    my $redirecturl = $req->param('redirectto');
    $redirecturl = $url unless $redirecturl;

    return unless $redirecturl;

    if ( $redirecturl =~ m#^$regex{linkProtocolPattern}://# ) {

        # assuming URL
        return $redirecturl if Foswiki::_isRedirectSafe($redirecturl);
        return;
    }

    my @attrs = ();

    # capture anchor
    if ( $redirecturl =~ s/#(.*)// ) {
        push( @attrs, '#' => $1 );
    }

    # capture params
    if ( $redirecturl =~ s/\?(.*)// ) {
        push( @attrs, map { split( '=', $_, 2 ) } split( /[;&]/, $1 ) );
    }

    # assuming 'web.topic' or 'topic'
    my ( $w, $t ) = $req->normalizeWebTopicName( $req->web, $redirecturl );

    return $this->cfg->getScriptUrl( 0, 'view', $w, $t, @attrs );
}

=begin TML

---++ ObjectMethod satisfiedByCache( $action, $web, $topic ) -> $boolean

Try and satisfy the current request for the given web.topic from the cache, given
the current action (view, edit, rest etc).

If the action is satisfied, the cache content is written to the output and
true is returned. Otherwise ntohing is written, and false is returned.

Designed for calling from Foswiki::UI::*

=cut

sub satisfiedByCache {
    my ( $this, $action, $web, $topic ) = @_;

    my $cache = $this->cache;
    return 0 unless $cache;

    my $cachedPage = $cache->getPage( $web, $topic ) if $cache;
    return 0 unless $cachedPage;

    $this->writeDebug("found $web.$topic for $action in cache")
      if Foswiki::PageCache::TRACE();
    if ( int( $this->response->status || 200 ) >= 500 ) {
        $this->writeDebug(
            "Cache retrieval skipped due to non-200 status code "
              . $this->response->status )
          if DEBUG;
        return 0;
    }
    Monitor::MARK("found page in cache");

    my $hdrs = { 'Content-Type' => $cachedPage->{contenttype} };

    # Mark the response so we know it was satisfied from the cache
    $hdrs->{'X-Foswiki-PageCache'} = 1;

    # render uncacheable areas
    my $text = $cachedPage->{data};

    if ( $cachedPage->{isdirty} ) {
        $cache->renderDirtyAreas( \$text );

        # dirty pages are cached in unicode
        $text = Foswiki::encode_utf8($text);
    }
    elsif ( $Foswiki::cfg{HttpCompress} ) {

        # Does the client accept gzip?
        if ( my $encoding = $this->engine->gzipAccepted ) {

            # Cache has compressed data, just whack it out
            $hdrs->{'Content-Encoding'} = $encoding;
            $hdrs->{'Vary'}             = 'Accept-Encoding';

        }
        else {
        # e.g. CLI request satisfied from the cache, or old browser that doesn't
        # support gzip. Non-isdirty pages are cached already utf8-encoded, so
        # all we have to do is unzip.
            $text = Compress::Zlib::memGunzip( $cachedPage->{data} );
        }
    }    # else { Non-isdirty pages are stored already utf8-encoded }

    # set status
    my $response = $this->response;
    if ( $cachedPage->{status} == 302 ) {
        $response->redirect( $cachedPage->{location} );
    }
    else {

     # See Item9941
     # Don't allow a 200 status to overwrite a status (possibly an error status)
     # coming from elsewhere in the code. Note that 401's are not cached (they
     # fail Foswiki::PageCache::isCacheable) but all other statuses are.
     # SMELL: Cdot doesn't think any other status can get this far.
        $response->status( $cachedPage->{status} )
          unless int( $cachedPage->{status} ) == 200;
    }

    # set remaining headers
    $text = undef unless $this->setETags( $cachedPage, $hdrs );
    $response->generateHTTPHeaders($hdrs);

    # send it out
    $response->body($text) if defined $text;

    Monitor::MARK('Wrote HTML');
    $this->logger->log(
        {
            level    => 'info',
            action   => $action,
            webTopic => $web . '.' . $topic,
            extra    => '(cached)',
        }
    );

    return 1;
}

=begin TML

---++ ObjectMethod setCacheControl( $pageType, \%hopts )

Set the cache control headers in a response

   * =$pageType= - page type - 'view', ;edit' etc
   * =\%hopts - ref to partially filled in hash of headers

=cut

sub setCacheControl {
    my ( $this, $pageType, $hopts ) = @_;

    if ( $pageType && $pageType eq 'edit' ) {

        # Edit pages - future versions will extend to
        # of other types of page, with expiry time driven by page type.

        # Get time now in HTTP header format
        my $lastModifiedString =
          Foswiki::Time::formatTime( time, '$http', 'gmtime' );

        # Expiry time is set high to avoid any data loss.  Each instance of
        # Edit page has a unique URL with time-string suffix (fix for
        # RefreshEditPage), so this long expiry time simply means that the
        # browser Back button always works.  The next Edit on this page
        # will use another URL and therefore won't use any cached
        # version of this Edit page.
        my $expireHours   = 24;
        my $expireSeconds = $expireHours * 60 * 60;

        # and cache control headers, to ensure edit page
        # is cached until required expiry time.
        $hopts->{'last-modified'} = $lastModifiedString;
        $hopts->{expires}         = "+${expireHours}h";
        $hopts->{'Cache-Control'} = "max-age=$expireSeconds";
    }
    else {

        # we need to force the browser into a check on every
        # request; let the server decide on an 304 as below
        my $cacheControl = 'max-age=0';

        my $req = $this->request;

        # allow the admin to disable us from setting the max-age, as then
        # it can't be set by apache
        $cacheControl = $Foswiki::cfg{BrowserCacheControl}->{ $req->web }
          if ( $Foswiki::cfg{BrowserCacheControl}
            && defined( $Foswiki::cfg{BrowserCacheControl}->{ $req->web } ) );

        # don't remove the 'if'; we need the header to not be there at
        # all for the browser to use the cached version
        $hopts->{'Cache-Control'} = $cacheControl if ( $cacheControl ne '' );
    }
}

=begin TML

---++ ObjectMethod setETags( $cachedPage, \%hopts ) -> $boolean

Set etags (and modify status) depending on what the cached page specifies.
Return 1 if the page has been modified since it was last retrieved, 0 otherwise.

   * =$cachedPage= - page cache to use
   * =\%hopts - ref to partially filled in hash of headers

=cut

sub setETags {
    my ( $this, $cachedPage, $hopts ) = @_;

    # check etag and last modification time
    my $etag         = $cachedPage->{etag};
    my $lastModified = $cachedPage->{lastmodified};

    $hopts->{'ETag'}          = $etag         if $etag;
    $hopts->{'Last-Modified'} = $lastModified if $lastModified;

    # only send a 304 if both criteria are true
    return 1
      unless (
           $etag
        && $lastModified

        && $this->env->{'HTTP_IF_NONE_MATCH'}
        && $etag eq $this->env->{'HTTP_IF_NONE_MATCH'}

        && $this->env->{'HTTP_IF_MODIFIED_SINCE'}
        && $lastModified eq $this->env->{'HTTP_IF_MODIFIED_SINCE'}
      );

    # finally decide on a 304 reply
    $hopts->{'Status'} = '304 Not Modified';

    #print STDERR "NOT modified\n";
    return 0;
}

=begin TML

---++ ObjectMethod getSkin () -> $string

Get the currently requested skin path

=cut

sub getSkin {
    my $this = shift;

    my @skinpath;
    my $skins;

    if ( $this->request ) {
        $skins = $this->request->param('cover');
        if ( defined $skins
            && $skins =~ m/([[:alnum:].,\s]+)/ )
        {

            # Implicit untaint ok - validated
            $skins = $1;
            push( @skinpath, split( /,\s]+/, $skins ) );
        }
    }

    $skins = $this->prefs->getPreference('COVER');
    if ( defined $skins
        && $skins =~ m/([[:alnum:].,\s]+)/ )
    {

        # Implicit untaint ok - validated
        $skins = $1;
        push( @skinpath, split( /[,\s]+/, $skins ) );
    }

    $skins = $this->request ? $this->request->param('skin') : undef;
    $skins = $this->prefs->getPreference('SKIN') unless $skins;

    if ( defined $skins && $skins =~ m/([[:alnum:].,\s]+)/ ) {

        # Implicit untaint ok - validated
        $skins = $1;
        push( @skinpath, split( /[,\s]+/, $skins ) );
    }

    return join( ',', @skinpath );
}

=begin TML

---++ ObjectMethod systemMessage( @messages )

Adds a new system message to be displayed to a user (who most likely would be an
admin) either as a banner on the top of a wiki topic or by a special macro.

This method is to be used with care when really necessary.

=cut

sub systemMessage {
    my $this = shift;
    if (@_) {
        push @{ $this->system_messages }, @_;
    }
    return join( '%BR%', @{ $this->system_messages } );
}

=begin TML

---++ ObjectMethod writeCompletePage( $text, $pageType, $contentType )

Write a complete HTML page with basic header to the browser.
   * =$text= is the text of the page script (&lt;html&gt; to &lt;/html&gt; if it's HTML)
   * =$pageType= - May be "edit", which will cause headers to be generated that force
     caching for 24 hours, to prevent Codev.BackFromPreviewLosesText bug, which caused
     data loss with IE5 and IE6.
   * =$contentType= - page content type | text/html

This method removes noautolink and nop tags before outputting the page unless
$contentType is text/plain.

=cut

sub writeCompletePage {
    my ( $this, $text, $pageType, $contentType ) = @_;

    # true if the body is to be output without encoding to utf8
    # first. This is the case if the body has been gzipped and/or
    # rendered from the cache
    my $binary_body = 0;

    $contentType ||= 'text/html';

    my $cgis = $this->users->getCGISession();
    if (   $cgis
        && $contentType =~ m!^text/html!
        && $Foswiki::cfg{Validation}{Method} ne 'none' )
    {

        # Don't expire the validation key through login, or when
        # endpoint is an error.
        Foswiki::Validation::expireValidationKeys($cgis)
          unless ( $this->request->action eq 'login'
            or ( $ENV{REDIRECT_STATUS} || 0 ) >= 400 );

        my $usingStrikeOne =
          $this->cfg->data->{Validation}{Method} eq 'strikeone';
        if ($usingStrikeOne) {

            # add the validation cookie
            my $valCookie = Foswiki::Validation::getCookie($cgis);
            $valCookie->secure( $this->request->secure );
            $this->response->cookies(
                [ $this->response->cookies, $valCookie ] );

            # Add the strikeone JS module to the page.
            my $src = (DEBUG) ? '.uncompressed' : '';
            $this->zones->addToZone(
                'script',
                'JavascriptFiles/strikeone',
                '<script type="text/javascript" src="'
                  . $this->cfg->getPubURL(
                    $this->cfg->data->{SystemWebName}, 'JavascriptFiles',
                    "strikeone$src.js"
                  )
                  . '"></script>',
                'JQUERYPLUGIN'
            );

            # Add the onsubmit handler to the form
            $text =~ s/(<form[^>]*method=['"]POST['"][^>]*>)/
                Foswiki::Validation::addOnSubmit($1)/gei;
        }

        my $context =
          $this->request->url( -full => 1, -path => 1, -query => 1 ) . time();

        # Inject validation key in HTML forms
        $text =~ s/(<form[^>]*method=['"]POST['"][^>]*>)/
          $1 . Foswiki::Validation::addValidationKey(
              $cgis, $context, $usingStrikeOne )/gei;

        #add validation key to HTTP header so we can update it for ajax use
        $this->response->pushHeader(
            'X-Foswiki-Validation',
            Foswiki::Validation::generateValidationKey(
                $cgis, $context, $usingStrikeOne
            )
        ) if ($cgis);
    }

    if ( $this->zones ) {

        $text = $this->zones->_renderZones($text);
    }

    # Validate format of content-type (defined in rfc2616)
    my $tch = qr/[^\[\]()<>@,;:\\"\/?={}\s]/;
    if ( $contentType =~ m/($tch+\/$tch+(\s*;\s*$tch+=($tch+|"[^"]*"))*)$/i ) {
        $contentType = $1;
    }
    else {
        # SMELL: can't compute; faking content-type for backwards compatibility;
        # any other information might become bogus later anyway
        $contentType = "text/plain;contenttype=invalid";
    }
    my $hdr = "Content-type: " . $1 . "\r\n";

    # Call final handler
    $this->plugins->dispatch( 'completePageHandler', $text, $hdr );

    # cache final page, but only view and rest
    my $cachedPage;
    if ( $contentType ne 'text/plain' ) {

        # Remove <nop> and <noautolink> tags
        $text =~ s/([\t ]?)[ \t]*<\/?(nop|noautolink)\/?>/$1/gis;
        if ( $Foswiki::cfg{Cache}{Enabled}
            && ( $this->inContext('view') || $this->inContext('rest') ) )
        {
            $cachedPage = $this->cache->cachePage( $contentType, $text );
            $this->cache->renderDirtyAreas( \$text )
              if $cachedPage && $cachedPage->{isdirty};
        }

        # remove <dirtyarea> tags
        $text =~ s/<\/?dirtyarea[^>]*>//g;

        # Check that the templates specified clean HTML
        if (DEBUG) {

            # When tracing is enabled in Foswiki::Templates, then there will
            # always be a <!--bodyend--> after </html>. So we need to disable
            # this check.
            if (   !Foswiki::Templates->TRACE
                && $contentType =~ m#text/html#
                && $text =~ m#</html>(.*?\S.*)$#s )
            {
                ASSERT( 0, <<BOGUS );
Junk after </html>: $1. Templates may be bogus
- Check for excess blank lines at ends of .tmpl files
-  or newlines after %TMPL:INCLUDE
- You can enable TRACE in Foswiki::Templates to help debug
BOGUS
            }
        }
    }

    $this->response->pushHeader( 'X-Foswiki-Monitor-renderTime',
        $this->request->getTime() );

    my $hopts = { 'Content-Type' => $contentType };

    $this->setCacheControl( $pageType, $hopts );

    if ($cachedPage) {
        $text = '' unless $this->setETags( $cachedPage, $hopts );
    }

    if ( $Foswiki::cfg{HttpCompress} && length($text) ) {

        # Generate a zipped page, if the client accepts them

        # SMELL: $ENV{SPDY} is a non-standard way to detect spdy protocol
        if ( my $encoding = $this->engine->gzipAccepted ) {
            $hopts->{'Content-Encoding'} = $encoding;
            $hopts->{'Vary'}             = 'Accept-Encoding';

            # check if we take the version from the cache. NOTE: we don't
            # set X-Foswiki-Pagecache because this is *not* coming from
            # the cache (well it is, but it was only just put there)
            if ( $cachedPage && !$cachedPage->{isdirty} ) {
                $text = $cachedPage->{data};
            }
            else {
                # Not available from the cache, or it has dirty areas
                $text = Compress::Zlib::memGzip( encode_utf8($text) );
            }
            $binary_body = 1;
        }
    }    # Otherwise fall through and generate plain text

    # Generate (and print) HTTP headers.
    $this->response->generateHTTPHeaders($hopts);

    if ($binary_body) {
        $this->response->body($text);
    }
    else {
        $this->response->print($text);
    }
}

sub _prepareContext {
    my $this = shift;
    my $context = $this->_dispatcherAttrs->{context} // {};
    $context->{SUPPORTS_PARA_INDENT}   = 1;
    $context->{SUPPORTS_PREF_SET_URLS} = 1;
    if ( $this->cfg->data->{Password} ) {
        $context->{admin_available} = 1;
    }
    if ( $this->engine->isa('Foswiki::Engine::CLI') ) {
        $context->{command_line} = 1;
    }
    return $context;
}

sub _prepareEngine {
    my $this = shift;
    my @args = @_;
    my $env  = $this->env;
    my $engine;

    # Foswiki::Engine has to determine what environment are we run within and
    # return an object of corresponding class.
    $engine = Foswiki::Engine::start( env => $env, app => $this, @args );

    $this->cfg->data->{Engine} //= ref($engine) if $engine;

    return $engine;
}

sub _preparePrefs {
    my $this = shift;

    my $prefs = $this->create('Foswiki::Prefs');

    return $prefs;
}

sub _readPrefs {
    my $this = shift;

    my $req = $this->request;

    # Push global preferences from %SYSTEMWEB%.DefaultPreferences
    $this->prefs->loadDefaultPreferences;

    $this->prefs->loadPresetPreferences;

    # Static session variables that can be expanded in topics when they are
    # enclosed in % signs
    # SMELL: should collapse these into one. The duplication is pretty
    # pointless.
    $this->prefs->setInternalPreferences(
        BASEWEB        => $req->web,
        BASETOPIC      => $req->topic,
        INCLUDINGWEB   => $req->web,
        INCLUDINGTOPIC => $req->topic,
    );

    # Push plugin settings
    $this->plugins->settings();

    # Now the rest of the preferences
    $this->prefs->loadSitePreferences();

    # User preferences only available if we can get to a valid wikiname,
    # which depends on the user mapper.
    my $wn = $this->users->getWikiName( $this->user );
    if ($wn) {
        $this->prefs->setUserPreferences($wn);
    }

    $this->prefs->pushTopicContext( $req->web, $req->topic );
}

# The request attribute default method.
sub _prepareRequest {
    my $this = shift;
    my @args = @_;

    state $preparing = 0;

    if ($preparing) {
        Foswiki::Exception::Fatal->throw(
            text => 'Circular call to _prepareRequest' );
    }
    $preparing = 1;

    # The following is preferable form of Request creation. The request
    # constructor will then initialize itself using $app->engine as the source
    # of information about the environment we're running under.

    # app must be the last key of init hash to avoid occasional override from
    # user-supplied parameters.
    my $request;
    try {
        $request = Foswiki::Request::prepare( app => $this, @args );
    }
    catch {
        Foswiki::Exception::Fatal->rethrow($_);
    }
    finally {
        $preparing = 0;
    };
    return $request;
}

sub _prepareConfig {
    my $this = shift;
    my $cfg  = $this->create('Foswiki::Config');
    $this->callback('postConfig');
    return $cfg;
}

# Determines what dispatcher to use for the action requested.
sub _prepareDispatcher {
    my $this = shift;
    my $res  = $this->response;

    # Duplicate the entry to avoid changing the original.
    my $dispatcher =
      $this->cfg->data->{SwitchBoard}{ $this->engine->pathData->{action} };
    unless ( defined $dispatcher ) {
        Foswiki::Exception::HTTPError->throw(
            status => 404,
            header => 'Not Found',
            text   => 'The requested URL '
              . (
                $this->engine->request->uri
                  // 'action:' . $this->engine->pathData->{action}
              )
              . ' was not found on this server.',
        );
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
    $dispatcher->{method} //= $dispatcher->{function} || 'dispatch';
    $this->ui( $this->create( $dispatcher->{package} ) );
    $this->_dispatcherAttrs($dispatcher);
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

sub _checkReqCache {
    my $this = shift;
    my $req  = $this->request;

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

        # implicit untaint required, because $cache may be used in a
        # filename. Note that the cache serialises the method and path_info,
        # which will be restored.
        Foswiki::Request::Cache->new->load( $1, $req );
    }
}

sub _checkBootstrapStage2 {
    my $this = shift;
    my $cfg  = $this->cfg;

    # Phase 2 of Bootstrap.  Web settings require that the Foswiki request
    # has been parsed.
    if ( $cfg->data->{isBOOTSTRAPPING} ) {
        my $phase2_message =
          $cfg->bootstrapWebSettings( $this->request->action );
        $this->systemMessage(
            $this->engine->HTTPCompliant
            ? ( '<div class="foswikiHelp"> ' . $phase2_message . '</div>' )
            : $phase2_message
        );
        $this->systemMessage( $cfg->bootstrapMessage );
    }
}

sub _checkActionAccess {
    my $this            = shift;
    my $req             = $this->request;
    my $dispatcherAttrs = $this->_dispatcherAttrs;

    if (   UNIVERSAL::isa( $this->engine, 'Foswiki::Engine::CLI' )
        || UNIVERSAL::isa( $this->engine, 'Foswiki::Engine::Test' ) )
    {
        # Done in _prepareContext
        #$dispatcherAttrs->{context}{command_line} = 1;
    }
    elsif (
        defined $req->method
        && (
            (
                defined $dispatcherAttrs->{allow}
                && !$dispatcherAttrs->{allow}->{ uc( $req->method() ) }
            )
            || ( defined $dispatcherAttrs->{deny}
                && $dispatcherAttrs->{deny}->{ uc( $req->method() ) } )
        )
      )
    {
        my $res = $this->response;
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
        Foswiki::Exception::HTTPResponse->throw;
    }

}

#
# API Section
#

=begin TML

---++ API methods

=cut

# Given $web, $web and $topic, or $web $topic and $attachment, validate
# and untaint each of them and return. If any fails to validate it will
# be returned as undef.
sub _checkWTA {
    my $this = shift;
    my ( $web, $topic, $attachment ) = @_;
    if ( defined $topic ) {
        ( $web, $topic ) =
          $this->request->normalizeWebTopicName( $web, $topic );
    }
    if ( Scalar::Util::tainted($web) ) {
        $web = Foswiki::Sandbox::untaint( $web,
            \&Foswiki::Sandbox::validateWebName );
    }
    return ($web) unless defined $web && defined $topic;

    if ( Scalar::Util::tainted($topic) ) {
        $topic = Foswiki::Sandbox::untaint( $topic,
            \&Foswiki::Sandbox::validateTopicName );
    }
    return ( $web, $topic ) unless defined $topic && defined $attachment;

    if ( Scalar::Util::tainted($attachment) ) {
        $attachment = Foswiki::Sandbox::untaint( $attachment,
            \&Foswiki::Sandbox::validateAttachmentName );
    }
    return ( $web, $topic, $attachment );

}

# Validate a web.topic.attachment and throw an exception if the
# validation fails
sub _validateWTA {
    my $this = shift;
    my ( $web, $topic, $attachment ) = @_;
    my ( $w, $t, $a ) = $this->_checkWTA( $web, $topic, $attachment );
    die 'Invalid web'        if ( defined $web        && !defined $w );
    die 'Invalid topic'      if ( defined $topic      && !defined $t );
    die 'Invalid attachment' if ( defined $attachment && !defined $a );
    return ( $w, $t, $a );
}

=begin TML

---+++ ObjectMethod getUrlHost( ) -> $host

Get protocol, domain and optional port of script URL

Return: =$host= URL host, e.g. ="http://example.com:80"=

=cut

sub getUrlHost {
    return $_[0]->cfg->urlHost;
}

=begin TML

---+++ ObjectMethod getScriptUrl( $web, $topic, $script, ... ) -> $url

Compose fully qualified URL
   * =$web=    - Web name, e.g. ='Main'=
   * =$topic=  - Topic name, e.g. ='WebNotify'=
   * =$script= - Script name, e.g. ='view'=
   * =...= - an arbitrary number of name=>value parameter pairs that will be url-encoded and added to the url. The special parameter name '#' is reserved for specifying an anchor. e.g. <tt>getScriptUrl('x','y','view','#'=>'XXX',a=>1,b=>2)</tt> will give <tt>.../view/x/y?a=1&b=2#XXX</tt>

Return: =$url=       URL, e.g. ="http://example.com:80/cgi-bin/view.pl/Main/WebNotify"=

*Examples:*
<verbatim class="perl">
my $url;
# $url eq 'http://wiki.example.org/url/to/bin'
$url = $app->getScriptUrl();
# $url eq 'http://wiki.example.org/url/to/bin/edit'
$url = $app->getScriptUrl(undef, undef, 'edit');
# $url eq 'http://wiki.example.org/url/to/bin/edit/Web/Topic'
$url = $app->getScriptUrl('Web', 'Topic', 'edit');</verbatim>

=cut

sub getScriptUrl {
    my $this   = shift;
    my $web    = shift;
    my $topic  = shift;
    my $script = shift;

    return $this->cfg->getScriptUrl( 1, $script, $web, $topic, @_ );
}

=begin TML

---+++ ObjectMethod getScriptUrlPath( $web, $topic, $script, ... ) -> $path

Compose absolute URL path. See $app->getScriptUrl

*Examples:*
<verbatim class="perl">
my $path;
# $path eq '/path/to/bin'
$path = $app->getScriptUrlPath();
# $path eq '/path/to/bin/edit'
$path = $app->getScriptUrlPath(undef, undef, 'edit');
# $path eq '/path/to/bin/edit/Web/Topic'
$path = $app->getScriptUrlPath('Web', 'Topic', 'edit');</verbatim>

*Since:* 19 Jan 2012 (when called without parameters, this function is
backwards-compatible with the old version which was deprecated 28 Nov 2008).

=cut

sub getScriptUrlPath {
    my $this   = shift;
    my $web    = shift;
    my $topic  = shift;
    my $script = shift;

    return $this->cfg->getScriptUrl( 0, $script, $web, $topic, @_ );
}

=begin TML

---+++ ObjectMethod getViewUrl( $web, $topic ) -> $url

Compose fully qualified view URL
   * =$web=   - Web name, e.g. ='Main'=. The current web is taken if empty
   * =$topic= - Topic name, e.g. ='WebNotify'=
Return: =$url=      URL, e.g. ="http://example.com:80/cgi-bin/view.pl/Main/WebNotify"=

=cut

sub getViewUrl {
    my $this = shift;
    my ( $web, $topic ) = @_;

    $web ||= $this->request->web || $this->cfg->data->{UsersWebName};
    return $this->getScriptUrl( $web, $topic, 'view' );
}

=begin TML

---+++ ObjectMethod getSessionKeys() -> @keys
Get a list of all the names of session variables. The list is unsorted.

Session keys are stored and retrieved using =setSessionValue= and
=getSessionValue=.

=cut

sub getSessionKeys {
    my $this = shift;
    my $hash = $this->getLoginManager->getSessionValues;
    return keys %{$hash};
}

=begin TML

---+++ ObjectMethod pushTopicContext($web, $topic)
   * =$web= - new web
   * =$topic= - new topic
Change the Foswiki context, adding the requested =$web.$topic= onto the
preferences stack.  Any preferences found in =$web.$topic= will be used
in place of preferences previously set in the stack, provided that they
were not finalized in a lower level.  Preferences set in the prior
=web.topic= are *not* cleared.  =$web.$topic= replaces and adds to
preferences but does not remove preferences that it does not set.

Note that if the new topic is not readable by the logged in user due to
access control considerations, there will *not* be an exception. It is the
duty of the caller to check access permissions before changing the topic.
All other errors will throw an exception.

It is the duty of the caller to restore the original context by calling
=popTopicContext=.

Note that this call does *not* re-initialise plugins, so if you have used
global variables to remember the web and topic in =initPlugin=, then those
values will be unchanged.

=cut

sub pushTopicContext {
    my $this = shift;
    my ( $web, $topic ) = $this->_validateWTA(@_);

    $this->prefs->pushTopicContext( $web, $topic );
    $this->request->web($web);
    $this->request->topic($topic);
    $this->prefs->setInternalPreferences(
        BASEWEB        => $web,
        BASETOPIC      => $topic,
        INCLUDINGWEB   => $web,
        INCLUDINGTOPIC => $topic
    );
}

=begin TML

---+++ ObjectMethod popTopicContext()

Returns the Foswiki context to the state it was in before the
=pushTopicContext= was called.

=cut

sub popTopicContext {
    my $this = shift;
    my ( $web, $topic ) = $this->prefs->popTopicContext();
    $this->request->web($web);
    $this->request->topic($topic);
}

=begin TML

---+++ ObjectMethod getDefaultUserName -> $loginName
Get default user name as defined in the configuration as =DefaultUserLogin=

Return: =$loginName= Default user name, e.g. ='guest'=

=cut

sub getDefaultUserName {
    my $this = shift;
    return $this->cfg->data->{DefaultUserLogin};
}

=begin TML

---+++ ObjectMethod getCanonicalUserID( $user ) -> $cUID
   * =$user= can be a login, wikiname or web.wikiname
Return the cUID of the specified user. A cUID is a unique identifier which
is assigned by Foswiki for each user.
BEWARE: While the default TopicUserMapping uses a cUID that looks like a user's
LoginName, some characters may be modified to make them compatible with rcs.
Other usermappings may use other conventions - the !JoomlaUserMapping
for example, has cUIDs like 'JoomlaeUserMapping_1234'.

If $user is undefined, it assumes the currently logged-in user.

Return: =$cUID=, an internal unique and portable escaped identifier for
registered users. This may be autogenerated for an authenticated but
unregistered user.

=cut

sub getCanonicalUserID {
    my $this = shift;
    my $user = shift;
    return $this->user unless ($user);
    my $cUID = $this->users->getCanonicalUserID($user);
    if ( !$cUID ) {

        # Not a login name or a wiki name. Is it a valid cUID?
        my $ln = $this->users->getLoginName($user);
        $cUID = $user if defined $ln && $ln ne 'unknown';
    }
    return $cUID;
}

=begin TML

---+++ ObjectMethod getWikiName( $user ) -> $wikiName

return the WikiName of the specified user
if $user is undefined Get Wiki name of logged in user

   * $user can be a cUID, login, wikiname or web.wikiname

Return: =$wikiName= Wiki Name, e.g. ='JohnDoe'=

=cut

sub getWikiName {
    my $this = shift;
    my $user = shift;
    my $cUID = $this->getCanonicalUserID($user);
    unless ( defined $cUID ) {
        my ( $w, $u ) =
          $this->request->normalizeWebTopicName(
            $this->cfg->data->{UsersWebName}, $user );
        return $u;
    }
    return $this->users->getWikiName($cUID);
}

=begin TML

---+++ ObjectMethod getWikiUserName( $user ) -> $wikiName

return the userWeb.WikiName of the specified user
if $user is undefined Get Wiki name of logged in user

   * $user can be a cUID, login, wikiname or web.wikiname

Return: =$wikiName= Wiki Name, e.g. ="Main.JohnDoe"=

=cut

sub getWikiUserName {
    my $this = shift;
    my $user = shift;
    my $cUID = $this->getCanonicalUserID($user);
    unless ( defined $cUID ) {
        my ( $w, $u ) =
          $this->request->normalizeWebTopicName(
            $this->cfg->data->{UsersWebName}, $user );
        return "$w.$u";
    }
    return $this->users->webDotWikiName($cUID);
}

=begin TML

---+++ ObjectMethod wikiToUserName( $id ) -> $loginName
Translate a Wiki name to a login name.
   * =$id= - Wiki name, e.g. ='Main.JohnDoe'= or ='JohnDoe'=.
     $id may also be a login name. This will normally
     be transparent, but should be borne in mind if you have login names
     that are also legal wiki names.

Return: =$loginName=   Login name of user, e.g. ='jdoe'=, or undef if not
matched.

Note that it is possible for several login names to map to the same wikiname.
This function will only return the *first* login name that maps to the
wikiname.

returns undef if the WikiName is not found.

=cut 

sub wikiToUserName {
    my $this = shift;
    my ($wiki) = @_;
    return '' unless $wiki;

    my $cUID = $this->getCanonicalUserID($wiki);
    if ($cUID) {
        my $login = $this->users->getLoginName($cUID);
        return if !$login || $login eq 'unknown';
        return $login;
    }
    return;
}

=begin TML

---+++ ObjectMethod userToWikiName( $loginName, $dontAddWeb ) -> $wikiName
Translate a login name to a Wiki name
   * =$loginName=  - Login name, e.g. ='jdoe'=. This may
     also be a wiki name. This will normally be transparent, but may be
     relevant if you have login names that are also valid wiki names.
   * =$dontAddWeb= - Do not add web prefix if ="1"=
Return: =$wikiName=      Wiki name of user, e.g. ='Main.JohnDoe'= or ='JohnDoe'=

userToWikiName will always return a name. If the user does not
exist in the mapping, the $loginName parameter is returned. (backward compatibility)

=cut

sub userToWikiName {
    my $this = shift;
    my ( $login, $dontAddWeb ) = @_;
    return '' unless $login;
    my $users = $this->users;
    my $user  = $this->getCanonicalUserID($login);
    return (
          $dontAddWeb
        ? $login
        : ( $this->cfg->data->{UsersWebName} . '.' . $login )
    ) unless $user and $users->userExists($user);
    return $users->getWikiName($user) if $dontAddWeb;
    return $users->webDotWikiName($user);
}

=begin TML

---+++ ObjectMethod emailToWikiNames( $email, $dontAddWeb ) -> @wikiNames
   * =$email= - email address to look up
   * =$dontAddWeb= - Do not add web prefix if ="1"=
Find the wikinames of all users who have the given email address as their
registered address. Since several users could register with the same email
address, this returns a list of wikinames rather than a single wikiname.

=cut

sub emailToWikiNames {
    my $this = shift;
    my ( $email, $dontAddWeb ) = @_;
    ASSERT($email) if DEBUG;

    my %matches;
    my $users = $this->users;
    my $ua    = $users->findUserByEmail($email);
    if ($ua) {
        foreach my $user (@$ua) {
            if ($dontAddWeb) {
                $matches{ $users->getWikiName($user) } = 1;
            }
            else {
                $matches{ $users->webDotWikiName($user) } = 1;
            }
        }
    }

    return sort keys %matches;
}

=begin TML

---+++ ObjectMethod wikinameToEmails( $user ) -> @emails
   * =$user= - wikiname of user to look up
Returns the registered email addresses of the named user. If $user is
undef, returns the registered email addresses for the logged-in user.

$user may also be a group.

=cut

sub wikinameToEmails {
    my $this       = shift;
    my ($wikiname) = @_;
    my $users      = $this->users;
    if ($wikiname) {
        if ( $users->isGroup($wikiname) ) {
            return $users->getEmails($wikiname);
        }
        else {
            my $uids = $users->findUserByWikiName($wikiname);
            my @em   = ();
            foreach my $user (@$uids) {
                push( @em, $users->getEmails($user) );
            }
            return @em;
        }
    }
    my $user = $this->user;
    return $users->getEmails($user);
}

=begin TML

---+++ ObjectMethod isGuest( ) -> $boolean

Test if logged in user is a guest (WikiGuest)

=cut

sub isGuest {
    my $this = shift;
    return $this->user eq
      $this->users->getCanonicalUserID( $this->cfg->data->{DefaultUserLogin} );
}

=begin TML

---+++ ObjectMethod isAnAdmin( $id ) -> $boolean

Find out if the user is an admin or not. If the user is not given,
the currently logged-in user is assumed.
   * $id can be either a login name or a WikiName

=cut

sub isAnAdmin {
    my $this = shift;
    my $user = shift;
    return $this->users->isAdmin( $this->getCanonicalUserID($user) );
}

=begin TML

---+++ ObjectMethod isGroupMember( $group, $id, $options ) -> $boolean

Find out if $id is in the named group.  The expand option controls whether or not nested groups are searched.

e.g. Is jordi in the HesperionXXGroup, and not in a nested group. e.g.
<verbatim>
if( $app->isGroupMember( "HesperionXXGroup", "jordi", { expand => 0 } )) {
    ...
}
</verbatim>
If =$user= is =undef=, it defaults to the currently logged-in user.

   * $id can be a login name or a WikiName
   * Nested groups are expanded unless $options{ expand => } is set to false.

=cut

sub isGroupMember {
    my $this = shift;
    my ( $group, $user, $options ) = @_;
    my $users = $this->users;

    my $expand = isTrue( $options->{expand}, 1 );

    return () unless $users->isGroup($group);
    if ($user) {

        #my $login = wikiToUserName( $user );
        #return 0 unless $login;
        $user = $this->getCanonicalUserID($user) || $user;
    }
    else {
        $user = $this->user;
    }
    return $users->isInGroup( $user, $group, { expand => $expand } );
}

=begin TML

---+++ ObjectMethod eachUser() -> $iterator
Get an iterator over the list of all the registered users *not* including
groups. The iterator will return each wiki name in turn (e.g. 'FredBloggs').

Use it as follows:
<verbatim>
    my $it = $app->eachUser();
    while ($it->hasNext()) {
        my $user = $it->next();
        # $user is a wikiname
    }
</verbatim>

*WARNING* on large sites, this could be a long list!

=cut

# SMELL Better be something like usersIterator method in Foswiki::Users.
sub eachUser {
    my $this  = shift;
    my $users = $this->users;
    my $it    = $users->eachUser();
    $it->process(
        sub {
            return $users->getWikiName( $_[0] );
        }
    );
    return $it;
}

=begin TML

---+++ ObjectMethod eachMembership($id) -> $iterator
   * =$id= - WikiName or login name of the user.
     If =$id= is =undef=, defaults to the currently logged-in user.
Get an iterator over the names of all groups that the user is a member of.

=cut

sub eachMembership {
    my $this   = shift;
    my ($user) = @_;
    my $users  = $this->users;

    if ($user) {
        my $login = $this->wikiToUserName($user);
        return 0 unless $login;
        $user = $this->getCanonicalUserID($login);
    }
    else {
        $user = $this->user;
    }

    return $users->eachMembership($user);
}

=begin TML

---+++ eachGroupMember($group) -> $iterator
Get an iterator over all the members of the named group. Returns undef if
$group is not a valid group.  Nested groups are expanded unless the
expand option is set to false.

Use it as follows:  Process all users in RadioHeadGroup without expanding nested groups
<verbatim>
    my $iterator = $app->eachGroupMember('RadioheadGroup', {expand => 'false');
    while ($it->hasNext()) {
        my $user = $it->next();
        # $user is a wiki name e.g. 'TomYorke', 'PhilSelway'
        #   With expand set to false, group names can also be returned.
        #   Users are not checked to exist.
    }
</verbatim>

*WARNING* on large sites, this could be a long list!

=cut

sub eachGroupMember {
    my $this = shift;
    my ( $user, $options ) = @_;

    my $users = $this->users;

    my $expand = isTrue( $options->{expand}, 1 );

    return
      unless $users->isGroup($user);
    my $it = $users->eachGroupMember( $user, { expand => $expand } );
    $it->process(
        sub {
            return $users->getWikiName( $_[0] );
        }
    );
    return $it;
}

=begin TML

---+++ addUserToGroup( $id, $group, $create ) -> $boolean

   * $id can be a login name or a WikiName

=cut

sub addUserToGroup {
    my $this = shift;
    my ( $user, $group, $create ) = @_;
    my $users = $this->users;

    return () unless ( $users->isGroup($group) || $create );
    if ( defined $user && !$users->isGroup($user) )
    {    #requires isInGroup to also work on nested groupnames
        $user = $this->getCanonicalUserID($user) || $user;
        return unless ( defined($user) );
    }
    return $users->addUserToGroup( $user, $group, $create );
}

=begin TML

---+++ removeUserFromGroup( $group, $id ) -> $boolean

   * $id can be a login name or a WikiName

=cut

sub removeUserFromGroup {
    my $this = shift;
    my ( $user, $group ) = @_;
    my $users = $this->users;

    return () unless $users->isGroup($group);

    if ( !$users->isGroup($user) )
    {    #requires isInGroup to also work on nested groupnames
        $user = $this->getCanonicalUserID($user) || $user;
        return unless ( defined($user) );
    }
    return $users->removeUserFromGroup( $user, $group );
}

=begin TML

---+++ ObjectMethod checkAccessPermission( $type, $id, $text, $topic, $web, $meta ) -> $boolean

Check access permission for a topic based on the
[[%SYSTEMWEB%.AccessControl]] rules
   * =$type=     - Access type, required, e.g. ='VIEW'=, ='CHANGE'=.
   * =$id=  - WikiName of remote user, required, e.g. ="RickShaw"=.
     $id may also be a login name.
     If =$id= is '', 0 or =undef= then access is *always permitted*.  This is used
     by other functions if the caller should be able to bypass access checks.
   * =$text=     - Topic text, optional. If 'perl false' (undef, 0 or ''),
     topic =$web.$topic= is consulted. =$text= may optionally contain embedded
     =%META:PREFERENCE= tags. Provide this parameter if:
      1 You are setting different access controls in the text to those defined
      in the stored topic,
      1 You already have the topic text in hand, and want to help avoid
        having to read it again,
      1 You are providing a =$meta= parameter.
   * =$topic=    - Topic name, optional, e.g. ='PrivateStuff'=, '' or =undef=
      * If undefined, the Web preferences are checked.
      * If null, the default (WebHome) topic is checked.
      * If topic specified but does not exist, the web preferences are checked, 
      allowing the caller to determine 
      _"If the topic existed, would the operation be permitted"._
   * =$web=      - Web name, required, e.g. ='Sandbox'=
      * If missing, the default Users Web (Main) is used.
   * =$meta=     - Meta-data object, as returned by =readTopic=. Optional.
     If =undef=, but =$text= is defined, then access controls will be parsed
     from =$text=. If defined, then metadata embedded in =$text= will be
     ignored. This parameter is always ignored if =$text= is undefined.
     Settings in =$meta= override =Set= settings in $text.
A perl true result indicates that access is permitted.

*Note* the weird parameter order is due to compatibility constraints with
earlier releases.

<blockquote class="foswikiHelp">
%T% *Tip:* if you want, you can use this method to check your own access control types. For example, if you:
   * Set ALLOWTOPICSPIN = IncyWincy
in =ThatWeb.ThisTopic=, then a call to =checkAccessPermission('SPIN', 'IncyWincy', undef, 'ThisTopic', 'ThatWeb', undef)= will return =true=.
</blockquote>

*Example code:*

<verbatim>
    use Try::Tiny;
    use Foswiki::AccessControlException;
    ...
    unless (
        $app->checkAccessPermission(
            "VIEW", $session->{user}, undef, $topic, $web
        )
      )
    {
        Foswiki::AccessControlException->throw( "VIEW", $session->{user}, $web,
            $topic,  $Foswiki::Meta::reason );
    }
</verbatim>

=cut

sub checkAccessPermission {
    my $this = shift;
    my ( $type, $user, $text, $inTopic, $inWeb, $meta ) = @_;
    return 1 unless ($user);

    my ( $web, $topic ) = $this->_checkWTA( $inWeb, $inTopic );
    return 0 unless defined $web;    #Web name is illegal.
    if ( defined $inTopic ) {
        my $top = $topic;
        return 0 unless ( defined $topic );    #Topic name is illegal
    }

    $text = undef unless $text;
    my $cUID = $this->getCanonicalUserID($user)
      || $this->getCanonicalUserID( $this->cfg->data->{DefaultUserLogin} );
    if ( !defined($meta) ) {
        if ($text) {
            $meta = $this->create(
                'Foswiki::Meta',
                web   => $web,
                topic => $topic,
                text  => $text
            );
        }
        else {
            $meta = Foswiki::Meta->load( $this, $web, $topic );
        }
    }
    elsif ($text) {

        # don't alter an existing $meta using the provided text;
        # use a temporary clone instead
        my $tmpMeta = $this->create(
            'Foswiki::Meta',
            web   => $web,
            topic => $topic,
            text  => $text
        );
        $tmpMeta->copyFrom($meta);
        $meta = $tmpMeta;

    }    # Otherwise meta overrides text - Item2953

    return $meta->haveAccess( $type, $cUID );
}

=begin TML

---+++ ObjectMethod getListOfWebs( $filter [, $web] ) -> @webs

   * =$filter= - spec of web types to recover
Gets a list of webs, filtered according to the spec in the $filter,
which may include one of:
   1 'user' (for only user webs)
   2 'template' (for only template webs i.e. those starting with "_")
=$filter= may also contain the word 'public' which will further filter
out webs that have NOSEARCHALL set on them.
'allowed' filters out webs the current user can't read.
   * =$web= - (*Since* 2009-01-01) name of web to get list of subwebs for. Defaults to the root.
              note that if set, the list will not contain the web specified in $web

For example, the deprecated getPublicWebList function can be duplicated
as follows:
<verbatim>
   my @webs = $app->getListOfWebs( "user,public" );
</verbatim>

=cut

sub getListOfWebs {
    my $this   = shift;
    my $filter = shift;
    my $web    = shift;
    if ( defined $web ) {
        $web = $this->_checkWTA($web);
        return () unless defined $web;
    }
    my $f = new Foswiki::WebFilter( $filter || '' );
    return $this->deepWebList( $f, $web );
}

=begin TML

---+++ ObjectMethod webExists( $web ) -> $boolean

Test if web exists
   * =$web= - Web name, required, e.g. ='Sandbox'=

=cut

sub webExists {
    my $this = shift;
    my ($web) = $this->_checkWTA(@_);
    return 0 unless defined $web;

    return $this->store->webExists($web);
}

=begin TML

---+++ ObjectMethod topicExists( $web, $topic ) -> $boolean

Test if topic exists
   * =$web=   - Web name, optional, e.g. ='Main'=.
   * =$topic= - Topic name, required, e.g. ='TokyoOffice'=, or ="Main.TokyoOffice"=

$web and $topic are parsed as described in the documentation for =normalizeWebTopicName=.
Specifically, the %USERSWEB% is used if $web is not specified and $topic has no web specifier.
To get an expected behaviour it is recommened to specify the current web for $web; don't leave it empty.

=cut

sub topicExists {
    my $this = shift;
    my ( $web, $topic ) = $this->_checkWTA(@_);
    return 0 unless defined $web && defined $topic;
    return $this->store->topicExists( $web, $topic );
}

=begin TML

---+++ ObjectMethod readTopic( $web, $topic, $rev ) -> ( $meta, $text )

Read topic text and meta data, regardless of access permissions.
   * =$web= - Web name, required, e.g. ='Main'=
   * =$topic= - Topic name, required, e.g. ='TokyoOffice'=
   * =$rev= - revision to read (default latest)
Return: =( $meta, $text )= Meta data object and topic text

=$meta= is a perl 'object' of class =Foswiki::Meta=. This class is
fully documented in the source code documentation shipped with the
release, or can be inspected in the =lib/Foswiki/Meta.pm= file.

This method *ignores* topic access permissions. You should be careful to use
=checkAccessPermission= to ensure the current user has read access to the
topic.

=cut

sub readTopic {
    my $this = shift;

    my ( $web, $topic, $rev ) = @_;
    ( $web, $topic ) = $this->_validateWTA( $web, $topic );

    my $meta = Foswiki::Meta->load( $this, $web, $topic, $rev );
    return ( $meta, $meta->text() );
}

=begin TML

---+++ ObjectMethod getTopicList( $web ) -> @topics

Get list of all topics in a web
   * =$web= - Web name, required, e.g. ='Sandbox'=
Return: =@topics= Topic list, e.g. =( 'WebChanges',  'WebHome', 'WebIndex', 'WebNotify' )=

=cut

sub getTopicList {
    my $this = shift;

    my ($web) = $this->_validateWTA(@_);

    my $webObject = $this->create( 'Foswiki::Meta', web => $web );
    my $it = $webObject->eachTopic();
    return $it->all();
}

=begin TML

---+++ ObjectMethod getRevisionInfo($web, $topic, $rev, $attachment ) -> ( $date, $user, $rev, $comment ) 

Get revision info of a topic or attachment
   * =$web= - Web name, optional, e.g. ='Main'=
   * =$topic=   - Topic name, required, e.g. ='TokyoOffice'=
   * =$rev=     - revsion number, or tag name (can be in the format 1.2, or just the minor number)
   * =$attachment=                 -attachment filename
Return: =( $date, $user, $rev, $comment )= List with: ( last update date, login name of last user, minor part of top revision number, comment of attachment if attachment ), e.g. =( 1234561, 'phoeny', "5",  )=
| $date | in epochSec |
| $user | Wiki name of the author (*not* login name) |
| $rev | actual rev number |
| $comment | comment given for uploaded attachment |

NOTE: if you are trying to get revision info for a topic, use
=$meta->getRevisionInfo= instead if you can - it is significantly
more efficient.

=cut

sub getRevisionInfo {
    my $this = shift;
    my ( $web, $topic, $rev, $attachment ) = @_;

    ( $web, $topic ) = $this->_validateWTA( $web, $topic );

    my $topicObject;
    my $info;
    if ($attachment) {
        $topicObject = Foswiki::Meta->load( $this, $web, $topic );
        $info = $topicObject->getRevisionInfo( $attachment, $rev );
    }
    else {
        $topicObject = Foswiki::Meta->load( $this, $web, $topic, $rev );
        $info = $topicObject->getRevisionInfo();
    }
    return ( $info->{date}, $this->users->getWikiName( $info->{author} ),
        $info->{version}, $info->{comment} );
}

=begin TML

---+++ ObjectMethod getRevisionAtTime( $web, $topic, $time ) -> $rev

Get the revision number of a topic at a specific time.
   * =$web= - web for topic
   * =$topic= - topic
   * =$time= - time (in epoch secs) for the rev
Return: Single-digit revision number, or undef if it couldn't be determined
(either because the topic isn't that old, or there was a problem)

=cut

sub getRevisionAtTime {
    my $this = shift;
    my ( $web, $topic, $time ) = @_;
    ( $web, $topic ) = $this->_validateWTA( $web, $topic );
    my $topicObject = $this->create(
        'Foswiki::Meta',
        web   => $web,
        topic => $topic
    );
    return $topicObject->getRevisionAtTime($time);
}

=begin TML

---+++ ObjectMethod getAttachmentList( $web, $topic ) -> @list
Get a list of the attachments on the given topic.

*Since:* 31 Mar 2009

=cut

sub getAttachmentList {
    my $this = shift;
    my ( $web, $topic ) = @_;
    ( $web, $topic ) = $this->_validateWTA( $web, $topic );
    my $topicObject = $this->create(
        'Foswiki::Meta',
        web   => $web,
        topic => $topic
    );
    my $it = $topicObject->eachAttachment();
    return sort $it->all();
}

=begin TML

---+++ ObjectMethod attachmentExists( $web, $topic, $attachment ) -> $boolean

Test if attachment exists
   * =$web=   - Web name, optional, e.g. =Main=.
   * =$topic= - Topic name, required, e.g. =TokyoOffice=, or =Main.TokyoOffice=
   * =$attachment= - attachment name, e.g.=logo.gif=
$web and $topic are parsed as described in the documentation for =normalizeWebTopicName=.

The attachment must exist in the store (it is not sufficient for it to be referenced
in the object only)

=cut

sub attachmentExists {
    my $this = shift;
    my ( $web, $topic, $attachment ) = $this->_checkWTA(@_);
    return 0 unless defined $web && defined $topic && $attachment;

    my $topicObject = $this->create(
        'Foswiki::Meta',
        web   => $web,
        topic => $topic
    );
    return $topicObject->hasAttachment($attachment);
}

=begin TML

---+++ ObjectMethod readAttachment( $web, $topic, $name, $rev ) -> $data

   * =$web= - web for topic - must not be tainted
   * =$topic= - topic - must not be tainted
   * =$name= - attachment name - must not be tainted
   * =$rev= - revision to read (default latest)
Read an attachment from the store for a topic, and return it as a string. The
names of attachments on a topic can be recovered from the meta-data returned
by =readTopic=. If the attachment does not exist, or cannot be read, undef
will be returned. If the revision is not specified, the latest version will
be returned.

View permission on the topic is required for the
read to be successful.  Access control violations are flagged by a
Foswiki::AccessControlException. Permissions are checked for the current user.

<verbatim>
use Try::Tiny;
use Foswiki::AccessControlException ();

my( $meta, $text ) = Foswiki::Func::readTopic( $web, $topic );
my @attachments = $meta->find( 'FILEATTACHMENT' );
foreach my $a ( @attachments ) {
   try {
       my $data = Foswiki::Func::readAttachment( $web, $topic, $a->{name} );
       ...
   } catch Foswiki::AccessControlException with {
   };
}
</verbatim>

This is the way 99% of extensions will access attachments.
See =Foswiki::Meta::openAttachment= for a lower level interface that does
not check access controls.

=cut

sub readAttachment {
    my $this = shift;
    my ( $web, $topic, $attachment, $rev ) = @_;

    ( $web, $topic, $attachment ) =
      $this->_validateWTA( $web, $topic, $attachment );
    Foswiki::Exception::Fatal->throw( text => "Invalid attachment" )
      unless $attachment;

    my $result;

    my $topicObject = $this->create(
        'Foswiki::Meta',
        web   => $web,
        topic => $topic
    );
    unless ( $topicObject->haveAccess('VIEW') ) {
        Foswiki::AccessControlException->throw(
            mode   => 'VIEW',
            user   => $this->user,
            web    => $web,
            topic  => $topic,
            reason => $topicObject->reason,
        );
    }
    my $fh;
    try {
        $fh = $topicObject->openAttachment( $attachment, '<', version => $rev );
    }
    catch {
        # SMELL XXX Exception must be processed and perhaps propagaded!
        $fh = undef;
    };
    return undef unless $fh;
    local $/;
    my $data = <$fh>;
    return $data;
}

=begin TML

---++ Manipulating

=cut

=begin TML

---+++ ObjectMethod createWeb( $newWeb, $baseWeb, $opts )

   * =$newWeb= is the name of the new web.
   * =$baseWeb= is the name of an existing web (a template web). If the base
     web is a system web, all topics in it will be copied into the new web. If it is
     a normal web, only topics starting with 'Web' will be copied. If no base web is
     specified, an empty web (with no topics) will be created. If it is specified
     but does not exist, an error will be thrown.
   * =$opts= is a ref to a hash that contains settings to be modified in
the web preferences topic in the new web.

<verbatim>
use Try::Tiny;
use Foswiki::AccessControlException ();

try {
    Foswiki::Func::createWeb( "Newweb" );
} catch Foswiki::AccessControlException with {
    my $e = shift;
    # see documentation on Foswiki::AccessControlException
} catch Foswiki::OopsException with {
        shift->throw();    # propagate
} catch Error with {
    my $e = shift;
    # see documentation on Error
} otherwise {
    ...
};
</verbatim>

=cut

sub createWeb {
    my $this = shift;
    my ( $web, $baseweb, $opts ) = @_;
    ($web) = $this->_validateWTA($web);
    if ( defined $baseweb ) {
        ($baseweb) = $this->_validateWTA($baseweb);
    }

    my ($parentWeb) = $web =~ m#(.*)/[^/]+$#;

    my $rootObject = $this->create( 'Foswiki::Meta', web => $parentWeb );
    unless ( $rootObject->haveAccess('CHANGE') ) {
        Foswiki::AccessControlException->throw(
            mode   => 'CHANGE',
            user   => $this->user,
            web    => $web,
            topic  => '',
            reason => $rootObject->reason,
        );
    }

    my $baseObject = $this->create( 'Foswiki::Meta', web => $baseweb );
    unless ( $baseObject->haveAccess('VIEW') ) {
        Foswiki::AccessControlException->throw(
            mode   => 'VIEW',
            user   => $this->user,
            web    => $web,
            topic  => '',
            reason => $baseObject->reason,
        );
    }

    my $webObject = $this->create( 'Foswiki::Meta', web => $web );
    $webObject->populateNewWeb( $baseweb, $opts );
}

=begin TML

---+++ ObjectMethod moveWeb( $oldName, $newName )

Move (rename) a web.

<verbatim>
use Try::Tiny;
use Foswiki::AccessControlException ();

try {
    Foswiki::Func::moveWeb( "Oldweb", "Newweb" );
} catch Foswiki::AccessControlException with {
    my $e = shift;
    # see documentation on Foswiki::AccessControlException
} catch Foswiki::OopsException with {
        shift->throw();    # propagate
} catch Error with {
    my $e = shift;
    # see documentation on Error::Simple
} otherwise {
    ...
};
</verbatim>

To delete a web, move it to a subweb of =Trash=
<verbatim>
Foswiki::Func::moveWeb( "Deadweb", "Trash.Deadweb" );
</verbatim>

=cut

sub moveWeb {
    my $this = shift;
    my ( $from, $to ) = @_;
    ($from) = $this->_validateWTA($from);
    ($to)   = $this->_validateWTA($to);

    $from = $this->create( 'Foswiki::Meta', web => $from );
    $to   = $this->create( 'Foswiki::Meta', web => $to );
    return $from->move($to);
}

=begin TML

---+++ ObjectMethod checkTopicEditLock( $web, $topic, $script ) -> ( $oopsUrl, $loginName, $unlockTime )

Check if a lease has been taken by some other user.
   * =$web= Web name, e.g. ="Main"=, or empty
   * =$topic= Topic name, e.g. ="MyTopic"=, or ="Main.MyTopic"=
Return: =( $oopsUrl, $loginName, $unlockTime )= - The =$oopsUrl= for calling =redirect()=, user's =$loginName=, and estimated =$unlockTime= in minutes, or ( '', '', 0 ) if no lease exists.
   * =$script= The script to invoke when continuing with the edit

=cut

sub checkTopicEditLock {
    my $this = shift;
    my ( $web, $topic, $script ) = @_;

    ( $web, $topic ) = $this->_checkWTA( $web, $topic );
    return ( '', '', 0 ) unless defined $web && defined $topic;

    $script ||= 'edit';

    my $topicObject = $this->create(
        'Foswiki::Meta',
        web   => $web,
        topic => $topic
    );
    my $lease = $topicObject->getLease();
    if ($lease) {
        my $remain = $lease->{expires} - time();

        if ( $remain > 0 ) {
            my $who  = $lease->{user};
            my $past = Foswiki::Time::formatDelta( time() - $lease->{taken},
                $this->i18n );
            my $future = Foswiki::Time::formatDelta( $lease->{expires} - time(),
                $this->i18n );
            my $url = $this->getScriptUrl(
                $web, $topic, 'oops',
                template => 'oopsleaseconflict',
                def      => 'lease_active',
                param1   => $who,
                param2   => $past,
                param3   => $future,
                param4   => $script
            );
            my $login = $this->users->getLoginName($who);
            return ( $url, $login || $who, $remain / 60 );
        }
    }
    return ( '', '', 0 );
}

=begin TML

---+++ ObjectMethod setTopicEditLock( $web, $topic, $lock )

   * =$web= Web name, e.g. ="Main"=, or empty
   * =$topic= Topic name, e.g. ="MyTopic"=, or ="Main.MyTopic"=
   * =$lock= 1 to lease the topic, 0 to clear an existing lease

Takes out a "lease" on the topic. The lease doesn't prevent
anyone from editing and changing the topic, but it does redirect them
to a warning screen, so this provides some protection. The =edit= script
always takes out a lease.

It is *impossible* to fully lock a topic. Concurrent changes will be
merged.

=cut

sub setTopicEditLock {
    my $this = shift;
    my ( $web, $topic, $lock ) = @_;
    ( $web, $topic ) = $this->_validateWTA( $web, $topic );
    my $topicObject = $this->create(
        'Foswiki::Meta',
        web   => $web,
        topic => $topic
    );
    if ($lock) {
        $topicObject->setLease( $this->cfg->data->{LeaseLength} );
    }
    else {
        $topicObject->clearLease();
    }
    return '';
}

=begin TML

---+++ ObjectMethod saveTopic( $web, $topic, $meta, $text, $options )

   * =$web= - web for the topic
   * =$topic= - topic name
   * =$meta= - reference to Foswiki::Meta object 
     (optional, set to undef to create a new topic containing just text,
     or to just change that topic's text)
   * =$text= - text of the topic (without embedded meta-data!!!
   * =\%options= - ref to hash of save options
     =\%options= may include:
     | =dontlog= | mark this change so it doesn't appear in the statistics |
     | =minor= | True if this change is not to be notified |
     | =forcenewrevision= | force the save to increment the revision counter |
     | =ignorepermissions= | don't check acls |
For example,
<verbatim>
use Try::Tiny;
use Foswiki::AccessControlException ();

my( $meta, $text );
if ($app->topicExists($web, $topic)) {
    ( $meta, $text ) = $app->readTopic( $web, $topic );
} else {
    #if the topic doesn't exist, we can either leave $meta undefined
    #or if we need to set more than just the topic text, we create a new Meta object and use it.
    $meta = $app->create('Foswiki::Meta', web => $web, topic => $topic );
    $text = '';
}
$text =~ s/APPLE/ORANGE/g;
try {
    $app->saveTopic( $web, $topic, $meta, $text );
} catch Foswiki::AccessControlException with {
    my $e = shift;
    # see documentation on Foswiki::AccessControlException
} catch Foswiki::OopsException with {
        shift->throw();    # propagate
} catch Error with {
    my $e = shift;
    # see documentation on Error::Simple
} otherwise {
    ...
};
</verbatim>

In the event of an error an exception will be thrown. Callers can elect
to trap the exceptions thrown, or allow them to propagate to the calling
environment. May throw Foswiki::OopsException or Error::Simple.

*Note:* The =ignorepermissions= option is only available in Foswiki 1.1 and
later.

=cut

sub saveTopic {
    my $this = shift;
    my ( $web, $topic, $smeta, $text, $options ) = @_;
    ( $web, $topic ) = $this->_validateWTA( $web, $topic );
    my $topicObject = $this->create(
        'Foswiki::Meta',
        web   => $web,
        topic => $topic
    );

    $options //= {};

    unless ( $options->{ignorepermissions}
        || $topicObject->haveAccess('CHANGE') )
    {
        Foswiki::AccessControlException->throw(
            mode   => 'CHANGE',
            user   => $this->user,
            web    => $web,
            topic  => $topic,
            reason => $topicObject->reason,
        );
    }

    # Set the new text and meta, now that access to the existing topic
    # is verified
    $topicObject->text($text);
    $topicObject->copyFrom($smeta) if $smeta;
    return $topicObject->save(%$options);
}

=begin TML

---+++ ObjectMethod moveTopic( $web, $topic, $newWeb, $newTopic )

   * =$web= source web - required
   * =$topic= source topic - required
   * =$newWeb= dest web
   * =$newTopic= dest topic
Renames the topic. Throws an exception if something went wrong.
If $newWeb is undef, it defaults to $web. If $newTopic is undef, it defaults
to $topic.

The destination topic must not already exist.

Rename a topic to the $Foswiki::cfg{TrashWebName} to delete it.

<verbatim>
use Try::Tiny;

try {
    moveTopic( "Work", "TokyoOffice", "Trash", "ClosedOffice" );
} catch Foswiki::AccessControlException with {
    my $e = shift;
    # see documentation on Foswiki::AccessControlException
} catch Foswiki::OopsException with {
        shift->throw();    # propagate
} catch Error with {
    my $e = shift;
    # see documentation on Error::Simple
} otherwise {
    ...
};
</verbatim>

=cut

sub moveTopic {
    my $this = shift;
    my ( $web, $topic, $newWeb, $newTopic ) = @_;
    ( $web, $topic ) = $this->_validateWTA( $web, $topic );
    ( $newWeb, $newTopic ) =
      $this->_validateWTA( $newWeb || $web, $newTopic || $topic );

    return if ( $newWeb eq $web && $newTopic eq $topic );

    my $from = $this->create(
        'Foswiki::Meta',
        web   => $web,
        topic => $topic
    );
    unless ( $from->haveAccess('CHANGE') ) {
        Foswiki::AccessControlException->throw(
            mode   => 'CHANGE',
            user   => $this->user,
            web    => $web,
            topic  => $topic,
            reason => $from->reason,
        );
    }

    my $toWeb = $this->create( 'Foswiki::Meta', web => $newWeb );
    unless ( $from->haveAccess('CHANGE') ) {
        Foswiki::AccessControlException->throw(
            mode   => 'CHANGE',
            user   => $this->user,
            web    => $newWeb,
            topic  => undef,
            reason => $toWeb->reason,
        );
    }

    my $to = $this->create(
        'Foswiki::Meta',
        web   => $newWeb,
        topic => $newTopic
    );

    $from->move($to);
}

=begin TML

---+++ ObjectMethod saveAttachment( $web, $topic, $attachment, \%opts )
   * =$web= - web for topic
   * =$topic= - topic to atach to
   * =$attachment= - name of the attachment
   * =\%opts= - Ref to hash of options
Create an attachment on the given topic.
=\%opts= may include:
| =dontlog= | mark this change so it is not picked up in statistics |
| =comment= | comment for save |
| =hide= | if the attachment is to be hidden in normal topic view |
| =stream= | Stream of file to upload |
| =file= | Name of a file to use for the attachment data. ignored if stream is set. Local file on the server. |
| =filepath= | Client path to file |
| =filesize= | Size of uploaded data |
| =filedate= | Date |
| =createlink= | Set true to create a link at the end of the topic |
| =notopicchange= | Set to true to *prevent* this upload being recorded in the meta-data of the topic. |
Save an attachment to the store for a topic. On success, returns undef.
If there is an error, an exception will be thrown. The current user must
have CHANGE access on the topic being attached to.

<verbatim>
    try {
        Foswiki::Func::saveAttachment( $web, $topic, 'image.gif',
                                     { file => 'image.gif',
                                       comment => 'Picture of Health',
                                       hide => 1 } );
   } catch Foswiki::AccessControlException with {
      # Topic CHANGE access denied
   } catch Foswiki::OopsException with {
        shift->throw();    # propagate
   } catch Error with {
      # see documentation on Error
   } otherwise {
      ...
   };
</verbatim>
This is the way 99% of extensions will create new attachments. See
=Foswiki::Meta::openAttachment= for a much lower-level interface.

=cut

sub saveAttachment {
    my $this = shift;
    my ( $web, $topic, $attachment, $data ) = @_;
    ( $web, $topic, $attachment ) =
      $this->_validateWTA( $web, $topic, $attachment );
    Foswiki::Exception::Fatal->throw( text => "Invalid attachment" )
      unless $attachment;

    my $topicObject = $this->create(
        'Foswiki::Meta',
        web   => $web,
        topic => $topic
    );
    unless ( $topicObject->haveAccess('CHANGE') ) {
        Foswiki::AccessControlException->throw(
            mode   => 'CHANGE',
            user   => $this->user,
            web    => $web,
            topic  => $topic,
            reason => $topicObject->reason,
        );
    }
    $topicObject->attach( name => $attachment, %$data );
}

=begin TML

---+++ ObjectMethod moveAttachment( $web, $topic, $attachment, $newWeb, $newTopic, $newAttachment )

   * =$web= source web - required
   * =$topic= source topic - required
   * =$attachment= source attachment - required
   * =$newWeb= dest web
   * =$newTopic= dest topic
   * =$newAttachment= dest attachment
Renames the attachment. Throws an exception on error or access violation.
If $newWeb is undef, it defaults to $web. If $newTopic is undef, it defaults
to $topic. If $newAttachment is undef, it defaults to $attachment. If all of $newWeb, $newTopic and $newAttachment are undef, it is an error.

The destination topic must already exist, but the destination attachment must
*not* exist.

Rename an attachment to $Foswiki::cfg{TrashWebName}.TrashAttament to delete it.

<verbatim>
use Try::Tiny;

try {
   # move attachment between topics
   moveAttachment( "Countries", "Germany", "AlsaceLorraine.dat",
                     "Countries", "France" );
   # Note destination attachment name is defaulted to the same as source
} catch Foswiki::AccessControlException with {
   my $e = shift;
   # see documentation on Foswiki::AccessControlException
} catch Foswiki::OopsException with {
        shift->throw();    # propagate
} catch Error with {
   my $e = shift;
   # see documentation on Error
};
</verbatim>

=cut

sub moveAttachment {
    my $this = shift;
    my ( $web, $topic, $attachment, $newWeb, $newTopic, $newAttachment ) = @_;

    ( $web, $topic, $attachment ) =
      $this->_validateWTA( $web, $topic, $attachment );
    Foswiki::Exception::Fatal->throw( text => "Invalid attachment" )
      unless $attachment;

    ( $newWeb, $newTopic, $newAttachment ) = $this->_validateWTA(
        $newWeb        || $web,
        $newTopic      || $topic,
        $newAttachment || $attachment
    );

    return
      if ( $newWeb eq $web
        && $newTopic eq $topic
        && $newAttachment eq $attachment );

    my $from = Foswiki::Meta->load( $this, $web, $topic );
    unless ( $from->haveAccess('CHANGE') ) {
        Foswiki::AccessControlException->throw(
            mode  => 'CHANGE',
            user  => $this->user,
            web   => $web,
            topic => $topic,
            reson => $from->reason,
        );
    }
    my @opts;
    push( @opts, new_name => $newAttachment ) if defined $newAttachment;

    if (   $web eq $newWeb
        && $topic eq $newTopic
        && defined $newAttachment )
    {
        $from->moveAttachment( $attachment, $from, @opts );
    }
    else {
        my $to = Foswiki::Meta->load( $this, $newWeb, $newTopic );
        unless ( $to->haveAccess('CHANGE') ) {
            Foswiki::AccessControlException->throw(
                mode   => 'CHANGE',
                user   => $this->user,
                web    => $newWeb,
                topic  => $newTopic,
                reason => $to->reason,
            );
        }

        $from->moveAttachment( $attachment, $to, @opts );
    }
}

=begin TML

---+++ ObjectMethod copyAttachment( $web, $topic, $attachment, $newWeb, $newTopic, $newAttachment )

   * =$web= source web - required
   * =$topic= source topic - required
   * =$attachment= source attachment - required
   * =$newWeb= dest web
   * =$newTopic= dest topic
   * =$newAttachment= dest attachment
Copies the attachment. Throws an exception on error or access violation.
If $newWeb is undef, it defaults to $web. If $newTopic is undef, it defaults
to $topic. If $newAttachment is undef, it defaults to $attachment. If all of $newWeb, $newTopic and $newAttachment are undef, it is an error.

The destination topic must already exist, but the destination attachment must
*not* exist.

<verbatim>
use Try::Tiny;

try {
   # copy attachment between topics
   copyAttachment( "Countries", "Germany", "AlsaceLorraine.dat",
                     "Countries", "France" );
   # Note destination attachment name is defaulted to the same as source
} catch Foswiki::AccessControlException with {
   my $e = shift;
   # see documentation on Foswiki::AccessControlException
} catch Foswiki::OopsException with {
        shift->throw();    # propagate
} catch Error with {
   my $e = shift;
   # see documentation on Error
};
</verbatim>

*Since:* 19 Jul 2010

=cut

sub copyAttachment {
    my $this = shift;
    my ( $web, $topic, $attachment, $newWeb, $newTopic, $newAttachment ) = @_;

    ( $web, $topic, $attachment ) =
      $this->_validateWTA( $web, $topic, $attachment );
    Foswiki::Exception::Fatal->throw( text => "Invalid attachment" )
      unless $attachment;

    ( $newWeb, $newTopic, $newAttachment ) = $this->_validateWTA(
        $newWeb        || $web,
        $newTopic      || $topic,
        $newAttachment || $attachment
    );

    return
      if ( $newWeb eq $web
        && $newTopic eq $topic
        && $newAttachment eq $attachment );

    my $from = Foswiki::Meta->load( $this, $web, $topic );
    unless ( $from->haveAccess('CHANGE') ) {
        Foswiki::AccessControlException->throw(
            mode   => 'CHANGE',
            user   => $this->user,
            web    => $web,
            topic  => $topic,
            reason => $from->reason,
        );
    }
    my @opts;
    push( @opts, new_name => $newAttachment ) if defined $newAttachment;

    if (   $web eq $newWeb
        && $topic eq $newTopic
        && defined $newAttachment )
    {
        $from->copyAttachment( $attachment, $from, @opts );
    }
    else {
        my $to = Foswiki::Meta->load( $this, $newWeb, $newTopic );
        unless ( $to->haveAccess('CHANGE') ) {
            Foswiki::AccessControlException->throw(
                mode   => 'CHANGE',
                user   => $this->user,
                web    => $newWeb,
                topic  => $newTopic,
                reason => $to->reason,
            );
        }

        $from->copyAttachment( $attachment, $to, @opts );
    }
}

=begin TML

---++ Finding changes

=cut

=begin TML

---+++ ObjectMethod eachChangeSince($web, $time) -> $iterator

Get an iterator over the list of all the changes in the given web between
=$time= and now. $time is a time in seconds since 1st Jan 1970, and is not
guaranteed to return any changes that occurred before (now - 
{Store}{RememberChangesFor}). {Store}{RememberChangesFor}) is a
setting in =configure=. Changes are returned in *most-recent-first*
order.

Use it as follows:
<verbatim>
    my $iterator = $app->eachChangeSince(
        $web, time() - 7 * 24 * 60 * 60); # the last 7 days
    while ($iterator->hasNext()) {
        my $change = $iterator->next();
        ...
    }
</verbatim>
=$change= is a reference to a hash containing the following fields:
   * =verb= - the action - one of
      * =update= - a web, topic or attachment has been modified
      * =insert= - a web, topic or attachment is being inserted
      * =remove= - a topic or attachment is being removed
   * =time= - time of the change, in epoch-secs
   * =cuid= - canonical UID of the user who is making the change
   * =revision= - the revision of the topic that the change appears in
   * =path= - web.topic path for the affected
   * =attachment= - attachment name (optional)
   * =oldpath= - web.topic path for the origin of a move
   * =oldattachment= - origin of move
   * =minor= - boolean true if this change is flagged as minor
   * =comment= - descriptive text

The following additional fields are *deprecated* and will be removed
in Foswiki 2.0:
   * =more= - formatted string indicating if the change was minor or not
   * =topic= - name of the topic the change occurred to
   * =user= - wikiname of the user who made the change
These additional fields

If you are writing an extension that requires compatibility with
Foswiki < 2 only the =more=, =revision=, =time=, =topic= and =user=
can be assumed.

=cut

sub eachChangeSince {
    my $this = shift;
    my ( $web, $time ) = @_;
    ($web) = $this->_validateWTA($web);
    ASSERT( $this->store->webExists($web) ) if DEBUG;

    my $webObject = $this->create( 'Foswiki::Meta', web => $web );
    return $webObject->eachChange($time);
}

=begin TML

---+++ ObjectMethod summariseChanges($web, $topic, $orev, $nrev, $tml, $nochecks) -> $text
Generate a summary of the changes between rev $orev and rev $nrev of the
given topic.
   * =$web=, =$topic= - topic (required)
   * =$orev= - older rev (required)
   * =$nrev= - later rev (may be undef for the latest)
   * =$tml= - if true will generate renderable TML (i.e. HTML with NOPs. if false will generate a summary suitable for use in plain text (mail, for example)
Generate a (max 3 line) summary of the differences between the revs.
   * =$nochecks= if true, will suppress access control checks. (*Since* 2.0)

If there is only one rev, a topic summary will be returned.

If =$tml= is not set, all HTML will be removed.

In non-tml, lines are truncated to 70 characters. Differences are shown using + and - to indicate added and removed text.

If access is denied to either revision, then it will be treated as blank
text.

*Since* 2009-03-06

=cut

sub summariseChanges {
    my $this = shift;
    my ( $web, $topic, $orev, $nrev, $tml, $nochecks ) = @_;
    ( $web, $topic ) = $this->_validateWTA( $web, $topic );

    my $topicObject = $this->create(
        'Foswiki::Meta',
        web   => $web,
        topic => $topic
    );
    return $topicObject->summariseChanges(
        Foswiki::Store::cleanUpRevID($orev),
        Foswiki::Store::cleanUpRevID($nrev),
        $tml, $nochecks
    );
}

=begin TML

---++ Templates

=cut

=begin TML

---+++ ObjectMethod readTemplate( $name, $skin ) -> $text

Read a template or skin. Embedded [[%SYSTEMWEB%.SkinTemplates][template directives]] get expanded
   * =$name= - Template name, e.g. ='view'=
   * =$skin= - Comma-separated list of skin names, optional, e.g. ='print'=
Return: =$text=    Template text

=cut

sub readTemplate {
    my $this = shift;
    my ( $name, $skin ) = @_;
    return $this->templates->readTemplate(
        $name,
        skins   => $skin,
        no_oops => 1
    ) || '';
}

=begin TML

---+++ ObjectMethod loadTemplate ( $name, $skin, $web ) -> $text

   * =$name= - template file name
   * =$skin= - comma-separated list of skins to use (default: current skin)
   * =$web= - the web to look in for topics that contain templates (default: current web)
Return: expanded template text (what's left after removal of all %TMPL:DEF% statements)

Reads a template and extracts template definitions, adding them to the
list of loaded templates, overwriting any previous definition.

How Foswiki searches for templates is described in SkinTemplates.

If template text is found, extracts include statements and fully expands them.

=cut

sub loadTemplate {
    my $this = shift;
    my ( $name, $skin, $web ) = @_;

    my %opts = ( no_oops => 1 );
    $opts{skins} = $skin if defined $skin;
    ( $opts{web} ) = $this->_validateWTA($web) if defined $web;

    my $tmpl = $this->templates->readTemplate( $name, %opts );
    $tmpl = '' unless defined $tmpl;

    return $tmpl;
}

=begin TML

---+++ ObjectMethod expandCommonVariables( $text, $topic, $web, $meta ) -> $text

Expand all common =%<nop>VARIABLES%=
   * =$text=  - Text with variables to expand, e.g. ='Current user is %<nop>WIKIUSER%'=
   * =$topic= - Current topic name, optional, e.g. ='WebNotify'=
   * =$web=   - Web name, optional, e.g. ='Main'=. The current web is taken if missing
   * =$meta=  - topic meta-data to use while expanding
Return: =$text=     Expanded text, e.g. ='Current user is <nop>WikiGuest'=

See also: expandVariablesOnTopicCreation

*Caution:* This function needs all the installed plugins to have gone through initialization.
Never call this function from within an initPlugin handler,  bad things happen.

*Caution:* This function ultimately calls the following handlers:
   * =beforeCommonTagsHandler=
   * =commonTagsHandler=
   * =registered macro handlers=
   * =afterCommonTagsHandler=

%X% *It is possible to create an infinite loop if expandCommonVariables is called in any of these handlers.* 
It can be used, but care should be taken to ensure that the text being expanded does
not cause this function to be called recursively.

=cut

sub expandCommonVariables {
    my $this = shift;
    my ( $text, $topic, $web, $meta ) = @_;

    if (DEBUG) {
        for ( my $i = 4 ; $i <= 7 ; $i++ ) {
            my $caller = ( caller($i) )[3];
            Foswiki::Exception::Fatal->throw(
                text => "expandCommonVariables called during registration" )
              if ( defined $caller
                && $caller eq 'Foswiki::Plugin::registerHandlers' );
        }
    }

    ( $web, $topic ) = $this->_validateWTA( $web || $this->request->web,
        $topic || $this->request->topic );
    $meta ||= $this->create(
        'Foswiki::Meta',
        web   => $web,
        topic => $topic
    );

    return $meta->expandMacros($text);
}

=begin TML

---+++ ObjectMethod expandVariablesOnTopicCreation ( $text ) -> $text

Expand the limited set of variables that are always expanded during topic creation
   * =$text= - the text to process
Return: text with variables expanded

Expands only the variables expected in templates that must be statically
expanded in new content.

The expanded variables are:
   * =%<nop>DATE%= Signature-format date
   * =%<nop>SERVERTIME%= See [[Macros]]
   * =%<nop>GMTIME%= See [[Macros]]
   * =%<nop>USERNAME%= Base login name
   * =%<nop>WIKINAME%= Wiki name
   * =%<nop>WIKIUSERNAME%= Wiki name with prepended web
   * =%<nop>URLPARAM{...}%= - Parameters to the current CGI query
   * =%<nop>NOP%= No-op

See also: expandVariables

=cut

sub expandVariablesOnTopicCreation {
    my $this        = shift;
    my $topicObject = $this->create(
        'Foswiki::Meta',
        web   => $this->request->web,
        topic => $this->request->topic,
        text  => $_[0],
    );
    $topicObject->expandNewTopic();
    return $topicObject->text();
}

=begin TML

---+++ ObjectMethod renderText( $text, $web, $topic ) -> $text

Render text from TML into XHTML as defined in [[%SYSTEMWEB%.TextFormattingRules]]
   * =$text= - Text to render, e.g. ='*bold* text and =fixed font='=
   * =$web=  - Web name, optional, e.g. ='Main'=. The current web is taken if missing
   * =$topic= - topic name, optional, defaults to web home
Return: =$text=    XHTML text, e.g. ='&lt;b>bold&lt;/b> and &lt;code>fixed font&lt;/code>'=

NOTE: renderText expects that all %MACROS% have already been expanded - it does not expand them for you (call expandCommonVariables above).

=cut

sub renderText {
    my $this = shift;
    my ( $text, $web, $topic ) = @_;

    $web   ||= $this->request->web;
    $topic ||= $this->cfg->data->{HomeTopicName};
    my $webObject = $this->create(
        'Foswiki::Meta',
        web   => $web,
        topic => $topic
    );
    return $webObject->renderTML($text);
}

=begin TML

---+++ ObjectMethod internalLink( $pre, $web, $topic, $label, $anchor, $createLink ) -> $text

Render topic name and link label into an XHTML link. Normally you do not need to call this funtion, it is called internally by =renderText()=
   * =$pre=        - Text occuring before the link syntax, optional
   * =$web=        - Web name, required, e.g. ='Main'=
   * =$topic=      - Topic name to link to, required, e.g. ='WebNotify'=
   * =$label=      - Link label, required. Usually the same as =$topic=, e.g. ='notify'=
   * =$anchor=     - Anchor, optional, e.g. ='#Jump'=
   * =$createLink= - Set to ='1'= to add question linked mark after topic name if topic does not exist;<br /> set to ='0'= to suppress link for non-existing topics
Return: =$text=          XHTML anchor, e.g. ='&lt;a href='/cgi-bin/view/Main/WebNotify#Jump'>notify&lt;/a>'=

=cut

sub internalLink {
    my $this = shift;
    my $pre  = shift;

    return $pre . $this->renderer->internalLink(@_);
}

=begin TML

---+++ ObjectMethod query($searchString, $topics, \%options ) -> iterator (resultset)

Query the topic data in the specified webs. A programatic interface to SEARCH results.

   * =$searchString= - the search string, as appropriate for the selected type
   * =$topics= - undef OR reference to a ResultSet, Iterator, or array containing the web.topics to be evaluated. 
                 if undef, then all the topics in the webs specified will be evaluated.
   * =\%option= - reference to an options hash
The =\%options= hash may contain the following options:
   * =type= - =regex=, =keyword=, =query=, ... defaults to =query=
   * =web= - The web/s to search in - string can have the same form as the =web= param of SEARCH (if not specified, defaults to BASEWEB)
   * =casesensitive= - false to ignore case (default true)
   * =files_without_match= - true to return files only (default false). If =files_without_match= is specified, it will return on the first match in each topic (i.e. it will return only one match per 
   * topic, excludetopic and other params as per SEARCH)
   * =includeTopics= - Seach only in this topic, a topic with asterisk wildcards, or a list of topics separated by comma
   * =excludeTopics= - Exclude search in this topic, a topic with asterisk wildcards, or a list of topics separated by comma

To iterate over the returned topics use:
<verbatim>
    my $matches = $app->query( "Slimy Toad", undef,
            { web => 'Main,San*', casesensitive => 0, files_without_match => 0 } );
    while ($matches->hasNext) {
        my $webtopic = $matches->next;
        my ($web, $topic) = $app->request->normalizeWebTopicName('', $webtopic);
      ...etc
</verbatim>

=cut

sub query {
    my $this = shift;
    my ( $searchString, $topics, $options ) = @_;

    my $inputTopicSet = $topics;
    if ( $topics and ( ref($topics) eq 'ARRAY' ) ) {
        $inputTopicSet =
          $this->create( 'Foswiki::ListIterator', list => $topics );
    }
    $options->{type} ||= 'query';
    my $query = $this->search->parseSearch( $searchString, $options );

    return $this->store->query( $query, $inputTopicSet, $options );
}

=begin TML

---+++ ObjectMethod writeEvent( $action, $extra )

Log an event.
   * =$action= - name of the event (keep them unique!)
   * =$extra= - arbitrary extra information to add to the log.
You can enumerate the contents of the log using the =eachEventSince= function.

=cut

sub writeEvent {
    my $this = shift;
    my ( $action, $extra ) = @_;
    my $webTopic = $this->request->web . '.' . $this->request->topic;

    return $this->logger->log(
        {
            level    => 'info',
            action   => $action || '',
            webTopic => $webTopic || '',
            extra    => $extra || '',
        }
    );
}

=begin TML

---+++ ObjectMethof writeWarning( $text )

Log a warning that may require admin intervention to the warnings log (=data/warn*.txt=)
   * =$text= - Text to write; timestamp gets added

=cut

sub writeWarning {
    my $this = shift;
    return $this->logger->log(
        {
            level  => 'warning',
            caller => scalar( caller() ),
            extra  => \@_
        }
    );
}

=begin TML

---+++ ObjectMethod writeDebug( $text )

Log debug message to the debug log 
   * =$text= - Text to write; timestamp gets added

=cut

sub writeDebug {
    my $this = shift;
    return $this->logger->log(
        {
            level => 'debug',
            extra => \@_
        }
    );
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2016 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
