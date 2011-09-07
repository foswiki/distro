# Configuration of Foswiki - The Free and Open Source Wiki, http://foswiki.org/
# See bottom of file for license and copyright information.

# This specification file is held in 'foswiki/lib' directory. DO NOT EDIT
# THIS FILE!

# DO NOT COPY THIS FILE TO LocalSite.cfg - Run configure from your browser
# which will guess required settings, merge the files and write a new
# LocalSite.cfg.

# If for some reason you still want to copy this file to LocalSite.cfg,  you
# must un-comment and complete the 10 PATH and URLPATH settings that are flagged
# as Mandatory ( M** ) and remove the __END__ line toward the end of the file.

# Manually building LocalSite.cfg is STRONGLY DISCOURAGED.

# See 'setlib.cfg' in the 'bin' directory for how to configure a non-standard
# include path for Perl modules.
#
# Note that the comments in this file are formatted specifically so
# that the 'configure' script can extract documentation from here. See
# http://foswiki.org/System/DevelopingPlugins#Integrating_with_configure
# for details of the syntax used.
#
# NOTE FOR DEVELOPERS: you can use $Foswiki::cfg variables in other settings,
# but you must be sure they are only evaluated under program control and
# not when this file is loaded. For example:
## $Foswiki::cfg{Blah} = "$Foswiki::cfg{DataDir}/blah.dat"; # BAD
## $Foswiki::cfg{Blah} = '$Foswiki::cfg{DataDir}/blah.dat'; # GOOD

# Note that the general path settings are deliberately commented out.
# This is because they *must* be defined in LocalSite.cfg, and *not* here.

#---+ General path settings
# <p><strong>If you are a first-time installer:</strong> once you have set
# up the eight paths below, your wiki should work - try it. You can
# always come back and tweak other settings later.</p>
# <p><b>Security Note:</b> Only the URL paths listed below should
# be browseable from the web. If you expose any other directories (such as
# lib or templates) you are opening up routes for possible hacking attempts.</p>

# **URL M**
#  This is the root of all Foswiki URLs e.g. http://myhost.com:123.
# $Foswiki::cfg{DefaultUrlHost} = 'http://your.domain.com';

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

# **URLPATH M**
# This is the 'cgi-bin' part of URLs used to access the Foswiki bin
# directory e.g. <code>/foswiki/bin</code><br />
# Do <b>not</b> include a trailing /.
# <p />
# See <a href="http://foswiki.org/Support/ShorterUrlCookbook" target="_new">ShorterUrlCookbook</a> for more information on setting up
# Foswiki to use shorter script URLs.  Expand expert settings to get to settings for the <code>view</code> script.  Other scripts need to 
# be manually added to <code>lib/LocalSite.cfg</code>
# $Foswiki::cfg{ScriptUrlPath} = '/foswiki/bin';

# **URLPATH M**
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
$Foswiki::cfg{ScriptUrlPaths}{view} = '$Foswiki::cfg{ScriptUrlPath}/view$Foswiki::cfg{ScriptSuffix}';

# **PATH M**
# This is the file system path used to access the Foswiki bin
# directory.
# $Foswiki::cfg{ScriptDir} = '/home/httpd/foswiki/bin';

# **URLPATH M**
# Attachments URL path e.g. /foswiki/pub
# <p /><b>Security Note:</b> files in this directory are *not*
# protected by Foswiki access controls. If you require access controls, you
# will have to use webserver controls (e.g. .htaccess on Apache)
# $Foswiki::cfg{PubUrlPath} = '/foswiki/pub';

# **NUMBER EXPERT**
# This is the maximum number of files and directories that will be checked 
# for permissions for the pub and data Directory paths.  This limit is initially set to 
# 5000, which should be reasonable for a default installation.  If it is 
# exceeded, then an informational message is returned stating that incomplete
# checking was performed.  If this is set to a large number on large installations,
# then a significant delay will be incurred when configure is run, due to the 
# recursive directory checking.
$Foswiki::cfg{PathCheckLimit} = 5000;

# **PATH M**
# Attachments store (file path, not URL), must match /foswiki/pub e.g.
# /usr/local/foswiki/pub
# $Foswiki::cfg{PubDir} = '/home/httpd/foswiki/pub';

# **PATH M**
# Topic files store (file path, not URL) e.g. /usr/local/foswiki/data
# $Foswiki::cfg{DataDir} = '/home/httpd/foswiki/data';

# **PATH M**
# Tools directory e.g. /usr/local/foswiki/tools
# $Foswiki::cfg{ToolsDir} = '/home/httpd/foswiki/tools';

# **PATH M**
# Template directory e.g. /usr/local/foswiki/templates
# $Foswiki::cfg{TemplateDir} = '/home/httpd/foswiki/templates';

# **PATH M**
# Translation files directory (file path, not URL) e.g. /usr/local/foswiki/locale
# $Foswiki::cfg{LocalesDir} = '/home/httpd/foswiki/locale';

# **PATH M**
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
# <li>{WorkingDir}<tt>/work_areas</tt> - these are work areas used by
# extensions that need to store data on the disc </li>
# <li>{WorkingDir}<tt>/registration_approvals</tt> - this is used by the
# default Foswiki registration process to store registrations that are pending
# verification.</li>
# </ul>
# $Foswiki::cfg{WorkingDir} = '/home/httpd/foswiki/working';

# **STRING 10**
# Suffix of Foswiki CGI scripts (e.g. .cgi or .pl). You may need to set this
# if your webserver requires an extension.
$Foswiki::cfg{ScriptSuffix} = '';

# **STRING 20 EXPERT**
# {OS} and {DetailedOS} are calculated in the Foswiki code. <b>You
# should only need to override if there is something badly wrong with
# those calculations.</b><br />
# {OS} may be one of UNIX WINDOWS VMS DOS MACINTOSH OS2
$Foswiki::cfg{OS} = '';
# **STRING 20 EXPERT**
# The value of Perl $OS
$Foswiki::cfg{DetailedOS} = '';

#---+ Security and Authentication -- TABS
# <p>In order to support tracking who changed what, and apply access controls,
# Foswiki is normally configured to use logins. The tabs below control
# various aspects of logins.</p>
#---++ Sessions
# <p>Sessions are how Foswiki tracks a user across multiple requests.
# A user's session id is stored in a cookie, and this is used to identify
# the user for each request they make to the server.
# You can use sessions even if you are not using login.
# This allows you to have persistent session variables - for example, skins.
# Client sessions are not required for logins to work, but Foswiki will not
# be able to remember logged-in users consistently.
# See <a href="http://foswiki.org/System/UserAuthentication" target="_new">User 
# Authentication</a> for a full discussion of the pros and
# cons of using persistent sessions.</p>

# **BOOLEAN**
# Control whether Foswiki will use persistent sessions.
$Foswiki::cfg{UseClientSessions} = 1;

# **STRING 20**
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
# <p /> Session files are stored in the <tt>{WorkingDir}/tmp</tt> directory.
$Foswiki::cfg{Sessions}{ExpireAfter} = 21600;

# **NUMBER EXPERT**
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

