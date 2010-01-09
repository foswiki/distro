# Configuration file of Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 1999-2007 Peter Thoeny, peter@thoeny.org and TWiki Contributors
# Copyright (C) 2008-2009 Foswiki Contributors.
# All Rights Reserved. TWiki Contributors and Foswiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# As per the GPL, removal of this notice is prohibited.
#
# This configuration file is held in 'foswiki/lib' directory. You can edit
# this file directly to set your configuration, but it's much MUCH better
# to leave this file untouched and create a new file called "LocalSite.cfg"
# That way, there is no risk of your local settings being overwritten when
# you upgrade.
#
# See 'setlib.cfg' in 'bin' directory to configure non-standard location
# for 'lib' directory or Perl modules.
#
# Note that the comments in this file are formatted specifically so
# that the 'configure' script can extract documentation from here.
# You are *strongly* advised not to edit this file!
#
# You can alter the most recent revision of a topic using
# /edit/web/topic?cmd=repRev
#    * use only as a last resort, as history is altered
#    * you must be in AdminGroup
#    * you will be presented with normal edit box, but this will also
#      include meta information, modify this with extreme care
#
# You can delete the most recent revision of a topic using
# /edit/web/topic?cmd=delRev
#    * use only as a last resort, as history is lost
#    * you must be in AdminGroup
#    * fill in some dummy text in the edit box
#    * ignore preview output
#    * when you press save, last revision will be deleted
#
# ======================================================================
# This page is used to set up the configuration options for Foswiki. Certain of
# the settings are required; these are marked with a
# <font color="red">*</font>. Fill in the settings, and then select 'Update'.
# The settings will be updated and you will be returned to this page. Any
# errors in your configuration will be <font color="red">highlighted</font>
# below.
# <p />
# If you are installing Foswiki for the first time, and you are on a
# Unix or Linux platform and behind a firewall, the only section you
# should need to worry about below is "General path settings".
# <p />
# If you are on a public site, you will need to consider carefully
# how you are going to manage authentication and access control.
# <p />
# There are a number of documentation topics describing how to
# configure Foswiki for different platforms, and a lot of support
# available at Foswiki.org. The configuration settings currently in
# use can be managed using the 'configure' script.
#
# If your Foswiki site is working, the front page should be
# <a href="$Foswiki::cfg{ScriptUrlPath}/view$Foswiki::cfg{ScriptSuffix}">right here</a>

# NOTE FOR DEVELOPERS: you can use $Foswiki::cfg variables in other settings,
# but you must be sure they are only evaluated under program control and
# not when this file is loaded. For example:
## $Foswiki::cfg{Blah} = "$Foswiki::cfg{DataDir}/blah.dat"; # BAD
## $Foswiki::cfg{Blah} = '$Foswiki::cfg{DataDir}/blah.dat'; # GOOD

my $OS = $Foswiki::cfg{OS} || '';
# Note that the general path settings are deliberately commented out.
# This is because they *must* be defined in LocalSite.cfg, and *not* here.

#---+ General path settings
# If you are a first-time installer; once you have set up the next
# eight paths below, your Foswiki should work - try it. You can always come
# back and tweak other settings later.<p />
# <b>Security Note:</b> Only the URL paths listed below should
# be browseable from the web. If you expose any other directories (such as
# lib or templates) you are opening up routes for possible hacking attempts.

# **URL M**
#  This is the root of all Foswiki URLs e.g. http://myhost.com:123.
# $Foswiki::cfg{DefaultUrlHost} = 'http://your.domain.com';

# **STRING**
# If your host has aliases (such as both www.foswiki.org and foswiki.org
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

# **PATH M**
# This is the 'cgi-bin' part of URLs used to access the Foswiki bin
# directory e.g. <code>/foswiki/bin</code><br />
# Do <b>not</b> include a trailing /.
# <p />
# See http://foswiki.org/Support.ShorterUrlCookbook for more information on setting up
# Foswiki to use shorter script URLs.
# $Foswiki::cfg{ScriptUrlPath} = '/foswiki/bin';

# **URLPATH M**
# Attachments URL path e.g. /foswiki/pub
# <p /><b>Security Note:</b> files in this directory are *not*
# protected by Foswiki access controls. If you require access controls, you
# will have to use webserver controls (e.g. .htaccess on Apache)
# $Foswiki::cfg{PubUrlPath} = '/foswiki/pub';

# **PATH M**
# Attachments store (file path, not URL), must match /foswiki/pub e.g.
# /usr/local/foswiki/pub
# $Foswiki::cfg{PubDir} = '/home/httpd/foswiki/pub';

# **PATH M**
# Template directory e.g. /usr/local/foswiki/templates
# $Foswiki::cfg{TemplateDir} = '/home/httpd/foswiki/templates';

# **PATH M**
# Topic files store (file path, not URL) e.g. /usr/local/foswiki/data
# $Foswiki::cfg{DataDir} = '/home/httpd/foswiki/data';

