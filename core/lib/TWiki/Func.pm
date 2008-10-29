# See bottom of file for license and copyright information

=pod

---+ package TWiki::Func

<!-- STARTINCLUDE required for huge TWikiDocumentation topic -->
%STARTINCLUDE%

_Official list of stable TWiki functions for Plugin developers_

This module defines official functions that [[%SYSTEMWEB%.TWikiPlugins][Plugins]]
can use to interact with the TWiki engine and content.

Refer to TWiki.EmptyPlugin and lib/TWiki/Plugins/EmptyPlugin.pm for a template Plugin and documentation on how to write a Plugin.

Plugins should *only* use functions published in this module. If you use
functions in other TWiki libraries you might create a security hole and
you will probably need to change your Plugin when you upgrade TWiki.

Deprecated functions will still work in older code, though they should
_not_ be called in new Plugins and should be replaced in older Plugins
as soon as possible.

The version of the TWiki::Func module is defined by the VERSION number of the
TWiki::Plugins module, currently %PLUGINVERSION%. This can be shown
by the =%<nop>PLUGINVERSION%= TWiki variable, and accessed in code using
=$TWiki::Plugins::VERSION=. The 'Since' field in the function
documentation refers to =$TWiki::Plugins::VERSION=.

Notes on use of =$TWiki::Plugins::VERSION= (from 1.2 forwards):
   * If the *major* version (e.g. =1.=) is the same then any plugin coded
     to use any *earlier* revision of the =1.= API will still work. No
     function has been removed from the interface, nor has any API published
     in that version changed in such a way as to *require* plugins to be
     recoded.
   * If the *minor* version (e.g. 1.1) is incremented there may be changes
     in the API that may help improve the coding of some plugins - for
     example, new interfaces giving access to previously hidden core functions.
     In addition, *deprecation* of functions in the interface trigger a minor
     version increment. Note that deprecated functions are not _removed_, they
     are merely frozen, and plugin authors are recommended to stop using them.
   * Any additional digits in the version number relate to minor changes, such
     as the addition of parameters to the existing functions, or addition of
     utility functions that are unlikely to require significant changes to
     existing plugins.
   * =TWiki::Plugins::VERSION= also applies to the plugin handlers. The
     handlers are documented in the !EmptyPlugin, and that module indicates
     what version of =TWiki::Plugins::VERSION= it relates to.
A full history of the changes to this API can be found at the end of this
topic.

=cut

package TWiki::Func;

use strict;
use Error qw( :try );
use Assert;

require TWiki;
require TWiki::Plugins;

=pod

---++ Environment

=cut

=pod

---+++ getSkin( ) -> $skin

Get the skin path, set by the =SKIN= and =COVER= preferences variables or the =skin= and =cover= CGI parameters

Return: =$skin= Comma-separated list of skins, e.g. ='gnu,tartan'=. Empty string if none.

*Since:* TWiki::Plugins::VERSION 1.000 (29 Jul 2001)

=cut

sub getSkin {
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;

    return $TWiki::Plugins::SESSION->getSkin();
}

=pod

---+++ getUrlHost( ) -> $host

Get protocol, domain and optional port of script URL

Return: =$host= URL host, e.g. ="http://example.com:80"=

*Since:* TWiki::Plugins::VERSION 1.000 (7 Dec 2002)

=cut

sub getUrlHost {
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;

    return $TWiki::Plugins::SESSION->{urlHost};
}

=pod

---+++ getScriptUrl( $web, $topic, $script, ... ) -> $url

Compose fully qualified URL
   * =$web=    - Web name, e.g. ='Main'=
   * =$topic=  - Topic name, e.g. ='WebNotify'=
   * =$script= - Script name, e.g. ='view'=
   * =...= - an arbitrary number of name=>value parameter pairs that will be url-encoded and added to the url. The special parameter name '#' is reserved for specifying an anchor. e.g. <tt>getScriptUrl('x','y','view','#'=>'XXX',a=>1,b=>2)</tt> will give <tt>.../view/x/y?a=1&b=2#XXX</tt>

Return: =$url=       URL, e.g. ="http://example.com:80/cgi-bin/view.pl/Main/WebNotify"=

*Since:* TWiki::Plugins::VERSION 1.000 (7 Dec 2002)

=cut

sub getScriptUrl {
    my $web = shift;
    my $topic = shift;
    my $script = shift;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;

    return $TWiki::Plugins::SESSION->getScriptUrl( 1, $script, $web, $topic, @_ );
}

=pod

---+++ getViewUrl( $web, $topic ) -> $url

Compose fully qualified view URL
   * =$web=   - Web name, e.g. ='Main'=. The current web is taken if empty
   * =$topic= - Topic name, e.g. ='WebNotify'=
Return: =$url=      URL, e.g. ="http://example.com:80/cgi-bin/view.pl/Main/WebNotify"=

*Since:* TWiki::Plugins::VERSION 1.000 (7 Dec 2002)

=cut

