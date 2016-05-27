# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::LoginManager

The package is also a Factory for login managers and also the base class
for all login managers.

On it's own, an object of this class is used when you specify 'none' in
the security setup section of
[[%SCRIPTURL{"configure"}%][configure]]. When it is used,
logins are not supported. If you want to authenticate users then you should
consider TemplateLogin or ApacheLogin, which are subclasses of this class.

If you are building a new login manager, then you should write a new subclass
of this class, implementing the methods marked as *VIRTUAL*. There are already
examples in the =lib/Foswiki/LoginManager= directory.

The class has extensive tracing, which is enabled by
$Foswiki::cfg{Trace}{LoginManager}. The tracing is done in such a way as to
let the perl optimiser optimise out the trace function as a no-op if tracing
is disabled.

Here's an overview of how it works:

Early in Foswiki::new, the login manager is created. The creation of the login manager does two things:
   1 If sessions are in use, it loads CGI::Session but doesn't initialise the session yet.
   1 Creates the login manager object
Slightly later in Foswiki::new, loginManager->loadSession is called.
   1 Calls loginManager->getUser to get the username *before* the session is created
      * Foswiki::LoginManager::ApacheLogin looks at REMOTE_USER (only for authenticated scripts)
      * Foswiki::LoginManager::TemplateLogin just returns undef
   1 If the NO_FOSWIKI_SESSION environment variable is defined, then no session is created and the username is returned. This might be defined for search engine bots, depending on how the web server is configured
   1 Reads the FOSWIKISID cookie to get the SID (or the FOSWIKISID parameters in the CGI query if cookies aren't available, or IP2SID mapping if that's enabled).
   1 Creates the CGI::Session object, and the session is thereby read.
   1 If the username still isn't known, reads it from the cookie. Thus Foswiki::LoginManager::ApacheLogin overrides the cookie using REMOTE_USER, and Foswiki::LoginManager::TemplateLogin *always* uses the session.

Later again in Foswiki::new, plugins are given a chance to *override* the username found from the loginManager.

The last step in Foswiki::new is to find the user, using whatever user mapping manager is in place.

---++ ObjectData =twiki=

The Foswiki object this login manager is attached to.

=cut

package Foswiki::LoginManager;

use strict;
use warnings;
use Assert;
use Error qw( :try );

use Foswiki::Sandbox ();
use CGI::Session     ();

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

# Marker chars
our $M1 = chr(5);
our $M2 = chr(6);
our $M3 = chr(7);

# Some session keys are secret (not to be given to the browser) and
# others read only (not to be changed from the browser)
our %secretSK = ( STRIKEONESECRET => 1, VALID_ACTIONS => 1 );
our %readOnlySK = ( %secretSK, AUTHUSER => 1, SUDOFROMAUTHUSER => 1 );

use constant TRACE => $Foswiki::cfg{Trace}{LoginManager} || 0;

use constant CGIDRIVER => 'driver:File;serializer:Storable';

# GusestSessions should default to enabled, since much of Foswiki depends on
# having a valid session.
my $guestSessions =
  ( !defined $Foswiki::cfg{Sessions}{EnableGuestSessions}
      || $Foswiki::cfg{Sessions}{EnableGuestSessions} );

=begin TML

---++ StaticMethod makeLoginManager( $session ) -> $Foswiki::LoginManager

Factory method, used to generate a new Foswiki::LoginManager object
for the given session.

=cut

sub makeLoginManager {
    my $session = shift;

    ASSERT( $session->isa('Foswiki') ) if DEBUG;

    #user is trying to sudo login - use BaseUserMapping
    if ( $session->{request}->param('sudo') ) {

        #promote / login to internal wiki admin
        $session->enterContext('sudo_login');
    }

    if ( $Foswiki::cfg{UseClientSessions}
        && !$session->inContext('command_line') )
    {

        my $sessionname;
        my $use = 'use Foswiki::LoginManager::Session';
        if ( $Foswiki::cfg{Sessions}{UseIPMatching} ) {
            $use .= ' qw(-ip_match)';
        }
        $use .= '; use CGI::Cookie ()';
        eval $use;
        throw Error::Simple($@) if $@;
        if ( $session->{request}->https() ) {
            $sessionname = 'SFOSWIKISID';
        }
        else {
            $sessionname = 'FOSWIKISID';
        }
        if ( $Foswiki::LoginManager::Session::VERSION eq '4.10' ) {

            # 4.10 is broken; see Item1989
            $Foswiki::LoginManager::Session::NAME = $sessionname;
        }
        else {
            Foswiki::LoginManager::Session->name($sessionname);
        }
    }

    my $mgr;
    if ( $Foswiki::cfg{LoginManager} eq 'none' ) {

        # No login manager; just use default behaviours
        $mgr = new Foswiki::LoginManager($session);
    }
    else {

        # Rename from old "Client" to new "LoginManager" - see TWikibug:Item3375
        $Foswiki::cfg{LoginManager} =~ s/::Client::/::LoginManager::/;
        my $loginManager = $Foswiki::cfg{LoginManager};
        if ( $session->inContext('sudo_login') )
        {    #TODO: move selection into BaseUserMapper
            $loginManager = 'Foswiki::LoginManager::TemplateLogin';
        }
        eval "require $loginManager";
        die $@ if $@;
        $mgr = $loginManager->new($session);
    }
    return $mgr;
}

=begin TML

---++ ClassMethod new ($session, $impl)

Construct the user management object

=cut