# **PATH M**
# Translation files directory (file path, not URL) e.g. /usr/local/foswiki/locale
# $Foswiki::cfg{LocalesDir} = '/home/httpd/foswiki/locale';

# **PATH M**
# Directory where Foswiki stores files that are required for the management
# of Foswiki, but are not normally required to be browsed from the web.
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

# ---+ Security setup

# **STRING H**
# Configuration password (not prompted)
$Foswiki::cfg{Password} = '';

#---++ Paths
# **PATH M**
# Path control. Overrides the default PATH setting to control
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

#---++ Sessions

# **BOOLEAN**
# You can use persistent CGI session tracking even if you are not using login.
# This allows you to have persistent session variables - for example, skins.
# Client sessions are not required for logins to work, but Foswiki will not
# be able to remember logged-in users consistently.
#
# See UserAuthentication for a full discussion of the pros and
# cons of using persistent sessions. Session files are stored in the
# <tt>{WorkingDir}/tmp</tt> directory.
$Foswiki::cfg{UseClientSessions} = 1;

# **STRING 20 EXPERT**
# Set the session timeout, in seconds. The session will be cleared after this
# amount of time without the session being accessed. The default is 6 hours
# (21600 seconds).<p />
# <b>Note</b>By default, session expiry is done "on the fly" by the same
# processes used to
# serve Foswiki requests. As such it imposes a load on the server. When
# there are very large numbers of session files, this load can become
# significant. For best performance, you can set {Sessions}{ExpireAfter}
# to a negative number, which will mean that Foswiki won't try to clean
# up expired sessions using CGI processes. Instead you should use a cron
# job to clean up expired sessions. The standard maintenance cron script
# <tt>tools/tick_foswiki.pl</tt> includes this function.
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

# **SELECT strikeone,embedded,none EXPERT **
# By default Foswiki uses Javascript to perform "double submission" validation
# of browser requests. This technique, called "strikeone", is highly
# recommended for the prevention of cross-site request forgery (CSRF).
# If Javascript is known not to be available in browsers that use the site,
# or cookies are disabled, but you still want validation of submissions,
# then you can fall back on a embedded-key validation technique that
# is less secure, but still offers some protection against CSRF. Both
# validation techniques rely on user verification of "suspicious"
# transactions.
# This option allows you to select which validation technique will be
# used.<br />
# If it is set to "strikeone", or is undefined, 0, or the empty string, then
# double-submission using Javascript will be used.<br />
# If it is set to "embedded", then embedded validation keys will be used.<br/>
# If it is set to "none", then no validation of posted requests will
# be performed.
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
# server. This setting means that if a user edits and saves a page and then go
# back to the edit screen using the browser back button and saves again, the
# user will be met by a warning screen against "Suspicious request from
# browser". Same warning will be displayed if you build an application with
# pages containing multiple forms and the users tries to submit from these
# forms more than once. If this warning screen is a problem for your users you
# can disable this setting which enables reuse of validation keys. This
# however lowers the level of security against cross-site request forgery.
$Foswiki::cfg{Validation}{ExpireKeyOnUse} = 1;

#---++ Authentication
# **SELECTCLASS none,Foswiki::LoginManager::*Login**
# Foswiki supports different ways of responding when the user asks to log
# in (or is asked to log in as the result of an access control fault).
# They are:
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
# Browsers typically remember your login and passwords to make authentication
# more convenient for users. If your Foswiki is used on public terminals, or other
# you can prevent this, forcing the user to enter the login and password every time.
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

# **STRING 100 EXPERT**
# Comma-separated list of scripts in the bin directory that require the user to
# authenticate. Any time an unauthenticated user attempts to access one of these
# scripts, they will be required to authenticate. With TemplateLogin, they are
# redirected to the login script. With ApacheLogin the web server directly asks
# the browser to authenticate without redirecting to a login page and for this
# reason the bin scripts must be configured for authentication in the webserver
# configuration.
$Foswiki::cfg{AuthScripts} = 'attach,edit,manage,rename,save,upload,viewauth,rdiffauth,rest';

# **STRING 80 EXPERT**
# Authentication realm. This is
# normally only used in md5 password encoding. You may need to change it
# if you are sharing a password file with another application.
$Foswiki::cfg{AuthRealm} = 'Enter your $Foswiki::cfg{SystemWebName}.LoginName. (Typically First name and last name, no space, no dots, capitalized, e.g. !JohnSmith, unless you chose otherwise). Visit $Foswiki::cfg{SystemWebName}.UserRegistration if you do not have one.';

#---++ User Mapping
# **SELECTCLASS Foswiki::Users::*UserMapping**
# The user mapping is used to equate login names, used with external
# authentication systems, with Foswiki user identities. By default only
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

#---++ Registration
# **BOOLEAN**
# If you want users to be able to use a login ID other than their
# wikiname, you need to turn this on. It controls whether the 'LoginName'
# box appears during the user registration process, and is used to tell
# the User Mapping module whether to map login names to wikinames or not
# (if it supports mappings, that is).
$Foswiki::cfg{Register}{AllowLoginName} = $FALSE;