# **BOOLEAN EXPERT**
# If you have persistent sessions enabled, then Foswiki will use a cookie in
# the browser to store the session ID. If the client has cookies disabled,
# then Foswiki will not be able to record the session. As a fallback, Foswiki
# can rewrite local URLs to pass the session ID as a parameter to the URL.
# This is a potential security risk, because it increases the chance of a
# session ID being stolen (accidentally or intentionally) by another user.
# If this is turned off, users with cookies disabled will have to
# re-authenticate for every secure page access (unless you are using
# {Sessions}{MapIP2SID}).
$Foswiki::cfg{Sessions}{IDsInURLs} = 0;

# **BOOLEAN EXPERT**
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

# **BOOLEAN EXPERT**
# For compatibility with older versions, Foswiki supports the mapping of the
# clients IP address to a session ID. You can only use this if all
# client IP addresses are known to be unique.
# If this option is enabled, Foswiki will <b>not</b> store cookies in the
# browser.
# The mapping is held in the file $Foswiki::cfg{WorkingDir}/tmp/ip2sid.
# If you turn this option on, you can safely turn {Sessions}{IDsInURLs}
# <i>off</i>.
$Foswiki::cfg{Sessions}{MapIP2SID} = 0;

# **STRING 20 EXPERT**
# By default the Foswiki session cookie is only accessible by the host which
# sets it. To change the scope of this cookie you can set this to any other
# value (ie. company.com). Make sure, Foswiki can access its own cookie. <br />
# If empty, this defaults to the current host.
$Foswiki::cfg{Sessions}{CookieRealm} = '';

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

# **NUMBER EXPERT**
# Validation keys are stored for a maximum of this amount of time before
# they are invalidated. Time in seconds.
$Foswiki::cfg{Validation}{ValidForTime} = 3600;

# **NUMBER EXPERT**
# The maximum number of validation keys to store in a session. There is one
# key stored for each page rendered. If the number of keys exceeds this
# number, the oldest keys will be force-expired to bring the number down.
$Foswiki::cfg{Validation}{MaxKeysPerSession} = 1000;

# **BOOLEAN EXPERT**
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

# **STRING 100**
# Comma-separated list of scripts in the bin directory that require the user to
# authenticate. This setting is used with TemplateLogin; any time an
# unauthenticated user attempts to access one of these scripts, they will be
# required to authenticate. With ApacheLogin, the web server must be configured
# to require a valid user for access to these scripts.  <code>edit</code> and
# <code>save</code> should be removed from this list if the guest user is permitted to
# edit topics without authentication.
$Foswiki::cfg{AuthScripts} = 'attach,edit,manage,rename,save,upload,viewauth,viewfileauth,previewauth,rdiffauth,restauth,rest';

# **BOOLEAN EXPERT**
# Browsers typically remember your login and passwords to make authentication
# more convenient for users. If your Foswiki is used on public terminals,
# you can prevent this, forcing the user to enter the login and password
# every time.
$Foswiki::cfg{TemplateLogin}{PreventBrowserRememberingPassword} = 0;

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
# An admin user WikiName what is displayed for actions done by the AdminUserLogin
# You should normally not need to change this. (You will need to move the
# %USERSWEB%.AdminUser topic to match.)
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

# **STRING 80 EXPERT**
# Authentication realm. This is
# normally only used in md5 password encoding. You may need to change it
# if you are sharing a password file with another application.
$Foswiki::cfg{AuthRealm} = 'Enter your WikiName. (First name and last name, no space, no dots, capitalized, e.g. JohnSmith). Cancel to register if you do not have one.';


# **SELECTCLASS Foswiki::Users::*UserMapping**
# The user mapping is used to equate login names, used with external
# authentication systems, with Foswiki user identities. 
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


#---++ Access Control
# **SELECTCLASS Foswiki::Access::*Access EXPERT**
# under development - see http://foswiki.org/Development/PluggableAccessControlImplementation
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

# **NUMBER**
# Minimum length for a password, for new registrations and password changes.
# If you want to allow null passwords, set this to 0.
$Foswiki::cfg{MinPasswordLength} = 7;

# **PATH**
# Path to the file that stores passwords, for the Foswiki::Users::HtPasswdUser
# password manager. You can use the <tt>htpasswd</tt> Apache program to create a new
# password file with the right encoding.
$Foswiki::cfg{Htpasswd}{FileName} = '$Foswiki::cfg{DataDir}/.htpasswd';

# **SELECT htdigest-md5,sha1,apache-md5,crypt-md5,crypt,plain**
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
# the encrypted form of the password, thus: <tt>user:{AuthRealm}:hash</tt>.
# This encoding is generated by the Apache <tt>htdigest</tt> command.</dd>
# <dt><tt>sha1</tt></dt><dd> is recommended.  It has the strongest hash.  This is the encoding
# generated by the <tt>htpasswd -s</tt> command (<tt>userid:{SHA}hash</tt>).</dd>
# <dt><tt>apache-md5</tt></dt><dd> Enable an Apache-specific algorithm using an iterated
# (1,000 times) MD5 digest of various combinations of a random 32-bit salt and the password
# (<tt>userid:$apr1$salt$hash</tt>).
# This is the encoding generated by the <tt>htpasswd -m</tt> command.</dd>
# <dt><tt>crypt-md5</tt></dt><dd> Enable use of standard libc (/etc/shadow) crypt-md5 password
# (like <tt>user:$1$salt$hash:email</tt>).  Unlike <tt>crypt</tt> encoding, it does not suffer from password truncation.
# Passwords are salted, and the salt is stored in the encrypted password string as in normal crypt passwords. This
# encoding is understood by Apache but cannot be generated by the <tt>htpasswd</tt> command.</dd>
# <dt><tt>crypt</tt></dt><dd> is the default. <b>Not Recommended.</b> crypt encoding only
# uses the first 8 characters of the password. Extra characters are silently discarded.
# This is the default generated by the Apache <tt>htpasswd</tt> command (<tt>user:hash:email</tt>)</dd>
# <dt><tt>plain</tt></dt><dd> stores passwords as plain text (no encryption). Useful for testing. Not compatible with <tt>{AutoDetect}</tt> option.</dd>
# </dl>

# If you need to create entries in <tt>.htpasswd</tt> before Foswiki is operational, you can use the
# <tt>htpasswd</tt> or <tt>htdigest</tt> Apache program to create a new password file with the correct
# encoding. Use caution however as these programs do not support the email addresses stored by Foswiki in
# the <tt>.htpasswd</tt> file.
$Foswiki::cfg{Htpasswd}{Encoding} = 'crypt';

# **BOOLEAN**
# Allow the <tt>Foswiki::Users::HtPasswdUser</tt>password check routines to auto-detect the stored encoding type.  Enable
# this to allow migration from one encoding format to another format.  Note that this does
# add a small overhead to the parsing of the <tt>.htpasswd</tt> file.  Tests show approximately 1ms per 1000 entries.  It should be used
# with caution unless you are using CGI acceleration such as FastCGI or mod_perl.
#
# This option is not compatible with <tt>plain</tt> text passwords.
$Foswiki::cfg{Htpasswd}{AutoDetect} = $FALSE;

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

