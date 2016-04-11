
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

use Moo;
use namespace::clean;
extends qw( Foswiki::Object );

use Assert;
use Exporter qw(import);
our @EXPORT_OK = qw(%regex);

sub SINGLE_SINGLETONS       { 0 }
sub SINGLE_SINGLETONS_TRACE { 0 }

has attach => (
    is        => 'ro',
    lazy      => 1,
    clearer   => 1,
    predicate => 1,
    default   => sub {
        require Foswiki::Attach;
        new Foswiki::Attach( session => $_[0] );
    },
);
has digester => (
    is      => 'ro',
    lazy    => 1,
    clearer => 1,
    default => sub { return Digest::MD5->new; },
);
has forms => (
    is      => 'ro',
    lazy    => 1,
    clearer => 1,
    default => sub { {} },
);

# Heap is to be used for data persistent over session lifetime.
# Usage: $sessiom->heap->{key} = <your data>;
has heap => (
    is      => 'rw',
    clearer => 1,
    lazy    => 1,
    default => sub { {} },
);
has net => (
    is        => 'ro',
    lazy      => 1,
    clearer   => 1,
    predicate => 1,
    default   => sub {
        load_package('Foswiki::Net');
        return Foswiki::Net->new( session => $_[0] );
    },
);
has remoteUser => (
    is      => 'rw',
    clearer => 1,
);
has renderer => (
    is        => 'ro',
    lazy      => 1,
    clearer   => 1,
    predicate => 1,
    default   => sub {
        load_package('Foswiki::Render');
        Foswiki::Render->new( session => $_[0] );
    },
);
has requestedWebName => ( is => 'rw', clearer => 1, );
has response => (
    is      => 'rw',
    lazy    => 1,
    clearer => 1,
    default => sub { return Foswiki::Response->new; },
);
has sandbox => (
    is      => 'ro',
    default => 'Foswiki::Sandbox',
    clearer => 1,
);
has scriptUrlPath => (
    is      => 'ro',
    lazy    => 1,
    clearer => 1,
    default => sub {
        my $this          = shift;
        my $scriptUrlPath = $Foswiki::cfg{ScriptUrlPath};
        my $url           = $this->request->url;
        if (   $Foswiki::cfg{GetScriptUrlFromCgi}
            && $url
            && $url =~ m{^[^:]*://[^/]*(.*)/.*$}
            && $1 )
        {

            # SMELL: this is a really dangerous hack. It will fail
            # spectacularly with mod_perl.
            # SMELL: why not just use $query->script_name?
            # SMELL: unchecked implicit untaint?
            $scriptUrlPath = $1;
        }
        return $scriptUrlPath;
    },
);
has search => (
    is        => 'ro',
    lazy      => 1,
    clearer   => 1,
    predicate => 1,
    default   => sub {
        require Foswiki::Search;
        return Foswiki::Search->new( session => $_[0] );
    },
);
has topicName => (
    is      => 'rw',
    clearer => 1,
);

# SMELL Shouldn't urlHost attribute be available from the request object?
has urlHost => (
    is      => 'rw',
    lazy    => 1,
    clearer => 1,
    default => sub {
        my $this = shift;

        #{urlHost}  is needed by loadSession..
        my $url = $this->request->url();
        my $urlHost;
        if (   $url
            && !$Foswiki::cfg{ForceDefaultUrlHost}
            && $url =~ m{^([^:]*://[^/]*).*$} )
        {
            $urlHost = $1;

            if ( $Foswiki::cfg{RemovePortNumber} ) {
                $urlHost =~ s/\:[0-9]+$//;
            }

            # If the urlHost in the url is localhost, this is a lot less
            # useful than the default url host. This is because new CGI("")
            # assigns this host by default - it's a default setting, used
            # when there is nothing better available.
            if ( $urlHost =~ m/^(https?:\/\/)localhost$/i ) {
                my $protocol = $1;

#only replace localhost _if_ the protocol matches the one specified in the DefaultUrlHost
                if ( $Foswiki::cfg{DefaultUrlHost} =~ m/^$protocol/i ) {
                    $urlHost = $Foswiki::cfg{DefaultUrlHost};
                }
            }
        }
        else {
            $urlHost = $Foswiki::cfg{DefaultUrlHost};
        }
        ASSERT($urlHost) if DEBUG;
        return $urlHost;
    },
);
has webName => (
    is      => 'rw',
    clearer => 1,
);
has zones => (
    is        => 'ro',
    lazy      => 1,
    clearer   => 1,
    predicate => 1,
    default   => sub {
        load_package('Foswiki::Render::Zones');
        return Foswiki::Render::Zones->new( session => $_[0] );
    },
);

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
            $SIG{'__WARN__'} = sub { die @_ };
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
    use version 0.77; $VERSION = version->declare('v2.1.0');
    $RELEASE = 'Foswiki-2.1.0';

    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }

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

around BUILDARGS => sub {
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
};

sub BUILD {
    my $this = shift;

    if (SINGLE_SINGLETONS_TRACE) {
        require Data::Dumper;
        print STDERR "new $this: "
          . Data::Dumper->Dump( [ [caller], [ caller(1) ] ] );
    }

    # This is required in case we get an exception during
    # initialisation, so that we have a session to handle it with.
    ASSERT( !$Foswiki::Plugins::SESSION ) if SINGLE_SINGLETONS;

    $Foswiki::Plugins::SESSION = $this;

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

    my $webtopic      = urlDecode( $query->path_info() || '' );
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
          unless ( $this->request->action() eq 'login'
            or ( $ENV{REDIRECT_STATUS} || 0 ) >= 400 );

        my $usingStrikeOne = $Foswiki::cfg{Validation}{Method} eq 'strikeone';
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
                  . $this->getPubURL(
                    $Foswiki::cfg{SystemWebName}, 'JavascriptFiles',
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

        $text = $this->zones()->_renderZones($text);
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
            require Foswiki::Templates;
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
        if ( my $encoding = _gzipAccepted() ) {
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
                require Compress::Zlib;
                $text = Compress::Zlib::memGzip( encode_utf8($text) );
            }
            $binary_body = 1;
        }
    }    # Otherwise fall through and generate plain text

    # Generate (and print) HTTP headers.
    $this->generateHTTPHeaders($hopts);

    if ($binary_body) {
        $this->response->body($text);
    }
    else {
        $this->response->print($text);
    }
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

        # allow the admin to disable us from setting the max-age, as then
        # it can't be set by apache
        $cacheControl = $Foswiki::cfg{BrowserCacheControl}->{ $this->webName }
          if ( $Foswiki::cfg{BrowserCacheControl}
            && defined( $Foswiki::cfg{BrowserCacheControl}->{ $this->webName } )
          );

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

        && $ENV{'HTTP_IF_NONE_MATCH'}
        && $etag eq $ENV{'HTTP_IF_NONE_MATCH'}

        && $ENV{'HTTP_IF_MODIFIED_SINCE'}
        && $lastModified eq $ENV{'HTTP_IF_MODIFIED_SINCE'}
      );

    # finally decide on a 304 reply
    $hopts->{'Status'} = '304 Not Modified';

    #print STDERR "NOT modified\n";
    return 0;
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

---++ ObjectMethod redirectto($url) -> $url

If the CGI parameter 'redirectto' is present on the query, then will validate
that it is a legal redirection target (url or topic name). If 'redirectto'
is not present on the query, performs the same steps on $url.

Returns undef if the target is not valid, and the target URL otherwise.

=cut

sub redirectto {
    my ( $this, $url ) = @_;

    my $redirecturl = $this->request->param('redirectto');
    $redirecturl = $url unless $redirecturl;

    return unless $redirecturl;

    if ( $redirecturl =~ m#^$regex{linkProtocolPattern}://# ) {

        # assuming URL
        return $redirecturl if _isRedirectSafe($redirecturl);
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
    my ( $w, $t ) =
      $this->normalizeWebTopicName( $this->webName, $redirecturl );

    return $this->getScriptUrl( 0, 'view', $w, $t, @attrs );
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
    my ( $this, $url, $passthru, $status ) = @_;
    ASSERT( defined $url ) if DEBUG;

    return unless $this->request;

    ( $url, my $anchor ) = splitAnchorFromUrl($url);

    if ( $passthru && defined $this->request->method() ) {
        my $existing = '';
        if ( $url =~ s/\?(.*)$// ) {
            $existing = $1;    # implicit untaint OK; recombined later
        }
        if ( uc( $this->request->method() ) eq 'POST' ) {

            # Redirecting from a post to a get
            my $cache = $this->cacheQuery();
            if ($cache) {
                if ( $url eq '/' ) {
                    $url = $this->getScriptUrl( 1, 'view' );
                }
                $url .= $cache;
            }
        }
        else {

            # Redirecting a get to a get; no need to use passthru
            if ( $this->request->query_string() ) {
                $url .= '?' . $this->request->query_string();
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
    if ( !_isRedirectSafe($url) ) {

        # goto oops if URL is trying to take us somewhere dangerous
        $url = $this->getScriptUrl(
            1, 'oops',
            $this->webName   || $Foswiki::cfg{UsersWebName},
            $this->topicName || $Foswiki::cfg{HomeTopicName},
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

    $url = $this->getLoginManager()->rewriteRedirectUrl($url);

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

---++ ObjectMethod getScriptUrl( $absolute, $script, $web, $topic, ... ) -> $scriptURL

Returns the URL to a Foswiki script, providing the web and topic as
"path info" parameters.  The result looks something like this:
"http://host/foswiki/bin/$script/$web/$topic".
   * =...= - an arbitrary number of name,value parameter pairs that will
be url-encoded and added to the url. The special parameter name '#' is
reserved for specifying an anchor. e.g.
=getScriptUrl('x','y','view','#'=>'XXX',a=>1,b=>2)= will give
=.../view/x/y?a=1&b=2#XXX=

If $absolute is set, generates an absolute URL. $absolute is advisory only;
Foswiki can decide to generate absolute URLs (for example when run from the
command-line) even when relative URLs have been requested.

The default script url is taken from {ScriptUrlPath}, unless there is
an exception defined for the given script in {ScriptUrlPaths}. Both
{ScriptUrlPath} and {ScriptUrlPaths} may be absolute or relative URIs. If
they are absolute, then they will always generate absolute URLs. if they
are relative, then they will be converted to absolute when required (e.g.
when running from the command line, or when generating rss). If
$script is not given, absolute URLs will always be generated.

If either the web or the topic is defined, will generate a full url (including web and topic). Otherwise will generate only up to the script name. An undefined web will default to the main web name.

As required by RFC3986, the returned URL will only contain the
allowed characters -A-Za-z0-9_.~!*\'();:@&=+$,/?%#[]

=cut

sub getScriptUrl {
    my ( $this, $absolute, $script, $web, $topic, @params ) = @_;

    $absolute ||=
      ( $this->inContext('command_line') || $this->inContext('absolute_urls') );

    # SMELL: topics and webs that contain spaces?

    my $url;
    if ( defined $Foswiki::cfg{ScriptUrlPaths} && $script ) {
        $url = $Foswiki::cfg{ScriptUrlPaths}{$script};
    }
    unless ( defined($url) ) {
        $url = $Foswiki::cfg{ScriptUrlPath};
        if ($script) {
            $url .= '/' unless $url =~ m/\/$/;
            $url .= $script;
            if (
                rindex( $url, $Foswiki::cfg{ScriptSuffix} ) !=
                ( length($url) - length( $Foswiki::cfg{ScriptSuffix} ) ) )
            {
                $url .= $Foswiki::cfg{ScriptSuffix} if $script;
            }
        }
    }

    if ( $absolute && $url !~ /^[a-z]+:/ ) {

        # See http://www.ietf.org/rfc/rfc2396.txt for the definition of
        # "absolute URI". Foswiki bastardises this definition by assuming
        # that all relative URLs lack the <authority> component as well.
        $url = $this->urlHost . $url;
    }

    if ($topic) {
        ( $web, $topic ) = $this->normalizeWebTopicName( $web, $topic );

        $url .= urlEncode( '/' . $web . '/' . $topic );

    }
    elsif ($web) {
        $url .= urlEncode( '/' . $web );
    }
    $url .= make_params(@params);

    return $url;
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

---++ ObjectMethod deepWebList($filter, $web) -> @list

Deep list subwebs of the named web. $filter is a Foswiki::WebFilter
object that is used to filter the list. The listing of subwebs is
dependent on $Foswiki::cfg{EnableHierarchicalWebs} being true.

Webs are returned as absolute web pathnames.

=cut

sub deepWebList {
    my ( $this, $filter, $rootWeb ) = @_;
    my @list;
    my $webObject = new Foswiki::Meta( session => $this, web => $rootWeb );
    my $it = $webObject->eachWeb( $Foswiki::cfg{EnableHierarchicalWebs} );
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

---++ StaticMethod load_package( $full_package_name )

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

sub DEMOLISH {
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

---++ ObjectMethod inlineAlert($template, $def, ... ) -> $string

Format an error for inline inclusion in rendered output. The message string
is obtained from the template 'oops'.$template, and the DEF $def is
selected. The parameters (...) are used to populate %PARAM1%..%PARAMn%

=cut

sub inlineAlert {
    my $this     = shift;
    my $template = shift;
    my $def      = shift;

    # web and topic can be anything; they are not used
    my $topicObject = Foswiki::Meta->new(
        session => $this,
        web     => $this->webName,
        topic   => $this->topicName
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

=begin TML

---++ ObjectMethod getApproxRevTime (  $web, $topic  ) -> $epochSecs

Get an approximate rev time for the latest rev of the topic. This method
is used to optimise searching. Needs to be as fast as possible.

SMELL: is there a reason this is in Foswiki.pm, and not in Search?

=cut

sub getApproxRevTime {
    my ( $this, $web, $topic ) = @_;

    my $metacache = $this->search->metacache;
    if ( $metacache->hasCached( $web, $topic ) ) {

        #don't kill me - this should become a property on Meta
        return $metacache->get( $web, $topic )->{modified};
    }

    return $this->store->getApproxRevTime( $web, $topic );
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