# **BOOLEAN EXPERT**
# If a login name (or an internal user id) cannot be mapped to a wikiname,
# then the user is unknown. By default the user will be displayed using
# whatever identity is stored for them. For security reasons you may want
# to obscure this stored id by setting this option to true.
$Foswiki::cfg{RenderLoggedInButUnknownUsers} = $FALSE;

#---++ Passwords
# **SELECTCLASS none,Foswiki::Users::*User**
# Name of the password handler implementation. The password handler manages
# the passwords database, and provides password lookup, and optionally
# password change, services. Foswiki ships with two alternative implementations:
# <ol><li>
# Foswiki::Users::HtPasswdUser - handles 'htpasswd' format files, with
#   passwords encoded as per the HtpasswdEncoding
# </li><li>
# Foswiki::Users::ApacheHtpasswdUser - should behave identically to
# HtpasswdUser, but uses the CPAN:Apache::Htpasswd package to interact
# with Apache. It is shipped mainly as a demonstration of how to write
# a new password manager.
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

# **SELECT crypt,sha1,md5,plain,crypt-md5**
# Password encryption, for the Foswiki::Users::HtPasswdUser password manager.
# You can use the <tt>htpasswd</tt> Apache program to create a new
# password file with the right encoding.
# <dl>
# <dt>crypt</dt><dd>is the default, and should be used on Linux/Unix.</dd>
# <dt>sha1</dt><dd> is recommended for use on Windows.</dd>
# <dt>md5</dt><dd> htdigest format - useful on sites where password files are required
# to be portable. In this case, the {AuthRealm} is used with the username
# and password to generate the encrypted form of the password, thus:
# <tt>user:{AuthRealm}:password</tt>. Take note of this, because it means that
# if the {AuthRealm} changes, any existing MD5 encoded passwords will be
# invalidated by the change!</dd>
# <dt>plain</dt><dd> stores passwords as plain text (no encryption).</dd>
# <dt>crypt-md5</dt><dd>Enable use of standard libc (/etc/shadow) crypt-md5 password (like $1$saltsalt$hashashhashhashhash...$) which are stronger than the crypt paswords, salted, and the salt is stored in the encrypted password string as in normal crypt passwords. </dd>
# </dl>
$Foswiki::cfg{Htpasswd}{Encoding} = 'crypt';

#---++ Miscellaneous

# **STRING 20 EXPERT**
# {OS} and {DetailedOS} are calculated in the Foswiki code. <b>You
# should only need to override if there is something badly wrong with
# those calculations.</b><br />
# {OS} may be one of UNIX WINDOWS VMS DOS MACINTOSH OS2
# $Foswiki::cfg{OS} =
# **STRING 20 EXPERT**
# The value of Perl $OS
# $Foswiki::cfg{DetailedOS} =

# **BOOLEAN EXPERT**
# Remove .. from %INCLUDE{filename}%, to stop includes
# of relative paths.
$Foswiki::cfg{DenyDotDotInclude} = $TRUE;

# **BOOLEAN EXPERT**
#
# Allow %INCLUDE of URLs. This is disabled by default, because it is possible
# to mount a denial-of-service (DoS) attack on a Foswiki site using INCLUDE and
# URLs. Only enable it if you are in an environment where a DoS attack is not
# a high risk.
# <br /> You may also need to configure the proxy settings ({PROXY}{HOST} and
# {PROXY}{PORT}) if your server is behind a firewall and you allow %INCLUDE of
# external webpages.
$Foswiki::cfg{INCLUDE}{AllowURLs} = $FALSE;

