# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Func

_Interface for Foswiki extensions developers_

This module defines the main interfaces that extensions
can use to interact with the Foswiki engine and content.

Refer to =lib/Foswiki/Plugins/EmptyPlugin.pm= for a template Plugin
and starter documentation on how to write a Plugin.

Plugins should *only* call methods in packages documented in
System.DevelopingPlugins. If you use
functions in other Foswiki libraries you risk creating a security hole, and
you will probably need to change your plugin when you upgrade Foswiki.

%TOC%

API version $Date$ (revision $Rev$)

*Since* _date_ indicates where functions or parameters have been added since
the baseline of the API (TWiki release 4.2.3). The _date_ indicates the
earliest date of a Foswiki release that will support that function or
parameter.

*Deprecated* _date_ indicates where a function or parameters has been
[[http://en.wikipedia.org/wiki/Deprecation][deprecated]]. Deprecated
functions will still work, though they should
_not_ be called in new plugins and should be replaced in older plugins
as soon as possible. Deprecated parameters are simply ignored in Foswiki
releases after _date_.

*Until* _date_ indicates where a function or parameter has been removed.
The _date_ indicates the latest date at which Foswiki releases still supported
the function or parameter.

=cut

# THIS PACKAGE IS PART OF THE PUBLISHED API USED BY EXTENSION AUTHORS.
# DO NOT CHANGE THE EXISTING APIS (well thought out extensions are OK)
# AND ENSURE ALL POD DOCUMENTATION IS COMPLETE AND ACCURATE.
#
# Deprecated functions should not be removed, but should be moved to to the
# deprecated functions section.

package Foswiki::Func;

use strict;
use Error qw( :try );
use Assert;

require Foswiki;
require Foswiki::Plugins;

=begin TML

---++ Environment

=cut

=begin TML

---+++ getSkin( ) -> $skin

Get the skin path, set by the =SKIN= and =COVER= preferences variables or the =skin= and =cover= CGI parameters

Return: =$skin= Comma-separated list of skins, e.g. ='gnu,tartan'=. Empty string if none.

=cut

sub getSkin {
    ASSERT($Foswiki::Plugins::SESSION) if DEBUG;

    return $Foswiki::Plugins::SESSION->getSkin();
}

=begin TML

---+++ getUrlHost( ) -> $host

Get protocol, domain and optional port of script URL

Return: =$host= URL host, e.g. ="http://example.com:80"=

=cut

sub getUrlHost {
    ASSERT($Foswiki::Plugins::SESSION) if DEBUG;

    return $Foswiki::Plugins::SESSION->{urlHost};
}

=begin TML

---+++ getScriptUrl( $web, $topic, $script, ... ) -> $url

Compose fully qualified URL
   * =$web=    - Web name, e.g. ='Main'=
   * =$topic=  - Topic name, e.g. ='WebNotify'=
   * =$script= - Script name, e.g. ='view'=
   * =...= - an arbitrary number of name=>value parameter pairs that will be url-encoded and added to the url. The special parameter name '#' is reserved for specifying an anchor. e.g. <tt>getScriptUrl('x','y','view','#'=>'XXX',a=>1,b=>2)</tt> will give <tt>.../view/x/y?a=1&b=2#XXX</tt>

Return: =$url=       URL, e.g. ="http://example.com:80/cgi-bin/view.pl/Main/WebNotify"=

=cut

sub getScriptUrl {
    my $web    = shift;
    my $topic  = shift;
    my $script = shift;
    ASSERT($Foswiki::Plugins::SESSION) if DEBUG;

    return $Foswiki::Plugins::SESSION->getScriptUrl( 1, $script, $web, $topic,
        @_ );
}

=begin TML

---+++ getViewUrl( $web, $topic ) -> $url

Compose fully qualified view URL
   * =$web=   - Web name, e.g. ='Main'=. The current web is taken if empty
   * =$topic= - Topic name, e.g. ='WebNotify'=
Return: =$url=      URL, e.g. ="http://example.com:80/cgi-bin/view.pl/Main/WebNotify"=

=cut

sub getViewUrl {
    my ( $web, $topic ) = @_;
    ASSERT($Foswiki::Plugins::SESSION) if DEBUG;

    $web ||= $Foswiki::Plugins::SESSION->{webName}
      || $Foswiki::cfg{UsersWebName};
    return getScriptUrl( $web, $topic, 'view' );
}

=begin TML

---+++ getPubUrlPath( ) -> $path

Get pub URL path

Return: =$path= URL path of pub directory, e.g. ="/pub"=

=cut

sub getPubUrlPath {
    return $Foswiki::cfg{PubUrlPath};
}

=begin TML

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
my $response = Foswiki::Func::getExternalResource($url);
if (!$response->is_error() && $response->isa('HTTP::Response')) {
    ... other methods of HTTP::Response may be called
} else {
    ... only the methods listed above may be called
}
</verbatim>

=cut

sub getExternalResource {
    my ($url) = @_;
    ASSERT($Foswiki::Plugins::SESSION) if DEBUG;
    ASSERT( defined $url ) if DEBUG;

    return $Foswiki::Plugins::SESSION->net->getExternalResource($url);
}

=begin TML

---+++ getCgiQuery( ) -> $query

Get CGI query object. Important: Plugins cannot assume that scripts run under CGI, Plugins must always test if the CGI query object is set

Return: =$query= CGI query object; or 0 if script is called as a shell script

=cut

sub getCgiQuery {
    ASSERT($Foswiki::Plugins::SESSION) if DEBUG;
    return $Foswiki::Plugins::SESSION->{request};
}

=begin TML

---+++ getSessionKeys() -> @keys
Get a list of all the names of session variables. The list is unsorted.

Session keys are stored and retrieved using =setSessionValue= and
=getSessionValue=.

=cut

sub getSessionKeys {
    ASSERT($Foswiki::Plugins::SESSION) if DEBUG;
    my $hash =
      $Foswiki::Plugins::SESSION->{users}->{loginManager}->getSessionValues();
    return keys %{$hash};
}

=begin TML

---+++ getSessionValue( $key ) -> $value

Get a session value from the client session module
   * =$key= - Session key
Return: =$value=  Value associated with key; empty string if not set

=cut

sub getSessionValue {

    #   my( $key ) = @_;
    ASSERT($Foswiki::Plugins::SESSION) if DEBUG;

    return $Foswiki::Plugins::SESSION->{users}->{loginManager}
      ->getSessionValue(@_);
}

=begin TML

---+++ setSessionValue( $key, $value ) -> $boolean

Set a session value.
   * =$key=   - Session key
   * =$value= - Value associated with key
Return: true if function succeeded

=cut

sub setSessionValue {

    #   my( $key, $value ) = @_;
    ASSERT($Foswiki::Plugins::SESSION) if DEBUG;

    $Foswiki::Plugins::SESSION->{users}->{loginManager}->setSessionValue(@_);
}

=begin TML

---+++ clearSessionValue( $key ) -> $boolean

Clear a session value that was set using =setSessionValue=.
   * =$key= - name of value stored in session to be cleared. Note that
   you *cannot* clear =AUTHUSER=.
Return: true if the session value was cleared

=cut

sub clearSessionValue {
    ASSERT($Foswiki::Plugins::SESSION) if DEBUG;

    return $Foswiki::Plugins::SESSION->{users}->{loginManager}
      ->clearSessionValue(@_);
}

=begin TML

---+++ getContext() -> \%hash

Get a hash of context identifiers representing the currently active
context.

The context is a set of identifiers that are set
during specific phases of processing. For example, each of
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
   Foswiki::Func::getContext()->{'MyID'} = 1;
   ...
</verbatim>
This can be used in !SecondPlugin.pm like this:
<verbatim>
sub initPlugin {
   if( Foswiki::Func::getContext()->{'MyID'} ) {
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

=cut

sub getContext {
    ASSERT($Foswiki::Plugins::SESSION) if DEBUG;
    return $Foswiki::Plugins::SESSION->{context};
}

=begin TML

---+++ pushTopicContext($web, $topic)
   * =$web= - new web
   * =$topic= - new topic
Change the Foswiki context so it behaves as if it was processing =$web.$topic=
from now on. All the preferences will be reset to those of the new topic.
Note that if the new topic is not readable by the logged in user due to
access control considerations, there will *not* be an exception. It is the
duty of the caller to check access permissions before changing the topic.

It is the duty of the caller to restore the original context by calling
=popTopicContext=.

Note that this call does *not* re-initialise plugins, so if you have used
global variables to remember the web and topic in =initPlugin=, then those
values will be unchanged.

=cut

sub pushTopicContext {
    my $twiki = $Foswiki::Plugins::SESSION;
    ASSERT($twiki) if DEBUG;
    my ( $web, $topic ) = $twiki->normalizeWebTopicName(@_);
    my $old = {
        web   => $twiki->{webName},
        topic => $twiki->{topicName},
        mark  => $twiki->{prefs}->mark()
    };

    push( @{ $twiki->{_FUNC_PREFS_STACK} }, $old );
    $twiki->{webName}   = $web;
    $twiki->{topicName} = $topic;
    $twiki->{prefs}->pushWebPreferences($web);
    $twiki->{prefs}->pushPreferences( $web, $topic, 'TOPIC' );
    $twiki->{prefs}->pushPreferenceValues( 'SESSION',
        $twiki->{users}->{loginManager}->getSessionValues() );
}

=begin TML

---+++ popTopicContext()

Returns the Foswiki context to the state it was in before the
=pushTopicContext= was called.

=cut

sub popTopicContext {
    ASSERT($Foswiki::Plugins::SESSION) if DEBUG;
    my $twiki = $Foswiki::Plugins::SESSION;
    ASSERT( scalar( @{ $twiki->{_FUNC_PREFS_STACK} } ) ) if DEBUG;
    my $old = pop( @{ $twiki->{_FUNC_PREFS_STACK} } );
    $twiki->{prefs}->restore( $old->{mark} );
    $twiki->{webName}   = $old->{web};
    $twiki->{topicName} = $old->{topic};
}

=begin TML

---++ Preferences

=cut

=begin TML

---+++ getPreferencesValue( $key, $web ) -> $value

Get a preferences value for the currently requested context, from the currently request topic, its web and the site.
   * =$key= - Preference name
   * =$web= - Name of web, optional. if defined, we shortcircuit to the WebPreferences (and its Sitewide defaults)
Return: =$value=  Preferences value; empty string if not set

   * Example for preferences setting:
      * WebPreferences topic has: =* Set WEBBGCOLOR = #FFFFC0=
      * =my $webColor = Foswiki::Func::getPreferencesValue( 'WEBBGCOLOR', 'Sandbox' );=

   * Example for MyPlugin setting:
      * if the %SYSTEMWEB%.MyPlugin topic has: =* Set COLOR = red=
      * Use ="MYPLUGIN_COLOR"= for =$key=
      * =my $color = Foswiki::Func::getPreferencesValue( "MYPLUGIN_COLOR" );=
      
*NOTE:* If =$NO_PREFS_IN_TOPIC= is enabled in the plugin, then
preferences set in the plugin topic will be ignored.

=cut

sub getPreferencesValue {
    my ( $key, $web ) = @_;
    ASSERT($Foswiki::Plugins::SESSION) if DEBUG;
    if ($web) {
        return $Foswiki::Plugins::SESSION->{prefs}
          ->getWebPreferencesValue( $key, $web );
    }
    else {
        return $Foswiki::Plugins::SESSION->{prefs}->getPreferencesValue($key);
    }
}

=begin TML

---+++ getPluginPreferencesValue( $key ) -> $value

Get a preferences value from your Plugin
   * =$key= - Plugin Preferences key w/o PLUGINNAME_ prefix.
Return: =$value=  Preferences value; empty string if not set

__Note__: This function will will *only* work when called from the Plugin.pm file itself. it *will not work* if called from a sub-package (e.g. Foswiki::Plugins::MyPlugin::MyModule)

*NOTE:* If =$NO_PREFS_IN_TOPIC= is enabled in the plugin, then
preferences set in the plugin topic will be ignored.

=cut

sub getPluginPreferencesValue {
    my ($key) = @_;
    ASSERT($Foswiki::Plugins::SESSION) if DEBUG;
    my $package = caller;
    $package =~ s/.*:://;    # strip off Foswiki::Plugins:: prefix
    return $Foswiki::Plugins::SESSION->{prefs}
      ->getPreferencesValue("\U$package\E_$key");
}

=begin TML

---+++ getPreferencesFlag( $key, $web ) -> $value

Get a preferences flag from Foswiki or from a Plugin
   * =$key= - Preferences key
   * =$web= - Name of web, optional. Current web if not specified; does not apply to settings of Plugin topics
Return: =$value=  Preferences flag ='1'= (if set), or ="0"= (for preferences values ="off"=, ="no"= and ="0"=)

   * Example for Plugin setting:
      * MyPlugin topic has: =* Set SHOWHELP = off=
      * Use ="MYPLUGIN_SHOWHELP"= for =$key=
      * =my $showHelp = Foswiki::Func::getPreferencesFlag( "MYPLUGIN_SHOWHELP" );=

*NOTE:* If =$NO_PREFS_IN_TOPIC= is enabled in the plugin, then
preferences set in the plugin topic will be ignored.

=cut

sub getPreferencesFlag {

    #   my( $key, $web ) = @_;
    my $t = getPreferencesValue(@_);
    return Foswiki::isTrue($t);
}

=begin TML

---+++ getPluginPreferencesFlag( $key ) -> $boolean

Get a preferences flag from your Plugin
   * =$key= - Plugin Preferences key w/o PLUGINNAME_ prefix.
Return: false for preferences values ="off"=, ="no"= and ="0"=, or values not set at all. True otherwise.

__Note__: This function will will *only* work when called from the Plugin.pm file itself. it *will not work* if called from a sub-package (e.g. Foswiki::Plugins::MyPlugin::MyModule)

*NOTE:* If =$NO_PREFS_IN_TOPIC= is enabled in the plugin, then
preferences set in the plugin topic will be ignored.

=cut

sub getPluginPreferencesFlag {
    my ($key) = @_;
    my $package = caller;
    $package =~ s/.*:://;    # strip off Foswiki::Plugins:: prefix
    return getPreferencesFlag("\U$package\E_$key");
}

=begin TML

---+++ setPreferencesValue($name, $val)

Set the preferences value so that future calls to getPreferencesValue will
return this value, and =%$name%= will expand to the preference when used in
future variable expansions.

The preference only persists for the rest of this request. Finalised
preferences cannot be redefined using this function.

Returns 1 if the preference was defined, and 0 otherwise.

=cut

sub setPreferencesValue {
    return $Foswiki::Plugins::SESSION->{prefs}->setPreferencesValue(@_);
}

=begin TML

---++ User Handling and Access Control
---+++ getDefaultUserName( ) -> $loginName
Get default user name as defined in the configuration as =DefaultUserLogin=

Return: =$loginName= Default user name, e.g. ='guest'=

=cut

sub getDefaultUserName {
    return $Foswiki::cfg{DefaultUserLogin};
}

=begin TML

---+++ getCanonicalUserID( $user ) -> $cUID
   * =$user= can be a login, wikiname or web.wikiname
Return the cUID of the specified user. A cUID is a unique identifier which
is assigned by Foswiki for each user.
BEWARE: While the default TopicUserMapping uses a cUID that looks like a user's
LoginName, some characters are modified to make them compatible with rcs.
Other usermappings may use other conventions - the !JoomlaUserMapping
for example, has cUIDs like 'JoomlaeUserMapping_1234'.

If $user is undefined, it assumes the currently logged-in user.

Return: =$cUID=, an internal unique and portable escaped identifier for
registered users. This may be autogenerated for an authenticated but
unregistered user.

=cut

sub getCanonicalUserID {
    my $user = shift;
    return $Foswiki::Plugins::SESSION->{user} unless ($user);
    ASSERT($Foswiki::Plugins::SESSION) if DEBUG;
    my $cUID;
    if ($user) {
        $cUID = $Foswiki::Plugins::SESSION->{users}->getCanonicalUserID($user);
        if ( !$cUID ) {

            # Not a login name or a wiki name. Is it a valid cUID?
            my $ln = $Foswiki::Plugins::SESSION->{users}->getLoginName($user);
            $cUID = $user if defined $ln && $ln ne 'unknown';
        }
    }
    else {
        $cUID = $Foswiki::Plugins::SESSION->{user};
    }
    return $cUID;
}

=begin TML

---+++ getWikiName( $user ) -> $wikiName

return the WikiName of the specified user
if $user is undefined Get Wiki name of logged in user

   * $user can be a cUID, login, wikiname or web.wikiname

Return: =$wikiName= Wiki Name, e.g. ='JohnDoe'=

=cut

sub getWikiName {
    my $user = shift;
    ASSERT($Foswiki::Plugins::SESSION) if DEBUG;
    my $cUID = getCanonicalUserID($user);
    unless ( defined $cUID ) {
        my ( $w, $u ) =
          normalizeWebTopicName( $Foswiki::cfg{UsersWebName}, $user );
        return $u;
    }
    return $Foswiki::Plugins::SESSION->{users}->getWikiName($cUID);
}

=begin TML 
 
---+++ getWikiUserName( $user ) -> $wikiName

return the userWeb.WikiName of the specified user
if $user is undefined Get Wiki name of logged in user

   * $user can be a cUID, login, wikiname or web.wikiname

Return: =$wikiName= Wiki Name, e.g. ="Main.JohnDoe"=

=cut

sub getWikiUserName {
    my $user = shift;
    ASSERT($Foswiki::Plugins::SESSION) if DEBUG;
    my $cUID = getCanonicalUserID($user);
    unless ( defined $cUID ) {
        my ( $w, $u ) =
          normalizeWebTopicName( $Foswiki::cfg{UsersWebName}, $user );
        return "$w.$u";
    }
    return $Foswiki::Plugins::SESSION->{users}->webDotWikiName($cUID);
}

=begin TML

---+++ wikiToUserName( $id ) -> $loginName
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
    my ($wiki) = @_;
    ASSERT($Foswiki::Plugins::SESSION) if DEBUG;
    return '' unless $wiki;

    my $cUID = getCanonicalUserID($wiki);
    if ($cUID) {
        my $login = $Foswiki::Plugins::SESSION->{users}->getLoginName($cUID);
        return undef if !$login || $login eq 'unknown';
        return $login;
    }
    return undef;
}

=begin TML

---+++ userToWikiName( $loginName, $dontAddWeb ) -> $wikiName
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
    my ( $login, $dontAddWeb ) = @_;
    return '' unless $login;
    ASSERT($Foswiki::Plugins::SESSION) if DEBUG;
    my $users = $Foswiki::Plugins::SESSION->{users};
    my $user  = getCanonicalUserID($login);
    return (
          $dontAddWeb
        ? $login
        : ( $Foswiki::cfg{UsersWebName} . '.' . $login )
    ) unless $users->userExists($user);
    return $users->getWikiName($user) if $dontAddWeb;
    return $users->webDotWikiName($user);
}

=begin TML

---+++ emailToWikiNames( $email, $dontAddWeb ) -> @wikiNames
   * =$email= - email address to look up
   * =$dontAddWeb= - Do not add web prefix if ="1"=
Find the wikinames of all users who have the given email address as their
registered address. Since several users could register with the same email
address, this returns a list of wikinames rather than a single wikiname.

=cut

sub emailToWikiNames {
    my ( $email, $dontAddWeb ) = @_;
    ASSERT($email) if DEBUG;

    my %matches;
    my $users = $Foswiki::Plugins::SESSION->{users};
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

---+++ wikinameToEmails( $user ) -> @emails
   * =$user= - wikiname of user to look up
Returns the registered email addresses of the named user. If $user is
undef, returns the registered email addresses for the logged-in user.

$user may also be a group.

=cut

sub wikinameToEmails {
    my ($wikiname) = @_;
    if ($wikiname) {
        if ( isGroup($wikiname) ) {
            return $Foswiki::Plugins::SESSION->{users}->getEmails($wikiname);
        }
        else {
            my $uids =
              $Foswiki::Plugins::SESSION->{users}
              ->findUserByWikiName($wikiname);
            my @em = ();
            foreach my $user (@$uids) {
                push( @em,
                    $Foswiki::Plugins::SESSION->{users}->getEmails($user) );
            }
            return @em;
        }
    }
    else {
        my $user = $Foswiki::Plugins::SESSION->{user};
        return $Foswiki::Plugins::SESSION->{users}->getEmails($user);
    }
}

=begin TML

---+++ isGuest( ) -> $boolean

Test if logged in user is a guest (WikiGuest)

=cut

sub isGuest {
    ASSERT($Foswiki::Plugins::SESSION) if DEBUG;
    return $Foswiki::Plugins::SESSION->{user} eq
      $Foswiki::Plugins::SESSION->{users}
      ->getCanonicalUserID( $Foswiki::cfg{DefaultUserLogin} );
}

=begin TML

---+++ isAnAdmin( $id ) -> $boolean

Find out if the user is an admin or not. If the user is not given,
the currently logged-in user is assumed.
   * $id can be either a login name or a WikiName

=cut

sub isAnAdmin {
    my $user = shift;
    return $Foswiki::Plugins::SESSION->{users}
      ->isAdmin( getCanonicalUserID($user) );
}

=begin TML

---+++ isGroupMember( $group, $id ) -> $boolean

Find out if $id is in the named group. e.g.
<verbatim>
if( Foswiki::Func::isGroupMember( "HesperionXXGroup", "jordi" )) {
    ...
}
</verbatim>
If =$user= is =undef=, it defaults to the currently logged-in user.

   * $id can be a login name or a WikiName

=cut

sub isGroupMember {
    my ( $group, $user ) = @_;
    my $users = $Foswiki::Plugins::SESSION->{users};

    return () unless $users->isGroup($group);
    if ($user) {

        #my $login = wikiToUserName( $user );
        #return 0 unless $login;
        $user = getCanonicalUserID($user);
    }
    else {
        $user = $Foswiki::Plugins::SESSION->{user};
    }
    return $users->isInGroup( $user, $group );
}

=begin TML

---+++ eachUser() -> $iterator
Get an iterator over the list of all the registered users *not* including
groups. The iterator will return each wiki name in turn (e.g. 'FredBloggs').

Use it as follows:
<verbatim>
    my $iterator = Foswiki::Func::eachUser();
    while ($it->hasNext()) {
        my $user = $it->next();
        # $user is a wikiname
    }
</verbatim>

*WARNING* on large sites, this could be a long list!

=cut

sub eachUser {
    my $it = $Foswiki::Plugins::SESSION->{users}->eachUser();
    $it->{process} = sub {
        return $Foswiki::Plugins::SESSION->{users}->getWikiName( $_[0] );
    };
    return $it;
}

=begin TML

---+++ eachMembership($id) -> $iterator
   * =$id= - WikiName or login name of the user.
     If =$id= is =undef=, defaults to the currently logged-in user.
Get an iterator over the names of all groups that the user is a member of.

=cut

sub eachMembership {
    my ($user) = @_;
    my $users = $Foswiki::Plugins::SESSION->{users};

    if ($user) {
        my $login = wikiToUserName($user);
        return 0 unless $login;
        $user = getCanonicalUserID($login);
    }
    else {
        $user = $Foswiki::Plugins::SESSION->{user};
    }

    return $users->eachMembership($user);
}

=begin TML

---+++ eachGroup() -> $iterator
Get an iterator over all groups.

Use it as follows:
<verbatim>
    my $iterator = Foswiki::Func::eachGroup();
    while ($it->hasNext()) {
        my $group = $it->next();
        # $group is a group name e.g. AdminGroup
    }
</verbatim>

*WARNING* on large sites, this could be a long list!

=cut

sub eachGroup {
    my $session = $Foswiki::Plugins::SESSION;
    my $it      = $session->{users}->eachGroup();
    return $it;
}

=begin TML

---+++ isGroup( $group ) -> $boolean

Checks if =$group= is the name of a user group.

=cut

sub isGroup {
    my ($group) = @_;

    return $Foswiki::Plugins::SESSION->{users}->isGroup($group);
}

=begin TML

---+++ eachGroupMember($group) -> $iterator
Get an iterator over all the members of the named group. Returns undef if
$group is not a valid group.

Use it as follows:
<verbatim>
    my $iterator = Foswiki::Func::eachGroupMember('RadioheadGroup');
    while ($it->hasNext()) {
        my $user = $it->next();
        # $user is a wiki name e.g. 'TomYorke', 'PhilSelway'
    }
</verbatim>

*WARNING* on large sites, this could be a long list!

=cut

sub eachGroupMember {
    my $user    = shift;
    my $session = $Foswiki::Plugins::SESSION;
    return undef
      unless $Foswiki::Plugins::SESSION->{users}->isGroup($user);
    my $it = $Foswiki::Plugins::SESSION->{users}->eachGroupMember($user);
    $it->{process} = sub {
        return $Foswiki::Plugins::SESSION->{users}->getWikiName( $_[0] );
    };
    return $it;
}

=begin TML

---+++ checkAccessPermission( $type, $id, $text, $topic, $web, $meta ) -> $boolean

Check access permission for a topic based on the
[[%SYSTEMWEB%.AccessControl]] rules
   * =$type=     - Access type, required, e.g. ='VIEW'=, ='CHANGE'=.
   * =$id=  - WikiName of remote user, required, e.g. ="RickShaw"=.
     $id may also be a login name.
     If =$id= is '', 0 or =undef= then access is *always permitted*.
   * =$text=     - Topic text, optional. If 'perl false' (undef, 0 or ''),
     topic =$web.$topic= is consulted. =$text= may optionally contain embedded
     =%META:PREFERENCE= tags. Provide this parameter if:
      1 You are setting different access controls in the text to those defined
      in the stored topic,
      1 You already have the topic text in hand, and want to help avoid
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
earlier releases.

*Tip* if you want, you can use this method to check your own access control types. For example, if you:
   * Set ALLOWTOPICSPIN = IncyWincy
in =ThatWeb.ThisTopic=, then a call to =checkAccessPermission('SPIN', 'IncyWincy', undef, 'ThisTopic', 'ThatWeb', undef)= will return =true=.

=cut

sub checkAccessPermission {
    my ( $type, $user, $text, $topic, $web, $meta ) = @_;
    return 1 unless ($user);
    ASSERT($Foswiki::Plugins::SESSION) if DEBUG;
    $text = undef unless $text;
    my $cUID = getCanonicalUserID($user)
      || getCanonicalUserID( $Foswiki::cfg{DefaultUserLogin} );
    return $Foswiki::Plugins::SESSION->security->checkAccessPermission( $type,
        $cUID, $text, $meta, $topic, $web );
}

=begin TML

---++ Webs, Topics and Attachments

=cut

=begin TML

---+++ getListOfWebs( $filter [, $web] ) -> @webs

   * =$filter= - spec of web types to recover
Gets a list of webs, filtered according to the spec in the $filter,
which may include one of:
   1 'user' (for only user webs)
   2 'template' (for only template webs i.e. those starting with "_")
=$filter= may also contain the word 'public' which will further filter
out webs that have NOSEARCHALL set on them.
'allowed' filters out webs the current user can't read.
   * =$web= - (since NextWiki 1.0.0) name of web to get list of subwebs for. Defaults to the root.

For example, the deprecated getPublicWebList function can be duplicated
as follows:
<verbatim>
   my @webs = Foswiki::Func::getListOfWebs( "user,public" );
</verbatim>

=cut

sub getListOfWebs {
    ASSERT($Foswiki::Plugins::SESSION) if DEBUG;
    return $Foswiki::Plugins::SESSION->{store}->getListOfWebs(@_);
}

=begin TML

---+++ webExists( $web ) -> $boolean

Test if web exists
   * =$web= - Web name, required, e.g. ='Sandbox'=

=cut

sub webExists {

    #   my( $web ) = @_;
    ASSERT($Foswiki::Plugins::SESSION) if DEBUG;
    return $Foswiki::Plugins::SESSION->{store}->webExists(@_);
}

=begin TML

---+++ createWeb( $newWeb, $baseWeb, $opts )

   * =$newWeb= is the name of the new web.
   * =$baseWeb= is the name of an existing web (a template web). If the base web is a system web, all topics in it will be copied into the new web. If it is a normal web, only topics starting with 'Web' will be copied. If no base web is specified, an empty web (with no topics) will be created. If it is specified but does not exist, an error will be thrown.
   * =$opts= is a ref to a hash that contains settings to be modified in
the web preferences topic in the new web.

<verbatim>
use Error qw( :try );
use Foswiki::AccessControlException;

try {
    Foswiki::Func::createWeb( "Newweb" );
} catch Error::Simple with {
    my $e = shift;
    # see documentation on Error::Simple
} catch Foswiki::AccessControlException with {
    my $e = shift;
    # see documentation on Foswiki::AccessControlException
} otherwise {
    ...
};
</verbatim>

=cut

sub createWeb {
    ASSERT($Foswiki::Plugins::SESSION) if DEBUG;
    $Foswiki::Plugins::SESSION->{store}
      ->createWeb( $Foswiki::Plugins::SESSION->{user}, @_ );
}

=begin TML

---+++ moveWeb( $oldName, $newName )

Move (rename) a web.

<verbatim>
use Error qw( :try );
use Foswiki::AccessControlException;

try {
    Foswiki::Func::moveWeb( "Oldweb", "Newweb" );
} catch Error::Simple with {
    my $e = shift;
    # see documentation on Error::Simple
} catch Foswiki::AccessControlException with {
    my $e = shift;
    # see documentation on Foswiki::AccessControlException
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
    ASSERT($Foswiki::Plugins::SESSION) if DEBUG;
    return $Foswiki::Plugins::SESSION->{store}
      ->moveWeb( @_, $Foswiki::Plugins::SESSION->{user} );

}

=begin TML

---+++ eachChangeSince($web, $time) -> $iterator

Get an iterator over the list of all the changes in the given web between
=$time= and now. $time is a time in seconds since 1st Jan 1970, and is not
guaranteed to return any changes that occurred before (now - 
{Store}{RememberChangesFor}). {Store}{RememberChangesFor}) is a
setting in =configure=. Changes are returned in *most-recent-first*
order.

Use it as follows:
<verbatim>
    my $iterator = Foswiki::Func::eachChangeSince(
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
    my ( $web, $time ) = @_;
    ASSERT($Foswiki::Plugins::SESSION) if DEBUG;
    ASSERT( $Foswiki::Plugins::SESSION->{store}->webExists($web) ) if DEBUG;

    my $iterator =
      $Foswiki::Plugins::SESSION->{store}->eachChange( $web, $time );
    return $iterator;
}

=begin TML

---+++ getTopicList( $web ) -> @topics

Get list of all topics in a web
   * =$web= - Web name, required, e.g. ='Sandbox'=
Return: =@topics= Topic list, e.g. =( 'WebChanges',  'WebHome', 'WebIndex', 'WebNotify' )=

=cut

sub getTopicList {

    #   my( $web ) = @_;
    ASSERT($Foswiki::Plugins::SESSION) if DEBUG;
    return $Foswiki::Plugins::SESSION->{store}->getTopicNames(@_);
}

=begin TML

---+++ topicExists( $web, $topic ) -> $boolean

Test if topic exists
   * =$web=   - Web name, optional, e.g. ='Main'=.
   * =$topic= - Topic name, required, e.g. ='TokyoOffice'=, or ="Main.TokyoOffice"=

$web and $topic are parsed as described in the documentation for =normalizeWebTopicName=.
Specifically, the %USERSWEB% is used if $web is not specified and $topic has no web specifier.
To get an expected behaviour it is recommened to specify the current web for $web; don't leave it empty.

=cut

sub topicExists {
    my ( $web, $topic ) = $Foswiki::Plugins::SESSION->normalizeWebTopicName(@_);
    ASSERT($Foswiki::Plugins::SESSION) if DEBUG;
    return $Foswiki::Plugins::SESSION->{store}->topicExists( $web, $topic );
}

=begin TML

---+++ checkTopicEditLock( $web, $topic, $script ) -> ( $oopsUrl, $loginName, $unlockTime )

Check if a lease has been taken by some other user.
   * =$web= Web name, e.g. ="Main"=, or empty
   * =$topic= Topic name, e.g. ="MyTopic"=, or ="Main.MyTopic"=
Return: =( $oopsUrl, $loginName, $unlockTime )= - The =$oopsUrl= for calling redirectCgiQuery(), user's =$loginName=, and estimated =$unlockTime= in minutes, or ( '', '', 0 ) if no lease exists.
   * =$script= The script to invoke when continuing with the edit

=cut

sub checkTopicEditLock {
    my ( $web, $topic, $script ) = @_;
    ASSERT($Foswiki::Plugins::SESSION) if DEBUG;

    ( $web, $topic ) = normalizeWebTopicName( $web, $topic );
    $script ||= 'edit';

    my $lease = $Foswiki::Plugins::SESSION->{store}->getLease( $web, $topic );
    if ($lease) {
        my $remain  = $lease->{expires} - time();
        my $session = $Foswiki::Plugins::SESSION;

        if ( $remain > 0 ) {
            my $who = $lease->{user};
            require Foswiki::Time;
            my $past = Foswiki::Time::formatDelta( time() - $lease->{taken},
                $Foswiki::Plugins::SESSION->i18n );
            my $future = Foswiki::Time::formatDelta( $lease->{expires} - time(),
                $Foswiki::Plugins::SESSION->i18n );
            my $url = getScriptUrl(
                $web, $topic, 'oops',
                template => 'oopsleaseconflict',
                def      => 'lease_active',
                param1   => $who,
                param2   => $past,
                param3   => $future,
                param4   => $script
            );
            my $login = $session->{users}->getLoginName($who);
            return ( $url, $login, $remain / 60 );
        }
    }
    return ( '', '', 0 );
}

=begin TML

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

=cut

sub setTopicEditLock {
    my ( $web, $topic, $lock ) = @_;
    ASSERT($Foswiki::Plugins::SESSION) if DEBUG;
    my $session = $Foswiki::Plugins::SESSION;
    my $store   = $session->{store};
    if ($lock) {
        $store->setLease( $web, $topic, $session->{user},
            $Foswiki::cfg{LeaseLength} );
    }
    else {
        $store->clearLease( $web, $topic );
    }
    return '';
}

=begin TML

---+++ saveTopic( $web, $topic, $meta, $text, $options )

   * =$web= - web for the topic
   * =$topic= - topic name
   * =$meta= - reference to Foswiki::Meta object
   * =$text= - text of the topic (without embedded meta-data!!!
   * =\%options= - ref to hash of save options
     =\%options= may include:
     | =dontlog= | don't log this change in twiki log |
     | =forcenewrevision= | force the save to increment the revision counter |
     | =minor= | True if this is a minor change, and is not to be notified |
     | =comment= | Comment relating to the save |
For example,
<verbatim>
my( $meta, $text ) = Foswiki::Func::readTopic( $web, $topic );
$text =~ s/APPLE/ORANGE/g;
Foswiki::Func::saveTopic( $web, $topic, $meta, $text, { forcenewrevision => 1 } );
</verbatim>

__Note:__ Plugins handlers ( e.g. =beforeSaveHandler= ) will be called as
appropriate.

In the event of an error an exception will be thrown. Callers can elect
to trap the exceptions thrown, or allow them to propagate to the calling
environment. May throw Foswiki::OopsException, Foswiki::AccessControlException or Error::Simple.

=cut

sub saveTopic {
    my ( $web, $topic, $meta, $text, $options ) = @_;
    ASSERT($Foswiki::Plugins::SESSION) if DEBUG;

    return $Foswiki::Plugins::SESSION->{store}
      ->saveTopic( $Foswiki::Plugins::SESSION->{user},
        $web, $topic, $text, $meta, $options );

}

=begin TML

---+++ saveTopicText( $web, $topic, $text, $ignorePermissions, $dontNotify ) -> $oopsUrl

Save topic text, typically obtained by readTopicText(). Topic data usually includes meta data; the file attachment meta data is replaced by the meta data from the topic file if it exists.
   * =$web=                - Web name, e.g. ='Main'=, or empty
   * =$topic=              - Topic name, e.g. ='MyTopic'=, or ="Main.MyTopic"=
   * =$text=               - Topic text to save, assumed to include meta data
   * =$ignorePermissions=  - Set to ="1"= if checkAccessPermission() is already performed and OK
   * =$dontNotify=         - Set to ="1"= if not to notify users of the change
Return: =$oopsUrl=               Empty string if OK; the =$oopsUrl= for calling redirectCgiQuery() in case of error

This method is a lot less efficient and much more dangerous than =saveTopic=.

<verbatim>
my $text = Foswiki::Func::readTopicText( $web, $topic );

# check for oops URL in case of error:
if( $text =~ /^http.*?\/oops/ ) {
    Foswiki::Func::redirectCgiQuery( $query, $text );
    return;
}
# do topic text manipulation like:
$text =~ s/old/new/g;
# do meta data manipulation like:
$text =~ s/(META\:FIELD.*?name\=\"TopicClassification\".*?value\=\")[^\"]*/$1BugResolved/;
$oopsUrl = Foswiki::Func::saveTopicText( $web, $topic, $text ); # save topic text
</verbatim>

=cut

sub saveTopicText {
    my ( $web, $topic, $text, $ignorePermissions, $dontNotify ) = @_;
    ASSERT($Foswiki::Plugins::SESSION) if DEBUG;

    my $session = $Foswiki::Plugins::SESSION;

    # check access permission
    unless (
        $ignorePermissions
        || $session->security->checkAccessPermission(
            'CHANGE', $session->{user}, undef, undef, $topic, $web
        )
      )
    {
        my @plugin = caller();
        return getScriptUrl(
            $web, $topic, 'oops',
            template => 'oopsaccessdenied',
            def      => 'topic_access',
            param1   => 'in',
            param2   => $plugin[0]
        );
    }

    return getScriptUrl(
        $web, $topic, 'oops',
        template => 'oopsattention',
        def      => 'save_error',
        param1   => 'No text'
    ) unless ( defined $text );

    # extract meta data and merge old attachment meta data
    require Foswiki::Meta;
    my $meta = new Foswiki::Meta( $session, $web, $topic, $text );

    $meta->remove('FILEATTACHMENT');

    my ( $oldMeta, $oldText ) =
      $session->{store}->readTopic( undef, $web, $topic, undef );
    $meta->copyFrom( $oldMeta, 'FILEATTACHMENT' );

    # save topic
    my $error =
      $session->{store}
      ->saveTopic( $session->{user}, $web, $topic, $meta->text(), $meta,
        { notify => $dontNotify } );
    return getScriptUrl(
        $web, $topic, 'oops',
        template => 'oopsattention',
        def      => 'save_error',
        param1   => $error
    ) if ($error);
    return '';
}

=begin TML

---+++ moveTopic( $web, $topic, $newWeb, $newTopic )

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
use Error qw( :try );

try {
    moveTopic( "Work", "TokyoOffice", "Trash", "ClosedOffice" );
} catch Error::Simple with {
    my $e = shift;
    # see documentation on Error::Simple
} catch Foswiki::AccessControlException with {
    my $e = shift;
    # see documentation on Foswiki::AccessControlException
} otherwise {
    ...
};
</verbatim>

=cut

sub moveTopic {
    my ( $web, $topic, $newWeb, $newTopic ) = @_;
    $newWeb   ||= $web;
    $newTopic ||= $topic;

    return if ( $newWeb eq $web && $newTopic eq $topic );

    my $session = $Foswiki::Plugins::SESSION;
    my $store   = $session->{store};
    $store->moveTopic( $web, $topic, $newWeb, $newTopic,
        $Foswiki::Plugins::SESSION->{user} );
    my ( $meta, $text ) = $store->readTopic( undef, $newWeb, $newTopic );

    $meta->put(
        'TOPICMOVED',
        {
            from => $web . '.' . $topic,
            to   => $newWeb . '.' . $newTopic,
            date => time(),
            by   => $session->{user},
        }
    );

    $store->saveTopic( $session->{user}, $newWeb, $newTopic, $text, $meta,
        { minor => 1, comment => 'rename' } );

}

=begin TML

---+++ getRevisionInfo($web, $topic, $rev, $attachment ) -> ( $date, $user, $rev, $comment ) 

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
    ASSERT($Foswiki::Plugins::SESSION) if DEBUG;
    my ( $date, $user, $rev, $comment ) =
      $Foswiki::Plugins::SESSION->{store}->getRevisionInfo(@_);
    $user = $Foswiki::Plugins::SESSION->{users}->getWikiName($user);
    return ( $date, $user, $rev, $comment );
}

=begin TML

---+++ getRevisionAtTime( $web, $topic, $time ) -> $rev

Get the revision number of a topic at a specific time.
   * =$web= - web for topic
   * =$topic= - topic
   * =$time= - time (in epoch secs) for the rev
Return: Single-digit revision number, or undef if it couldn't be determined
(either because the topic isn't that old, or there was a problem)

=cut

sub getRevisionAtTime {
    ASSERT($Foswiki::Plugins::SESSION) if DEBUG;
    return $Foswiki::Plugins::SESSION->{store}->getRevisionAtTime(@_);
}

=begin TML

---+++ readTopic( $web, $topic, $rev ) -> ( $meta, $text )

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

    #my( $web, $topic, $rev ) = @_;
    ASSERT($Foswiki::Plugins::SESSION) if DEBUG;

    return $Foswiki::Plugins::SESSION->{store}->readTopic( undef, @_ );
}

=begin TML

---+++ readTopicText( $web, $topic, $rev, $ignorePermissions ) -> $text

Read topic text, including meta data
   * =$web=                - Web name, e.g. ='Main'=, or empty
   * =$topic=              - Topic name, e.g. ='MyTopic'=, or ="Main.MyTopic"=
   * =$rev=                - Topic revision to read, optional. Specify the minor part of the revision, e.g. ="5"=, not ="1.5"=; the top revision is returned if omitted or empty.
   * =$ignorePermissions=  - Set to ="1"= if checkAccessPermission() is already performed and OK; an oops URL is returned if user has no permission
Return: =$text=                  Topic text with embedded meta data; an oops URL for calling redirectCgiQuery() is returned in case of an error

This method is more efficient than =readTopic=, but returns meta-data embedded in the text. Plugins authors must be very careful to avoid damaging meta-data. You are recommended to use readTopic instead, which is a lot safer.

=cut

sub readTopicText {
    my ( $web, $topic, $rev, $ignorePermissions ) = @_;
    ASSERT($Foswiki::Plugins::SESSION) if DEBUG;

    my $user;
    $user = $Foswiki::Plugins::SESSION->{user}
      unless defined($ignorePermissions);

    my $text;
    try {
        $text =
          $Foswiki::Plugins::SESSION->{store}
          ->readTopicRaw( $user, $web, $topic, $rev );
    }
    catch Foswiki::AccessControlException with {
        my $e = shift;
        $text = getScriptUrl(
            $web, $topic, 'oops',
            template => 'oopsaccessdenied',
            def      => 'topic_access',
            param1   => $e->{mode},
            param2   => $e->{reason}
        );
    };

    return $text;
}

=begin TML

---+++ attachmentExists( $web, $topic, $attachment ) -> $boolean

Test if attachment exists
   * =$web=   - Web name, optional, e.g. =Main=.
   * =$topic= - Topic name, required, e.g. =TokyoOffice=, or =Main.TokyoOffice=
   * =$attachment= - attachment name, e.g.=logo.gif=
$web and $topic are parsed as described in the documentation for =normalizeWebTopicName=.

=cut

sub attachmentExists {
    my ( $web, $topic, $attachment ) = @_;
    ASSERT($Foswiki::Plugins::SESSION) if DEBUG;

    ( $web, $topic ) =
      $Foswiki::Plugins::SESSION->normalizeWebTopicName( $web, $topic );
    return $Foswiki::Plugins::SESSION->{store}
      ->attachmentExists( $web, $topic, $attachment );
}

=begin TML

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
Foswiki::AccessControlException. Permissions are checked for the current user.

<verbatim>
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

=cut

sub readAttachment {
    ASSERT($Foswiki::Plugins::SESSION) if DEBUG;
    my $result;

    #    try {
    $result =
      $Foswiki::Plugins::SESSION->{store}
      ->readAttachment( $Foswiki::Plugins::SESSION->{user}, @_ );

    #    } catch Error::Simple with {
    #    };
    return $result;
}

=begin TML

---+++ saveAttachment( $web, $topic, $attachment, \%opts )

   * =$web= - web for topic
   * =$topic= - topic to atach to
   * =$attachment= - name of the attachment
   * =\%opts= - Ref to hash of options
=\%opts= may include:
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
        Foswiki::Func::saveAttachment( $web, $topic, 'image.gif',
                                     { file => 'image.gif',
                                       comment => 'Picture of Health',
                                       hide => 1 } );
   } catch Error::Simple with {
      # see documentation on Error
   } otherwise {
      ...
   };
</verbatim>

=cut

sub saveAttachment {
    my ( $web, $topic, $name, $data ) = @_;
    ASSERT($Foswiki::Plugins::SESSION) if DEBUG;
    my $result = undef;

    try {
        $Foswiki::Plugins::SESSION->{store}
          ->saveAttachment( $web, $topic, $name,
            $Foswiki::Plugins::SESSION->{user}, $data );
    }
    catch Error::Simple with {
        $result = shift->{-text};
    };

    return $result;
}

=begin TML

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

Rename an attachment to $Foswiki::cfg{TrashWebName}.TrashAttament to delete it.

<verbatim>
use Error qw( :try );

try {
   # move attachment between topics
   moveAttachment( "Countries", "Germany", "AlsaceLorraine.dat",
                     "Countries", "France" );
   # Note destination attachment name is defaulted to the same as source
} catch Foswiki::AccessControlException with {
   my $e = shift;
   # see documentation on Foswiki::AccessControlException
} catch Error::Simple with {
   my $e = shift;
   # see documentation on Error::Simple
};
</verbatim>

=cut

sub moveAttachment {
    my ( $web, $topic, $attachment, $newWeb, $newTopic, $newAttachment ) = @_;

    $newWeb        ||= $web;
    $newTopic      ||= $topic;
    $newAttachment ||= $attachment;

    return
      if ( $newWeb eq $web
        && $newTopic eq $topic
        && $newAttachment eq $attachment );

    $Foswiki::Plugins::SESSION->{store}
      ->moveAttachment( $web, $topic, $attachment, $newWeb, $newTopic,
        $newAttachment, $Foswiki::Plugins::SESSION->{user} );
}

=begin TML

---++ Assembling Pages

=cut

=begin TML

---+++ readTemplate( $name, $skin ) -> $text

Read a template or skin. Embedded [[%SYSTEMWEB%.SkinTemplates][template directives]] get expanded
   * =$name= - Template name, e.g. ='view'=
   * =$skin= - Comma-separated list of skin names, optional, e.g. ='print'=
Return: =$text=    Template text

=cut

sub readTemplate {

    #   my( $name, $skin ) = @_;
    ASSERT($Foswiki::Plugins::SESSION) if DEBUG;
    return $Foswiki::Plugins::SESSION->templates->readTemplate(@_);
}

=begin TML

---+++ loadTemplate ( $name, $skin, $web ) -> $text

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
    ASSERT($Foswiki::Plugins::SESSION) if DEBUG;
    return $Foswiki::Plugins::SESSION->templates->readTemplate(@_);
}

=begin TML

---+++ expandTemplate( $def  ) -> $string

Do a %TMPL:P{$def}%, only expanding the template (not expanding any variables other than %TMPL)
   * =$def= - template name
Return: the text of the expanded template

A template is defined using a %TMPL:DEF% statement in a template
file. See the documentation on Foswiki templates for more information.

=cut

sub expandTemplate {
    ASSERT($Foswiki::Plugins::SESSION) if DEBUG;
    return $Foswiki::Plugins::SESSION->templates->expandTemplate(@_);
}

=begin TML

---+++ writeHeader()

Prints a basic content-type HTML header for text/html to standard out.

=cut

sub writeHeader {
    ASSERT($Foswiki::Plugins::SESSION) if DEBUG;
    $Foswiki::Plugins::SESSION->generateHTTPHeaders();
}

=begin TML

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
same installation. If =$passthru= is set to a true value, then Foswiki
will save the current URL parameters, and then try to restore them on the
other side of the redirect. Parameters are stored on the server in a cache
file.

Note that if =$passthru= is set, then any parameters in =$url= will be lost
when the old parameters are restored. if you want to change any parameter
values, you will need to do that in the current CGI query before redirecting
e.g.
<verbatim>
my $query = Foswiki::Func::getCgiQuery();
$query->param(-name => 'text', -value => 'Different text');
Foswiki::Func::redirectCgiQuery(
  undef, Foswiki::Func::getScriptUrl($web, $topic, 'edit'), 1);
</verbatim>
=$passthru= does nothing if =$url= does not point to a script in the current
Foswiki installation.

=cut

sub redirectCgiQuery {
    my ( $query, $url, $passthru ) = @_;
    ASSERT($Foswiki::Plugins::SESSION) if DEBUG;
    return $Foswiki::Plugins::SESSION->redirect( $url, $passthru );
}

=begin TML

---+++ addToHEAD( $id, $header, $requires )

Adds =$header= to the HTML header (the <head> tag).
This is useful for Plugins that want to include some javascript custom css.
   * =$id= - Unique ID to prevent the same HTML from being duplicated. Plugins should use a prefix to prevent name clashes (e.g EDITTABLEPLUGIN_JSCALENDAR)
   * =$header= - the HTML to be added to the <head> section. The HTML must be valid in a HEAD tag - no checks are performed.
   * =requires= optional, comma-separated list of id's of other head blocks this one depends on.

All macros present in =$header= will be expanded before being inserted into the =<head>= section.

Note that this is _not_ the same as the HTTP header, which is modified through the Plugins =modifyHeaderHandler=.

Example:
<verbatim>
Foswiki::Func::addToHEAD('PATTERN_STYLE','<link id="foswikiLayoutCss" rel="stylesheet" type="text/css" href="%PUBURL%/Foswiki/PatternSkin/layout.css" media="all" />');
</verbatim>

=cut=

sub addToHEAD {
    my ( $tag, $header, $requires ) = @_;
    ASSERT($Foswiki::Plugins::SESSION) if DEBUG;

    $Foswiki::Plugins::SESSION->addToHEAD(@_);
}

=begin TML

---+++ expandCommonVariables( $text, $topic, $web, $meta ) -> $text

Expand all common =%<nop>VARIABLES%=
   * =$text=  - Text with variables to expand, e.g. ='Current user is %<nop>WIKIUSER%'=
   * =$topic= - Current topic name, e.g. ='WebNotify'=
   * =$web=   - Web name, optional, e.g. ='Main'=. The current web is taken if missing
   * =$meta=  - topic meta-data to use while expanding
Return: =$text=     Expanded text, e.g. ='Current user is <nop>WikiGuest'=

See also: expandVariablesOnTopicCreation

=cut

sub expandCommonVariables {
    my ( $text, $topic, $web, $meta ) = @_;
    ASSERT($Foswiki::Plugins::SESSION) if DEBUG;
    $topic ||= $Foswiki::Plugins::SESSION->{topicName};
    $web   ||= $Foswiki::Plugins::SESSION->{webName};
    return $Foswiki::Plugins::SESSION->handleCommonTags( $text, $web, $topic,
        $meta );
}

=begin TML

---+++ renderText( $text, $web ) -> $text

Render text from TML into XHTML as defined in [[%SYSTEMWEB%.TextFormattingRules]]
   * =$text= - Text to render, e.g. ='*bold* text and =fixed font='=
   * =$web=  - Web name, optional, e.g. ='Main'=. The current web is taken if missing
Return: =$text=    XHTML text, e.g. ='&lt;b>bold&lt;/b> and &lt;code>fixed font&lt;/code>'=

=cut

sub renderText {

    #   my( $text, $web ) = @_;
    ASSERT($Foswiki::Plugins::SESSION) if DEBUG;
    return $Foswiki::Plugins::SESSION->renderer->getRenderedVersion(@_);
}

=begin TML

---+++ internalLink( $pre, $web, $topic, $label, $anchor, $createLink ) -> $text

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
    my $pre = shift;
    ASSERT($Foswiki::Plugins::SESSION) if DEBUG;

    #   my( $web, $topic, $label, $anchor, $anchor, $createLink ) = @_;
    return $pre . $Foswiki::Plugins::SESSION->renderer->internalLink(@_);
}

