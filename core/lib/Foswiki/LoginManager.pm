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
$Foswiki::cfg{Trace}{LoginManager.pm}. The tracing is done in such a way as to
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
   1 reads the FOSWIKISID cookie to get the SID (or the FOSWIKISID parameters in the CGI query if cookies aren't available, or IP2SID mapping if that's enabled).
   1 Creates the CGI::Session object, and the session is thereby read.
   1 If the username still isn't known, reads it from the cookie. Thus Foswiki::LoginManager::ApacheLogin overrides the cookie using REMOTE_USER, and Foswiki::LoginManager::TemplateLogin *always* uses the session.

Later again in Foswiki::new, plugins are given a chance to *override* the username found from the loginManager.

The last step in Foswiki::new is to find the user, using whatever user mapping manager is in place.

---++ ObjectData =twiki=

The Foswiki object this login manager is attached to.

=cut

package Foswiki::LoginManager;

use strict;
use Assert;
use Error qw( :try );

require Foswiki::Sandbox;

# Marker chars
use vars qw( $M1 $M2 $M3 );
$M1 = chr(5);
$M2 = chr(6);
$M3 = chr(7);

# Some session keys are secret (not to be given to the browser) and
# others read only (not to be changed from the browser)
our %secretSK   = ( STRIKEONESECRET => 1, VALID_ACTIONS => 1 );
our %readOnlySK = ( %secretSK, AUTHUSER => 1, SUDOFROMAUTHUSER => 1 );

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

        my $use = 'use Foswiki::LoginManager::Session';
        if ( $Foswiki::cfg{Sessions}{UseIPMatching} ) {
            $use .= ' qw(-ip_match)';
        }
        $use .= '; use CGI::Cookie';
        eval $use;
        throw Error::Simple($@) if $@;
        if ( $Foswiki::LoginManager::Session::VERSION eq "4.10" ) {

            # 4.10 is broken; see Item1989
            $Foswiki::LoginManager::Session::NAME = 'FOSWIKISID';
        }
        else {
            Foswiki::LoginManager::Session->name('FOSWIKISID');
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
            session => $session,
            twiki   => $session,    # backwards compatibility
        },
        $class
    );

    $session->leaveContext('can_login');
    $this->{_cookies} = [];
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
    undef $this->{_cookies};
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
    my $id = 'Session'
      . ( $this->{_cgisession} ? $this->{_cgisession}->id() : 'unknown' );
    $id .= '(c)' if $this->{_haveCookie};
    print STDERR "$id: $mess\n";
}

if ( $Foswiki::cfg{Trace}{LoginManager} ) {
    *_trace = \&_real_trace;
}
else {
    *_trace = sub { undef };
}

=begin TML

---++ ClassMethod _IP2SID ($session, $impl)

 read/write IP to SID map, return SID

=cut

# TSA: Forced to make this a object method
sub _IP2SID {
    my ( $this, $sid ) = @_;

    my $ip = $this->{session}->{request}->address;

    return undef unless $ip;    # no IP address, can't map

    my %ips;
    if ( open( IPMAP, '<', $Foswiki::cfg{WorkingDir} . '/tmp/ip2sid' ) ) {
        local $/ = undef;
        %ips = map { split( /:/, $_ ) } split( /\r?\n/, <IPMAP> );
        close(IPMAP);
    }
    if ($sid) {

        # known SID, map the IP addr to it
        $ips{$ip} = $sid;
        open( IPMAP, '>', $Foswiki::cfg{WorkingDir} . '/tmp/ip2sid' )
          || die
"Failed to open ip2sid map for write. Ask your administrator to make sure that the {Sessions}{Dir} is writable by the webserver user.";
        print IPMAP map { "$_:$ips{$_}\n" } keys %ips;
        close(IPMAP);
    }
    else {

        # Return the SID for this IP address
        $sid = $ips{$ip};
    }
    return $sid;
}

=begin TML

---++ ObjectMethod loadSession($defaultUser) -> $login

Get the client session data, using the cookie and/or the request URL.
Set up appropriate session variables in the twiki object and return
the login name.

$defaultUser is a username to use if one is not available from other
sources. The username passed when you create a Foswiki instance is
passed in here.

