# Foswiki - The Free and Open Source Wiki, http://foswiki.org/
# See bottom of file for license and copyright information.
#
# This file contains a specification of the parts of Foswiki that can be
# configured using =configure=. It is combined with =Config.spec= files
# shipped with extensions to generate the interface seen when you run
# =configure=.
#
# When you run configure from your browser, it will work out required
# settings and write a new LocalSite.cfg. It should never be necessary to
# modify this file directly.
#
# If for some strange reason you want to brew your own LocalSite.cfg by
# copying this file (NOT recommended),  then you must un-comment and complete
# the PATH and URLPATH settings that are flagged as Mandatory ( M** ) and
# remove the __END__ line toward the end of the file.
#
# See 'setlib.cfg' in the 'bin' directory for how to configure a non-standard
# include path for Perl modules.
#
#############################################################################
#
# NOTE FOR DEVELOPERS:
# The comments in this file are formatted so that the 'configure' script
# can extract documentation from here. See
# http://foswiki.org/System/DevelopingPlugins#Integrating_with_configure
# for details of the syntax used.
#
# You can use $Foswiki::cfg variables in other settings,
# but you must be sure they are only evaluated under program control and
# NOT when this file is loaded. For example:
## $Foswiki::cfg{Blah} = "$Foswiki::cfg{DataDir}/blah.dat"; # BAD
## $Foswiki::cfg{Blah} = '$Foswiki::cfg{DataDir}/blah.dat'; # GOOD
#
# Note that the general path settings are deliberately commented out.
# This is because they *must* be defined in LocalSite.cfg, and *not* here.

#############################################################################
#---+ General path settings
# <p><strong>If you are a first-time installer:</strong> once you have set
# up the eight paths below, your wiki should work - try it. You can
# always come back and tweak other settings later.</p>
# <p><b>Security Note:</b> Only the URL paths listed below should
# be browseable from the web. If you expose any other directories (such as
# lib or templates) you are opening up routes for possible hacking attempts.</p>

# **URL CHECK="parts:scheme,authority,path \
#              partsreq:scheme,authority \
#              schemes:http,https \
#              authtype:host" \
#              M**
#  This is the root of all Foswiki URLs e.g. http://myhost.com:123.
# $Foswiki::cfg{DefaultUrlHost} = 'http://your.domain.com';

# **BOOLEAN EXPERT**
# Enable this parameter to force foswiki to ignore the hostname of the entered URL and generate all links using the <code>DefaultUrlHost</code>.
# <p>By default, foswiki will use whatever URL that was entered by the user to generate links. The only exception is the special "localhost"
# name, which will be automatically replaced by the DefaultUrlHost.  In most installations this is the preferred behavior, however when using
# SSL Accelerators, Reverse Proxys, and load balancers, the URL entered by the user may have been altered, and foswiki should be forced
# to return the <code>DefaultUrlHost</code>.</p>
$Foswiki::cfg{ForceDefaultUrlHost} = $FALSE;

# **URLPATH CHECK="expand" M**
# This is the 'cgi-bin' part of URLs used to access the Foswiki bin
# directory e.g. <code>/foswiki/bin</code><br />
# Do <b>not</b> include a trailing /.
# <p />
# See <a href="http://foswiki.org/Support/ShorterUrlCookbook" target="_new">ShorterUrlCookbook</a> for more information on setting up
# Foswiki to use shorter script URLs.  The setting for the <code>view</code> script may be adjusted below.  Other scripts need to
# be manually added to <code>lib/LocalSite.cfg</code>
# $Foswiki::cfg{ScriptUrlPath} = '/foswiki/bin';

# **URLPATH CHECK='expand nullok' M**
# This is the complete path used to access the Foswiki view script including any suffix.  Do not include a trailing /.
# (This is an exception override, so the ScriptSuffix is not automatically added.)
# e.g. <code>/foswiki/bin/view.pl</code><br />  Note:  The default is acceptable except when shorter URLs are used.
# <p />
# If you are using Shorter URL's, then this is typically set to the base path of your wiki, which should be the value
# of {ScriptUrlPath} excluding <code>/bin</code>. e.g. if your {ScriptUrlPath} is either empty or set to <code>/bin</code> leave
# <code>{ScriptUrlPaths}{view}</code> empty; if it is set to something like <code>/directory/bin</code> set it to <code>/directory</code>
# <p />
# Do not change
# this unless your Web Server configuration has been set to use shorter URLs.  See also the Foswiki
# <a href="http://foswiki.org/Support/ApacheConfigGenerator" target="_new">Apache Config Generator</a> and
# <a href="http://foswiki.org/Support/ShorterUrlCookbook" target="_new">Shorter URL Cookbook</a>
$Foswiki::cfg{ScriptUrlPaths}{view} =
  '$Foswiki::cfg{ScriptUrlPath}/view$Foswiki::cfg{ScriptSuffix}';

# **PATH AUDIT="DIRS" FEEDBACK="Validate Permissions" CHECK="guess:bin" M**
# This is the file system path used to access the Foswiki bin
# directory.
# $Foswiki::cfg{ScriptDir} = '/home/httpd/foswiki/bin';

# **URLPATH CHECK='expand' M T**
# Attachments URL path e.g. /foswiki/pub
# <p /><b>Security Note:</b> files in this directory are *not*
# protected by Foswiki access controls. If you require access controls, you
# will have to use webserver controls (e.g. .htaccess on Apache)
# $Foswiki::cfg{PubUrlPath} = '/foswiki/pub';

# **NUMBER FEEDBACK=AUTO EXPERT**
# This is the maximum number of files and directories that will be checked
# for permissions for the pub and data Directory paths.  This limit is initially set to
# 5000, which should be reasonable for a default installation.  If it is
# exceeded, then an informational message is returned stating that incomplete
# checking was performed.  If this is set to a large number on large installations,
# then a significant delay will be incurred when configure is run, due to the
# recursive directory checking.
$Foswiki::cfg{PathCheckLimit} = 5000;

# **PATH AUDIT="DIRS:1" FEEDBACK="Validate Permissions" CHECK="guess:pub perms:rw filter:',v$'" M**
# Attachments store (file path, not URL), must match /foswiki/pub e.g.
# /usr/local/foswiki/pub
# $Foswiki::cfg{PubDir} = '/home/httpd/foswiki/pub';

# **PATH AUDIT="DIRS" FEEDBACK="Validate Permissions" CHECK="guess:data perms:rwpd filter:',v$'" CHECK="perms:r filter:'\\\\.txt$'" M**
# Topic files store (file path, not URL) e.g. /usr/local/foswiki/data
# $Foswiki::cfg{DataDir} = '/home/httpd/foswiki/data';

# **PATH AUDIT="DIRS" FEEDBACK="Validate Permissions" CHECK="guess:tools perms:r" M**
# Tools directory e.g. /usr/local/foswiki/tools
# $Foswiki::cfg{ToolsDir} = '/home/httpd/foswiki/tools';

# **PATH AUDIT="DIRS" FEEDBACK="Validate Permissions" CHECK="guess:templates perms:r" M**
# Template directory e.g. /usr/local/foswiki/templates
# $Foswiki::cfg{TemplateDir} = '/home/httpd/foswiki/templates';

# **PATH AUDIT="DIRS" FEEDBACK="Validate Permissions" CHECK="guess:locale perms:r" M**
# Translation files directory (file path, not URL) e.g. /usr/local/foswiki/locale
# $Foswiki::cfg{LocalesDir} = '/home/httpd/foswiki/locale';

# **PATH  AUDIT="DIRS" FEEDBACK="Validate Permissions" CHECK="guess:working perms:rw" M**
# Directory where Foswiki stores files that are required for the management
# of Foswiki, but are not required to be browsed from the web.
# A number of subdirectories will be created automatically under this
# directory:
# <ul><li>{WorkingDir}<tt>/tmp</tt> - used for security-related temporary
# files (these files can be deleted at any time without permanent damage)
# <ul><li>
# <i>Passthrough files</i> are used by Foswiki to work around the limitations
# of HTTP when redirecting URLs</li>
# <li><i>Session files</i> are used to record information about active
# users - for example, whether they are logged in or not.</li>
# </ul>
# For obvious reasons, these files must <b>not</b> be browseable from the web!
# Additionally you are recommended to restrict access rights to this directory
# so only the web server user can create files.</li>
# <li>{WorkngDir}<tt>/requestTmp</tt> - used as an alternate location for the
# system <tt>/tmp</tt> directory.  This is only used if <tt>{TempfileDir}</tt>
# is configured.</li>
# <li>{WorkingDir}<tt>/work_areas</tt> - these are work areas used by
# extensions that need to store persistent data across sessions. </li>
# <li>{WorkingDir}<tt>/registration_approvals</tt> - this is used by the
# default Foswiki registration process to store registrations that are pending
# verification.</li>
# </ul>
# $Foswiki::cfg{WorkingDir} = '/home/httpd/foswiki/working';

# **PATH**
# This is used to override the default system temporary file location.
# Set this if you wish to have control over where working tmp files are
# created.  It substitutes as the environment <tt>TempfileDir</tt> setting which
# will not be used by perl for security reasons.
#$Foswiki::cfg{TempfileDir} = '/tmp';

# **STRING**
# If your host has aliases (such as both www.mywiki.net and mywiki.net
# and some IP addresses) you need to tell Foswiki that redirecting to them
# is OK. Foswiki uses redirection as part of its normal mode of operation
# when it changes between editing and viewing.
# To prevent Foswiki from being used in phishing attacks and to protect it
# from middleman exploits, the security setting {AllowRedirectUrl} is by
# default disabled, restricting redirection to other domains. If a redirection
# to a different host is attempted, the target URL is compared against this
# list of additional trusted sites, and only if it matches is the redirect
# permitted.<br />
# Enter as a comma separated list of URLs (protocol, hostname and (optional)
# port) e.g. <code>http://your.domain.com:8080,https://other.domain.com</code>
$Foswiki::cfg{PermittedRedirectHostUrls} = '';

# **STRING 10**
# Suffix of Foswiki CGI scripts (e.g. .cgi or .pl). You may need to set this
# if your webserver requires an extension.
$Foswiki::cfg{ScriptSuffix} = '';

# **PATH FEEDBACK=On-Change M**
# You can override the default PATH setting to control
# where Foswiki looks for external programs, such as grep and rcs.
# By restricting this path to just a few key
# directories, you increase the security of your Foswiki.
# <ol>
# 	<li>
# 		Unix or Linux
# 		<ul>
# 			<li>
# 				Path separator is :
# 			</li>
# 			<li>
# 				Make sure diff and shell (Bourne or bash type) are found on path.
# 			</li>
# 			<li>
# 				Typical setting is /bin:/usr/bin
# 			</li>
# 		</ul>
# 	</li>
# 	<li>
# 		Windows ActiveState Perl, using DOS shell
# 		<ul>
# 			<li>
# 				path separator is ;
# 			</li>
# 			<li>
# 				The Windows system directory is required.
# 			</li>
# 			<li>
# 				Use '\' not '/' in pathnames.
# 			</li>
# 			<li>
# 				Typical setting is C:\windows\system32
# 			</li>
# 		</ul>
# 	</li>
# 	<li>
# 		Windows Cygwin Perl
# 		<ul>
# 			<li>
# 				path separator is :
# 			</li>
# 			<li>
# 				The Windows system directory is required.
# 			</li>
# 			<li>
# 				Use '/' not '\' in pathnames.
# 			</li>
# 			<li>
# 				Typical setting is /cygdrive/c/windows/system32
# 			</li>
# 		</ul>
# 	</li>
# </ol>
#$Foswiki::cfg{SafeEnvPath} = '';

# **STRING 20 EXPERT**
# {OS} and {DetailedOS} are calculated in the Foswiki code. <b>You
# should only need to override if there is something badly wrong with
# those calculations.</b><br />
# {OS} may be one of UNIX WINDOWS VMS DOS MACINTOSH OS2
$Foswiki::cfg{OS} = '';

# **STRING 20 EXPERT**
# The value of Perl $OS
$Foswiki::cfg{DetailedOS} = '';

#############################################################################
#---+ Security and Authentication -- TABS
# <p>The above tabs allow you to control most aspects of how Foswiki handles security
# related activities.</p>
#---++ Sessions
# <p>Sessions are how Foswiki tracks a user across multiple requests.
# <p>'Show expert options' has advanced options for controlling sessions.</p>

# **BOOLEAN**
# Control whether Foswiki will use persistent sessions.
# A user's session id is stored in a cookie, and this is used to identify
# the user for each request they make to the server.
# You can use sessions even if you are not using login.
# This allows you to have persistent session variables - for example, skins.
# Client sessions are not required for logins to work, but Foswiki will not
# be able to remember logged-in users consistently.
# See <a href="http://foswiki.org/System/UserAuthentication" target="_new">User
# Authentication</a> for a full discussion of the pros and
# cons of using persistent sessions.</p>
$Foswiki::cfg{UseClientSessions} = 1;

# **NUMBER FEEDBACK=AUTO 20 EXPERT DISPLAY_IF {UseClientSessions}**
# Set the session timeout, in seconds. The session will be cleared after this
# amount of time without the session being accessed. The default is 6 hours
# (21600 seconds).<p />
# <b>Note</b> By default, session expiry is done "on the fly" by the same
# processes used to
# serve Foswiki requests. As such it imposes a load on the server. When
# there are very large numbers of session files, this load can become
# significant. For best performance, you can set {Sessions}{ExpireAfter}
# to a negative number, which will mean that Foswiki won't try to clean
# up expired sessions using CGI processes. Instead you should use a cron
# job to clean up expired sessions. The standard maintenance cron script
# <tt>tools/tick_foswiki.pl</tt> includes this function.
# <p> Session files are stored in the <tt>{WorkingDir}/tmp</tt> directory.</p>
# <p> This setting is also used to set a lifetime for registration requests.</p>
$Foswiki::cfg{Sessions}{ExpireAfter} = 21600;

# **NUMBER FEEDBACK=AUTO EXPERT DISPLAY_IF {UseClientSessions} && {LoginManager}=='Foswiki::LoginManager::TemplateLogin'**
# TemplateLogin only.
# Normally the cookie that remembers a user session is set to expire
# when the browser exits, but using this value you can make the cookie
# expire after a set number of seconds instead. If you set it then
# users will be able to tick a 'Remember me' box when logging in, and
# their session cookie will be remembered even if the browser exits.<p />
# This should always be the same as, or longer than, {Sessions}{ExpireAfter},
# otherwise Foswiki may delete the session from its memory even though the
# cookie is still active.<p />
# A value of 0 will cause the cookie to expire when the browser exits.
# One month is roughly equal to 2600000 seconds.
$Foswiki::cfg{Sessions}{ExpireCookiesAfter} = 0;