# **BOOLEAN EXPERT**
# Controls whether the user password has to be entered twice on the
# registration page or not. The default is to require confirmation, in which
# case the same password must be provided in the Twk1Password and
# Twk1Confirm inputs.
$Foswiki::cfg{Register}{DisablePasswordConfirmation} = $FALSE;

# **BOOLEAN EXPERT**
# Hide password in registration email to the <em>user</em>
# Note that Foswiki sends administrators a separate confirmation.
$Foswiki::cfg{Register}{HidePasswd} = $TRUE;

# **STRING 20 EXPERT**
# The internal user that creates user topics on new registrations.
# You are recommended not to change this.
$Foswiki::cfg{Register}{RegistrationAgentWikiName} = 'RegistrationAgent';

# **STRING H**
# Configuration password (not prompted)
$Foswiki::cfg{Password} = '';

#---++ Environment
# **PATH M**
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
$Foswiki::cfg{SafeEnvPath} = '';

# **PERL**
# Array of the names of configuration items that are available when using %IF, %SEARCH
# and %QUERY{}%. Extensions can push into this array to extend the set. This is done as
# a filter in because while the bulk of configuration items are quite innocent,
# it's better to be a bit paranoid.
$Foswiki::cfg{AccessibleCFG} = [ '{ScriptSuffix}', '{LoginManager}', '{AuthScripts}', '{LoginNameFilterIn}', '{AdminUserLogin}', '{AdminUserWikiName}', '{SuperAdminGroup}', '{UsersTopicName}', '{AuthRealm}', '{MinPasswordLength}', '{Register}{AllowLoginName}', '{Register}{EnableNewUserRegistration}', '{Register}{NeedVerification}', '{Register}{RegistrationAgentWikiName}', '{AllowInlineScript}', '{DenyDotDotInclude}', '{UploadFilter}', '{NameFilter}', '{AccessibleCFG}', '{AntiSpam}{EmailPadding}', '{AntiSpam}{EntityEncode}','{AntiSpam}{HideUserDetails}', '{AntiSpam}{RobotsAreWelcome}', '{Stats}{TopViews}', '{Stats}{TopContrib}', '{Stats}{TopicName}', '{UserInterfaceInternationalisation}', '{UseLocale}', '{Site}{Locale}', '{Site}{CharSet}', '{DisplayTimeValues}', '{DefaultDateFormat}', '{Site}{LocaleRegexes}', '{UpperNational}', '{LowerNational}', '{PluralToSingular}', '{EnableHierarchicalWebs}', '{WebMasterEmail}', '{WebMasterName}', '{NotifyTopicName}', '{SystemWebName}', '{TrashWebName}', '{SitePrefsTopicName}', '{LocalSitePreferences}', '{HomeTopicName}', '{WebPrefsTopicName}', '{UsersWebName}', '{TemplatePath}', '{LinkProtocolPattern}', '{NumberOfRevisions}', '{MaxRevisionsInADiff}', '{ReplaceIfEditedAgainWithin}', '{LeaseLength}', '{LeaseLengthLessForceful}', '{Plugins}{WebSearchPath}', '{PluginsOrder}', '{Cache}{Enabled}', '{Validation}{Method}', '{Register}{DisablePasswordConfirmation}' ];

# **BOOLEAN**
# Allow %INCLUDE of URLs. This is disabled by default, because it is possible
# to mount a denial-of-service (DoS) attack on a Foswiki site using INCLUDE and
# URLs. Only enable it if you are in an environment where a DoS attack is not
# a high risk.
# <p /> You may also need to configure the proxy settings ({PROXY}{HOST} and
# {PROXY}{PORT}) if your server is behind a firewall and you allow %INCLUDE of
# external webpages (see Mail and Proxies).
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
$Foswiki::cfg{UploadFilter} = qr/^(\.htaccess|.*\.(?i)(?:php[0-9s]?(\..*)?|[sp]htm[l]?(\..*)?|pl|py|cgi))$/;

# **REGEX EXPERT**
# Filter-out regex for webnames, topic names, usernames, include paths
# and skin names. This is a filter <b>out</b>, so if any of the
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
$Foswiki::cfg{RemovePortNumber}  = $FALSE;

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
$Foswiki::cfg{AllowRedirectUrl}  = $FALSE;

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
$Foswiki::cfg{AccessibleENV} = '^(HTTP_\w+|REMOTE_\w+|SERVER_\w+|REQUEST_\w+|MOD_PERL|FOSWIKI_ACTION|PATH_INFO)$';

#---++ Anti-Spam
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
# Normally Foswiki stores the user's sensitive information (such as their e-mail
# address) in a database out of public view. This is to help prevent e-mail
# spam and identity fraud.<br />
# If that is not a risk for you (e.g. you are behind a firewall) and you
# are happy for e-mails to be made public to all Foswiki users,
# then you can set this option.<br />
# Note that if this option is set, then the <code>user</code> parameter to
# <code>%USERINFO</code> is ignored.
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

#---+ Logging and Statistics

# **PATH**
# Directory where log files will be written. Log files are automatically
# cycled once a month.
$Foswiki::cfg{Log}{Dir} = '$Foswiki::cfg{WorkingDir}/logs';

# **SELECTCLASS none,Foswiki::Logger::* **
# Foswiki supports different implementations of log files. It can be
# useful to be able to plug in a database implementation, for example,
# for a large site, or even provide your own custom logger. Select the
# implementation to be used here. Most sites should be OK with the
# PlainFile logger, which automatically rotates the logs every month.<p />
# Note: the Foswiki 1.0 implementation of logfiles is still supported,
# through use of the <tt>Foswiki::Logger::Compatibility</tt> logger.
# Foswiki will automatically select the Compatibility logger if it detects
# a setting for <tt>{WarningFileName}</tt> in your LocalSite.cfg.
# You are recommended to change to the PlainFile logger at your earliest 
# convenience by removing <tt>{WarningFileName}</tt>, 
# <tt>{LogFileName}</tt> and <tt>{DebugFileName}</tt>
# from LocalSite.cfg and re-running configure.
$Foswiki::cfg{Log}{Implementation} = 'Foswiki::Logger::PlainFile';

# **PERL EXPERT**
# Whether or not to log different actions in the events log.
# Information in the events log is used in gathering web statistics,
# and is useful as an audit trail of Foswiki activity.
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

# **NUMBER**
# Number of top viewed topics to show in statistics topic
$Foswiki::cfg{Stats}{TopViews} = 10;

# **NUMBER**
# Number of top contributors to show in statistics topic
$Foswiki::cfg{Stats}{TopContrib} = 10;

# **STRING 20 EXPERT**
# Name of statistics topic
$Foswiki::cfg{Stats}{TopicName} = 'WebStatistics';

#---+ Internationalisation -- TABS
#---++ Languages
# **BOOLEAN**
# <p>Enable user interface internationalisation, i.e. presenting the user
# interface in the users own language(s). Some languages require the
# <code>Locale::Maketext::Lexicon</code> and <code>Encode/MapUTF8</code> Perl
# modules to be installed.</p>
$Foswiki::cfg{UserInterfaceInternationalisation} = $FALSE;

