
# See bottom of file for license and copyright information

use strict;
use warnings;

# Continuation of configure initialization.  This is the boostrap/dispatcher
# that manages everything after loading setlib.cfg - which has setup the
# library path so that the other pieces of configure can be loaded.
#
# It is separate to allow globals to be defined in Foswiki::Configure, as
# with all the other modules.
#
# This module is invoked by 'use', and should never return.

# We are configuring $Foswiki::cfg, so we need to be in package Foswiki from
# now on.

package Foswiki;

use version 0.77;

# minimum version of client JavaScript that configure requires.
#
my $minScriptVersion = version->parse("v3.126");

# Maximum acceptable time skew between client and server (seconds)
#
my $maxTimeSkew = 5 * 60;    # No reason this can't be much less if NTP is used.

use Foswiki::Configure (qw/:DEFAULT :auth :cgi :config :session :trace/);

$query                = CGI->new;
$unsavedChangesNotice = '';

# NOT exported, used if code needs to know whether running
# under configure or the webserver.  Webserver will never load Dispatch.

our $configureRunning = 1;

my $action;
my @feedbackHeaders;
if ( $query->http('X-Foswiki-FeedbackRequest') ) {
    @feedbackHeaders = (
        -type                        => 'application/octet-stream',
        'X-Foswiki-FeedbackResponse' => 'V1.0',
    );
    $action = 'feedbackUI';
}
else {
    $action = $query->param('action');
    die "Invalid protocol\n" if ( defined $action && $action eq 'feedbackUI' );
}
$query->delete('action');

$time = time();

$url        = $query->url();
$scriptName = Foswiki::Configure::CGI::getScriptName();
$method     = $query->request_method();
$pathinfo   = $query->path_info();

{
    my $pinfo = $pathinfo;
    $pinfo =~ s,^/,,;
    @pathinfo = split( '/', $pinfo ) if ( defined $pinfo );
    $action ||= $pathinfo[0] || 'Configure';
}
$action =~ tr/A-Za-z0-9_-//cd;

# Use path style URIs except where the webserver can't deal with them.
# So far, Microsoft IIS is reportedly unable to cope...

my $usePinfo = ( $ENV{SERVER_SOFTWARE} || '' ) !~ /\b(Microsoft-IIS)\b/;

# generate references to resources
$resourceURI = $scriptName
  . (
    $usePinfo
    ? "/resource/"
    : "?action=resource&resource="
  );
$actionURI = $scriptName
  . (
    $usePinfo
    ? "/"
    : "?action="
  );

print STDERR "CFG Entered: '$action' "
  . $query->request_method . " - "
  . $query->url() . " - "
  . ( $query->path_info() || 'mt' ) . ' - '
  . ( $query->cookie(COOKIENAME) || 'nocookie' ) . ' '
  . (
    TRANSACTIONLOG > 1
    ? join( ', ',
        map { ( "$_=" . ( $query->param($_) || 'mt' ) ) } sort $query->param() )
    : ''
  )
  . "\n"
  if (TRANSACTIONLOG);

# Make sure we can handle this request

exists { _getValidActions('_validate') }->{$action} or invalidRequest();

#print STDERR "\nNEW TRANSACTION: $action \n";

$DEFAULT_FIELD_WIDTH_NO_CSS = '70';

# Minimal modules needed to handle validation (and resources)

::_loadBasicModule(qw/CGI::Session File::Temp CGI::Cookie/);

# Obtain any existing session for validation and authentication

{
    my $sid = $query->cookie(COOKIENAME) || undef;
    if ( defined $sid && $sid =~ m/^([\w_-]+)$/ ) {
        $sid = $1;
    }
    else {
        undef $sid;
    }

    # Do we need a more permanent place than tmpdir (carts)?

    $session =
      CGI::Session->load( SESSION_DSN, $sid,
        { Directory => File::Spec->tmpdir } )
      or die CGI::Session->errstr();

    if ( RT80346 && $session->dataref->{_SESSION_ID} ) {
        $session->dataref->{_SESSION_ID} =~ /^(.*)$/;
        $session->dataref->{_SESSION_ID} = $1;
    }
}
my $cookie = newCookie($session);

# Any redirect action supersedes request

if ( ( $redirect = $session->param('redirect') ) ) {
    print STDERR "Redirect action: $action => $redirect\n" if (TRANSACTIONLOG);
    $action = $redirect;
    $session->clear('redirect');

  # Should always be valid, but in case of a stale session file, we check anyway

    exists { _getValidActions('_validate') }->{$action} or invalidRequest();
}

::_loadBasicModule(
    qw/Foswiki::Configure::Util Foswiki::Configure::TemplateParser/);