# **BOOLEAN EXPERT DISPLAY_IF {UseClientSessions}**
# Foswiki will normally use a cookie in
# the browser to store the session ID. If the client has cookies disabled,
# then Foswiki will not be able to record the session. As a fallback, Foswiki
# can rewrite local URLs to pass the session ID as a parameter to the URL.
# This is a potential security risk, because it increases the chance of a
# session ID being stolen (accidentally or intentionally) by another user.
# If this is turned off, users with cookies disabled will have to
# re-authenticate for every secure page access (unless you are using
# {Sessions}{MapIP2SID}).
$Foswiki::cfg{Sessions}{IDsInURLs} = 0;

# **STRING 20 EXPERT DISPLAY_IF {UseClientSessions}**
# By default the Foswiki session cookie is only accessible by the host which
# sets it. To change the scope of this cookie you can set this to any other
# value (ie. company.com). Make sure that Foswiki can access its own cookie. <br />
# If empty, this defaults to the current host.
$Foswiki::cfg{Sessions}{CookieRealm} = '';

# **BOOLEAN EXPERT DISPLAY_IF {UseClientSessions}**
# It is possible to enable a check that the user trying to use a session
# is on the same IP address that was used when the session was created.
# This gives a small increase in security. Public web sites can easily be
# accessed by different users from the same IP address when they access
# through the same proxy gateway, meaning that the protection is limited.
# Additionally, people get more and more mobile using a mix of LAN, WLAN,
# and 3G modems and they will often change IP address several times per day.
# For these users IP matching causes the need to re-authenticate all the time.
# IP matching is therefore disabled by default and should only be enabled if
# you are sure the users IP address never changes during the lifetime of a
# session.
$Foswiki::cfg{Sessions}{UseIPMatching} = 0;

# **BOOLEAN EXPERT DISPLAY_IF {UseClientSessions}**
# For compatibility with older versions, Foswiki supports the mapping of the
# clients IP address to a session ID. You can only use this if all
# client IP addresses are known to be unique.
# If this option is enabled, Foswiki will <b>not</b> store cookies in the
# browser.
# The mapping is held in the file $Foswiki::cfg{WorkingDir}/tmp/ip2sid.
# If you turn this option on, you can safely turn {Sessions}{IDsInURLs}
# <i>off</i>.
$Foswiki::cfg{Sessions}{MapIP2SID} = 0;

# **OCTAL CHECK="min:000 max:777" FEEDBACK=AUTO EXPERT**
# File security for new session objects created by the login manager.
# You may have to adjust these permissions to allow (or deny) users other than the webserver
# user access session objects that Foswiki creates in the filesystem.
# This is an <strong>octal</strong> number representing the standard UNIX permissions
# (e.g. 0640 == rw-r-----)
$Foswiki::cfg{Session}{filePermission} = 0600;

#---++ Validation
# Validation is the process by which Foswiki validates that a request is
# allowed by the site, and is not part of an attack on the site.
# <p>'Show expert options' has advanced options for controlling validation.</p>
# **SELECT strikeone,embedded,none **
# <p>By default Foswiki uses Javascript to perform "double submission" validation
# of browser requests. This technique, called "strikeone", is highly
# recommended for the prevention of cross-site request forgery (CSRF). See also
# <a href="http://foswiki.org/Support/WhyYouAreAskedToConfirm" target="_new">
# Why am I being asked to confirm?</a>.</p>
# <p>If Javascript is known not to be available in browsers that use the site,
# or cookies are disabled, but you still want validation of submissions,
# then you can fall back on a embedded-key validation technique that
# is less secure, but still offers some protection against CSRF. Both
# validation techniques rely on user verification of "suspicious"
# transactions.</p>
# <p>This option allows you to select which validation technique will be
# used.<br />
# If it is set to "strikeone", or is undefined, 0, or the empty string, then
# double-submission using Javascript will be used.<br />
# If it is set to "embedded", then embedded validation keys will be used.<br/>
# If it is set to "none", then no validation of posted requests will
# be performed.</p>
$Foswiki::cfg{Validation}{Method} = 'strikeone';

# **NUMBER CHECK="min:1" FEEDBACK=AUTO EXPERT DISPLAY_IF {Validation}{Method}!='none'**
# Validation keys are stored for a maximum of this amount of time before
# they are invalidated. Time in seconds. A shorter time reduces the risk
# of a hacker finding and re-using one of the keys, at the cost of more
# frequent confirmation prompts for users.
$Foswiki::cfg{Validation}{ValidForTime} = 3600;

# **NUMBER CHECK="min:10" FEEDBACK=AUTO EXPERT DISPLAY_IF {Validation}{Method}!='none'**
# The maximum number of validation keys to store in a session. There is one
# key stored for each page rendered. If the number of keys exceeds this
# number, the oldest keys will be force-expired to bring the number down.
# This is a simple tradeoff between space on the server, and the number of
# keys a single user might use (usually dictated by the number of wiki pages
# they have open simultaneously)
$Foswiki::cfg{Validation}{MaxKeysPerSession} = 1000;

# **BOOLEAN EXPERT DISPLAY_IF {Validation}{Method}!='none'**
# Expire a validation key immediately when it is used to validate the saving
# of a page. This protects against an attacker evesdropping the communication
# between browser and server and exploiting the keys sent from browser to
# server. If this is enabled and a user edits and saves a page, and then goes
# back to the edit screen using the browser back button and saves again, they
# will be met by a warning screen against "Suspicious request from
# browser". The same warning will be displayed if you build an application with
# pages containing multiple forms and users try to submit from these
# forms more than once. If this warning screen is a problem for your users, you
# can disable this setting which enables reuse of validation keys.
# However this will lower the level of security against cross-site request
# forgery.
$Foswiki::cfg{Validation}{ExpireKeyOnUse} = 1;

#---++ Login
# <p>Foswiki supports different ways of handling how a user asks, or is asked,
# to log in.</p>
# <p>Infrequently used options can be displayed by clicking 'Show expert options'</p>
# **SELECTCLASS none,Foswiki::LoginManager::*Login**
# <ol><li>
# none - Don't support logging in, all users have access to everything.
# </li><li>
# Foswiki::LoginManager::TemplateLogin - Redirect to the login template, which
#   asks for a username and password in a form. Does not cache the ID in
#   the browser, so requires client sessions to work.
# </li><li>
# Foswiki::LoginManager::ApacheLogin - Redirect to an '...auth' script for which
#   Apache can be configured to ask for authorization information. Does
#   not require client sessions, but works best with them enabled.
# </li></ol>
$Foswiki::cfg{LoginManager} = 'Foswiki::LoginManager::TemplateLogin';

# **BOOLEAN EXPERT**
# Write debugging output to the webserver error log.
$Foswiki::cfg{Trace}{LoginManager} = 0;

# **STRING 100 DISPLAY_IF {LoginManager}=='Foswiki::LoginManager::TemplateLogin'**
# Comma-separated list of scripts in the bin directory that require the user to
# authenticate. This setting is used with TemplateLogin; any time an
# unauthenticated user attempts to access one of these scripts, they will be
# required to authenticate. With ApacheLogin, the web server must be configured
# to require a valid user for access to these scripts.  <code>edit</code> and
# <code>save</code> should be removed from this list if the guest user is permitted to
# edit topics without authentication.
$Foswiki::cfg{AuthScripts} =
'attach,compareauth,edit,manage,previewauth,rdiffauth,rename,restauth,save,statistics,upload,viewauth,viewfileauth';

# **BOOLEAN EXPERT DISPLAY_IF {LoginManager}=='Foswiki::LoginManager::TemplateLogin'**
# Browsers typically remember your login and passwords to make authentication
# more convenient for users. If your Foswiki is used on public terminals,
# you can prevent this, forcing the user to enter the login and password
# every time.
$Foswiki::cfg{TemplateLogin}{PreventBrowserRememberingPassword} = 0;

# **BOOLEAN EXPERT DISPLAY_IF {LoginManager}=='Foswiki::LoginManager::TemplateLogin'**
# Allow a user to log in to foswiki using the email addresses known to the password
# system (in addition to their username).
$Foswiki::cfg{TemplateLogin}{AllowLoginUsingEmailAddress} = 0;