# **BOOLEAN EXPERT**
# Allow the use of SCRIPT and LITERAL tags in content. If this is set false,
# all SCRIPT and LITERAL sections will be removed from the body of topics.
# SCRIPT can still be used in the HEAD section, though. Note that this may
# prevent some plugins from functioning correctly.
$Foswiki::cfg{AllowInlineScript} = $TRUE;

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
$Foswiki::cfg{NameFilter} = qr/[\s\*?~^\$@%`"'&;|<>\[\]\x00-\x1f]/;

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
# variables that can be seen using the %ENV{}% Foswiki variable. Set it to
# '^.*$' to allow all environment variables to be seen (not recommended).
$Foswiki::cfg{AccessibleENV} = '^(HTTP_\w+|REMOTE_\w+|SERVER_\w+|REQUEST_\w+|MOD_PERL|FOSWIKI_ACTION)$';

#---+ Anti-spam measures

# Standard Foswiki incorporates some simple anti-spam measures to protect
# e-mail addresses and control the activities of benign robots. These
# should be enough to handle intranet requirements. Administrators of
# public (internet) sites are strongly recommended to install
# <a href="http://foswiki.org/Extensions/AntiWikiSpamPlugin">
# AntiWikiSpamPlugin </a>

# **STRING 50**
# Text added to email addresses to prevent spambots from grabbing
# addresses e.g. set to 'NOSPAM' to get fred@user.co.ru
# rendered as fred@user.co.NOSPAM.ru
$Foswiki::cfg{AntiSpam}{EmailPadding} = '';

# **BOOLEAN**
# Normally Foswiki stores the user's sensitive information (such as their e-mail
# address) in a database out of public view. It also obfuscates e-mail
# addresses displayed in the browser. This is to help prevent e-mail
# spam and identity fraud.<br />
# If that is not a risk for you (e.g. you are behind a firewall) and you
# are happy for e-mails to be made public to all Foswiki users,
# then you can set this option.<br />
# Note that if this option is set, then the <code>user</code> parameter to
# <code>%USERINFO</code> is ignored.
$Foswiki::cfg{AntiSpam}{HideUserDetails} = $TRUE;

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

#---+ Log files

# **SELECTCLASS none,Foswiki::Logger::* EXPERT **
# Foswiki supports different implementations of log files. It can be
# useful to be able to plug in a database implementation, for example,
# for a large site, or even provide your own custom logger. Select the
# implementation to be used here. Most sites should be OK with the
# PlainFile logger, which automatically rotates the logs every month.
$Foswiki::cfg{Log}{Implementation} = 'Foswiki::Logger::PlainFile';

# **BOOLEAN EXPERT**
# Whether or not to to log different actions in the Access log
# (in order of how frequently they occur in a typical installation).
# Information in the Access log is used in gathering web statistics,
# and is useful as an audit trail of Foswiki activity.
$Foswiki::cfg{Log}{view}     = $TRUE; # very frequent, every page view
# **BOOLEAN EXPERT**
$Foswiki::cfg{Log}{search}   = $TRUE;
# **BOOLEAN EXPERT**
$Foswiki::cfg{Log}{changes}  = $TRUE; # infrequent if you use WebChanges
# **BOOLEAN EXPERT**
$Foswiki::cfg{Log}{rdiff}    = $TRUE; # whenever revisions are differenced
# **BOOLEAN EXPERT**
$Foswiki::cfg{Log}{edit}     = $TRUE; # fairly frequent, every time a page is edited
# **BOOLEAN EXPERT**
$Foswiki::cfg{Log}{save}     = $TRUE;
# **BOOLEAN EXPERT**
$Foswiki::cfg{Log}{upload}   = $TRUE; # whenever a new attachment is created
# **BOOLEAN EXPERT**
$Foswiki::cfg{Log}{attach}   = $TRUE;
# **BOOLEAN EXPERT**
$Foswiki::cfg{Log}{rename}   = $TRUE; # when a topic or attachment is renamed
# **BOOLEAN EXPERT**
$Foswiki::cfg{Log}{register} = $TRUE; # rare, when a new user registers

# Names of the various log files. You can use %DATE% (which gets expanded
# to YYYYMM e.g. 200501) in the pathnames to cause the file to be renewed
# every month e.g. /var/log/Foswiki/log.%DATE%.
# It defaults to the data dir

# **PATH**
# File for configuration messages generated by the configure script.
# (usually very very low volume).
$Foswiki::cfg{ConfigurationLogName} = '$Foswiki::cfg{DataDir}/configurationlog.txt';

# **PATH**
# Log file for debug messages when using the PlainFile logger (the default).
# Usually very low volume. %DATE% gets expanded
# to YYYYMM (year, month), allowing you to rotate logs.
$Foswiki::cfg{DebugFileName} = '$Foswiki::cfg{DataDir}/debug.txt';

# **PATH**
# Log file for Warnings when using the PlainFile logger (the default).
# Low volume, hopefully! %DATE% gets expanded
# to YYYYMM (year, month), allowing you to rotate logs.
$Foswiki::cfg{WarningFileName} = '$Foswiki::cfg{DataDir}/warn%DATE%.txt';

# **PATH**
# Log file for logging script runs when using the PlainFile logger (the
# default). High volume. %DATE% gets expanded to YYYYMM (year, month),
# allowing you to rotate logs. You can control what script runs are logged
# using EXPERT options.
$Foswiki::cfg{LogFileName} = '$Foswiki::cfg{DataDir}/log%DATE%.txt';

#---+ Localisation

# <p>
# Configuration items in this section control two things: recognition of
# national (non-ascii) characters and the system locale used by Foswiki, which
# influences how programs Foswiki and external programa called by it behave
# regarding internationalization.
# </p>
# <p>
# <b>Note:</b> for user interface internationalization, the only settings that
# matter are {UserInterfaceInternationalisation}, which enables user interface
# internationalisation, and {Site}{CharSet}, which controls which charset Foswiki
# will use for storing topics and displaying content for the users. As soon as
# {UserInterfaceInternationalisation} is set and the required
# (<code>Locale::Maketext::Lexicon</code> and <code>Encode</code>/MapUTF8 Perl
# modules) are installed (see the <em>CGI Setup</em> section above), the
# multi-language user interface will <em>just</em> work.
# </p>

# **BOOLEAN**
# Enable user interface internationalisation, i.e. presenting the user
# interface in the users own language.
# <p />
# Under {UserInterfaceInternationalisation}, check every language that you want
# your site to support. This setting is only used when
# {UserInterfaceInternationalisation} is enabled. If you disable all languages,
# internationalisation will also be disabled, even if
# {UserInterfaceInternationalisation} is enabled: internationalisation support
# for no languages doesn't make any sense.
# <p />
# Allowing all languages is the best for <em>really</em> international sites.
# But for best performance you should enable only the languages you really
# need. English is the default language, and is always enabled.
# <p />
# {LocalesDir} is used to find the languages supported in your installation,
# so if the list below is empty, it's probably because {LocalesDir} is pointing
# to the wrong place.
$Foswiki::cfg{UserInterfaceInternationalisation} = $FALSE;

# *LANGUAGES* Marker used by bin/configure script - do not remove!
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
$Foswiki::cfg{Languages}{'zh-cn'}{Enabled} = 1;
$Foswiki::cfg{Languages}{'zh-tw'}{Enabled} = 1;

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

# **BOOLEAN**
# Locale - set to enable operating system level locales and
# internationalisation support for 8-bit character sets
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

# **STRING 50 **
# Set this to match your chosen {Site}{Locale} (from 'locale -a')
# whose character set is not supported by your available perl conversion module
# (i.e. Encode for Perl 5.8 or higher, or Unicode::MapUTF8 for other Perl
# versions).  For example, if the locale 'ja_JP.eucjp' exists on your system
# but only 'euc-jp' is supported by Unicode::MapUTF8, set this to 'euc-jp'.
# If you don't define it, it will automatically be defaulted to iso-8859-1<br />
# UTF-8 support is still considered experimental. Use the value 'utf-8' to try it.
$Foswiki::cfg{Site}{CharSet} = undef;

# **BOOLEAN EXPERT**
# Change non-existent plural topic name to singular,
# e.g. TestPolicies to TestPolicy. Only works in English.
$Foswiki::cfg{PluralToSingular} = $TRUE;

#---+ Store settings

# **SELECT RcsWrap,RcsLite**
# Default store implementation.
# <ul><li>RcsWrap uses normal RCS executables.</li>
# <li>RcsLite uses a 100% Perl simplified implementation of RCS.
# RcsLite is useful if you don't have, and can't install, RCS - for
# example, on a hosted platform. It will work, and is compatible with
# RCS, but is not quite as fast.</li></ul>
# You can manually add options to LocalSite.cfg to select a
# different store for each web. If $Foswiki::cfg{Store}{Fred} is defined, it will
# be taken as the name of a perl class (which must implement the methods of
# Foswiki::Store::RcsFile).
# The Foswiki::Store::Subversive class is an example implementation using the
# Subversion version control system as a data store.
$Foswiki::cfg{StoreImpl} = 'RcsWrap';

# **STRING 20 EXPERT**
# Specifies the extension to use on RCS files. Set to -x,v on windows, leave
# blank on other platforms.
$Foswiki::cfg{RCS}{ExtOption} = "";

# **OCTAL**
# File security for new directories. You may have to adjust these
# permissions to allow (or deny) users other than the webserver user access
# to directories that Foswiki creates. This is an <b>octal</b> number
# representing the standard UNIX permissions (e.g. 755 == rwxr-xr-x)
$Foswiki::cfg{RCS}{dirPermission}= 0755;

# **OCTAL**
# File security for new files. You may have to adjust these
# permissions to allow (or deny) users other than the webserver user access
# to files that Foswiki creates.  This is an <b>octal</b> number
# representing the standard UNIX permissions (e.g. 644 == rw-r--r--)
$Foswiki::cfg{RCS}{filePermission}= 0644;

# **BOOLEAN EXPERT**
# Some file-based Store implementations (RcsWrap and RcsLite for
# example) store attachment meta-data separately from the actual attachments.
# This means that it is possible to have a file in an attachment directory
# that is not seen as an attachment by Foswiki. Sometimes it is desirable to
# be able to simply copy files into a directory and have them appear as
# attachments, and that's what this feature allows you to do.
# Considered experimental.
$Foswiki::cfg{AutoAttachPubFiles} = $FALSE;

# **NUMBER EXPERT**
# Number of seconds to remember changes for. This doesn't affect revision
# histories, which always remember the date a file change. It only affects
# the number of changes that are cached for fast access by the 'changes' and
# 'statistics' scripts, and for use by extensions such as the change
# notification mailer. It should be no shorter than the interval between runs
# of these scripts.
$Foswiki::cfg{Store}{RememberChangesFor} = 31 * 24 * 60 * 60;

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

# **SELECTCLASS Foswiki::Store::SearchAlgorithms::***
# Foswiki RCS has two built-in search algorithms
# <ol><li> The default 'Forking' algorithm, which forks a subprocess that
# runs a 'grep' command and is recommended for Linux/Unix,
# </li><li> The 'PurePerl' implementation, which is written in Perl and
# usually only used for native Windows installations where forking
# does not work stable because of limitations in length of command line</li></ol>
# On Linux/Unix you will be just fine with the 'Forking' implementation.
# However if you find searches run very slowly, you may want to try a 
# different algorithm, which may work better on your configuration.
# Forking may work OK also on Windows if you keep the directory path to 
# Foswiki very short.
# Note that there is an alternative algorithm available from
# <a href="http://foswiki.org/Extensions/NativeSearchContrib">
# http://foswiki.org/Extensions/NativeSearchContrib </a>, that often
# gives better performance with mod_perl and Speedy CGI.
$Foswiki::cfg{RCS}{SearchAlgorithm} = 'Foswiki::Store::SearchAlgorithms::Forking';

# **SELECTCLASS Foswiki::Store::QueryAlgorithms::* EXPERT**
# The standard Foswiki algorithm for performing queries is not particularly
# fast (it is based on plain-text searching). You may be able to select
# a different algorithm here, depending on what alternative implementations
# may have been installed.
$Foswiki::cfg{RCS}{QueryAlgorithm} = 'Foswiki::Store::QueryAlgorithms::BruteForce';

# **COMMAND EXPERT**
# Full path to GNU-compatible egrep program. This is used for searching when
# {SearchAlgorithm} is 'Foswiki::Store::SearchAlgorithms::Forking'.
# %CS{|-i}% will be expanded
# to -i for case-sensitive search or to the empty string otherwise.
# Similarly for %DET, which controls whether matching lines are required.
# (see the documentation on these options with GNU grep for details).
$Foswiki::cfg{RCS}{EgrepCmd} = '/bin/grep -E %CS{|-i}% %DET{|-l}% -H -- %TOKEN|U% %FILES|F%';

# **COMMAND EXPERT**
# Full path to GNU-compatible fgrep program. This is used for searching when
# {SearchAlgorithm} is 'Foswiki::Store::SearchAlgorithms::Forking'.
$Foswiki::cfg{RCS}{FgrepCmd} = '/bin/grep -F %CS{|-i}% %DET{|-l}% -H -- %TOKEN|U% %FILES|F%';

# **BOOLEAN**
# Set to enable hierarchical webs. Without this setting, Foswiki will only
# allow a single level of webs. If you set this, you can use
# multiple levels, like a directory tree, i.e. webs within webs.
$Foswiki::cfg{EnableHierarchicalWebs} = 1;

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
# Name of the web where usertopics are stored. If you
# change this setting, you must make sure the web exists and contains
# appropriate content, and upgrade scripts may no longer work
# (i.e. don't change it unless you are <b>certain</b> that you know what
# you are doing!)
$Foswiki::cfg{UsersWebName} = 'Main';

#---+ Mail and Proxies
# **BOOLEAN**
# Enable email globally.
$Foswiki::cfg{EnableEmail} = $TRUE;

# **STRING 30**
# Wiki administrator's e-mail address e.g. <code>webmaster@example.com</code>
# (used in <code>%WIKIWEBMASTER%</code>)
# NOTE: must be a single valid email address
$Foswiki::cfg{WebMasterEmail} = '';

# **STRING 30**
# Wiki administrator's name address, for use in mails (first name and
# last name, e.g. =Fred Smith=) (used in %WIKIWEBMASTERNAME%)
$Foswiki::cfg{WebMasterName} = 'Wiki Administrator';

# **COMMAND**
# Mail program. If Net::SMTP is installed, it will be used in preference.
# To force Foswiki to use the {MailProgram}, unset both {SMTP}{MAILHOST}
# below and all SMTPMAILHOST settings in your Foswiki's Preferences topics.
# This needs to be a command-line program that accepts
# MIME format mail messages on standard input, and mails them.
# To disable all outgoing email from Foswiki leave both this field and the
# MAILHOST field below blank.
$Foswiki::cfg{MailProgram} = '/usr/sbin/sendmail -t -oi -oeq';

# **STRING 30**
# Mail host for outgoing mail. This is only used if Net::SMTP is installed.
# Examples: mail.your.company
# <b>CAUTION</b> This setting can be overridden by a setting of SMTPMAILHOST
# in SitePreferences. Make sure you delete that setting if you are using a
# SitePreferences topic from a previous release of Foswiki. To disable all
# outgoing mail from Foswiki leave both this field and the MailProgram field
# above blank. If the smtp server uses a different port than the default 25
# use the syntax mail.your.company:portnumber.
$Foswiki::cfg{SMTP}{MAILHOST} = '';

# **STRING 30**
# Mail domain sending mail, required if you are using Net::SMTP. SMTP
# requires that you identify the server sending mail. If not set,
# Net::SMTP will guess it for you. Example: foswiki.your.company.
# <b>CAUTION</b> This setting can be overridden by a setting of SMTPSENDERHOST
# in SitePreferences. Make sure you delete that setting if you are using a
# SitePreferences topic from a previous release of Foswiki.
$Foswiki::cfg{SMTP}{SENDERHOST} = '';

# **STRING 30**
# Username for SMTP. Only required if your server requires authentication. If
# this is left blank, Foswiki will not attempt to authenticate the mail sender.
$Foswiki::cfg{SMTP}{Username} = '';

# **PASSWORD 30**
# Password for your {SMTP}{Username}.
$Foswiki::cfg{SMTP}{Password} = '';

# **BOOLEAN EXPERT**
# Remove IMG tags in notification mails.
$Foswiki::cfg{RemoveImgInMailnotify} = $TRUE;

# **STRING 20 EXPERT**
# Name of topic in each web that has notification registrations.
# <b>If you change this setting you will have to
# use Foswiki to manually rename the topic in all existing webs</b>
$Foswiki::cfg{NotifyTopicName}     = 'WebNotify';

# **BOOLEAN EXPERT**
# Set this option on to enable debug
# mode in SMTP. Output will go to the webserver error log.
$Foswiki::cfg{SMTP}{Debug} = 0;

# **STRING 30 EXPERT**
# Some environments require outbound HTTP traffic to go through a proxy
# server. (e.g. http://proxy.your.company).
# <b>CAUTION</b> This setting can be overridden by a PROXYHOST setting
# in SitePreferences. Make sure you delete the setting from there if
# you are using a SitePreferences topic from a previous release of Foswiki.
$Foswiki::cfg{PROXY}{HOST} = '';

# **STRING 30 EXPERT**
# Some environments require outbound HTTP traffic to go through a proxy
# server. Set the port number here (e.g: 8080).
# <b>CAUTION</b> This setting can be overridden by a PROXYPORT setting
# in SitePreferences. Make sure you delete the setting from there if you
# are using a SitePreferences topic from a previous release of Foswiki.
$Foswiki::cfg{PROXY}{PORT} = '';

#---+ Miscellaneous settings

# **NUMBER**
# Number of top viewed topics to show in statistics topic
$Foswiki::cfg{Stats}{TopViews} = 10;

# **NUMBER**
# Number of top contributors to show in statistics topic
$Foswiki::cfg{Stats}{TopContrib} = 10;

# **STRING 20 EXPERT**
# Name of statistics topic
$Foswiki::cfg{Stats}{TopicName} = 'WebStatistics';

# **STRING 120 EXPERT**
# Template path. A comma-separated list of generic file names, containing
# variables standing for part of the file name. When a template $name in $web
# with $skin is requested, this path is instantiated into a sequence of file
# names. The first file on this list that is found considered to be the
# requested template file. The file names can either be absolute file names
# ending in ".tmpl" or a topic file in a Foswiki web.
$Foswiki::cfg{TemplatePath} = '$Foswiki::cfg{TemplateDir}/$web/$name.$skin.tmpl, $Foswiki::cfg{TemplateDir}/$name.$skin.tmpl, $web.$skinSkin$nameTemplate, $Foswiki::cfg{SystemWebName}.$skinSkin$nameTemplate, $Foswiki::cfg{TemplateDir}/$web/$name.tmpl, $Foswiki::cfg{TemplateDir}/$name.tmpl, $web.$nameTemplate, $Foswiki::cfg{SystemWebName}.$nameTemplate';

# **STRING 120 EXPERT**
# List of protocols (URI schemes) that Foswiki will
# automatically recognize and activate if found in absolute links.
# Additions you might find useful in your environment could be 'imap' or 'pop'
# (if you are using shared mailboxes accessible through your browser), or 'tel'
# if you have a softphone setup that supports links using this URI scheme. A list of popular URI schemes can be
# found at <a href="http://en.wikipedia.org/wiki/URI_scheme">http://en.wikipedia.org/wiki/URI_scheme</a>.
$Foswiki::cfg{LinkProtocolPattern} = '(file|ftp|gopher|https|http|irc|mailto|news|nntp|telnet)';

# **STRING 50 EXPERT**
# Set to enable experimental mirror-site support. If this name is
# different to MIRRORSITENAME, then this Foswiki is assumed to be a
# mirror of another. You are <b>highly</b> recommended not
# to dabble with this experimental, undocumented, untested feature!
$Foswiki::cfg{SiteWebTopicName} = '';

# **STRING 20 EXPERT**
# Name of site-level preferences topic in the {SystemWebName} web.
# <b>If you change this setting you will have to
# use Foswiki and *manually* rename the existing topic.</b>
# (i.e. don't change it unless you are <b>certain</b> that you know what
# you are doing!)
$Foswiki::cfg{SitePrefsTopicName} = 'DefaultPreferences';

# **STRING 40 EXPERT**
# Web.TopicName of the site-level local preferences topic. If this topic
# exists, any settings in it will <b>override</b> settings in
# {SitePrefsTopicName}.<br />
# You are <b>strongly</b> recommended to keep all your local changes in
# a {LocalSitePreferences} topic rather than changing DefaultPreferences,
# as it will make upgrading a lot easier.
$Foswiki::cfg{LocalSitePreferences} = 'Main.SitePreferences';

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

# **NUMBER EXPERT**
# How many links to other revisions to show in the bottom bar. 0 for all
$Foswiki::cfg{NumberOfRevisions} = 4;

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

# **PERL H**
# List of operators permitted in structured search queries.
# Each operator is implemented by a class. Not visible in the
# configure UI.
$Foswiki::cfg{Operators}{Query} = [ 'Foswiki::Query::OP_and', 'Foswiki::Query::OP_eq', 'Foswiki::Query::OP_lc', 'Foswiki::Query::OP_lte', 'Foswiki::Query::OP_not', 'Foswiki::Query::OP_ref', 'Foswiki::Query::OP_d2n', 'Foswiki::Query::OP_gte', 'Foswiki::Query::OP_length', 'Foswiki::Query::OP_lt', 'Foswiki::Query::OP_ob', 'Foswiki::Query::OP_uc', 'Foswiki::Query::OP_dot', 'Foswiki::Query::OP_gt', 'Foswiki::Query::OP_like', 'Foswiki::Query::OP_ne', 'Foswiki::Query::OP_or', 'Foswiki::Query::OP_where' ];

# **PERL H**
# List of operators permitted in %IF statements.
# Each operator is implemented by a class. Not visible in the
# configure UI.
$Foswiki::cfg{Operators}{If} = [ 'Foswiki::If::OP_allows', 'Foswiki::If::OP_defined', 'Foswiki::If::OP_isempty','Foswiki::If::OP_ingroup', 'Foswiki::If::OP_isweb', 'Foswiki::If::OP_context', 'Foswiki::If::OP_dollar', 'Foswiki::If::OP_istopic' ];

#---+ Plugins
# *PLUGINS* Marker used by bin/configure script - do not remove!
# The plugins listed below were discovered by searching the @INC path for
# modules that match the Foswiki standard e.g. Foswiki/Plugins/MyPlugin.pm
# or the TWiki standard i.e. TWiki/Plugins/YourPlugin.pm
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
$Foswiki::cfg{Plugins}{TWikiCompatibilityPlugin}{Enabled} = 1;
$Foswiki::cfg{Plugins}{TWikiCompatibilityPlugin}{Module} = 'Foswiki::Plugins::TWikiCompatibilityPlugin';

# **PERL H**
# Search path (web names) for plugin topics. Note that the session web
# is always searched last.
$Foswiki::cfg{Plugins}{WebSearchPath} = '$Foswiki::cfg{SystemWebName},TWiki';

# **STRING 80**
# Plugins evaluation order. If set to a comma-separated list of plugin names,
# will change the execution order of plugins so the listed subset of plugins
# are executed first. The default execution order is alphabetical on plugin
# name.
$Foswiki::cfg{PluginsOrder} = 'TWikiCompatibilityPlugin,SpreadSheetPlugin';

#---+ Extensions
# *FINDEXTENSIONS*
# **STRING 80 EXPERT**
# <b>Extensions Repositories Search List</b><br />
# Foswiki extension repositories are just Foswiki webs that are organised in the
# same way as the Extensions web on Foswiki.org. The 'Find more extensions' link
# above searches these repositories for installable extensions. To set up an
# extensions repository:
# <ol>
# <li>Create a Foswiki web to contain the repository</li>
# <li>Copy the <tt>FastReport</tt> page from <a href="http://foswiki.org/Extensions/FastReport?raw=on">Foswiki:Extensions.FastReport</a> to your new web</li>
# <li> Set the <tt>WEBFORMS</tt> variable in WebPreferences to <tt>PackageForm</tt></li>
# </ol>
# The page for each extension must have the <tt>PackageForm</tt> (copy from Foswiki.org),
# and should have the packaged extension attached as a <tt>zip</tt> and/or
# <tt>tgz</tt> file.
# <p />
# The search list is a semicolon-separated list of repository specifications, each in the format: <i>name=(listurl,puburl)</i>
# where:
# <ul>
# <li><em>name</em> is the symbolic name of the repository e.g. Foswiki.org</li>
# <li><em>listurl</em> is the root of a view URL</li>
# <li><em>puburl</em> is the root of a download URL</li>
# </ul>
# For example,<code>
# twiki.org=(http://twiki.org/cgi-bin/view/Plugins/,http://twiki.org/p/pub/Plugins/);foswiki.org=(http://foswiki.org/Extensions/,http://foswiki.org/pub/Extensions/);</code><p />
# For Extensions with the same name in more than one repository, the <strong>last</strong> matching repository in the list will be chosen, so Foswiki.org should always be last in the list for maximum compatibility.
$Foswiki::cfg{ExtensionsRepositories} = 'Foswiki.org=(http://foswiki.org/Extensions/,http://foswiki.org/pub/Extensions/)';
1;