# Validate request.

dispatch( '_validate', $action, \&invalidDispatch, $session, $cookie );

# Note that a resource request never returns!
###########################################################
# From this point on we shouldn't have any more "fatal" (to configure)
# errors, so we can report errors in the browser (i.e. without using die)

_getEnvironmentInfo();

# Load all the bits of the configure module that we explicitly use
# The loadBasicModule does some extra analysis on errors.
::_loadBasicModule(
    qw {
      Cwd
      Data::Dumper
      File::Copy
      Foswiki::Configure::Checker
      Foswiki::Configure::Item
      Foswiki::Configure::Load
      Foswiki::Configure::Pluggable
      Foswiki::Configure::Root
      Foswiki::Configure::Section
      Foswiki::Configure::Type
      Foswiki::Configure::Types::BOOLEAN
      Foswiki::Configure::Types::NUMBER
      Foswiki::Configure::Types::SELECT
      Foswiki::Configure::Types::STRING
      Foswiki::Configure::FoswikiCfg
      Foswiki::Configure::UI
      Foswiki::Configure::UIs::Section
      Foswiki::Configure::Value
      Foswiki::Configure::Valuer
      Foswiki::Configure::GlobalControls
      }
);

# Handle authentication

my $messageType;

dispatch( '_authenticate', $action, sub { htmlResponse( "", 401 ) },
    $session, $cookie );

# Dispatch the action (should not return)

dispatch( '_action', $action, \&invalidDispatch, $session, $cookie );

invalidRequest("$action handling incomplete");

exit(1);

# ######################################################################
# End of the main program; the rest is all subs
# ######################################################################

# Each action has three subroutines that live in Foswiki::
#
# _validateXXX - ensures that the request is acceptable.  May handle
# if GUI isn't required.   Loads any necessary service modules.
#
# _authenticateXXX - ensures that the request is allowable (session, password, etc)
# _actionXXX - actually processes the request
#
# These are called from dispatch().  Any value returned will call an error handler,
# usually invalidRequest, which generates an HTML error page and does not return.
#
# All three routines must exist for each action: implementors must think about each
# request phase.  To add a new action, simply define the three subroutines (there is
# no master list.  The only constraint is that the _validate routine must
# be defined before _getValidActions is called.

# ######################################################################
# Dispatch hooks for each action
# ######################################################################

sub _validateConfigure {
    my ( $action, $session, $cookie ) = @_;

    if ( $method !~ /^(GET|POST)$/ ) {
        invalidRequest( "", 405, Allow => 'GET,POST' );
    }

    ::_loadBasicModule('Foswiki::Configure::MainScreen');
    return;
}

sub _validateSavechanges {
    my ( $action, $session, $cookie ) = @_;

    if ( $query->request_method() ne 'POST' ) {
        invalidRequest( "", 405, Allow => 'POST' );
    }

    ::_loadBasicModule('Foswiki::Configure::MainScreen');
    return;
}

sub _validateMakemorechanges {
    my ( $action, $session, $cookie ) = @_;

    if ( $query->request_method() ne 'POST' ) {
        invalidRequest( "", 405, Allow => 'POST' );
    }

    ::_loadBasicModule('Foswiki::Configure::MainScreen');
    return;
}

sub _validateFindMoreExtensions {
    my ( $action, $session, $cookie ) = @_;

    if ( $query->request_method() ne 'GET' ) {
        invalidRequest( "", 405, Allow => 'GET' );
    }

    ::_loadBasicModule('Foswiki::Configure::MainScreen');
    return;
}

sub _validateManageExtensions {
    my ( $action, $session, $cookie ) = @_;

    if ( $query->request_method() ne 'POST' ) {
        invalidRequest( "", 405, Allow => 'POST' );
    }

    ::_loadBasicModule('Foswiki::Configure::MainScreen');
    return;
}

sub _validateManageExtensionsResponse {
    my ( $action, $session, $cookie ) = @_;

    if ( $query->request_method() ne 'GET' ) {
        invalidRequest( "", 405, Allow => 'GET' );
    }
    invalidRequest( "Not valid interactively", 400 ) unless ($redirect);

    ::_loadBasicModule('Foswiki::Configure::MainScreen');
    return;
}