# **BOOLEAN EXPERT**
# <p>Enable compilation of .po string files into compressed .mo files.
# This can result in a significant performance improvement for I18N, but has also been
# reported to cause issues on some systems.  So for now this is considered experimental.
# Note that if string files are being edited, it requires that configure be rerun to recompile
# modified files.  Disable this option to prevent compling of string files.  If disabled,
# stale <code>&lt;language&gt;.mo</code> files should be removed from the
# Foswiki locale directory so that the modified .po file will be used.
$Foswiki::cfg{LanguageFileCompression} = $FALSE;

# *LANGUAGES* Marker used by bin/configure script - do not remove!
# <p>These settings control the languages that are available for the
# user interface. Check every language that you want your site to support.</p>
# <p>Allowing all languages is the best for <strong>really</Strong> international 
# sites, but for best performance you should enable only the languages you 
# really need. English is the default language, and is always enabled.</p>
# <p><code>{LocalesDir}</code> is used to find the languages supported in your installation,
# so if the list of available languages below is empty, it's probably because
# <code>{LocalesDir}</code> is pointing to the wrong place.</p>

$Foswiki::cfg{Languages}{bg}{Enabled} = 1;
$Foswiki::cfg{Languages}{cs}{Enabled} = 1;
$Foswiki::cfg{Languages}{da}{Enabled} = 1;
$Foswiki::cfg{Languages}{de}{Enabled} = 1;
$Foswiki::cfg{Languages}{es}{Enabled} = 1;
$Foswiki::cfg{Languages}{fr}{Enabled} = 1;
$Foswiki::cfg{Languages}{it}{Enabled} = 1;
$Foswiki::cfg{Languages}{ja}{Enabled} = 1;
$Foswiki::cfg{Languages}{nl}{Enabled} = 1;
$Foswiki::cfg{Languages}{pl}{Enabled} = 1;
$Foswiki::cfg{Languages}{pt}{Enabled} = 1;
$Foswiki::cfg{Languages}{ru}{Enabled} = 1;
$Foswiki::cfg{Languages}{sv}{Enabled} = 1;
$Foswiki::cfg{Languages}{tr}{Enabled} = 1;
$Foswiki::cfg{Languages}{'zh-cn'}{Enabled} = 1;
$Foswiki::cfg{Languages}{'zh-tw'}{Enabled} = 1;

#---++ Locale
# <p>Enable operating system level locales and internationalisation support
# for 8-bit character sets. This may be required for correct functioning
# of the programs that Foswiki calls when your wiki content uses
# international character sets.</p>

# **BOOLEAN**
# Enable the used of {Site}{Locale}
$Foswiki::cfg{UseLocale} = $FALSE;

# **STRING 50**
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
# Set this to match your chosen {Site}{Locale} (from 'locale -a')
# whose character set is not supported by your available perl conversion module
# (i.e. Encode for Perl 5.8 or higher, or Unicode::MapUTF8 for other Perl
# versions).  For example, if the locale 'ja_JP.eucjp' exists on your system
# but only 'euc-jp' is supported by Unicode::MapUTF8, set this to 'euc-jp'.
# If you don't define it, it will automatically be defaulted to iso-8859-1<br />
# UTF-8 support is still considered experimental. Use the value 'utf-8' to try it.
$Foswiki::cfg{Site}{CharSet} = undef;

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

# **STRING EXPERT**
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
# **STRING EXPERT**
#
$Foswiki::cfg{LowerNational} = '';

# **BOOLEAN EXPERT**
# Change non-existent plural topic name to singular,
# e.g. TestPolicies to TestPolicy. Only works in English.
$Foswiki::cfg{PluralToSingular} = $TRUE;

#---+ Store
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
$Foswiki::cfg{Store}{Implementation} = 'Foswiki::Store::RcsLite' if ($^O eq 'MSWin32');

# **BOOLEAN**
# Set to enable hierarchical webs. Without this setting, Foswiki will only
# allow a single level of webs. If you set this, you can use
# multiple levels, like a directory tree, i.e. webs within webs.
$Foswiki::cfg{EnableHierarchicalWebs} = 1;

# **NUMBER EXPERT**
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
$Foswiki::cfg{Store}{SearchAlgorithm} = 'Foswiki::Store::SearchAlgorithms::Forking';
$Foswiki::cfg{Store}{SearchAlgorithm} = 'Foswiki::Store::SearchAlgorithms::PurePerl' if ($^O eq 'MSWin32');

# bodgey up a default location for grep
my $grepDefaultPath = '/bin/';
$grepDefaultPath = '/usr/bin/' if ($^O eq 'darwin');
$grepDefaultPath = 'c:/PROGRA~1/GnuWin32/bin/' if ($^O eq 'MSWin32');

# **COMMAND EXPERT**
# Full path to GNU-compatible egrep program. This is used for searching when
# {SearchAlgorithm} is 'Foswiki::Store::SearchAlgorithms::Forking'.
# %CS{|-i}% will be expanded
# to -i for case-sensitive search or to the empty string otherwise.
# Similarly for %DET, which controls whether matching lines are required.
# (see the documentation on these options with GNU grep for details).
$Foswiki::cfg{Store}{EgrepCmd} = $grepDefaultPath.'grep -E %CS{|-i}% %DET{|-l}% -H -- %TOKEN|U% %FILES|F%';

# **COMMAND EXPERT**
# Full path to GNU-compatible fgrep program. This is used for searching when
# {SearchAlgorithm} is 'Foswiki::Store::SearchAlgorithms::Forking'.
$Foswiki::cfg{Store}{FgrepCmd} = $grepDefaultPath.'grep -F %CS{|-i}% %DET{|-l}% -H -- %TOKEN|U% %FILES|F%';

# **SELECTCLASS Foswiki::Store::QueryAlgorithms::***
# This is the algorithm used to perform query searches. The default Foswiki
# algorithm (BruteForce) works well, but is not particularly fast (it is
# based on plain-text searching). You may be able to select a different
# algorithm here, depending on what alternative implementations have been
# installed.
$Foswiki::cfg{Store}{QueryAlgorithm} = 'Foswiki::Store::QueryAlgorithms::BruteForce';

# **SELECTCLASS Foswiki::Prefs::*RAM* EXPERT**
# The algorithm used to store preferences. The default algorithm reads
# topics each time to access preferences. A caching algorithm that uses
# BerkeleyDB is also available from the PrefsCachePlugin. This algorithm
# is faster, but requires BerkeleyDB to be installed.
$Foswiki::cfg{Store}{PrefsBackend} = 'Foswiki::Prefs::TopicRAM';

# **PERL EXPERT**
# Hash of full class names of objects that want to listen to changes to
# the store. The Key is the Class name, and the value is an integer, used
# to define the execution order (low values are executed first). For example,
# <tt>{ 'Foswiki::Contrib::DBIStoreContrib::Listener' => 100,
# 'Foswiki::Plugins::MongoDBPlugin::Listener' => 200 }</tt>.
$Foswiki::cfg{Store}{Listeners} = {};