# protected: Construct new client object.
sub new {
    my ( $class, $session ) = @_;
    my $this = bless(
        {
            session     => $session,
            twiki       => $session,    # backwards compatibility
            _haveCookie => 0,
        },
        $class
    );

    # make sure the filePermission setting has got a sensible default
    $Foswiki::cfg{Session}{filePermission} = 0600
      unless defined $Foswiki::cfg{Session}{filePermission};

    $session->leaveContext('can_login');
    map { $this->{_authScripts}{$_} = 1; }
      split( /[\s,]+/, $Foswiki::cfg{AuthScripts} );

    # register tag handlers and values
    Foswiki::registerTagHandler( 'LOGINURL',         \&_LOGINURL );
    Foswiki::registerTagHandler( 'LOGIN',            \&_LOGIN );
    Foswiki::registerTagHandler( 'LOGOUT',           \&_LOGOUT );
    Foswiki::registerTagHandler( 'LOGOUTURL',        \&_LOGOUTURL );
    Foswiki::registerTagHandler( 'SESSION_VARIABLE', \&_SESSION_VARIABLE );
    Foswiki::registerTagHandler( 'AUTHENTICATED',    \&_AUTHENTICATED );
    Foswiki::registerTagHandler( 'CANLOGIN',         \&_CANLOGIN );

    return $this;
}

=begin TML

---++ ObjectMethod finish()
Break circular references.

=cut

# Note to developers; please undef *all* fields in the object explicitly,
# whether they are references or not. That way this method is "golden
# documentation" of the live fields in the object.
sub finish {
    my $this = shift;
    $this->complete();    # call to flush the session if not already done
    undef $this->{_authScripts};
    undef $this->{_cgisession};
    undef $this->{_haveCookie};
    undef $this->{_MYSCRIPTURL};
    undef $this->{session};
}

=begin TML

---++ ClassMethod _real_trace ($session, $impl)

Construct the user management object

=cut

sub _real_trace {
    my ( $this, $mess ) = @_;
    my $id =
      'SESSION ' . ( $this->{_cgisession} ? $this->{_cgisession}->id() : '?' );
    $id .= '(c)' if $this->{_haveCookie};
    print STDERR "$id: $mess\n";
}

if (TRACE) {
    *_trace = \&_real_trace;
}
else {
    *_trace = sub { undef };
}

=begin TML

---++ ClassMethod _IP2SID ($session, $impl)

 read/write IP to SID map, return SID

=cut

sub _IP2SID {
    my ( $this, $sid ) = @_;

    my $ip = $this->{session}->{request}->address;

    return unless $ip;    # no IP address, can't map

    my %ips;
    my $IPMAP;
    if ( open( $IPMAP, '<', $Foswiki::cfg{WorkingDir} . '/tmp/ip2sid' ) ) {
        local $/ = undef;
        %ips = map { split( /:/, $_ ) } split( /\r?\n/, <$IPMAP> );
        close($IPMAP);
    }
    if ($sid) {

        # known SID, map the IP addr to it
        $ips{$ip} = $sid;
        open( $IPMAP, '>', $Foswiki::cfg{WorkingDir} . '/tmp/ip2sid' )
          || die
"Failed to open ip2sid map for write. Ask your administrator to make sure that the {Sessions}{Dir} is writable by the webserver user.";
        print $IPMAP map { "$_:$ips{$_}\n" } keys %ips;
        close($IPMAP);
    }
    else {

        # Return the SID for this IP address
        $sid = $ips{$ip};
    }
    return $sid;
}

=begin TML

---++ ObjectMethod loadSession($defaultUser, $pwchecker) -> $login

Get the client session data, using the cookie and/or the request URL.
Set up appropriate session variables in the session object and return
the login name.

$pwchecker is a pointer to an object that implements checkPassword

$defaultUser is a username to use if one is not available from other
sources. The username passed when you create a Foswiki instance is
passed in here.

=cut