sub _validatefeedbackUI {
    my ( $action, $session, $cookie ) = @_;

    if ( $query->request_method() ne 'POST' ) {
        invalidRequest( "", 405, Allow => 'POST' );
    }

    # Protocol version check
    my $version = $query->http('X-Foswiki-FeedbackRequest');
    unless ( defined $version
        && ( my $fmtOK = ( $version =~ /^V(\d+)\.(\d+)(\.\d+)?$/ ) )
        && $1 == 1 )
    {
        scriptVersionError( ( defined $version ? ( $fmtOK ? 3 : 2 ) : 1 ),
            protocolVersion => $version, );
    }

    # Script version check - catch browser cache issues, .gz issues,
    # people switching sessions...and botched installations.
    $version = $query->http('X-Foswiki-ScriptVersion');
    unless ( defined $version ) {
        scriptVersionError(4);
    }

    # Version required by perl code (mismatch can be cache or old file)
    unless ( version->parse($version) >= $minScriptVersion ) {
        scriptVersionError(
            5,
            scriptVersionReceived => $version,
            scriptVersionRequired => $minScriptVersion,
        );
    }

    # Version we sent (mismatch is cache or .gz issue)
    my $jsFile =
      "$Foswiki::foswikiLibPath/Foswiki/Configure/resources/scripts.js";
    open( my $s, '<', $jsFile )
      or die "Can't find client javascript $jsFile: $!\n";
    my $jsVersionFound;
    while (<$s>) {
        if (/^\s*(?:var\s+)?VERSION\s+=\s+['"](.*)["']\s*[,;]\s*$/) {
            $jsVersionFound = $1;
            scriptVersionError(
                5,
                scriptVersionReceived => $version,
                scriptVersionRequired => $jsVersionFound,
            ) unless ( $jsVersionFound eq $version );
            last;
        }
    }
    close $s;
    scriptVersionError(6) unless ($jsVersionFound);

    # Tell script what version it should be.

    push @feedbackHeaders,
      ( 'X-Foswiki-ScriptVersionRequired' => $jsVersionFound );

    # Fast null response to version check request.
    htmlResponse('') unless $ENV{CONTENT_LENGTH};

    my $clientTime = $query->http('X-Foswiki-ClientTime') || 0;
    my $serverTime = time;
    my $skew       = abs( $clientTime - $serverTime );
    if ( $skew > $maxTimeSkew ) {
        require POSIX;
        my $tz = localtime($serverTime);    # Initialize tzname
        $tz = POSIX::tzname() || 'server local';
        if ( $maxTimeSkew >= 60 ) {
            my $mins = sprintf( "%.0f", $maxTimeSkew / 60 );
            $mins .= $mins == 1 ? ' minute' : ' minutes';
            $maxTimeSkew = "$maxTimeSkew seconds ($mins)";
        }
        $clientTime =
          gmtime($clientTime) . ' UTC' . ', ' . localtime($clientTime) . " $tz";
        $serverTime =
          gmtime($serverTime) . ' UTC' . ', ' . localtime($serverTime) . " $tz";

        scriptVersionError(
            7,
            clientTime  => $clientTime,
            serverTime  => $serverTime,
            maxTimeSkew => $maxTimeSkew
        );
    }

    ::_loadBasicModule('Foswiki::Configure::Feedback');
    return;
}

# Report errors due to mismatch with script version

sub scriptVersionError {
    my $errorType = shift;

    ::_loadBasicModule('Foswiki::Configure::UI');

    my $html =
      Foswiki::Configure::UI::getTemplateParser()
      ->readTemplate('feedbackprotocol');
    $html = Foswiki::Configure::UI::getTemplateParser()->parse(
        $html,
        {
            RESOURCEURI => $resourceURI,
            resourcePath =>
              "$Foswiki::foswikiLibPath/Foswiki/Configure/resources",
            protocolVersion => '',
            etype           => $errorType,
            versionReceived => '',
            versionRequired => '',
            @_,
        }
    );
    Foswiki::Configure::UI::getTemplateParser()->cleanupTemplateResidues($html);

    htmlResponse( $html, 200 );

    # Does not return
}

# ######################################################################
# Common subroutines
# ######################################################################

# Get the LocalSite.cfg file and .spec files read
# Check for severe errors

sub _loadSiteConfig {

    # Subset UI for these checks

    my $stub = new Foswiki::Configure::Item();
    my $sanityUI = Foswiki::Configure::UI::loadChecker( 'BasicSanity', $stub );

    # This "checker" actually loads the LocalSite.cfg and Foswiki.spec files

    $sanityStatement = $sanityUI->check();

    # Bad LocalSite.cfg, errors (no file, no path, not writable, perl syntax)

    $badLSC = $sanityUI->lscIsBad();
    $insane = $sanityUI->insane();

    return;
}

# Sort a list of hash keys for display