# **BOOLEAN EXPERT**
# Some systems will override the default umask to a highly restricted setting,
# which will block the application of the file and directory permissions.
# If mod_suexec is enabled, the Apache umask directive will also be ignored.
# Enable this setting if the checker reports that the umask is in conflict with
# the permissions, or adust the expert settings {RCS}{dirPermission} and 
# {RCS}{filePermission} to be consistent with the system umask.
$Foswiki::cfg{RCS}{overrideUmask}= $FALSE;

# **OCTAL EXPERT**
# File security for new directories created by RCS stores. You may have
# to adjust these
# permissions to allow (or deny) users other than the webserver user access
# to directories that Foswiki creates. This is an <strong>octal</strong> number
# representing the standard UNIX permissions (e.g. 755 == rwxr-xr-x)
$Foswiki::cfg{RCS}{dirPermission}= 0755;

# **OCTAL EXPERT**
# File security for new files created by RCS stores. You may have to adjust these
# permissions to allow (or deny) users other than the webserver user access
# to files that Foswiki creates.  This is an <strong>octal</strong> number
# representing the standard UNIX permissions (e.g. 644 == rw-r--r--)
$Foswiki::cfg{RCS}{filePermission}= 0644;

# **BOOLEAN EXPERT**
# Some file-based Store implementations (RcsWrap and RcsLite) store
# attachment meta-data separately from the actual attachments.
# This means that it is possible to have a file in an attachment directory
# that is not seen as an attachment by Foswiki. Sometimes it is desirable to
# be able to simply copy files into a directory and have them appear as
# attachments, and that's what this feature allows you to do.
# Considered experimental.
$Foswiki::cfg{RCS}{AutoAttachPubFiles} = $FALSE;

# **STRING 20 EXPERT**
# Specifies the extension to use on RCS files. Set to -x,v on windows, leave
# blank on other platforms.
$Foswiki::cfg{RCS}{ExtOption} = "";

# **REGEX EXPERT**
# Perl regular expression matching suffixes valid on plain text files
# Defines which attachments will be treated as ASCII in RCS. This is a
# filter <b>in</b>, so any filenames that match this expression will
# be treated as ASCII.
$Foswiki::cfg{RCS}{asciiFileSuffixes} = qr/\.(txt|html|xml|pl)$/;

# **BOOLEAN EXPERT**
# Set this if your RCS cannot check out using the -p option.
# May be needed in some windows installations (not required for cygwin)
$Foswiki::cfg{RCS}{coMustCopy} = $FALSE;

# **COMMAND EXPERT**
# RcsWrap initialise a file as binary.
# %FILENAME|F% will be expanded to the filename.
$Foswiki::cfg{RCS}{initBinaryCmd} = "/usr/bin/rcs $Foswiki::cfg{RCS}{ExtOption} -i -t-none -kb %FILENAME|F%";
# **COMMAND EXPERT**
# RcsWrap initialise a topic file.
$Foswiki::cfg{RCS}{initTextCmd} = "/usr/bin/rcs $Foswiki::cfg{RCS}{ExtOption} -i -t-none -ko %FILENAME|F%";
# **COMMAND EXPERT**
# RcsWrap uses this on Windows to create temporary binary files during upload.
$Foswiki::cfg{RCS}{tmpBinaryCmd}  = "/usr/bin/rcs $Foswiki::cfg{RCS}{ExtOption} -kb %FILENAME|F%";
# **COMMAND EXPERT**
# RcsWrap check-in.
# %USERNAME|S% will be expanded to the username.
# %COMMENT|U% will be expanded to the comment.
$Foswiki::cfg{RCS}{ciCmd} =
    "/usr/bin/ci $Foswiki::cfg{RCS}{ExtOption} -m%COMMENT|U% -t-none -w%USERNAME|S% -u %FILENAME|F%";
# **COMMAND EXPERT**
# RcsWrap check in, forcing the date.
# %DATE|D% will be expanded to the date.
$Foswiki::cfg{RCS}{ciDateCmd} =
    "/usr/bin/ci $Foswiki::cfg{RCS}{ExtOption} -m%COMMENT|U% -t-none -d%DATE|D% -u -w%USERNAME|S% %FILENAME|F%";
# **COMMAND EXPERT**
# RcsWrap check out.
# %REVISION|N% will be expanded to the revision number
$Foswiki::cfg{RCS}{coCmd} =
    "/usr/bin/co $Foswiki::cfg{RCS}{ExtOption} -p%REVISION|N% -ko %FILENAME|F%";
# **COMMAND EXPERT**
# RcsWrap file history.
$Foswiki::cfg{RCS}{histCmd} =
    "/usr/bin/rlog $Foswiki::cfg{RCS}{ExtOption} -h %FILENAME|F%";
# **COMMAND EXPERT**
# RcsWrap revision info about the file.
$Foswiki::cfg{RCS}{infoCmd} =
    "/usr/bin/rlog $Foswiki::cfg{RCS}{ExtOption} -r%REVISION|N% %FILENAME|F%";
# **COMMAND EXPERT**
# RcsWrap revision info about the revision that existed at a given date.
# %REVISIONn|N% will be expanded to the revision number.
# %CONTEXT|N% will be expanded to the number of lines of context.
$Foswiki::cfg{RCS}{rlogDateCmd} =
    "/usr/bin/rlog $Foswiki::cfg{RCS}{ExtOption} -d%DATE|D% %FILENAME|F%";
# **COMMAND EXPERT**
# RcsWrap differences between two revisions.
$Foswiki::cfg{RCS}{diffCmd} =
    "/usr/bin/rcsdiff $Foswiki::cfg{RCS}{ExtOption} -q -w -B -r%REVISION1|N% -r%REVISION2|N% -ko --unified=%CONTEXT|N% %FILENAME|F%";
# **COMMAND EXPERT**
# RcsWrap lock a file.
$Foswiki::cfg{RCS}{lockCmd} =
    "/usr/bin/rcs $Foswiki::cfg{RCS}{ExtOption} -l %FILENAME|F%";
# **COMMAND EXPERT**
# RcsWrap unlock a file.
$Foswiki::cfg{RCS}{unlockCmd} =
    "/usr/bin/rcs $Foswiki::cfg{RCS}{ExtOption} -u %FILENAME|F%";
# **COMMAND EXPERT**
# RcsWrap break a file lock.
$Foswiki::cfg{RCS}{breaklockCmd} =
    "/usr/bin/rcs $Foswiki::cfg{RCS}{ExtOption} -u -M %FILENAME|F%";
# **COMMAND EXPERT**
# RcsWrap delete a specific revision.
$Foswiki::cfg{RCS}{delRevCmd} =
    "/usr/bin/rcs $Foswiki::cfg{RCS}{ExtOption} -o%REVISION|N% %FILENAME|F%";

#---+ Tuning

#---++ HTTP Compression
# <p>Expert settings controlling compression of the generated HTML.</p>
# **BOOLEAN EXPERT**
# Enable gzip/deflate page compression. Modern browsers can uncompress content
# encoded using gzip compression. You will save a lot of bandwidth by compressing
# pages. This makes most sense when enabling page caching as well as these are
# stored in compressed format by default when {HttpCompress} is enabled.
# Note that only pages without any 'dirty areas' will be compressed. Any other page
# will be transmitted uncompressed.
$Foswiki::cfg{HttpCompress} = $FALSE;