sub getViewUrl {
    my( $web, $topic ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;

    $web ||= $TWiki::Plugins::SESSION->{webName} || $TWiki::cfg{UsersWebName};
    return getScriptUrl( $web, $topic, 'view' );
}

=pod

---+++ getPubUrlPath( ) -> $path

Get pub URL path

Return: =$path= URL path of pub directory, e.g. ="/pub"=

*Since:* TWiki::Plugins::VERSION 1.000 (14 Jul 2001)

=cut

sub getPubUrlPath {
    return $TWiki::cfg{PubUrlPath};
}

=pod

---+++ getExternalResource( $url ) -> $response

Get whatever is at the other end of a URL (using an HTTP GET request). Will
only work for encrypted protocols such as =https= if the =LWP= CPAN module is
installed.

Note that the =$url= may have an optional user and password, as specified by
the relevant RFC. Any proxy set in =configure= is honoured.

The =$response= is an object that is known to implement the following subset of
the methods of =LWP::Response=. It may in fact be an =LWP::Response= object,
but it may also not be if =LWP= is not available, so callers may only assume
the following subset of methods is available:
| =code()= |
| =message()= |
| =header($field)= |
| =content()= |
| =is_error()= |
| =is_redirect()= |

Note that if LWP is *not* available, this function:
   1 can only really be trusted for HTTP/1.0 urls. If HTTP/1.1 or another
     protocol is required, you are *strongly* recommended to =require LWP=.
   1 Will not parse multipart content

In the event of the server returning an error, then =is_error()= will return
true, =code()= will return a valid HTTP status code
as specified in RFC 2616 and RFC 2518, and =message()= will return the
message that was received from
the server. In the event of a client-side error (e.g. an unparseable URL)
then =is_error()= will return true and =message()= will return an explanatory
message. =code()= will return 400 (BAD REQUEST).

Note: Callers can easily check the availability of other HTTP::Response methods
as follows:

<verbatim>
my $response = TWiki::Func::getExternalResource($url);
if (!$response->is_error() && $response->isa('HTTP::Response')) {
    ... other methods of HTTP::Response may be called
} else {
    ... only the methods listed above may be called
}
</verbatim>

*Since:* TWiki::Plugins::VERSION 1.2

=cut

sub getExternalResource {
    my( $url ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    ASSERT(defined $url) if DEBUG;

    return $TWiki::Plugins::SESSION->net->getExternalResource( $url );
}

=pod

---+++ getCgiQuery( ) -> $query

Get CGI query object. Important: Plugins cannot assume that scripts run under CGI, Plugins must always test if the CGI query object is set

Return: =$query= CGI query object; or 0 if script is called as a shell script

*Since:* TWiki::Plugins::VERSION 1.000 (7 Dec 2002)

=cut

sub getCgiQuery {
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    return $TWiki::Plugins::SESSION->{request};
}

=pod

---+++ getSessionKeys() -> @keys
Get a list of all the names of session variables. The list is unsorted.

Session keys are stored and retrieved using =setSessionValue= and
=getSessionValue=.

*Since:* TWiki::Plugins::VERSION 1.2

=cut

sub getSessionKeys {
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    my $hash = $TWiki::Plugins::SESSION->{users}->{loginManager}->getSessionValues();
    return keys %{$hash};
}

=pod

---+++ getSessionValue( $key ) -> $value

Get a session value from the client session module
   * =$key= - Session key
Return: =$value=  Value associated with key; empty string if not set

*Since:* TWiki::Plugins::VERSION 1.000 (27 Feb 200)

=cut

sub getSessionValue {
#   my( $key ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;

    return $TWiki::Plugins::SESSION->{users}->{loginManager}->getSessionValue( @_ );
}


=pod

---+++ setSessionValue( $key, $value ) -> $boolean

Set a session value.
   * =$key=   - Session key
   * =$value= - Value associated with key
Return: true if function succeeded

*Since:* TWiki::Plugins::VERSION 1.000 (17 Aug 2001)

=cut

sub setSessionValue {
#   my( $key, $value ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;

    $TWiki::Plugins::SESSION->{users}->{loginManager}->setSessionValue( @_ );
}

=pod

---+++ clearSessionValue( $key ) -> $boolean

Clear a session value that was set using =setSessionValue=.
   * =$key= - name of value stored in session to be cleared. Note that
   you *cannot* clear =AUTHUSER=.
Return: true if the session value was cleared

*Since:* TWiki::Plugins::VERSION 1.1

=cut

sub clearSessionValue {
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;

    return $TWiki::Plugins::SESSION->{users}->{loginManager}->clearSessionValue( @_ );
}

=pod

---+++ getContext() -> \%hash

Get a hash of context identifiers representing the currently active
context.

The context is a set of identifiers that are set
during specific phases of TWiki processing. For example, each of
the standard scripts in the 'bin' directory each has a context
identifier - the view script has 'view', the edit script has 'edit'
etc. So you can easily tell what 'type' of script your Plugin is
being called within. The core context identifiers are listed
in the %SYSTEMWEB%.IfStatements topic. Please be careful not to
overwrite any of these identifiers!

Context identifiers can be used to communicate between Plugins, and between
Plugins and templates. For example, in FirstPlugin.pm, you might write:
<verbatim>
sub initPlugin {
   TWiki::Func::getContext()->{'MyID'} = 1;
   ...
</verbatim>
This can be used in !SecondPlugin.pm like this:
<verbatim>
sub initPlugin {
   if( TWiki::Func::getContext()->{'MyID'} ) {
      ...
   }
   ...
</verbatim>
or in a template, like this:
<verbatim>
%TMPL:DEF{"ON"}% Not off %TMPL:END%
%TMPL:DEF{"OFF"}% Not on %TMPL:END%
%TMPL:P{context="MyID" then="ON" else="OFF"}%
</verbatim>
or in a topic:
<verbatim>
%IF{"context MyID" then="MyID is ON" else="MyID is OFF"}%
</verbatim>
__Note__: *all* plugins have an *automatically generated* context identifier
if they are installed and initialised. For example, if the FirstPlugin is
working, the context ID 'FirstPlugin' will be set.

*Since:* TWiki::Plugins::VERSION 1.1

=cut

sub getContext {
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    return $TWiki::Plugins::SESSION->{context};
}

=pod

---+++ pushTopicContext($web, $topic)
   * =$web= - new web
   * =$topic= - new topic
Change the TWiki context so it behaves as if it was processing =$web.$topic=
from now on. All the preferences will be reset to those of the new topic.
Note that if the new topic is not readable by the logged in user due to
access control considerations, there will *not* be an exception. It is the
duty of the caller to check access permissions before changing the topic.

It is the duty of the caller to restore the original context by calling
=popTopicContext=.

Note that this call does *not* re-initialise plugins, so if you have used
global variables to remember the web and topic in =initPlugin=, then those
values will be unchanged.

*Since:* TWiki::Plugins::VERSION 1.2

=cut

sub pushTopicContext {
    my $twiki = $TWiki::Plugins::SESSION;
    ASSERT($twiki) if DEBUG;
    my( $web, $topic ) = $twiki->normalizeWebTopicName( @_ );
    my $old = {
        web => $twiki->{webName},
        topic => $twiki->{topicName},
        mark => $twiki->{prefs}->mark() };

    push( @{$twiki->{_FUNC_PREFS_STACK}}, $old );
    $twiki->{webName} = $web;
    $twiki->{topicName} = $topic;
    $twiki->{prefs}->pushWebPreferences( $web );
    $twiki->{prefs}->pushPreferences( $web, $topic, 'TOPIC' );
    $twiki->{prefs}->pushPreferenceValues(
        'SESSION', $twiki->{users}->{loginManager}->getSessionValues() );
}

=pod

---+++ popTopicContext()

Returns the TWiki context to the state it was in before the
=pushTopicContext= was called.

*Since:* TWiki::Plugins::VERSION 1.2

=cut

sub popTopicContext {
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    my $twiki = $TWiki::Plugins::SESSION;
    ASSERT(scalar(@{$twiki->{_FUNC_PREFS_STACK}})) if DEBUG;
    my $old = pop( @{$twiki->{_FUNC_PREFS_STACK}} );
    $twiki->{prefs}->restore( $old->{mark});
    $twiki->{webName} = $old->{web};
    $twiki->{topicName} = $old->{topic};
}

=pod

---++ Preferences

=cut

=pod

---+++ getPreferencesValue( $key, $web ) -> $value

Get a preferences value from TWiki or from a Plugin
   * =$key= - Preferences key
   * =$web= - Name of web, optional. Current web if not specified; does not apply to settings of Plugin topics
Return: =$value=  Preferences value; empty string if not set

*Since:* TWiki::Plugins::VERSION 1.000 (7 Dec 2002)

   * Example for Plugin setting:
      * MyPlugin topic has: =* Set COLOR = red=
      * Use ="MYPLUGIN_COLOR"= for =$key=
      * =my $color = TWiki::Func::getPreferencesValue( "MYPLUGIN_COLOR" );=

   * Example for preferences setting:
      * WebPreferences topic has: =* Set WEBBGCOLOR = #FFFFC0=
      * =my $webColor = TWiki::Func::getPreferencesValue( 'WEBBGCOLOR', 'Sandbox' );=

*NOTE:* As of TWiki4.1, if =$NO_PREFS_IN_TOPIC= is enabled in the plugin, then
preferences set in the plugin topic will be ignored.

=cut

sub getPreferencesValue {
    my( $key, $web ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    if( $web ) {
        return $TWiki::Plugins::SESSION->{prefs}->getWebPreferencesValue(
            $key, $web );
    } else {
        return $TWiki::Plugins::SESSION->{prefs}->getPreferencesValue( $key );
    }
}

=pod

---+++ getPluginPreferencesValue( $key ) -> $value

Get a preferences value from your Plugin
   * =$key= - Plugin Preferences key w/o PLUGINNAME_ prefix.
Return: =$value=  Preferences value; empty string if not set

__Note__: This function will will *only* work when called from the Plugin.pm file itself. it *will not work* if called from a sub-package (e.g. TWiki::Plugins::MyPlugin::MyModule)

*Since:* TWiki::Plugins::VERSION 1.021 (27 Mar 2004)

*NOTE:* As of TWiki4.1, if =$NO_PREFS_IN_TOPIC= is enabled in the plugin, then
preferences set in the plugin topic will be ignored.

=cut

sub getPluginPreferencesValue {
    my( $key ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    my $package = caller;
    $package =~ s/.*:://; # strip off TWiki::Plugins:: prefix
    return $TWiki::Plugins::SESSION->{prefs}->getPreferencesValue( "\U$package\E_$key" );
}

=pod

---+++ getPreferencesFlag( $key, $web ) -> $value

Get a preferences flag from TWiki or from a Plugin
   * =$key= - Preferences key
   * =$web= - Name of web, optional. Current web if not specified; does not apply to settings of Plugin topics
Return: =$value=  Preferences flag ='1'= (if set), or ="0"= (for preferences values ="off"=, ="no"= and ="0"=)

*Since:* TWiki::Plugins::VERSION 1.000 (7 Dec 2002)

   * Example for Plugin setting:
      * MyPlugin topic has: =* Set SHOWHELP = off=
      * Use ="MYPLUGIN_SHOWHELP"= for =$key=
      * =my $showHelp = TWiki::Func::getPreferencesFlag( "MYPLUGIN_SHOWHELP" );=

*NOTE:* As of TWiki4.1, if =$NO_PREFS_IN_TOPIC= is enabled in the plugin, then
preferences set in the plugin topic will be ignored.

=cut

sub getPreferencesFlag {
#   my( $key, $web ) = @_;
    my $t = getPreferencesValue( @_ );
    return TWiki::isTrue( $t );
}

=pod

---+++ getPluginPreferencesFlag( $key ) -> $boolean

Get a preferences flag from your Plugin
   * =$key= - Plugin Preferences key w/o PLUGINNAME_ prefix.
Return: false for preferences values ="off"=, ="no"= and ="0"=, or values not set at all. True otherwise.

__Note__: This function will will *only* work when called from the Plugin.pm file itself. it *will not work* if called from a sub-package (e.g. TWiki::Plugins::MyPlugin::MyModule)

*Since:* TWiki::Plugins::VERSION 1.021 (27 Mar 2004)

*NOTE:* As of TWiki4.1, if =$NO_PREFS_IN_TOPIC= is enabled in the plugin, then
preferences set in the plugin topic will be ignored.

=cut

sub getPluginPreferencesFlag {
    my( $key ) = @_;
    my $package = caller;
    $package =~ s/.*:://; # strip off TWiki::Plugins:: prefix
    return getPreferencesFlag( "\U$package\E_$key" );
}

=pod

---+++ setPreferencesValue($name, $val)

Set the preferences value so that future calls to getPreferencesValue will
return this value, and =%$name%= will expand to the preference when used in
future variable expansions.

The preference only persists for the rest of this request. Finalised
preferences cannot be redefined using this function.

Returns 1 if the preference was defined, and 0 otherwise.

=cut

sub setPreferencesValue {
    return $TWiki::Plugins::SESSION->{prefs}->setPreferencesValue(@_);
}

=pod

---+++ getWikiToolName( ) -> $name

Get toolname as defined in TWiki.cfg

Return: =$name= Name of tool, e.g. ='TWiki'=

*Since:* TWiki::Plugins::VERSION 1.000 (27 Feb 2001)

=cut

sub getWikiToolName {
    return $TWiki::cfg{WikiToolName};
}

=pod

---+++ getMainWebname( ) -> $name

Get name of Main web as defined in TWiki.cfg

Return: =$name= Name, e.g. ='Main'=

*Since:* TWiki::Plugins::VERSION 1.000 (27 Feb 2001)

=cut

sub getMainWebname {
    return $TWiki::cfg{UsersWebName};
}

=pod

---+++ getTwikiWebname( ) -> $name

Get name of TWiki documentation web as defined in TWiki.cfg

Return: =$name= Name, e.g. ='TWiki'=

*Since:* TWiki::Plugins::VERSION 1.000 (27 Feb 2001)

=cut

sub getTwikiWebname {
    return $TWiki::cfg{SystemWebName};
}

=pod

---++ User Handling and Access Control
---+++ getDefaultUserName( ) -> $loginName
Get default user name as defined in the configuration as =DefaultUserLogin=

Return: =$loginName= Default user name, e.g. ='guest'=

*Since:* TWiki::Plugins::VERSION 1.000 (7 Dec 2002)

=cut

sub getDefaultUserName {
    return $TWiki::cfg{DefaultUserLogin};
}

=pod

---+++ getCanonicalUserID( $user ) -> $cUID
   * =$user= can be a login, wikiname or web.wikiname
Return the cUID of the specified user. A cUID is a unique identifier which
is assigned by TWiki for each user.
BEWARE: While the default TWikiUserMapping uses a cUID that looks like a user's
LoginName, some characters are modified to make them compatible with rcs.
Other usermappings may use other conventions - the !JoomlaUserMapping
for example, has cUIDs like 'JoomlaeUserMapping_1234'.

If $user is undefined, it assumes the currently logged-in user.

Return: =$cUID=, an internal unique and portable escaped identifier for
registered users. This may be autogenerated for an authenticated but
unregistered user.

*Since:* TWiki::Plugins::VERSION 1.2

=cut

sub getCanonicalUserID {
    my $user = shift;
    return $TWiki::Plugins::SESSION->{user} unless ($user);
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    my $cUID;
    if ($user) {
        $cUID =
          $TWiki::Plugins::SESSION->{users}->getCanonicalUserID( $user );
        if (!$cUID) {
            # Not a login name or a wiki name. Is it a valid cUID?
            my $ln = $TWiki::Plugins::SESSION->{users}->getLoginName($user);
            $cUID = $user if defined $ln && $ln ne 'unknown';
        }
    } else {
        $cUID = $TWiki::Plugins::SESSION->{user};
    }
    return $cUID;
}

=pod

---+++ getWikiName( $user ) -> $wikiName

return the WikiName of the specified user
if $user is undefined Get Wiki name of logged in user

   * $user can be a cUID, login, wikiname or web.wikiname

Return: =$wikiName= Wiki Name, e.g. ='JohnDoe'=

*Since:* TWiki::Plugins::VERSION 1.000 (7 Dec 2002)

=cut

sub getWikiName {
    my $user = shift;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    my $cUID = getCanonicalUserID( $user );
    unless( defined $cUID ) {
        my ($w, $u) = normalizeWebTopicName($TWiki::cfg{UsersWebName}, $user);
        return $u;
    }
    return $TWiki::Plugins::SESSION->{users}->getWikiName( $cUID );
}
 
=pod 
 
---+++ getWikiUserName( $user ) -> $wikiName

return the userWeb.WikiName of the specified user
if $user is undefined Get Wiki name of logged in user

   * $user can be a cUID, login, wikiname or web.wikiname

Return: =$wikiName= Wiki Name, e.g. ="Main.JohnDoe"=

*Since:* TWiki::Plugins::VERSION 1.000 (7 Dec 2002)

=cut

sub getWikiUserName {
    my $user = shift;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    my $cUID = getCanonicalUserID( $user );
    unless( defined $cUID ) {
        my ($w, $u) = normalizeWebTopicName($TWiki::cfg{UsersWebName}, $user);
        return "$w.$u";
    }
    return $TWiki::Plugins::SESSION->{users}->webDotWikiName($cUID);
}

=pod

---+++ wikiToUserName( $id ) -> $loginName
Translate a Wiki name to a login name.
   * =$id= - Wiki name, e.g. ='Main.JohnDoe'= or ='JohnDoe'=.
     Since TWiki 4.2.1, $id may also be a login name. This will normally
     be transparent, but should be borne in mind if you have login names
     that are also legal wiki names.

Return: =$loginName=   Login name of user, e.g. ='jdoe'=, or undef if not
matched.

Note that it is possible for several login names to map to the same wikiname.
This function will only return the *first* login name that maps to the
wikiname.

returns undef if the WikiName is not found.

*Since:* TWiki::Plugins::VERSION 1.000 (7 Dec 2002)

=cut 

sub wikiToUserName {
    my( $wiki ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    return '' unless $wiki;

    my $cUID = getCanonicalUserID($wiki);
    if ($cUID) {
        my $login = $TWiki::Plugins::SESSION->{users}->getLoginName($cUID);
        return undef if !$login || $login eq 'unknown';
        return $login;
    }
    return undef;
}

=pod

---+++ userToWikiName( $loginName, $dontAddWeb ) -> $wikiName
Translate a login name to a Wiki name
   * =$loginName=  - Login name, e.g. ='jdoe'=. Since TWiki 4.2.1 this may
     also be a wiki name. This will normally be transparent, but may be
     relevant if you have login names that are also valid wiki names.
   * =$dontAddWeb= - Do not add web prefix if ="1"=
Return: =$wikiName=      Wiki name of user, e.g. ='Main.JohnDoe'= or ='JohnDoe'=

userToWikiName will always return a name. If the user does not
exist in the mapping, the $loginName parameter is returned. (backward compatibility)

*Since:* TWiki::Plugins::VERSION 1.000 (7 Dec 2002)

=cut

sub userToWikiName {
    my( $login, $dontAddWeb ) = @_;
    return '' unless $login;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    my $users = $TWiki::Plugins::SESSION->{users};
    my $user = getCanonicalUserID( $login );
    return ( $dontAddWeb ? $login :
               ( $TWiki::cfg{UsersWebName} . '.' . $login ) )
      unless $users->userExists( $user );
    return $users->getWikiName( $user ) if $dontAddWeb;
    return $users->webDotWikiName($user);
}

=pod

---+++ emailToWikiNames( $email, $dontAddWeb ) -> @wikiNames
   * =$email= - email address to look up
   * =$dontAddWeb= - Do not add web prefix if ="1"=
Find the wikinames of all users who have the given email address as their
registered address. Since several users could register with the same email
address, this returns a list of wikinames rather than a single wikiname.

*Since:* TWiki::Plugins::VERSION 1.2

=cut

sub emailToWikiNames {
    my( $email, $dontAddWeb ) = @_;
    ASSERT($email) if DEBUG;

    my %matches;
    my $users = $TWiki::Plugins::SESSION->{users};
    my $ua = $users->findUserByEmail( $email );
    if ($ua) {
        foreach my $user (@$ua) {
            if( $dontAddWeb ) {
                $matches{$users->getWikiName($user)} = 1;
            } else {
                $matches{$users->webDotWikiName($user)} = 1;
            }
        }
    }

    return sort keys %matches;
}

=pod

---+++ wikinameToEmails( $user ) -> @emails
   * =$user= - wikiname of user to look up
Returns the registered email addresses of the named user. If $user is
undef, returns the registered email addresses for the logged-in user.

Since TWiki 4.2.1, $user may also be a login name, or the name of a group.

*Since:* TWiki::Plugins::VERSION 1.2

=cut

sub wikinameToEmails {
    my( $wikiname ) = @_;
    if( $wikiname ) {
        if (isGroup($wikiname)) {
            return $TWiki::Plugins::SESSION->{users}->getEmails( $wikiname );
        } else {
            my $uids = $TWiki::Plugins::SESSION->{users}->findUserByWikiName(
                $wikiname );
            my @em = ();
            foreach my $user (@$uids) {
                push(@em, $TWiki::Plugins::SESSION->{users}->getEmails( $user ));
            }
            return @em;
        }
    } else {
        my $user = $TWiki::Plugins::SESSION->{user};
        return $TWiki::Plugins::SESSION->{users}->getEmails( $user );
    }
}

=pod

---+++ isGuest( ) -> $boolean

Test if logged in user is a guest (TWikiGuest)

*Since:* TWiki::Plugins::VERSION 1.000 (7 Dec 2002)

=cut

sub isGuest {
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    return $TWiki::Plugins::SESSION->{user} eq
      $TWiki::Plugins::SESSION->{users}->getCanonicalUserID(
          $TWiki::cfg{DefaultUserLogin} );
}

=pod

---+++ isAnAdmin( $id ) -> $boolean

Find out if the user is an admin or not. If the user is not given,
the currently logged-in user is assumed.
   * $id can be either a login name or a WikiName

*Since:* TWiki::Plugins::VERSION 1.2

=cut

sub isAnAdmin {
    my $user = shift;
    return $TWiki::Plugins::SESSION->{users}->isAdmin(
        getCanonicalUserID( $user ));
}

=pod

---+++ isGroupMember( $group, $id ) -> $boolean

Find out if $id is in the named group. e.g.
<verbatim>
if( TWiki::Func::isGroupMember( "HesperionXXGroup", "jordi" )) {
    ...
}
</verbatim>
If =$user= is =undef=, it defaults to the currently logged-in user.

   * $id can be a login name or a WikiName

*Since:* TWiki::Plugins::VERSION 1.2

=cut

sub isGroupMember {
    my ($group, $user) = @_;
    my $users = $TWiki::Plugins::SESSION->{users};

    return () unless $users->isGroup($group);
    if( $user ) {
        #my $login = wikiToUserName( $user );
        #return 0 unless $login;
        $user = getCanonicalUserID( $user );
    } else {
        $user = $TWiki::Plugins::SESSION->{user};
    }
    return $users->isInGroup( $user, $group );
}

=pod

---+++ eachUser() -> $iterator
Get an iterator over the list of all the registered users *not* including
groups. The iterator will return each wiki name in turn (e.g. 'FredBloggs').

Use it as follows:
<verbatim>
    my $iterator = TWiki::Func::eachUser();
    while ($it->hasNext()) {
        my $user = $it->next();
        # $user is a wikiname
    }
</verbatim>

*WARNING* on large sites, this could be a long list!

*Since:* TWiki::Plugins::VERSION 1.2

=cut

sub eachUser {
    my $it = $TWiki::Plugins::SESSION->{users}->eachUser();
    $it->{process} = sub {
        return $TWiki::Plugins::SESSION->{users}->getWikiName( $_[0] );
    };
    return $it;
}

=pod

---+++ eachMembership($id) -> $iterator
   * =$id= - WikiName or login name of the user.
     If =$id= is =undef=, defaults to the currently logged-in user.
Get an iterator over the names of all groups that the user is a member of.

*Since:* TWiki::Plugins::VERSION 1.2

=cut

sub eachMembership {
    my ($user) = @_;
    my $users = $TWiki::Plugins::SESSION->{users};

    if( $user ) {
        my $login = wikiToUserName( $user );
        return 0 unless $login;
        $user = getCanonicalUserID( $login );
    } else {
        $user = $TWiki::Plugins::SESSION->{user};
    }

    return $users->eachMembership($user);
}

=pod

---+++ eachGroup() -> $iterator
Get an iterator over all groups.

Use it as follows:
<verbatim>
    my $iterator = TWiki::Func::eachGroup();
    while ($it->hasNext()) {
        my $group = $it->next();
        # $group is a group name e.g. TWikiAdminGroup
    }
</verbatim>

*WARNING* on large sites, this could be a long list!

*Since:* TWiki::Plugins::VERSION 1.2

=cut

sub eachGroup {
    my $session = $TWiki::Plugins::SESSION;
    my $it = $session->{users}->eachGroup();
    return $it;
}

=pod

---+++ isGroup( $group ) -> $boolean

Checks if =$group= is the name of a group known to TWiki.

=cut

sub isGroup {
    my( $group ) = @_;

    return $TWiki::Plugins::SESSION->{users}->isGroup( $group );
}

=pod

---+++ eachGroupMember($group) -> $iterator
Get an iterator over all the members of the named group. Returns undef if
$group is not a valid group.

Use it as follows:
<verbatim>
    my $iterator = TWiki::Func::eachGroupMember('RadioheadGroup');
    while ($it->hasNext()) {
        my $user = $it->next();
        # $user is a wiki name e.g. 'TomYorke', 'PhilSelway'
    }
</verbatim>

*WARNING* on large sites, this could be a long list!

*Since:* TWiki::Plugins::VERSION 1.2

=cut

sub eachGroupMember {
    my $user = shift;
    my $session = $TWiki::Plugins::SESSION;
    return undef unless
      $TWiki::Plugins::SESSION->{users}->isGroup($user);
    my $it = $TWiki::Plugins::SESSION->{users}->eachGroupMember($user);
    $it->{process} = sub {
        return $TWiki::Plugins::SESSION->{users}->getWikiName( $_[0] );
    };
    return $it;
}

=pod

---+++ checkAccessPermission( $type, $id, $text, $topic, $web, $meta ) -> $boolean

Check access permission for a topic based on the
[[%SYSTEMWEB%.TWikiAccessControl]] rules
   * =$type=     - Access type, required, e.g. ='VIEW'=, ='CHANGE'=.
   * =$id=  - WikiName of remote user, required, e.g. ="PeterThoeny"=. From
     TWiki 4.2.1, $id may also be a login name.
     If =$id= is '', 0 or =undef= then access is *always permitted*.
   * =$text=     - Topic text, optional. If 'perl false' (undef, 0 or ''),
     topic =$web.$topic= is consulted. =$text= may optionally contain embedded
     =%META:PREFERENCE= tags. Provide this parameter if:
      1 You are setting different access controls in the text to those defined
      in the stored topic,
      1 You already have the topic text in hand, and want to help TWiki avoid
        having to read it again,
      1 You are providing a =$meta= parameter.
   * =$topic=    - Topic name, required, e.g. ='PrivateStuff'=
   * =$web=      - Web name, required, e.g. ='Sandbox'=
   * =$meta=     - Meta-data object, as returned by =readTopic=. Optional.
     If =undef=, but =$text= is defined, then access controls will be parsed
     from =$text=. If defined, then metadata embedded in =$text= will be
     ignored. This parameter is always ignored if =$text= is undefined.
     Settings in =$meta= override =Set= settings in $text.
A perl true result indicates that access is permitted.

*Note* the weird parameter order is due to compatibility constraints with
earlier TWiki releases.

*Tip* if you want, you can use this method to check your own access control types. For example, if you:
   * Set ALLOWTOPICSPIN = IncyWincy
in =ThatWeb.ThisTopic=, then a call to =checkAccessPermissions('SPIN', 'IncyWincy', undef, 'ThisTopic', 'ThatWeb', undef)= will return =true=.

*Since:* TWiki::Plugins::VERSION 1.000 (27 Feb 2001)

=cut

sub checkAccessPermission {
    my( $type, $user, $text, $topic, $web, $meta ) = @_;
    return 1 unless ( $user );
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    $text = undef unless $text;
    my $cUID = getCanonicalUserID($user) ||
        getCanonicalUserID($TWiki::cfg{DefaultUserLogin});
    return $TWiki::Plugins::SESSION->security->checkAccessPermission(
        $type, $cUID, $text, $meta, $topic, $web );
}

=pod

---++ Webs, Topics and Attachments

=cut

=pod

---+++ getListOfWebs( $filter ) -> @webs

   * =$filter= - spec of web types to recover
Gets a list of webs, filtered according to the spec in the $filter,
which may include one of:
   1 'user' (for only user webs)
   2 'template' (for only template webs i.e. those starting with "_")
=$filter= may also contain the word 'public' which will further filter
out webs that have NOSEARCHALL set on them.
'allowed' filters out webs the current user can't read.

For example, the deprecated getPublicWebList function can be duplicated
as follows:
<verbatim>
   my @webs = TWiki::Func::getListOfWebs( "user,public" );
</verbatim>

*Since:* TWiki::Plugins::VERSION 1.1

=cut

sub getListOfWebs {
    my $filter = shift;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    return $TWiki::Plugins::SESSION->{store}->getListOfWebs($filter);
}

=pod

---+++ webExists( $web ) -> $boolean

Test if web exists
   * =$web= - Web name, required, e.g. ='Sandbox'=

*Since:* TWiki::Plugins::VERSION 1.000 (14 Jul 2001)

=cut

sub webExists {
#   my( $web ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    return $TWiki::Plugins::SESSION->{store}->webExists( @_ );
}

=pod

---+++ createWeb( $newWeb, $baseWeb, $opts )

   * =$newWeb= is the name of the new web.
   * =$baseWeb= is the name of an existing web (a template web). If the base web is a system web, all topics in it will be copied into the new web. If it is a normal web, only topics starting with 'Web' will be copied. If no base web is specified, an empty web (with no topics) will be created. If it is specified but does not exist, an error will be thrown.
   * =$opts= is a ref to a hash that contains settings to be modified in
the web preferences topic in the new web.

<verbatim>
use Error qw( :try );
use TWiki::AccessControlException;

try {
    TWiki::Func::createWeb( "Newweb" );
} catch Error::Simple with {
    my $e = shift;
    # see documentation on Error::Simple
} catch TWiki::AccessControlException with {
    my $e = shift;
    # see documentation on TWiki::AccessControlException
} otherwise {
    ...
};
</verbatim>

*Since:* TWiki::Plugins::VERSION 1.1

=cut

sub createWeb {
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    $TWiki::Plugins::SESSION->{store}->createWeb(
        $TWiki::Plugins::SESSION->{user}, @_ );
}

=pod

---+++ moveWeb( $oldName, $newName )

Move (rename) a web.

<verbatim>
use Error qw( :try );
use TWiki::AccessControlException;

try {
    TWiki::Func::moveWeb( "Oldweb", "Newweb" );
} catch Error::Simple with {
    my $e = shift;
    # see documentation on Error::Simple
} catch TWiki::AccessControlException with {
    my $e = shift;
    # see documentation on TWiki::AccessControlException
} otherwise {
    ...
};
</verbatim>

To delete a web, move it to a subweb of =Trash=
<verbatim>
TWiki::Func::moveWeb( "Deadweb", "Trash.Deadweb" );
</verbatim>

*Since:* TWiki::Plugins::VERSION 1.1

=cut

sub moveWeb {
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    return $TWiki::Plugins::SESSION->{store}->moveWeb(
        @_, $TWiki::Plugins::SESSION->{user});

}

=pod

---+++ eachChangeSince($web, $time) -> $iterator

Get an iterator over the list of all the changes in the given web between
=$time= and now. $time is a time in seconds since 1st Jan 1970, and is not
guaranteed to return any changes that occurred before (now - 
{Store}{RememberChangesFor}). {Store}{RememberChangesFor}) is a
setting in =configure=. Changes are returned in *most-recent-first*
order.

Use it as follows:
<verbatim>
    my $iterator = TWiki::Func::eachChangeSince(
        $web, time() - 7 * 24 * 60 * 60); # the last 7 days
    while ($iterator->hasNext()) {
        my $change = $iterator->next();
        # $change is a perl hash that contains the following fields:
        # topic => topic name
        # user => wikiname - wikiname of user who made the change
        # time => time of the change
        # revision => revision number *after* the change
        # more => more info about the change (e.g. 'minor')
    }
</verbatim>

=cut

sub eachChangeSince {
    my( $web, $time ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    ASSERT($TWiki::Plugins::SESSION->{store}->webExists($web)) if DEBUG;

    my $iterator =
      $TWiki::Plugins::SESSION->{store}->eachChange( $web, $time );
    return $iterator;
}

=pod

---+++ getTopicList( $web ) -> @topics

Get list of all topics in a web
   * =$web= - Web name, required, e.g. ='Sandbox'=
Return: =@topics= Topic list, e.g. =( 'WebChanges',  'WebHome', 'WebIndex', 'WebNotify' )=

*Since:* TWiki::Plugins::VERSION 1.000 (7 Dec 2002)

=cut

sub getTopicList {
#   my( $web ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    return $TWiki::Plugins::SESSION->{store}->getTopicNames ( @_ );
}

=pod

---+++ topicExists( $web, $topic ) -> $boolean

Test if topic exists
   * =$web=   - Web name, optional, e.g. ='Main'=.
   * =$topic= - Topic name, required, e.g. ='TokyoOffice'=, or ="Main.TokyoOffice"=

$web and $topic are parsed as described in the documentation for =normalizeWebTopicName=.
Specifically, the %USERSWEB% is used if $web is not specified and $topic has no web specifier.
To get an expected behaviour it is recommened to specify the current web for $web; don't leave it empty.

*Since:* TWiki::Plugins::VERSION 1.000 (14 Jul 2001)

=cut

sub topicExists {
    my( $web, $topic ) = $TWiki::Plugins::SESSION->normalizeWebTopicName( @_ );
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    return $TWiki::Plugins::SESSION->{store}->topicExists( $web, $topic );
}

=pod

---+++ checkTopicEditLock( $web, $topic, $script ) -> ( $oopsUrl, $loginName, $unlockTime )

Check if a lease has been taken by some other user.
   * =$web= Web name, e.g. ="Main"=, or empty
   * =$topic= Topic name, e.g. ="MyTopic"=, or ="Main.MyTopic"=
Return: =( $oopsUrl, $loginName, $unlockTime )= - The =$oopsUrl= for calling redirectCgiQuery(), user's =$loginName=, and estimated =$unlockTime= in minutes, or ( '', '', 0 ) if no lease exists.
   * =$script= The script to invoke when continuing with the edit

*Since:* TWiki::Plugins::VERSION 1.010 (31 Dec 2002)

=cut

sub checkTopicEditLock {
    my( $web, $topic, $script ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;

    ( $web, $topic ) = normalizeWebTopicName( $web, $topic );
    $script ||= 'edit';

    my $lease = $TWiki::Plugins::SESSION->{store}->getLease( $web, $topic );
    if( $lease ) {
        my $remain = $lease->{expires} - time();
        my $session = $TWiki::Plugins::SESSION;

        if( $remain > 0 ) {
            my $who = $lease->{user};
            require TWiki::Time;
            my $past = TWiki::Time::formatDelta(
                time()-$lease->{taken},
                $TWiki::Plugins::SESSION->i18n
               );
            my $future = TWiki::Time::formatDelta(
                $lease->{expires}-time(),
                $TWiki::Plugins::SESSION->i18n
               );
            my $url = getScriptUrl(
                $web, $topic, 'oops',
                template => 'oopsleaseconflict',
                def => 'lease_active',
                param1 => $who,
                param2 => $past,
                param3 => $future,
                param4 => $script );
            my $login = $session->{users}->getLoginName($who);
            return( $url, $login, $remain / 60 );
        }
    }
    return ('', '', 0);
}

=pod

---+++ setTopicEditLock( $web, $topic, $lock )

   * =$web= Web name, e.g. ="Main"=, or empty
   * =$topic= Topic name, e.g. ="MyTopic"=, or ="Main.MyTopic"=
   * =$lock= 1 to lease the topic, 0 to clear an existing lease

Takes out a "lease" on the topic. The lease doesn't prevent
anyone from editing and changing the topic, but it does redirect them
to a warning screen, so this provides some protection. The =edit= script
always takes out a lease.

It is *impossible* to fully lock a topic. Concurrent changes will be
merged.

*Since:* TWiki::Plugins::VERSION 1.010 (31 Dec 2002)

=cut

sub setTopicEditLock {
    my( $web, $topic, $lock ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    my $session = $TWiki::Plugins::SESSION;
    my $store = $session->{store};
    if( $lock ) {
        $store->setLease( $web, $topic, $session->{user},
                          $TWiki::cfg{LeaseLength} );
    } else {
        $store->clearLease( $web, $topic );
    }
    return '';
}

=pod

---+++ saveTopic( $web, $topic, $meta, $text, $options ) -> $error

   * =$web= - web for the topic
   * =$topic= - topic name
   * =$meta= - reference to TWiki::Meta object
   * =$text= - text of the topic (without embedded meta-data!!!
   * =\%options= - ref to hash of save options
     =\%options= may include:
     | =dontlog= | don't log this change in twiki log |
     | =forcenewrevision= | force the save to increment the revision counter |
     | =minor= | True if this is a minor change, and is not to be notified |
Return: error message or undef.

*Since:* TWiki::Plugins::VERSION 1.000 (29 Jul 2001)

For example,
<verbatim>
my( $meta, $text ) = TWiki::Func::readTopic( $web, $topic )
$text =~ s/APPLE/ORANGE/g;
TWiki::Func::saveTopic( $web, $topic, $meta, $text, { forcenewrevision => 1 } );
</verbatim>

__Note:__ Plugins handlers ( e.g. =beforeSaveHandler= ) will be called as
appropriate.

=cut

sub saveTopic {
    my( $web, $topic, $meta, $text, $options ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;

    return $TWiki::Plugins::SESSION->{store}->saveTopic
      ( $TWiki::Plugins::SESSION->{user}, $web, $topic, $text, $meta,
        $options );

}

=pod

---+++ saveTopicText( $web, $topic, $text, $ignorePermissions, $dontNotify ) -> $oopsUrl

Save topic text, typically obtained by readTopicText(). Topic data usually includes meta data; the file attachment meta data is replaced by the meta data from the topic file if it exists.
   * =$web=                - Web name, e.g. ='Main'=, or empty
   * =$topic=              - Topic name, e.g. ='MyTopic'=, or ="Main.MyTopic"=
   * =$text=               - Topic text to save, assumed to include meta data
   * =$ignorePermissions=  - Set to ="1"= if checkAccessPermission() is already performed and OK
   * =$dontNotify=         - Set to ="1"= if not to notify users of the change
Return: =$oopsUrl=               Empty string if OK; the =$oopsUrl= for calling redirectCgiQuery() in case of error

This method is a lot less efficient and much more dangerous than =saveTopic=.

*Since:* TWiki::Plugins::VERSION 1.010 (31 Dec 2002)

<verbatim>
my $text = TWiki::Func::readTopicText( $web, $topic );

# check for oops URL in case of error:
if( $text =~ /^http.*?\/oops/ ) {
    TWiki::Func::redirectCgiQuery( $query, $text );
    return;
}
# do topic text manipulation like:
$text =~ s/old/new/g;
# do meta data manipulation like:
$text =~ s/(META\:FIELD.*?name\=\"TopicClassification\".*?value\=\")[^\"]*/$1BugResolved/;
$oopsUrl = TWiki::Func::saveTopicText( $web, $topic, $text ); # save topic text
</verbatim>

=cut

sub saveTopicText {
    my( $web, $topic, $text, $ignorePermissions, $dontNotify ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;

    my $session = $TWiki::Plugins::SESSION;
    my( $mirrorSite, $mirrorViewURL ) = $session->readOnlyMirrorWeb( $web );
    throw Error::Simple('Cannot save on a mirror site') if( $mirrorSite );

    # check access permission
    unless( $ignorePermissions ||
            $session->security->checkAccessPermission(
                'CHANGE', $session->{user}, undef, undef,
                $topic, $web )
          ) {
        my @plugin = caller();
        return getScriptUrl(
            $web, $topic, 'oops',
            template => 'oopsaccessdenied',
            def => 'topic_access',
            param1 => 'in',
            param2 => $plugin[0] );
    }

    return getScriptUrl(
        $web, $topic, 'oops', template => 'oopsattention', def => 'save_error',
        param1 => 'No text' )
      unless( defined $text );

    # extract meta data and merge old attachment meta data
    require TWiki::Meta;
    my $meta = new TWiki::Meta( $session, $web, $topic, $text );

    $meta->remove( 'FILEATTACHMENT' );

    my( $oldMeta, $oldText ) =
      $session->{store}->readTopic( undef, $web, $topic, undef );
    $meta->copyFrom( $oldMeta, 'FILEATTACHMENT' );
    # save topic
    my $error =
      $session->{store}->saveTopic
        ( $session->{user}, $web, $topic, $meta->text(), $meta,
          { notify => $dontNotify } );
    return getScriptUrl(
        $web, $topic, 'oops', template => 'oopsattention', def => 'save_error',
          param1 => $error ) if( $error );
    return '';
}

=pod

---+++ moveTopic( $web, $topic, $newWeb, $newTopic )

   * =$web= source web - required
   * =$topic= source topic - required
   * =$newWeb= dest web
   * =$newTopic= dest topic
Renames the topic. Throws an exception if something went wrong.
If $newWeb is undef, it defaults to $web. If $newTopic is undef, it defaults
to $topic.

The destination topic must not already exist.

Rename a topic to the $TWiki::cfg{TrashWebName} to delete it.

*Since:* TWiki::Plugins::VERSION 1.1

<verbatim>
use Error qw( :try );

try {
    moveTopic( "Work", "TokyoOffice", "Trash", "ClosedOffice" );
} catch Error::Simple with {
    my $e = shift;
    # see documentation on Error::Simple
} catch TWiki::AccessControlException with {
    my $e = shift;
    # see documentation on TWiki::AccessControlException
} otherwise {
    ...
};
</verbatim>

=cut

sub moveTopic {
    my( $web, $topic, $newWeb, $newTopic ) = @_;
    $newWeb ||= $web;
    $newTopic ||= $topic;

    return if( $newWeb eq $web && $newTopic eq $topic );

    $TWiki::Plugins::SESSION->{store}->moveTopic(
        $web, $topic,
        $newWeb, $newTopic,
        $TWiki::Plugins::SESSION->{user} );
}

=pod

---+++ getRevisionInfo($web, $topic, $rev, $attachment ) -> ( $date, $user, $rev, $comment ) 

Get revision info of a topic or attachment
   * =$web= - Web name, optional, e.g. ='Main'=
   * =$topic=   - Topic name, required, e.g. ='TokyoOffice'=
   * =$rev=     - revsion number, or tag name (can be in the format 1.2, or just the minor number)
   * =$attachment=                 -attachment filename
Return: =( $date, $user, $rev, $comment )= List with: ( last update date, login name of last user, minor part of top revision number ), e.g. =( 1234561, 'phoeny', "5" )=
| $date | in epochSec |
| $user | Wiki name of the author (*not* login name) |
| $rev | actual rev number |
| $comment | WHAT COMMENT? |

NOTE: if you are trying to get revision info for a topic, use
=$meta->getRevisionInfo= instead if you can - it is significantly
more efficient.

*Since:* TWiki::Plugins::VERSION 1.000 (29 Jul 2001)

=cut

sub getRevisionInfo {
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    my( $date, $user, $rev, $comment ) =
      $TWiki::Plugins::SESSION->{store}->getRevisionInfo( @_ );
    $user = $TWiki::Plugins::SESSION->{users}->getWikiName( $user );
    return ( $date, $user, $rev, $comment );
}

=pod

---+++ getRevisionAtTime( $web, $topic, $time ) -> $rev

Get the revision number of a topic at a specific time.
   * =$web= - web for topic
   * =$topic= - topic
   * =$time= - time (in epoch secs) for the rev
Return: Single-digit revision number, or undef if it couldn't be determined
(either because the topic isn't that old, or there was a problem)

*Since:* TWiki::Plugins::VERSION 1.1

=cut

sub getRevisionAtTime {
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    return $TWiki::Plugins::SESSION->{store}->getRevisionAtTime( @_ );
}

=pod

---+++ readTopic( $web, $topic, $rev ) -> ( $meta, $text )

Read topic text and meta data, regardless of access permissions.
   * =$web= - Web name, required, e.g. ='Main'=
   * =$topic= - Topic name, required, e.g. ='TokyoOffice'=
   * =$rev= - revision to read (default latest)
Return: =( $meta, $text )= Meta data object and topic text

=$meta= is a perl 'object' of class =TWiki::Meta=. This class is
fully documented in the source code documentation shipped with the
release, or can be inspected in the =lib/TWiki/Meta.pm= file.

This method *ignores* topic access permissions. You should be careful to use
=checkAccessPermissions= to ensure the current user has read access to the
topic.

*Since:* TWiki::Plugins::VERSION 1.000 (7 Dec 2002)

=cut

sub readTopic {
    #my( $web, $topic, $rev ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;

    return $TWiki::Plugins::SESSION->{store}->readTopic( undef, @_ );
}

=pod

---+++ readTopicText( $web, $topic, $rev, $ignorePermissions ) -> $text

Read topic text, including meta data
   * =$web=                - Web name, e.g. ='Main'=, or empty
   * =$topic=              - Topic name, e.g. ='MyTopic'=, or ="Main.MyTopic"=
   * =$rev=                - Topic revision to read, optional. Specify the minor part of the revision, e.g. ="5"=, not ="1.5"=; the top revision is returned if omitted or empty.
   * =$ignorePermissions=  - Set to ="1"= if checkAccessPermission() is already performed and OK; an oops URL is returned if user has no permission
Return: =$text=                  Topic text with embedded meta data; an oops URL for calling redirectCgiQuery() is returned in case of an error

This method is more efficient than =readTopic=, but returns meta-data embedded in the text. Plugins authors must be very careful to avoid damaging meta-data. You are recommended to use readTopic instead, which is a lot safer.

*Since:* TWiki::Plugins::VERSION 1.010 (31 Dec 2002)

=cut

sub readTopicText {
    my( $web, $topic, $rev, $ignorePermissions ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;

    my $user;
    $user = $TWiki::Plugins::SESSION->{user}
      unless defined( $ignorePermissions );

    my $text;
    try {
        $text =
          $TWiki::Plugins::SESSION->{store}->readTopicRaw
            ( $user, $web, $topic, $rev );
    } catch TWiki::AccessControlException with {
        my $e = shift;
        $text = getScriptUrl(
            $web, $topic, 'oops',
            template => 'oopsaccessdenied', def=>'topic_access',
            param1 => $e->{mode},
            param2 => $e->{reason} );
    };

    return $text;
}

=pod

---+++ attachmentExists( $web, $topic, $attachment ) -> $boolean

Test if attachment exists
   * =$web=   - Web name, optional, e.g. =Main=.
   * =$topic= - Topic name, required, e.g. =TokyoOffice=, or =Main.TokyoOffice=
   * =$attachment= - attachment name, e.g.=logo.gif=
$web and $topic are parsed as described in the documentation for =normalizeWebTopicName=.

*Since:* TWiki::Plugins::VERSION 1.1

=cut

sub attachmentExists {
    my( $web, $topic, $attachment ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;

    ( $web, $topic ) =
      $TWiki::Plugins::SESSION->normalizeWebTopicName( $web, $topic );
    return $TWiki::Plugins::SESSION->{store}->attachmentExists(
        $web, $topic, $attachment );
}

=pod

---+++ readAttachment( $web, $topic, $name, $rev ) -> $data

   * =$web= - web for topic
   * =$topic= - topic
   * =$name= - attachment name
   * =$rev= - revision to read (default latest)
Read an attachment from the store for a topic, and return it as a string. The
names of attachments on a topic can be recovered from the meta-data returned
by =readTopic=. If the attachment does not exist, or cannot be read, undef
will be returned. If the revision is not specified, the latest version will
be returned.

View permission on the topic is required for the
read to be successful.  Access control violations are flagged by a
TWiki::AccessControlException. Permissions are checked for the current user.

<verbatim>
my( $meta, $text ) = TWiki::Func::readTopic( $web, $topic );
my @attachments = $meta->find( 'FILEATTACHMENT' );
foreach my $a ( @attachments ) {
   try {
       my $data = TWiki::Func::readAttachment( $web, $topic, $a->{name} );
       ...
   } catch TWiki::AccessControlException with {
   };
}
</verbatim>

*Since:* TWiki::Plugins::VERSION 1.1

=cut

sub readAttachment {
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    my $result;

#    try {
        $result = $TWiki::Plugins::SESSION->{store}->readAttachment(
            $TWiki::Plugins::SESSION->{user}, @_ );
#    } catch Error::Simple with {
#    };
    return $result;
}

=pod

---+++ saveAttachment( $web, $topic, $attachment, $opts )

   * =$web= - web for topic
   * =$topic= - topic to atach to
   * =$attachment= - name of the attachment
   * =$opts= - Ref to hash of options
=$opts= may include:
| =dontlog= | don't log this change in twiki log |
| =comment= | comment for save |
| =hide= | if the attachment is to be hidden in normal topic view |
| =stream= | Stream of file to upload |
| =file= | Name of a file to use for the attachment data. ignored if stream is set. Local file on the server. |
| =filepath= | Client path to file |
| =filesize= | Size of uploaded data |
| =filedate= | Date |

Save an attachment to the store for a topic. On success, returns undef. If there is an error, an exception will be thrown.

<verbatim>
    try {
        TWiki::Func::saveAttachment( $web, $topic, 'image.gif',
                                     { file => 'image.gif',
                                       comment => 'Picture of Health',
                                       hide => 1 } );
   } catch Error::Simple with {
      # see documentation on Error
   } otherwise {
      ...
   };
</verbatim>

*Since:* TWiki::Plugins::VERSION 1.1

=cut

sub saveAttachment {
    my( $web, $topic, $name, $data ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    my $result = undef;

    try {
        $TWiki::Plugins::SESSION->{store}->saveAttachment(
            $web, $topic, $name,
            $TWiki::Plugins::SESSION->{user},
            $data );
    } catch Error::Simple with {
        $result = shift->{-text};
    };

    return $result;
}

=pod

---+++ moveAttachment( $web, $topic, $attachment, $newWeb, $newTopic, $newAttachment )

   * =$web= source web - required
   * =$topic= source topic - required
   * =$attachment= source attachment - required
   * =$newWeb= dest web
   * =$newTopic= dest topic
   * =$newAttachment= dest attachment
Renames the topic. Throws an exception on error or access violation.
If $newWeb is undef, it defaults to $web. If $newTopic is undef, it defaults
to $topic. If $newAttachment is undef, it defaults to $attachment. If all of $newWeb, $newTopic and $newAttachment are undef, it is an error.

The destination topic must already exist, but the destination attachment must
*not* exist.

Rename an attachment to $TWiki::cfg{TrashWebName}.TrashAttament to delete it.

<verbatim>
use Error qw( :try );

try {
   # move attachment between topics
   moveAttachment( "Countries", "Germany", "AlsaceLorraine.dat",
                     "Countries", "France" );
   # Note destination attachment name is defaulted to the same as source
} catch TWiki::AccessControlException with {
   my $e = shift;
   # see documentation on TWiki::AccessControlException
} catch Error::Simple with {
   my $e = shift;
   # see documentation on Error::Simple
};
</verbatim>

*Since:* TWiki::Plugins::VERSION 1.1

=cut

sub moveAttachment {
    my( $web, $topic, $attachment, $newWeb, $newTopic, $newAttachment ) = @_;

    $newWeb ||= $web;
    $newTopic ||= $topic;
    $newAttachment ||= $attachment;

    return if( $newWeb eq $web &&
                 $newTopic eq $topic &&
                   $newAttachment eq $attachment );

    $TWiki::Plugins::SESSION->{store}->moveAttachment(
        $web, $topic, $attachment,
        $newWeb, $newTopic, $newAttachment,
        $TWiki::Plugins::SESSION->{user} );
}

=pod

---++ Assembling Pages

=cut

=pod

---+++ readTemplate( $name, $skin ) -> $text

Read a template or skin. Embedded [[%SYSTEMWEB%.TWikiTemplates][template directives]] get expanded
   * =$name= - Template name, e.g. ='view'=
   * =$skin= - Comma-separated list of skin names, optional, e.g. ='print'=
Return: =$text=    Template text

*Since:* TWiki::Plugins::VERSION 1.000 (7 Dec 2002)

=cut

sub readTemplate {
#   my( $name, $skin ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    return $TWiki::Plugins::SESSION->templates->readTemplate( @_ );
}

=pod

---+++ loadTemplate ( $name, $skin, $web ) -> $text

   * =$name= - template file name
   * =$skin= - comma-separated list of skins to use (default: current skin)
   * =$web= - the web to look in for topics that contain templates (default: current web)
Return: expanded template text (what's left after removal of all %TMPL:DEF% statements)

*Since:* TWiki::Plugins::VERSION 1.1

Reads a template and extracts template definitions, adding them to the
list of loaded templates, overwriting any previous definition.

How TWiki searches for templates is described in TWikiTemplates.

If template text is found, extracts include statements and fully expands them.

=cut

sub loadTemplate {
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    return $TWiki::Plugins::SESSION->templates->readTemplate( @_ );
}

=pod

---+++ expandTemplate( $def  ) -> $string

Do a %TMPL:P{$def}%, only expanding the template (not expanding any variables other than %TMPL)
   * =$def= - template name
Return: the text of the expanded template

*Since:* TWiki::Plugins::VERSION 1.1

A template is defined using a %TMPL:DEF% statement in a template
file. See the documentation on TWiki templates for more information.

=cut

sub expandTemplate {
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    return $TWiki::Plugins::SESSION->templates->expandTemplate( @_ );
}

=pod

---+++ writeHeader( $query, $contentLength )

Prints a basic content-type HTML header for text/html to standard out
   * =$query= - CGI query object. If not given, the default CGI query will be used (optional, in most cases you should _not_ pass this parameter)
   * =$contentLength= - Length of content (optional, in most cases you should _not_ pass this parameter)
Return:             none

*Since:* TWiki::Plugins::VERSION 1.000 (7 Dec 2002)

=cut

sub writeHeader {
    my( $query, $len ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    $TWiki::Plugins::SESSION->generateHTTPHeaders( $query );
}

=pod

---+++ redirectCgiQuery( $query, $url, $passthru )

Redirect to URL
   * =$query= - CGI query object. Ignored, only there for compatibility. The session CGI query object is used instead.
   * =$url=   - URL to redirect to
   * =$passthru= - enable passthrough.

Return:             none

Print output to STDOUT that will cause a 302 redirect to a new URL.
Nothing more should be printed to STDOUT after this method has been called.

The =$passthru= parameter allows you to pass the parameters that were passed
to the current query on to the target URL, as long as it is another URL on the
same TWiki installation. If =$passthru= is set to a true value, then TWiki
will save the current URL parameters, and then try to restore them on the
other side of the redirect. Parameters are stored on the server in a cache
file.

Note that if =$passthru= is set, then any parameters in =$url= will be lost
when the old parameters are restored. if you want to change any parameter
values, you will need to do that in the current CGI query before redirecting
e.g.
<verbatim>
my $query = TWiki::Func::getCgiQuery();
$query->param(-name => 'text', -value => 'Different text');
TWiki::Func::redirectCgiQuery(
  undef, TWiki::Func::getScriptUrl($web, $topic, 'edit'), 1);
</verbatim>
=$passthru= does nothing if =$url= does not point to a script in the current
TWiki installation.

*Since:* TWiki::Plugins::VERSION 1.000 (7 Dec 2002)

=cut

sub redirectCgiQuery {
    my( $query, $url, $passthru ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    return $TWiki::Plugins::SESSION->redirect( $url, $passthru );
}

=pod

---+++ addToHEAD( $id, $header, $requires )

Adds =$header= to the HTML header (the <head> tag).
This is useful for Plugins that want to include some javascript custom css.
   * =$id= - Unique ID to prevent the same HTML from being duplicated. Plugins should use a prefix to prevent name clashes (e.g EDITTABLEPLUGIN_JSCALENDAR)
   * =$header= - the HTML to be added to the <head> section. The HTML must be valid in a HEAD tag - no checks are performed.
   * =requires= optional, comma-separated list of id's of other head blocks this one depends on.
   
All TWiki variables present in =$header= will be expanded before being inserted into the =<head>= section.

Note that this is _not_ the same as the HTTP header, which is modified through the Plugins =modifyHeaderHandler=.

*Since:* TWiki::Plugins::VERSION 1.1

example:
<verbatim>
TWiki::Func::addToHEAD('PATTERN_STYLE','<link id="twikiLayoutCss" rel="stylesheet" type="text/css" href="%PUBURL%/TWiki/PatternSkin/layout.css" media="all" />');
</verbatim>

=cut=

sub addToHEAD {
    my( $tag, $header, $requires ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    $TWiki::Plugins::SESSION->addToHEAD( @_ );
}

=pod

---+++ expandCommonVariables( $text, $topic, $web, $meta ) -> $text

Expand all common =%<nop>VARIABLES%=
   * =$text=  - Text with variables to expand, e.g. ='Current user is %<nop>WIKIUSER%'=
   * =$topic= - Current topic name, e.g. ='WebNotify'=
   * =$web=   - Web name, optional, e.g. ='Main'=. The current web is taken if missing
   * =$meta=  - topic meta-data to use while expanding (Since TWiki::Plugins::VERSION 1.2)
Return: =$text=     Expanded text, e.g. ='Current user is <nop>TWikiGuest'=

*Since:* TWiki::Plugins::VERSION 1.000 (7 Dec 2002)

See also: expandVariablesOnTopicCreation

=cut

sub expandCommonVariables {
    my( $text, $topic, $web, $meta ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    $topic ||= $TWiki::Plugins::SESSION->{topicName};
    $web ||= $TWiki::Plugins::SESSION->{webName};
    return $TWiki::Plugins::SESSION->handleCommonTags(
        $text, $web, $topic, $meta );
}

=pod

---+++ renderText( $text, $web ) -> $text

Render text from TWiki markup into XHTML as defined in [[%SYSTEMWEB%.TextFormattingRules]]
   * =$text= - Text to render, e.g. ='*bold* text and =fixed font='=
   * =$web=  - Web name, optional, e.g. ='Main'=. The current web is taken if missing
Return: =$text=    XHTML text, e.g. ='&lt;b>bold&lt;/b> and &lt;code>fixed font&lt;/code>'=

*Since:* TWiki::Plugins::VERSION 1.000 (7 Dec 2002)

=cut

sub renderText {
#   my( $text, $web ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    return $TWiki::Plugins::SESSION->renderer->getRenderedVersion( @_ );
}

=pod

---+++ internalLink( $pre, $web, $topic, $label, $anchor, $createLink ) -> $text

Render topic name and link label into an XHTML link. Normally you do not need to call this funtion, it is called internally by =renderText()=
   * =$pre=        - Text occuring before the TWiki link syntax, optional
   * =$web=        - Web name, required, e.g. ='Main'=
   * =$topic=      - Topic name to link to, required, e.g. ='WebNotify'=
   * =$label=      - Link label, required. Usually the same as =$topic=, e.g. ='notify'=
   * =$anchor=     - Anchor, optional, e.g. ='#Jump'=
   * =$createLink= - Set to ='1'= to add question linked mark after topic name if topic does not exist;<br /> set to ='0'= to suppress link for non-existing topics
Return: =$text=          XHTML anchor, e.g. ='&lt;a href='/cgi-bin/view/Main/WebNotify#Jump'>notify&lt;/a>'=

*Since:* TWiki::Plugins::VERSION 1.000 (7 Dec 2002)

=cut

sub internalLink {
    my $pre = shift;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
#   my( $web, $topic, $label, $anchor, $anchor, $createLink ) = @_;
    return $pre . $TWiki::Plugins::SESSION->renderer->internalLink( @_ );
}

=pod

---++ E-mail

---+++ sendEmail ( $text, $retries ) -> $error

   * =$text= - text of the mail, including MIME headers
   * =$retries= - number of times to retry the send (default 1)
Send an e-mail specified as MIME format content. To specify MIME
format mails, you create a string that contains a set of header
lines that contain field definitions and a message body such as:
<verbatim>
To: liz@windsor.gov.uk
From: serf@hovel.net
CC: george@whitehouse.gov
Subject: Revolution

Dear Liz,

Please abolish the monarchy (with King George's permission, of course)

Thanks,

A. Peasant
</verbatim>
Leave a blank line between the last header field and the message body.

*Since:* TWiki::Plugins::VERSION 1.1

=cut

sub sendEmail {
    #my( $text, $retries ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    return $TWiki::Plugins::SESSION->net->sendEmail( @_ );
}

=pod

---+++ wikiToEmail( $wikiName ) -> $email

   * =$wikiname= - wiki name of the user
Get the e-mail address(es) of the named user. If the user has multiple
e-mail addresses (for example, the user is a group), then the list will
be comma-separated.

*Since:* TWiki::Plugins::VERSION 1.1

*Deprecated* in favour of wikinameToEmails, because this function only
returns a single email address, where a user may in fact have several.

Since TWiki 4.2.1, $wikiName may also be a login name.

=cut

sub wikiToEmail {
    my( $user ) = @_;
    my @emails = wikinameToEmails( $user );
    if (scalar(@emails)) {
        return $emails[0];
    }
    return '';
}

=pod

---++ Creating New Topics

=cut

=pod

---+++ expandVariablesOnTopicCreation ( $text ) -> $text

Expand the limited set of variables that are always expanded during topic creation
   * =$text= - the text to process
Return: text with variables expanded

*Since:* TWiki::Plugins::VERSION 1.1

Expands only the variables expected in templates that must be statically
expanded in new content.

The expanded variables are:
   * =%<nop>DATE%= Signature-format date
   * =%<nop>SERVERTIME%= See TWikiVariables
   * =%<nop>GMTIME%= See TWikiVariables
   * =%<nop>USERNAME%= Base login name
   * =%<nop>WIKINAME%= Wiki name
   * =%<nop>WIKIUSERNAME%= Wiki name with prepended web
   * =%<nop>URLPARAM{...}%= - Parameters to the current CGI query
   * =%<nop>NOP%= No-op

See also: expandVariables

=cut

sub expandVariablesOnTopicCreation {
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    return $TWiki::Plugins::SESSION->expandVariablesOnTopicCreation( shift, $TWiki::Plugins::SESSION->{user} );
}

=pod

---++ Special handlers

Special handlers can be defined to make functions in plugins behave as if they were built-in to TWiki.

=cut

=pod=

---+++ registerTagHandler( $var, \&fn, $syntax )

Should only be called from initPlugin.

Register a function to handle a simple variable. Handles both %<nop>VAR% and %<nop>VAR{...}%. Registered variables are treated the same as TWiki internal variables, and are expanded at the same time. This is a _lot_ more efficient than using the =commonTagsHandler=.
   * =$var= - The name of the variable, i.e. the 'MYVAR' part of %<nop>MYVAR%. The variable name *must* match /^[A-Z][A-Z0-9_]*$/ or it won't work.
   * =\&fn= - Reference to the handler function.
   * =$syntax= can be 'classic' (the default) or 'context-free'. 'classic' syntax is appropriate where you want the variable to support classic TWiki syntax i.e. to accept the standard =%<nop>MYVAR{ "unnamed" param1="value1" param2="value2" }%= syntax, as well as an unquoted default parameter, such as =%<nop>MYVAR{unquoted parameter}%=. If your variable will only use named parameters, you can use 'context-free' syntax, which supports a more relaxed syntax. For example, %MYVAR{param1=value1, value 2, param3="value 3", param4='value 5"}%

*Since:* TWiki::Plugins::VERSION 1.1

The variable handler function must be of the form:
<verbatim>
sub handler(\%session, \%params, $topic, $web)
</verbatim>
where:
   * =\%session= - a reference to the TWiki session object (may be ignored)
   * =\%params= - a reference to a TWiki::Attrs object containing parameters. This can be used as a simple hash that maps parameter names to values, with _DEFAULT being the name for the default parameter.
   * =$topic= - name of the topic in the query
   * =$web= - name of the web in the query
for example, to execute an arbitrary command on the server, you might do this:
<verbatim>
sub initPlugin{
   TWiki::Func::registerTagHandler('EXEC', \&boo);
}

sub boo {
    my( $session, $params, $topic, $web ) = @_;
    my $cmd = $params->{_DEFAULT};

    return "NO COMMAND SPECIFIED" unless $cmd;

    my $result = `$cmd 2>&1`;
    return $params->{silent} ? '' : $result;
}
}
</verbatim>
would let you do this:
=%<nop>EXEC{"ps -Af" silent="on"}%=

Registered tags differ from tags implemented using the old TWiki approach (text substitution in =commonTagsHandler=) in the following ways:
   * registered tags are evaluated at the same time as system tags, such as %SERVERTIME. =commonTagsHandler= is only called later, when all system tags have already been expanded (though they are expanded _again_ after =commonTagsHandler= returns).
   * registered tag names can only contain alphanumerics and _ (underscore)
   * registering a tag =FRED= defines both =%<nop>FRED{...}%= *and also* =%FRED%=.
   * registered tag handlers *cannot* return another tag as their only result (e.g. =return '%<nop>SERVERTIME%';=). It won't work.

=cut

sub registerTagHandler {
    my( $tag, $function, $syntax ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    # Use an anonymous function so it gets inlined at compile time.
    # Make sure we don't mangle the session reference.
    TWiki::registerTagHandler( $tag,
                               sub {
                                   my $record = $TWiki::Plugins::SESSION;
                                   $TWiki::Plugins::SESSION = $_[0];
                                   my $result = &$function( @_ );
                                   $TWiki::Plugins::SESSION = $record;
                                   return $result;
                               },
                               $syntax
                             );
}

=pod=

---+++ registerRESTHandler( $alias, \&fn, )

Should only be called from initPlugin.

Adds a function to the dispatch table of the REST interface 
   * =$alias= - The name .
   * =\&fn= - Reference to the function.

*Since:* TWiki::Plugins::VERSION 1.1

The handler function must be of the form:
<verbatim>
sub handler(\%session)
</verbatim>
where:
   * =\%session= - a reference to the TWiki session object (may be ignored)

From the REST interface, the name of the plugin must be used
as the subject of the invokation.

Example
-------

The EmptyPlugin has the following call in the initPlugin handler:
<verbatim>
   TWiki::Func::registerRESTHandler('example', \&restExample);
</verbatim>

This adds the =restExample= function to the REST dispatch table 
for the EmptyPlugin under the 'example' alias, and allows it 
to be invoked using the URL

=http://server:port/bin/rest/EmptyPlugin/example=

note that the URL

=http://server:port/bin/rest/EmptyPlugin/restExample=

(ie, with the name of the function instead of the alias) will not work.

=cut

sub registerRESTHandler {
    my( $alias, $function) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    my $plugin = caller;
    $plugin =~ s/.*:://; # strip off TWiki::Plugins:: prefix

    # Use an anonymous function so it gets inlined at compile time.
    # Make sure we don't mangle the session reference.
    TWiki::registerRESTHandler( $plugin,
                                $alias,
                               sub {
                                   my $record = $TWiki::Plugins::SESSION;
                                   $TWiki::Plugins::SESSION = $_[0];
                                   my $result = &$function( @_ );
                                   $TWiki::Plugins::SESSION = $record;
                                   return $result;
                               }
                             );
}

=pod

---+++ decodeFormatTokens($str) -> $unencodedString

TWiki has an informal standard set of tokens used in =format=
parameters that are used to block evaluation of paramater strings.
For example, if you were to write

=%<nop>MYTAG{format="%<nop>WURBLE%"}%=

then %<nop>WURBLE would be expanded *before* %<NOP>MYTAG is evaluated. To avoid
this TWiki uses escapes in the format string. For example:

=%<nop>MYTAG{format="$percntWURBLE$percnt"}%=

This lets you enter arbitrary strings into parameters without worrying that
TWiki will expand them before your plugin gets a chance to deal with them
properly. Once you have processed your tag, you will want to expand these
tokens to their proper value. That's what this function does.

| *Escape:* | *Expands To:* |
| =$n= or =$n()= | New line. Use =$n()= if followed by alphanumeric character, e.g. write =Foo$n()Bar= instead of =Foo$nBar= |
| =$nop= or =$nop()= | Is a "no operation". |
| =$quot= | Double quote (="=) |
| =$percnt= | Percent sign (=%=) |
| =$dollar= | Dollar sign (=$=) |

Note thath $quot, $percnt and $dollar all work *even if they are followed by
alphanumeric characters*. You have been warned!

*Since:* TWiki::Plugins::VERSION 1.2

=cut

sub decodeFormatTokens {
    return TWiki::expandStandardEscapes( @_ );
}

=pod

---++ Searching

=cut

=pod

---+++ searchInWebContent($searchString, $web, \@topics, \%options ) -> \%map

Search for a string in the content of a web. The search is over all content, including meta-data. Meta-data matches will be returned as formatted lines within the topic content (meta-data matches are returned as lines of the format %META:\w+{.*}%)
   * =$searchString= - the search string, in egrep format
   * =$web= - The web to search in
   * =\@topics= - reference to a list of topics to search
   * =\%option= - reference to an options hash
The =\%options= hash may contain the following options:
   * =type= - if =regex= will perform a egrep-syntax RE search (default '')
   * =casesensitive= - false to ignore case (defaulkt true)
   * =files_without_match= - true to return files only (default false). If =files_without_match= is specified, it will return on the first match in each topic (i.e. it will return only one match per topic, and will not return matching lines).

The return value is a reference to a hash which maps each matching topic
name to a list of the lines in that topic that matched the search,
as would be returned by 'grep'.

To iterate over the returned topics use:
<verbatim>
my $result = TWiki::Func::searchInWebContent( "Slimy Toad", $web, \@topics,
   { casesensitive => 0, files_without_match => 0 } );
foreach my $topic (keys %$result ) {
   foreach my $matching_line ( @{$result->{$topic}} ) {
      ...etc
</verbatim>

*Since:* TWiki::Plugins::VERSION 1.1

=cut

sub searchInWebContent {
    #my( $searchString, $web, $topics, $options ) = @_;

    return $TWiki::Plugins::SESSION->{store}->searchInWebContent( @_ );
}

=pod

---++ Plugin-specific file handling

=cut

=pod

---+++ getWorkArea( $pluginName ) -> $directorypath

Gets a private directory for Plugin use. The Plugin is entirely responsible
for managing this directory; TWiki will not read from it, or write to it.

The directory is guaranteed to exist, and to be writable by the webserver
user. By default it will *not* be web accessible.

The directory and it's contents are permanent, so Plugins must be careful
to keep their areas tidy.

*Since:* TWiki::Plugins::VERSION 1.1 (Dec 2005)

=cut

sub getWorkArea {
    my( $plugin ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    return $TWiki::Plugins::SESSION->{store}->getWorkArea( $plugin );
}

=pod

---+++ readFile( $filename ) -> $text

Read file, low level. Used for Plugin workarea.
   * =$filename= - Full path name of file
Return: =$text= Content of file, empty if not found

__NOTE:__ Use this function only for the Plugin workarea, *not* for topics and attachments. Use the appropriate functions to manipulate topics and attachments.

*Since:* TWiki::Plugins::VERSION 1.000 (07 Dec 2002)

=cut

sub readFile {
    my $name = shift;
    my $data = '';
    open( IN_FILE, "<$name" ) || return '';
    local $/ = undef; # set to read to EOF
    $data = <IN_FILE>;
    close( IN_FILE );
    $data = '' unless $data; # no undefined
    return $data;
}

=pod

---+++ saveFile( $filename, $text )

Save file, low level. Used for Plugin workarea.
   * =$filename= - Full path name of file
   * =$text=     - Text to save
Return:                none

__NOTE:__ Use this function only for the Plugin workarea, *not* for topics and attachments. Use the appropriate functions to manipulate topics and attachments.

*Since:* TWiki::Plugins::VERSION 1.000 (07 Dec 2002)

=cut

sub saveFile {
    my( $name, $text ) = @_;

    unless ( open( FILE, ">$name" ) )  {
        die "Can't create file $name - $!\n";
    }
    print FILE $text;
    close( FILE);
}

=pod

---++ General Utilities

=cut

=pod

---+++ getRegularExpression( $name ) -> $expr

Retrieves a TWiki predefined regular expression or character class.
   * =$name= - Name of the expression to retrieve.  See notes below
Return: String or precompiled regular expression matching as described below.

*Since:* TWiki::Plugins::VERSION 1.020 (9 Feb 2004)

__Note:__ TWiki internally precompiles several regular expressions to
represent various string entities in an <nop>I18N-compatible manner. Plugins
authors are encouraged to use these in matching where appropriate. The
following are guaranteed to be present. Others may exist, but their use
is unsupported and they may be removed in future TWiki versions.

In the table below, the expression marked type 'String' are intended for
use within character classes (i.e. for use within square brackets inside
a regular expression), for example:
<verbatim>
   my $upper = TWiki::Func::getRegularExpression('upperAlpha');
   my $alpha = TWiki::Func::getRegularExpression('mixedAlpha');
   my $capitalized = qr/[$upper][$alpha]+/;
</verbatim>
Those expressions marked type 'RE' are precompiled regular expressions that can be used outside square brackets. For example:
<verbatim>
   my $webRE = TWiki::Func::getRegularExpression('webNameRegex');
   my $isWebName = ( $s =~ m/$webRE/ );
</verbatim>

| *Name*         | *Matches*                        | *Type* |
| upperAlpha     | Upper case characters            | String |
| upperAlphaNum  | Upper case characters and digits | String |
| lowerAlpha     | Lower case characters            | String |
| lowerAlphaNum  | Lower case characters and digits | String |
| numeric        | Digits                           | String |
| mixedAlpha     | Alphabetic characters            | String |
| mixedAlphaNum  | Alphanumeric characters          | String |
| wikiWordRegex  | WikiWords                        | RE |
| webNameRegex   | User web names                   | RE |
| anchorRegex    | #AnchorNames                     | RE |
| abbrevRegex    | Abbreviations e.g. GOV, IRS      | RE |
| emailAddrRegex | email@address.com                | RE |
| tagNameRegex   | Standard variable names e.g. %<nop>THIS_BIT% (THIS_BIT only) | RE |

=cut

sub getRegularExpression {
    my ( $regexName ) = @_;
    return $TWiki::regex{$regexName};
}

=pod

---+++ normalizeWebTopicName($web, $topic) -> ($web, $topic)

Parse a web and topic name, supplying defaults as appropriate.
   * =$web= - Web name, identifying variable, or empty string
   * =$topic= - Topic name, may be a web.topic string, required.
Return: the parsed Web/Topic pair

*Since:* TWiki::Plugins::VERSION 1.1

| *Input*                               | *Return*  |
| <tt>( 'Web', 'Topic' ) </tt>          | <tt>( 'Web', 'Topic' ) </tt>  |
| <tt>( '', 'Topic' ) </tt>             | <tt>( 'Main', 'Topic' ) </tt>  |
| <tt>( '', '' ) </tt>                  | <tt>( 'Main', 'WebHome' ) </tt>  |
| <tt>( '', 'Web/Topic' ) </tt>         | <tt>( 'Web', 'Topic' ) </tt>  |
| <tt>( '', 'Web/Subweb/Topic' ) </tt>  | <tt>( 'Web/Subweb', 'Topic' ) </tt>  |
| <tt>( '', 'Web.Topic' ) </tt>         | <tt>( 'Web', 'Topic' ) </tt>  |
| <tt>( '', 'Web.Subweb.Topic' ) </tt>  | <tt>( 'Web/Subweb', 'Topic' ) </tt>  |
| <tt>( 'Web1', 'Web2.Topic' )</tt>     | <tt>( 'Web2', 'Topic' ) </tt>  |

Note that hierarchical web names (Web.SubWeb) are only available if hierarchical webs are enabled in =configure=.

The symbols %<nop>USERSWEB%, %<nop>SYSTEMWEB% and %<nop>DOCWEB% can be used in the input to represent the web names set in $cfg{UsersWebName} and $cfg{SystemWebName}. For example:
| *Input*                               | *Return* |
| <tt>( '%<nop>USERSWEB%', 'Topic' )</tt>     | <tt>( 'Main', 'Topic' ) </tt>  |
| <tt>( '%<nop>SYSTEMWEB%', 'Topic' )</tt>    | <tt>( 'TWiki', 'Topic' ) </tt>  |
| <tt>( '', '%<nop>DOCWEB%.Topic' )</tt>    | <tt>( 'TWiki', 'Topic' ) </tt>  |

=cut

sub normalizeWebTopicName {
    #my( $web, $topic ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    return $TWiki::Plugins::SESSION->normalizeWebTopicName( @_ );
}

=pod

---+++ StaticMethod sanitizeAttachmentName($fname) -> ($fileName, $origName)

Given a file namer, sanitise it according to the rules for transforming
attachment names. Returns
the sanitised name together with the basename before sanitisation.

Sanitation includes filtering illegal characters and mapping client
file names to legal server names.

*Since:* TWiki::Plugins::VERSION 1.2

=cut

sub sanitizeAttachmentName {
    require TWiki::Sandbox;
    return TWiki::Sandbox::sanitizeAttachmentName(@_);
}

=pod

---+++ spaceOutWikiWord( $word, $sep ) -> $text

Spaces out a wiki word by inserting a string (default: one space) between each word component.
With parameter $sep any string may be used as separator between the word components; if $sep is undefined it defaults to a space.

*Since:* TWiki::Plugins::VERSION 1.2

=cut

sub spaceOutWikiWord {
    #my ( $word, $sep ) = @_;
    return TWiki::spaceOutWikiWord(@_);
}

=pod

---+++ writeWarning( $text )

Log Warning that may require admin intervention to data/warning.txt
   * =$text= - Text to write; timestamp gets added
Return:            none

*Since:* TWiki::Plugins::VERSION 1.020 (16 Feb 2004)

=cut

sub writeWarning {
#   my( $text ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    my ($message)=@_;
    return $TWiki::Plugins::SESSION->writeWarning( "(".caller().") ".$message );
}

=pod

---+++ writeDebug( $text )

Log debug message to data/debug.txt
   * =$text= - Text to write; timestamp gets added
Return:            none

*Since:* TWiki::Plugins::VERSION 1.020 (16 Feb 2004)

=cut

sub writeDebug {
#   my( $text ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    return $TWiki::Plugins::SESSION->writeDebug( @_ );
}

=pod

---+++ formatTime( $time, $format, $timezone ) -> $text

Format the time in seconds into the desired time string
   * =$time=     - Time in epoc seconds
   * =$format=   - Format type, optional. Default e.g. ='31 Dec 2002 - 19:30'=. Can be ='$iso'= (e.g. ='2002-12-31T19:30Z'=), ='$rcs'= (e.g. ='2001/12/31 23:59:59'=, ='$http'= for HTTP header format (e.g. ='Thu, 23 Jul 1998 07:21:56 GMT'=), or any string with tokens ='$seconds, $minutes, $hours, $day, $wday, $month, $mo, $year, $ye, $tz'= for seconds, minutes, hours, day of month, day of week, 3 letter month, 2 digit month, 4 digit year, 2 digit year, timezone string, respectively
   * =$timezone= - either not defined (uses the displaytime setting), 'gmtime', or 'servertime'
Return: =$text=        Formatted time string
| Note:                  | if you used the removed formatGmTime, add a third parameter 'gmtime' |

*Since:* TWiki::Plugins::VERSION 1.020 (26 Feb 2004)

=cut

sub formatTime {
#   my ( $epSecs, $format, $timezone ) = @_;
    require TWiki::Time;
    return TWiki::Time::formatTime( @_ );
}

=pod

---+++ isTrue( $value, $default ) -> $boolean

Returns 1 if =$value= is true, and 0 otherwise. "true" means set to
something with a Perl true value, with the special cases that "off",
"false" and "no" (case insensitive) are forced to false. Leading and
trailing spaces in =$value= are ignored.

If the value is undef, then =$default= is returned. If =$default= is
not specified it is taken as 0.

*Since:* $TWiki::Plugins::VERSION 1.2

=cut

sub isTrue {
#   my ( $value, $default ) = @_;

    return TWiki::isTrue( @_ );
}

=pod

---+++ isValidWikiWord ( $text ) -> $boolean

Check for a valid WikiWord or WikiName
   * =$text= - Word to test

*Since:* TWiki::Plugins::VERSION 1.100 (Dec 2005)

=cut

sub isValidWikiWord {
   return TWiki::isValidWikiWord(@_);
}

=pod

---+++ extractParameters($attr ) -> %params

Extract all parameters from a variable string and returns a hash of parameters
   * =$attr= - Attribute string
Return: =%params=  Hash containing all parameters. The nameless parameter is stored in key =_DEFAULT=

*Since:* TWiki::Plugins::VERSION 1.025 (26 Aug 2004)

   * Example:
      * Variable: =%<nop>TEST{ 'nameless' name1="val1" name2="val2" }%=
      * First extract text between ={...}= to get: ='nameless' name1="val1" name2="val2"=
      * Then call this on the text: <br />
   * params = TWiki::Func::extractParameters( $text );=
      * The =%params= hash contains now: <br />
        =_DEFAULT => 'nameless'= <br />
        =name1 => "val1"= <br />
        =name2 => "val2"=

=cut

sub extractParameters {
    my( $attr ) = @_;
    require TWiki::Attrs;
    my $params = new TWiki::Attrs( $attr );
    # take out _RAW and _ERROR (compatibility)
    delete $params->{_RAW};
    delete $params->{_ERROR};
    return %$params;
}

=pod

---+++ extractNameValuePair( $attr, $name ) -> $value

Extract a named or unnamed value from a variable parameter string
- Note:              | Function TWiki::Func::extractParameters is more efficient for extracting several parameters
   * =$attr= - Attribute string
   * =$name= - Name, optional
Return: =$value=   Extracted value

*Since:* TWiki::Plugins::VERSION 1.000 (7 Dec 2002)

   * Example:
      * Variable: =%<nop>TEST{ 'nameless' name1="val1" name2="val2" }%=
      * First extract text between ={...}= to get: ='nameless' name1="val1" name2="val2"=
      * Then call this on the text: <br />
        =my $noname = TWiki::Func::extractNameValuePair( $text );= <br />
        =my $val1  = TWiki::Func::extractNameValuePair( $text, "name1" );= <br />
        =my $val2  = TWiki::Func::extractNameValuePair( $text, "name2" );=

=cut

sub extractNameValuePair {
    require TWiki::Attrs;
    return TWiki::Attrs::extractValue( @_ );
}

=pod

---++ Deprecated functions

From time-to-time, the TWiki developers will add new functions to the interface (either to TWikiFuncDotPm, or new handlers). Sometimes these improvements mean that old functions have to be deprecated to keep the code manageable. When this happens, the deprecated functions will be supported in the interface for at least one more TWiki release, and probably longer, though this cannot be guaranteed.

Updated plugins may still need to define deprecated handlers for compatibility with old TWiki versions. In this case, the plugin package that defines old handlers can suppress the warnings in %<nop>FAILEDPLUGINS%.

This is done by defining a map from the handler name to the =TWiki::Plugins= version _in which the handler was first deprecated_. For example, if we need to define the =endRenderingHandler= for compatibility with =TWiki::Plugins= versions before 1.1, we would add this to the plugin:
<verbatim>
package TWiki::Plugins::SinkPlugin;
use vars qw( %TWikiCompatibility );
$TWikiCompatibility{endRenderingHandler} = 1.1;
</verbatim>
If the currently-running TWiki version is 1.1 _or later_, then the _handler will not be called_ and _the warning will not be issued_. TWiki with versions of =TWiki::Plugins= before 1.1 will still call the handler as required.

The following functions are retained for compatibility only. You should
stop using them as soon as possible.

---+++ getScriptUrlPath( ) -> $path

Get script URL path

*DEPRECATED* since 1.1 - use =getScriptUrl= instead.

Return: =$path= URL path of TWiki scripts, e.g. ="/cgi-bin"=

*WARNING:* you are strongly recommended *not* to use this function, as the
{ScriptUrlPaths} URL rewriting rules will not apply to urls generated
using it.

*Since:* TWiki::Plugins::VERSION 1.000 (7 Dec 2002)

=cut

sub getScriptUrlPath {
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    return $TWiki::Plugins::SESSION->getScriptUrl( 0, '' );
}

=pod

---+++ getOopsUrl( $web, $topic, $template, $param1, $param2, $param3, $param4 ) -> $url

Compose fully qualified 'oops' dialog URL
   * =$web=                  - Web name, e.g. ='Main'=. The current web is taken if empty
   * =$topic=                - Topic name, e.g. ='WebNotify'=
   * =$template=             - Oops template name, e.g. ='oopsmistake'=. The 'oops' is optional; 'mistake' will translate to 'oopsmistake'.
   * =$param1= ... =$param4= - Parameter values for %<nop>PARAM1% ... %<nop>PARAMn% variables in template, optional
Return: =$url=                     URL, e.g. ="http://example.com:80/cgi-bin/oops.pl/ Main/WebNotify?template=oopslocked&amp;param1=joe"=

*DEPRECATED* since 1.1, the recommended approach is to throw an [[TWikiOopsExceptionDotPm][oops exception]].
<verbatim>
   use Error qw( :try );

   throw TWiki::OopsException(
      'toestuckerror',
      web => $web,
      topic => $topic,
      params => [ 'I got my toe stuck' ]);
</verbatim>
(this example will use the =oopstoestuckerror= template.)

If this is not possible (e.g. in a REST handler that does not trap the exception)
then you can use =getScriptUrl= instead:
<verbatim>
   my $url = TWiki::Func::getScriptUrl($web, $topic, 'oops',
            template => 'oopstoestuckerror',
            param1 => 'I got my toe stuck');
   TWiki::Func::redirectCgiQuery( undef, $url );
   return 0;
</verbatim>

*Since:* TWiki::Plugins::VERSION 1.000 (7 Dec 2002)

=cut

sub getOopsUrl {
    my( $web, $topic, $template, @params ) = @_;

    my $n = 1;
    @params = map { 'param'.($n++) => $_ } @params;
    return getScriptUrl( $web, $topic, 'oops',
                         template => $template,
                         @params );
}

=pod

---+++ permissionsSet( $web ) -> $boolean

Test if any access restrictions are set for this web, ignoring settings on
individual pages
   * =$web= - Web name, required, e.g. ='Sandbox'=

*Since:* TWiki::Plugins::VERSION 1.000 (27 Feb 2001)

*DEPRECATED* since 1.2 - use =getPreferencesValue= instead to determine
what permissions are set on the web, for example:
<verbatim>
foreach my $type qw( ALLOW DENY ) {
    foreach my $action qw( CHANGE VIEW ) {
        my $pref = $type . 'WEB' . $action;
        my $val = getPreferencesValue( $pref, $web ) || '';
        if( $val =~ /\S/ ) {
            print "$pref is set to $val on $web\n";
        }
    }
}
</verbatim>

=cut

sub permissionsSet {
    my( $web ) = @_;

    foreach my $type qw( ALLOW DENY ) {
        foreach my $action qw( CHANGE VIEW RENAME ) {
            my $pref = $type . 'WEB' . $action;
            my $val = getPreferencesValue( $pref, $web ) || '';
            return 1 if( $val =~ /\S/ );
        }
    }

    return 0;
}

=pod

---+++ getPublicWebList( ) -> @webs

*DEPRECATED* since 1.1 - use =getListOfWebs= instead.

Get list of all public webs, e.g. all webs that do not have the =NOSEARCHALL= flag set in the WebPreferences

Return: =@webs= List of all public webs, e.g. =( 'Main',  'Know', 'TWiki' )=

*Since:* TWiki::Plugins::VERSION 1.000 (07 Dec 2002)

=cut

sub getPublicWebList {
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    return $TWiki::Plugins::SESSION->{store}->getListOfWebs("user,public");
}

=pod

---+++ formatGmTime( $time, $format ) -> $text

*DEPRECATED* since 1.1 - use =formatTime= instead.

Format the time to GM time
   * =$time=   - Time in epoc seconds
   * =$format= - Format type, optional. Default e.g. ='31 Dec 2002 - 19:30'=, can be ='iso'= (e.g. ='2002-12-31T19:30Z'=), ='rcs'= (e.g. ='2001/12/31 23:59:59'=, ='http'= for HTTP header format (e.g. ='Thu, 23 Jul 1998 07:21:56 GMT'=)
Return: =$text=      Formatted time string

*Since:* TWiki::Plugins::VERSION 1.000 (7 Dec 2002)

=cut

sub formatGmTime {
#   my ( $epSecs, $format ) = @_;

    # FIXME: Write warning based on flag (disabled for now); indicate who is calling this function
    ## writeWarning( 'deprecated use of Func::formatGmTime' );

    require TWiki::Time;
    return TWiki::Time::formatTime( @_, 'gmtime' );
}

=pod

---+++ getDataDir( ) -> $dir

*DEPRECATED* since 1.1 - use the "Webs, Topics and Attachments" functions to manipulate topics instead

Get data directory (topic file root)

Return: =$dir= Data directory, e.g. ='/twiki/data'=

This function violates store encapsulation and is therefore *deprecated*.

*Since:* TWiki::Plugins::VERSION 1.000 (07 Dec 2002)

=cut

sub getDataDir {
    return $TWiki::cfg{DataDir};
}

=pod

---+++ getPubDir( ) -> $dir

*DEPRECATED* since 1.1 - use the "Webs, Topics and Attachments" functions to manipulateattachments instead

Get pub directory (file attachment root). Attachments are in =$dir/Web/TopicName=

Return: =$dir= Pub directory, e.g. ='/htdocs/twiki/pub'=

This function violates store encapsulation and is therefore *deprecated*.

Use =readAttachment= and =saveAttachment= instead.

*Since:* TWiki::Plugins::VERSION 1.000 (07 Dec 2002)

=cut

sub getPubDir {
    return $TWiki::cfg{PubDir};
}

=pod

---+++ checkDependencies( $moduleName, $dependenciesRef ) -> $error

*DEPRECATED* since 1.1 - use TWiki:Plugins.BuildContrib and define DEPENDENCIES that can be statically
evaluated at install time instead. It is a lot more efficient.

*Since:* TWiki::Plugins::VERSION 1.025 (01 Aug 2004)

=cut

sub checkDependencies {
    my ( $context, $deps ) = @_;
    my $report = '';
    my $depsOK = 1;
    foreach my $dep ( @$deps ) {
        my ( $ok, $ver ) = ( 1, 0 );
        my $msg = '';
        my $const = '';

        eval "require $dep->{package}";
        if ( $@ ) {
            $msg .= "it could not be found: $@";
            $ok = 0;
        } else {
            if ( defined( $dep->{constraint} ) ) {
                $const = $dep->{constraint};
                eval "\$ver = \$$dep->{package}::VERSION;";
                if ( $@ ) {
                    $msg .= "the VERSION of the package could not be found: $@";
                    $ok = 0;
                } else {
                    eval "\$ok = ( \$ver $const )";
                    if ( $@ || ! $ok ) {
                        $msg .= " $ver is currently installed: $@";
                        $ok = 0;
                    }
                }
            }
        }
        unless ( $ok ) {
            $report .= "WARNING: $dep->{package}$const is required for $context, but $msg\n";
            $depsOK = 0;
        }
    }
    return undef if( $depsOK );

    return $report;
}

1;

__DATA__

Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/

Copyright (C) 2000-2007 Peter Thoeny, peter@thoeny.org
and TWiki Contributors. All Rights Reserved. TWiki Contributors
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

---++ API History

---+++ twiki-20010901-release (Athens)
$TWiki::Plugins::VERSION 1.000
---++++ EmptyPlugin.pm
   * =commonTagsHandler($text, $topic, $web)=
   * =endRenderingHandler($text)=
   * =outsidePREHandler($text)=
   * =insidePREHandler($text)=
   * =startRenderingHandler($text, $web)=
---++++ Func.pm
   * =checkAccessPermission($type, $login, $topicText, $topicName, $webName) -> $boolean=
   * =expandCommonVariables($text, $topic, $web) -> $text=
   * =extractNameValuePair($attrs, $name) -> $value=
   * =formatGmTime($time) -> $text=
   * =getCgiQuery() -> $query=
   * =getDataDir() -> $dir=
   * =getDefaultUserName() -> $loginName=
   * =getMainWebname() -> $name=
   * =getOopsUrl($web, $topic, $template, @theParams) -> $url=
   * =getPreferencesFlag($key) -> $boolean=
   * =getPreferencesValue($key, $web) -> $value=
   * =getPublicWebList() -> @webs=
   * =getPubDir() -> $dir=
   * =getPubUrlPath() -> $path=
   * =getRevisionInfo($webName, $topic, $rev, $attachment) -> ($date, $user, $rev, $comment)=
   * =getScriptUrl($web, $topic, $script) -> $url=
   * =getScriptUrlPath() -> $path=
   * =getSessionValue($key) -> $value=
   * =getSkin() -> $skin=
   * =getTopicList($web) -> @topics=
   * =getTwikiWebname() -> $name=
   * =getUrlHost() -> $host=
   * =getViewUrl($web, $topic) -> $url=
   * =getWikiName() -> $wikiName=
   * =getWikiUserName($text) -> $wikiName=
   * =getWikiToolName() -> $name=
   * =internalLink($preamble, $web, $topic, $linkText, $anchor, $createLink) -> $text=
   * =isGuest() -> $boolean=
   * =permissionsSet($web) -> $boolean=
   * =readFile($filename) -> $text=
   * =readTemplate($name, $skin) -> $text=
   * =readTopic($webName, $topic) -> ($meta, $text)=
   * =redirectCgiQuery($query, $url)=
   * =renderText($text, $web) -> $text=
   * =saveFile($filename, $text)=
   * =setSessionValue($key, $value)=
   * =topicExists($web, $topic) -> $boolean=
   * =userToWikiName($user, $dontAddWeb) -> $wikiName=
   * =webExists($web) -> $boolean=
   * =wikiToUserName($wiki) -> $loginName=
   * =writeDebug($text)=
   * =writeHeader($query)=
   * =writeWarning($text)=

---+++ TWikiRelease01Feb2003 (Beijing)
$TWiki::Plugins::VERSION 1.010
---++++ EmptyPlugin.pm
   * =afterEditHandler($text, $topic, $web)=
   * =beforeEditHandler($text, $topic, $web)=
   * =beforeSaveHandler($text, $topic, $web)=
   * =initializeUserHandler($loginName, $url, $pathInfo)=
   * =redirectCgiQueryHandler($query, $url)=
   * =registrationHandler($web, $wikiName, $loginName)=
   * =writeHeaderHandler($query)=
---++++ Func.pm
   * =checkTopicEditLock($web, $topic) ->($oopsUrl, $loginName, $unlockTime)=
   * =readTopicText($web, $topic, $rev, $ignorePermissions) -> $text=
   * =saveTopicText($web, $topic, $text, $ignorePermissions, $dontNotify) -> $oopsUrl=
   * =setTopicEditLock($web, $topic, $lock) -> $oopsUrl=

---+++ twiki-20040902-release (Cairo)
$TWiki::Plugins::VERSION 1.025
---++++ EmptyPlugin.pm
   * =afterCommonTagsHandler($text, $topic, $web)=
   * =afterSaveHandler($text, $topic, $web, $error)=
   * =beforeCommonTagsHandler($text, $topic, $web)=
   * =earlyInitPlugin()=
---++++ Func.pm
   * =afterAttachmentSaveHandler(\%attrHash, $topic, $web, $error)=
   * =beforeAttachmentSaveHandler(\%attrHash, $topic, $web)=
   * =checkDependencies($moduleName, $dependenciesRef) -> $error=
   * =extractParameters($attr) -> %params=
   * =formatTime($time, $format, $timezone) -> $text=
   * =getPluginPreferencesFlag($key) -> $boolean=
   * =getPluginPreferencesValue($key) -> $value=
   * =getRegularExpression($regexName) -> $pattern=

---+++ TWikiRelease04x00x00 (Dakar)
$TWiki::Plugins::VERSION 1.1
---++++ EmptyPlugin.pm
   * =mergeHandler($diff, $old, $new, \%info) -> $text=
   * =modifyHeaderHandler(\%headers, $query)=
   * =postRenderingHandler($text)=
   * =preRenderingHandler($text, \%map)=
   * =renderFormFieldForEditHandler($name, $type, $size, $value, $attributes, $possibleValues) -> $html=
   * =renderWikiWordHandler($linkText, $hasExplicitLinkLabel, $web, $topic) -> $linkText=

   * <strike> =endRenderingHandler($text)= </strike>
   * <strike> =startRenderingHandler($text, $web)= </strike>
---++++ Func.pm
   * =addToHEAD($id, $header)=
   * =attachmentExists($web, $topic, $attachment) -> $boolean=
   * =clearSessionValue($key) -> $boolean=
   * =checkDependencies($moduleName, $dependenciesRef) -> $error=
   * =createWeb($newWeb, $baseWeb, $opts)=
   * =expandTemplate($def ) -> $string=
   * =expandVariablesOnTopicCreation($text) -> $text=
   * =getContext() -> \%hash=
   * =getListOfWebs($filter) -> @webs=
   * =getScriptUrl($web, $topic, $script, @params) -> $url=
   * =getRevisionAtTime($web, $topic, $time) -> $rev=
   * =getWorkArea($pluginName) -> $directorypath=
   * =isValidWikiWord($text) -> $boolean=
   * =loadTemplate($name, $skin, $web) -> $text=
   * =moveAttachment($web, $topic, $attachment, $newWeb, $newTopic, $newAttachment)=
   * =moveTopic($web, $topic, $newWeb, $newTopic)=
   * =moveWeb($oldName, $newName)=
   * =normalizeWebTopicName($web, $topic) ->($web, $topic)=
   * =readAttachment($web, $topic, $name, $rev) -> $data=
   * =registerRESTHandler($alias, \&fn,)=
   * =registerTagHandler($var, \&fn, $syntax)=
   * =saveAttachment($web, $topic, $attachment, $opts)=
   * =saveTopic($web, $topic, $meta, $text, $options) -> $error=
   * =searchInWebContent($searchString, $web, \@topics, \%options) -> \%map=
   * =sendEmail($text, $retries) -> $error=
   * =wikiToEmail($wikiName) -> $email=
   * =writeHeader($query, $contentLength)=

   * <strike> =checkDependencies($moduleName, $dependenciesRef) -> $error= </strike>
   * <strike> =formatGmTime($time, $format) -> $text= </strike>
   * <strike> =getDataDir() -> $dir= </strike>
   * <strike> =getOopsUrl( $web, $topic, $template, @params ) -> $url= </strike>
   * <strike> =getPubDir() -> $dir= </strike>
   * <strike> =getPublicWebList() -> @webs= </strike>
   * <strike> =getScriptUrlPath() -> $path= </strike>

---+++ TWikiRelease04x00x01
$TWiki::Plugins::VERSION 1.1
---++++ EmptyPlugin.pm
   * =afterSaveHandler($text, $topic, $web, $error, $meta)=
   * =beforeSaveHandler($text, $topic, $web, $meta)=
---++++ Func.pm

---+++ TWikiRelease04x01x00
$TWiki::Plugins::VERSION 1.11
---++++ EmptyPlugin.pm
   * =afterRenameHandler($oldWeb, $oldTopic, $oldAttachment, $newWeb, $newTopic, $newAttachment)=
---++++ Func.pm
No changes

---+++ TWikiRelease04x02x00
$TWiki::Plugins::VERSION 1.2
---++++ EmptyPlugin.pm
   * =afterCommonTagsHandler($text, $topic, $web, $meta)=
   * =beforeCommonTagsHandler($text, $topic, $web, $meta)=
   * =commonTagsHandler($text, $topic, $web, $included, $meta)=
---++++ Func.pm
   * =decodeFormatTokens($str) -> $unencodedString=
   * =eachChangeSince($web, $time) -> $iterator=
   * =eachGroup() -> $iterator=
   * =eachGroupMember($group) -> $iterator=
   * =eachMembership($wikiname) -> $iterator=
   * =eachUser() -> $iterator=
   * =emailToWikiNames($email, $dontAddWeb) -> @wikiNames=
   * =expandCommonVariables($text, $topic, $web, $meta) -> $text=
   * =getCanonicalUserID( $user ) -> $cUID=
   * =getExternalResource($url) -> $response=
   * =getSessionKeys() -> @keys=
   * =isAnAdmin($login) -> $boolean=
   * =isGroup($group) -> $boolean=
   * =isGroupMember($group, $login) -> $boolean=
   * =isTrue($value, $default) -> $boolean=
   * =popTopicContext()=
   * =pushTopicContext($web, $topic)=
   * =sanitizeAttachmentName($fname) -> ($fileName, $origName)=
   * =setPreferencesValue($name, $val)=
   * =spaceOutWikiWord($word, $sep) -> $text=
   * =wikiNameToEmails($wikiname) -> @emails=
   * <strike> =permissionsSet($web) -> $boolean= </strike>
   * <strike> =getOopsUrl( $web, $topic, $template, $param1, $param2, $param3, $param4 ) -> $url= </strike>

