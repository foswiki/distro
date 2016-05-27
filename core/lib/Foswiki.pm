
package Foswiki;
use v5.14;    # First version to accept v-numbers.

=begin TML

---+ package Foswiki

Foswiki operates by creating a singleton object (known as the Session
object) that acts as a point of reference for all the different
modules in the system. This package is the class for this singleton,
and also contains the vast bulk of the basic constants and the per-
site configuration mechanisms.

Global variables are avoided wherever possible to avoid problems
with CGI accelerators such as mod_perl.

---++ Public Data members
   * =request=          Pointer to the Foswiki::Request
   * =response=         Pointer to the Foswiki::Response
   * =context=          Hash of context ids
   * =plugins=          Foswiki::Plugins singleton
   * =prefs=            Foswiki::Prefs singleton
   * =remoteUser=       Login ID when using ApacheLogin. Maintained for
                        compatibility only, do not use.
   * =requestedWebName= Name of web found in URL path or =web= URL parameter
   * =scriptUrlPath=    URL path to the current script. May be dynamically
                        extracted from the URL path if {GetScriptUrlFromCgi}.
                        Only required to support {GetScriptUrlFromCgi} and
                        not consistently used. Avoid.
   * =access=         Foswiki::Access singleton
   * =store=            Foswiki::Store singleton
   * =topicName=        Name of topic found in URL path or =topic= URL
                        parameter
   * =urlHost=          Host part of the URL (including the protocol)
                        determined during intialisation and defaulting to
                        {DefaultUrlHost}
   * =user=             Unique user ID of logged-in user
   * =users=            Foswiki::Users singleton
   * =webName=          Name of web found in URL path, or =web= URL parameter,
                        or {UsersWebName}

=cut

use Cwd qw( abs_path );
use Module::Load;
use File::Spec               ();
use Monitor                  ();
use CGI                      ();  # Always required to get html generation tags;
use Digest::MD5              ();  # For passthru and validation
use Foswiki::Configure::Load ();
use Scalar::Util             ();
use Foswiki::Exception;

#use Foswiki::Store::PlainFile ();