#---++ HTML Page Layout
# <p>Expert setting controlling the layout of the generated HTML.</p>
# **BOOLEAN EXPERT**
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

# **STRING 80 EXPERT**
# List of those topics that have a manual dependency on every topic
# in a web. Web dependencies can also be specified using the WEBDEPENDENCIES
# preference, which overrides this setting.
$Foswiki::cfg{Cache}{WebDependencies} = 'WebRss, WebAtom, WebTopicList, WebIndex, WebSearch, WebSearchAdvanced';

# **REGEX EXPERT**
# Exclude topics that match this regular expression from the dependency
# tracker.
$Foswiki::cfg{Cache}{DependencyFilter} = '$Foswiki::cfg{SystemWebName}\..*|$Foswiki::cfg{TrashWebName}\..*|.*Template$|TWiki\..*';

# **SELECTCLASS Foswiki::Cache::* EXPERT**
# Select the default caching mechanism. Note that individual subsystems might
# choose a different backend for their own purposes.
$Foswiki::cfg{CacheManager} = 'Foswiki::Cache::FileCache';

# **SELECT Foswiki::Cache::DB_File,Foswiki::Cache::BDB EXPERT**
# Select the database backend use to store meta data for the page cache.
$Foswiki::cfg{MetaCacheManager} = 'Foswiki::Cache::DB_File';

# **PATH EXPERT**
# Specify the root directory for CacheManagers that use file-system based
# storage. This is where the database files will be stored.
$Foswiki::cfg{Cache}{RootDir} = '$Foswiki::cfg{WorkingDir}/tmp/cache';

# **STRING 30 EXPERT**
# Specify the database file for the <code>Foswiki::Cache::DB_File</code>
# CacheManager
$Foswiki::cfg{Cache}{DBFile} = '$Foswiki::cfg{WorkingDir}/tmp/foswiki_db';

# **STRING EXPERT**
# Specify the namespace used by this site in a store shared with other systems.
$Foswiki::cfg{Cache}{NameSpace} = '$Foswiki::cfg{DefaultUrlHost}';

# **NUMBER EXPERT**
# Specify the maximum number of cache entries for size-aware CacheManagers like
# <code>MemoryLRU</code>. This won't have any effect on other CacheManagers.
$Foswiki::cfg{Cache}{MaxSize} = 1000;

# **STRING 30 EXPERT**
# Specify a comma separated list of servers for distributed CacheManagers like
# <code>Memcached</code>. This setting won't have any effect on other CacheManagers.
$Foswiki::cfg{Cache}{Servers} = '127.0.0.1:11211';

#---+ Mail and Proxies -- TABS
# <p>Settings controlling if and how Foswiki sends email, and the proxies used
# to access external web pages.</p>

#---++ Email General
# <p>Settings controlling if and how Foswiki sends email including the identity of the sender
# and other expert settings controlling the email process.</p>
# **BOOLEAN**
# Enable email globally.  Un-check this option to disable all outgoing
# email from Foswiki
$Foswiki::cfg{EnableEmail} = $TRUE;

# **STRING 30**
# Wiki administrator's e-mail address e.g. <code>webmaster@example.com</code>
# (used in <code>%WIKIWEBMASTER%</code>)
# NOTE: must be a single valid email address
$Foswiki::cfg{WebMasterEmail} = '';

# **STRING 30**
# Wiki administrator's name address, for use in mails (first name and
# last name, e.g. <tt>Fred Smith</tt>) (used in %WIKIWEBMASTERNAME%)
$Foswiki::cfg{WebMasterName} = 'Wiki Administrator';

# **BOOLEAN EXPERT**
# Remove IMG tags in notification mails.
$Foswiki::cfg{RemoveImgInMailnotify} = $TRUE;

# **STRING 20 EXPERT**
# Name of topic in each web that has notification registrations.
# <b>If you change this setting you will have to
# use Foswiki to manually rename the topic in all existing webs</b>
$Foswiki::cfg{NotifyTopicName}     = 'WebNotify';

# **BOOLEAN EXPERT**
# Send email Date header using local "server time" instead of GMT
$Foswiki::cfg{Email}{Servertime} = $FALSE;

#---++ Email Server
# <p>Settings to select the destination mail server or local email agent used for forwarding email.</p>

# **SELECT Net::SMTP,Net::SMTP::SSL,MailProgram **
# Select the method Foswiki will use for sending email.  On Unix/Linux hosts
# "MailProgram" is generally acceptable.  Otherwise choose one of the Email
# methods required by your ISP or Email server.
# <ul><li><code>Net::SMTP</code> sends in cleartext.
# <li><code>Net::SMTP::SSL</code> sends using a secure encrypted connection.
# </ul>Both of the above methods will perform authentication if a Username and
# password are provided below.
# <ul><li><code>MailProgram</code> uses the program configured below to send email.
# Authentication and encryption is done externally to Foswiki and the remainder of
# the below fields are not used.
#$Foswiki::cfg{Email}{MailMethod} = 'Net::SMTP';

# **COMMAND**
# This needs to be a command-line program that accepts
# MIME format mail messages on standard input, and mails them.
$Foswiki::cfg{MailProgram} = '/usr/sbin/sendmail -t -oi -oeq';

# **BOOLEAN EXPERT**
# Set this option on to enable debug
# mode in SMTP. Output will go to the webserver error log.
$Foswiki::cfg{SMTP}{Debug} = 0;

# **STRING 30**
# Mail host for outgoing mail. This is only used if Net::SMTP is installed.
# Examples: <tt>mail.your.company</tt> If the smtp server uses a different port
# than the default 25 # use the syntax <tt>mail.your.company:portnumber</tt>
# <p><b>CAUTION</b> This setting can be overridden by a setting of SMTPMAILHOST
# in SitePreferences. Make sure you delete that setting if you are using a
# SitePreferences topic from a previous release of Foswiki.</p>
# <p>For Gmail, set MailMethod to Net::SMTP::SSL, set MAILHOST to <tt>smtp.gmail.com:465</tt>
# and provide your gmail email address and password below for authentication.</p>
$Foswiki::cfg{SMTP}{MAILHOST} = '';

# **STRING 30**
# Mail domain sending mail, required if you are using <tt>Net::SMTP</tt>. SMTP
# requires that you identify the server sending mail. If not set,
# <tt>Net::SMTP</tt> will guess it for you. Example: foswiki.your.company.
# <b>CAUTION</b> This setting can be overridden by a setting of %SMTPSENDERHOST%
# in SitePreferences. Make sure you delete that setting.
$Foswiki::cfg{SMTP}{SENDERHOST} = '';

# **STRING 30**
# Username for SMTP. Only required if your server requires authentication. If
# this is left blank, Foswiki will not attempt to authenticate the mail sender.
$Foswiki::cfg{SMTP}{Username} = '';

# **PASSWORD 30**
# Password for your {SMTP}{Username}.
$Foswiki::cfg{SMTP}{Password} = '';