sub loadSession {
    my ( $this, $defaultUser, $pwchecker ) = @_;
    my $session = $this->{session};

    _trace( $this, "loadSession" );

    $defaultUser = $Foswiki::cfg{DefaultUserLogin}
      unless ( defined($defaultUser) );

    # Try and get the user from the webserver. This is referred to as
    # the "webserver user". the webserver user is authenticated by some
    # means beyond foswiki e.g. Basic Auth.  getUser is defined in the
    # LoginManager.  The default returns undef.

    my $authUser = $this->getUser($this);
    _trace( $this, "Webserver says user is $authUser" ) if ($authUser);

    # If the NO_FOSWIKI_SESSION environment variable is defined, then
    # do not create the session. This might be defined if the request
    # is made by a search engine bot, depending on how the web server
    # is configured

    if ( $ENV{NO_FOSWIKI_SESSION} ) {
        _trace( $this, "ENV{NO_FOSWIKI_SESSION} blocked the session" );
        return $authUser;
    }

    # Client sessions processing either cookie or IP2SID based:
    if (   $Foswiki::cfg{UseClientSessions}
        && !$session->inContext('command_line')
        && $Foswiki::cfg{WorkingDir} )
    {
        $this->{_haveCookie} = $session->{request}->header('Cookie');

        _trace( $this,
            $this->{_haveCookie}
            ? "Cookie $this->{_haveCookie}"
            : "No cookie " );

        # rough check - if we have a cookie for the SID,
        # or we are using IP2SID mapping then keep going.
        if (
            (
                   $this->{_haveCookie}
                && $this->{_haveCookie} =~ m/FOSWIKISID=([^\s]*)/
            )
            || $Foswiki::cfg{Sessions}{MapIP2SID}
          )
        {
            _trace( $this, " ... Found session id $1" )
              unless ( $Foswiki::cfg{Sessions}{MapIP2SID} );

            if ( $Foswiki::cfg{Sessions}{MapIP2SID} ) {

                # map the end user IP address to a session ID
                my $sid = $this->_IP2SID();

                $this->{_cgisession} = $this->_loadCreateCGISession($sid);

                _trace( $this, "New IP2SID session" ) unless ($sid);
                $this->_IP2SID( $this->{_cgisession}->id() );
            }
            else {

                # IP mapping is off; use the request cookie
                $this->{_cgisession} =
                  $this->_loadCreateCGISession( $session->{request} );

            }

            die Foswiki::LoginManager::Session->errstr()
              unless $this->{_cgisession};

            # Get the authorised user stored in the session

            my $sessionUser = Foswiki::Sandbox::untaintUnchecked(
                $this->{_cgisession}->param('AUTHUSER') );

            _trace( $this, "AUTHUSER from session is $sessionUser" )
              if defined $sessionUser;

    # If we are bootstrapping, and the defaultUser from Foswiki.pm is admin
    # Then override the session user to become admin.   This gets around a stale
    # browser cookie from blocking the bootstrap admin login.

            $authUser = $defaultUser
              if ( $Foswiki::cfg{isBOOTSTRAPPING}
                && $defaultUser eq 'admin' );

            _trace( $this, "AUTHUSER after BOOTSTRAP check is $authUser" )
              if defined $authUser;

            # An admin user stored in the session can override the webserver
            # user; handy for sudo

            $authUser = $sessionUser
              if ( !defined($authUser)
                || $sessionUser
                && $sessionUser eq $Foswiki::cfg{AdminUserLogin} );
        }
    }

    # Checking for URI parameters
    if ( !$authUser ) {

        _trace( $this, "No session, checking URI Params for a user" );

        # if we couldn't get the login manager or the http session to tell
        # us who the user is, check the username and password URI params.
        #
        # Note that this code only applies to scripts other than login.
        # The login script is handled separately.

        my $script = $session->{request}->base_action();

        my $login;    # username from CLI/URI parameters
        my $pass;     # password from CLI/URI parameters

        # If we are in the CLI environment, then
        # the only option is to pass "URL parameters"
        #  - The CLI overrides the "defaultUser" to
        #    be admin.  CLI runs as admin by default.
        #  - -username/-password parameters allow
        #    CLI to use conventional authentication

        if (   $session->inContext('command_line')
            && $session->{request}->param('username') )
        {
            $login = $session->{request}->param('username');
            $pass = $session->{request}->param('password') || '';
            $session->{request}->delete( 'username', 'password' );

            # CLI defaults to Admin User,  but if a
            # user/pass was provided on the cli,  and was wrong,
            # we probably don't want to fall back
            # to Admin, so override the default.
            $defaultUser = $Foswiki::cfg{DefaultUserLogin};

            _trace( $this,
"CLI Credentials $login accepted from command line for further validation"
            );
        }

        # If the configuration allows URL params,
        # and the correct HTTP method is in use,
        # Then accept the username & password,
        # and delete them from the request to avoid
        # them being accessed later.

        if ( !$login ) {
            if (   defined $session->{request}->param('username')
                && defined $Foswiki::cfg{Session}{AcceptUserPwParam}
                && $script =~ m/$Foswiki::cfg{Session}{AcceptUserPwParam}/ )
            {
                if (
                    $Foswiki::cfg{Session}{AcceptUserPwParamOnGET}
                    || ( defined $session->{request}->method()
                        && uc( $session->{request}->method() ) eq 'POST' )
                  )
                {
                    $login = $session->{request}->param('username');
                    $pass  = $session->{request}->param('password');
                    $session->{request}->delete( 'username', 'password' );
                    _trace( $this,
                        "URI Credentials $login accepted for further validation"
                    );
                }
            }
        }

        # Implements the X-Authorization header if one is present
        # Nothing was in the query params. Check query headers.
        if ( !$login ) {

            my $auth = $session->{request}->http('X-Authorization');
            if ( defined $auth ) {
                _trace( $this, "X-Authorization: $auth" );
                if ( $auth =~ m/^FoswikiBasic (.+)$/ ) {

                    # If the user agent wishes to send the userid "Aladdin"
                    # and password "open sesame", it would use the following
                    # header field:
                    # Authorization: Foswiki QWxhZGRpbjpvcGVuIHNlc2FtZQ==
                    require MIME::Base64;
                    my $cred = MIME::Base64::decode_base64($1);
                    if ( $cred =~ m/:/ ) {
                        ( $login, $pass ) = split( ':', $cred, 2 );
                        _trace( $this,
"Login credentials taken from query headers for further validation"
                        );
                    }
                }    # TODO: implement FoswikiDigest here
            }
        }

        # A login credential was found,  verify the userid & password
        if ( $login && defined $pass && $pwchecker ) {
            _trace( $this, "Validating password for $login" );
            my $validation = $pwchecker->checkPassword( $login, $pass );
            unless ($validation) {
                _trace( $this,
                    "URI validation FAILED:  Falling back to $defaultUser" );

                # Item1953: You might think that this is needed:
                #    $res->header( -type => 'text/html', -status => '401' );
                #    throw Foswiki::EngineException( 401, $err, $res );
                # but it would be wrong, because it would require the
                # exception to be handled before the session object is
                # properly initialised, which would cause an error.
                # Instead, we do this, and let the caller handle the error.
                undef $login;
            }
            $authUser = $login || $defaultUser;
            _trace( $this, "After password validation, user is: $authUser" );
        }
        else {

            # Last ditch attempt; if a user was passed in to this function,
            # then use it (it is normally {remoteUser} from the session object
            # or the -user parameter in the command_line (defaults to admin)
            # Also used in unit tests when creating a newFoswikiSession
            $authUser = $defaultUser;
            _trace( $this, "Falling back to DEFAULT USER: $defaultUser" )
              if $authUser;

        }
    }

    # We should have a user at this point; or $defaultUser if there
    # was no better information available.

    # is this a logout?
    if (
        ( $authUser && $authUser ne $Foswiki::cfg{DefaultUserLogin} )
        && (   $this->{_cgisession}
            && $session->{request}
            && $session->{request}->param('logout') )
      )
    {

        # SMELL: is there any way to get evil data into the CGI session such
        # that this untaint is less than safe?
        my $sudoUser = Foswiki::Sandbox::untaintUnchecked(
            $this->{_cgisession}->param('SUDOFROMAUTHUSER') );

        if ($sudoUser) {
            _trace( $this, "User is logging out from $sudoUser" );
            $session->logger->log(
                {
                    level  => 'info',
                    action => 'sudo logout',
                    extra  => 'from ' . ( $authUser || '' ),
                    user   => $sudoUser
                }
            );
            $this->{_cgisession}->clear('SUDOFROMAUTHUSER');
            $authUser = $sudoUser;
        }
        else {
            $this->{_cgisession}->delete();
            $this->{_cgisession}->flush();
            $this->{_cgisession} = undef;
            $this->_delSessionCookieFromResponse();

            $authUser =
              $this->redirectToLoggedOutUrl( $authUser, $defaultUser );
        }
    }
    $session->{request}->delete('logout');

    # SMELL:  EXPERIMENTAL - Guest sessions can be made optional:
    #  - unset $Foswiki::cfg{Sessions}{EnableGuestSessions}
    #
    # Note that if guests can comment, update, or otherwise POST to
    # Foswiki, then pages with forms should be listed in
    # $Foswiki::cfg{Sessions}{TopicsRequireGuestSessions}

    # Call to getLoggedIn inserts the auth user into the cgi session
    $this->userLoggedIn($authUser)
      unless ( $authUser eq $Foswiki::cfg{DefaultUserLogin}
        && !$guestSessions
        && !$session->inContext('sessionRequired') );

    if ( $this->{_cgisession} ) {

        # Restore CGI Session parameters
        for ( $this->{_cgisession}->param ) {
            my $value = $this->{_cgisession}->param($_);
            $session->{prefs}->setInternalPreferences( $_ => $value );
            $this->_trace( "Setting internal preference $_ to "
                  . ( $value ? $value : 'null' ) );
        }

        # May end up doing this several times; but this is the only place
        # if should really need to be done, unless someone allocates a
        # new response object.
        $this->_addSessionCookieToResponse();
    }

    return $authUser;
}

