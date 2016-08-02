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

*Since:* _date_ indicates where functions or parameters have been added since
the baseline of the API (Foswiki 1.0.0). The _date_ indicates the
earliest date of a Foswiki release that will support that function or
parameter. See Foswiki:Download.ReleaseDates for version release dates.

*Deprecated* _date_ indicates where a function or parameters has been
[[http://en.wikipedia.org/wiki/Deprecation][deprecated]]. Deprecated
functions will still work, though they should
_not_ be called in new plugins and should be replaced in older plugins
as soon as possible. Deprecated parameters are simply ignored in Foswiki
releases after _date_.

*Until* _date_ indicates where a function or parameter has been removed.
The _date_ indicates the latest date at which Foswiki releases still supported
the function or parameter.

Note that the =Foswiki::Func= API should always be the first place extension
authors look for methods. Certain other lower-level APIs are also exposed
by the core, but those APIs should only be called if there is no alternative
available through =Foswiki::Func=. The APIs in question are documented in
System.DevelopingPlugins.

=cut

# THIS PACKAGE IS PART OF THE PUBLISHED API USED BY EXTENSION AUTHORS.
# DO NOT CHANGE THE EXISTING APIS (well thought out extensions are OK)
# AND ENSURE ALL POD DOCUMENTATION IS COMPLETE AND ACCURATE.
#
# Deprecated functions should not be removed, but should be moved to to the
# deprecated functions section.

package Foswiki::Func;

use strict;
use warnings;
use Scalar::Util ();

use Try::Tiny;
use Assert;

use Foswiki qw(expandStandardEscapes);
use Foswiki::App                    ();
use Foswiki::Plugins                ();
use Foswiki::Meta                   ();
use Foswiki::AccessControlException ();
use Foswiki::Sandbox                ();

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

# Given $web, $web and $topic, or $web $topic and $attachment, validate
# and untaint each of them and return. If any fails to validate it will
# be returned as undef.

# Validate a web.topic.attachment and throw an exception if the
# validation fails

=begin TML

---++ Environment

=cut

=begin TML

---+++ getSkin( ) -> $skin

Get the skin path, set by the =SKIN= and =COVER= preferences variables or the =skin= and =cover= CGI parameters

Return: =$skin= Comma-separated list of skins, e.g. ='gnu,tartan'=. Empty string if none.

=cut

=begin TML

---+++ getUrlHost( ) -> $host

Get protocol, domain and optional port of script URL

Return: =$host= URL host, e.g. ="http://example.com:80"=

=cut

sub getUrlHost {
    ASSERT($Foswiki::app) if DEBUG;

    return $Foswiki::app->cfg->urlHost;
}

=begin TML

---+++ getScriptUrl( $web, $topic, $script, ... ) -> $url

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
$url = Foswiki::Func::getScriptUrl();
# $url eq 'http://wiki.example.org/url/to/bin/edit'
$url = Foswiki::Func::getScriptUrl(undef, undef, 'edit');
# $url eq 'http://wiki.example.org/url/to/bin/edit/Web/Topic'
$url = Foswiki::Func::getScriptUrl('Web', 'Topic', 'edit');</verbatim>

=cut

=begin TML

---+++ getScriptUrlPath( $web, $topic, $script, ... ) -> $path

Compose absolute URL path. See Foswiki::Func::getScriptUrl

*Examples:*
<verbatim class="perl">
my $path;
# $path eq '/path/to/bin'
$path = Foswiki::Func::getScriptUrlPath();
# $path eq '/path/to/bin/edit'
$path = Foswiki::Func::getScriptUrlPath(undef, undef, 'edit');
# $path eq '/path/to/bin/edit/Web/Topic'
$path = Foswiki::Func::getScriptUrlPath('Web', 'Topic', 'edit');</verbatim>

*Since:* 19 Jan 2012 (when called without parameters, this function is
backwards-compatible with the old version which was deprecated 28 Nov 2008).

=cut

=begin TML

---+++ getViewUrl( $web, $topic ) -> $url

Compose fully qualified view URL
   * =$web=   - Web name, e.g. ='Main'=. The current web is taken if empty
   * =$topic= - Topic name, e.g. ='WebNotify'=
Return: =$url=      URL, e.g. ="http://example.com:80/cgi-bin/view.pl/Main/WebNotify"=

=cut

=begin TML

---+++ getPubUrlPath( $web, $topic, $attachment, %options ) -> $url

Get pub URL path/attachment URL

Return: with no parameters, returns the URL path of the root of
all attachments.

Prior to Foswiki 2, URLs to attachments had to be constructed by the caller.
For example, =%<nop>PUBURL%/Main/JohnSmith/picture.gif=
This method of constructing URLs causes many problems, and is
*strongly* discouraged.

Since Foswiki 2 this function accepts parameters as follows:
   * =$web= - name of web
   * =$topic= - name of topic (ignored if =web= is not given)
   * =$attachment= - name of attachment (ignored if =web= or =topic= not given)
   * =%options= - additional options
%options may include:
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
will be linked. Not all stores support retrieving old attachment versions
this way.

If =absolute= is not specified (or is 0), this function will generate
relative URLs. However if Foswiki is running in an absolute URL context
(the skin requires absolute URLs, such as print or rss, or Foswiki is
running from the command-line) then =absolute= will be ignored and
absolute URLs will always be generated.

=cut

sub getPubUrlPath {
    return $Foswiki::app->cfg->getPubURL(@_);
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

=begin TML

---+++ getRequestObject( ) -> $query

Get the request object. This is a subclass of =Foswiki::Request=. The request
object can be used to get the parameters passed to the request, either
via CGI or on the command line (depending on how the script was called).

A =Foswiki::Request= object is largely compatible with a CPAN:CGI object.
Most of the time, documentation for that class applies directly to
=Foswiki::Request= objects as well.

Note that this method replaces =getCgiQuery= (which is a synonym for this
method). Code that is expected to run with pre-1.1 versions of Foswiki
can continue to call =getCgiQuery= for as long as necessary.

*Caution:* Direct use of the CGI parameters can introduce security vulnerabilities.
Any parameters from the URL should be carefully validated, and encoded for safety
before displaying the data back to the user.

Example:
<verbatim>
   my $query    = Foswiki::Func::getRequestObject();
   my $single   = $query->param('parm1');        # Get a scalar value (Returns 1st value if multiple valued)
   my @multi    = $query->multi_param('parm2');  # Get multi-valued parameter
</verbatim>

*Since:* 31 Mar 2009

=cut

sub getRequestObject {
    ASSERT($Foswiki::app) if DEBUG;
    return $Foswiki::app->request;
}

=begin TML

---+++ getSessionKeys() -> @keys
Get a list of all the names of session variables. The list is unsorted.

Session keys are stored and retrieved using =setSessionValue= and
=getSessionValue=.

=cut

=begin TML

---+++ getSessionValue( $key ) -> $value

Get a session value from the client session module
   * =$key= - Session key
Return: =$value=  Value associated with key; empty string if not set

=cut

=begin TML

---+++ setSessionValue( $key, $value ) -> $boolean

Set a session value.
   * =$key=   - Session key
   * =$value= - Value associated with key
Return: true if function succeeded

=cut

=begin TML

---+++ clearSessionValue( $key ) -> $boolean

Clear a session value that was set using =setSessionValue=.
   * =$key= - name of value stored in session to be cleared. Note that
   you *cannot* clear =AUTHUSER=.
Return: true if the session value was cleared

=cut

=begin TML

---+++ getContext() -> \%hash

Get a hash of context identifiers representing the currently active
context.

The context is a set of identifiers that are set
during specific phases of processing. For example, each of
the standard scripts in the 'bin' directory each has a context
identifier - the view script has 'view', the edit script has 'edit'
etc. So you can easily tell what 'type' of script your Plugin is
being called within. 

A comprehensive list of core context identifiers used by Foswiki is found in
%SYSTEMWEB%.IfStatements#Context_identifiers. Please be careful not to
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
    ASSERT($Foswiki::app) if DEBUG;
    return $Foswiki::app->context;
}

=begin TML

---+++ pushTopicContext($web, $topic)
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

=begin TML

---+++ popTopicContext()

Returns the Foswiki context to the state it was in before the
=pushTopicContext= was called.

=cut

=begin TML

---++ Registering extensions

Plugins work either by using handlers to manipulate the text being processed,
or by registering extensions, such as new macros, scripts, or meta-data types.

=cut

=begin TML=

---+++ registerTagHandler( $var, \&fn, $syntax )

Should only be called from initPlugin.

Register a function to handle a simple variable. Handles both %<nop>VAR% and 
%<nop>VAR{...}%. Registered variables are treated the same as internal macros, 
and are expanded at the same time. This is a _lot_ more efficient than using the =commonTagsHandler=.
   * =$var= - The name of the variable, i.e. the 'MYVAR' part of %<nop>MYVAR%. 
   The variable name *must* match /^[A-Z][A-Z0-9_]*$/ or it won't work.
   * =\&fn= - Reference to the handler function.
   * =$syntax= can be 'classic' (the default) or 'context-free'. (context-free may be removed in future)
   'classic' syntax is appropriate where you want the variable to support classic syntax 
   i.e. to accept the standard =%<nop>MYVAR{ "unnamed" param1="value1" param2="value2" }%= syntax, 
   as well as an unquoted default parameter, such as =%<nop>MYVAR{unquoted parameter}%=. 
   If your variable will only use named parameters, you can use 'context-free' syntax, 
   which supports a more relaxed syntax. For example, 
   %MYVAR{param1=value1, value 2, param3="value 3", param4='value 5"}%

The variable handler function must be of the form:
<verbatim>
sub handler(\%session, \%params, $topic, $web, $topicObject)
</verbatim>
where:
   * =\%session= - a reference to the session object (may be ignored)
   * =\%params= - a reference to a Foswiki::Attrs object containing parameters. This can be used as a simple hash that maps parameter names to values, with _DEFAULT being the name for the default parameter.
   * =$topic= - name of the topic in the query
   * =$web= - name of the web in the query
   * =$topicObject= - is the Foswiki::Meta object for the topic *Since* 2009-03-06
for example, to execute an arbitrary command on the server, you might do this:
<verbatim>
sub initPlugin{
   Foswiki::Func::registerTagHandler('EXEC', \&boo);
}

sub boo {
    my( $session, $params, $topic, $web, $topicObject ) = @_;
    my $cmd = $params->{_DEFAULT};

    return "NO COMMAND SPECIFIED" unless $cmd;

    my $result = `$cmd 2>&1`;
    return $params->{silent} ? '' : $result;
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
     As of Foswiki 2, authenticate defaults to true.  If the handler being
     registered is usable by guests, and does its own checking, pass
     authenticate => 0 to remove the requirement for an authenticated session.
   * =validate= - use this boolean option to require validation of any requests
     made to this handler. Validation is the process by which a secret key
     is passed to the server so it can identify the origin of the request.
     As of Foswiki 2, validate will default to true.  If your handler is
     typically invoked multipe times on a page, or doesn not need protection
     from CSRF attacks, set validate => 0.
   * =http_allow= use this option to specify that the HTTP methods that can
     be used to invoke the handler. For example, =http_allow=>'POST,GET'= will
     constrain the handler to be invoked using POST and GET, but not other
     HTTP methods, such as DELETE. Normally you will use http_allow=>'POST'.
     Together with authentication this is an important security tool.
     Handlers that can be invoked using GET are vulnerable to being called
     in the =src= parameter of =img= tags, a common method for cross-site
     request forgery (CSRF) attacks. As of Foswiki 2, this option will
     default to http_allow => 'POST'.   If your handler does not update,
     then explicitly set this to http_allow => 'GET,POST'
   * =description= => 'handler information'   This is a completely optional
     short description of the handler function.  It is displayed  by the
     %<nop>RESTHANDLERS% macro used for extension diagnostics.

See http://foswiki.org/Support/GuidelinesForSecureExtensions for more information.
---++++ Example

The EmptyPlugin has the following call in the initPlugin handler:
<verbatim>
   Foswiki::Func::registerRESTHandler('example', \&restExample,
     authenticate  => 1,      # Set to 0 if handler should be useable by WikiGuest
     validate      => 1,      # Set to 0 to disable StrikeOne CSRF protection
     http_allow    => 'POST', # Set to 'GET,POST' to allow use HTTP GET and POST
     description   => 'Example handler for Empty Plugin'
     );
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

# XXX vrurg Not sure how to deal with this one.
sub registerRESTHandler {
    my ( $alias, $function, %options ) = @_;
    ASSERT($Foswiki::app) if DEBUG;
    my $plugin = caller;
    $plugin =~ s/.*:://;    # strip off Foswiki::Plugins:: prefix

    # Use an anonymous function so it gets inlined at compile time.
    # Make sure we don't mangle the session reference.
    Foswiki::load_class('Foswiki::UI::Rest');
    Foswiki::UI::Rest::registerRESTHandler(
        $plugin, $alias,
        sub {
            my $record = $Foswiki::app;
            $Foswiki::app = $_[0];
            ASSERT( $Foswiki::app->isa('Foswiki::App') ) if DEBUG;
            my $result = &$function(@_);
            $Foswiki::app = $record;
            return $result;
        },
        %options
    );
}

=begin TML

---+++ registerMETA($macro, $spec)
Deprecated: please use Foswiki::Meta::registerMETA instead.

=cut

sub registerMETA {

    #my ( $macro, %spec ) = @_;
    Foswiki::Meta::registerMETA(@_);
}

=begin TML

---++ Preferences

=cut

=begin TML

---+++ getPreferencesValue( $key, $web ) -> $value

Get a preferences value for the currently requested context, from the currently request topic, its web and the site.
   * =$key= - Preference name
   * =$web= - Name of web, optional. If defined, we shortcircuit to WebPreferences (ignoring SitePreferences). This is really only useful for ACLs.
   
Return: =$value=  Preferences value; undefined if not set

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
    ASSERT($Foswiki::app) if DEBUG;
    return $Foswiki::app->prefs->getValue(@_);
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
    ASSERT($Foswiki::app) if DEBUG;
    return $Foswiki::app->prefs->getPluginValue(@_);
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
    ASSERT($Foswiki::app) if DEBUG;
    return $Foswiki::app->prefs->getFlag(@_);
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
    ASSERT($Foswiki::app) if DEBUG;
    return $Foswiki::app->prefs->getPluginFlag(@_);
}

=begin TML

---+++ setPreferencesValue($name, $val)

Set the preferences value so that future calls to getPreferencesValue will
return this value, and =%$name%= will expand to the preference when used in
future variable expansions.

The preference only persists for the rest of this request. Finalised
preferences cannot be redefined using this function.

=cut

sub setPreferencesValue {
    ASSERT($Foswiki::app) if DEBUG;
    return $Foswiki::app->prefs->setSessionPreferences(@_);
}

=begin TML

---++ User Handling and Access Control
---+++ getDefaultUserName( ) -> $loginName
Get default user name as defined in the configuration as =DefaultUserLogin=

Return: =$loginName= Default user name, e.g. ='guest'=

=cut

=begin TML

---+++ getCanonicalUserID( $user ) -> $cUID
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

=begin TML

---+++ getWikiName( $user ) -> $wikiName

return the WikiName of the specified user
if $user is undefined Get Wiki name of logged in user

   * $user can be a cUID, login, wikiname or web.wikiname

Return: =$wikiName= Wiki Name, e.g. ='JohnDoe'=

=cut

=begin TML

---+++ getWikiUserName( $user ) -> $wikiName

return the userWeb.WikiName of the specified user
if $user is undefined Get Wiki name of logged in user

   * $user can be a cUID, login, wikiname or web.wikiname

Return: =$wikiName= Wiki Name, e.g. ="Main.JohnDoe"=

=cut

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

=begin TML

---+++ emailToWikiNames( $email, $dontAddWeb ) -> @wikiNames
   * =$email= - email address to look up
   * =$dontAddWeb= - Do not add web prefix if ="1"=
Find the wikinames of all users who have the given email address as their
registered address. Since several users could register with the same email
address, this returns a list of wikinames rather than a single wikiname.

=cut

=begin TML

---+++ wikinameToEmails( $user ) -> @emails
   * =$user= - wikiname of user to look up
Returns the registered email addresses of the named user. If $user is
undef, returns the registered email addresses for the logged-in user.

$user may also be a group.

=cut

=begin TML

---+++ isGuest( ) -> $boolean

Test if logged in user is a guest (WikiGuest)

=cut

=begin TML

---+++ isAnAdmin( $id ) -> $boolean

Find out if the user is an admin or not. If the user is not given,
the currently logged-in user is assumed.
   * $id can be either a login name or a WikiName

=cut

=begin TML

---+++ isGroupMember( $group, $id, $options ) -> $boolean

Find out if $id is in the named group.  The expand option controls whether or not nested groups are searched.

e.g. Is jordi in the HesperionXXGroup, and not in a nested group. e.g.
<verbatim>
if( Foswiki::Func::isGroupMember( "HesperionXXGroup", "jordi", { expand => 0 } )) {
    ...
}
</verbatim>
If =$user= is =undef=, it defaults to the currently logged-in user.

   * $id can be a login name or a WikiName
   * Nested groups are expanded unless $options{ expand => } is set to false.

=cut

=begin TML

---+++ eachUser() -> $iterator
Get an iterator over the list of all the registered users *not* including
groups. The iterator will return each wiki name in turn (e.g. 'FredBloggs').

Use it as follows:
<verbatim>
    my $it = Foswiki::Func::eachUser();
    while ($it->hasNext()) {
        my $user = $it->next();
        # $user is a wikiname
    }
</verbatim>

*WARNING* on large sites, this could be a long list!

=cut

=begin TML

---+++ eachMembership($id) -> $iterator
   * =$id= - WikiName or login name of the user.
     If =$id= is =undef=, defaults to the currently logged-in user.
Get an iterator over the names of all groups that the user is a member of.

=cut

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

=begin TML

---+++ isGroup( $group ) -> $boolean

Checks if =$group= is the name of a user group.

=cut

=begin TML

---+++ eachGroupMember($group) -> $iterator
Get an iterator over all the members of the named group. Returns undef if
$group is not a valid group.  Nested groups are expanded unless the
expand option is set to false.

Use it as follows:  Process all users in RadioHeadGroup without expanding nested groups
<verbatim>
    my $iterator = Foswiki::Func::eachGroupMember('RadioheadGroup', {expand => 'false');
    while ($it->hasNext()) {
        my $user = $it->next();
        # $user is a wiki name e.g. 'TomYorke', 'PhilSelway'
        #   With expand set to false, group names can also be returned.
        #   Users are not checked to exist.
    }
</verbatim>

*WARNING* on large sites, this could be a long list!

=cut

=begin TML

---+++ addUserToGroup( $id, $group, $create ) -> $boolean

   * $id can be a login name or a WikiName

=cut

=begin TML

---+++ removeUserFromGroup( $group, $id ) -> $boolean

   * $id can be a login name or a WikiName

=cut

=begin TML

---+++ checkAccessPermission( $type, $id, $text, $topic, $web, $meta ) -> $boolean

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
        Foswiki::Func::checkAccessPermission(
            "VIEW", $session->{user}, undef, $topic, $web
        )
      )
    {
        Foswiki::AccessControlException->throw( "VIEW", $session->{user}, $web,
            $topic,  $Foswiki::Meta::reason );
    }
</verbatim>

=cut

=begin TML

---++ Traversing

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
   * =$web= - (*Since* 2009-01-01) name of web to get list of subwebs for. Defaults to the root.
              note that if set, the list will not contain the web specified in $web

For example, the deprecated getPublicWebList function can be duplicated
as follows:
<verbatim>
   my @webs = Foswiki::Func::getListOfWebs( "user,public" );
</verbatim>

=cut

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

---+++ webExists( $web ) -> $boolean

Test if web exists
   * =$web= - Web name, required, e.g. ='Sandbox'=

=cut

=begin TML

---+++ getTopicList( $web ) -> @topics

Get list of all topics in a web
   * =$web= - Web name, required, e.g. ='Sandbox'=
Return: =@topics= Topic list, e.g. =( 'WebChanges',  'WebHome', 'WebIndex', 'WebNotify' )=

=cut

=begin TML

---+++ isValidTopicName( $name [, $allowNonWW] ) -> $boolean

Check for a valid topic name.
   * =$name= - topic name
   * =$allowNonWW= - true to allow non-wikiwords

=cut

sub isValidTopicName {
    return Foswiki::isValidTopicName(@_);
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

=begin TML

---+++ getRevisionAtTime( $web, $topic, $time ) -> $rev

Get the revision number of a topic at a specific time.
   * =$web= - web for topic
   * =$topic= - topic
   * =$time= - time (in epoch secs) for the rev
Return: Single-digit revision number, or undef if it couldn't be determined
(either because the topic isn't that old, or there was a problem)

=cut

=begin TML

---+++ getAttachmentList( $web, $topic ) -> @list
Get a list of the attachments on the given topic.

*Since:* 31 Mar 2009

=cut

=begin TML

---+++ attachmentExists( $web, $topic, $attachment ) -> $boolean

Test if attachment exists
   * =$web=   - Web name, optional, e.g. =Main=.
   * =$topic= - Topic name, required, e.g. =TokyoOffice=, or =Main.TokyoOffice=
   * =$attachment= - attachment name, e.g.=logo.gif=
$web and $topic are parsed as described in the documentation for =normalizeWebTopicName=.

The attachment must exist in the store (it is not sufficient for it to be referenced
in the object only)

=cut

=begin TML

---+++ readAttachment( $web, $topic, $name, $rev ) -> $data

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

=begin TML

---++ Manipulating

=cut

=begin TML

---+++ createWeb( $newWeb, $baseWeb, $opts )

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

=begin TML

---+++ moveWeb( $oldName, $newName )

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

=begin TML

---+++ checkTopicEditLock( $web, $topic, $script ) -> ( $oopsUrl, $loginName, $unlockTime )

Check if a lease has been taken by some other user.
   * =$web= Web name, e.g. ="Main"=, or empty
   * =$topic= Topic name, e.g. ="MyTopic"=, or ="Main.MyTopic"=
Return: =( $oopsUrl, $loginName, $unlockTime )= - The =$oopsUrl= for calling redirectCgiQuery(), user's =$loginName=, and estimated =$unlockTime= in minutes, or ( '', '', 0 ) if no lease exists.
   * =$script= The script to invoke when continuing with the edit

=cut

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

=begin TML

---+++ saveTopic( $web, $topic, $meta, $text, $options )

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
if (Foswiki::Func::topicExists($web, $topic)) {
    ( $meta, $text ) = Foswiki::Func::readTopic( $web, $topic );
} else {
    #if the topic doesn't exist, we can either leave $meta undefined
    #or if we need to set more than just the topic text, we create a new Meta object and use it.
    $meta = new Foswiki::Meta($Foswiki::app, $web, $topic );
    $text = '';
}
$text =~ s/APPLE/ORANGE/g;
try {
    Foswiki::Func::saveTopic( $web, $topic, $meta, $text );
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

=begin TML

---+++ saveAttachment( $web, $topic, $attachment, \%opts )
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

=begin TML

---+++ moveAttachment( $web, $topic, $attachment, $newWeb, $newTopic, $newAttachment )

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

=begin TML

---+++ copyAttachment( $web, $topic, $attachment, $newWeb, $newTopic, $newAttachment )

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

=begin TML

---++ Finding changes

=cut

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

=begin TML

---+++ summariseChanges($web, $topic, $orev, $nrev, $tml, $nochecks) -> $text
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

=begin TML

---++ Templates

=cut

=begin TML

---+++ readTemplate( $name, $skin ) -> $text

Read a template or skin. Embedded [[%SYSTEMWEB%.SkinTemplates][template directives]] get expanded
   * =$name= - Template name, e.g. ='view'=
   * =$skin= - Comma-separated list of skin names, optional, e.g. ='print'=
Return: =$text=    Template text

=cut

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

=begin TML

---+++ expandTemplate( $def ) -> $string

Do a =%<nop>TMPL:P{$def}%=, only expanding the template (not expanding any variables other than =%TMPL%=.)
   * =$def= - template name or parameters (as a string)
Return: the text of the expanded template

A template is defined using a =%TMPL:DEF%= statement in a template
file. See the [[System.SkinTemplates][documentation on Foswiki templates]] for more information.

eg:
    #load the templates (relying on the system-wide skin path.)
    Foswiki::Func::loadTemplate('linkedin');
    #get the 'profile' DEF section
    my $tml = Foswiki::Func::expandTemplate('profile');
    #get the 'profile' DEF section expanding the inline Template macros (such as %USER% and %TYPE%)
    #NOTE: when using it this way, it is important to use the double quotes "" to delineate the values of the parameters.
    my $tml = Foswiki::Func::expandTemplate(
        '"profile" USER="' . $user . '" TYPE="' . $type . '"' );

=cut

=begin TML

---++ Rendering

=cut

=begin TML

---+++ expandCommonVariables( $text, $topic, $web, $meta ) -> $text

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

=begin TML

---+++ renderText( $text, $web, $topic ) -> $text

Render text from TML into XHTML as defined in [[%SYSTEMWEB%.TextFormattingRules]]
   * =$text= - Text to render, e.g. ='*bold* text and =fixed font='=
   * =$web=  - Web name, optional, e.g. ='Main'=. The current web is taken if missing
   * =$topic= - topic name, optional, defaults to web home
Return: =$text=    XHTML text, e.g. ='&lt;b>bold&lt;/b> and &lt;code>fixed font&lt;/code>'=

NOTE: renderText expects that all %MACROS% have already been expanded - it does not expand them for you (call expandCommonVariables above).

=cut

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

=begin TML

---+++ addToZone( $zone, $id, $data, $requires )

Direct interface to %<nop>ADDTOZONE (see %SYSTEMWEB%.VarADDTOZONE)

   * =$zone= - name of the zone
   * =$id= - unique ID
   * =$data= - the content.
   * =requires= optional, comma-separated list of =$id= identifiers that should
     precede the content

All macros present in =$data= will be expanded before being inserted into the =&lt;head>= section.

<blockquote class="foswikiHelp">%X%
*Note:* Read the developer supplement at Foswiki:Development.AddToZoneFromPluginHandlers if you are
calling =addToZone()= from a rendering or macro/tag-related plugin handler
</blockquote>

Examples:
<verbatim>
Foswiki::Func::addToZone( 'head', 'PATTERN_STYLE',
   '<link rel="stylesheet" type="text/css" href="%PUBURL%/Foswiki/PatternSkin/layout.css" media="all" />');

Foswiki::Func::addToZone( 'script', 'MY_JQUERY',
   '<script type="text/javascript" src="%PUBURL%/Myweb/MyJQuery/myjquery.js"></scipt>',
   'JQUERYPLUGIN::FOSWIKI');
</verbatim>

=cut=

=begin TML

---++ Controlling page output

=cut

=begin TML

---+++ redirectCgiQuery( $query, $url, $passthru, $status )

*DEPRECATED* Use =Foswiki::App::redirect()= method instead.

Redirect to URL
   * =$query= - CGI query object. Ignored, only there for compatibility. The session CGI query object is used instead.
   * =$url=   - URL to redirect to
   * =$passthru= - enable passthrough.
   * =$status= - HTTP status code (30x) to redirect with. Optional, defaults to 302. *Since* 2012-03-28

Return:             none

Issue a =Location= HTTP header that will cause a redirect to a new URL.
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
my $query = Foswiki::Func::getRequestObject();
$query->param(-name => 'text', -value => 'Different text');
Foswiki::Func::redirectCgiQuery(
  undef, Foswiki::Func::getScriptUrl($web, $topic, 'edit'), 1);
</verbatim>
=$passthru= does nothing if =$url= does not point to a script in the current
Foswiki installation.

=cut

sub redirectCgiQuery {
    my ( $query, $url, $passthru, $status ) = @_;
    ASSERT($Foswiki::app) if DEBUG;
    writeWarning("redirectCgiQuery: not a valid redirect status: $status")
      if $status && $status !~ /^\s*3\d\d.*/;
    return $Foswiki::app->redirect( $url, $passthru, $status );
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

The directory and its contents are permanent, so Plugins must be careful
to keep their areas tidy.

For temporary file storage that only exists for the life of the transaction,
use the Perl =File::Temp=  or related =File::Spec= functions.

=cut

=begin TML

---+++ readFile( $filename, $unicode ) -> $text

Read file, low level. Used for Plugin workarea.
   * =$filename= - Full path name of file
   * =$unicode= - Specify that file contains unicode text  *New with Foswiki 2.0*
Return: =$text= Content of file, empty if not found

__NOTE:__ Use this function only for the Plugin workarea, *not* for topics and attachments. Use the appropriate functions to manipulate topics and attachments.

Foswiki 2.0 APIs generally all use UNICODE strings, and all data is properly decoded from/to utf-8 at the edge.  *This API is an exception!*
Because this API can be used to retrieve data of any type including binary data, it is *not* decoded to unicode by default.
By default, data is read as raw bytes, without any encoding layer.

If you are using this API to read topic originated data, topic names, etc. then you should set the =$unicode= flag so that the data returned is a valid perl character string.

=cut

sub readFile {
    return Foswiki::readFile(@_);
}

=begin TML

---+++ saveFile( $filename, $text, $unicode )

Save file, low level. Used for Plugin workarea.
   * =$filename= - Full path name of file
   * =$text=     - Text to save
   * =$unicode=  - Flag indicates that $text string should be saved as utf-8. *New with Foswiki 2.0*

Return:                none

__NOTE:__ Use this function only for the Plugin workarea, *not* for topics and attachments. Use the appropriate functions to manipulate topics and attachments.

Foswiki 2.0 APIs generally all use UNICODE strings, and all data is properly decoded from/to utf-8 at the edge.  *This API is an exception!*
Because this API can be used to save data of any type including binary data, it is *not* decoded to unicode by default.
By default, data is written as raw bytes, without any encoding layer.

If you are using this API to write topic data, topic names, etc. then you should set the =$unicode= flag so that the data returned as a valid perl character string.

Failure to set the =$unicode= flag when required will result in perl "Wide character in print" errors.

=cut

sub saveFile {
    return Foswiki::saveFile(@_);
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
| <tt>( 'Web1', 'Web2.' )</tt>          | <tt>( 'Web2', 'WebHome' ) </tt>  |

Note that sub web names (Web.SubWeb) are only available if hierarchical webs are enabled in =configure=.

The symbols %<nop>USERSWEB%, %<nop>SYSTEMWEB% and %<nop>DOCWEB% can be used in the input to represent the web names set in $cfg{UsersWebName} and $cfg{SystemWebName}. For example:
| *Input*                               | *Return* |
| <tt>( '%<nop>USERSWEB%', 'Topic' )</tt>     | <tt>( 'Main', 'Topic' ) </tt>  |
| <tt>( '%<nop>SYSTEMWEB%', 'Topic' )</tt>    | <tt>( 'System', 'Topic' ) </tt>  |
| <tt>( '', '%<nop>DOCWEB%.Topic' )</tt>    | <tt>( 'System', 'Topic' ) </tt>  |

=cut

=begin TML

---+++ query($searchString, $topics, \%options ) -> iterator (resultset)

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
    my $matches = Foswiki::Func::query( "Slimy Toad", undef,
            { web => 'Main,San*', casesensitive => 0, files_without_match => 0 } );
    while ($matches->hasNext) {
        my $webtopic = $matches->next;
        my ($web, $topic) = Foswiki::Func::normalizeWebTopicName('', $webtopic);
      ...etc
</verbatim>

=cut

=begin TML

---+++ decodeFormatTokens($str) -> $unencodedString

Alias for =Foswiki::expandStandardEscapes()=.

Foswiki has an informal standard set of tokens used in =format=
parameters that are used to block evaluation of paramater strings.
For example, if you were to write

=%<nop>MYTAG{format="%<nop>WURBLE%"}%=

then %<nop>WURBLE would be expanded *before* %<NOP>MYTAG is evaluated. To avoid
this Foswiki uses escapes in the format string. For example:

=%<nop>MYTAG{format="$percentWURBLE$percent"}%=

This lets you enter arbitrary strings into parameters without worrying that
Foswiki will expand them before your plugin gets a chance to deal with them
properly. Once you have processed your tag, you will want to expand these
tokens to their proper value. That's what this function does.

The set of tokens that is expanded is described in System.FormatTokens.

=cut

*decodeFormatTokens = \&Foswiki::expandStandardEscapes;

=begin TML

---+++ sanitizeAttachmentName($fname) -> ($fileName, $origName)

Alias for =Foswiki::Sandbox::sanitizeAttachmentName()=.

Given a file path, sanitise it according to the rules for transforming
attachment names. Returns
the sanitised name together with the basename before sanitisation.

Sanitation includes filtering illegal characters and mapping client
file names to legal server names.

Avoid using this if you can; rewriting attachment names uses some very
nasty heuristics that cannot be changed because of compatibility issues.
It is much better use point-of-source validation to ensure only valid
attachment names are uploaded.

=cut

*sanitizeAttachmentName = \&Foswiki::Sandbox::sanitizeAttachmentName;

=begin TML

---+++ spaceOutWikiWord( $word, $sep ) -> $text

Spaces out a wiki word by inserting a string (default: one space) between each word component.
With parameter $sep any string may be used as separator between the word components; if $sep is undefined it defaults to a space.

=cut

*spaceOutWikiWord = \&Foswiki::spaceOutWikiWord;

=begin TML

---+++ isTrue( $value, $default ) -> $boolean

Returns 1 if =$value= is true, and 0 otherwise. "true" means set to
something with a Perl true value, with the special cases that "off",
"false" and "no" (case insensitive) are forced to false. Leading and
trailing spaces in =$value= are ignored.

If the value is undef, then =$default= is returned. If =$default= is
not specified it is taken as 0.

=cut

*isTrue = \&Foswiki::isTrue;

=begin TML

---+++ isValidWikiWord ( $text ) -> $boolean

Check for a valid WikiWord or WikiName
   * =$text= - Word to test

=cut

*isValidWikiWord = \&Foswiki::isValidWikiWord;

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

*extractParameters = \&Foswiki::Attrs::extractParameters;

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

*extractNameValuePair = \&Foswiki::Attrs::extractValue;

=begin TML

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

=begin TML

---++ Logging

=cut

=begin TML

---+++ writeEvent( $action, $extra )

Log an event.
   * =$action= - name of the event (keep them unique!)
   * =$extra= - arbitrary extra information to add to the log.
You can enumerate the contents of the log using the =eachEventSince= function.

*NOTE:* Older plugins may use =$Foswiki::cfg{LogFileName}=. These
plugins must be modified to use =writeEvent= and =eachEventSince= instead.

To maintain compatibility with older Foswiki releases, you can write
conditional code as follows:
<verbatim>
if (defined &Foswiki::Func::writeEvent) {
   # use writeEvent and eachEventSince
} else {
   # old code using {LogFileName}
}
</verbatim>

Note that the ability to read/write =$Foswiki::cfg{LogFileName}= is
maintained for compatibility but is *deprecated* (should not be used
in new code intended to work only with Foswiki 1.1 and later) and will
not work with any installation that stores logs in a database.

=cut

=begin TML

---+++ writeWarning( $text )

Log a warning that may require admin intervention to the warnings log (=data/warn*.txt=)
   * =$text= - Text to write; timestamp gets added

=cut

=begin TML

---+++ writeDebug( $text )

Log debug message to the debug log 
   * =$text= - Text to write; timestamp gets added

=cut

=begin TML

---+++ eachEventSince($time, $level) -> $iterator
   * =$time= - a time in the past (seconds since the epoch)
   * =$level= - log level to return events for.

Get an iterator over the list of all the events at the given level
between =$time= and now. Events are written to the event log using
=writeEvent=. The Foswiki core will write other events that will
also be returned.

If the chosen Logger does not support querying the logs, an empty
iterator will be returned.  The supplied PlainFile and Compatibility loggers
will return events only if the log files have not been archived.

Events are returned in *oldest-first* order.

Each event is returned as a reference to an array. The elements are:
   1 date of the event (seconds since the epoch)
   1 login name of the user who triggered the event
   1 the event name (the $action passed to =writeEvent=)
   1 the Web.Topic that the event applied to
   1 Extras (the $extra passed to =writeEvent=)
   1 The IP address that was the source of the event (if known)

Use the iterator like this:
<verbatim>
my $it = Foswiki::Func::eachEventSince(Foswiki::Time::parseTime("1 Apr 2010"));
while ($it->hasNext()) {
   my $entry = $it->next();
   my $date = $entry->[0];
   my $loginName = $entry->[1];
   ...
}
</verbatim>

=cut

#sub eachEventSince {
#    my $time = shift;
#    return $Foswiki::app->logger->eachEventSince( $time, 'info' );
#}

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
If the currently-running code version is 1.1 _or later_, then the _handler will not be called_ and _the warning will not be issued_. Wersions of =Foswiki::Plugins= before 1.1 will still call the handler as required.

The following functions are retained for compatibility only. You should
stop using them as soon as possible.

=cut

=begin TML

---+++ getRegularExpression( $name ) -> $expr

*Deprecated* 28 Nov 2008 - use =$Foswiki::regex{...}= instead, it is directly
equivalent.

See System.DevelopingPlugins for more information

=cut

sub _deprecated_getRegularExpression {
    my ($regexName) = @_;
    return $Foswiki::regex{$regexName};
}

=begin TML

---+++ getWikiToolName( ) -> $name

*Deprecated* 28 Nov 2008 in Foswiki; use $Foswiki::cfg{WikiToolName} instead

=cut

sub _deprecated_getWikiToolName { return $Foswiki::cfg{WikiToolName}; }

=begin TML

---+++ getMainWebname( ) -> $name

*Deprecated* 28 Nov 2008 in Foswiki; use $Foswiki::cfg{UsersWebName} instead

=cut

sub _deprecated_getMainWebname { return $Foswiki::cfg{UsersWebName}; }

=begin TML

---+++ getTwikiWebname( ) -> $name

*Deprecated* 28 Nov 2008 in Foswiki; use $Foswiki::cfg{SystemWebName} instead

=cut

sub _deprecated_getTwikiWebname { return $Foswiki::cfg{SystemWebName}; }

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
   use Try::Tiny;

   Foswiki::OopsException->throw(
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

sub _deprecated_getOopsUrl {
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

sub _deprecated_wikiToEmail {
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
foreach my $type (qw( ALLOW DENY )) {
    foreach my $action (qw( CHANGE VIEW )) {
        my $pref = $type . 'WEB' . $action;
        my $val = Foswiki::Func::getPreferencesValue( $pref, $web ) || '';
        if( $val =~ m/\S/ ) {
            print "$pref is set to $val on $web\n";
        }
    }
}
</verbatim>

=cut

sub _deprecated_permissionsSet {
    my ($web) = @_;

    foreach my $type (qw( ALLOW DENY )) {
        foreach my $action (qw( CHANGE VIEW RENAME )) {
            my $pref = $type . 'WEB' . $action;
            my $val = getPreferencesValue( $pref, $web ) || '';
            return 1 if ( $val =~ m/\S/ );
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

sub _deprecated_getPublicWebList {
    return getListOfWebs("user,public");
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

sub _deprecated_formatTime {

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

sub _deprecated_formatGmTime {

    #   my ( $epSecs, $format ) = @_;
    require Foswiki::Time;
    return Foswiki::Time::formatTime( @_, 'gmtime' );
}

=begin TML

---+++ getDataDir( ) -> $dir

*Deprecated* 28 Nov 2008 - use the "Webs, Topics and Attachments" functions
to manipulate topics instead

=cut

sub _deprecated_getDataDir {
    return $Foswiki::cfg{DataDir};
}

=begin TML

---+++ getPubDir( ) -> $dir

*Deprecated* 28 Nov 2008 - use the "Webs, Topics and Attachments" functions
to manipulate attachments instead

=cut

sub _deprecated_getPubDir { return $Foswiki::cfg{PubDir}; }

=begin TML

---+++ getCgiQuery( ) -> $query

*Deprecated* 31 Mar 2009 - use =getRequestObject= instead if you can. Code
that is expected to run with pre-1.1 versions of Foswiki will still need to
use this method, as =getRequestObject= will not be available.

=cut

sub _deprecated_getCgiQuery { return getRequestObject(); }

# Removed; it was never used
#sub checkDependencies {
#    die
#"checkDependencies removed; contact plugin author or maintainer and tell them to use BuildContrib DEPENDENCIES instead";
#}

=begin TML

---+++ readTopicText( $web, $topic, $rev, $ignorePermissions ) -> $text

Read topic text, including meta data
   * =$web=                - Web name, e.g. ='Main'=, or empty
   * =$topic=              - Topic name, e.g. ='MyTopic'=, or ="Main.MyTopic"=
   * =$rev=                - Topic revision to read, optional. Specify the minor part of the revision, e.g. ="5"=, not ="1.5"=; the top revision is returned if omitted or empty.
   * =$ignorePermissions=  - Set to ="1"= if checkAccessPermission() is already performed and OK; an oops URL is returned if user has no permission

Return: =$text=                  Topic text with embedded meta data; an oops URL for calling redirectCgiQuery() is returned in case of an error

*Deprecated: 6 Aug 2009. Use =readTopic= instead.
This method returns meta-data embedded in the text. Plugins authors must be very careful to avoid damaging meta-data. Use readTopic instead, which is a lot safer and supports the full set of read options.

=cut

sub _deprecated_readTopicText {
    my ( $web, $topic, $rev, $ignorePermissions ) = @_;
    ASSERT($Foswiki::app) if DEBUG;

    my $user;
    $user = $Foswiki::app->user
      unless defined($ignorePermissions);

    my $topicObject = Foswiki::Meta->load( $Foswiki::app, $web, $topic, $rev );

    my $text;
    if (   $ignorePermissions
        || $topicObject->haveAccess( 'VIEW', $Foswiki::app->user ) )
    {
        require Foswiki::Serialise;
        $text = Foswiki::Serialise::serialise( $topicObject, 'Embedded' );
    }
    else {
        $text = getScriptUrl(
            $web, $topic, 'oops',
            template => 'oopsaccessdenied',
            def      => 'topic_access',
            param1   => 'VIEW',
            param2   => $Foswiki::Meta::reason
        );
    }

    return $text;
}

=begin TML

---+++ saveTopicText( $web, $topic, $text, $ignorePermissions, $dontNotify ) -> $oopsUrl

Save topic text, typically obtained by readTopicText(). Topic data usually includes meta data; the file attachment meta data is replaced by the meta data from the topic file if it exists.
   * =$web=                - Web name, e.g. ='Main'=, or empty
   * =$topic=              - Topic name, e.g. ='MyTopic'=, or ="Main.MyTopic"=
   * =$text=               - Topic text to save, assumed to include meta data
   * =$ignorePermissions=  - Set to ="1"= if checkAccessPermission() is already performed and OK
   * =$dontNotify=         - Set to ="1"= if not to notify users of the change

*Deprecated* 6 Aug 2009 - use saveTopic instead.
=saveTopic= supports embedded meta-data in the saved text, and also
supports the full set of save options.

Return: =$oopsUrl=               Empty string if OK; the =$oopsUrl= for calling redirectCgiQuery() in case of error

<verbatim>
my $text = Foswiki::Func::readTopicText( $web, $topic );

# check for oops URL in case of error:
if( $text =~ m/^http.*?\/oops/ ) {
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

sub _deprecated_saveTopicText {
    my ( $web, $topic, $text, $ignorePermissions, $dontNotify ) = @_;
    ASSERT($Foswiki::app) if DEBUG;

    my $session = $Foswiki::app;

    # extract meta data and merge old attachment meta data
    my $topicObject =
      $Foswiki::app->create( 'Foswiki::Meta', web => $web, topic => $topic );
    $topicObject->remove('FILEATTACHMENT');

    my $oldMeta = Foswiki::Meta->load( $session, $web, $topic );
    $topicObject->copyFrom( $oldMeta, 'FILEATTACHMENT' );

    my $outcome = '';
    unless ( $ignorePermissions || $topicObject->haveAccess('CHANGE') ) {
        my @caller = caller(1);
        return getScriptUrl(
            $web, $topic, 'oops',
            template => 'oopsattention',
            def      => 'topic_access',
            param1   => ( $caller[0] || 'unknown' )
        );
    }

    #see Tasks.Item11586 - saveTopicText is supposed to use the embedded meta
    require Foswiki::Serialise;
    Foswiki::Serialise::deserialise( $text, 'Embedded', $topicObject );

    # Ensure the meta object realises it's the latest
    $topicObject->setLoadStatus( $topicObject->getLoadedRev, 1 );

    try {
        $topicObject->save( minor => $dontNotify );
    }
    catch {
        my $e = $_;
        Foswiki::Exception->rethrow($e) unless ref($e);
        if ( $e->isa('Foswiki::OopsException') ) {
            $e->rethrow;    # propagate
        }
        elsif ( $e->isa('Foswiki::Exception') ) {
            $outcome = getScriptUrl(
                $web, $topic, 'oops',
                template => 'oopsattention',
                def      => 'save_error',
                param1   => $e->text
            );
        }
        elsif ( $e->isa('Error') ) {
            $outcome = getScriptUrl(
                $web, $topic, 'oops',
                template => 'oopsattention',
                def      => 'save_error',
                param1   => $e->{-text}
            );
        }
    };
    return $outcome;
}

=begin TML

---+++ addToHEAD( $id, $data, $requires )

Adds =$data= to the HTML header (the &lt;head> tag).

*Deprecated* 26 Mar 2010 - use =addZoZone('head', ...)=.

%X% *Note:* Any calls using addToHEAD for javascript should be rewritten to use the
new =script= zone in addToZone as soon as possible.

Rewrite:
<verbatim>
Foswiki::Func::addToHEAD("id", "<script>...</script>", "JQUERYPLUGIN");
</verbatim>
To:
<verbatim>
Foswiki::Func::addToZone("script", "id", "<script>...</script>", "JQUERYPLUGIN");
</verbatim>

The reason is that all &lt;script> markup should be added to a dedicated zone, script,
and so any usage of ADDTOHEAD - which adds to the head zone - will be unable to
satisfy ordering requirements when the requirements exist in another zone ( script ).

See Foswiki:Development/UpdatingExtensionsScriptZone for more details.

=cut

sub _deprecated_addToHEAD {
    my $session = $Foswiki::app;
    ASSERT($session) if DEBUG;
    $session->zones()->addToZone( 'head', @_ );
}

=begin TML

---+++ searchInWebContent($searchString, $web, \@topics, \%options ) -> reference to a hash - keys of which are topic names

*Deprecated* 17 Oct 2010 - use =query( ...)=.
__WARNING: This function has been deprecated in foswiki 1.1.0 for scalability reasons__


Search for a string in the content of a web. The search is over all content, including meta-data. 
Meta-data matches will be returned as formatted lines within the topic content (meta-data matches are returned as lines of the format %META:\w+{.*}%)
   * =$searchString= - the search string, in egrep format
   * =$web= - The web/s to search in - string can have the same form as the =web= param of SEARCH
   * =\@topics= - reference to a list of topics to search (if undef, then the store will search all topics in the specified web/webs.)
   * =\%option= - reference to an options hash
The =\%options= hash may contain the following options:
   * =type= - =regex=, =keyword=, =query= - defaults to =regex=
   * =casesensitive= - false to ignore case (default true)
   * =files_without_match= - true to return files only (default false). If =files_without_match= is specified, it will return on the first match in each topic (i.e. it will return only one match per topic, and will not return matching lines).
   * TODO: topic, excludetopic and other params as per SEARCH

The return value is a reference to a hash which maps each matching topic
name to a list of the lines in that topic that matched the search,
as would be returned by 'grep'.

To iterate over the returned topics use:
<verbatim>
    my $matches = Foswiki::Func::searchInWebContent( "Slimy Toad", $searchWeb, \@topics,
            { casesensitive => 0, files_without_match => 0 } );
    foreach my $topic (keys(%$matches)) {
         ...etc
</verbatim>


=cut

sub _deprecated_searchInWebContent {

    my ( $searchString, $webs, $topics, $options ) = @_;
    ASSERT($Foswiki::app) if DEBUG;

    my $inputTopicSet = $topics;
    if ( $topics and ( ref($topics) eq 'ARRAY' ) ) {
        $inputTopicSet =
          $Foswiki::app->create( 'Foswiki::ListIterator', list => $topics );
    }
    $options->{type} ||= 'regex';
    $options->{web} = $webs;
    my $query = $Foswiki::app->search->parseSearch( $searchString, $options );

    my $itr = $Foswiki::app->store->query( $query, $inputTopicSet, $options );
    my %matches;
    while ( $itr->hasNext ) {
        my $webtopic = $itr->next;
        my ( $web, $searchTopic ) =
          Foswiki::Func::normalizeWebTopicName( '', $webtopic );
        $matches{$searchTopic} = 1;
    }
    return \%matches;
}

# %_funcPrefixMap defines what must be prepended by AUTOLOAD to the function
# name instead of `$Foswiki::app->'. For example, for a static function this
# could be changed to just `Foswiki::' if prototype is defined there. Not that
# for some more complicated cases where function maps into a method with
# different name in a different class this wouldn't work and manually defined
# function is required. See getUrlHost, for instance.
my %_funcPrefixMap = (
    getExternalResource   => '$Foswiki::app->net->',
    getSessionValue       => '$Foswiki::app->users->getLoginManager->',
    setSessionValue       => '$Foswiki::app->users->getLoginManager->',
    clearSessionValue     => '$Foswiki::app->users->getLoginManager->',
    registerTagHandler    => '$Foswiki::app->plugins->',
    eachGroup             => '$Foswiki::app->users->',
    isGroup               => '$Foswiki::app->users->',
    expandTemplate        => '$Foswiki::app->templates->',
    addToZone             => '$Foswiki::app->zones->',
    getWorkArea           => '$Foswiki::app->store->',
    normalizeWebTopicName => '$Foswiki::app->request->',
    sendEmail             => '$Foswiki::app->net->',
);

our $AUTOLOAD;

sub AUTOLOAD {

    #say STDERR "AUTOLOAD($AUTOLOAD)";
    ( my $func = $AUTOLOAD ) =~ s/^.*:://;
    my $deprecatedFunc = "_deprecated_$func";
    my $funcBody;
    if ( __PACKAGE__->can($deprecatedFunc) ) {
        $funcBody = <<FBDY;
    \$Foswiki::app->logger->warn(
"Function $AUTOLOAD is deprecated; read Foswiki::Func manual to find how to deal with it!"
    );
    return ${deprecatedFunc}(\@_);
FBDY
    }
    else {
        my $funcPrefix = $_funcPrefixMap{$func} // '$Foswiki::app->';
        $funcBody = <<FBDY;
    ASSERT(\$Foswiki::app) if DEBUG;
    return ${funcPrefix}${func}(\@_);
FBDY
    }
    eval <<FUNC;
sub $func {
$funcBody
}
FUNC
    Foswiki::Exception::Fatal->throw( text => $@ ) if $@;
    goto &$func;
}

1;

__END__

Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/, http://Foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
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