#---++ S/MIME
# <p>Configure signing of outgoing email. (Secure/Multipurpose Internet Mail Extensions)
# is a standard for public key encryption and signing of MIME encoded email messages.
# Messages generated by the server will be signed using an X.509 certificate.</p>

# **BOOLEAN**
# Enable S/MIME signing.
$Foswiki::cfg{Email}{EnableSMIME} = $FALSE;

# **PATH**
# Secure email certificate.  If you want e-mail sent by Foswiki to be signed,
# specify the filename of the administrator's X.509 certificate here.  It
# must be in PEM format.
$Foswiki::cfg{Email}{SmimeCertificateFile} = '$Foswiki::cfg{DataDir}/cert.pem';

# **PATH**
# Secure email certificate.  If you want e-mail sent by Foswiki to be signed,
# specify the filename of the administrator's X.509 private key here.  It
# must be in PEM format.  <em>Be sure that this file is only readable by the
# Foswiki software; it must NOT be readable by users!</em>
$Foswiki::cfg{Email}{SmimeKeyFile} = '$Foswiki::cfg{DataDir}/key.pem';

#---++ Proxy
# Some environments require outbound HTTP traffic to go through a proxy
# server. (e.g. http://proxy.your.company).
# **STRING 30**
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

#---++ Email Test
# <p> This section provides a test facility to verify your configuration before
# enabling email or testing user registration.

# *TESTEMAIL* Marker used by bin/configure script - do not remove!


#---+ Miscellaneous -- EXPERT
# <p>Miscellaneous expert options.</p>

# **STRING 20 EXPERT**
# Name of the web where documentation and default preferences are held. If you
# change this setting, you must make sure the web exists and contains
# appropriate content, and upgrade scripts may no longer work (i.e. don't
# change it unless you are certain that you know what you are doing!)
$Foswiki::cfg{SystemWebName} = 'System';

# **STRING 20 EXPERT**
# Name of the web used as a trashcan (where deleted topics are moved)
# If you change this setting, you must make sure the web exists.
$Foswiki::cfg{TrashWebName} = 'Trash';

# **STRING 20 EXPERT**
# Name of the web used as a scratchpad or temporary workarea for users to
# experiment with Foswiki topics.
$Foswiki::cfg{SandboxWebName} = 'Sandbox';

# **STRING 20 EXPERT**
# Name of site-level preferences topic in the {SystemWebName} web.
# <b>If you change this setting you will have to
# use Foswiki and *manually* rename the existing topic.</b>
# (i.e. don't change it unless you are <b>certain</b> that you know what
# you are doing!)
$Foswiki::cfg{SitePrefsTopicName} = 'DefaultPreferences';

# **STRING 70 EXPERT**
# Web.TopicName of the site-level local preferences topic. If this topic
# exists, any settings in it will <b>override</b> settings in
# {SitePrefsTopicName}.<br />
# You are <b>strongly</b> recommended to keep all your local changes in
# a {LocalSitePreferences} topic rather than changing DefaultPreferences,
# as it will make upgrading a lot easier.
$Foswiki::cfg{LocalSitePreferences} = '$Foswiki::cfg{UsersWebName}.SitePreferences';

# **STRING 20 EXPERT**
# Name of main topic in a web.
# <b>If you change this setting you will have to
# use Foswiki to manually rename the topic in all existing webs</b>
# (i.e. don't change it unless you are <b>certain</b> that you know what
# you are doing!)
$Foswiki::cfg{HomeTopicName} = 'WebHome';

# **STRING 20 EXPERT**
# Name of preferences topic in a web.
# <b>If you change this setting you will have to
# use Foswiki to manually rename the topic in all existing webs</b>
# (i.e. don't change it unless you are <b>certain</b> that you know what
# you are doing!)
$Foswiki::cfg{WebPrefsTopicName} = 'WebPreferences';

# **STRING 20 EXPERT**
# Name of the web where usertopics are stored. If you
# change this setting, you must make sure the web exists and contains
# appropriate content, and upgrade scripts may no longer work
# (i.e. don't change it unless you are <b>certain</b> that you know what
# you are doing!)
$Foswiki::cfg{UsersWebName} = 'Main';

# **STRING 70x10 EXPERT**
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
$Foswiki::cfg{TemplatePath} = '$Foswiki::cfg{TemplateDir}/$web/$name.$skin.tmpl, $Foswiki::cfg{TemplateDir}/$name.$skin.tmpl, $web.$skinSkin$nameTemplate, $Foswiki::cfg{SystemWebName}.$skinSkin$nameTemplate, $Foswiki::cfg{TemplateDir}/$web/$name.tmpl, $Foswiki::cfg{TemplateDir}/$name.tmpl, $web.$nameTemplate, $Foswiki::cfg{SystemWebName}.$nameTemplate';

# **STRING 120 EXPERT**
# List of protocols (URI schemes) that Foswiki will
# automatically recognize in absolute links.
# Add any extra protocols specific to your environment (for example, you might
# add 'imap' or 'pop' if you are using shared mailboxes accessible through
# your browser, or 'tel' if you have a softphone setup that supports links
# using this URI scheme). A list of popular URI schemes can be
# found at <a href="http://en.wikipedia.org/wiki/URI_scheme">http://en.wikipedia.org/wiki/URI_scheme</a>.
$Foswiki::cfg{LinkProtocolPattern} = '(file|ftp|gopher|https|http|irc|mailto|news|nntp|telnet)';

# **BOOLEAN EXPERT**
# 'Anchors' are positions within a Foswiki page that can be targeted in
# a URL using the <tt>#anchor</tt> syntax. The format of these anchors has
# changed several times. If this option is set, Foswiki will generate extra
# redundant anchors that are compatible with the old formats. If it is not
# set, the links will still work but will go to the head of the target page.
# There is a small performance cost for enabling this option. Set it if
# your site has been around for a long time, and you want existing external
# links to the internals of pages to continue to work.
$Foswiki::cfg{RequireCompatibleAnchors} = 0;

# **NUMBER EXPERT**
# How many links to other revisions to show in the bottom bar. 0 for all
$Foswiki::cfg{NumberOfRevisions} = 4;

# **NUMBER EXPERT**
# Set the upper limit of the maximum number of difference that will be
# displayed when viewing the entire history of a page. The compared revisions
# will be evenly spaced across the history of the page e.g. if the page has
# 100 revisions and we have set this option to 10, we will see differences
# between r100 and r90, r90 and r80, r80 and r70 and so on.
$Foswiki::cfg{MaxRevisionsInADiff} = 25;

# **NUMBER EXPERT**
# If this is set to a > 0 value, and the revision control system
# supports it (RCS does), then if a second edit of the same topic
# is done by the same user within this number of seconds, a new
# revision of the topic will NOT be created (the top revision will
# be replaced). Set this to 0 if you want <b>all</b> topic changes to create
# a new revision (as required by most formal development processes).
$Foswiki::cfg{ReplaceIfEditedAgainWithin} = 3600;

# **NUMBER EXPERT**
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

# **NUMBER EXPERT**
# Even if the other users' lease has expired, then you can specify that
# they should still get a (less forceful) warning about the old lease for
# some additional time after the lease expired. You can set this to 0 to
# suppress these extra warnings completely, or to -1 so they are always
# issued, or to a number of seconds since the old lease expired.
$Foswiki::cfg{LeaseLengthLessForceful} = 3600;