# **REGEX EXPERT**
# The perl regular expression used to constrain user login names. Some
# environments may require funny characters in login names, such as \.
# This is a filter <b>in</b> expression i.e. a login name must match this
# expression or an error will be thrown and the login denied.
$Foswiki::cfg{LoginNameFilterIn} = qr/^[^\s\*?~^\$@%`"'&;|<>\x00-\x1f]+$/;

# **STRING 20 EXPERT**
# Guest user's login name. You are recommended not to change this.
$Foswiki::cfg{DefaultUserLogin} = 'guest';

# **STRING 20 EXPERT**
# Guest user's wiki name. You are recommended not to change this.
$Foswiki::cfg{DefaultUserWikiName} = 'WikiGuest';

# **STRING 20 EXPERT**
# An internal admin user login name (matched with the configure password, if set)
# which can be used as a temporary Admin login (see: Main.AdminUser).
# This login name is additionally required by the install script for some addons
# and plugins, usually to gain write access to the Foswiki web.
# If you change this you risk making topics uneditable.
$Foswiki::cfg{AdminUserLogin} = 'admin';

# **STRING 20 EXPERT**
# An admin user WikiName that is displayed for actions done by the AdminUserLogin
# You should normally not need to change this. (You will need to move the
# %USERSWEB%.AdminUser topic to match. Do not register a user with this name!)
# This is a special WikiName and should never be directly authenticated.
# It is accessed by logging in using the AdminUserLogin either directly or with the
# sudo login.
$Foswiki::cfg{AdminUserWikiName} = 'AdminUser';

# **STRING 20 EXPERT**
# Group of users that can use special action=repRev and action=delRev
# on <code>save</code> and ALWAYS have edit powers. See %SYSTEMWEB%.CompleteDocumentation
# for an explanation of wiki groups. This user will also run all the
# standard cron jobs, such as statistics and mail notification.
# The default value "AdminGroup" is used everywhere in Foswiki to
# protect important settings so you would need a really special reason to
# change this setting.
$Foswiki::cfg{SuperAdminGroup} = 'AdminGroup';

# **STRING 20 EXPERT**
# Name of topic in the {UsersWebName} web where registered users
# are listed. Automatically maintained by the standard
# registration scripts. <b>If you change this setting you will have to
# use Foswiki to manually rename the existing topic</b>
$Foswiki::cfg{UsersTopicName} = 'WikiUsers';

#---++ User mapping
# The user mapping is used to equate login names, used with external
# authentication systems, with Foswiki user identities.
# **SELECTCLASS Foswiki::Users::*UserMapping**
# By default only
# two mappings are available, though other mappings *may* be installed to
# support authentication providers.
# <ol><li>
#  Foswiki::Users::TopicUserMapping - uses Foswiki user and group topics to
#  determine user information, and group memberships.
# </li><li>
#  Foswiki::Users::BaseUserMapping - has only pseudo users such as {AdminUser} and
#  {DefaultUserWikiName}, with the Admins login and password being set from this
#  configure script. <b>Does not support User registration</b>, and
#  only works with TemplateLogin.
# </li></ol>
$Foswiki::cfg{UserMappingManager} = 'Foswiki::Users::TopicUserMapping';

# **BOOLEAN EXPERT DISPLAY_IF {UserMappingManager}=="Foswiki::Users::TopicUserMapping"**
# Enable this parameter to force the TopicUserMapping manager to directly manage email
# accresses, and not pass management over to the PasswordManager. When enabled, TopicUserMapping
# will store addresses in the user topics.<br />
# Default is disabled.  The PasswordManager will determine what is responsible for storing email addresses.<br />
# <br />
# Note: Foswiki provides a utility to migrate emails from user topic to the password file, but
# does not provide any way to migrate emails from the password file back to user topics.
$Foswiki::cfg{TopicUserMapping}{ForceManageEmails} = $FALSE;

#---++ Access Control
# **SELECTCLASS Foswiki::Access::*Access**
# <ol><li>
# TopicACLAccess is the normal foswiki ACL system, as documented throught the setup guides.
# </li><li>
# AdminOnlyAccess denies all non-admins (not in the AdminGroup) any access to the wiki - useful for site maintainence.
# </li></ol>
$Foswiki::cfg{AccessControl} = 'Foswiki::Access::TopicACLAccess';

#---++ Passwords
# <p>The password manager handles the passwords database, and provides
# password lookup, and optionally password change, services to the rest of
# Foswiki.</p>
# **SELECTCLASS none,Foswiki::Users::*User**
# Name of the password handler implementation. Foswiki ships with two alternative implementations:
# <ol><li>
# Foswiki::Users::HtPasswdUser - handles 'htpasswd' format files, with
#   passwords encoded as per the HtpasswdEncoding
# </li><li>
# Foswiki::Users::ApacheHtpasswdUser - should behave identically to
# HtpasswdUser for crypt encoding, but uses the CPAN:Apache::Htpasswd package to interact
# with Apache. It is shipped mainly as a demonstration of how to write
# a new password manager.  It is not recommended for production.
# </li></ol>
# You can provide your own alternative by implementing a new subclass of
# Foswiki::Users::Password, and pointing {PasswordManager} at it in
# lib/LocalSite.cfg.<p />
# If 'none' is selected, users will not be able to change passwords
# and TemplateLogin manager then will always succeed, regardless of
# what username or password they enter. This may be useful when you want to
# enable logins so Foswiki can identify contributors, but you don't care about
# passwords. Using ApacheLogin and PassordManager set to 'none' (and
# AllowLoginName = true) is a common  Enterprise SSO configuration, in which
# any logged in user can then register to create  their Foswiki Based identity.
$Foswiki::cfg{PasswordManager} = 'Foswiki::Users::HtPasswdUser';

# **NUMBER FEEDBACK=AUTO**
# Minimum length for a password, for new registrations and password changes.
# If you want to allow null passwords, set this to 0.
$Foswiki::cfg{MinPasswordLength} = 7;

# **PATH DISPLAY_IF /htpasswd/i.test({PasswordManager})**
# Path to the file that stores passwords, for the Foswiki::Users::HtPasswdUser
# password manager. You can use the <tt>htpasswd</tt> Apache program to create a new
# password file with the right encoding, however use caution, as it will remove
# email addresses from an existing file.
$Foswiki::cfg{Htpasswd}{FileName} = '$Foswiki::cfg{DataDir}/.htpasswd';

# **PATH EXPERT DISPLAY_IF /htpasswd/i.test({PasswordManager})**
# Path to the lockfile for the password file.  This normally does not need to be changed
# however if two Foswiki installations share and update a common password file it is
# critical that both use the same lockfile.  For example, change it to the location of the
# password file,  <tt>$Foswiki::cfg{DataDir}/htpasswd.lock</tt>.  Foswiki must have
# rights to create the file in this location.
# Only applicable to <tt>HtPasswdUser</tt>.
$Foswiki::cfg{Htpasswd}{LockFileName} =
  '$Foswiki::cfg{WorkingDir}/htpasswd.lock';

# **BOOLEAN EXPERT DISPLAY_IF {PasswordManager}=="Foswiki::Users::HtPasswdUser"**
# Enable this option on systems using <tt>FastCGI, FCGID, or Mod_Perl</tt> in order to avoid reading the password file
# for every transaction. It will cause the <tt>HtPasswdUser</tt> module to globally
# cache the password file, reading it only once on initization.
$Foswiki::cfg{Htpasswd}{GlobalCache} = $FALSE;

# **BOOLEAN DISPLAY_IF {PasswordManager}=="Foswiki::Users::HtPasswdUser"**
# Enable this option if the .htpasswd file can be updated either external to Foswiki
# or by another Foswiki instance.  When enabled, Foswiki will verify the timestamp of
# the file and will invalidate the cache if the file has been changed. This is only useful
# if Foswiki is running in a <tt>mod_perl</tt> or <tt>fcgi</tt> envinroment.
$Foswiki::cfg{Htpasswd}{DetectModification} = $FALSE;

# **SELECT bcrypt,htdigest-md5,apache-md5,sha1,crypt-md5,crypt,plain DISPLAY_IF /htpasswd/i.test({PasswordManager})**
# Password encryption, for the <tt>Foswiki::Users::HtPasswdUser</tt> password manager. This
# specifies the type of password hash to generate when writing entries to <tt>.htpasswd</tt>
# It is also used when reading password entries unless the parameter
# <tt>{Htpasswd}{AutoDetect}</tt> is enabled.
# <br /><br />
# The choices in order of strongest to lowest strength:
# <dl>
# <dt>(HTTPS)</dt><dd> Any below encoding over an HTTPS SSL connection. (Not a selection here.)</dd>
# <dt><tt>htdigest-md5</tt></dt><dd> Strongest only when combined with the <tt>Foswiki::LoginManager::ApacheLogin</tt>
# Useful on sites where password files are required to be
# portable. The <tt>{AuthRealm}</tt> value is used with the username and password to generate
# the hashed form of the password, thus: <tt>user:{AuthRealm}:hash</tt>.
# This encoding is generated by the Apache <tt>htdigest</tt> command.</dd>
# <dt><tt>bcrypt</tt></dt><dd>Hash based upon blowfish algorithm, strength of hash controlled by a cost parameter.
# <b>Not compatible with Apache Authentication</b></dd>
# <dt><tt>apache-md5</tt></dt><dd> Enable an Apache-specific algorithm using an iterated
# (1,000 times) MD5 digest of various combinations of a random 32-bit salt and the password
# (<tt>userid:$apr1$salt$hash</tt>).  This is the default.
# This is the encoding generated by the <tt>htpasswd -m</tt> command.</dd>
# <dt><tt>sha1</tt></dt><dd>It has the strongest hash however does not use salt and is therefor more
# vulnerable to dictionary attacks.  This is the encoding
# generated by the <tt>htpasswd -s</tt> command (<tt>userid:{SHA}hash</tt>).</dd>
# <dt><tt>crypt-md5</tt></dt><dd> Enable use of standard libc (/etc/shadow) crypt-md5 password
# (like <tt>user:$1$salt$hash:email</tt>).  Unlike <tt>crypt</tt> encoding, it does not suffer from password truncation.
# Passwords are salted, and the salt is stored in the encrypted password string as in normal crypt passwords. This
# encoding is understood by Apache but cannot be generated by the <tt>htpasswd</tt> command.</dd>
# <dt><tt>crypt</tt></dt><dd> <b>Not Recommended.</b> crypt encoding only
# uses the first 8 characters of the password. Extra characters are silently discarded.
# This is the default generated by the Apache <tt>htpasswd</tt> command (<tt>user:hash:email</tt>)</dd>
# <dt><tt>plain</tt></dt><dd> stores passwords as plain text (no encryption). Useful for testing.</dd>
# </dl>
# If you need to create entries in <tt>.htpasswd</tt> before Foswiki is operational, you can use the
# <tt>htpasswd</tt> or <tt>htdigest</tt> Apache program to create a new password file with the correct
# encoding. Use caution however as these programs do not support the email addresses stored by Foswiki in
# the <tt>.htpasswd</tt> file.
$Foswiki::cfg{Htpasswd}{Encoding} = 'apache-md5';

# **STRING 80 DISPLAY_IF /htpasswd/i.test({PasswordManager}) && /md5$/.test({Htpasswd}{Encoding})**
# Authentication realm. You may need to change it
# if you are sharing a password file with another application.
$Foswiki::cfg{AuthRealm} =
'Enter your WikiName. (First name and last name, no space, no dots, capitalized, e.g. JohnSmith). Cancel to register if you do not have one.';

# **BOOLEAN DISPLAY_IF {PasswordManager}=="Foswiki::Users::HtPasswdUser" && {Htpasswd}{Encoding}!="plain"**
# Auto-detect the stored password encoding type.  Enable
# this to allow migration from one encoding format to another format.  Note that this does
# add a small overhead to the parsing of the <tt>.htpasswd</tt> file.  Tests show approximately 1ms per 1000 entries.  It should be used
# with caution unless you are using CGI acceleration such as FastCGI or mod_perl.
# This option is not compatible with <tt>plain</tt> text passwords.
$Foswiki::cfg{Htpasswd}{AutoDetect} = $TRUE;

# **NUMBER CHECK="min:0" FEEDBACK=AUTO **
# Specify the cost that should be incured when computing the hash of a password.  This number should be increased as CPU speeds increase.
# The iterations of the hash is roughly 2^cost - default is 8, or 256 iterations.
#
$Foswiki::cfg{Htpasswd}{BCryptCost} = 8;

#---++ Registration
# <p>Registration is the process by which new users register themselves with
# Foswiki.</p>
# **BOOLEAN**
# If you want users to be able to use a login ID other than their
# wikiname, you need to turn this on. It controls whether the 'LoginName'
# box appears during the user registration process, and is used to tell
# the User Mapping module whether to map login names to wikinames or not
# (if it supports mappings, that is).
$Foswiki::cfg{Register}{AllowLoginName} = $FALSE;

# **BOOLEAN**
# Controls whether new user registration is available.
# It will have no effect on existing users.
$Foswiki::cfg{Register}{EnableNewUserRegistration} = $TRUE;

# **BOOLEAN**
# Whether registrations must be verified by the user, by following
# a link sent in an email to the user's registered email address
$Foswiki::cfg{Register}{NeedVerification} = $FALSE;

# **BOOLEAN**
# Whether registrations must be verified by a referee. The referees are
# listed in the {Register}{Approvers} setting, by wikiname. Note that
# the AntiWikiSpamPlugin supports automatic checking of registration
# sources against black- and white-lists, and may be a good alternative
# to an approval system.
$Foswiki::cfg{Register}{NeedApproval} = $FALSE;

# **STRING 40**
# Comma-separated list of WikiNames of users who are able to approve
# new registrations. These referees will be sent an email when a new
# user verifies their registration. The referee must click a link in
# the email to approve (or deny) the registration.
# If the approver list is empty, the email will be sent to the wiki
# administrator.
$Foswiki::cfg{Register}{Approvers} = '';

# **BOOLEAN EXPERT**
# Controls whether the user password has to be entered twice on the
# registration page or not. The default is to require confirmation, in which
# case the same password must be provided in the confirmation input.
$Foswiki::cfg{Register}{DisablePasswordConfirmation} = $FALSE;

# **BOOLEAN EXPERT**
# Hide password in registration email to the <em>user</em>
# Note that Foswiki sends administrators a separate confirmation.
$Foswiki::cfg{Register}{HidePasswd} = $TRUE;

# **STRING 20 EXPERT**
# The internal user that creates user topics on new registrations.
# You are recommended not to change this.
$Foswiki::cfg{Register}{RegistrationAgentWikiName} = 'RegistrationAgent';

# **BOOLEAN**
# Normally users can register multiple WikiNames using the same email address.
# Enable this parameter to prevent multiple registrations using the same email address.
$Foswiki::cfg{Register}{UniqueEmail} = $FALSE;

# **REGEX 80 EXPERT**
# This regular expression can be used to block certain email addresses from being used
# for registering users.  It can be used to block some of the more common wikispam bots.
# If this regex matches the entered address, the registration is rejected.  For example:<br/>
# <code>^.*@(lease-a-seo\.com|paydayloans).*$</code><br/>
# To block all domains and list only the permitted domains, use an expression of the format:<br/>
# <code>@(?!(example\.com|example\.net)$)</code>
$Foswiki::cfg{Register}{EmailFilter} = '';

# **STRING H**
# Configuration password (not prompted)
$Foswiki::cfg{Password} = '';

#---++ Environment
# **PERL**
# Array of the names of configuration items that are available when using %IF, %SEARCH
# and %QUERY{}%. Extensions can push into this array to extend the set. This is done as
# a filter in because while the bulk of configuration items are quite innocent,
# it's better to be a bit paranoid.
$Foswiki::cfg{AccessibleCFG} = [
    '{ScriptSuffix}',
    '{LoginManager}',
    '{AuthScripts}',
    '{LoginNameFilterIn}',
    '{AdminUserLogin}',
    '{AdminUserWikiName}',
    '{SuperAdminGroup}',
    '{UsersTopicName}',
    '{AuthRealm}',
    '{MinPasswordLength}',
    '{Register}{AllowLoginName}',
    '{Register}{EnableNewUserRegistration}',
    '{Register}{NeedVerification}',
    '{Register}{NeedApproval}',
    '{Register}{Approvers}',
    '{Register}{RegistrationAgentWikiName}',
    '{AllowInlineScript}',
    '{DenyDotDotInclude}',
    '{UploadFilter}',
    '{NameFilter}',
    '{AccessibleCFG}',
    '{AntiSpam}{EmailPadding}',
    '{AntiSpam}{EntityEncode}',
    '{AntiSpam}{HideUserDetails}',
    '{AntiSpam}{RobotsAreWelcome}',
    '{Stats}{TopViews}',
    '{Stats}{TopContrib}',
    '{Stats}{TopicName}',
    '{UserInterfaceInternationalisation}',
    '{UseLocale}',
    '{Site}{Locale}',
    '{Site}{CharSet}',
    '{DisplayTimeValues}',
    '{DefaultDateFormat}',
    '{Site}{LocaleRegexes}',
    '{UpperNational}',
    '{LowerNational}',
    '{PluralToSingular}',
    '{EnableHierarchicalWebs}',
    '{WebMasterEmail}',
    '{WebMasterName}',
    '{NotifyTopicName}',
    '{SystemWebName}',
    '{TrashWebName}',
    '{SitePrefsTopicName}',
    '{LocalSitePreferences}',
    '{HomeTopicName}',
    '{WebPrefsTopicName}',
    '{UsersWebName}',
    '{TemplatePath}',
    '{LinkProtocolPattern}',
    '{NumberOfRevisions}',
    '{MaxRevisionsInADiff}',
    '{ReplaceIfEditedAgainWithin}',
    '{LeaseLength}',
    '{LeaseLengthLessForceful}',
    '{Plugins}{WebSearchPath}',
    '{PluginsOrder}',
    '{Cache}{Enabled}',
    '{Validation}{Method}',
    '{Register}{DisablePasswordConfirmation}',
    '{TemplateLogin}{AllowLoginUsingEmailAddress}',
    '{FormTypes}'
];

# **BOOLEAN**
# Allow %INCLUDE of URLs. This is disabled by default, because it is possible
# to mount a denial-of-service (DoS) attack on a Foswiki site using INCLUDE and
# URLs. Only enable it if you are in an environment where a DoS attack is not
# a high risk.
# <p /> You may also need to configure the proxy settings ({PROXY}{HOST} and
# {PROXY}{PORT}) if your server is behind a firewall and you allow %INCLUDE of
# external webpages (see Proxies).
$Foswiki::cfg{INCLUDE}{AllowURLs} = $FALSE;

# **BOOLEAN**
# Used to disallow the use of SCRIPT and LITERAL tags in topics by removing
# them from the body of topics during rendering.
# <font color="red">This setting is fundamentally unsafe and is now
# DEPRECATED</font> - use <a href="http://foswiki.org/Extensions/SafeWikiPlugin">SafeWikiPlugin</a> instead.
$Foswiki::cfg{AllowInlineScript} = $TRUE;

# **BOOLEAN EXPERT**
# If a login name (or an internal user id) cannot be mapped to a wikiname,
# then the user is unknown. By default the user will be displayed using
# whatever identity is stored for them. For security reasons you may want
# to obscure this stored id by setting this option to true.
$Foswiki::cfg{RenderLoggedInButUnknownUsers} = $FALSE;

# **BOOLEAN EXPERT**
# Remove .. from %INCLUDE{filename}%, to stop includes
# of relative paths.
$Foswiki::cfg{DenyDotDotInclude} = $TRUE;

# **REGEX EXPERT**
# Filter-in regex for uploaded (attached) file names. This is a filter
# <b>in</b>, so any files that match this filter will be renamed on upload
# to prevent upload of files with the same file extensions as executables.
# <p /> NOTE: Be sure to update
# this list with any configuration or script filetypes that are
# automatically run by your web server.
$Foswiki::cfg{UploadFilter} =
  qr/^(\.htaccess|.*\.(?i)(?:php[0-9s]?(\..*)?|[sp]htm[l]?(\..*)?|pl|py|cgi))$/;

# **REGEX EXPERT**
# Filter-out regex for webnames, topic names, file attachment names, usernames,
# include paths and skin names. This is a filter <b>out</b>, so if any of the
# characters matched by this expression are seen in names, they will be
# removed.
$Foswiki::cfg{NameFilter} = qr/[\s\*?~^\$@%`"'&;|<>\[\]#\x00-\x1f]/;

# **BOOLEAN EXPERT**
# If this is set, then the search module will use more relaxed
# rules governing regular expressions searches.
$Foswiki::cfg{ForceUnsafeRegexes} = $FALSE;

# **BOOLEAN EXPERT**
# Build the path to /foswiki/bin from the URL that was used to get this
# far. This can be useful when rewriting rules or redirection are used
# to shorten URLs. Note that displayed links are incorrect after failed
# authentication if this is set, so unless you really know what you are
# doing, leave it alone.
$Foswiki::cfg{GetScriptUrlFromCgi} = $FALSE;

# **BOOLEAN EXPERT**
# Draining STDIN may be necessary if the script is called due to a
# redirect and the original query was a POST. In this case the web
# server is waiting to write the POST data to this script's STDIN,
# but CGI.pm won't drain STDIN as it is seeing a GET because of the
# redirect, not a POST. Enable this <b>only</b> in case a Foswiki script
# hangs.
$Foswiki::cfg{DrainStdin} = $FALSE;

# **BOOLEAN EXPERT**
# Remove port number from URL. If set, and a URL is given with a port
# number e.g. http://my.server.com:8080/foswiki/bin/view, this will strip
# off the port number before using the url in links.
$Foswiki::cfg{RemovePortNumber} = $FALSE;

# **BOOLEAN EXPERT**
# Allow the use of URLs in the <tt>redirectto</tt> parameter to the
# <tt>save</tt> script, and in <tt>topic</tt> parameter to the
# <tt>view</tt> script. <b>WARNING:</b> Enabling this feature makes it
# very easy to build phishing pages using the wiki, so in general,
# public sites should <b>not</b> enable it. Note: It is possible to
# redirect to a topic regardless of this setting, such as
# <tt>topic=OtherTopic</tt> or <tt>redirectto=Web.OtherTopic</tt>.
# To enable redirection to a list of trusted URLs, keep this setting
# disabled and set the {PermittedRedirectHostUrls}.
$Foswiki::cfg{AllowRedirectUrl} = $FALSE;

# **BOOLEAN EXPERT**
# Some authentication systems do not allow parameters to be passed in
# the target URL to be redirected to after authentication. In this case,
# Foswiki can be configured to encode the address of the parameter cache
# in the path information of the URL. Note that if you are using Apache
# rewriting rules, this may not work.
$Foswiki::cfg{UsePathForRedirectCache} = $FALSE;

# **REGEX EXPERT**
# Defines the filter-in regexp that must match the names of environment
# variables that can be seen using the %ENV{}% macro. Set it to
# '^.*$' to allow all environment variables to be seen (not recommended).
$Foswiki::cfg{AccessibleENV} =
'^(HTTP_\w+|REMOTE_\w+|SERVER_\w+|REQUEST_\w+|MOD_PERL|FOSWIKI_ACTION|PATH_INFO)$';

#---++ Proxies
# Some environments require outbound HTTP traffic to go through a proxy
# server. (e.g. http://proxy.your.company).
# **URL CHECK='parts:scheme,authority,path,user,pass  \
#              partsreq:scheme,authority \
#              schemes:http,https \
#              authtype:hostip \
#              nullok' \
#              30**
# Hostname or address of the proxy server.
# <b>CAUTION</b> This setting can be overridden by a PROXYHOST setting
# in SitePreferences. Make sure you delete the setting from there if
# you are using a SitePreferences topic from a previous release of Foswiki.
# If your proxy requires authentication, simply put it in the URL, as in:
# http://username:password@proxy.your.company.
$Foswiki::cfg{PROXY}{HOST} = '';

# **STRING 30**
# Some environments require outbound HTTP traffic to go through a proxy
# server. Set the port number here (e.g: 8080).
# <b>CAUTION</b> This setting can be overridden by a PROXYPORT setting
# in SitePreferences. Make sure you delete the setting from there if you
# are using a SitePreferences topic from a previous release of Foswiki.
$Foswiki::cfg{PROXY}{PORT} = '';

#---++ Anti-spam
# <p>Foswiki incorporates some simple anti-spam measures to protect
# e-mail addresses and control the activities of benign robots. These
# should be enough to handle intranet requirements. Administrators of
# public (internet) sites are strongly recommended to install
# <a href="http://foswiki.org/Extensions/AntiWikiSpamPlugin" target="_new">
# AntiWikiSpamPlugin</a></p>

# **STRING 50**
# Text added to e-mail addresses to prevent spambots from grabbing
# addresses e.g. set to 'NOSPAM' to get fred@user.co.ru
# rendered as fred@user.coNOSPAM.ru
$Foswiki::cfg{AntiSpam}{EmailPadding} = '';

# **BOOLEAN**
# <p>Normally Foswiki stores the user's sensitive information (such as their e-mail
# address) in a database out of public view. This is to help prevent e-mail
# spam and identity fraud.</p>
# <p>This setting controls whether or not the <code>%USERINFO%</code> macro will
# reveal details about users other than the current logged in user.  It does not
# control how Foswiki actually stores email addresses.</p>
# If disclosure of emails is not a risk for you (e.g. you are behind a firewall) and you
# are happy for e-mails to be made public to all Foswiki users,
# then you can disable this option.  If you prefer to store email addresses directly in user
# topics, see the TopicUserMapping expert setting under the UserMapping tab.</p>
# <p>Note that if this option is set, then the <code>user</code> parameter to
# <code>%USERINFO</code> is ignored for non-admin users.
$Foswiki::cfg{AntiSpam}{HideUserDetails} = $TRUE;

# **BOOLEAN**
# By default Foswiki will also manipulate e-mail addresses to reduce the harvesting
# of e-mail addresses. Foswiki will encode all non-alphanumeric characters to their
# HTML entity equivalent. e.g. @ becomes &<nop>#64;  This is not completely effective,
# however it can prevent some primitive spambots from seeing the addresses.
# More advanced bots will still collect addresses.
$Foswiki::cfg{AntiSpam}{EntityEncode} = $TRUE;

# **BOOLEAN**
# By default, Foswiki doesn't do anything to stop robots, such as those used
# by search engines, from visiting "normal view" pages.
# If you disable this option, Foswiki will generate a META tag to tell robots
# not to index pages.<br />
# Inappropriate pages (like the raw and edit views) are always protected from
# being indexed.<br />
# Note that for full protection from robots you should also use robots.txt
# (there is an example in the root of your Foswiki installation).
$Foswiki::cfg{AntiSpam}{RobotsAreWelcome} = $TRUE;

#---+ Logging and Statistics -- TABS
#---++ Logging

# **SELECTCLASS none,Foswiki::Logger::*,Foswiki::Logger::PlainFile::* FEEDBACK=AUTO **
# Foswiki supports different implementations of log files. It can be
# useful to be able to plug in a database implementation, for example,
# for a large site, or even provide your own custom logger. Select the
# implementation to be used here. Most sites should be OK with the
# PlainFile logger, which automatically rotates the logs every month.<p />
# Note that on very busy systems, this logfile rotation can be disruptive and the
# Compatibility logger might perform better.<p />
# The <tt>PlainFile::Obfuscating</tt> logger is identical to the <tt>PlainFile</tt>
# logger except that IP addresses are either obfuscated by replacing the IP Address
# with a MD5 Hash, or by completely masking it to x.x.x.x.  If your regulatory domain
# prohibits tracking of IP Addresses, use the Obfuscating logger. Note that
# Authentication Errors are never obfuscated.<p />
# Note: the Foswiki 1.0 implementation of logfiles is still supported,
# through use of the <tt>Foswiki::Logger::Compatibility</tt> logger.
# Foswiki will automatically select the Compatibility logger if it detects
# a setting for <tt>{WarningFileName}</tt> in your LocalSite.cfg.
$Foswiki::cfg{Log}{Implementation} = 'Foswiki::Logger::PlainFile';

# **PATH**
# Directory where log files will be written.  Note that the Compatibility
# Logger does not use this setting by default.
$Foswiki::cfg{Log}{Dir} = '$Foswiki::cfg{WorkingDir}/logs';

# **BOOLEAN DISPLAY_IF /PlainFile::Obfuscating/i.test({Log}{Implementation})**
# The Obfuscating logger can either replace IP addresses with a hashed address
# that cannot be easily reversed to the original IP,  or the IP address can
# be completely masked as <tt>x.x.x.x</tt>.  Enable this parameter to replace
# The IP address with the literal string <tt>x.x.x.x</tt>.
$Foswiki::cfg{Log}{Obfuscating}{MaskIP} = $FALSE;

# **PERL EXPERT**
# Whether or not to log different actions in the events log.
# Information in the events log is used in gathering web statistics,
# and is useful as an audit trail of Foswiki activity. Actions
# not listed here will be logged by default.  To disable logging of an action,
# add it to this list if not already present, and set value to <code>0</code>.
$Foswiki::cfg{Log}{Action} = {
    view     => 1,
    search   => 1,
    changes  => 1,
    rdiff    => 1,
    compare  => 1,
    edit     => 1,
    save     => 1,
    upload   => 1,
    attach   => 1,
    rename   => 1,
    register => 1,
    rest     => 1,
    viewfile => 1,
};

# **PATH FEEDBACK=AUTO DISPLAY_IF /Compatibility/i.test({Log}{Implementation}) || {DebugFileName}**
# Log file for debug messages when using the Compatibility logger.
# (Usually very low volume.) If <code>%DATE%</code> is included in the file name, it gets expanded
# to YYYYMM (year, month), causing a new log to be written each month.<p />
# To use the Compatibility logger, set this to a valid file path and name.<br />
# Foswiki 1.0.x default: <code>$Foswiki::cfg{DataDir}/debug.txt</code><br />
# or Foswiki 1.1 logging directory <code>$Foswiki::cfg{Log}{Dir}/debug%DATE%.txt</code>
$Foswiki::cfg{DebugFileName} = '';

# **PATH FEEDBACK=AUTO DISPLAY_IF /Compatibility/i.test({Log}{Implementation}) || {WarningFileName}**
# Log file for Warnings when using the Compatibility logger.
# (Usually low volume) If <code>%DATE%</code> is included in the file name, it gets expanded
# to YYYYMM (year, month), causing a new log to be written each month.<p />
# To use the Compatibility logger, set this to a valid file path and name.<br />
# Foswiki 1.0.x default: <code>$Foswiki::cfg{DataDir}/warn%DATE%.txt</code><br />
# or Foswiki 1.1 logging directory <code>$Foswiki::cfg{Log}{Dir}/warn%DATE%.txt</code>
$Foswiki::cfg{WarningFileName} = '';

# **PATH**
# Log file recording web activity when using the Compatibility logger. (High volume).
# If <code>%DATE%</code> is included in the file name, it gets expanded
# to YYYYMM (year, month), causing a new log to be written each month.<p />
# To use the Compatibility logger, set this to a valid file path and name.<p />
# Foswiki 1.0.x default: <code>$Foswiki::cfg{DataDir}/log%DATE%.txt</code><br />
# or Foswiki 1.1 logging directory <code>$Foswiki::cfg{Log}{Dir}/log%DATE%.txt</code>
$Foswiki::cfg{LogFileName} = '';

#---++ Statistics
# **NUMBER CHECK="min:0" FEEDBACK=AUTO **
# Number of top viewed topics to show in statistics topic
$Foswiki::cfg{Stats}{TopViews} = 10;

# **NUMBER CHECK="min:0" FEEDBACK=AUTO **
# Number of top contributors to show in statistics topic
$Foswiki::cfg{Stats}{TopContrib} = 10;

# **SELECT Prohibited, Allowed, Always**
# Set this parameter to <code>Allowed</code> if you want the statistics script to create a
# missing WebStatistics topic only when the parameter <code>autocreate=1</code> is supplied.
# Set it to <code>Always</code> if a missing WebStatistics topic should be created unless
# overridden by URL parameter <code>'autocreate=0'</code>.  <code>Prohibited</code> is
# the previous behavior and is the default.
$Foswiki::cfg{Stats}{AutoCreateTopic} = 'Prohibited';

# **STRING 20**
# If this is set to the name of a Group, then the statistics script will only run for
# members of the specified  and the AdminGroup.  Ex. Set to <code>AdminGroup</code> to restrict
# statistics to  administrators.   Default is un-set.  Anyone can run statistics.
$Foswiki::cfg{Stats}{StatisticsGroup} = '';

# **STRING 20 EXPERT**
# Name of statistics topic.  Note:  If you change the name of the statistics topic
# you must also rename the WebStatistics topic in each web, and the DefaultWebStatistics topic
# in the System web (and possibly in the Main web).
$Foswiki::cfg{Stats}{TopicName} = 'WebStatistics';

#############################################################################
#---+ Internationalisation -- TABS
#---++ Languages
# **BOOLEAN**
# <p>Enable user interface internationalisation, i.e. presenting the user
# interface in the users own language(s). Some languages require the
# <code>Locale::Maketext::Lexicon</code> and <code>Encode/MapUTF8</code> Perl
# modules to be installed.</p>
$Foswiki::cfg{UserInterfaceInternationalisation} = $FALSE;

# **BOOLEAN EXPERT DISPLAY_IF {UserInterfaceInternationalisation}**
# <p>Enable compilation of .po string files into compressed .mo files.
# This can result in a significant performance improvement for I18N, but has also been
# reported to cause issues on some systems.  So for now this is considered experimental.
# Note that if string files are being edited, it requires that configure be rerun to recompile
# modified files.  Disable this option to prevent compling of string files.  If disabled,
# stale <code>&lt;language&gt;.mo</code> files should be removed from the
# Foswiki locale directory so that the modified .po file will be used.
$Foswiki::cfg{LanguageFileCompression} = $FALSE;

# *LANGUAGES* Marker used by bin/configure script - do not remove!
# <p>If <tt>{UserInterfaceInternationalisation}</tt> is enabled, the following
# settings control the languages that are available in the
# user interface. Check every language that you want your site to support.</p>
# <p>Allowing all languages is the best for <strong>really</Strong> international
# sites, but for best performance you should enable only the languages you
# really need. English is the default language, and is always enabled.</p>
# <p><code>{LocalesDir}</code> is used to find the languages supported in your installation,
# so if the list of available languages is empty, it's probably because
# <code>{LocalesDir}</code> is pointing to the wrong place.</p>

#---++ Locale
# <p>Enable operating system level locales and internationalisation support
# for 8-bit character sets. This may be required for correct functioning
# of the programs that Foswiki calls when your wiki content uses
# international character sets.</p>

# **BOOLEAN**
# Enable the used of {Site}{Locale}
$Foswiki::cfg{UseLocale} = $FALSE;

# **STRING 50 DISPLAY_IF {UseLocale}**
# Site-wide locale - used by Foswiki and external programs such as grep, and to
# specify the character set in which content must be presented for the user's
# web browser.
# <br/>
# Note that {Site}{Locale} is ignored unless {UseLocale} is set.
# <br />
# Locale names are not standardised. On Unix/Linux check 'locale -a' on
# your system to see which locales are supported by your system.
# You may also need to check what charsets your browsers accept - the
# 'preferred MIME names' at http://www.iana.org/assignments/character-sets
# are a good starting point.
# <br />
# WARNING: Topics are stored in site character set format, so data
# conversion of file names and contents will be needed if you change
# locales after creating topics whose names or contents include 8-bit
# characters.
# <br />
# Examples:<br />
# <code>en_US.ISO-8859-1</code> - Standard US ISO-8859-1 (default)<br />
# <code>de_AT.ISO-8859-15</code> - Austria with ISO-8859-15 for Euro<br />
# <code>ru_RU.KOI8-R</code> - Russia<br />
# <code>ja_JP.eucjp</code> - Japan <br />
# <code>C</code> - English only; no I18N features regarding character
# encodings and external programs.<br />
# UTF-8 locale like en_US.utf8 is still considered experimental
$Foswiki::cfg{Site}{Locale} = 'en_US.ISO-8859-1';

# **STRING 50 **
# Set this to match your site locale (from 'locale -a')
# whose character set is not supported by your available perl conversion module
# (i.e. Encode for Perl 5.8 or higher, or Unicode::MapUTF8 for other Perl
# versions).  For example, if the locale 'ja_JP.eucjp' exists on your system
# but only 'euc-jp' is supported by Unicode::MapUTF8, set this to 'euc-jp'.
# If you don't define it, it will automatically be defaulted to iso-8859-1<br />
#$Foswiki::cfg{Site}{CharSet} = undef;

# **SELECT gmtime,servertime**
# Set the timezone (this only effects the display of times,
# all internal storage is still in GMT). May be gmtime or servertime
$Foswiki::cfg{DisplayTimeValues} = 'gmtime';

# **SELECT $day $month $year, $year-$mo-$day, $year/$mo/$day, $year.$mo.$day**
# Set the default format for dates. The traditional Foswiki format is
# '$day $month $year' (31 Dec 2007). The ISO format '$year-$mo-$day'
# (2007-12-31) is recommended for non English language Foswikis. Note that $mo
# is the month as a two digit number. $month is the three first letters of
# English name of the month
$Foswiki::cfg{DefaultDateFormat} = '$day $month $year';

# **BOOLEAN EXPERT**
# Disable to force explicit listing of national chars in
# regexes, rather than relying on locale-based regexes. Intended
# for Perl 5.6 or higher on platforms with broken locales: should
# only be disabled if you have locale problems.
$Foswiki::cfg{Site}{LocaleRegexes} = $TRUE;

# **STRING DISPLAY_IF ! {UseLocale} || ! {Site}{LocaleRegexes} **
# If a suitable working locale is not available (i.e. {UseLocale}
# is disabled), OR  you are using Perl 5.005 (with or without working
# locales), OR {Site}{LocaleRegexes} is disabled, you can use WikiWords with
# accented national characters by putting any '8-bit' accented
# national characters within these strings - i.e. {UpperNational}
# should contain upper case non-ASCII letters.  This is termed
# 'non-locale regexes' mode.
# If 'non-locale regexes' is in effect, WikiWord linking will work,
# but  some features such as sorting of WikiWords in search results
# may not. These features depend on {UseLocale}, which can be set
# independently of {Site}{{LocaleRegexes}, so they will work with Perl
# 5.005 as long as {UseLocale} is set and you have working
# locales.
$Foswiki::cfg{UpperNational} = '';

# **STRING DISPLAY_IF ! {UseLocale}**
#
$Foswiki::cfg{LowerNational} = '';

# **BOOLEAN**
# Change non-existent plural topic name to singular,
# e.g. TestPolicies to TestPolicy. Only works in English.
$Foswiki::cfg{PluralToSingular} = $TRUE;

#############################################################################
#---+ Store -- TABS
#---++ Store Implementation
# <p>Foswiki supports different back-end store implementations.</p>
# **SELECTCLASS Foswiki::Store::* **
# Store implementation.
# <ul>
# <li>RcsWrap uses normal RCS executables.</li>
# <li>RcsLite uses a 100% Perl simplified implementation of RCS.
# RcsLite is useful if you don't have, and can't install, RCS - for
# example, on a hosted platform. It will work, and is compatible with
# RCS, but is not quite as fast.</li>
# </ul>
$Foswiki::cfg{Store}{Implementation} = 'Foswiki::Store::RcsWrap';
$Foswiki::cfg{Store}{Implementation} = 'Foswiki::Store::RcsLite'
  if ( $^O eq 'MSWin32' );

# **BOOLEAN EXPERT**
# enabling this will allow customisation of the Foswiki Store implementation selected
# above.
# If any customisations are installed, you will see a list of full class names of classes 
# that can selectivly overide the store. Each key will the full Class name, and its value 
# will determine its order. Zero means disabled.
$Foswiki::cfg{Store}{ImplementationClasses}{Enabled} = $TRUE;

# **BOOLEAN EXPERT**
# Set to enable (hierarchical) sub-webs. Without this setting, Foswiki will only
# allow a single level of webs. If you set this, you can use
# multiple levels, like a directory tree, i.e. webs within webs.
$Foswiki::cfg{EnableHierarchicalWebs} = 1;

# **NUMBER CHECK="min:60" FEEDBACK=AUTO EXPERT**
# Number of seconds to remember changes for. This doesn't affect revision
# histories, which always remember when a file changed. It only affects
# the number of changes that are cached for fast access by the 'changes' and
# 'statistics' scripts, and for use by extensions such as the change
# notification mailer. It should be no shorter than the interval between runs
# of these scripts.
$Foswiki::cfg{Store}{RememberChangesFor} = 31 * 24 * 60 * 60;

# **SELECTCLASS Foswiki::Store::SearchAlgorithms::***
# This is the algorithm used to perform plain text (not query) searches.
# Foswiki has two built-in search algorithms, both of which are designed to
# work with the default flat-file database.
# <ol><li> The default 'Forking' algorithm, which forks a subprocess that
# runs a 'grep' command, is recommended for Linux/Unix.
# Forking may also work OK on Windows if you keep the directory path to
# Foswiki very short.</li>
# <li> The 'PurePerl' algorithm, which is written in Perl and
# usually only used for native Windows installations where forking
# is not stable, due to limitations in the length of command lines.
# </li></ol>
# On Linux/Unix you will be just fine with the 'Forking' implementation.
# However if you find searches run very slowly, you may want to try a
# different algorithm, which may work better on your configuration.
# For example, there is an alternative algorithm available from
# <a href="http://foswiki.org/Extensions/NativeSearchContrib">
# http://foswiki.org/Extensions/NativeSearchContrib </a>, that usually
# gives better performance with mod_perl and Speedy CGI, but requires root
# access to install.
# <p />
# Other store implementations and indexing search engines (for example,
# <a href="http://foswiki.org/Extensions/KinoSearchContrib">
# http://foswiki.org/Extensions/KinoSearchContrib</a>) may come with their
# own search algorithms.
$Foswiki::cfg{Store}{SearchAlgorithm} =
  'Foswiki::Store::SearchAlgorithms::Forking';
$Foswiki::cfg{Store}{SearchAlgorithm} =
  'Foswiki::Store::SearchAlgorithms::PurePerl'
  if ( $^O eq 'MSWin32' );

# **SELECTCLASS Foswiki::Store::QueryAlgorithms::***
# This is the algorithm used to perform query searches. The default Foswiki
# algorithm (BruteForce) works well, but is not particularly fast (it is
# based on plain-text searching). You may be able to select a different
# algorithm here, depending on what alternative implementations have been
# installed.
$Foswiki::cfg{Store}{QueryAlgorithm} =
  'Foswiki::Store::QueryAlgorithms::BruteForce';

# **SELECTCLASS Foswiki::Prefs::*RAM* EXPERT**
# The algorithm used to store preferences. The default algorithm reads
# topics each time to access preferences. A caching algorithm that uses
# BerkeleyDB is also available from the PrefsCachePlugin. This algorithm
# is faster, but requires BerkeleyDB to be installed.
$Foswiki::cfg{Store}{PrefsBackend} = 'Foswiki::Prefs::TopicRAM';

# bodgey up a default location for grep
my $grepDefaultPath = '/bin/';
$grepDefaultPath = '/usr/bin/' if ( $^O eq 'darwin' );
$grepDefaultPath = 'c:/PROGRA~1/GnuWin32/bin/' if ( $^O eq 'MSWin32' );

# **COMMAND EXPERT DISPLAY_IF {Store}{SearchAlgorithm}=='Foswiki::Store::SearchAlgorithms::Forking' **
# Full path to GNU-compatible egrep program. This is used for searching when
# {SearchAlgorithm} is 'Foswiki::Store::SearchAlgorithms::Forking'.
# %CS{|-i}% will be expanded
# to -i for case-sensitive search or to the empty string otherwise.
# Similarly for %DET, which controls whether matching lines are required.
# (see the documentation on these options with GNU grep for details).
$Foswiki::cfg{Store}{EgrepCmd} =
  $grepDefaultPath . 'grep -E %CS{|-i}% %DET{|-l}% -H -- %TOKEN|U% %FILES|F%';

# **COMMAND EXPERT DISPLAY_IF {Store}{SearchAlgorithm}=='Foswiki::Store::SearchAlgorithms::Forking'**
# Full path to GNU-compatible fgrep program. This is used for searching when
# {SearchAlgorithm} is 'Foswiki::Store::SearchAlgorithms::Forking'.
$Foswiki::cfg{Store}{FgrepCmd} =
  $grepDefaultPath . 'grep -F %CS{|-i}% %DET{|-l}% -H -- %TOKEN|U% %FILES|F%';

#---++ DataForm settings
# **PERL**
# this setting is automatically updated by configure to list all the installed FormField types.
# If you install an extension that adds new Form Field types, you need to run configure for them
# to be registered.
$Foswiki::cfg{FormTypes} = [
    {
        'multivalued' => 0,
        'class'       => 'Foswiki::Form::Radio',
        'type'        => 'radio',
        'size'        => 4
    },
    {
        'multivalued' => 0,
        'class'       => 'Foswiki::Form::Text',
        'type'        => 'text',
        'size'        => 10
    },
    {
        'multivalued' => 1,
        'class'       => 'Foswiki::Form::Checkbox',
        'type'        => 'checkbox',
        'size'        => 4
    },
    {
        'multivalued' => 1,
        'class'       => 'Foswiki::Form::Checkbox',
        'type'        => 'checkbox+values',
        'size'        => 4
    },
    {
        'multivalued' => 0,
        'class'       => 'Foswiki::Form::Color',
        'type'        => 'color',
        'size'        => ''
    },
    {
        'multivalued' => '',
        'class'       => 'Foswiki::Form::Select',
        'type'        => 'select',
        'size'        => 1
    },
    {
        'multivalued' => 1,
        'class'       => 'Foswiki::Form::Select',
        'type'        => 'select+multi',
        'size'        => 1
    },
    {
        'multivalued' => '',
        'class'       => 'Foswiki::Form::Select',
        'type'        => 'select+values',
        'size'        => 1
    },
    {
        'multivalued' => 1,
        'class'       => 'Foswiki::Form::Select',
        'type'        => 'select+multi+values',
        'size'        => 1
    },
    {
        'multivalued' => 0,
        'class'       => 'Foswiki::Form::Date',
        'type'        => 'date',
        'size'        => 20
    },
    {
        'multivalued' => 0,
        'class'       => 'Foswiki::Form::Label',
        'type'        => 'label',
        'size'        => ''
    },
    {
        'multivalued' => 0,
        'class'       => 'Foswiki::Form::ListFieldDefinition',
        'type'        => 'listfielddefinition',
        'size'        => ''
    },
    {
        'multivalued' => 0,
        'class'       => 'Foswiki::Form::Rating',
        'type'        => 'rating',
        'size'        => 4
    },
    {
        'multivalued' => 0,
        'class'       => 'Foswiki::Form::FieldDefinition',
        'type'        => 'fielddefinition',
        'size'        => ''
    },
    {
        'multivalued' => 0,
        'class'       => 'Foswiki::Form::Textarea',
        'type'        => 'textarea',
        'size'        => ''
    },
    {
        'multivalued' => 1,
        'class'       => 'Foswiki::Form::Textboxlist',
        'type'        => 'textboxlist',
        'size'        => ''
    }
];

#---++ RcsWrap Store options
# **BOOLEAN EXPERT DISPLAY_IF /Foswiki::Store::Rcs/.test({Store}{Implementation})**
# Some systems will override the default umask to a highly restricted setting,
# which will block the application of the file and directory permissions.
# If mod_suexec is enabled, the Apache umask directive will also be ignored.
# Enable this setting if the checker reports that the umask is in conflict with
# the permissions, or adust the expert settings {RCS}{dirPermission} and
# {RCS}{filePermission} to be consistent with the system umask.
$Foswiki::cfg{RCS}{overrideUmask} = $FALSE;

# **OCTAL CHECK="min:000 max:777" FEEDBACK=AUTO EXPERT DISPLAY_IF /Foswiki::Store::Rcs/.test({Store}{Implementation})**
# File security for new directories created by RCS stores. You may have
# to adjust these
# permissions to allow (or deny) users other than the webserver user access
# to directories that Foswiki creates. This is an <strong>octal</strong> number
# representing the standard UNIX permissions (e.g. 755 == rwxr-xr-x)
$Foswiki::cfg{RCS}{dirPermission} = 0755;

# **OCTAL CHECK="min:000 max:777" FEEDBACK=AUTO EXPERT DISPLAY_IF /Foswiki::Store::Rcs/.test({Store}{Implementation})**
# File security for new files created by RCS stores. You may have to adjust these
# permissions to allow (or deny) users other than the webserver user access
# to files that Foswiki creates.  This is an <strong>octal</strong> number
# representing the standard UNIX permissions (e.g. 644 == rw-r--r--)
$Foswiki::cfg{RCS}{filePermission} = 0644;

# **BOOLEAN EXPERT DISPLAY_IF /Foswiki::Store::Rcs/.test({Store}{Implementation})**
# Some file-based Store implementations (RcsWrap and RcsLite) store
# attachment meta-data separately from the actual attachments.
# This means that it is possible to have a file in an attachment directory
# that is not seen as an attachment by Foswiki. Sometimes it is desirable to
# be able to simply copy files into a directory and have them appear as
# attachments, and that's what this feature allows you to do.
# Considered experimental.
$Foswiki::cfg{RCS}{AutoAttachPubFiles} = $FALSE;

# **STRING 20 EXPERT DISPLAY_IF {Store}{Implementation}=='Foswiki::Store::RcsWrap'**
# Specifies the extension to use on RCS files. Set to -x,v on windows, leave
# blank on other platforms.
$Foswiki::cfg{RCS}{ExtOption} = "";

# **REGEX EXPERT DISPLAY_IF /Foswiki::Store::Rcs/.test({Store}{Implementation})**
# Perl regular expression matching suffixes valid on plain text files
# Defines which attachments will be treated as ASCII in RCS. This is a
# filter <b>in</b>, so any filenames that match this expression will
# be treated as ASCII.
$Foswiki::cfg{RCS}{asciiFileSuffixes} = qr/\.(txt|html|xml|pl)$/;

# **BOOLEAN DISPLAY_IF {Store}{Implementation}=='Foswiki::Store::RcsWrap'**
# Set this if your RCS cannot check out using the -p option.
# May be needed in some windows installations (not required for cygwin)
$Foswiki::cfg{RCS}{coMustCopy} = $FALSE;

# **COMMAND DISPLAY_IF {Store}{Implementation}=='Foswiki::Store::RcsWrap'**
# RcsWrap initialise a file as binary.
# %FILENAME|F% will be expanded to the filename.
$Foswiki::cfg{RCS}{initBinaryCmd} =
  "/usr/bin/rcs $Foswiki::cfg{RCS}{ExtOption} -i -t-none -kb %FILENAME|F%";

# **COMMAND DISPLAY_IF {Store}{Implementation}=='Foswiki::Store::RcsWrap'**
# RcsWrap initialise a topic file.
$Foswiki::cfg{RCS}{initTextCmd} =
  "/usr/bin/rcs $Foswiki::cfg{RCS}{ExtOption} -i -t-none -ko %FILENAME|F%";

# **COMMAND DISPLAY_IF {Store}{Implementation}=='Foswiki::Store::RcsWrap'**
# RcsWrap uses this on Windows to create temporary binary files during upload.
$Foswiki::cfg{RCS}{tmpBinaryCmd} =
  "/usr/bin/rcs $Foswiki::cfg{RCS}{ExtOption} -kb %FILENAME|F%";

# **COMMAND EXPERT**
# RcsWrap check-in.
# %USERNAME|S% will be expanded to the username.
# %COMMENT|U% will be expanded to the comment.
$Foswiki::cfg{RCS}{ciCmd} =
"/usr/bin/ci $Foswiki::cfg{RCS}{ExtOption} -m%COMMENT|U% -t-none -w%USERNAME|S% -u %FILENAME|F%";

# **COMMAND DISPLAY_IF {Store}{Implementation}=='Foswiki::Store::RcsWrap'**
# RcsWrap check in, forcing the date.
# %DATE|D% will be expanded to the date.
$Foswiki::cfg{RCS}{ciDateCmd} =
"/usr/bin/ci $Foswiki::cfg{RCS}{ExtOption} -m%COMMENT|U% -t-none -d%DATE|D% -u -w%USERNAME|S% %FILENAME|F%";

# **COMMAND DISPLAY_IF {Store}{Implementation}=='Foswiki::Store::RcsWrap'**
# RcsWrap check out.
# %REVISION|N% will be expanded to the revision number
$Foswiki::cfg{RCS}{coCmd} =
  "/usr/bin/co $Foswiki::cfg{RCS}{ExtOption} -p%REVISION|N% -ko %FILENAME|F%";

# **COMMAND DISPLAY_IF {Store}{Implementation}=='Foswiki::Store::RcsWrap'**
# RcsWrap file history.
$Foswiki::cfg{RCS}{histCmd} =
  "/usr/bin/rlog $Foswiki::cfg{RCS}{ExtOption} -h %FILENAME|F%";

# **COMMAND DISPLAY_IF {Store}{Implementation}=='Foswiki::Store::RcsWrap'**
# RcsWrap revision info about the file.
$Foswiki::cfg{RCS}{infoCmd} =
  "/usr/bin/rlog $Foswiki::cfg{RCS}{ExtOption} -r%REVISION|N% %FILENAME|F%";

# **COMMAND DISPLAY_IF {Store}{Implementation}=='Foswiki::Store::RcsWrap'**
# RcsWrap revision info about the revision that existed at a given date.
# %REVISIONn|N% will be expanded to the revision number.
# %CONTEXT|N% will be expanded to the number of lines of context.
$Foswiki::cfg{RCS}{rlogDateCmd} =
  "/usr/bin/rlog $Foswiki::cfg{RCS}{ExtOption} -d%DATE|D% %FILENAME|F%";

# **COMMAND DISPLAY_IF {Store}{Implementation}=='Foswiki::Store::RcsWrap'**
# RcsWrap differences between two revisions.
$Foswiki::cfg{RCS}{diffCmd} =
"/usr/bin/rcsdiff $Foswiki::cfg{RCS}{ExtOption} -q -w -B -r%REVISION1|N% -r%REVISION2|N% -ko --unified=%CONTEXT|N% %FILENAME|F%";

# **COMMAND DISPLAY_IF {Store}{Implementation}=='Foswiki::Store::RcsWrap'**
# RcsWrap lock a file.
$Foswiki::cfg{RCS}{lockCmd} =
  "/usr/bin/rcs $Foswiki::cfg{RCS}{ExtOption} -l %FILENAME|F%";

# **COMMAND DISPLAY_IF {Store}{Implementation}=='Foswiki::Store::RcsWrap'**
# RcsWrap unlock a file.
$Foswiki::cfg{RCS}{unlockCmd} =
  "/usr/bin/rcs $Foswiki::cfg{RCS}{ExtOption} -u %FILENAME|F%";

# **COMMAND DISPLAY_IF {Store}{Implementation}=='Foswiki::Store::RcsWrap'**
# RcsWrap break a file lock.
$Foswiki::cfg{RCS}{breaklockCmd} =
  "/usr/bin/rcs $Foswiki::cfg{RCS}{ExtOption} -u -M %FILENAME|F%";

# **COMMAND DISPLAY_IF {Store}{Implementation}=='Foswiki::Store::RcsWrap'**
# RcsWrap delete a specific revision.
$Foswiki::cfg{RCS}{delRevCmd} =
  "/usr/bin/rcs $Foswiki::cfg{RCS}{ExtOption} -o%REVISION|N% %FILENAME|F%";

#############################################################################
#---+ Tuning

#---++ Browser Cache max-age
# **PERL EXPERT**
# Disable or change the HTTP Cache-Control header. Foswiki defaults to
# =Cache-Control: max-age=0= which recomends to the browser that it should
# ask foswiki if the topic has changed. If you have a web that does not change
# (like System), you can get the browser to use its cache by setting ={'System' => ''}=
# you can also set =max-age=28800= (for 8 hours), or any other of the
# =Cache-Control= directives.
# <br />
# Setting the CacheControl to '' also allows you to manage this from your web
# server (which will not over-ride the setting provided by the application), thus enabling
# web server based caching policies. When the user receives a browser-cache topic,
# they can force a refresh using ctrl-r
# <br />
# this hash must be explicitly set per web or sub-web.
$Foswiki::cfg{BrowserCacheControl} = {};

#---++ HTTP Compression
# <p>Expert settings controlling compression of the generated HTML.</p>
# **BOOLEAN**
# Enable gzip/deflate page compression. Modern browsers can uncompress content
# encoded using gzip compression. You will save a lot of bandwidth by compressing
# pages. This makes most sense when enabling page caching as well as these are
# stored in compressed format by default when {HttpCompress} is enabled.
# Note that only pages without any 'dirty areas' will be compressed. Any other page
# will be transmitted uncompressed.
$Foswiki::cfg{HttpCompress} = $FALSE;

#---++ HTML Page Layout
# <p>Expert setting controlling the layout of the generated HTML.</p>
# **BOOLEAN**
# <p><code>{MergeHeadAndScriptZones}</code> is provided to maintain compatibility with legacy extensions that use <code>ADDTOHEAD</code> to add <code>&lt;script&gt;</code> markup and require content that is now in the <code>script</code> zone.</p>
# <p>Normally, dependencies between individual <code>ADDTOZONE</code> statements are resolved within each zone. However, if <code>{MergeHeadAndScriptZones}</code> is enabled, then <code>head</code> content which requires an <code>id</code> that only exists in <code>script</code> (and vice-versa) will be re-ordered to satisfy any dependency.</p>
# <p><strong><code>{MergeHeadAndScriptZones}</code> will be removed from a future version of Foswiki.</strong></p>
$Foswiki::cfg{MergeHeadAndScriptZones} = $FALSE;

#---++ Cache
# <p>Foswiki includes built-in support for caching HTML pages. This can
# dramatically increase performance, especially if there are a lot more page
# views than changes.</p>
# The cache has a number of setup and tuning parameters. You should read
# <a href="http://foswiki.org/System/PageCaching">Page Caching</a> on
# foswiki.org (or your local copy of this page in the System web) before
# enabling the cache. It is important that you read this topic carefully
# as the cache also has some major disadvantages with respect to formatted
# searches.

# **BOOLEAN**
# This setting will switch on/off caching.
$Foswiki::cfg{Cache}{Enabled} = $FALSE;

# **PATH DISPLAY_IF {Cache}{Enabled}**
# Specify the directory where binary large objects will be stored.
$Foswiki::cfg{Cache}{RootDir} = '$Foswiki::cfg{WorkingDir}/cache';

# **STRING 80 DISPLAY_IF {Cache}{Enabled}**
# List of those topics that have a manual dependency on every topic
# in a web. Web dependencies can also be specified using the WEBDEPENDENCIES
# preference, which overrides this setting.
$Foswiki::cfg{Cache}{WebDependencies} =
  'WebRss, WebAtom, WebTopicList, WebIndex, WebSearch, WebSearchAdvanced';

# **REGEX DISPLAY_IF {Cache}{Enabled}**
# Exclude topics that match this regular expression from the dependency
# tracker.
$Foswiki::cfg{Cache}{DependencyFilter} =
  '$Foswiki::cfg{SystemWebName}\..*|$Foswiki::cfg{TrashWebName}\..*|TWiki\..*';

# **SELECTCLASS Foswiki::PageCache::DBI::*  DISPLAY_IF {Cache}{Enabled}**
# Select the cache implementation. The default page cache implementation
# is based on DBI (http://dbi.perl.org) which requires a working DBI driver to
# connect to a database. This database will hold all cached data as well as the
# maintenance data to keep the cache correct while content changes in the wiki.
# Recommended drivers are DBD::mysql, DBD::Pg, DBD::SQLite or any other database driver connecting
# to a real SQL engine.
$Foswiki::cfg{Cache}{Implementation} = 'Foswiki::PageCache::DBI::Generic';

# **STRING 80 DISPLAY_IF {Cache}{Enabled} && /Foswiki::PageCache::DBI.*/.test({Cache}{Implementation}) **
# Prefix used naming tables and indexes generated in the database.
$Foswiki::cfg{Cache}{DBI}{TablePrefix} = 'foswiki_cache';

# **STRING 80 DISPLAY_IF {Cache}{Enabled} && {Cache}{Implementation} == 'Foswiki::PageCache::DBI::Generic' **
# Generic database driver. See the docu of your DBI driver for the exact syntax of the DSN parameter string.
$Foswiki::cfg{Cache}{DBI}{DSN} = '';

# **STRING 80 DISPLAY_IF {Cache}{Enabled} && {Cache}{Implementation} == 'Foswiki::PageCache::DBI::Generic' **
# Database user name. Add a value if your database needs authentication
$Foswiki::cfg{Cache}{DBI}{Username} = '';

# **PASSWORD 80 DISPLAY_IF {Cache}{Enabled} && {Cache}{Implementation} == 'Foswiki::PageCache::DBI::Generic' **
# Database user password. Add a value if your database needs authentication
$Foswiki::cfg{Cache}{DBI}{Password} = '';

# **STRING 80 DISPLAY_IF {Cache}{Enabled} && {Cache}{Implementation} == 'Foswiki::PageCache::DBI::SQLite'**
# Name of the SQL
$Foswiki::cfg{Cache}{DBI}{SQLite}{Filename} =
  '$Foswiki::cfg{WorkingDir}/sqlite.db';

# **STRING 80 DISPLAY_IF {Cache}{Enabled} && {Cache}{Implementation} == 'Foswiki::PageCache::DBI::MySQL' **
# Name or IP address of the database server
$Foswiki::cfg{Cache}{DBI}{MySQL}{Host} = 'localhost';

# **STRING 80 DISPLAY_IF {Cache}{Enabled} && {Cache}{Implementation} == 'Foswiki::PageCache::DBI::MySQL' **
# Port on the database server to connect to
$Foswiki::cfg{Cache}{DBI}{MySQL}{Port} = '';

# **STRING 80 DISPLAY_IF {Cache}{Enabled} && {Cache}{Implementation} == 'Foswiki::PageCache::DBI::MySQL' **
# Name of the database on the server host.
$Foswiki::cfg{Cache}{DBI}{MySQL}{Database} = '';

# **STRING 80 DISPLAY_IF {Cache}{Enabled} && {Cache}{Implementation} == 'Foswiki::PageCache::DBI::MySQL' **
# Database user name. Add a value if your database needs authentication
$Foswiki::cfg{Cache}{DBI}{MySQL}{Username} = '';

# **PASSWORD 80 DISPLAY_IF {Cache}{Enabled} && {Cache}{Implementation} == 'Foswiki::PageCache::DBI::MySQL' **
# Database user password. Add a value if your database needs authentication
$Foswiki::cfg{Cache}{DBI}{MySQL}{Password} = '';

# **STRING 80 DISPLAY_IF {Cache}{Enabled} && {Cache}{Implementation} == 'Foswiki::PageCache::DBI::PostgreSQL' **
# Name or IP address of the database server
$Foswiki::cfg{Cache}{DBI}{MySQL}{Host} = 'localhost';

# **STRING 80 DISPLAY_IF {Cache}{Enabled} && {Cache}{Implementation} == 'Foswiki::PageCache::DBI::PostgreSQL' **
# Port on the database server to connect to
$Foswiki::cfg{Cache}{DBI}{PostgreSQL}{Port} = '';

# **STRING 80 DISPLAY_IF {Cache}{Enabled} && {Cache}{Implementation} == 'Foswiki::PageCache::DBI::PostgreSQL' **
# Name of the database on the server host.
$Foswiki::cfg{Cache}{DBI}{PostgreSQL}{Database} = '';

# **STRING 80 DISPLAY_IF {Cache}{Enabled} && {Cache}{Implementation} == 'Foswiki::PageCache::DBI::PostgreSQL' **
# Database user name. Add a value if your database needs authentication
$Foswiki::cfg{Cache}{DBI}{PostgreSQL}{Username} = '';

# **PASSWORD 80 DISPLAY_IF {Cache}{Enabled} && {Cache}{Implementation} == 'Foswiki::PageCache::DBI::PostgreSQL' **
# Database user password. Add a value if your database needs authentication
$Foswiki::cfg{Cache}{DBI}{PostgreSQL}{Password} = '';

#############################################################################
#---+ Mail -- TABS
# <p>Settings controlling if and how Foswiki sends email</p>

#---++ Email general
# <p>Settings controlling if and how Foswiki handles email including the identity of the sender
# and other expert settings controlling the email process.</p>
# **BOOLEAN \
#             FEEDBACK='Auto-configure';\
#                       wait="Contacting your e-mail server, this may take several minutes...";\
#                       title="Attempts to automatically configure e-mail by scanning your system and contacting your mail server" \
#             CHECK="prefer:perl" \
#             **
# Enable email globally.  Un-check this option to disable all outgoing
# email from Foswiki.  Use the action button to auto-configure e-mail service.
#
$Foswiki::cfg{EnableEmail} = $TRUE;

# **EMAILADDRESS FEEDBACK=AUTO FEEDBACK="Send Test Email" 30**
# Wiki administrator's e-mail address e.g. <code>webmaster@example.com</code>
# (used in <code>%WIKIWEBMASTER%</code>)
# NOTE: must be a single valid email address
$Foswiki::cfg{WebMasterEmail} = '';

# **STRING FEEDBACK=AUTO \
#          FEEDBACK="Generate S/MIME Certificate";span='2';\
#                   title="Generate a self-signed certficate for the WebMaster.\
#                          This allows immediate use of signed email." \
#          CHECK="expires:1y passlen:15,35 O:'Foswiki Customers' OU:'Self-signed certificates' \
#          #!C:US ST:'Mass Bay' L:'Greater Boston' \
#                " \
#          FEEDBACK="Generate S/MIME CSR";col='1';\
#                   title="Generate a Certificate Signing Request for the WebMaster.\
#                          This request must be signed by a Certificate Authority to create \
#                          a certificate, then installed." \
#         FEEDBACK="Cancel CSR";\
#                   title="Cancel a pending Certificate Signing request.  This destroys the private \
#                          key associated with the request." \
#          30**
# Wiki administrator's name address, for use in mails (first name and
# last name, e.g. <tt>Fred Smith</tt>) (used in %WIKIWEBMASTERNAME%)
# <p>The action buttons are used to generate certificates for S/MIME signed email.  There are
# two ways to use this</p>
# <ul><li><strong>Self signed certificates:</strong>
# The action button will generate a self-signed S/MIME certificate and install it
# for Foswiki e-mail.  If you use this option, you will have to arrange for your
# users' e-mail clients to trust this certificate. This type of certificate
# is adequate for a small user base and for testing.
# <li><strong>Certificate Authority signed certificates:</strong>. The Generate CSR button
# is used to build a "Certificate Signing Request" for use by your private Certificate Authority or
# by a trusted commercial Certificate authority.  Use the Generate CSR button to create
# a private key and signing request. The Cancel button is used to delete a pending request.
# </ul><p>The S/MIME Certificate information on the S/MIME tab must be completed for these
# buttons to provide useful information.</p>
$Foswiki::cfg{WebMasterName} = 'Wiki Administrator';

# **BOOLEAN EXPERT**
# Send email Date header using local "server time" instead of GMT
$Foswiki::cfg{Email}{Servertime} = $FALSE;

# **REGEX 80 EXPERT**
# This parameter is used to determine which Top Level domains are vaild
# when auto-linking email addresses.  It is also used by UserRegistration to
# validate email addresses.  Note, this parameter <em>only</em> controls
# matching of 3 character and longer TLDs.   2-character country codes and
# IP Address domains always permitted.  See:<br/><code>
# Valid TLD's at http://data.iana.org/TLD/tlds-alpha-by-domain.txt<br/>
# Version 2012022300, Last Updated Thu Feb 23 15:07:02 2012 UTC</code>
$Foswiki::cfg{Email}{ValidTLD} =
qr(AERO|ARPA|ASIA|BIZ|CAT|COM|COOP|EDU|GOV|INFO|INT|JOBS|MIL|MOBI|MUSEUM|NAME|NET|ORG|PRO|TEL|TRAVEL|XXX)i;

#---++ Email server
# <p>Settings to select the destination mail server or local email agent used for forwarding email.</p>

# **SELECT Net::SMTP,\
#          Net::SMTP (SSL),\
#          Net::SMTP (TLS),\
#          Net::SMTP (STARTTLS),\
#          MailProgram **
# Select the method Foswiki will use for sending email.  On Unix/Linux hosts
# "MailProgram" is generally acceptable.  Otherwise choose one of the Email
# methods required by your ISP or Email server.
# You can select a method manually,  or use the "Auto-configure" button to
# determine the best connection type for your ISP or Email server.
# Auto-configure requires {SMTP}{MAILHOST}, but you can leave everything else
# blank.  You'll be told if the server requires a username and password.
#$Foswiki::cfg{Email}{MailMethod} = 'Net::SMTP';

# **COMMAND DISPLAY_IF {Email}{MailMethod} == 'MailProgram'**
# This needs to be a command-line program that accepts
# MIME format mail messages on standard input, and mails them.
$Foswiki::cfg{MailProgram} = '/usr/sbin/sendmail -t -oi -oeq';

# **BOOLEAN**
# Set this option on to enable debug
# mode in SMTP. Output will go to the webserver error log.
$Foswiki::cfg{SMTP}{Debug} = 0;

# **STRING 30 EXPERT \
#          DISPLAY_IF {SMTP}{Debug} && {Email}{MailMethod} == 'MailProgram'**
# These flags are passed to the mail program selected by {MailProgram}
# when {SMTP}{Debug} is enabled in addition to any specified with
# the program.  These flags should enable tracing of the SMTP
# transactions to debug configuration issues.<br />
# The default flags are correct for the <tt>sendmail</tt> program
# on many Unix/Linux systems.  Note, however that <tt>sendmail</tt>
# will drop its privileges when running with -X.  You must arrange
# for the client queue files (e.g. <tt>/var/spool/clientmqueue/</tt>)
# to be read and writable by the webserver for the duration of any
# testing.

$Foswiki::cfg{SMTP}{DebugFlags} = '-X /dev/stderr';

# **STRING 30 FEEDBACK=AUTO \
#             DISPLAY_IF /Net::SMTP/.test({Email}{MailMethod})**
# Mail host for outgoing mail. This is only used if Net::SMTP is used.
# Examples: <tt>mail.your.company</tt> If the smtp server uses a different port
# than the default 25 # use the syntax <tt>mail.your.company:portnumber</tt>
# <p><b>CAUTION</b> This setting can be overridden by a setting of SMTPMAILHOST
# in SitePreferences. Make sure you delete that setting if you are using a
# SitePreferences topic from a previous release of Foswiki.</p>
# <p>For Gmail, set MailMethod to Net::SMTP, set MAILHOST to <tt>smtp.gmail.com</tt>
# provide your gmail email address and password below for authentication, and click <strong>Auto-configure</strong>.</p>
$Foswiki::cfg{SMTP}{MAILHOST} = '';

# **STRING 30 DISPLAY_IF /Net::SMTP/.test({Email}{MailMethod})**
# Mail domain sending mail, required. SMTP
# requires that you identify the server sending mail. If not set, <b>Auto-configure</b> or
# <tt>Net::SMTP</tt> will guess it for you. Example: foswiki.your.company.
# <b>CAUTION</b> This setting can be overridden by a setting of %SMTPSENDERHOST%
# in SitePreferences. Make sure you delete that setting.
$Foswiki::cfg{SMTP}{SENDERHOST} = '';

# **STRING 30 DISPLAY_IF /Net::SMTP/.test({Email}{MailMethod})**
# Username for SMTP. Only required if your mail server requires authentication. If
# this is left blank, Foswiki will not attempt to authenticate the mail sender.
$Foswiki::cfg{SMTP}{Username} = '';

# **PASSWORD 30 DISPLAY_IF /Net::SMTP/.test({Email}{MailMethod})**
# Password for your {SMTP}{Username}.
$Foswiki::cfg{SMTP}{Password} = '';

#---++ S/MIME
# <p>Configure signing of outgoing email. (Secure/Multipurpose Internet Mail Extensions)
# is a standard for public key encryption and signing of MIME encoded email messages.
# Messages generated by the server will be signed using an X.509 certificate.</p>

# **BOOLEAN FEEDBACK=auto**
# Enable to cause all e-mails sent by Foswiki to be signed using S/MIME.
$Foswiki::cfg{Email}{EnableSMIME} = $FALSE;

# **PATH FEEDBACK=auto DISPLAY_IF {Email}{EnableSMIME}**
# Specify the file containing the administrator's X.509 certificate.  It
# must be in PEM format. <p>
# If your issuer requires an intermediate CA certificate(s), include them in this
# file after the sender's certificate in order from least to most authoritative CA.
$Foswiki::cfg{Email}{SmimeCertificateFile} = '';

# **PATH FEEDBACK=auto DISPLAY_IF {Email}{EnableSMIME}**
# Specify the file containing the private key corresponding to the administrator's X.509 certificate.
# It must be in PEM format.  <p><em>Be sure that this file is only readable by the
# Foswiki software; it must NOT be readable by users!</em>
$Foswiki::cfg{Email}{SmimeKeyFile} = '';

# **PASSWORD 30 FEEDBACK=auto DISPLAY_IF {Email}{EnableSMIME}**
# If the file containing the certificate's private key is encrypted, specify the password.
# Otherwise leave blank.
# <p>Currently only DES3 encryption is supported, but you can convert other files with
# *openssl* as follows: <br />
# <i>openssl rsa -in keyfile.pem -out keyfile.pem -des3</i>
$Foswiki::cfg{Email}{SmimeKeyPassword} = '';

# **PASSWORD 30 DISPLAY_IF false**
# This field never displays.  It holds the password for an uninstalled S/MIME private key.
$Foswiki::cfg{Email}{SmimePendingKeyPassword} = '';

#---+++ Certificate Management
# The following paramenters can be used to specify commonly used components of the subject
# name for Certificate Signing Requests.<p>
# You can also install a signed certificate with the action button.
# **STRING LABEL="Country Code"**
# ISO country code (2 letters)
$Foswiki::cfg{Email}{SmimeCertC} = '';

# **STRING LABEL="State or Province"**
# State or Province
$Foswiki::cfg{Email}{SmimeCertST} = '';

# **STRING LABEL="Locality"**
# Locality (city or town)
$Foswiki::cfg{Email}{SmimeCertL} = '';

# **STRING LABEL="Organization"**
# Organization - Required
$Foswiki::cfg{Email}{SmimeCertO} = '';

# **STRING LABEL="Organizational Unit"**
# Organizational unit (e.g. Department) - Required
$Foswiki::cfg{Email}{SmimeCertOU} = '';

# **STRING 70x10 s \
#           FEEDBACK="Display CSR" NOLABEL \
#                     title="Display pending Certificate Signing Request" \
#           FEEDBACK="Install Certificate" NOLABEL \
#                     title="Install a signed certificate" \
#           FEEDBACK="Display Certificate";col="2" NOLABEL \
#                     title="Display the active certificate" **
$Foswiki::cfg{ConfigureGUI}{SMIME}{InstallCert} = '';

#---+ Miscellaneous -- EXPERT
# <p>Miscellaneous expert options.</p>

# **STRING 20**
# Name of the web where documentation and default preferences are held. If you
# change this setting, you must make sure the web exists and contains
# appropriate content, and upgrade scripts may no longer work (i.e. don't
# change it unless you are certain that you know what you are doing!)
$Foswiki::cfg{SystemWebName} = 'System';

# **STRING 20**
# Name of the web used as a trashcan (where deleted topics are moved)
# If you change this setting, you must make sure the web exists.
$Foswiki::cfg{TrashWebName} = 'Trash';

# **STRING 20**
# Name of the web used as a scratchpad or temporary workarea for users to
# experiment with Foswiki topics.
$Foswiki::cfg{SandboxWebName} = 'Sandbox';

# **STRING 20**
# Name of site-level preferences topic in the {SystemWebName} web.
# <b>If you change this setting you will have to
# use Foswiki and *manually* rename the existing topic.</b>
# (i.e. don't change it unless you are <b>certain</b> that you know what
# you are doing!)
$Foswiki::cfg{SitePrefsTopicName} = 'DefaultPreferences';

# **STRING 70**
# Web.TopicName of the site-level local preferences topic. If this topic
# exists, any settings in it will <b>override</b> settings in
# {SitePrefsTopicName}.<br />
# You are <b>strongly</b> recommended to keep all your local changes in
# a {LocalSitePreferences} topic rather than changing DefaultPreferences,
# as it will make upgrading a lot easier.
$Foswiki::cfg{LocalSitePreferences} =
  '$Foswiki::cfg{UsersWebName}.SitePreferences';

# **STRING 20**
# Name of main topic in a web.
# <b>If you change this setting you will have to
# use Foswiki to manually rename the topic in all existing webs</b>
# (i.e. don't change it unless you are <b>certain</b> that you know what
# you are doing!)
$Foswiki::cfg{HomeTopicName} = 'WebHome';

# **STRING 20**
# Name of preferences topic in a web.
# <b>If you change this setting you will have to
# use Foswiki to manually rename the topic in all existing webs</b>
# (i.e. don't change it unless you are <b>certain</b> that you know what
# you are doing!)
$Foswiki::cfg{WebPrefsTopicName} = 'WebPreferences';

# **STRING 20**
# Name of topic in each web that has notification registrations.
# <b>If you change this setting you will have to
# use Foswiki to manually rename the topic in all existing webs</b>
$Foswiki::cfg{NotifyTopicName} = 'WebNotify';

# **STRING 20**
# Name of the web where usertopics are stored. If you
# change this setting, you must make sure the web exists and contains
# appropriate content, and upgrade scripts may no longer work
# (i.e. don't change it unless you are <b>certain</b> that you know what
# you are doing!)
$Foswiki::cfg{UsersWebName} = 'Main';

# **STRING 70x10 s**
# A comma-separated list of generic file name templates that defines the order
# in which templates are assigned to skin path components.
# The file name templates can either be absolute file names ending in ".tmpl"
# or a topic name in a Foswiki web. The file names may contain
# these placeholders: <code>$name</code> (the template name), <code>$web</code>
# (the web), and <code>$skin</code> (the skin).
# Finding the right template file is done by following the skin path, and for
# each skin path component following the template path.
# The first file on the skin path + template path that is found is taken to be
# the requested template file.
# See 'Security and usability' in System.SkinTemplates for advice on
# setting this path for increased security.
$Foswiki::cfg{TemplatePath} =
'$Foswiki::cfg{TemplateDir}/$web/$name.$skin.tmpl, $Foswiki::cfg{TemplateDir}/$name.$skin.tmpl, $web.$skinSkin$nameTemplate, $Foswiki::cfg{SystemWebName}.$skinSkin$nameTemplate, $Foswiki::cfg{TemplateDir}/$web/$name.tmpl, $Foswiki::cfg{TemplateDir}/$name.tmpl, $web.$nameTemplate, $Foswiki::cfg{SystemWebName}.$nameTemplate';

# **STRING 120**
# List of protocols (URI schemes) that Foswiki will
# automatically recognize in absolute links.
# Add any extra protocols specific to your environment (for example, you might
# add 'imap' or 'pop' if you are using shared mailboxes accessible through
# your browser, or 'tel' if you have a softphone setup that supports links
# using this URI scheme). A list of popular URI schemes can be
# found at <a href="http://en.wikipedia.org/wiki/URI_scheme">http://en.wikipedia.org/wiki/URI_scheme</a>.
$Foswiki::cfg{LinkProtocolPattern} =
  '(file|ftp|gopher|https|http|irc|mailto|news|nntp|telnet)';

# **NUMBER CHECK="min:2" FEEDBACK=AUTO **
# Length of linking acronyms.  Minumum number of consecutive upper case characters
# required to be linked as an acronym.
$Foswiki::cfg{AcronymLength} = 3;

# **BOOLEAN**
# 'Anchors' are positions within a Foswiki page that can be targeted in
# a URL using the <tt>#anchor</tt> syntax. The format of these anchors has
# changed several times. If this option is set, Foswiki will generate extra
# redundant anchors that are compatible with the old formats. If it is not
# set, the links will still work but will go to the head of the target page.
# There is a small performance cost for enabling this option. Set it if
# your site has been around for a long time, and you want existing external
# links to the internals of pages to continue to work.
$Foswiki::cfg{RequireCompatibleAnchors} = 0;

# **NUMBER CHECK="min:0" FEEDBACK=AUTO **
# How many links to other revisions to show in the bottom bar. 0 for all
$Foswiki::cfg{NumberOfRevisions} = 4;

# **NUMBER CHECK="min:1" FEEDBACK=AUTO **
# Set the upper limit of the maximum number of difference that will be
# displayed when viewing the entire history of a page. The compared revisions
# will be evenly spaced across the history of the page e.g. if the page has
# 100 revisions and we have set this option to 10, we will see differences
# between r100 and r90, r90 and r80, r80 and r70 and so on.
$Foswiki::cfg{MaxRevisionsInADiff} = 25;

# **NUMBER CHECK="min:0" FEEDBACK=AUTO **
# If this is set to a > 0 value, and the revision control system
# supports it (RCS does), then if a second edit of the same topic
# is done by the same user within this number of seconds, a new
# revision of the topic will NOT be created (the top revision will
# be replaced). Set this to 0 if you want <b>all</b> topic changes to create
# a new revision (as required by most formal development processes).
$Foswiki::cfg{ReplaceIfEditedAgainWithin} = 3600;

# **NUMBER CHECK="min:60" FEEDBACK=AUTO **
# When a topic is edited, the user takes a "lease" on that topic.
# If another user tries to also edit the topic while the lease
# is still active, they will get a warning. Leases are released
# automatically when the topic is saved; otherwise they remain active
# for {LeaseLength} seconds from when the edit started (or was checkpointed).
# <p />Note: Leases are <b>not</b> locks; they are purely advisory. Leases
# can always be broken, but they are valuable if you want to avoid merge
# conflicts (e.g. you use highly structured data in your topic text and
# want to avoid ever having to deal with conflicts)
# <p />Since Foswiki 1.0.6, Foswiki pages that can be used to POST to the
# server have a validation key, that must be sent to the server for the
# post to succeed. These validation keys can only be used once, and expire
# at the same time as the lease expires.
$Foswiki::cfg{LeaseLength} = 3600;

# **NUMBER CHECK="min:-1" FEEDBACK=AUTO **
# Even if the other users' lease has expired, then you can specify that
# they should still get a (less forceful) warning about the old lease for
# some additional time after the lease expired. You can set this to 0 to
# suppress these extra warnings completely, or to -1 so they are always
# issued, or to a number of seconds since the old lease expired.
$Foswiki::cfg{LeaseLengthLessForceful} = 3600;

# **PATH**
# Pathname to file that maps file suffixes to MIME types :
# For Apache server set this to Apache's mime.types file pathname,
# for example /etc/httpd/mime.types, or use the default shipped in
# the Foswiki data directory.
$Foswiki::cfg{MimeTypesFileName} = '$Foswiki::cfg{DataDir}/mime.types';

# **BOOLEAN EXPERT**
# Enable tracebacks in error messages.  Used for debugging.
# $Foswiki::cfg{DebugTracebacks} = '';

# **NUMBER CHECK="min:-1" FEEDBACK=AUTO EXPERT**
# Maximum number of backup versions of LocalSite.cfg to retain when changes
# are saved.  Enables you to recover quickly from accidental changes.
# 0 does not save any backup versions.  -1 does not limit the number of versions
# retained.
$Foswiki::cfg{MaxLSCBackups} = 10;

#############################################################################
#---+ Extensions -- TABS

#---++ Extension operation and maintenance
# <ul>
# <li>Specify the plugin load order.</li>
# <li>Use the Extensions Repository to add, update or remove plugins.</li>
# <li>Enable and disable installed plugins.</li>
# </ul>

#---+++ Configure how plugins are loaded by Foswiki
# **STRING AUDIT="EPARS:1" FEEDBACK="Re-test" 80**
# Plugins evaluation order. If set to a comma-separated list of plugin names,
# will change the execution order of plugins so the listed subset of plugins
# are executed first. The default execution order is alphabetical on plugin
# name. <br/><br/>
#
# If TWiki compatibility is required, TWikiCompatibilityPlugin should be the first
# Plugin in the list.  SpreadSheetPlugin should typically be next in the list for proper operation.<br/><br/>
#
# Note that some other general extension environment checks are made and reported here.  Plugins
# that are enabled but not installed and duplicate plugins in the TWiki and Foswiki libraries
# are reported here.  Also if a TWiki plugin is enabled and the Foswik version is installed, this
# will also be reported here.  Expand the "Expert" options to find these issues.
#
$Foswiki::cfg{PluginsOrder} = 'TWikiCompatibilityPlugin,SpreadSheetPlugin';

# **STRING 80 EXPERT**
# Search path (web names) for plugin topics. Note that the current web
# is searched last, after this list.   Most modern foswiki plugins do not
# use the plugin topic for settings, and this setting is ignored. It is
# recommended that this setting not be changed.
$Foswiki::cfg{Plugins}{WebSearchPath} = '$Foswiki::cfg{SystemWebName},TWiki';

#---+++ Install, Update or Remove extensions
# **STRING 80 EXPERT**
# <b>Extensions Repositories Search List</b><br />
# Foswiki extension repositories are just Foswiki webs that are organised in the
# same way as the Extensions web on Foswiki.org. The 'Find more extensions' link
# above searches these repositories for installable extensions. To set up an
# extensions repository:
# <ol>
# <li>Create a Foswiki web to contain the repository</li>
# <li>Copy the <tt>FastReport</tt> page from <a href="http://foswiki.org/Extensions/FastReport?raw=on" target="_new">Foswiki:Extensions.FastReport</a> to your new web</li>
# <li> Set the <tt>WEBFORMS</tt> preference in WebPreferences to <tt>PackageForm</tt></li>
# </ol>
# The page for each extension must have the <tt>PackageForm</tt> (copy from Foswiki.org),
# and should have the packaged extension attached as a <tt>zip</tt> and/or
# <tt>tgz</tt> file.
# <p />
# The search list is a semicolon-separated list of repository specifications, each in the format: <i>name=(listurl,puburl,username,password)</i>
# where:
# <ul>
# <li><code>name</code> is the symbolic name of the repository e.g. Foswiki.org</li>
# <li><code>listurl</code> is the root of a view URL</li>
# <li><code>puburl</code> is the root of a download URL</li>
# <li><code>username</code> is the username if TemplateAuth is required on the repository (optional)</li>
# <li><code>password</code> is the password if TemplateAuth is required on the repository (optional)</li>
# </ul>
# Note: if your Repository uses ApacheAuth, embed the username and password into the listurl as <code>?username=x;password=y</code>
# <p />
# For example,<code>
# twiki.org=(http://twiki.org/cgi-bin/viewlugins/,http://twiki.org/p/pub/Plugins/); foswiki.org=(http://foswiki.org/Extensions/,http://foswiki.org/pub/Extensions/);</code><p />
# For Extensions with the same name in more than one repository, the <strong>last</strong> matching repository in the list will be chosen, so Foswiki.org should always be last in the list for maximum compatibility.
$Foswiki::cfg{ExtensionsRepositories} =
'Foswiki.org=(http://foswiki.org/Extensions/,http://foswiki.org/pub/Extensions/)';

# *FINDEXTENSIONS* Marker used by bin/configure script - do not remove!

#---+++ Enable or disable installed extensions

# *PLUGINS* Marker used by bin/configure script - do not remove!
# <p>The plugins listed below were discovered by searching the <code>@INC</code>
# path for modules that match the Foswiki standard e.g.
# <code>Foswiki/Plugins/MyPlugin.pm</code> or the TWiki standard i.e.
# <code>TWiki/Plugins/YourPlugin.pm</code> Note that this list
# is only for Plugins. You cannot Enable/Disable Contribs, AddOns or Skins.</p>
# <p>Any plugins enabled in the configuration but not found in the <code>@INC</code>
# path are listed at the end and are flagged as errors in the PluginsOrder check.</p>

$Foswiki::cfg{Plugins}{PreferencesPlugin}{Enabled} = 1;
$Foswiki::cfg{Plugins}{PreferencesPlugin}{Module} =
  'Foswiki::Plugins::PreferencesPlugin';
$Foswiki::cfg{Plugins}{SmiliesPlugin}{Enabled} = 1;
$Foswiki::cfg{Plugins}{SmiliesPlugin}{Module} =
  'Foswiki::Plugins::SmiliesPlugin';
$Foswiki::cfg{Plugins}{CommentPlugin}{Enabled} = 1;
$Foswiki::cfg{Plugins}{CommentPlugin}{Module} =
  'Foswiki::Plugins::CommentPlugin';
$Foswiki::cfg{Plugins}{SpreadSheetPlugin}{Enabled} = 1;
$Foswiki::cfg{Plugins}{SpreadSheetPlugin}{Module} =
  'Foswiki::Plugins::SpreadSheetPlugin';
$Foswiki::cfg{Plugins}{InterwikiPlugin}{Enabled} = 1;
$Foswiki::cfg{Plugins}{InterwikiPlugin}{Module} =
  'Foswiki::Plugins::InterwikiPlugin';
$Foswiki::cfg{Plugins}{NatEditPlugin}{Enabled} = 1;
$Foswiki::cfg{Plugins}{NatEditPlugin}{Module} =
  'Foswiki::Plugins::NatEditPlugin';
$Foswiki::cfg{Plugins}{TablePlugin}{Enabled} = 1;
$Foswiki::cfg{Plugins}{TablePlugin}{Module}  = 'Foswiki::Plugins::TablePlugin';
$Foswiki::cfg{Plugins}{EditRowPlugin}{Enabled} = 1;
$Foswiki::cfg{Plugins}{EditRowPlugin}{Module} =
  'Foswiki::Plugins::EditRowPlugin';
$Foswiki::cfg{Plugins}{SlideShowPlugin}{Enabled} = 1;
$Foswiki::cfg{Plugins}{SlideShowPlugin}{Module} =
  'Foswiki::Plugins::SlideShowPlugin';
$Foswiki::cfg{Plugins}{TwistyPlugin}{Enabled} = 1;
$Foswiki::cfg{Plugins}{TwistyPlugin}{Module} = 'Foswiki::Plugins::TwistyPlugin';
$Foswiki::cfg{Plugins}{TinyMCEPlugin}{Enabled} = 1;
$Foswiki::cfg{Plugins}{TinyMCEPlugin}{Module} =
  'Foswiki::Plugins::TinyMCEPlugin';
$Foswiki::cfg{Plugins}{WysiwygPlugin}{Enabled} = 1;
$Foswiki::cfg{Plugins}{WysiwygPlugin}{Module} =
  'Foswiki::Plugins::WysiwygPlugin';
$Foswiki::cfg{Plugins}{TWikiCompatibilityPlugin}{Enabled} = 0;
$Foswiki::cfg{Plugins}{TWikiCompatibilityPlugin}{Module} =
  'Foswiki::Plugins::TWikiCompatibilityPlugin';
$Foswiki::cfg{Plugins}{AutoViewTemplatePlugin}{Enabled} = 1;
$Foswiki::cfg{Plugins}{AutoViewTemplatePlugin}{Module} =
  'Foswiki::Plugins::AutoViewTemplatePlugin';
$Foswiki::cfg{Plugins}{CompareRevisionsAddonPlugin}{Enabled} = 1;
$Foswiki::cfg{Plugins}{CompareRevisionsAddonPlugin}{Module} =
  'Foswiki::Plugins::CompareRevisionsAddonPlugin';
$Foswiki::cfg{Plugins}{HistoryPlugin}{Enabled} = 1;
$Foswiki::cfg{Plugins}{HistoryPlugin}{Module} =
  'Foswiki::Plugins::HistoryPlugin';
$Foswiki::cfg{Plugins}{JQueryPlugin}{Enabled} = 1;
$Foswiki::cfg{Plugins}{JQueryPlugin}{Module} = 'Foswiki::Plugins::JQueryPlugin';
$Foswiki::cfg{Plugins}{RenderListPlugin}{Enabled} = 1;
$Foswiki::cfg{Plugins}{RenderListPlugin}{Module} =
  'Foswiki::Plugins::RenderListPlugin';
$Foswiki::cfg{Plugins}{MailerContribPlugin}{Enabled} = 1;
$Foswiki::cfg{Plugins}{MailerContribPlugin}{Module} =
  'Foswiki::Plugins::MailerContribPlugin';
$Foswiki::cfg{Plugins}{SubscribePlugin}{Enabled} = 1;
$Foswiki::cfg{Plugins}{SubscribePlugin}{Module} =
  'Foswiki::Plugins::SubscribePlugin';
$Foswiki::cfg{Plugins}{UpdatesPlugin}{Enabled} = 1;
$Foswiki::cfg{Plugins}{UpdatesPlugin}{Module} =
  'Foswiki::Plugins::UpdatesPlugin';

$Foswiki::cfg{Plugins}{HomePagePlugin}{Enabled} = 1;
$Foswiki::cfg{Plugins}{HomePagePlugin}{Module} =
  'Foswiki::Plugins::HomePagePlugin';

# ---+ Configuration Audit
# Functions on this page perform extensive inspection and/or analysis of 
# your configuration and its environment
# *AUDIT* # Plugin generates Configuration audit tab

1;
__END__
#
# Copyright (C) 2008-2012 Foswiki Contributors. Foswiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this module
# as follows:
# Copyright (C) 1999-2007 Peter Thoeny, peter@thoeny.org and
# TWiki Contributors.# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# As per the GPL, removal of this notice is prohibited.
