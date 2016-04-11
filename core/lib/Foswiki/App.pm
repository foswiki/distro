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
use CGI;
use Try::Tiny;
use Storable qw(dclone);
use Compress::Zlib  ();
use Foswiki::Config ();
use Foswiki::Engine ();

use Moo;
use namespace::clean;
extends qw(Foswiki::Object);

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
            eval "require " . $cfg->data->{Cache}{Implementation};
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
    default => \&_readConfig,
    isa => Foswiki::Object::isaCLASS( 'cfg', 'Foswiki::Config', noUndef => 1, ),
);
has env => (
    is       => 'rw',
    required => 1,
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
    is      => 'rw',
    lazy    => 1,
    default => \&_prepareEngine,
    isa =>
      Foswiki::Object::isaCLASS( 'engine', 'Foswiki::Engine', noUndef => 1, ),
);
has i18n => (
    is        => 'ro',
    lazy      => 1,
    clearer   => 1,
    predicate => 1,
    default   => sub {
        load_package('Foswiki::I18N');

        # language information; must be loaded after
        # *all possible preferences sources* are available
        $_[0]->create('Foswiki::I18N');
    },
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
    default   => sub { return $_[0]->create('Foswiki::Prefs'); },
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
    default => sub { $_[0]->create('Foswiki::Response') },
    isa     => Foswiki::Object::isaCLASS(
        'response', 'Foswiki::Response', noUndef => 1,
    ),
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
    default => sub {
        return {};
    },
);
has ui => (
    is      => 'rw',
    lazy    => 1,
    default => sub {
        return $_[0]->create('Foswiki::UI');
    },
);
has remoteUser => (
    is      => 'rw',
    clearer => 1,
);
has user => (
    is      => 'rw',
    clearer => 1,
);
has users => (
    is        => 'rw',
    lazy      => 1,
    predicate => 1,
    clearer   => 1,
    default   => sub { return $_[0]->create('Foswiki::Users'); },
);
has _dispatcherObject => (
    is  => 'rw',
    isa => Foswiki::Object::isaCLASS(
        '_dispatcherObject', 'Foswiki::AppObject', noUndef => 1
    ),
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

    # Enforce some shell environment variables.
    # SMELL Would it be tolerated in PSGI?
    $CGI::TMPDIRECTORY = $ENV{TMPDIR} = $ENV{TEMP} = $ENV{TMP} =
      $cfg->data->{TempfileDir};

    # Make %ENV safer, preventing hijack of the search path. The
    # environment is set per-query, so this can't be done in a BEGIN.
    # This MUST be done before any external programs are run via Sandbox.
    # or it will fail with taint errors.  See Item13237
    if ( defined $cfg->data->{SafeEnvPath} ) {
        $ENV{PATH} = $cfg->data->{SafeEnvPath};
    }
    else {
        # Default $ENV{PATH} must be untainted because
        # Foswiki may be run with the -T flag.
        # SMELL: how can we validate the PATH?
        $this->systemMessage(
"Unsafe shell variable PATH is used, consider setting SafeEnvPath configuration parameter."
        );
        $ENV{PATH} = Foswiki::Sandbox::untaintUnchecked( $ENV{PATH} );
    }
    delete @ENV{qw( IFS CDPATH ENV BASH_ENV )};

# TODO It's not clear yet as how to deal with logger configuration - see Foswiki::BUILDARGS().

    unless ( defined $this->engine ) {
        Foswiki::Exception::Fatal->throw( text => "Cannot initialize engine" );
    }

    unless ( $this->cfg->data->{isVALID} ) {
        $this->cfg->bootstrap;
    }

    # Override user to be admin if no configuration exists.
    # Do this really early, so that later changes in isBOOTSTRAPPING can't
    # change Foswiki's behavior.
    $this->user('admin') if ( $cfg->data->{isBOOTSTRAPPING} );

    $this->_prepareDispatcher;
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

    # Before localizing shell environment we need to preserve and restore it.
    local %ENV = %ENV;

    my $app;

    # We use shell environment by default. PSGI would supply its own env
    # hashref. Because PSGI env is not the same as shell env we would need to
    # avoid any side effects related to situations when changes to the env
    # hashref are gettin' translated back onto the shell env.
    $params{env} //= dclone( \%ENV );

    # Use current working dir for fetching the initial setlib.cfg
    $params{env}{PWD} //= getcwd;

    try {
        local $SIG{__DIE__} = sub {
            Foswiki::Exception::Fatal->rethrow( $_[0] );
        };
        local $SIG{__WARN__} =
          sub { Foswiki::Exception::Fatal->rethrow( $_[0] ); }
          if DEBUG;

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

            # Send error output to user using the initialized engine.
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
    my $res = $this->response;

    try {
        $this->_checkBootstrapStage2;
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

        # Load (or create) the CGI session This initialization is better be kept
        # here because $this->user may change later.
        $this->remoteUser( $this->users->loadSession( $this->user ) );

        # Push global preferences from %SYSTEMWEB%.DefaultPreferences
        $this->prefs->loadDefaultPreferences();

        my $method = $this->_dispatcherAttrs->{method};
        $this->_prepareContext;
        $this->_dispatcherObject->$method;
    }
    catch {
        my $e = $_;
        Foswiki::Exception::Fatal->rethrow($e);
    }
    finally {
        # Whatever happens at this stage we shall be able to reply with a valid
        # HTTP response using valid HTML.
        # XXX vrurg Sample code from pre-OO implementation.
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

    Foswiki::load_class($class);

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

    Foswiki::Func::writeDebug("found $web.$topic for $action in cache")
      if Foswiki::PageCache::TRACE();
    if ( int( $this->response->status || 200 ) >= 500 ) {
        Foswiki::Func::writeDebug(
            "Cache retrieval skipped due to non-200 status code "
              . $this->response->status )
          if DEBUG;
        return 0;
    }
    Monitor::MARK("found page in cache");

    my $hdrs = { 'Content-Type' => $cachedPage->{contenttype} };

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

            # Mark the response so we know it was satisfied from the cache
            $hdrs->{'X-Foswiki-PageCache'} = 1;
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

---++ ObjectMethod getPubURL($web, $topic, $attachment, %options) -> $url

Composes a pub url.
   * =$web= - name of the web for the URL, defaults to $session->{webName}
   * =$topic= - name of the topic, defaults to $session->{topicName}
   * =$attachment= - name of the attachment, defaults to no attachment
Supported %options are:
   * =topic_version= - version of topic to retrieve attachment from
   * =attachment_version= - version of attachment to retrieve
   * =absolute= - requests an absolute URL (rather than a relative path)

If =$web= is not given, =$topic= and =$attachment= are ignored.
If =$topic= is not given, =$attachment= is ignored.

If =topic_version= is not given, the most recent revision of the topic
will be linked. Similarly if attachment_version= is not given, the most recent
revision of the attachment will be assumed. If =topic_version= is specified
but =attachment_version= is not (or the specified =attachment_version= is not
present), then the most recent version of the attachment in that topic version
will be linked.

If Foswiki is running in an absolute URL context (e.g. the skin requires
absolute URLs, such as print or rss, or Foswiki is running from the
command-line) then =absolute= will automatically be set.

Note: for compatibility with older plugins, which use %PUBURL*% with
a constructed URL path, do not use =*= unless =web=, =topic=, and
=attachment= are all specified.

As required by RFC3986, the returned URL will only contain the
allowed characters -A-Za-z0-9_.~!*\'();:@&=+$,/?%#[]

=cut

sub getPubURL {
    my ( $this, $web, $topic, $attachment, %options ) = @_;

    $options{absolute} ||=
      ( $this->inContext('command_line') || $this->inContext('absolute_urls') );

    return $this->store->getAttachmentURL( $this, $web, $topic, $attachment,
        %options );
}

=begin TML

---++ ObjectMethod systemMessage( $message )

Adds a new system message to be displayed to a user (who most likely would be an
admin) either as a banner on the top of a wiki topic or by a special macro.

This method is to be used with care when really necessary.

=cut

sub systemMessage {
    my $this = shift;
    my ($message) = @_;
    push @{ $this->system_messages }, $message;
}

sub _prepareContext {
    my $this = shift;
    $this->context->{SUPPORTS_PARA_INDENT}   = 1;
    $this->context->{SUPPORTS_PREF_SET_URLS} = 1;
    if ( $this->cfg->data->{Password} ) {
        $this->context->{admin_available} = 1;
    }
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
    my $this = shift;

    # The following is preferable form of Request creation. The request
    # constructor will then initialize itself using $app->engine as the source
    # of information about the environment we're running under.

    my $request = Foswiki::Request::prepare( app => $this );
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
    my $res  = $this->response;

    # Duplicate the entry to avoid changing the original.
    my $dispatcher =
      $this->cfg->data->{SwitchBoard}{ $this->engine->pathData->{action} };
    unless ( defined $dispatcher ) {
        Foswiki::Exception::HTTPError->throw(
            status => 404,
            header => 'Not Found',
            text   => 'The requested URL '
              . ( $this->engine->pathData->{uri} // '' )
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
    $this->_dispatcherObject( $this->create( $dispatcher->{package} ) );
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
          $cfg->bootstrapWebSettins( $this->request->action );
        $this->systemMessage(
            $this->engine->HTTPCompliant
            ? ( '<div class="foswikiHelp"> ' . $phase2_message . '</div>' )
            : $phase2_message
        );
    }
}

sub _checkActionAccess {
    my $this            = shift;
    my $req             = $this->request;
    my $dispatcherAttrs = $this->_dispatcherAttrs;

    if ( UNIVERSAL::isa( $Foswiki::engine, 'Foswiki::Engine::CLI' ) ) {
        $dispatcherAttrs->{context}{command_line} = 1;
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