=begin TML

---++ ObjectMethod redirectToLoggedOutUrl($authUser, $defaultUser)

Helper method, called by loadSession, to redirect to the non-authenticated url and return the non-authenticated "default user" login name.

$authUser is the currently logged in user, derived from the request's username.

$defaultUser is a username to use if one is not available from other
sources. The username passed when you create a Foswiki instance is
passed in here.

=cut

sub redirectToLoggedOutUrl {
    my ( $this, $authUser, $defaultUser ) = @_;
    _trace( $this, "User is logging out" );

    my $session = $this->{session};
    $defaultUser = $Foswiki::cfg{DefaultUserLogin}
      unless ( defined($defaultUser) );

    $session->logger->log(
        {
            level  => 'info',
            action => 'logout',
            extra  => "AUTHENTICATION LOGOUT - $authUser - ",
            user   => $authUser
        }
    );

    #TODO: consider if we should risk passing on the urlparams on logout
    my $path_info = Foswiki::urlDecode( $session->{request}->path_info() );
    if ( my $topic = $session->{request}->param('topic') )
    {    #we should at least respect the ?topic= request
        my $topicRequest = Foswiki::Sandbox::untaintUnchecked($topic);
        ( my $web, $topic ) =
          $this->{session}->normalizeWebTopicName( undef, $topicRequest );
        $path_info = '/' . $web . '/' . $topic;
    }

    if ( $path_info =~ m/['"]/ ) {
        $path_info = substr( $path_info, 0, ( ( pos $path_info ) - 1 ) );
    }

    $path_info = Foswiki::urlEncode($path_info);

    my $redirectUrl;
    if ( $Foswiki::cfg{ForceDefaultUrlHost} ) {

        # ForceDefaultUrlHost enabled - probably a reverse proxy.
        $path_info ||= '';
        my $action = $session->{request}->{action} || 'view';
        $redirectUrl = $session->getScriptUrl( '1', $action ) . $path_info;
    }
    elsif ($path_info) {
        $redirectUrl = $session->{request}->url() . $path_info;
    }
    else {
        $redirectUrl = $session->{request}->referer();
    }

    #lets avoid infinite loops
    $session->{request}->delete('logout');
    $authUser = $defaultUser;
    $session->redirect( $redirectUrl, 0 );

    return $authUser;
}

=begin TML

---++ ObjectMethod checkAccess()

Check if the script being run in this session is authorised for execution.
If not, throw an access control exception.

=cut

sub checkAccess {

    return unless ( $Foswiki::cfg{UseClientSessions} );

    my $this    = shift;
    my $session = $this->{session};

    return if $session->inContext('command_line');

    unless ( $session->inContext('authenticated')
        || $Foswiki::cfg{LoginManager} eq 'none' )
    {

        # This checks the *base_action* which is the action in the
        # request *before* any request cache was restored. Otherwise
        # you can end up with an infinite loop - see
        # Foswiki:Development.FoswikiRedirectCache
        my $action = $session->{request}->base_action();

        if ( defined $action && $this->{_authScripts}{$action} ) {
            my $topic = $session->{topicName};
            my $web   = $session->{webName};
            require Foswiki::AccessControlException;
            throw Foswiki::AccessControlException( $action, $session->{user},
                $web, $topic, $action . ' requires authentication' );
        }
    }
}

=begin TML

---++ ObjectMethod complete()

Complete processing after the client's HTTP request has been responded
to. Flush the user's session (if any) to disk.

=cut

sub complete {
    my $this = shift;

    if ( $this->{_cgisession} ) {
        $this->{_cgisession}->flush();
        die $this->{_cgisession}->errstr()
          if $this->{_cgisession}->errstr();
    }

    return unless ( $Foswiki::cfg{Sessions}{ExpireAfter} > 0 );

    expireDeadSessions();
}

=begin TML

---++ StaticMethod expireDeadSessions()

Delete sessions and passthrough files that are sitting around but are really expired.
This *assumes* that the sessions are stored as files.

This is a static method, but requires Foswiki::cfg. It is designed to be
run from a session or from a cron job.

=cut

sub expireDeadSessions {
    return unless $Foswiki::cfg{WorkingDir};

    my $time = time() || 0;
    my $exp = $Foswiki::cfg{Sessions}{ExpireAfter} || 36000;    # 10 hours
    $exp = -$exp if $exp < 0;

    opendir( D, "$Foswiki::cfg{WorkingDir}/tmp" ) || return;
    foreach my $file ( readdir(D) ) {

        # Validate
        next unless $file =~ m/^((passthru|cgisess)_[0-9a-f]{32})$/;
        $file = $1;    # untaint validated file name

        my @stat = stat("$Foswiki::cfg{WorkingDir}/tmp/$file");

        # CGI::Session updates the session file each time a browser views a
        # topic setting the access and expiry time as values in the file. This
        # also sets the mtime (modification time) for the file which is all
        # we need. We know that the expiry time is mtime +
        # $Foswiki::cfg{Sessions}{ExpireAfter} so we do not need to waste
        # execution time opening and reading the file. We just check the
        # mtime. As a fallback we also check ctime. Files are deleted when
        # they expire.
        my $lat = $stat[9] || $stat[10] || 0;
        unlink "$Foswiki::cfg{WorkingDir}/tmp/$file"
          if ( $time - $lat >= $exp );
        next;
    }
    closedir D;
}

=begin TML

---++ ObjectMethod userLoggedIn( $authUser, $wikiname)

Called when the user is known. It's invoked from Foswiki::UI::Register::finish
and from loadSession (above) once credentials are validated.
   1 when the user follows the link in their verification email message
   2 or when the session store is read
   3 when the user authenticates (via templatelogin / sudo)

   * =$authUser= - string login name
   * =$wikiname= - string wikiname

=cut

sub userLoggedIn {
    my ( $this, $authUser, $wikiName ) = @_;

    _trace( $this,
            "userLoggedIn called with "
          . ( $authUser || 'undef' ) . " - "
          . ( $wikiName || 'undef' ) );

    my $session = $this->{session};
    if ( $session->{users} ) {
        $session->{user} = $session->{users}->getCanonicalUserID($authUser);
    }

    if ( $session->inContext('command_line') ) {

        # Command line is automatically 'authenticated' unless the guest user
        # is explicitly requested.  No need for cgi sessions so just return.
        $session->enterContext('authenticated')
          if ( $authUser && $authUser ne $Foswiki::cfg{DefaultUserLogin} );
        _trace( $this,
            'userLoggedIn: CLI Session established for: ' . $authUser );
        return;
    }

    if ( $Foswiki::cfg{UseClientSessions} ) {

        # create new session if necessary
        unless ( $this->{_cgisession} ) {

            _trace( $this,
                "Creating a new client session - _cgisession is empty" );
            $this->{_cgisession} =
              $this->_loadCreateCGISession( $session->{request} );

            die Foswiki::LoginManager::Session->errstr()
              unless $this->{_cgisession};
        }
    }

    my $sessUser = $this->{_cgisession}->param('AUTHUSER')
      || $Foswiki::cfg{DefaultUserLogin};

    _trace( $this, "====   Initial user is $sessUser" );
    _trace( $this,
        "====   Remote user is " . $session->{request}->remoteUser() )
      if defined $session->{request}->remoteUser();

    if ( $authUser && $authUser ne $Foswiki::cfg{DefaultUserLogin} ) {
        _trace( $this,
                'Authenticated; converting from '
              . ( $session->{remoteUser} || $sessUser || 'undef' ) . ' to '
              . $authUser
              . ' - default '
              . $Foswiki::cfg{DefaultUserLogin} );

        # SMELL: right now anyone that makes a template login url can log
        # in multiple times - should i forbid it
        if ( $Foswiki::cfg{UseClientSessions} ) {
            if ( defined( $session->{remoteUser} )
                && $session->inContext('sudo_login') )
            {
                $session->logger->log(
                    {
                        level  => 'info',
                        action => 'sudo login',
                        extra  => 'from ' . ( $session->{remoteUser} || '' ),
                        user   => $authUser
                    }
                );
                $this->{_cgisession}
                  ->param( 'SUDOFROMAUTHUSER', $session->{remoteUser} );
            }

            # SMELL: these are bare logins, so if and when there are
            # multiple usermappings, this would need to include cUID..
            $this->{_cgisession}->param( 'AUTHUSER', $authUser );
        }
        $session->enterContext('authenticated');
    }
    else {
        _trace( $this, "Session is NOT authenticated" );

        # if we are not authenticated, expire any existing session
        $this->{_cgisession}->clear( ['AUTHUSER'] )
          if ( $Foswiki::cfg{UseClientSessions} );
        $session->leaveContext('authenticated');
    }
    if ( $Foswiki::cfg{UseClientSessions} ) {

        # The user has changed.  Create a new session.
        if ( $sessUser ne $authUser ) {

            _trace( $this, "Replace the session $sessUser -> $authUser " );

            my $oldid   = $this->{_cgisession}->id();
            my $dataref = $this->{_cgisession}->dataref();

# SMELL: Needed to both delete and undef the old sesson or for some reason
# Session->new() manages to find / use the old session and the ID doesn't change
            $this->{_cgisession}->delete();
            $this->{_cgisession}->flush();
            $this->{_cgisession} = undef;

            # Don't make a session for the guest user.
            unless ( $authUser eq $Foswiki::cfg{DefaultUserLogin}
                && !$guestSessions
                && !$session->inContext('sessionRequired') )

            {
                $this->{_cgisession} =
                  $this->_loadCreateCGISession( $session->{request} );
                _trace( $this,
                    "Changed SID from $oldid to "
                      . $this->{_cgisession}->id() );
                foreach my $key ( keys %$dataref ) {
                    next if ( substr( $key, 0, 1 ) eq '_' );
                    $this->{_cgisession}->param( $key, $dataref->{$key} );
                    _trace( $this,
                        " - $key = " . ( $dataref->{$key} || 'undef' ) );
                }

            }
        }

        if ( $this->{_cgisession} ) {

            # flush the session, to try to fix Item1820 and Item2234
            $this->{_cgisession}->flush();
            die $this->{_cgisession}->errstr()
              if $this->{_cgisession}->errstr();
        }
    }

    if ( $this->{_cgisession} ) {
        $this->_addSessionCookieToResponse();
        $session->{prefs}->setInternalPreferences(
            SESSIONID  => $this->{_cgisession}->id(),
            SESSIONVAR => $CGI::Session::NAME
        );
    }

}

=begin TML

---++ ObjectMethod _myScriptURLRE ($thisl)

=cut

# get an RE that matches a local script URL
sub _myScriptURLRE {
    my $this = shift;

    my $s = $this->{_MYSCRIPTURL};
    unless ($s) {
        $s = quotemeta( $this->{session}->getScriptUrl( 1, $M1, $M2, $M3 ) );
        $s =~ s@\\$M1@[^/]*?@go;
        $s =~ s@\\$M2@[^/]*?@go;
        $s =~ s@\\$M3@[^#\?/]*@go;

        # now add alternates for the various script-specific overrides
        foreach my $v ( values %{ $Foswiki::cfg{ScriptUrlPaths} } ) {
            my $over = $v;

            # escape non-alphabetics
            $over =~ s/(\W)/\\$1/g;
            $s .= '|' . $over;
        }
        $this->{_MYSCRIPTURL} = "($s)";
    }
    return $s;
}

=begin TML

---++ ObjectMethod _rewriteURL ($this, $url) -> $url

=cut

# Rewrite a URL inserting the session id
sub _rewriteURL {
    my ( $this, $url ) = @_;

    return $url unless $url;

    my $sessionId = $this->{_cgisession}->id();
    return $url unless $sessionId;
    return $url if $url =~ m/\?$Foswiki::LoginManager::Session::NAME=/;

    my $s = _myScriptURLRE($this);

    # If the URL has no colon in it, or it matches the local script
    # URL, it must be an internal URL and therefore needs the session.
    if ( $url !~ /:/ || $url =~ m/^$s/ ) {

        # strip off the anchor
        my $anchor = '';
        if ( $url =~ s/(#.*)// ) {
            $anchor = $1;
        }

        # strip off existing params
        my $params = "?$Foswiki::LoginManager::Session::NAME=$sessionId";

        # implicit untaint is OK because recombined with url later
        if ( $url =~ s/\?(.*)$// ) {
            $params .= ';' . $1;
        }

        # rebuild the URL
        $url .= $params . $anchor;
    }    # otherwise leave it untouched

    return $url;
}

=begin TML

---++ ObjectMethod _rewriteFORM ($thisl)


=cut

# Catch all FORMs and add a hidden Session ID variable.
# Only do this if the form is pointing to an internal link.
# This occurs if there are no colons in its target, if it has
# no target, or if its target matches a getScriptUrl URL.
# '$rest' is the bit of the initial form tag up to the closing >
sub _rewriteFORM {
    my ( $this, $url, $rest ) = @_;

    return $url . $rest unless $this->{_cgisession};

    my $s = _myScriptURLRE($this);

    if ( $url !~ /:/ || $url =~ m/^($s)/ ) {
        $rest .= CGI::hidden(
            -name  => $Foswiki::LoginManager::Session::NAME,
            -value => $this->{_cgisession}->id()
        );
    }
    return $url . $rest;
}

=begin TML

---++ ObjectMethod endRenderingHandler()

This handler is called by getRenderedVersion just before the plugins
postRenderingHandler. So it is passed all HTML text just before it is
printed.

*DEPRECATED* Use postRenderingHandler instead.

=cut

sub endRenderingHandler {
    return unless ( $Foswiki::cfg{UseClientSessions} );

    my $this = shift;
    return if $this->{session}->inContext('command_line');

    # If cookies are not turned on and transparent CGI session IDs are,
    # grab every URL that is an internal link and pass a CGI variable
    # with the session ID
    unless ( $this->{_haveCookie} || !$Foswiki::cfg{Sessions}{IDsInURLs} ) {

        # rewrite internal links to include the transparent session ID
        # Doesn't catch Javascript, because there are just so many ways
        # to generate links from JS.
        # SMELL: this would probably be done better using javascript
        # that handles navigation away from this page, and uses the
        # rules to rewrite any relative URLs at that time.

        # a href= rewriting
        $_[0] =~
s/(<a[^>]*(?<=\s)href=(["']))(.*?)(\2)/$1.$this->_rewriteURL($3).$4/gei;

        # form action= rewriting
        # SMELL: Forms that have no target are also implicit internal
        # links, but are not handled. Does this matter>
        $_[0] =~
s/(<form[^>]*(?<=\s)(?:action)=(["']))(.*?)(\2[^>]*>)/$1._rewriteFORM( $this,$3, $4)/gei;
    }

    # And, finally, the logon stuff
    $_[0] =~ s/%SESSIONLOGON%/_dispLogon( $this )/ge;
    $_[0] =~ s/%SKINSELECT%/_skinSelect( $this )/ge;
}

sub _loadCreateCGISession {
    my $this = shift;
    my $sid  = shift;    #IP, Object  or undef

    _trace( $this, "_loadCreateCGISession called ..." );

    # Item3568: CGI::Session from 4.0 already does the -d and creates the
    # sessions directory if it does not exist. For performance reasons we
    # only test for and create session file directory for older
    # CGI::Session
    my $sessionDir = "$Foswiki::cfg{WorkingDir}/tmp";
    if ( $Foswiki::LoginManager::Session::VERSION < 4.0 ) {
        unless (
            -d $sessionDir
            || (   mkdir( $Foswiki::cfg{WorkingDir} )
                && mkdir($sessionDir) )
          )
        {
            die "Could not create $sessionDir for storing sessions";
        }
    }

    # force an appropriate umask
    my $oldUmask =
      umask(
        oct(777) - ( ( $Foswiki::cfg{Session}{filePermission} + 0 ) ) &
          oct(777) );

    my $newsess;

    $newsess = Foswiki::LoginManager::Session->new(
        CGIDRIVER,
        $sid,
        {
            Directory => $sessionDir,
            UMask     => $Foswiki::cfg{Session}{filePermission}
        }
    );

    # restore old umask
    umask($oldUmask);

    return $newsess;
}

sub _addSessionCookieToResponse {
    my $this = shift;

    my $cookie = CGI::Cookie->new(
        -name     => $Foswiki::LoginManager::Session::NAME,
        -value    => $this->{_cgisession}->id(),
        -path     => '/',
        -domain   => $Foswiki::cfg{Sessions}{CookieRealm} || '',
        -httponly => 1,
        -secure   => $this->{session}->{request}->secure,
    );

    # An expiry time is only set if the session has the REMEMBER variable
    # in it. This is to prevent accidentally remembering cookies with
    # login managers where the authority is cached in the browser and
    # *not* in the session. Otherwise another user might be able to login
    # on the same machine and inherit the authorities of a prior user.
    if (   $Foswiki::cfg{Sessions}{ExpireCookiesAfter}
        && $this->getSessionValue('REMEMBER') )
    {
        require Foswiki::Time;
        my $exp = Foswiki::Time::formatTime(
            time() + $Foswiki::cfg{Sessions}{ExpireCookiesAfter},
            '$wday, $day-$month-$ye $hours:$minutes:$seconds GMT'
        );

        $cookie->expires($exp);
    }

    $this->{session}->{response}->cookies( [$cookie] );
}

sub _delSessionCookieFromResponse {
    my $this = shift;

    _trace( $this, "Session cookie deleted " );

    my $cookie = CGI::Cookie->new(
        -name     => $Foswiki::LoginManager::Session::NAME,
        -value    => '',
        -path     => '/',
        -domain   => $Foswiki::cfg{Sessions}{CookieRealm} || '',
        -httponly => 1,
        -secure   => $this->{session}->{request}->secure,
        -expires  => '-1d'
    );

    $this->{session}->{response}->cookies( [$cookie] );
}

=begin TML

---++ ObjectMethod rewriteRedirectUrl( $url ) ->$url

Rewrite the URL used in a redirect if necessary to include any session
identification. 
   * =$url= - target of the redirection.

=cut

sub rewriteRedirectUrl {

    my ( $this, $url ) = @_;

    return $url unless $this->{_cgisession};

    if ( $Foswiki::cfg{Sessions}{IDsInURLs} && !$this->{_haveCookie} ) {
        $url = _rewriteURL( $this, $url );
    }

    # This usually won't be important, but just in case they haven't
    # yet received the cookie and happen to be redirecting, be sure
    # they do have the cookie.
    $this->_addSessionCookieToResponse();

    return $url;
}

=begin TML

---++ ObjectMethod getSessionValues() -> \%values

Get a name->value hash of all the defined session variables

=cut

sub getSessionValues {
    my ($this) = @_;

    return unless $this->{_cgisession};

    return $this->{_cgisession}->param_hashref();
}

=begin TML

---++ ObjectMethod getCGISession()
Get the currect CGI session object

=cut

sub getCGISession {
    my $this = shift;
    return $this->{_cgisession};
}

=begin TML

---++ ObjectMethod getSessionValue( $name ) -> $value

Get the value of a session variable.

=cut

sub getSessionValue {
    my ( $this, $key ) = @_;
    return unless $this->{_cgisession};

    return $this->{_cgisession}->param($key);
}

=begin TML

---++ ObjectMethod setSessionValue( $name, $value )

Set the value of a session variable.

=cut

sub setSessionValue {
    my ( $this, $key, $value ) = @_;

    if ( $this->{_cgisession}
        && defined( $this->{_cgisession}->param( $key, $value ) ) )
    {
        return 1;
    }

    return;
}

=begin TML

---++ ObjectMethod clearSessionValue( $name ) -> $boolean

Clear the value of a session variable.
We do not allow setting of AUTHUSER.

=cut

sub clearSessionValue {
    my ( $this, $key ) = @_;

    # We do not allow clearing of AUTHUSER.
    if (   $this->{_cgisession}
        && $key ne 'AUTHUSER'
        && defined( $this->{_cgisession}->param($key) ) )
    {
        $this->{_cgisession}->clear( [ $_[1] ] );

        return 1;
    }

    return;
}

=begin TML

---++ ObjectMethod forceAuthentication() -> boolean

*VIRTUAL METHOD* implemented by subclasses

Triggered by an access control violation, this method tests
to see if the current session is authenticated or not. If not,
it does whatever is needed so that the user can log in, and returns 1.

If the user has an existing authenticated session, the function simply drops
though and returns 0.

=cut

sub forceAuthentication {
    return 0;
}

=begin TML

---++ ObjectMethod loginUrl( ... ) -> $url

*VIRTUAL METHOD* implemented by subclasses

Return a full URL suitable for logging in.
   * =...= - url parameters to be added to the URL, in the format required by Foswiki::getScriptUrl()

=cut

sub loginUrl {
    return '';
}

=begin TML

---++ ObjectMethod getUser()

Should be implemented by subclasses

If there is some other means of getting a username - for example,
Apache has remote_user() - then return it. Otherwise, return undef and
the username stored in the session will be used.

This method of getting the user *assumes* that the identified user
has been authenticated in some way (for example, by the web server)

=cut

sub getUser {
    return;
}

=begin TML

---++ ObjectMethod isValidLoginName( $name ) -> $boolean

Check for a valid login name (not an existance check, just syntax).
Default behaviour is to check the login name against
$Foswiki::cfg{LoginNameFilterIn}

=cut

sub isValidLoginName {
    my ( $this, $name ) = @_;

    # this function was erroneously marked as static
    ASSERT( !ref($name) ) if DEBUG;
    return $name =~ m/$Foswiki::cfg{LoginNameFilterIn}/;
}

=begin TML

---++ ObjectMethod _LOGIN ($thisl)


=cut

sub _LOGIN {

    #my( $session, $params, $topic, $web ) = @_;
    my $session = shift;
    my $this    = $session->getLoginManager();

    return '' if $session->inContext('authenticated');

    my $url = $this->loginUrl();
    if ($url) {
        my $text = $session->templates->expandTemplate('LOG_IN');
        return CGI::a( { href => $url }, $text );
    }
    return '';
}

=begin TML

---++ ObjectMethod _LOGOUTURL ($thisl)


=cut

sub _LOGOUTURL {
    my ( $session, $params, $topic, $web ) = @_;
    my $this = $session->getLoginManager();

    return $session->getScriptUrl(
        0, 'view',
        $session->{prefs}->getPreference('BASEWEB'),
        $session->{prefs}->getPreference('BASETOPIC'),
        'logout' => 1
    );
}

=begin TML

---++ ObjectMethod _LOGOUT ($thisl)


=cut

sub _LOGOUT {
    my ( $session, $params, $topic, $web ) = @_;
    my $this = $session->getLoginManager();

    return '' unless $session->inContext('authenticated');

    my $url = _LOGOUTURL(@_);
    if ($url) {
        my $text = $session->templates->expandTemplate('LOG_OUT');
        return CGI::a( { href => $url }, $text );
    }
    return '';
}

=begin TML

---++ ObjectMethod _AUTHENTICATED ($thisl)


=cut

sub _AUTHENTICATED {
    my ( $session, $params ) = @_;
    my $this = $session->getLoginManager();

    if ( $session->inContext('authenticated') ) {
        return $params->{then} || 1;
    }
    else {
        return $params->{else} || 0;
    }
}

=begin TML

---++ ObjectMethod _CANLOGIN ($thisl)

=cut

sub _CANLOGIN {
    my ( $session, $params ) = @_;
    my $this = $session->getLoginManager();
    if ( $session->inContext('can_login') ) {
        return $params->{then} || 1;
    }
    else {
        return $params->{else} || 0;
    }
}

=begin TML

---++ ObjectMethod _SESSION_VARIABLE ($thisl)

=cut

sub _SESSION_VARIABLE {
    my ( $session, $params ) = @_;
    my $this = $session->getLoginManager();
    my $name = $params->{_DEFAULT};

    if ( defined $name ) {
        if ( defined( $params->{set} ) ) {
            unless ( $readOnlySK{$name} ) {
                $this->setSessionValue( $name, $params->{set} );
            }
        }
        elsif ( defined( $params->{clear} ) ) {
            unless ( $readOnlySK{$name} ) {
                $this->clearSessionValue($name);
            }
        }
        elsif ( !$secretSK{$name} ) {
            my $val = $this->getSessionValue($name);
            $val = '' unless defined $val;
            return $val;
        }
    }
    return '';
}

=begin TML

---++ ObjectMethod _LOGINURL ($thisl)

=cut

sub _LOGINURL {
    my ( $session, $params ) = @_;
    my $this = $session->{users}->getLoginManager();
    return $this->loginUrl();
}

=begin TML

---++ ObjectMethod _dispLogon ($thisl)

=cut

sub _dispLogon {
    my $this = shift;

    return '' unless $this->{_cgisession};

    my $session   = $this->{session};
    my $topic     = $session->{topicName};
    my $web       = $session->{webName};
    my $sessionId = $this->{_cgisession}->id();

    my $urlToUse = $this->loginUrl();

    unless ( $this->{_haveCookie} || !$Foswiki::cfg{Sessions}{IDsInURLs} ) {
        $urlToUse = _rewriteURL( $this, $urlToUse );
    }

    my $text = $session->templates->expandTemplate('LOG_IN');
    return CGI::a( { class => 'foswikiAlert', href => $urlToUse }, $text );
}

=begin TML

---++ PrivateMethod _skinSelect ()

Internal use only
TODO: what does it do?

=cut

sub _skinSelect {
    my $this    = shift;
    my $session = $this->{session};
    my $skins   = $session->{prefs}->getPreference('SKINS');
    my $skin    = $session->getSkin();
    my @skins   = split( /,/, $skins );
    unshift( @skins, 'default' );
    my $options = '';
    foreach my $askin (@skins) {
        $askin =~ s/\s//g;
        if ( $askin eq $skin ) {
            $options .=
              CGI::option( { selected => 'selected', name => $askin }, $askin );
        }
        else {
            $options .= CGI::option( { name => $askin }, $askin );
        }
    }
    return CGI::Select( { name => 'stickskin' }, $options );
}

=begin TML

---++ StaticMethod removeUserSessions()

Delete session files for a user that is being removed from the system.
Removing the Session prevents any further damage from a spammer when the
account has been removed.

This is a static method, but requires Foswiki::cfg. It is designed to be
run from a session.

=cut

sub removeUserSessions {
    my $user = shift;
    ASSERT($user) if DEBUG;

    my $msg = '';
    CGI::Session->find(
        CGIDRIVER,
        sub { purge_user( @_, $user, $msg ) },
        {
            Directory => "$Foswiki::cfg{WorkingDir}/tmp",
            UMask     => $Foswiki::cfg{Session}{filePermission},
        }
    );

    sub purge_user {

        #my ($session, $user, $msg) = @_;
        next if $_[0]->is_empty;    # <-- already expired?!
        if ( $_[0]->param('AUTHUSER') && $_[0]->param('AUTHUSER') eq $_[1] ) {
            $_[2] .= 'cgisess_' . $_[0]->id() . ',';
            $_[0]->delete();
            $_[0]->flush()
              ;    # Recommended practice says use flush() after delete().
        }
    }
    return $msg;
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2015 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:
Copyright (C) 2005-2007 TWiki Contributors.
Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
Copyright (C) 2005 Garage Games
Copyright (C) 2005 Crawford Currie http://c-dot.co.uk
Copyright (C) 2005 Greg Abbas, twiki@abbas.org

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