sub sortHashkeyList {
    return map { $_->[0] } sort {
        my @a = @{ $a->[1] };
        my @b = @{ $b->[1] };
        while ( @a && @b ) {
            my $c = shift(@a) cmp shift(@b);
            return $c if ($c);
        }
        return @a <=> @b;
      } map {
        [ $_, [ map { s/(?:^\{)|(?:\}$)//g; $_ } split( /\}\{/, $_ ) ] ]
      } @_;
}

sub _getEnvironmentInfo {

    # Get web server's group info
    $::WebServer_gid = '';
    eval {
        $::WebServer_gid =
          join( ',', map { lc( getgrgid($_) ) } split( ' ', $( ) );
    };
    if ($@) {

        # Try to use Cygwin's 'id' command - may be on the path, since Cygwin
        # is probably installed to supply ls, egrep, etc - if it isn't, give
        # up.
        # Run command without stderr output, to avoid CGI giving error.
        # Get names of primary and other groups.
        # This is down here because it takes 30s to execute on Strawberry perl
        $::WebServer_gid =
          lc( qx(sh -c '( id -un ; id -gn) 2>/dev/null' 2>nul ) || 'n/a' );
    }

    ###########################################################
    # Grope the OS. This duplicates a bit of code in Foswiki.pm,
    # but it has to be duplicated because we don't want to deal
    # with loading Foswiki just yet.

    unless ( $cfg{DetailedOS} ) {
        $cfg{DetailedOS} = $^O;
        unless ( $cfg{DetailedOS} ) {
            require Config;
            no warnings 'once';
            $cfg{DetailedOS} = $Config::Config{osname};
        }
    }
    unless ( $cfg{OS} ) {
        if ( $cfg{DetailedOS} =~ /darwin/i ) {    # MacOS X
            $cfg{OS} = 'UNIX';
        }
        elsif ( $cfg{DetailedOS} =~ /Win/i ) {
            $cfg{OS} = 'WINDOWS';
        }
        elsif ( $cfg{DetailedOS} =~ /vms/i ) {
            $cfg{OS} = 'VMS';
        }
        elsif ( $cfg{DetailedOS} =~ /bsdos/i ) {
            $cfg{OS} = 'UNIX';
        }
        elsif ( $cfg{DetailedOS} =~ /dos/i ) {
            $cfg{OS} = 'DOS';
        }
        elsif ( $cfg{DetailedOS} =~ /^MacOS$/i ) {    # MacOS 9 or earlier
            $cfg{OS} = 'MACINTOSH';
        }
        elsif ( $cfg{DetailedOS} =~ /os2/i ) {
            $cfg{OS} = 'OS2';
        }
        else {
            $cfg{OS} = 'UNIX';
        }
    }

    # Remember what we detected previously, for use by Checkers
    if ( $scriptName =~ /(\.\w+)$/ ) {
        $cfg{DETECTED}{ScriptExtension} = $1;
    }
}

# ######################################################################
# Unsaved changes report
# ######################################################################

sub unsavedChangesNotice {
    my ( $updated, $includeTime, $timeSaved ) = @_;

    return '' unless ( loggedIn($session) || $badLSC || $query->auth_type );

    require Foswiki::Configure::ModalTemplates;

    my $template = Foswiki::Configure::ModalTemplates->new(
        '{ConfigureGUI::Modals::UnsavedDetail}');

    $template->renderActivationButton( unsavedDetailButton => 'UnsavedDetail' );
    $template->renderFeedbackWindow( unsavedDetailFeedback => 'UnsavedDetail' );

    # Remove any {ConfigureGUI} pseudo-keys from %updated and count the rest.

    my $pending = 0;
    foreach my $keys ( keys %$updated ) {
        if ( $keys =~ /^\{ConfigureGUI\}/ ) {
            delete $updated->{$keys};
        }
        else {
            $pending++;
        }
    }
    $template->addArgs( pendingCount => $pending, );
    $template->addArgs( timesaved    => scalar localtime($timeSaved) )
      if ($includeTime);
    my $templateArgs = $template->getArgs;

    my $pendingHtml = $template->extractArgs('feedbackunsaved');
    $pendingHtml = Foswiki::Configure::UI::getTemplateParser()
      ->parse( $pendingHtml, $templateArgs );
    $pendingHtml = Foswiki::Configure::UI::getTemplateParser()
      ->parse( $pendingHtml, $templateArgs );
    Foswiki::Configure::UI::getTemplateParser()
      ->cleanupTemplateResidues($pendingHtml);

    return $pendingHtml;
}

# ######################################################################
# log an error
# ######################################################################

sub log {
    my ($message) = @_;

    $message ||= '';
    my $log = $cfg{DebugFileName} || 'ConfigureError.log';
    my $file;
    if ( open( $file, '>>', $log ) ) {
        print $file "$message\n";
        close($file);
    }
}

# ######################################################################
# Load a UI with extra diagnostics on failure
# ######################################################################

sub _checkLoadUI {
    my ( $uiname, $root ) = @_;
    my $ui = eval { Foswiki::Configure::UI::loadUI( $uiname, $root ) };
    unless ($ui) {
        my $msg = "Could not load $uiname UI. Error was: <pre>$@</pre>";
        if ( $@ =~ /Can't locate (\S+)/ ) {
            $msg .= << "HERE";
You may be able to correct this error by installing the missing $1 module.
HERE

        }
        htmlResponse( $msg, ERROR_FORM );
    }
    return $ui;
}

sub _validateDiscardChanges {
    my ( $action, $session, $cookie ) = @_;

    if ( $query->request_method() ne 'POST' ) {
        invalidRequest( "", 405, Allow => 'POST' );
    }

    ::_loadBasicModule('Foswiki::Configure::MainScreen');
    return;
}

sub _validateLogout {
    my ( $action, $session, $cookie ) = @_;

    if ( $query->request_method() ne 'POST' ) {
        invalidRequest( "", 405, Allow => 'POST' );
    }

    ::_loadBasicModule('Foswiki::Configure::MainScreen');
    return;
}

# ######################################################################
# Resource server
# ######################################################################

# This is the most frequently invoked function (every icon, image,etc).
# To keep it relatively fast, it lives in the main module, and executes
# before the heavyweight UI components are loaded.

# Request validator

sub _validateresource {
    my ( $action, $session, $cookie ) = @_;

    if ( $query->request_method() ne 'GET' ) {
        invalidRequest( "", 405, Allow => 'GET' );
    }

    my $resource = $query->param('resource') || $pathinfo[1];

    defined($resource) or return "No resource specified";

    if ( $resource =~ /^((?:[-\w_]+\.)+\w+)$/ ) {    # filter-in and untaint
        $resource = $1;
    }
    else {
        return "Invalid resource name";
    }

    # Resources don't need the GUI, so authenticate and handle the action here

    dispatch( '_authenticate', 'resource', \&invalidDispatch, $session );
    goto &_actionresource;
}

# Request authenticator

sub _authenticateresource {
    my ( $action, $session, $cookie ) = @_;

    # Must have an established session (not necessarily logged-in)
    # This prevents resource requests not preceeded by another action

    if (  !$session
        || $session->is_expired
        || !loggedIn($session)
        && !activeSession($session)
        && !$session->is_new )
    {
        invalidRequest( "", 401 );
    }
    refreshSession($session);

    return;
}

# Request handler

sub _actionresource {

    #    my( $action, $session, $cookie ) = @_;

    my $resource = $query->param('resource') || $pathinfo[1];

    defined($resource) or return "No resource specified";

    $resource =~ /^([-\w._]+\.\w+)$/
      or return "Invalid resource name $resource";    # filter-in and untaint
    $resource = $1;

    #ignore $query->param('type') and set it using the extension
    my $type = 'text/plain; charset=UTF-8';
    if ( $resource =~ /\.([^.]+)$/ ) {
        $type = {
            bmp  => 'image/x-ms-bmp',
            css  => 'text/css; charset=UTF-8',
            htm  => 'text/html; charset=UTF-8',
            html => 'text/html; charset=UTF-8',
            ico  => 'image/vnd.microsoft.icon',

            #                ico => 'image/x-icon',
            gif  => 'image/gif',
            jpg  => 'image/jpeg',
            jpeg => 'image/jpeg',
            js   => 'text/javascript; charset=UTF-8',
            png  => 'image/png',
            rgb  => 'image/rgb',
            tiff => 'image/tiff',
            xbm  => 'image/x-bitmap',
            xpm  => 'image/x-pixmap',
          }->{$1}
          || $type;
    }

    # We get the data unconditionally as we need to recompute
    # the validators.  Should be relatively cheap.
    # We will zip on demand for text/* content.

    my $parser = Foswiki::Configure::TemplateParser->new;
    my $zipok;
    my $text = ( $type =~ m,^text/, );
    if ($text) {
        my @accept = split( /,\s*/, ( $query->http('Accept-Encoding') || '' ) );
        foreach my $accept (@accept) {
            if ( $accept =~ /^(?:(?:gzip|\*)(?:\s*;\s*q=\d+(?:\.\d+)?)?)\s*$/ )
            {
                $zipok = 1;
                last;
            }
        }
    }

    # Note that only static variables are allowed here (such as the
    # WIKI's URI, as resources are cachable.  If they change once in
    # a while, a browser REFRESH will re-validate, and the ETag will
    # ensure that updated data is provided.  In particular, this
    # allows .css files to contain URIs (e.g. for background images.)
    # and still be cached.  Don't add anything dynamic.
    # N.B. Since some webservers may want to direct-map resources,
    # we'll replace the hard-coded query string with $resourceURI
    # in the sane ones.

    ( $text, my $etag, my $zipped ) = $parser->getResource(
        $resource,
        -remote                      => 1,
        -etag                        => 1,
        -binmode                     => !$text,
        -zipok                       => $zipok,
        RESOURCEURI                  => $resourceURI,
        '?action=resource&resource=' => $resourceURI,
    );

    defined $etag or htmlResponse( "$resource not found", 404 );

    my @headers = ( ETag => $etag );

    # Cache control mut be private because cookies are required to authenticate
    # resource requests.

    push @headers,
      (
        RESOURCECACHETIME > 0
        ? (
            Cache_Control => ( 'private, max-age=' . RESOURCECACHETIME ),
            -expires      => ( '+' . RESOURCECACHETIME . 's' ),
          )
        : (
            Cache_Control => 'no-cache',
            -expires      => '-1d',
        )
      );

    # See if we really need to send this
    # If the browser sent an ETag for this resource, and
    # it matches the current tag, we don't.
    # ETags are opaque; just an optional strength indicator
    # and a quoted string.  A browser may cache several
    # versions of a resource and thus send several
    # ETag candidates.  We return the one (if any) that
    # matches the current state.  (E.g. variable substitution)
    #
    # Note that we must not return entity headers with a weak validator and
    # should not for a strong one.  So we dont.

    if ( ( my $htags = $query->http('If-None-Match') ) ) {
        foreach my $htag ( split /\s*,\s*/, $htags ) {
            $htag =~ m,^\s*((?:W/)?"[^"]+")\s*$, or next;
            if ( $1 eq $etag ) {
                htmlResponse( '', 304, @headers );
            }
        }
    }

    push @headers, ( Content_Encoding => 'gzip' )
      if ($zipped);
    push @headers, ( Content_Type => $type );
    htmlResponse( $text, 200, @headers );
}

# ######################################################################
# Session management
# ######################################################################

# ######################################################################
# Establish a session
# ######################################################################

sub establishSession {
    my ( $session, $cookie ) = @_;

    if ( $session->is_empty ) {
        $session = $session->new($session) or die CGI::Session->errstr();
        $cookie  = newCookie($session);
        $_[0]    = $session;
        $_[1]    = $cookie;

        if (RT80346) {
            $session->dataref->{_SESSION_ID} =~ /^(.*)$/;
            $session->dataref->{_SESSION_ID} = $1;
        }
    }
    print STDERR "Strace: Establish "
      . join( ', ', ( caller(1) )[ 0, 3, 1, 2 ] ) . ' '
      . $session->id . ' '
      . ( $session->param('_PASSWD_OK') || 'f' )
      . ( $session->param('_SAVE_OK')   || 'f' ) . "\n"
      if (SESSIONTRACE);
}

# Session state variables.
# Note that these variables all auto-expire

# ######################################################################
# See if logged-in
# ######################################################################

sub loggedIn {
    my $session = shift;

    print STDERR "Strace: Islog "
      . join( ', ', ( caller(1) )[ 0, 3, 1, 2 ] ) . "\n"
      if (SESSIONTRACE);
    return 1 if ( $session->param('_PASSWD_OK') );

    return 0 unless ( $query->auth_type() );    # Basic, Digest, ...

    return 0
      unless ( $cfg{Password} && !$query->param('changePassword') );

    refreshLoggedIn($session);                  # OK to rely on browser

    return 1;
}

sub refreshLoggedIn {
    my $session = shift;

    print STDERR "Strace: Reflog "
      . join( ', ', ( caller(1) )[ 0, 3, 1, 2 ] ) . "\n"
      if (SESSIONTRACE);
    $newLogin = !$session->param('_PASSWD_OK');
    $session->param( '_PASSWD_OK', 1 );
    $session->expires( '_PASSWD_OK', SESSIONEXP );

    return 1;
}

# ######################################################################
# See if save permitted
# ######################################################################

sub saveAuthorized {
    my $session = shift;

    print STDERR "Strace: isSave "
      . join( ', ', ( caller(1) )[ 0, 3, 1, 2 ] ) . "\n"
      if (SESSIONTRACE);
    return $session->param('_SAVE_OK');
}

sub refreshSaveAuthorized {
    my $session = shift;

    print STDERR "Strace: Refsave "
      . join( ', ', ( caller(1) )[ 0, 3, 1, 2 ] ) . "\n"
      if (SESSIONTRACE);
    $session->param( '_SAVE_OK', 1 );
    $session->expires( '_SAVE_OK', SAVEEXP );

    return 1;
}

# ######################################################################
# See if resource access is allowed
# ######################################################################

sub activeSession {
    my $session = shift;

    print STDERR "Strace: Isact "
      . join( ', ', ( caller(1) )[ 0, 3, 1, 2 ] ) . "\n"
      if (SESSIONTRACE);
    return $session->param('_RES_OK');
}

sub refreshSession {
    my $session = shift;

    print STDERR "Strace: refact "
      . join( ', ', ( caller(1) )[ 0, 3, 1, 2 ] ) . "\n"
      if (SESSIONTRACE);
    $session->param( '_RES_OK', 1 );
    $session->expires( '_RES_OK', RESOURCEEXP );

    return 1;
}

# ######################################################################
# close session (e.g. logout)
# ######################################################################

sub closeSession {
    my ( $session, $cookie ) = @_;

    print STDERR "Strace: close "
      . join( ', ', ( caller(1) )[ 0, 3, 1, 2 ] ) . "\n"
      if (SESSIONTRACE);

    $session->clear(
        [qw/_PASSWD_OK _SAVE_OK _RES_OK redirect redirectResults/] );

    # Note that we do not clear 'pending' or delete the session

    return;
}

# ######################################################################
# create a new cookie
# ######################################################################

sub newCookie {
    my $session = shift;

    my @pars = ( -name => COOKIENAME, -value => $session->id );
    push @pars, -secure => 1 if ( $ENV{HTTPS} && $ENV{HTTPS} eq 'on' );

    # Can't include path since we test short URLs.
    push @pars, -path => '/', -expires => "+" . COOKIEEXP;
    $cookie = CGI->cookie(@pars);
    return $cookie;
}

# ######################################################################
# Request handling infrastructure
# ######################################################################

# Dispatch a request to a handler, reporting any error

sub dispatch {

    #    my( $type, $action, $errsub, @args );

    my $type   = shift;
    my $action = shift;
    my $errsub = shift or die "No errsub for $action\n";

    my %dispatch = _getValidActions($type);

    my $handler = $dispatch{$action} or invalidRequest();

    my $error = $handler->( $action, @_ );
    return 1 unless ($error);

    return $errsub->( $error, @_ );
}

# Not that it's a good idea:

sub ignoreError {
    return;
}

# ######################################################################
# Handle an invalid dispatch
# ######################################################################

sub invalidDispatch {
    my $error  = shift;
    my $type   = shift;
    my $action = shift;

    defined $error or $error = "";
    invalidRequest( "Invalid Dispatch $type/$action $error", 400 );
}

# ######################################################################
# Terminate request with a simple HTML response
# ######################################################################

sub invalidRequest {
    my $reason = shift || "The specified request ($action) is invalid";
    my $status = shift;
    $status = 400 unless ( defined $status );

    htmlResponse( $reason, $status + ERROR_FORM, @_ );
}

# ######################################################################
# Standard HTML response
# ######################################################################

# All responses come thru here (or should)
#
# Special handling is encoded in status (evaluated in order):
#   o Routine exits unless the status is 1xx_xxx
#   o POST responses are redirected unless the status is 1x_xxx
#   o Error screens are built if the status is 1_xxx;
#   o The actual status is in the low 3 decimal digits
#
# The session cookie is applied if we have one

sub htmlResponse {
    my $reason = shift;
    my $status = shift || 200;

    # See 'use constants' at # htmlResponse flags near top of file

    my $flags = sprintf( "%08u", $status / 1000 );
    $status %= 1000;
    $status ||= 200;

    my ( $moreOutput, $noRedirect, $errForm ) = $flags =~ /(.)(.)(.)$/;
    $noRedirect = 1 if (@feedbackHeaders);

    if ( $method eq 'POST' && !$noRedirect ) {
        htmlRedirect(
            'DisplayResults',
            {
                reason => $reason,
                status => $status,
                args   => [@_],
            }
        );
    }

    my $sts = {
        200 => { msg => 'OK', hdr => 'Request succeeded' },
        304 => { msg => 'Not Modified' },
        400 => { msg => 'Invalid Request' },
        401 => { msg => 'Not authorized' },
        404 => { msg => 'Not found' },
        405 => { msg => "Method $method not allowed" },
      }->{$status}
      or die "Invalid status";

    my $html = '';

    if ($errForm) {
        $sts->{hdr} = 'Request failed' if ( $status == 200 );
        $sts->{hdr} = $sts->{msg} unless ( exists $sts->{hdr} );
        $html .= CGI::start_html();
        $html .= CGI::h1( $sts->{hdr} );
        $html .= CGI::p($reason) if ($reason);
        $html .= CGI::end_html();
    }
    else {
        $html .= $reason;
    }

    # Default handling for cache control and content encoding
    # Output is non-cachable (except resources)
    # Gzip output if possible, unless more is coming from elsewhere.
    # Resource decision to zip is more complex; it's already done.

    unless ( $action eq 'resource' ) {
        push @_,
          (
            Cache_Control => 'no-cache',
            -expires      => '-1d',
          );

        unless ( $moreOutput || length($html) < 2048 ) {
            my @accept =
              split( /,\s*/, ( $query->http('Accept-Encoding') || '' ) );
            foreach my $accept (@accept) {
                if ( $accept =~
                    /^(?:(?:gzip|\*)(?:\s*;\s*q=\d+(?:\.\d+)?)?)\s*$/ )
                {
                    eval "use IO::Compress::Gzip ();";
                    last if ($@);
                    my $data = $html;
                    undef $html;
                    no warnings 'once';
                    IO::Compress::Gzip::gzip( \$data, \$html )
                      or die
"Unable to gzip response: $IO::Compress::Gzip::GzipError\n";
                    push @_, ( Content_Encoding => 'gzip' );
                    last;
                }
            }
        }
    }

    # With the data in final form, header can be generated.

    push @_, -cookie => $cookie if ( defined $cookie && $session );

    unshift @_, ( Content_Length => length($html) )
      unless ($moreOutput);

    $html = $query->header(
        -status       => "$status " . $sts->{msg},
        -Content_type => 'text/html; charset=utf8',
        @feedbackHeaders, @_,
    ) . $html;

    if ($session) {
        refreshSession($session);
        $session->flush;
    }

    print $html;

    exit unless ($moreOutput);
}

# ######################################################################
# Redirect to the main script to retrieve results
# ######################################################################

# $action is the command to be executed
# Other arguments are joined if there are more than one.
# If only one, it can be a hash or other structure.
# These are saved in the sesson for retrieval by the GET
# Does not return.

sub htmlRedirect {
    my $action = shift;
    my $content = ( @_ == 1 ? $_[0] : join( '', @_ ) );

    if ($session) {
        $session->param( 'redirectResults', $content );
        $session->param( 'redirect',        $action );
        refreshSession($session);
    }

    rawRedirect($scriptName);
}

# ######################################################################
# Retrieve results of redirect (and clear)
# ######################################################################

sub redirectResults {
    my $results = $session->param('redirectResults');
    $session->clear('redirectResults');

    return $results;
}

# ######################################################################
# Redirect anywhere
# ######################################################################

sub rawRedirect {
    my $destination = shift;

    if ($session) {
        $session->flush;
    }

    my $body = << "REDIRECT";
<html><head></head><body>Results at <a href="$destination">$destination</a></body></html>
REDIRECT

    print $query->redirect(
        -uri            => $destination,
        -status         => '303 Results ready',
        -Content_Type   => 'text/html; charset=utf8',
        -Content_Length => length($body),
        @feedbackHeaders, @_
    ), $body;

    exit;
}

# ######################################################################
# Display results in response to a redirect
# ######################################################################

sub _validateDisplayResults {
    my ( $action, $session, $cookie ) = @_;

    if ( $query->request_method() ne 'GET' ) {
        invalidRequest( "", 405, Allow => 'GET' );
    }

    my $results = redirectResults();
    invalidRequest("Bad redirect or use of BACK")
      unless ( $results && ref($results) eq 'HASH' );
    htmlResponse( $results->{reason}, $results->{status},
        @{ $results->{args} } );
}

sub _authenticateDisplayResults {
    my ( $action, $session, $cookie ) = @_;
    die;
}

sub _actionDisplayResults {
    my ( $action, $session, $cookie ) = @_;
    die;
}

# ######################################################################
# Return list of valid action routines suitable for dispatching
# ######################################################################

# N.B. This must be AFTER all _actionXX routines have been declared.
# It should be the last module in this file.

sub _getValidActions {
    my $prefix = shift;

    no strict 'refs';
    return map {
            ( /^$prefix(.*)$/ && ref( *{$_}{CODE} ) eq 'CODE' )
          ? ( $1 => *{$_}{CODE} )
          : ()
      }
      keys %Foswiki::;
}

# We should NEVER get here

0;
__END__

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2000-2006 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root
of this distribution. NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