# **PATH EXPERT**
# Pathname to file that maps file suffixes to MIME types :
# For Apache server set this to Apache's mime.types file pathname,
# for example /etc/httpd/mime.types, or use the default shipped in
# the Foswiki data directory.
$Foswiki::cfg{MimeTypesFileName} = '$Foswiki::cfg{DataDir}/mime.types';

# **BOOLEAN EXPERT**
# If set, this will cause Foswiki to treat warnings as errors that will
# cause Foswiki to die. Provided for use by Plugin and Skin developers,
# who should develop with it switched on.
$Foswiki::cfg{WarningsAreErrors} = $FALSE;

#---+ Extensions -- TABS

#---++ Install and update extensions
# <p>Consult online extensions repositories for new extensions, or check and manage updates.</p>
#
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
# twiki.org=(http://twiki.org/cgi-bin/view/Plugins/,http://twiki.org/p/pub/Plugins/); foswiki.org=(http://foswiki.org/Extensions/,http://foswiki.org/pub/Extensions/);</code><p />
# For Extensions with the same name in more than one repository, the <strong>last</strong> matching repository in the list will be chosen, so Foswiki.org should always be last in the list for maximum compatibility.
$Foswiki::cfg{ExtensionsRepositories} = 'Foswiki.org=(http://foswiki.org/Extensions/,http://foswiki.org/pub/Extensions/)';

# *FINDEXTENSIONS* Marker used by bin/configure script - do not remove!


#---++ Enabled plugins
# *PLUGINS* Marker used by bin/configure script - do not remove!
# <p>The plugins listed below were discovered by searching the <code>@INC</code>
# path for modules that match the Foswiki standard e.g.
# <code>Foswiki/Plugins/MyPlugin.pm</code> or the TWiki standard i.e.
# <code>TWiki/Plugins/YourPlugin.pm</code></p>
# <p>Any plugins enabled in the configuration but not found in the <code>@INC</code>
# path are listed at the end and are flagged as errors in the PluginsOrder check.</p>
# **STRING 80**
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

$Foswiki::cfg{Plugins}{PreferencesPlugin}{Enabled} = 1;
$Foswiki::cfg{Plugins}{PreferencesPlugin}{Module} = 'Foswiki::Plugins::PreferencesPlugin';
$Foswiki::cfg{Plugins}{SmiliesPlugin}{Enabled} = 1;
$Foswiki::cfg{Plugins}{SmiliesPlugin}{Module} = 'Foswiki::Plugins::SmiliesPlugin';
$Foswiki::cfg{Plugins}{CommentPlugin}{Enabled} = 1;
$Foswiki::cfg{Plugins}{CommentPlugin}{Module} = 'Foswiki::Plugins::CommentPlugin';
$Foswiki::cfg{Plugins}{SpreadSheetPlugin}{Enabled} = 1;
$Foswiki::cfg{Plugins}{SpreadSheetPlugin}{Module} = 'Foswiki::Plugins::SpreadSheetPlugin';
$Foswiki::cfg{Plugins}{InterwikiPlugin}{Enabled} = 1;
$Foswiki::cfg{Plugins}{InterwikiPlugin}{Module} = 'Foswiki::Plugins::InterwikiPlugin';
$Foswiki::cfg{Plugins}{TablePlugin}{Enabled} = 1;
$Foswiki::cfg{Plugins}{TablePlugin}{Module} = 'Foswiki::Plugins::TablePlugin';
$Foswiki::cfg{Plugins}{EditTablePlugin}{Enabled} = 1;
$Foswiki::cfg{Plugins}{EditTablePlugin}{Module} = 'Foswiki::Plugins::EditTablePlugin';
$Foswiki::cfg{Plugins}{SlideShowPlugin}{Enabled} = 1;
$Foswiki::cfg{Plugins}{SlideShowPlugin}{Module} = 'Foswiki::Plugins::SlideShowPlugin';
$Foswiki::cfg{Plugins}{TwistyPlugin}{Enabled} = 1;
$Foswiki::cfg{Plugins}{TwistyPlugin}{Module} = 'Foswiki::Plugins::TwistyPlugin';
$Foswiki::cfg{Plugins}{TinyMCEPlugin}{Enabled} = 1;
$Foswiki::cfg{Plugins}{TinyMCEPlugin}{Module} = 'Foswiki::Plugins::TinyMCEPlugin';
$Foswiki::cfg{Plugins}{WysiwygPlugin}{Enabled} = 1;
$Foswiki::cfg{Plugins}{WysiwygPlugin}{Module} = 'Foswiki::Plugins::WysiwygPlugin';
$Foswiki::cfg{Plugins}{TWikiCompatibilityPlugin}{Enabled} = 0;
$Foswiki::cfg{Plugins}{TWikiCompatibilityPlugin}{Module} = 'Foswiki::Plugins::TWikiCompatibilityPlugin';
$Foswiki::cfg{Plugins}{AutoViewTemplatePlugin}{Enabled} = 1;
$Foswiki::cfg{Plugins}{AutoViewTemplatePlugin}{Module} = 'Foswiki::Plugins::AutoViewTemplatePlugin';
$Foswiki::cfg{Plugins}{CompareRevisionsAddonPlugin}{Enabled} = 1;
$Foswiki::cfg{Plugins}{CompareRevisionsAddonPlugin}{Module} = 'Foswiki::Plugins::CompareRevisionsAddonPlugin';
$Foswiki::cfg{Plugins}{HistoryPlugin}{Enabled} = 1;
$Foswiki::cfg{Plugins}{HistoryPlugin}{Module} = 'Foswiki::Plugins::HistoryPlugin';
$Foswiki::cfg{Plugins}{JQueryPlugin}{Enabled} = 1;
$Foswiki::cfg{Plugins}{JQueryPlugin}{Module} = 'Foswiki::Plugins::JQueryPlugin';
$Foswiki::cfg{Plugins}{RenderListPlugin}{Enabled} = 1;
$Foswiki::cfg{Plugins}{RenderListPlugin}{Module} = 'Foswiki::Plugins::RenderListPlugin';
$Foswiki::cfg{Plugins}{MailerContribPlugin}{Enabled} = 1;
$Foswiki::cfg{Plugins}{MailerContribPlugin}{Module} = 'Foswiki::Plugins::MailerContribPlugin';
$Foswiki::cfg{Plugins}{SubscribePlugin}{Enabled} = 1;
$Foswiki::cfg{Plugins}{SubscribePlugin}{Module} = 'Foswiki::Plugins::SubscribePlugin';

#---++ Plugin settings
#<p>Expert settings controlling extension operation.</p>
# **STRING 80 EXPERT**
# Search path (web names) for plugin topics. Note that the session web
# is searched last, after this list.
$Foswiki::cfg{Plugins}{WebSearchPath} = '$Foswiki::cfg{SystemWebName},TWiki';

1;
__END__
#
# Copyright (C) 2008-2009 Foswiki Contributors. Foswiki Contributors
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