# Item13331 - use CGI::ENCODE_ENTITIES introduced in CGI>=4.14 to restrict encoding
# in CGI's html rendering code to only these; note that CGI's default values
# still breaks some unicode byte strings
$CGI::ENCODE_ENTITIES = q{&<>"'};

# Site configuration constants
our %cfg;

# Other computed constants
our $foswikiLibDir;
our %regex;
our $VERSION;
our $RELEASE;
our $UNICODE = 1;  # flag that extensions can use to test if the core is unicode
our $TRUE    = 1;
our $FALSE   = 0;
our $engine;
our $TranslationToken = "\0";    # Do not deprecate - used in many plugins
our $system_message;             # Important broadcast message from the system
my $bootstrap_message = '';      # Bootstrap message.

# Note: the following marker is used in text to mark RENDERZONE
# macros that have been hoisted from the source text of a page. It is
# carefully chosen so that it is (1) not normally present in written
# text (2) does not combine with other characters to form valid
# wide-byte characters and (3) does not conflict with other markers used
# by Foswiki/Render.pm
our $RENDERZONE_MARKER = "\3";

# Used by takeOut/putBack blocks
our $BLOCKID = 0;
our $OC      = "<!--\0";
our $CC      = "\0-->";

# This variable is set if Foswiki is running in unit test mode.
# It is provided so that modules can detect unit test mode to avoid
# corrupting data spaces.
our $inUnitTestMode = 0;

use Try::Tiny;

#use Moo;
#use namespace::clean;
#extends qw( Foswiki::Object );

use Assert;
use Exporter qw(import);
our @EXPORT_OK =
  qw(%regex urlEncode urlDecode make_params load_package load_class expandStandardEscapes);

sub SINGLE_SINGLETONS       { 0 }
sub SINGLE_SINGLETONS_TRACE { 0 }

#has digester => (
#    is      => 'ro',
#    lazy    => 1,
#    clearer => 1,
#    default => sub { return Digest::MD5->new; },
#);
#
## Heap is to be used for data persistent over session lifetime.
## Usage: $sessiom->heap->{key} = <your data>;
#has heap => (
#    is      => 'rw',
#    clearer => 1,
#    lazy    => 1,
#    default => sub { {} },
#);
#has remoteUser => (
#    is      => 'rw',
#    clearer => 1,
#);
#has requestedWebName => ( is => 'rw', clearer => 1, );
#has response => (
#    is      => 'rw',
#    lazy    => 1,
#    clearer => 1,
#    default => sub { return Foswiki::Response->new; },
#);
#has sandbox => (
#    is      => 'ro',
#    default => 'Foswiki::Sandbox',
#    clearer => 1,
#);
#has scriptUrlPath => (
#    is      => 'ro',
#    lazy    => 1,
#    clearer => 1,
#    default => sub {
#        my $this          = shift;
#        my $scriptUrlPath = $Foswiki::cfg{ScriptUrlPath};
#        my $url           = $this->request->url;
#        if (   $Foswiki::cfg{GetScriptUrlFromCgi}
#            && $url
#            && $url =~ m{^[^:]*://[^/]*(.*)/.*$}
#            && $1 )
#        {
#
#            # SMELL: this is a really dangerous hack. It will fail
#            # spectacularly with mod_perl.
#            # SMELL: why not just use $query->script_name?
#            # SMELL: unchecked implicit untaint?
#            $scriptUrlPath = $1;
#        }
#        return $scriptUrlPath;
#    },
#);
#has topicName => (
#    is      => 'rw',
#    clearer => 1,
#);
#
#has webName => (
#    is      => 'rw',
#    clearer => 1,
#);

our @_newParameters = qw( user request context );

# Returns the full path of the directory containing Foswiki.pm
sub _getLibDir {
    return $foswikiLibDir if $foswikiLibDir;

    $foswikiLibDir = $INC{'Foswiki.pm'};

    # fix path relative to location of called script
    if ( $foswikiLibDir =~ m/^\./ ) {
        print STDERR
"WARNING: Foswiki lib path $foswikiLibDir is relative; you should make it absolute, otherwise some scripts may not run from the command line.";
        my $bin;

        # SMELL : Should not assume environment variables; get data from request
        if (   $ENV{SCRIPT_FILENAME}
            && $ENV{SCRIPT_FILENAME} =~ m#^(.+)/.+?$# )
        {

            # CGI script name
            # implicit untaint OK, because of use of $SCRIPT_FILENAME
            $bin = $1;
        }
        elsif ( $0 =~ m#^(.*)/.*?$# ) {

            # program name
            # implicit untaint OK, because of use of $PROGRAM_NAME ($0)
            $bin = $1;
        }
        else {

            # last ditch; relative to current directory.
            require Cwd;
            $bin = Cwd::cwd();
        }
        $foswikiLibDir = "$bin/$foswikiLibDir/";

        # normalize "/../" and "/./"
        while ( $foswikiLibDir =~ s|([\\/])[^\\/]+[\\/]\.\.[\\/]|$1| ) {
        }
        $foswikiLibDir =~ s|([\\/])\.[\\/]|$1|g;
    }
    $foswikiLibDir =~ s|([\\/])[\\/]*|$1|g;    # reduce "//" to "/"
    $foswikiLibDir =~ s|[\\/]$||;              # cut trailing "/"

    return $foswikiLibDir;
}

# Character encoding/decoding stubs. Done so we can ovveride
# if necessary (e.g. on OSX we may want to monkey-patch in a
# NFC/NFD module)
#
# Note, NFC normalization is being done only for network and directory
# read operations,  but NOT for topic data. Adding normalization here
# caused performance issues because some versions of Unicode::Normalize
# have removed the XS versions.  We really only need to normalize directory
# names not file contents.

=begin TML

---++ StaticMethod decode_utf8($octets) -> $unicode

Decode a binary string of octets known to be encoded using UTF-8 into
perl characters (unicode).

=cut

*decode_utf8 = \&Encode::decode_utf8;

=begin TML

---++ StaticMethod encode_utf8($unicode) -> $octets

Encode a perl character string into a binary string of octets
encoded using UTF-8.

=cut

*encode_utf8 = \&Encode::encode_utf8;

BEGIN {

    # First thing we do; make sure we print unicode errors
    binmode( STDERR, ":utf8" );

    #Monitor::MARK("Start of BEGIN block in Foswiki.pm");
    if (DEBUG) {
        if ( not $Assert::soft ) {

            # If ASSERTs are on (and not soft), then warnings are errors.
            # Paranoid, but the only way to be sure we eliminate them all.
            # ASSERTS are turned on by defining the environment variable
            # FOSWIKI_ASSERTS. If ASSERTs are off, this is assumed to be a
            # production environment, and no stack traces or paths are
            # output to the browser.
            #$SIG{'__WARN__'} = sub { die @_ };
            $Error::Debug = 1;    # verbose stack traces, please
        }
        else {

            # ASSERTs are soft, so warnings are not errors
            # but ASSERTs are enabled. This is useful for tracking down
            # problems that only manifest on production servers.
            $Error::Debug = 0;    # no verbose stack traces
        }
    }
    else {
        $Error::Debug = 0;        # no verbose stack traces
    }

    # DO NOT CHANGE THE FORMAT OF $VERSION.
    # Use $RELEASE for a descriptive version.
    use version 0.77; $VERSION = version->declare('v2.99.0');
    $RELEASE = 'Foswiki-2.99.0';

    #if ( $Foswiki::cfg{UseLocale} ) {
    #    require locale;
    #    import locale();
    #}

    # Set environment var FOSWIKI_NOTAINT to disable taint checks even
    # if Taint::Runtime is installed
    if ( DEBUG && !$ENV{FOSWIKI_NOTAINT} ) {
        eval { require Taint::Runtime; };
        if ($@) {
            print STDERR
"DEVELOPER WARNING: taint mode could not be enabled. Is Taint::Runtime installed?\n";
        }
        else {
            # Enable taint checking
            Taint::Runtime::_taint_start();
        }
    }

    # locale setup
    #
    #
    # Note that 'use locale' must be done in BEGIN block for regexes and
    # sorting to work properly, although regexes can still work without
    # this in 'non-locale regexes' mode.

   # XXX TODO Reimplement using unicode routines.
   #if ( $Foswiki::cfg{UseLocale} ) {
   #
   #    # Set environment variables for grep
   #    $ENV{LC_CTYPE} = $Foswiki::cfg{Site}{Locale};
   #
   #    # Load POSIX for I18N support.
   #    require POSIX;
   #    import POSIX qw( locale_h LC_CTYPE LC_COLLATE );
   #
   #   # SMELL: mod_perl compatibility note: If Foswiki is running under Apache,
   #   # won't this play with the Apache process's locale settings too?
   #   # What effects would this have?
   #    setlocale( &LC_CTYPE,   $Foswiki::cfg{Site}{Locale} );
   #    setlocale( &LC_COLLATE, $Foswiki::cfg{Site}{Locale} );
   #}

    # initialize lib directory early because of later 'cd's
    _getLibDir();

    # initialize the runtime engine
    #if ( !defined $Foswiki::cfg{Engine} ) {
    #
    #    # Caller did not define an engine; try and work it out (mainly for
    #    # the benefit of pre-1.0 CGI scripts)
    #    $Foswiki::cfg{Engine} = 'Foswiki::Engine::Legacy';
    #}
    #$engine = eval qq(use $Foswiki::cfg{Engine}; $Foswiki::cfg{Engine}->new);
    #die $@ if $@;

    #Monitor::MARK('End of BEGIN block in Foswiki.pm');
}

# Components that all requests need
use Foswiki::Response ();
use Foswiki::Request  ();
use Foswiki::Logger   ();
use Foswiki::Meta     ();
use Foswiki::Sandbox  ();
use Foswiki::Time     ();
use Foswiki::Prefs    ();
use Foswiki::Plugins  ();
use Foswiki::Users    ();

=begin TML

---++ ClassMethod new( $defaultUser, $query, \%initialContext )

Constructs a new Foswiki session object. A unique session object exists for
every transaction with Foswiki, for example every browser request, or every
script run. Session objects do not persist between mod_perl runs.

   * =$defaultUser= is the username (*not* the wikiname) of the default
     user you want to be logged-in, if none is available from a session
     or browser. Used mainly for unit tests and debugging, it is typically
     undef, in which case the default user is taken from
     $Foswiki::cfg{DefaultUserName}.
   * =$query= the Foswiki::Request query (may be undef, in which case an
     empty query is used)
   * =\%initialContext= - reference to a hash containing context
     name=value pairs to be pre-installed in the context hash. May be undef.

=cut

sub __deprecated_BUILDARGS {
    my $orig = shift;

    my $params = $orig->(@_);

    Monitor::MARK("Static init over; make Foswiki object");
    ASSERT( !$params->{request}
          || UNIVERSAL::isa( $params->{request}, 'Foswiki::Request' ) )
      if DEBUG;

    # Override user to be admin if no configuration exists.
    # Do this really early, so that later changes in isBOOTSTRAPPING can't
    # change Foswiki's behavior.
    $params->{user} = 'admin' if ( $Foswiki::cfg{isBOOTSTRAPPING} );

    unless ( $Foswiki::cfg{TempfileDir} ) {

        # Give it a sane default.
        if ( $^O eq 'MSWin32' ) {

            # Windows default tmpdir is the C: root  use something sane.
            # Configure does a better job,  it should be run.
            $Foswiki::cfg{TempfileDir} = $Foswiki::cfg{WorkingDir};
        }
        else {
            $Foswiki::cfg{TempfileDir} = File::Spec->tmpdir();
        }
    }

    # Cover all the possibilities
    $ENV{TMPDIR} = $Foswiki::cfg{TempfileDir};
    $ENV{TEMP}   = $Foswiki::cfg{TempfileDir};
    $ENV{TMP}    = $Foswiki::cfg{TempfileDir};

    # Make sure CGI is also using the appropriate tempfile location
    $CGI::TMPDIRECTORY = $Foswiki::cfg{TempfileDir};

    # Make %ENV safer, preventing hijack of the search path. The
    # environment is set per-query, so this can't be done in a BEGIN.
    # This MUST be done before any external programs are run via Sandbox.
    # or it will fail with taint errors.  See Item13237
    if ( defined $Foswiki::cfg{SafeEnvPath} ) {
        $ENV{PATH} = $Foswiki::cfg{SafeEnvPath};
    }
    else {
        # Default $ENV{PATH} must be untainted because
        # Foswiki may be run with the -T flag.
        # SMELL: how can we validate the PATH?
        $ENV{PATH} = Foswiki::Sandbox::untaintUnchecked( $ENV{PATH} );
    }
    delete @ENV{qw( IFS CDPATH ENV BASH_ENV )};

    if (   $Foswiki::cfg{WarningFileName}
        && $Foswiki::cfg{Log}{Implementation} eq 'Foswiki::Logger::PlainFile' )
    {

        # Admin has already expressed a preference for where they want their
        # logfiles to go, and has obviously not re-run configure yet.
        $Foswiki::cfg{Log}{Implementation} = 'Foswiki::Logger::Compatibility';

#print STDERR "WARNING: Foswiki is using the compatibility logger. Please re-run configure and check your logfiles settings\n";
    }

    # Make sure LogFielname is defined for use in old plugins,
    # but don't overwrite the setting from configure, if there is one.
    # This is especially important when the admin has *chosen*
    # to use the compatibility logger. (Some old TWiki heritage
    # plugins write directly to the configured LogFileName
    if ( not $Foswiki::cfg{LogFileName} ) {
        if ( $Foswiki::cfg{Log}{Implementation} eq
            'Foswiki::Logger::Compatibility' )
        {
            my $stamp =
              Foswiki::Time::formatTime( time(), '$year$mo', 'servertime' );
            my $defaultLogDir = "$Foswiki::cfg{DataDir}";
            $Foswiki::cfg{LogFileName} = $defaultLogDir . "/log$stamp.txt";

#print STDERR "Overrode LogFileName to $Foswiki::cfg{LogFileName} for CompatibilityLogger\n"
        }
        else {
            $Foswiki::cfg{LogFileName} = "$Foswiki::cfg{Log}{Dir}/events.log";

#print STDERR "Overrode LogFileName to $Foswiki::cfg{LogFileName} for PlainFileLogger\n"
        }
    }

    return $params;
}

sub __deprecated_BUILD {
    my $this = shift;

    if (SINGLE_SINGLETONS_TRACE) {
        require Data::Dumper;
        print STDERR "new $this: "
          . Data::Dumper->Dump( [ [caller], [ caller(1) ] ] );
    }

    # This is required in case we get an exception during
    # initialisation, so that we have a session to handle it with.
    #ASSERT( !$Foswiki::Plugins::SESSION ) if SINGLE_SINGLETONS;

    #$Foswiki::Plugins::SESSION = $this;

    ASSERT( $Foswiki::Plugins::SESSION,
"\$Foswiki::Plugins::SESSION was most likely unexpectedly cleared by destructor."
    );
    ASSERT( $Foswiki::Plugins::SESSION->isa('Foswiki') ) if DEBUG;

    my $query = $this->request;

    # Phase 2 of Bootstrap.  Web settings require that the Foswiki request
    # has been parsed.
    if ( $Foswiki::cfg{isBOOTSTRAPPING} ) {
        my $phase2_message =
          Foswiki::Configure::Load::bootstrapWebSettings( $query->action() );
        unless ($system_message) {    # Don't do this more than once.
            $system_message =
              ( $Foswiki::cfg{Engine} && $Foswiki::cfg{Engine} !~ /CLI/i )
              ? ( '<div class="foswikiHelp"> '
                  . $bootstrap_message
                  . $phase2_message
                  . '</div>' )
              : $bootstrap_message . $phase2_message;
        }
    }

    # construct the store object
    my $base = $Foswiki::cfg{Store}{Implementation}
      || 'Foswiki::Store::PlainFile';

    load_package($base);

    # vurg Do not use this hack. ImplementationClasses are not crucial and
    # should be replaced by new plugin model.
    #foreach my $class ( @{ $Foswiki::cfg{Store}{ImplementationClasses} } ) {
    #
    #    # this allows us to add an arbitary set of mixins for things
    #    # like recordChanges
    #
    #    # Rejig the store impl's ISA to use each Class  in order.'
    #    # IMPORTANT NOTE: despite of any other class code ImplemetationClasses
    #    # are required to have 'use Moo;' line _after_ 'use namespace::clean;'.
    #    # Otherwise the extends method will be anavailable outside of the
    #    # class/module code.
    #    load_package($class);
    #    no strict 'refs';
    #    ASSERT( $class->can('extends'),
    #        "Cannot use $class as store implemetation class" )
    #      if DEBUG;
    #    *{ $class . '::extends' }{CODE}->($base);
    #    use strict 'refs';
    #    $base = $class;
    #}

    $this->_baseStoreClass($base);

    # Load (or create) the CGI session
    # This initialization is better be kept here because $this->user may change
    # later.
    $this->remoteUser( $this->users->loadSession( $this->user ) );

    # The web/topic can be provided by either the query path_info,
    # or by URL Parameters:
    # topic:       Specifies web.topic or topic.
    #              Overrides the path given in the URL
    # defaultweb:  Overrides the default web, for use when topic=
    #              does not provide a web.
    # path_info    Defaults to the Users web Home topic

    # Set the default for web
    # Development.AddWebParamToAllCgiScripts: enables
    # bin/script?topic=WebPreferences;defaultweb=Sandbox
    my $defaultweb = $query->param('defaultweb') || $Foswiki::cfg{UsersWebName};

    my $webtopic      = urlDecode( $query->pathInfo || '' );
    my $topicOverride = '';
    my $topic         = $query->param('topic');
    if ( defined $topic ) {
        if ( $topic =~ m/[\/.]+/ ) {
            $webtopic = $topic;

           #print STDERR "candidate webtopic set to $webtopic by query param\n";
        }
        else {
            $topicOverride = $topic;

            #print STDERR
            #  "candidate topic set to $topicOverride by query param\n";
        }
    }

    # SMELL Scripts like rest, jsonrpc,  don't use web/topic path.
    # So this ends up all bogus, but doesn't do any harm.

    ( my $web, $topic ) =
      $this->_parsePath( $webtopic, $defaultweb, $topicOverride );

    $this->topicName($topic);
    $this->webName($web);

    # Push global preferences from %SYSTEMWEB%.DefaultPreferences
    $this->prefs->loadDefaultPreferences();

   # SMELL: what happens if we move this into the Foswiki::Users::new?
   # Note:  The initializeUserHandler() can override settings like
   #        topicName and webName. For example, HomePagePlugin.
   # This code cannot be moved into default for user attribute because it
   # relies on remoteUser which relies on been set within constructor –– see
   # above.
    $this->user( $this->users->initialiseUser( $this->remoteUser ) );

    # Static session variables that can be expanded in topics when they
    # are enclosed in % signs
    # SMELL: should collapse these into one. The duplication is pretty
    # pointless.
    $this->prefs->setInternalPreferences(
        BASEWEB        => $this->webName,
        BASETOPIC      => $this->topicName,
        INCLUDINGTOPIC => $this->topicName,
        INCLUDINGWEB   => $this->webName
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

    $this->prefs->pushTopicContext( $this->webName, $this->topicName );

    # Set both isadmin and authenticated contexts.   If the current user
    # is admin, then they either authenticated, or we are in bootstrap.
    if ( $this->users->isAdmin( $this->user ) ) {
        $this->context->{authenticated} = 1;
        $this->context->{isadmin}       = 1;
    }

    # Finish plugin initialization - register handlers
    $this->plugins->enable();
}

# Tests if the $redirect is an external URL, returning false if
# AllowRedirectUrl is denied
sub _isRedirectSafe {
    my $redirect = shift;

    return 1 if ( $Foswiki::cfg{AllowRedirectUrl} );

    # relative URL - OK
    return 1 if $redirect =~ m#^/#;

    #TODO: this should really use URI
    # Compare protocol, host name and port number
    if ( $redirect =~ m!^(.*?://[^/?#]*)! ) {

        # implicit untaints OK because result not used. uc retaints
        # if use locale anyway.
        my $target = uc($1);

        $Foswiki::cfg{DefaultUrlHost} =~ m!^(.*?://[^/]*)!;
        return 1 if ( $target eq uc($1) );

        if ( $Foswiki::cfg{PermittedRedirectHostUrls} ) {
            foreach my $red (
                split( /\s*,\s*/, $Foswiki::cfg{PermittedRedirectHostUrls} ) )
            {
                $red =~ m!^(.*?://[^/]*)!;
                return 1 if ( $target eq uc($1) );
            }
        }
    }
    return 0;
}

=begin TML

---++ StaticMethod splitAnchorFromUrl( $url ) -> ( $url, $anchor )

Takes a full url (including possible query string) and splits off the anchor.
The anchor includes the # sign. Returns an empty string if not found in the url.

=cut

sub splitAnchorFromUrl {
    my ($url) = @_;

    ( $url, my $anchor ) = $url =~ m/^(.*?)(#(.*?))*$/;
    return ( $url, $anchor );
}

=begin TML

---++ ObjectMethod cacheQuery() -> $queryString

Caches the current query in the params cache, and returns a rewritten
query string for the cache to be picked up again on the other side of a
redirect.

We can't encode post params into a redirect, because they may exceed the
size of the GET request. So we cache the params, and reload them when the
redirect target is reached.

=cut

sub cacheQuery {
    my $this  = shift;
    my $query = $this->request;

    return '' unless ( $query->param() );

    # Don't double-cache
    return '' if ( $query->param('foswiki_redirect_cache') );

    require Foswiki::Request::Cache;
    my $uid = Foswiki::Request::Cache->new()->save($query);
    if ( $Foswiki::cfg{UsePathForRedirectCache} ) {
        return '/foswiki_redirect_cache/' . $uid;
    }
    else {
        return '?foswiki_redirect_cache=' . $uid;
    }
}

=begin TML

---++ ObjectMethod getCGISession() -> $cgisession

Get the CGI::Session object associated with this session, if there is
one. May return undef.

=cut

sub getCGISession {
    $_[0]->users->getCGISession();
}

=begin TML

---++ ObjectMethod getLoginManager() -> $loginManager

Get the Foswiki::LoginManager object associated with this session, if there is
one. May return undef.

=cut

sub getLoginManager {
    $_[0]->users->getLoginManager();
}

=begin TML

---++ StaticMethod isValidWikiWord( $name ) -> $boolean

Check for a valid WikiWord or WikiName

=cut

sub isValidWikiWord {
    my $name = shift || '';
    return ( $name =~ m/^$regex{wikiWordRegex}$/ );
}

=begin TML

---++ StaticMethod isValidTopicName( $name [, $nonww] ) -> $boolean

Check for a valid topic =$name=. If =$nonww=, then accept non wiki-words
(though they must still be composed of only valid, unfiltered characters)

=cut

# Note: must work on tainted names.
sub isValidTopicName {
    my ( $name, $nonww ) = @_;

    return 0 unless defined $name && $name ne '';

    # Make sure any name is supported by the Store encoding
    if (   $Foswiki::cfg{Store}{Encoding}
        && $Foswiki::cfg{Store}{Encoding} ne 'utf-8'
        && $name =~ m/[^[:ascii:]]+/ )
    {
        my $badName = 0;
        try {
            Foswiki::Store::encode( $name, 1 );
        }
        catch {
            $badName = 1;
        };
        return 0 if $badName;
    }

    return 1 if ( $name =~ m/^$regex{topicNameRegex}$/ );
    return 0 unless $nonww;
    return 0 if $name =~ m/$cfg{NameFilter}/;
    return 1;
}

=begin TML

---++ StaticMethod isValidWebName( $name, $system ) -> $boolean

STATIC Check for a valid web name. If $system is true, then
system web names are considered valid (names starting with _)
otherwise only user web names are valid

If $Foswiki::cfg{EnableHierarchicalWebs} is off, it will also return false
when a nested web name is passed to it.

=cut

# Note: must work on tainted names.
sub isValidWebName {
    my $name = shift || '';
    my $sys = shift;
    return 1 if ( $sys && $name =~ m/^$regex{defaultWebNameRegex}$/ );
    return ( $name =~ m/^$regex{webNameRegex}$/ );
}

=begin TML

---++ StaticMethod isValidEmailAddress( $name ) -> $boolean

STATIC Check for a valid email address name.

=cut

# Note: must work on tainted names.
sub isValidEmailAddress {
    my $name = shift || '';
    return $name =~ m/^$regex{emailAddrRegex}$/;
}

=begin TML

---++ StaticMethod make_params(...)
Generate a URL parameters string from parameters given. A parameter
named '#' will generate a fragment identifier.

=cut

sub make_params {
    my $url = '';
    my @ps;
    my $anchor = '';
    while ( my $p = shift @_ ) {
        if ( $p eq '#' ) {
            $anchor = '#' . urlEncode( shift(@_) );
        }
        else {
            my $v = shift(@_);
            $v = '' unless defined $v;
            push( @ps, urlEncode($p) . '=' . urlEncode($v) );
        }
    }
    if ( scalar(@ps) ) {
        @ps = sort(@ps) if (DEBUG);
        $url .= '?' . join( ';', @ps );
    }
    return $url . $anchor;
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

---++ StaticMethod load_package( $full_package_name [, %params ] )

Will cleanly load the package or fail. This is better than 'eval "require $package"'.

It is not perfect for Perl < 5.10. For Perl 5.8, if somewhere else 'eval "require $package"' 
was used *earlier* for a module that fails to load, then not only is the failure not detected
then. Neither will it be detected here.

The recommendation is to replace all dynamic require calls in Foswiki to be replaced with this call.

This functionality used to be done via module Class::Load, but that had painful dependencies.

See http://blog.fox.geek.nz/2010/11/searching-design-spec-for-ultimate.html for the gory details.

=cut

# _package_defined checks if package is present in the global symbol table.
sub _package_defined {
    my $fullname = shift;

    # See if package is already defined in the main symbol table.
    my ( $namePref, $nameSuff ) = ( $fullname =~ /^(.+::)?([^:]+)$/ );
    $namePref //= '::';
    no strict 'refs';
    my $pkgLoaded = defined $namePref->{"${nameSuff}::"};
    use strict 'refs';
    return $pkgLoaded;
}

# SMELL Wouldn't it be more reliable to use Module::Load? Or Class::Load? Though
# the latter requires additional CPAN module installed.
sub load_package {
    my $fullname = shift;
    my %params   = @_;

    my $defined = _package_defined($fullname);
    my $loaded  = $defined;
    if ( $defined && $params{method} ) {

        # Check if loaded package can do a method. If it can't we assume that
        # the entry in the symbol table was autovivified.
        $loaded = $fullname->can( $params{method} );
    }
    return if $loaded;

    my $filename = File::Spec->catfile( split /::/, $fullname ) . '.pm';
    #
    ## Check if the module has been already loaded before.
    #return if exists $INC{$filename};

    # Is it already loaded? If so, it might be an internal class an missing
    # from @INC, so skip it. See perldoc UNIVERSAL for what this does.
    # XXX vrurg This method is unreliable and sometimes detects a module which
    # hasn't been loaded yet. Besides it depends on module name being 1-to-1
    # mapped into file name which is not always the case. Consider macros which
    # are part of Foswiki namespace.
    #return if eval { $fullname->isa($fullname) };

    #say STDERR "Loading $fullname from $filename";

    local $SIG{__DIE__};
    require $filename;
}

sub load_class {
    load_package( @_, method => 'new', );
}

=begin TML

---++ Private _parsePath( $this, $webtopic, $defaultweb, $topicOverride )

Parses the Web/Topic path parameters to safely establish a valid web and topic,
or assign safe defaults.

   * $webtopic - A "web/topic" path.  It might have originated from the query path_info,
   or from the topic= URL parameter. (only when the topic param contained a web component)
   * $defaultweb - The default web to use if the web part of webtopic is missing or invalid.
   This can be from the default UsersWebName,  or from the url parameter defaultweb.
   * $topicOverride - A topic name to use instead of any topic provided in the pathinfo.

Note if $webtopic ends with a trailing slash, it provides a hint that the last component should be
considered web.  This allows disambiguation between a topic and subweb with the same name.
Trailing slash forces it to be recognized as a webname, otherwise the topic is shown.
Note. If the web doesn't exist, the force will be ignored.  It's not possible to create a missing web
by referencing it in a URL.

This routine sets two variables when encountering invalid input:
   * $this->invalidWeb  contains original invalid web / pathinfo content when validation fails.
   * $this->invalidTopic Same function but for topic name
When invalid / illegal characters are encountered, the session {webName} and {topicName} will be
defaulted to safe defaults.  Scripts using those fields should also test if the corresponding
invalid* versions are defined, and should throw an oops exception rathern than allowing execution
to proceed with defaulted values.

The topic name will always have the first character converted to upper case, to prevent creation of
or access to invalid topics.

=cut

sub _parsePath {
    my $this          = shift;
    my $webtopic      = shift;
    my $defaultweb    = shift;
    my $topicOverride = shift;

    #print STDERR "_parsePath called WT ($webtopic) DEF ($defaultweb)\n";

    my $trailingSlash = ( $webtopic =~ s/\/$// );

    #print STDERR "TRAILING = $trailingSlash\n";

    # Remove any leading slashes or dots.
    $webtopic =~ s/^[\/.]+//;

    my @parts = split /[\/.]+/, $webtopic;
    my $cur = 0;
    my @webs;         # Collect valid webs from path
    my @badpath;      # Collect all webs, including illegal
    my $temptopic;    # Candidate topicname extracted from path, defaults.

    foreach (@parts) {

        # Lax check on name to eliminate evil characters.
        my $p = Foswiki::Sandbox::untaint( $_,
            \&Foswiki::Sandbox::validateTopicName );
        unless ($p) {
            push @badpath, $_;
            next;
        }

        if ( \$_ == \$parts[-1] ) {    # This is the last part of path

            if ( $this->topicExists( join( '/', @webs ) || $defaultweb, $p )
                && !$trailingSlash )
            {

                #print STDERR "Exists and no trailing slash\n";

                # It exists in Store as a topic and there is no trailing slash
                $temptopic = $p || '';
            }
            elsif ( $this->webExists( join( '/', @webs, $p ) ) ) {

                #print STDERR "Web Exists " . join( '/', @webs, $p ) . "\n";

                # It exists in Store as a web
                push @badpath, $p;
                push @webs,    $p;
            }
            elsif ($trailingSlash) {

                #print STDERR "Web forced ...\n";
                if ( !$this->webExists( join( '/', @webs, $p ) )
                    && $this->topicExists( join( '/', @webs ) || $defaultweb,
                        $p ) )
                {

                    #print STDERR "Forced, but no such web, and topic exists";
                    $temptopic = $p;
                }
                else {

                    #print STDERR "Append it to the webs\n";
                    $p = Foswiki::Sandbox::untaint( $p,
                        \&Foswiki::Sandbox::validateWebName );

                    unless ($p) {
                        push @badpath, $_;
                        next;
                    }
                    else {
                        push @badpath, $p;
                        push @webs,    $p;
                    }
                }
            }
            else {
                #print STDERR "Just a topic. " . scalar @webs . "\n";
                $temptopic = $p;
            }
        }
        else {
            $p = Foswiki::Sandbox::untaint( $p,
                \&Foswiki::Sandbox::validateWebName );
            unless ($p) {
                push @badpath, $_;
                next;
            }
            else {
                push @badpath, $p;
                push @webs,    $p;
            }
        }
    }

    my $web    = join( '/', @webs );
    my $badweb = join( '/', @badpath );

    # Set the requestedWebName before applying defaults - used by statistics
    # generation.   Note:  This is validated using Topic name rules to permit
    # names beginning with lower case.
    $this->requestedWebName(
        Foswiki::Sandbox::untaint(
            $badweb, \&Foswiki::Sandbox::validateTopicName
        )
    );

    #say STDERR "Set requestedWebName to ", $this->requestedWebName
    #  if $this->requestedWebName;

    if ( length($web) != length($badweb) ) {

        #print STDERR "RESULTS:\nPATH: $web\nBAD:  $badweb\n";
        $this->invalidWeb($badweb);
    }

    unless ($web) {
        $web = Foswiki::Sandbox::untaint( $defaultweb,
            \&Foswiki::Sandbox::validateWebName );
        unless ($web) {
            $this->invalidWeb($defaultweb);
            $web = $Foswiki::cfg{UsersWebName};
        }
    }

    # Override topicname if urlparam $topic is provided.
    $temptopic = $topicOverride if ($topicOverride);

    # Provide a default topic if none specified
    $temptopic = $Foswiki::cfg{HomeTopicName} unless defined($temptopic);

    # Item3270 - here's the appropriate place to enforce spec
    # http://develop.twiki.org/~twiki4/cgi-bin/view/Bugs/Item3270
    my $topic =
      Foswiki::Sandbox::untaint( ucfirst($temptopic),
        \&Foswiki::Sandbox::validateTopicName );

    unless ($topic) {
        $this->invalidTopic($temptopic);
        $topic = $Foswiki::cfg{HomeTopicName};

        #print STDERR "RESULTS:\nTOPIC  $topic\nBAD:  $temptopic\n";
        $this->invalidTopic($temptopic);
    }

    #print STDERR "PARSE returns web $web topic $topic\n";

    return ( $web, $topic );
}

sub __depreacated_DEMOLISH {
    my $this = shift;

    $this->clear_plugins;
    $this->clear_forms;
    if ( $this == $Foswiki::Plugins::SESSION ) {

        #say STDERR $this, " Here we clear the old Plugins::SESSION";
        undef $Foswiki::Plugins::SESSION;
    }
}

=begin TML

---++ DEPRECATED  ObjectMethod logEvent( $action, $webTopic, $extra, $user )
   * =$action= - what happened, e.g. view, save, rename
   * =$webTopic= - what it happened to
   * =$extra= - extra info, such as minor flag
   * =$user= - login name of user - default current user,
     or failing that the user agent

Write the log for an event to the logfile

The method is deprecated,  Call logger->log directly.

=cut

sub logEvent {
    my $this = shift;

    my $action   = shift || '';
    my $webTopic = shift || '';
    my $extra    = shift || '';
    my $user     = shift;

    $this->logger->log(
        {
            level    => 'info',
            action   => $action || '',
            webTopic => $webTopic || '',
            extra    => $extra || '',
            user     => $user,
        }
    );
}

=begin TML

---++ StaticMethod validatePattern( $pattern ) -> $pattern

Validate a pattern provided in a parameter to $pattern so that
dangerous chars (interpolation and execution) are disabled.

=cut

sub validatePattern {
    my $pattern = shift;

    # Escape unescaped $ and @ characters that might interpolate
    # an internal variable.
    # There is no need to defuse (??{ and (?{ as perl won't allow
    # it anyway, unless one uses re 'eval' which we won't do
    $pattern =~ s/(^|[^\\])([\$\@])/$1\\$2/g;
    return $pattern;
}

=begin TML

---++ StaticMethod entityEncode( $text [, $extras] ) -> $encodedText

Escape special characters to HTML numeric entities. This is *not* a generic
encoding, it is tuned specifically for use in Foswiki.

HTML4.0 spec:
"Certain characters in HTML are reserved for use as markup and must be
escaped to appear literally. The "&lt;" character may be represented with
an <em>entity</em>, <strong class=html>&amp;lt;</strong>. Similarly, "&gt;"
is escaped as <strong class=html>&amp;gt;</strong>, and "&amp;" is escaped
as <strong class=html>&amp;amp;</strong>. If an attribute value contains a
double quotation mark and is delimited by double quotation marks, then the
quote should be escaped as <strong class=html>&amp;quot;</strong>.

Other entities exist for special characters that cannot easily be entered
with some keyboards..."

This method encodes:
   * all non-printable 7-bit chars (< \x1f), except \n (\xa) and \r (\xd)
   * HTML special characters '>', '<', '&', ''' (single quote) and '"' (double quote).
   * TML special characters '%', '|', '[', ']', '@', '_', '*', '$' and "="

$extras is an optional param that may be used to include *additional*
characters in the set of encoded characters. It should be a string
containing the additional chars.

This internal function is available for use by expanding the =%ENCODE= macro,
or the =%URLPARAM= macro, specifying =type="entities"= or =type="entity"=.

=cut

sub entityEncode {
    my ( $text, $extra ) = @_;
    $extra = '' unless defined $extra;

    # Safe on utf8 binary strings, as none of the characters has bit 7 set
    $text =~
s/([[\x01-\x09\x0b\x0c\x0e-\x1f"%&\$'*<=>@\]_\|$extra])/'&#'.ord($1).';'/ge;
    return $text;
}

#s/([[\x01-\x09\x0b\x0c\x0e-\x1f"%&\$'*<=>@[_\|$extra])/'&#'.ord($1).';'/ge;

=begin TML

---++ StaticMethod entityDecode ( $encodedText ) -> $text

Decodes all numeric entities (e.g. &amp;#123;). _Does not_ decode
named entities such as &amp;amp; (use HTML::Entities for that)

=cut

sub entityDecode {
    my $text = shift;

    $text =~ s/&#(\d+);/chr($1)/ge;
    return $text;
}

=begin TML

---++ StaticMethod expandStandardEscapes($str) -> $unescapedStr

Expands standard escapes used in parameter values to block evaluation. See
System.FormatTokens for a full list of supported tokens.

=cut

sub expandStandardEscapes {
    my $text = shift;

    # expand '$n()' and $n! to new line
    $text =~ s/\$n\(\)/\n/gs;
    $text =~ s/\$n(?=[^[:alpha:]]|$)/\n/gs;

    # filler, useful for nested search
    $text =~ s/\$nop(\(\))?//gs;

    # $quot -> "
    $text =~ s/\$quot(\(\))?/\"/gs;

    # $comma -> ,
    $text =~ s/\$comma(\(\))?/,/gs;

    # $percent -> %
    $text =~ s/\$perce?nt(\(\))?/\%/gs;

    # $lt -> <
    $text =~ s/\$lt(\(\))?/\</gs;

    # $gt -> >
    $text =~ s/\$gt(\(\))?/\>/gs;

    # $amp -> &
    $text =~ s/\$amp(\(\))?/\&/gs;

    # $dollar -> $, done last to avoid creating the above tokens
    $text =~ s/\$dollar(\(\))?/\$/gs;

    return $text;
}

=begin TML

---++ StaticMethod urlEncode( $perlstring ) -> $bytestring

Encode by converting characters that are reserved in URLs to
their %NN equivalents. This method is used for encoding
strings that must be embedded _verbatim_ in URLs; it cannot
be applied to URLs themselves, as it escapes reserved
characters such as =, &, %, ;, # and ?.

RFC 1738, Dec. '94:
    <verbatim>
    ...Only alphanumerics [0-9a-zA-Z], the special
    characters $-_.+!*'(), and reserved characters used for their
    reserved purposes may be used unencoded within a URL.
    </verbatim>

However this function is tuned for use with Foswiki. As such, it
encodes *all* characters except 0-9a-zA-Z-_.:~!*/

This internal function is available for use by expanding the =%ENCODE= macro,
specifying =type="url"=.  It is also the default encoding used by the =%URLPARAM= macro. 

=cut

sub urlEncode {
    my $text = shift;

    $text = encode_utf8($text);
    $text =~ s{([^0-9a-zA-Z-_.:~!*/])}{sprintf('%%%02x',ord($1))}ge;

    return $text;
}

=begin TML

---++ StaticMethod urlDecode( $bytestring ) -> $perlstring

Reverses the encoding done in urlEncode.

=cut

sub urlDecode {
    my $text = shift;

    $text =~ s/%([\da-fA-F]{2})/chr(hex($1))/ge;
    $text = decode_utf8($text);

    return $text;
}

=begin TML

---++ StaticMethod isTrue( $value, $default ) -> $boolean

Returns 1 if =$value= is true, and 0 otherwise. "true" means set to
something with a Perl true value, with the special cases that "off",
"false" and "no" (case insensitive) are forced to false. Leading and
trailing spaces in =$value= are ignored.

If the value is undef, then =$default= is returned. If =$default= is
not specified it is taken as 0.

=cut

sub isTrue {
    my ( $value, $default ) = @_;

    $default ||= 0;

    return $default unless defined($value);

    $value =~ s/^\s*(.*?)\s*$/$1/g;
    $value =~ s/off//gi;
    $value =~ s/no//gi;
    $value =~ s/false//gi;
    return ($value) ? 1 : 0;
}

=begin TML

---++ StaticMethod spaceOutWikiWord( $word, $sep ) -> $string

Spaces out a wiki word by inserting a string (default: one space) between each word component.
With parameter $sep any string may be used as separator between the word components; if $sep is undefined it defaults to a space.

=cut

sub spaceOutWikiWord {
    my ( $word, $sep ) = @_;

    # Both could have the value 0 so we cannot use simple = || ''
    $word = defined($word) ? $word : '';
    $sep  = defined($sep)  ? $sep  : ' ';
    my $mark = "\001";
    $word =~ s/([[:upper:]])([[:digit:]])/$1$mark$2/g;
    $word =~ s/([[:digit:]])([[:upper:]])/$1$mark$2/g;
    $word =~ s/([[:lower:]])([[:upper:][:digit:]]+)/$1$mark$2/g;
    $word =~ s/([[:upper:]])([[:upper:]])(?=[[:lower:]])/$1$mark$2/g;
    $word =~ s/$mark/$sep/g;
    return $word;
}

=begin TML

---++ StaticMethod takeOutBlocks( \$text, $tag, \%map ) -> $text
   * =$text= - Text to process
   * =$tag= - XML-style tag.
   * =\%map= - Reference to a hash to contain the removed blocks

Return value: $text with blocks removed

Searches through $text and extracts blocks delimited by an XML-style tag,
storing the extracted block, and replacing with a token string which is
not affected by TML rendering.  The text after these substitutions is
returned.

=cut

sub takeOutBlocks {
    my ( $intext, $tag, $map ) = @_;

    # Case insensitive regexes are very slow,  Change to character class match
    # link is transformed to [lL][iI][nN][kK]
    my $re = join( '', map { '[' . lc($_) . uc($_) . ']' } split( '', $tag ) );

    return $intext unless ( $intext =~ m/<$re\b/ );

    my $out   = '';
    my $depth = 0;
    my $scoop;
    my $tagParams;

    foreach my $token ( split( /(<\/?$re[^>]*>)/, $intext ) ) {
        if ( $token =~ m/<$re\b([^>]*)?>/ ) {
            $depth++;
            if ( $depth eq 1 ) {
                $tagParams = $1;
                next;
            }
        }
        elsif ( $token =~ m/<\/$re>/ ) {
            if ( $depth > 0 ) {
                $depth--;
                if ( $depth eq 0 ) {
                    my $placeholder = "$tag$BLOCKID";
                    $BLOCKID++;
                    $map->{$placeholder}{text}   = $scoop;
                    $map->{$placeholder}{params} = $tagParams;
                    $out .= "$OC$placeholder$CC";
                    $scoop = '';
                    next;
                }
            }
        }
        if ( $depth > 0 ) {
            $scoop .= $token;
        }
        else {
            $out .= $token;
        }
    }

    # unmatched tags
    if ( defined($scoop) && ( $scoop ne '' ) ) {
        my $placeholder = "$tag$BLOCKID";
        $BLOCKID++;
        $map->{$placeholder}{text}   = $scoop;
        $map->{$placeholder}{params} = $tagParams;
        $out .= "$OC$placeholder$CC";
    }

    return $out;
}

=begin TML

---++ StaticMethod putBackBlocks( \$text, \%map, $tag, $newtag, $callBack ) -> $text

Return value: $text with blocks added back
   * =\$text= - reference to text to process
   * =\%map= - map placeholders to blocks removed by takeOutBlocks
   * =$tag= - Tag name processed by takeOutBlocks
   * =$newtag= - Tag name to use in output, in place of $tag.
     If undefined, uses $tag.
   * =$callback= - Reference to function to call on each block
     being inserted (optional)

Reverses the actions of takeOutBlocks.

Each replaced block is processed by the callback (if there is one) before
re-insertion.

Parameters to the outermost cut block are replaced into the open tag,
even if that tag is changed. This allows things like =&lt;verbatim class=''>=
to be changed to =&lt;pre class=''>=

If you set $newtag to '', replaces the taken-out block with the contents
of the block, not including the open/close. This is used for &lt;literal>,
for example.

=cut

sub putBackBlocks {
    my ( $text, $map, $tag, $newtag, $callback ) = @_;

    $newtag = $tag if ( !defined($newtag) );

    my $otext = $$text;
    my $pos   = 0;
    my $ntext = '';

    while ( ( $pos = index( $otext, ${OC} . $tag, $pos ) ) >= 0 ) {

        # Grab the text ahead of the marker
        $ntext .= substr( $otext, 0, $pos );

        # Length of the marker prefix
        my $pfxlen = length( ${OC} . $tag );

        # Ending marker position
        my $epos = index( $otext, ${CC}, $pos );

        # Tag instance
        my $placeholder =
          $tag . substr( $otext, $pos + $pfxlen, $epos - $pos - $pfxlen );

  # Not all calls to putBack use a common map, so skip over any missing entries.
        unless ( exists $map->{$placeholder} ) {
            $ntext .= substr( $otext, $pos, $epos - $pos + 4 );
            $otext = substr( $otext, $epos + 4 );
            $pos = 0;
            next;
        }

        # Any params saved with the tag
        my $params = $map->{$placeholder}{params} || '';

        # Get replacement value
        my $val = $map->{$placeholder}{text};
        $val = &$callback($val) if ( defined($callback) );

        # Append the new data and remove leading text + marker from original
        if ( defined($val) ) {
            $ntext .=
              ( $newtag eq '' ) ? $val : "<$newtag$params>$val</$newtag>";
        }
        $otext = substr( $otext, $epos + 4 );

        # Reset position for next pass
        $pos = 0;

        delete( $map->{$placeholder} );
    }

    $ntext .= $otext;    # Append any remaining text.
    $$text = $ntext;     # Replace the entire text

}

=begin TML

---++ StaticMethod readFile( $filename ) -> $text

Returns the entire contents of the given file, which can be specified in any
format acceptable to the Perl open() function. Fast, but inherently unsafe.

WARNING: Never, ever use this for accessing topics or attachments! Use the
Store API for that. This is for global control files only, and should be
used *only* if there is *absolutely no alternative*.

=cut

sub readFile {
    my $name = shift;
    ASSERT(0) if DEBUG;
    my $IN_FILE;
    open( $IN_FILE, "<$name" ) || return '';
    local $/ = undef;
    my $data = <$IN_FILE>;
    close($IN_FILE);
    $data = '' unless ( defined($data) );
    return $data;
}

=begin TML

---++ ObjectMethod webExists( $web ) -> $boolean

Test if web exists
   * =$web= - Web name, required, e.g. ='Sandbox'=

A web _has_ to have a preferences topic to be a web.

=cut

sub webExists {
    my ( $this, $web ) = @_;

    ASSERT( UNTAINTED($web), 'web is tainted' ) if DEBUG;
    return $this->store->webExists($web);
}

=begin TML

---++ ObjectMethod topicExists( $web, $topic ) -> $boolean

Test if topic exists
   * =$web= - Web name, optional, e.g. ='Main'=
   * =$topic= - Topic name, required, e.g. ='TokyoOffice'=, or ="Main.TokyoOffice"=

=cut

sub topicExists {
    my ( $this, $web, $topic ) = @_;
    ASSERT( UNTAINTED($web),   'web is tainted' )   if DEBUG;
    ASSERT( UNTAINTED($topic), 'topic is tainted' ) if DEBUG;
    return $this->store->topicExists( $web, $topic );
}

=begin TML

---+++ ObjectMethod getWorkArea( $key ) -> $directorypath

Gets a private directory uniquely identified by $key. The directory is
intended as a work area for plugins etc. The directory will exist.

=cut

sub getWorkArea {
    my ( $this, $key ) = @_;
    return $this->store->getWorkArea($key);
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