=begin TML

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

=cut

sub sendEmail {

    #my( $text, $retries ) = @_;
    ASSERT($Foswiki::Plugins::SESSION) if DEBUG;
    return $Foswiki::Plugins::SESSION->net->sendEmail(@_);
}

=begin TML

---++ Creating New Topics

=cut

=begin TML

---+++ expandVariablesOnTopicCreation ( $text ) -> $text

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
    ASSERT($Foswiki::Plugins::SESSION) if DEBUG;
    return $Foswiki::Plugins::SESSION->expandVariablesOnTopicCreation( shift,
        $Foswiki::Plugins::SESSION->{user} );
}

=begin TML

---++ Special handlers

Special handlers can be defined to make functions in plugins behave as if they were built-in.

=cut

=begin TML=

---+++ registerTagHandler( $var, \&fn, $syntax )

Should only be called from initPlugin.

Register a function to handle a simple variable. Handles both %<nop>VAR% and %<nop>VAR{...}%. Registered variables are treated the same as internal macros, and are expanded at the same time. This is a _lot_ more efficient than using the =commonTagsHandler=.
   * =$var= - The name of the variable, i.e. the 'MYVAR' part of %<nop>MYVAR%. The variable name *must* match /^[A-Z][A-Z0-9_]*$/ or it won't work.
   * =\&fn= - Reference to the handler function.
   * =$syntax= can be 'classic' (the default) or 'context-free'. 'classic' syntax is appropriate where you want the variable to support classic syntax i.e. to accept the standard =%<nop>MYVAR{ "unnamed" param1="value1" param2="value2" }%= syntax, as well as an unquoted default parameter, such as =%<nop>MYVAR{unquoted parameter}%=. If your variable will only use named parameters, you can use 'context-free' syntax, which supports a more relaxed syntax. For example, %MYVAR{param1=value1, value 2, param3="value 3", param4='value 5"}%

The variable handler function must be of the form:
<verbatim>
sub handler(\%session, \%params, $topic, $web)
</verbatim>
where:
   * =\%session= - a reference to the session object (may be ignored)
   * =\%params= - a reference to a Foswiki::Attrs object containing parameters. This can be used as a simple hash that maps parameter names to values, with _DEFAULT being the name for the default parameter.
   * =$topic= - name of the topic in the query
   * =$web= - name of the web in the query
for example, to execute an arbitrary command on the server, you might do this:
<verbatim>
sub initPlugin{
   Foswiki::Func::registerTagHandler('EXEC', \&boo);
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

Registered tags differ from tags implemented using the old approach (text substitution in =commonTagsHandler=) in the following ways:
   * registered tags are evaluated at the same time as system tags, such as %SERVERTIME. =commonTagsHandler= is only called later, when all system tags have already been expanded (though they are expanded _again_ after =commonTagsHandler= returns).
   * registered tag names can only contain alphanumerics and _ (underscore)
   * registering a tag =FRED= defines both =%<nop>FRED{...}%= *and also* =%FRED%=.
   * registered tag handlers *cannot* return another tag as their only result (e.g. =return '%<nop>SERVERTIME%';=). It won't work.

=cut

sub registerTagHandler {
    my ( $tag, $function, $syntax ) = @_;
    ASSERT($Foswiki::Plugins::SESSION) if DEBUG;

    # Use an anonymous function so it gets inlined at compile time.
    # Make sure we don't mangle the session reference.
    Foswiki::registerTagHandler(
        $tag,
        sub {
            my $record = $Foswiki::Plugins::SESSION;
            $Foswiki::Plugins::SESSION = $_[0];
            my $result = &$function(@_);
            $Foswiki::Plugins::SESSION = $record;
            return $result;
        },
        $syntax
    );
}

=begin TML=

---+++ registerRESTHandler( $alias, \&fn, %options )

Should only be called from initPlugin.

Adds a function to the dispatch table of the REST interface 
   * =$alias= - The name .
   * =\&fn= - Reference to the function.
   * =%options= - additional options affecting the handler
The handler function must be of the form:
<verbatim>
sub handler(\%session)
</verbatim>
where:
   * =\%session= - a reference to the Foswiki session object (may be ignored)

From the REST interface, the name of the plugin must be used
as the subject of the invokation.

Additional options are set in the =%options= hash. These options are important
to ensuring that requests to your handler can't be used in cross-scripting
attacks, or used for phishing.
   * =authenticate= - use this boolean option to require authentication for the
     handler. If this is set, then an authenticated session must be in place
     or the REST call will be rejected with a 401 (Unauthorized) status code.
     By default, rest handlers do *not* require authentication.
   * =validate= - use this boolean option to require validation of any requests
     made to this handler. Validation is the process by which a secret key
     is passed to the server so it can identify the origin of the request.
     By default, requests made to REST handlers are not validated.
   * =http_allow= use this option to specify that the HTTP methods that can
     be used to invoke the handler. For example, =http_allow=>'POST,GET'= will
     constrain the handler to be invoked using POST and GET, but not other
     HTTP methods, such as DELETE. Normally you will use http_allow=>'POST'.
     Together with authentication this is an important security tool.
     Handlers that can be invoked using GET are vulnerable to being called
     in the =src= parameter of =img= tags, a common method for cross-site
     request forgery (CSRF) attacks. This option is set automatically if
     =authenticate= is specified.

---++++ Example

The EmptyPlugin has the following call in the initPlugin handler:
<verbatim>
   Foswiki::Func::registerRESTHandler('example', \&restExample,
     http_allow=>'GET,POST');
</verbatim>

This adds the =restExample= function to the REST dispatch table
for the EmptyPlugin under the 'example' alias, and allows it
to be invoked using the URL

=http://server:port/bin/rest/EmptyPlugin/example=

note that the URL

=http://server:port/bin/rest/EmptyPlugin/restExample=

(ie, with the name of the function instead of the alias) will not work.

---++++ Calling REST handlers from the command-line
The =rest= script allows handlers to be invoked from the command line. The
script is invoked passing the parameters as described in CommandAndCGIScripts.
If the handler requires authentication ( =authenticate=>1= ) then this can
be passed in the username and =password= parameters.

For example,

=perl -wT rest /EmptyPlugin/example -username HughPugh -password trumpton=

=cut

sub registerRESTHandler {
    my ( $alias, $function, %options ) = @_;
    ASSERT($Foswiki::Plugins::SESSION) if DEBUG;
    my $plugin = caller;
    $plugin =~ s/.*:://;    # strip off Foswiki::Plugins:: prefix

    # Use an anonymous function so it gets inlined at compile time.
    # Make sure we don't mangle the session reference.
    require Foswiki::UI::Rest;
    Foswiki::UI::Rest::registerRESTHandler(
        $plugin, $alias,
        sub {
            my $record = $Foswiki::Plugins::SESSION;
            $Foswiki::Plugins::SESSION = $_[0];
            my $result = &$function(@_);
            $Foswiki::Plugins::SESSION = $record;
            return $result;
        }, %options
    );
}

=begin TML

---+++ decodeFormatTokens($str) -> $unencodedString

Foswiki has an informal standard set of tokens used in =format=
parameters that are used to block evaluation of paramater strings.
For example, if you were to write

=%<nop>MYTAG{format="%<nop>WURBLE%"}%=

then %<nop>WURBLE would be expanded *before* %<NOP>MYTAG is evaluated. To avoid
this Foswiki uses escapes in the format string. For example:

=%<nop>MYTAG{format="$percntWURBLE$percnt"}%=

This lets you enter arbitrary strings into parameters without worrying that
Foswiki will expand them before your plugin gets a chance to deal with them
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

=cut

sub decodeFormatTokens {
    return Foswiki::expandStandardEscapes(@_);
}

=begin TML

---++ Searching

=cut

=begin TML

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
my $result = Foswiki::Func::searchInWebContent( "Slimy Toad", $web, \@topics,
   { casesensitive => 0, files_without_match => 0 } );
foreach my $topic (keys %$result ) {
   foreach my $matching_line ( @{$result->{$topic}} ) {
      ...etc
</verbatim>

=cut

sub searchInWebContent {

    #my( $searchString, $web, $topics, $options ) = @_;

    return $Foswiki::Plugins::SESSION->{store}->searchInWebContent(@_);
}

=begin TML

---++ Plugin-specific file handling

=cut

=begin TML

---+++ getWorkArea( $pluginName ) -> $directorypath

Gets a private directory for Plugin use. The Plugin is entirely responsible
for managing this directory; Foswiki will not read from it, or write to it.

The directory is guaranteed to exist, and to be writable by the webserver
user. By default it will *not* be web accessible.

The directory and it's contents are permanent, so Plugins must be careful
to keep their areas tidy.

=cut

sub getWorkArea {
    my ($plugin) = @_;
    ASSERT($Foswiki::Plugins::SESSION) if DEBUG;
    return $Foswiki::Plugins::SESSION->{store}->getWorkArea($plugin);
}

=begin TML

---+++ readFile( $filename ) -> $text

Read file, low level. Used for Plugin workarea.
   * =$filename= - Full path name of file
Return: =$text= Content of file, empty if not found

__NOTE:__ Use this function only for the Plugin workarea, *not* for topics and attachments. Use the appropriate functions to manipulate topics and attachments.

=cut

sub readFile {
    my $name = shift;
    my $data = '';
    open( IN_FILE, "<$name" ) || return '';
    local $/ = undef;    # set to read to EOF
    $data = <IN_FILE>;
    close(IN_FILE);
    $data = '' unless $data;    # no undefined
    return $data;
}

=begin TML

---+++ saveFile( $filename, $text )

Save file, low level. Used for Plugin workarea.
   * =$filename= - Full path name of file
   * =$text=     - Text to save
Return:                none

__NOTE:__ Use this function only for the Plugin workarea, *not* for topics and attachments. Use the appropriate functions to manipulate topics and attachments.

=cut

sub saveFile {
    my ( $name, $text ) = @_;

    unless ( open( FILE, ">$name" ) ) {
        die "Can't create file $name - $!\n";
    }
    print FILE $text;
    close(FILE);
}

=begin TML

---++ General Utilities

=cut

=begin TML

---+++ normalizeWebTopicName($web, $topic) -> ($web, $topic)

Parse a web and topic name, supplying defaults as appropriate.
   * =$web= - Web name, identifying variable, or empty string
   * =$topic= - Topic name, may be a web.topic string, required.
Return: the parsed Web/Topic pair

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
| <tt>( '%<nop>SYSTEMWEB%', 'Topic' )</tt>    | <tt>( 'System', 'Topic' ) </tt>  |
| <tt>( '', '%<nop>DOCWEB%.Topic' )</tt>    | <tt>( 'System', 'Topic' ) </tt>  |

=cut

sub normalizeWebTopicName {

    #my( $web, $topic ) = @_;
    ASSERT($Foswiki::Plugins::SESSION) if DEBUG;
    return $Foswiki::Plugins::SESSION->normalizeWebTopicName(@_);
}

=begin TML

---+++ StaticMethod sanitizeAttachmentName($fname) -> ($fileName, $origName)

Given a file namer, sanitise it according to the rules for transforming
attachment names. Returns
the sanitised name together with the basename before sanitisation.

Sanitation includes filtering illegal characters and mapping client
file names to legal server names.

=cut

sub sanitizeAttachmentName {
    require Foswiki::Sandbox;
    return Foswiki::Sandbox::sanitizeAttachmentName(@_);
}

=begin TML

---+++ spaceOutWikiWord( $word, $sep ) -> $text

Spaces out a wiki word by inserting a string (default: one space) between each word component.
With parameter $sep any string may be used as separator between the word components; if $sep is undefined it defaults to a space.

=cut

sub spaceOutWikiWord {

    #my ( $word, $sep ) = @_;
    return Foswiki::spaceOutWikiWord(@_);
}

=begin TML

---+++ writeWarning( $text )

Log Warning that may require admin intervention to data/warning.txt
   * =$text= - Text to write; timestamp gets added

=cut

sub writeWarning {

    #   my( $text ) = @_;
    ASSERT($Foswiki::Plugins::SESSION) if DEBUG;
    return $Foswiki::Plugins::SESSION->logger->log(
        'warning', scalar(caller()), @_ );
}

=begin TML

---+++ writeDebug( $text )

Log debug message to data/debug.txt
   * =$text= - Text to write; timestamp gets added

=cut

sub writeDebug {

    #   my( $text ) = @_;
    ASSERT($Foswiki::Plugins::SESSION) if DEBUG;
    return $Foswiki::Plugins::SESSION->logger->log('debug', @_);
}

=begin TML

---+++ isTrue( $value, $default ) -> $boolean

Returns 1 if =$value= is true, and 0 otherwise. "true" means set to
something with a Perl true value, with the special cases that "off",
"false" and "no" (case insensitive) are forced to false. Leading and
trailing spaces in =$value= are ignored.

If the value is undef, then =$default= is returned. If =$default= is
not specified it is taken as 0.

=cut

sub isTrue {

    #   my ( $value, $default ) = @_;

    return Foswiki::isTrue(@_);
}

=begin TML

---+++ isValidWikiWord ( $text ) -> $boolean

Check for a valid WikiWord or WikiName
   * =$text= - Word to test

=cut

sub isValidWikiWord {
    return Foswiki::isValidWikiWord(@_);
}

=begin TML

---+++ isValidWebName( $name [, $system] ) -> $boolean

Check for a valid web name. If $system is true, then
system web names are considered valid (names starting with _)
otherwise only user web names are valid

If $Foswiki::cfg{EnableHierarchicalWebs} is off, it will also return false
when a nested web name is passed to it.

=cut

sub isValidWebName {
    return Foswiki::isValidWebName(@_);
}

=begin TML

---++ StaticMethod isValidTopicName( $name [, $allowNonWW] ) -> $boolean

Check for a valid topic name.
   * =$name= - topic name
   * =$allowNonWW= - true to allow non-wikiwords

=cut

sub isValidTopicName {
    return Foswiki::isValidTopicName(@_);
}

=begin TML

---+++ extractParameters($attr ) -> %params

Extract all parameters from a variable string and returns a hash of parameters
   * =$attr= - Attribute string
Return: =%params=  Hash containing all parameters. The nameless parameter is stored in key =_DEFAULT=

   * Example:
      * Variable: =%<nop>TEST{ 'nameless' name1="val1" name2="val2" }%=
      * First extract text between ={...}= to get: ='nameless' name1="val1" name2="val2"=
      * Then call this on the text: <br />
   * params = Foswiki::Func::extractParameters( $text );=
      * The =%params= hash contains now: <br />
        =_DEFAULT => 'nameless'= <br />
        =name1 => "val1"= <br />
        =name2 => "val2"=

=cut

sub extractParameters {
    my ($attr) = @_;
    require Foswiki::Attrs;
    my $params = new Foswiki::Attrs($attr);

    # take out _RAW and _ERROR (compatibility)
    delete $params->{_RAW};
    delete $params->{_ERROR};
    return %$params;
}

=begin TML

---+++ extractNameValuePair( $attr, $name ) -> $value

Extract a named or unnamed value from a variable parameter string
- Note:              | Function Foswiki::Func::extractParameters is more efficient for extracting several parameters
   * =$attr= - Attribute string
   * =$name= - Name, optional
Return: =$value=   Extracted value

   * Example:
      * Variable: =%<nop>TEST{ 'nameless' name1="val1" name2="val2" }%=
      * First extract text between ={...}= to get: ='nameless' name1="val1" name2="val2"=
      * Then call this on the text: <br />
        =my $noname = Foswiki::Func::extractNameValuePair( $text );= <br />
        =my $val1  = Foswiki::Func::extractNameValuePair( $text, "name1" );= <br />
        =my $val2  = Foswiki::Func::extractNameValuePair( $text, "name2" );=

=cut

sub extractNameValuePair {
    require Foswiki::Attrs;
    return Foswiki::Attrs::extractValue(@_);
}

=begin TML

---++ Deprecated functions

From time-to-time, the Foswiki developers will add new functions to the interface (either to =Foswiki::Func=, or new handlers). Sometimes these improvements mean that old functions have to be deprecated to keep the code manageable. When this happens, the deprecated functions will be supported in the interface for at least one more release, and probably longer, though this cannot be guaranteed.

Updated plugins may still need to define deprecated handlers for compatibility with old Foswiki versions. In this case, the plugin package that defines old handlers can suppress the warnings in %<nop>FAILEDPLUGINS%.

This is done by defining a map from the handler name to the =Foswiki::Plugins= version _in which the handler was first deprecated_. For example, if we need to define the =endRenderingHandler= for compatibility with =Foswiki::Plugins= versions before 1.1, we would add this to the plugin:
<verbatim>
package Foswiki::Plugins::SinkPlugin;
use vars qw( %FoswikiCompatibility );
$FoswikiCompatibility{endRenderingHandler} = 1.1;
</verbatim>
If the currently-running code version is 1.1 _or later_, then the _handler will not be called_ and _the warning will not be issued_. TWiki with versions of =Foswiki::Plugins= before 1.1 will still call the handler as required.

The following functions are retained for compatibility only. You should
stop using them as soon as possible.

=cut

=begin TML

---+++ getRegularExpression( $name ) -> $expr

*Deprecated* 28 Nov 2008 - use =$Foswiki::regex{...}= instead, it is directly
equivalent.

See System.DevelopingPlugins for more information

=cut

sub getRegularExpression {
    my ($regexName) = @_;
    return $Foswiki::regex{$regexName};
}

=begin TML

---+++ getScriptUrlPath( ) -> $path

Get script URL path

*Deprecated* 28 Nov 2008 - use =getScriptUrl= instead.

Return: =$path= URL path of bin scripts, e.g. ="/cgi-bin"=

*WARNING:* you are strongly recommended *not* to use this function, as the
{ScriptUrlPaths} URL rewriting rules will not apply to urls generated
using it.

=cut

sub getScriptUrlPath {
    ASSERT($Foswiki::Plugins::SESSION) if DEBUG;
    return $Foswiki::Plugins::SESSION->getScriptUrl( 0, '' );
}

=begin TML

---+++ getWikiToolName( ) -> $name

*Deprecated* 28 Nov 2008 in Foswiki; use $Foswiki::cfg{WikiToolName} instead

=cut

sub getWikiToolName { return $Foswiki::cfg{WikiToolName}; }

=begin TML

---+++ getMainWebname( ) -> $name

*Deprecated* 28 Nov 2008 in Foswiki; use $Foswiki::cfg{UsersWebName} instead

=cut

sub getMainWebname { return $Foswiki::cfg{UsersWebName}; }

=begin TML

---+++ getTwikiWebname( ) -> $name

*Deprecated* 28 Nov 2008 in Foswiki; use $Foswiki::cfg{SystemWebName} instead

=cut

sub getTwikiWebname { return $Foswiki::cfg{SystemWebName}; }

=begin TML

---+++ getOopsUrl( $web, $topic, $template, $param1, $param2, $param3, $param4 ) -> $url

Compose fully qualified 'oops' dialog URL
   * =$web=                  - Web name, e.g. ='Main'=. The current web is taken if empty
   * =$topic=                - Topic name, e.g. ='WebNotify'=
   * =$template=             - Oops template name, e.g. ='oopsmistake'=. The 'oops' is optional; 'mistake' will translate to 'oopsmistake'.
   * =$param1= ... =$param4= - Parameter values for %<nop>PARAM1% ... %<nop>PARAMn% variables in template, optional
Return: =$url=                     URL, e.g. ="http://example.com:80/cgi-bin/oops.pl/ Main/WebNotify?template=oopslocked&amp;param1=joe"=

*Deprecated* 28 Nov 2008, the recommended approach is to throw an oops exception.
<verbatim>
   use Error qw( :try );

   throw Foswiki::OopsException(
      'toestuckerror',
      web => $web,
      topic => $topic,
      params => [ 'I got my toe stuck' ]);
</verbatim>
(this example will use the =oopstoestuckerror= template.)

If this is not possible (e.g. in a REST handler that does not trap the exception)
then you can use =getScriptUrl= instead:
<verbatim>
   my $url = Foswiki::Func::getScriptUrl($web, $topic, 'oops',
            template => 'oopstoestuckerror',
            param1 => 'I got my toe stuck');
   Foswiki::Func::redirectCgiQuery( undef, $url );
   return 0;
</verbatim>

=cut

sub getOopsUrl {
    my ( $web, $topic, $template, @params ) = @_;

    my $n = 1;
    @params = map { 'param' . ( $n++ ) => $_ } @params;
    return getScriptUrl(
        $web, $topic, 'oops',
        template => $template,
        @params
    );
}

=begin TML

---+++ wikiToEmail( $wikiName ) -> $email

   * =$wikiname= - wiki name of the user
Get the e-mail address(es) of the named user. If the user has multiple
e-mail addresses (for example, the user is a group), then the list will
be comma-separated.

*Deprecated* 28 Nov 2008 in favour of wikinameToEmails, because this function only
returns a single email address, where a user may in fact have several.

$wikiName may also be a login name.

=cut

sub wikiToEmail {
    my ($user) = @_;
    my @emails = wikinameToEmails($user);
    if ( scalar(@emails) ) {
        return $emails[0];
    }
    return '';
}

=begin TML

---+++ permissionsSet( $web ) -> $boolean

Test if any access restrictions are set for this web, ignoring settings on
individual pages
   * =$web= - Web name, required, e.g. ='Sandbox'=

*Deprecated* 28 Nov 2008 - use =getPreferencesValue= instead to determine
what permissions are set on the web, for example:
<verbatim>
foreach my $type qw( ALLOW DENY ) {
    foreach my $action qw( CHANGE VIEW ) {
        my $pref = $type . 'WEB' . $action;
        my $val = Foswiki::Func::getPreferencesValue( $pref, $web ) || '';
        if( $val =~ /\S/ ) {
            print "$pref is set to $val on $web\n";
        }
    }
}
</verbatim>

=cut

sub permissionsSet {
    my ($web) = @_;

    foreach my $type qw( ALLOW DENY ) {
        foreach my $action qw( CHANGE VIEW RENAME ) {
            my $pref = $type . 'WEB' . $action;
            my $val = getPreferencesValue( $pref, $web ) || '';
            return 1 if ( $val =~ /\S/ );
        }
    }

    return 0;
}

=begin TML

---+++ getPublicWebList( ) -> @webs

*Deprecated* 28 Nov 2008 - use =getListOfWebs= instead.

Get list of all public webs, e.g. all webs *and subwebs* that do not have the =NOSEARCHALL= flag set in the WebPreferences

Return: =@webs= List of all public webs *and subwebs*

=cut

sub getPublicWebList {
    ASSERT($Foswiki::Plugins::SESSION) if DEBUG;
    return $Foswiki::Plugins::SESSION->{store}->getListOfWebs("user,public");
}

=begin TML

---+++ formatTime( $time, $format, $timezone ) -> $text

*Deprecated* 28 Nov 2008 - use =Foswiki::Time::formatTime= instead (it has an identical interface).

Format the time in seconds into the desired time string
   * =$time=     - Time in epoch seconds
   * =$format=   - Format type, optional. Default e.g. ='31 Dec 2002 - 19:30'=. Can be ='$iso'= (e.g. ='2002-12-31T19:30Z'=), ='$rcs'= (e.g. ='2001/12/31 23:59:59'=, ='$http'= for HTTP header format (e.g. ='Thu, 23 Jul 1998 07:21:56 GMT'=), or any string with tokens ='$seconds, $minutes, $hours, $day, $wday, $month, $mo, $year, $ye, $tz'= for seconds, minutes, hours, day of month, day of week, 3 letter month, 2 digit month, 4 digit year, 2 digit year, timezone string, respectively
   * =$timezone= - either not defined (uses the displaytime setting), 'gmtime', or 'servertime'
Return: =$text=        Formatted time string
| Note:                  | if you used the removed formatGmTime, add a third parameter 'gmtime' |

=cut

sub formatTime {

    #   my ( $epSecs, $format, $timezone ) = @_;
    require Foswiki::Time;
    return Foswiki::Time::formatTime(@_);
}

=begin TML

---+++ formatGmTime( $time, $format ) -> $text

*Deprecated* 28 Nov 2008 - use =Foswiki::Time::formatTime= instead.

Format the time to GM time
   * =$time=   - Time in epoc seconds
   * =$format= - Format type, optional. Default e.g. ='31 Dec 2002 - 19:30'=, can be ='iso'= (e.g. ='2002-12-31T19:30Z'=), ='rcs'= (e.g. ='2001/12/31 23:59:59'=, ='http'= for HTTP header format (e.g. ='Thu, 23 Jul 1998 07:21:56 GMT'=)
Return: =$text=      Formatted time string

=cut

sub formatGmTime {

    #   my ( $epSecs, $format ) = @_;
    require Foswiki::Time;
    return Foswiki::Time::formatTime( @_, 'gmtime' );
}

=begin TML

---+++ getDataDir( ) -> $dir

*Deprecated* 28 Nov 2008 - use the "Webs, Topics and Attachments" functions to manipulate topics instead

=cut

sub getDataDir {
    return $Foswiki::cfg{DataDir};
}

=begin TML

---+++ getPubDir( ) -> $dir

*Deprecated* 28 Nov 2008 - use the "Webs, Topics and Attachments" functions to manipulateattachments instead

=cut

sub getPubDir { return $Foswiki::cfg{PubDir}; }

# Removed; it was never used
sub checkDependencies {
    die
"checkDependencies removed; contact plugin author or maintainer and tell them to use BuildContrib DEPENDENCIES instead";
}

1;

__DATA__

Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/, http://Foswiki.org/

Copyright (C) 2008-2009 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.
Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2000-2007 Peter Thoeny, peter@thoeny.org
and TWiki Contributors. All Rights Reserved. TWiki Contributors
are listed in the AUTHORS file in the root of this distribution.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