=cut

sub loadSession {
    my ( $this, $defaultUser ) = @_;
    my $session = $this->{session};

    # Try and get the user from the webserver
    my $authUser = $this->getUser($this) || $defaultUser;

    #this allows the session to over-ride apache_auth (useful for sudo)
    unless ( $Foswiki::cfg{UseClientSessions} ) {
        $this->userLoggedIn($authUser) if $authUser;
        return $authUser;
    }

    return $session->{request}->{remote_user} || $authUser
      if $session->inContext('command_line');

    my $query = $session->{request};

    $this->{_haveCookie} = $query->header('Cookie');

    _trace( $this, "URL " . $query->url() );
    if ( $this->{_haveCookie} ) {
        _trace( $this, "Cookie " . $this->{_haveCookie} );
    }
    else {
        _trace( $this, "No cookie " );
    }

    # Item3568: CGI::Session from 4.0 already does the -d and creates the
    # sessions directory if it does not exist. For performance reasons we
    # only test for and create session file directory for older CGI::Session
    if ( $Foswiki::LoginManager::Session::VERSION < 4.0 ) {
        unless ( -d "$Foswiki::cfg{WorkingDir}/tmp" ) {
            unless ( mkdir( $Foswiki::cfg{WorkingDir} )
                && mkdir("$Foswiki::cfg{WorkingDir}/tmp") )
            {
                die
"Could not create $Foswiki::cfg{WorkingDir}/tmp for session files";
            }
        }
    }

    # First, see if there is a cookied session, creating a new session
    # if necessary.
    if ( $Foswiki::cfg{Sessions}{MapIP2SID} ) {

        # map the end user IP address to SID
        my $sid = $this->_IP2SID();
        if ($sid) {
            $this->{_cgisession} =
              Foswiki::LoginManager::Session->new( undef, $sid,
                { Directory => "$Foswiki::cfg{WorkingDir}/tmp" } );
        }
        else {
            $this->{_cgisession} =
              Foswiki::LoginManager::Session->new( undef, undef,
                { Directory => "$Foswiki::cfg{WorkingDir}/tmp" } );
            _trace( $this, "New IP2SID session" );
            $this->_IP2SID( $this->{_cgisession}->id() );
        }
    }
    else {
        $this->{_cgisession} =
          Foswiki::LoginManager::Session->new( undef, $query,
            { Directory => "$Foswiki::cfg{WorkingDir}/tmp" } );
    }

    die Foswiki::LoginManager::Session->errstr() unless $this->{_cgisession};
    _trace( $this, "Opened session" );

    _trace( $this, "Webserver says user is $authUser" ) if ($authUser);

    # SMELL: is there any way to get evil data into the CGI session such
    # that this untaint is less than safe?
    my $sessionUser = Foswiki::Sandbox::untaintUnchecked(
        $this->{_cgisession}->param('AUTHUSER') );
    _trace( $this, "session says user is " . ( $sessionUser || 'undef' ) );
    if (   ( !defined($authUser) )
        || ( $sessionUser && $sessionUser eq $Foswiki::cfg{AdminUserLogin} ) )
    {
        $authUser = $sessionUser;

        #_trace($this, "session set to $authUser");
    }

    # if we couldn't get the login manager or the http session to tell
    # us who the user is, then let's use the CGI "remote user"
    # variable (which may have been set manually by a unit test,
    # or it might have come from Apache).
    if ($authUser) {
        # SMELL: is there any way to get evil data into the CGI session such
        # that this untaint is less than safe?
        my $cUID = Foswiki::Sandbox::untaintUnchecked(
            $this->{_cgisession}->param('cUID') )
          || '';
        _trace( $this, "Session says user is $authUser - $cUID" );
    }
    else {

        # Use remote user provided from "new Foswiki" call. This is mainly
        # for testing.
        $authUser = $defaultUser;
        _trace( $this, "Foswiki object says user is $authUser" ) if $authUser;
    }

    $authUser ||= $defaultUser;

    # is this a logout?
    if (   ( $authUser && $authUser ne $Foswiki::cfg{DefaultUserLogin} )
        && ( $query && $query->param('logout') ) )
    {
        # SMELL: is there any way to get evil data into the CGI session such
        # that this untaint is less than safe?
        my $sudoUser = Foswiki::Sandbox::untaintUnchecked(
            $this->{_cgisession}->param('SUDOFROMAUTHUSER') );

        if ($sudoUser) {
            _trace( $this, "User is logging out to $sudoUser" );
            $session->logEvent('sudo logout', '',
                'from ' . ( $authUser || '' ), $sudoUser );
            $this->{_cgisession}->clear('SUDOFROMAUTHUSER');
            $authUser = $sudoUser;
        }
        else {
            _trace( $this, "User is logging out" );

            #TODO: consider if we should risk passing on the urlparams on logout
            my $path_info = $query->path_info();
            if (my $topic = $query->param('topic')) {   #we should at least respect the ?topic= request
                my $topicRequest = Foswiki::Sandbox::untaintUnchecked($query->param('topic'));
                my ($web, $topic) = $this->{session}->normalizeWebTopicName(undef, $topicRequest);
                $path_info = '/'.$web.'/'.$topic;
            }

            my $redirectUrl;
            if ($path_info) {
                $redirectUrl = $query->url() . $path_info;
            } else {
                $redirectUrl = $query->referer();
            }

            $query->delete('logout');    #lets avoid infinite loops
            $this->redirectCgiQuery( $query, $redirectUrl );
            $authUser = undef;
        }
    }
    $query->delete('logout');
    $this->userLoggedIn($authUser);

    $session->{SESSION_TAGS}{SESSIONID} = $this->{_cgisession}->id();
    $session->{SESSION_TAGS}{SESSIONVAR} =
      $Foswiki::LoginManager::Session::NAME;

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

    return undef if $session->inContext('command_line');

    unless ( $session->inContext('authenticated')
        || $Foswiki::cfg{LoginManager} eq 'none' )
    {
        my $script = $session->{request}->action;

        if ( defined $script && $this->{_authScripts}{$script} ) {
            my $topic = $session->{topicName};
            my $web   = $session->{webName};
            require Foswiki::AccessControlException;
            throw Foswiki::AccessControlException( $script, $session->{user},
                $web, $topic, 'authentication required' );
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
        _trace( $this, "Flushed" );
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
    my $time = time() || 0;
    my $exp = $Foswiki::cfg{Sessions}{ExpireAfter} || 36000;    # 10 hours
    $exp = -$exp if $exp < 0;

    opendir( D, "$Foswiki::cfg{WorkingDir}/tmp" ) || return;
    foreach my $file ( readdir(D) ) {
        # Validate
        next unless $file =~ /^((passthru|cgisess)_[0-9a-f]{32})$/;
        $file = $1; # untaint validated file name

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
        unlink "$Foswiki::cfg{WorkingDir}/tmp/$file" if ( $time - $lat >= $exp );
        next;
    }
    closedir D;
}

=begin TML

---++ ObjectMethod userLoggedIn( $login, $wikiname)

Called when the user is known. It's invoked from Foswiki::UI::Register::finish
for instance,
   1 when the user follows the link in their verification email message
   2 or when the session store is read
   3 when the user authenticates (via templatelogin / sudo)
   
   * =$login= - string login name
   * =$wikiname= - string wikiname

=cut

sub userLoggedIn {
    my ( $this, $authUser, $wikiName ) = @_;

    my $session = $this->{session};
    if ($session->{users}) {
        $session->{user} = $session->{users}->getCanonicalUserID($authUser);
    }
    return undef if $session->inContext('command_line');

    if ( $Foswiki::cfg{UseClientSessions} ) {

        # create new session if necessary
        unless ( $this->{_cgisession} ) {
            $this->{_cgisession} =
              Foswiki::LoginManager::Session->new( undef, $session->{request},
                { Directory => "$Foswiki::cfg{WorkingDir}/tmp" } );
            die Foswiki::LoginManager::Session->errstr()
              unless $this->{_cgisession};
        }
    }
    if ( $authUser && $authUser ne $Foswiki::cfg{DefaultUserLogin} ) {
        _trace( $this, "Session is authenticated" );
        _trace( $this,
                'converting from '
              . ( $session->{remoteUser} || 'undef' ) . ' to '
              . $authUser );

#TODO: right now anyone that makes a template login url can log in multiple times - should i forbid it
        if ( $Foswiki::cfg{UseClientSessions} ) {
            if ( defined( $session->{remoteUser} )
                && $session->inContext('sudo_login') )
            {
                $session->logEvent('sudo login', '',
                    'from ' . ( $session->{remoteUser} || '' ), $authUser );
                $this->{_cgisession}
                  ->param( 'SUDOFROMAUTHUSER', $session->{remoteUser} );
            }

#TODO: these are bare login's, so if and when there are multiple usermappings, this would need to include cUID..
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

        # flush the session, to try to fix Item1820 and Item2234
        $this->{_cgisession}->flush();
        die $this->{_cgisession}->errstr() if $this->{_cgisession}->errstr();
        _trace( $this, "Flushed" );
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

---++ ObjectMethod _rewriteURL ($thisl)


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
    if ( $url !~ /:/ || $url =~ /^$s/ ) {

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

    if ( $url !~ /:/ || $url =~ /^($s)/ ) {
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
    return undef if $this->{session}->inContext('command_line');

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
s/(<a[^>]*(?<=\s)href=(["']))(.*?)(\2)/$1._rewriteURL( $this,$3).$4/geoi;

        # form action= rewriting
        # SMELL: Forms that have no target are also implicit internal
        # links, but are not handled. Does this matter>
        $_[0] =~
s/(<form[^>]*(?<=\s)(?:action)=(["']))(.*?)(\2[^>]*>)/$1._rewriteFORM( $this,$3, $4)/geoi;
    }

    # And, finally, the logon stuff
    $_[0] =~ s/%SESSIONLOGON%/_dispLogon( $this )/geo;
    $_[0] =~ s/%SKINSELECT%/_skinSelect( $this )/geo;
}

=begin TML

---++ ObjectMethod _pushCookie ($thisl)


=cut

# Push the standard cookie
sub _pushCookie {
    my $this = shift;

    my $cookie = CGI::Cookie->new(
        -name  => $Foswiki::LoginManager::Session::NAME,
        -value => $this->{_cgisession}->id(),
        -path  => '/',
        -httponly => 1
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

    $this->addCookie($cookie);
}

=begin TML

---++ ObjectMethod addCookie($c)

Add a cookie to the list of cookies for this session.
   * =$c= - a CGI::Cookie

=cut

sub addCookie {
    return unless ( $Foswiki::cfg{UseClientSessions} );

    my ( $this, $c ) = @_;
    return undef if $this->{session}->inContext('command_line');
    ASSERT( $c->isa('CGI::Cookie') ) if DEBUG;

    push( @{ $this->{_cookies} }, $c );
}

=begin TML

---++ ObjectMethod modifyHeader( \%header )

Modify a HTTP header
   * =\%header= - header entries

=cut

sub modifyHeader {
    my ( $this, $hopts ) = @_;

    return unless $this->{_cgisession};
    return if $Foswiki::cfg{Sessions}{MapIP2SID};

    my $response = $this->{session}->{response};
    _pushCookie($this);
    $response->cookies( $this->{_cookies} );
}

=begin TML

---++ ObjectMethod redirectCgiQuery( $url )

Generate an HTTP redirect on STDOUT, if you can. Return 1 if you did.
   * =$url= - target of the redirection.

=cut

# TSA SMELL: better to rename this...
sub redirectCgiQuery {

    my ( $this, $query, $url ) = @_;

    if ( $this->{_cgisession} ) {
        $url = _rewriteURL( $this, $url )
          unless ( !$Foswiki::cfg{Sessions}{IDsInURLs}
            || $this->{_haveCookie} );

        # This usually won't be important, but just in case they haven't
        # yet received the cookie and happen to be redirecting, be sure
        # they have the cookie. (this is a lot more important with
        # transparent CGI session IDs, because the session DIES when those
        # people go across a redirect without a ?CGISESSID= in it... But
        # EVEN in that case, they should be redirecting to a URL that
        # already *HAS* a sessionID in it... Maybe...)
        #
        # So this is just a big fat precaution, just like the rest of this
        # whole handler.
        _pushCookie($this);
    }

    if ( $Foswiki::cfg{Sessions}{MapIP2SID} ) {
        _trace( $this, "Redirect to $url WITHOUT cookie" );
        $this->{session}->{response}->redirect( -url => $url );
    }
    else {
        _trace( $this, "Redirect to $url with cookie" );
        $this->{session}->{response}
          ->redirect( -url => $url, -cookie => $this->{_cookies} );
    }

    return 1;
}

=begin TML

---++ ObjectMethod getSessionValues() -> \%values

Get a name->value hash of all the defined session variables

=cut

sub getSessionValues {
    my ($this) = @_;

    return undef unless $this->{_cgisession};

    return $this->{_cgisession}->param_hashref();
}

=begin TML

---++ ObjectMethod getSessionValue( $name ) -> $value

Get the value of a session variable.

=cut

sub getSessionValue {
    my ( $this, $key ) = @_;
    return undef unless $this->{_cgisession};

    return $this->{_cgisession}->param($key);
}

=begin TML

---++ ObjectMethod setSessionValue( $name, $value )

Set the value of a session variable.

=cut

sub setSessionValue {
    my ( $this, $key, $value ) = @_;

    if ( $this->{_cgisession}
           && defined( $this->{_cgisession}->param( $key, $value ) ) ) {
        return 1;
    }

    return undef;
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

    return undef;
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

*VIRTUAL METHOD* implemented by subclasses

If there is some other means of getting a username - for example,
Apache has remote_user() - then return it. Otherwise, return undef and
the username stored in the session will be used.

=cut

sub getUser {
    return undef;
}

=begin TML

---++ ObjectMethod isValidLoginName( $name ) -> $boolean

Check for a valid login name (not an existance check, just syntax).
Default behaviour is to check the login name against
$Foswiki::cfg{LoginNameFilterIn}

=cut

sub isValidLoginName {
    my ($this, $name) = @_;
    # this function was erroneously marked as static
    ASSERT(! ref($name) ) if DEBUG;

    return $name =~ /$Foswiki::cfg{LoginNameFilterIn}/;
}

=begin TML

---++ ObjectMethod _LOGIN ($thisl)


=cut

sub _LOGIN {

    #my( $session, $params, $topic, $web ) = @_;
    my $session = shift;
    my $this    = $session->{users}->{loginManager};

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
    my $this = $session->{users}->{loginManager};

    return $session->getScriptUrl(
        0, 'view',
        $session->{SESSION_TAGS}{BASEWEB},
        $session->{SESSION_TAGS}{BASETOPIC},
        'logout' => 1
    );
}

=begin TML

---++ ObjectMethod _LOGOUT ($thisl)


=cut

sub _LOGOUT {
    my ( $session, $params, $topic, $web ) = @_;
    my $this = $session->{users}->{loginManager};

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
    my $this = $session->{users}->{loginManager};

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
    my $this = $session->{users}->{loginManager};
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
    my $this = $session->{users}->{loginManager};
    my $name = $params->{_DEFAULT};

    if (defined $name) {
        if ( defined( $params->{set} ) ) {
            unless( $readOnlySK{$name} ) {
                $this->setSessionValue( $name, $params->{set} );
            }
        }
        elsif ( defined( $params->{clear} ) ) {
            unless( $readOnlySK{$name} ) {
                $this->clearSessionValue($name);
            }
        }
        elsif ( !$secretSK{$name} ) {
            return $this->getSessionValue($name) || '';
        }
    }
    return '';
}

=begin TML

---++ ObjectMethod _LOGINURL ($thisl)


=cut

sub _LOGINURL {
    my ( $session, $params ) = @_;
    my $this = $session->{users}->{loginManager};
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
    my $skins   = $session->{prefs}->getPreferencesValue('SKINS');
    my $skin    = $session->getSkin();
    my @skins   = split( /,/, $skins );
    unshift( @skins, 'default' );
    my $options = '';
    foreach my $askin (@skins) {
        $askin =~ s/\s//go;
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
# Copyright (C) 2005-2007 TWiki Contributors.
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2005 Garage Games
# Copyright (C) 2005 Crawford Currie http://c-dot.co.uk
# Copyright (C) 2005 Greg Abbas, twiki@abbas.org
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
