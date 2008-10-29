# Configuration file of TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2007 Peter Thoeny, peter@thoeny.org
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
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
# This configuration file is held in 'twiki/lib' directory. You can edit
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
#    * you must be in TWikiAdminGroup
#    * you will be presented with normal edit box, but this will also
#      include meta information, modify this with extreme care
#
# You can delete the most recent revision of a topic using
# /edit/web/topic?cmd=delRev
#    * use only as a last resort, as history is lost
#    * you must be in TWikiAdminGroup
#    * fill in some dummy text in the edit box
#    * ignore preview output
#    * when you press save, last revision will be deleted
#
# ======================================================================
# This page is used to set up the configuration options for TWiki. Certain of
# the settings are required; these are marked with a
# <font color="red">*</font>. Fill in the settings, and then select 'Update'.
# The settings will be updated and you will be returned to this page. Any
# errors in your configuration will be <font color="red">highlighted</font>
# below.
# <p />
# If you are installing TWiki for the first time, and you are on a
# Unix or Linux platform and behind a firewall, the only section you
# should need to worry about below is "General path settings".
# <p />
# If you are on a public site, you will need to consider carefully
# how you are going to manage authentication and access control.
# <p />
# There are a number of documentation topics describing how to
# configure TWiki for different platforms, and a lot of support
# available at TWiki.org. The configuration settings currently in
# use can be managed using the 'configure' script.
#
# If your TWiki site is working, the front page should be
# <a href="$TWiki::cfg{ScriptUrlPath}/view$TWiki::cfg{ScriptSuffix}">right here</a>

# NOTE FOR DEVELOPERS: you can use $TWiki::cfg variables in other settings,
# but you must be sure they are only evaluated under program control and
# not when this file is loaded. For example:
## $TWiki::cfg{Blah} = "$TWiki::cfg{DataDir}/blah.dat"; # BAD
## $TWiki::cfg{Blah} = '$TWiki::cfg{DataDir}/blah.dat'; # GOOD

my $OS = $TWiki::cfg{OS} || '';
# Note that the general path settings are deliberately commented out.
# This is because they *must* be defined in LocalSite.cfg, and *not* here.

#---+ General path settings
# If you are a first-time installer; once you have set up the next
# six paths below, your TWiki should work - try it. You can always come
# back and tweak other settings later.<p />
# <b>Security Note:</b> Only the URL paths listed below should
# be browseable from the web. If you expose any other directories (such as
# lib or templates) you are opening up routes for possible hacking attempts.

# **URL M**
#  This is the root of all TWiki URLs e.g. http://myhost.com:123.
# $TWiki::cfg{DefaultUrlHost} = 'http://your.domain.com';

# **STRING**
# If your host has aliases (such as both www.twiki.org and twiki.org, and some IP addresses)
# you need to list them to tell TWiki that redirecting to them is OK. TWiki uses redirection
# as part of its normal mode of operation when it changes between editing and viewing.
# The security setting {AllowRedirectUrl} is per default disabled making redirecting to other
# domains restricted to prevent TWiki from being used in phishing attacks to protect it from
# middleman exploits. You can add additional URLs to this setting to enable redirects to
# additional trusted sites. Enter as comma separated list of URLs or hostnames. The URL must 
# be in the format http://your.domain.com.
$TWiki::cfg{PermittedRedirectHostUrls} = '';

# **PATH M**
# This is the 'cgi-bin' part of URLs used to access the TWiki bin
# directory e.g. <code>/twiki/bin</code><br />
# Do <b>not</b> include a trailing /.
# <p />
# See http://twiki.org/cgi-bin/view/TWiki.ShorterUrlCookbook for more information on setting up
# TWiki to use shorter script URLs.
# $TWiki::cfg{ScriptUrlPath} = '/twiki/bin';

# **URLPATH M**
# Attachments URL path e.g. /twiki/pub
# <p /><b>Security Note:</b> files in this directory are *not*
# protected by TWiki access controls. If you require access controls, you
# will have to use webserver controls (e.g. .htaccess on Apache)
# $TWiki::cfg{PubUrlPath} = '/twiki/pub';

# **PATH M**
# Attachments store (file path, not URL), must match /twiki/pub e.g.
# /usr/local/twiki/pub
# $TWiki::cfg{PubDir} = '/home/httpd/twiki/pub';

# **PATH M**
# Template directory e.g. /usr/local/twiki/templates
# $TWiki::cfg{TemplateDir} = '/home/httpd/twiki/templates';

# **PATH M**
# Topic files store (file path, not URL) e.g. /usr/local/twiki/data
# $TWiki::cfg{DataDir} = '/home/httpd/twiki/data';

# **PATH M**
# Translation files directory (file path, not URL) e.g. /usr/local/twiki/locales
# $TWiki::cfg{LocalesDir} = '/home/httpd/twiki/po';

# **PATH M**
# Directory where TWiki stores files that are required for the management
# of TWiki, but are not normally required to be browsed from the web.
# A number of subdirectories will be created automatically under this
# directory:
# <ul><li>{WorkingDir}<tt>/tmp/</tt> - used for security-related temporary
# files (these files can be deleted at any time without permanent damage)
# <ul><li>
# <i>Passthrough files</i> are used by TWiki to work around the limitations
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
# default TWiki registration process to store registrations that are pending
# verification.</li>
# </ul>
# $TWiki::cfg{WorkingDir} = '/home/httpd/twiki/working';

# **STRING 10**
# Suffix of TWiki CGI scripts (e.g. .cgi or .pl). You may need to set this
# if your webserver requires an extension.
$TWiki::cfg{ScriptSuffix} = '';

# ---+ Security setup

# **STRING H**
# Configuration password (not prompted)
$TWiki::cfg{Password} = '';

#---++ Paths
# **PATH M**
# Path control. Overrides the default PATH setting to control
# where TWiki looks for external programs, such as grep and rcs.
# By restricting this path to just a few key
# directories, you increase the security of your TWiki.
# <ol>
# <li>Unix or Linux
#  <ul>
#   <li>Path separator is :</li>
#   <li>Make sure diff and shell (Bourne or bash type) are found on path.</li>
#   <li>Typical setting is <tt>/bin:/usr/bin</tt></li>
#  </ul>
# <li>Windows ActiveState Perl, using DOS shell</li>
#  <ul>
#   <li>path separator is ;</li>
#   <li>The Windows system directory is required.</li>
#   <li>Use '\' not '/' in pathnames.</li>
#   <li>Typical setting is <tt>C:\windows\system32</tt></li>
#  </ul>
# <li>Windows Cygwin Perl</li>
#  <ul>
#   <li>path separator is :</li>
#   <li>The Windows system directory is required.</li>
#   <li>Use '/' not '\' in pathnames.</li>
#   <li>Typical setting is <tt>/cygdrive/c/windows/system32</tt></li>
#  </ul>
# </ol>
$TWiki::cfg{SafeEnvPath} = '';

#---++ Sessions

# **BOOLEAN**
# You can use persistent CGI session tracking even if you are not using login.
# This allows you to have persistent session variables - for example, skins.
# Client sessions are not required for logins to work, but TWiki will not
# be able to remember logged-in users consistently.
#
# See TWiki.TWikiUserAuthentication for a full discussion of the pros and
# cons of using persistent sessions. Session files are stored in the
# <tt>{WorkingDir}/tmp</tt> directory.
$TWiki::cfg{UseClientSessions} = 1;

# **STRING 20 EXPERT**
# Set the session timeout, in seconds. The session will be cleared after this
# amount of time without the session being accessed. The default is 6 hours
# (21600 seconds).<p />
# <b>Note</b>By default, session expiry is done "on the fly" by the same
# processes used to
# serve TWiki requests. As such it imposes a load on the server. When
# there are very large numbers of session files, this load can become
# significant. For best performance, you can set {Sessions}{ExpireAfter}
# to a negative number, which will mean that TWiki won't try to clean
# up expired sessions using CGI processes. Instead you should use a cron
# job to clean up expired sessions. The standard maintenance cron script
# <tt>tools/tick_twiki.pl</tt> includes this function.
$TWiki::cfg{Sessions}{ExpireAfter} = 21600;

# **NUMBER EXPERT**
# TemplateLogin only.
# Normally the cookie that remembers a user session is set to expire
# when the browser exits, but using this value you can make the cookie
# expire after a set number of seconds instead. If you set it then
# users will be able to tick a 'Remember me' box when logging in, and
# their session cookie will be remembered even if the browser exits.<p />
# This should always be the same as, or longer than, {Sessions}{ExpireAfter},
# otherwise TWiki may delete the session from its memory even though the
# cookie is still active.<p />
# A value of 0 will cause the cookie to expire when the browser exits.
# One month is roughly equal to 2600000 seconds.
$TWiki::cfg{Sessions}{ExpireCookiesAfter} = 0;

# **BOOLEAN EXPERT**
# If you have persistent sessions enabled, then TWiki will use a cookie in
# the browser to store the session ID. If the client has cookies disabled,
# then TWiki will not be able to record the session. As a fallback, TWiki
# can rewrite local URLs to pass the session ID as a parameter to the URL.
# This is a potential security risk, because it increases the chance of a
# session ID being stolen (accidentally or intentionally) by another user.
# If this is turned off, users with cookies disabled will have to
# re-authenticate for every secure page access (unless you are using
# {Sessions}{MapIP2SID}).
$TWiki::cfg{Sessions}{IDsInURLs} = 0;

# **BOOLEAN EXPERT**
# It's important to check that the user trying to use a session is the
# same user who originally created the session. TWiki does this by making
# sure, before initializing a previously stored session, that the IP
# address stored in the session matches the IP address of the user asking
# for that session. Turn this off if a client IP address may change during
# the lifetime of a session (unlikely)
$TWiki::cfg{Sessions}{UseIPMatching} = 1;

# **BOOLEAN EXPERT**
# For compatibility with older versions, TWiki supports the mapping of the
# clients IP address to a session ID. You can only use this if all
# client IP addresses are known to be unique.
# If this option is enabled, TWiki will <b>not</b> store cookies in the
# browser.
# The mapping is held in the file $TWiki::cfg{WorkingDir}/tmp/ip2sid.
# If you turn this option on, you can safely turn {Sessions}{IDsInURLs}
# <i>off</i>.
$TWiki::cfg{Sessions}{MapIP2SID} = 0;

#---++ Authentication
# **SELECTCLASS none,TWiki::LoginManager::*Login**
# TWiki supports different ways of responding when the user asks to log
# in (or is asked to log in as the result of an access control fault).
# They are:
# <ol><li>
# none - Don't support logging in, all users have access to everything.
# </li><li>
# TWiki::LoginManager::TemplateLogin - Redirect to the login template, which
#   asks for a username and password in a form. Does not cache the ID in
#   the browser, so requires client sessions to work.
# </li><li>
# TWiki::LoginManager::ApacheLogin - Redirect to an '...auth' script for which
#   Apache can be configured to ask for authorization information. Does
#   not require client sessions, but works best with them enabled.
# </li></ol>
$TWiki::cfg{LoginManager} = 'TWiki::LoginManager::TemplateLogin';

# **BOOLEAN EXPERT**
# Browsers typically remember your login and passwords to make authentication 
# more convenient for users. If your TWiki is used on public terminals, or other
# you can prevent this, forcing the user to enter the login and password every time.
$TWiki::cfg{TemplateLogin}{PreventBrowserRememberingPassword} = 0;

# **REGEX EXPERT**
# The perl regular expression used to constrain user login names. Some
# environments may require funny characters in login names, such as \.
# This is a filter <b>in</b> expression i.e. a login name must match this
# expression or an error will be thrown and the login denied.
$TWiki::cfg{LoginNameFilterIn} = qr/^[^\s\*?~^\$@%`"'&;|<>\x00-\x1f]+$/;

# **STRING 20 EXPERT**
# Guest user's login name. You are recommended not to change this.
$TWiki::cfg{DefaultUserLogin} = 'guest';

# **STRING 20 EXPERT**
# Guest user's wiki name. You are recommended not to change this.
$TWiki::cfg{DefaultUserWikiName} = 'TWikiGuest';

# **STRING 20 EXPERT**
# An internal admin user login name (matched with the configure password, if set)
# which can be used as a temporary Admin login (see: Main.TWikiAdminUser).
# This login name is additionally required by the install script for some addons
# and plugins, usually to gain write access to the TWiki web.
# If you change this you risk making topics uneditable.
$TWiki::cfg{AdminUserLogin} = 'admin';

# **STRING 20 EXPERT**
# An admin user WikiName what is displayed for actions done by the AdminUserLogin
# You should normally not need to change this. (you will need to move the 
# %USERSWEB%.TWikiAdminUser topic to match)
$TWiki::cfg{AdminUserWikiName} = 'TWikiAdminUser';

# **STRING 20 EXPERT**
# Group of users that can use special action=repRev and action=delRev
# on =save= and ALWAYS have edit powers. See TWiki.TWikiDocumentation
# for an explanation of twiki groups. This user will also run all the
# standard cron jobs, such as statistics and mail notification.
# The default value "TWikiAdminGroup" is used everywhere in TWiki to
# protect important settings so you would need a really special reason to
# change this setting.
$TWiki::cfg{SuperAdminGroup} = 'TWikiAdminGroup';

# **STRING 20 EXPERT**
# Name of topic in the {UsersWebName} web where registered users
# are listed. Automatically maintained by the standard
# registration scripts. <b>If you change this setting you will have to
# use TWiki to manually rename the existing topic</b>
$TWiki::cfg{UsersTopicName} = 'TWikiUsers';

# **STRING 100 EXPERT**
# Comma-separated list of scripts that require the user to authenticate.
# With TemplateLogin, any time an unauthenticated user attempts to access
# one of these scripts, they will be redirected to the login script. With
# ApacheLogin, they will be redirected to the logon script (note
# login and logon; they are different scripts). This approach means that
# only the logon script needs to be specified as require valid-user when
# using Apache authentication.
# <p/>
# If you want finer access control (e.g. authorised users only in one web
# but open access in another) then you should *clear* this list, and use
# TWiki Permissions to control access. Users wishing to make changes will
# have to log in by clicking a "log in" link instead of being automatically
# redirected when they try to edit.
$TWiki::cfg{AuthScripts} = 'attach,edit,manage,rename,save,upload,viewauth,rdiffauth,rest';

# **STRING 80 EXPERT**
# Authentication realm. This is
# normally only used in md5 password encoding. You may need to change it
# if you are sharing a password file with another application.
$TWiki::cfg{AuthRealm} =
'Enter your TWiki.LoginName. (Typically First name and last name, no space, no dots, capitalized, e.g. !JohnSmith, unless you chose otherwise). Visit TWiki.TWikiRegistration if you do not have one.';

#---++ User Mapping
# **SELECTCLASS TWiki::Users::*UserMapping**
# The user mapping is used to equate login names, used with external
# authentication systems, with TWiki user identities. By default only
# two mappings are available, though other mappings *may* be installed to
# support authentication providers.
# <ol><li>
#  TWiki::Users::TWikiUserMapping - uses TWiki user and group topics to
#  determine user information, and group memberships.
# </li><li>
#  TWiki::Users::BaseUserMapping - has only 2 users, {TWikiAdminUser} and
#  {TWikiGuestUser}, with the Admins login and password being set from this
#  configure script. <b>Does not support User registration</b>, and
#  only works with TemplateLogin.
# </li></ol>
$TWiki::cfg{UserMappingManager} = 'TWiki::Users::TWikiUserMapping';

#---++ Registration
# **BOOLEAN**
# If you want users to be able to use a login ID other than their
# wikiname, you need to turn this on. It controls whether the 'LoginName'
# box appears during the user registration process, and is used to tell
# the User Mapping module whether to map login names to wikinames or not
# (if it supports mappings, that is).
$TWiki::cfg{Register}{AllowLoginName} = $FALSE;

# **BOOLEAN EXPERT**
# If a login name (or an internal user id) cannot be mapped to a wikiname,
# then the user is unknown. By default the user will be displayed using
# whatever identity is stored for them. For security reasons you may want
# to obscure this stored id by setting this option to true.
$TWiki::cfg{RenderLoggedInButUnknownUsers} = $FALSE;

# **BOOLEAN**
# by turning this option off, you can temporarily disable new user registration.
# it will have no effect on existing users.
$TWiki::cfg{Register}{EnableNewUserRegistration} = $TRUE;

# **BOOLEAN EXPERT**
# Hide password in registration email to the *user*
# Note that TWiki sends admins a separate confirmation.
$TWiki::cfg{Register}{HidePasswd} = $TRUE;

# **BOOLEAN**
# Whether registrations must be verified by the user following
# a link sent in an email to the user's registered email address
$TWiki::cfg{Register}{NeedVerification} = $FALSE;

#---++ Passwords
# **SELECTCLASS none,TWiki::Users::*User**
# Name of the password handler implementation. The password handler manages
# the passwords database, and provides password lookup, and optionally
# password change, services. TWiki ships with two alternative implementations:
# <ol><li>
# TWiki::Users::HtPasswdUser - handles 'htpasswd' format files, with
#   passwords encoded as per the HtpasswdEncoding
# </li><li>
# TWiki::Users::ApacheHtpasswdUser - should behave identically to
# HtpasswdUser, but uses the CPAN:Apache::Htpasswd package to interact
# with Apache. It is shipped mainly as a demonstration of how to write
# a new password manager.
# </li></ol>
# You can provide your own alternative by implementing a new subclass of
# TWiki::Users::Password, and pointing {PasswordManager} at it in
# lib/LocalSite.cfg.<p />
# If 'none' is selected, users will not be able to change passwords
# and TemplateLogin manager then will always succeed, regardless of
# what username or password they enter. This may be useful when you want to
# enable logins so TWiki can identify contributors, but you don't care about
# passwords. Using ApacheLogin and PassordManager set to 'none' (and
# AllowLoginName = true) is a common  Enterprise SSO configuration, in which
# any logged in user can then register to create  their TWiki Based identity.
$TWiki::cfg{PasswordManager} = 'TWiki::Users::HtPasswdUser';

# **NUMBER**
# Minimum length for a password, for new registrations and password changes.
# If you want to allow null passwords, set this to 0.
$TWiki::cfg{MinPasswordLength} = 1;

# **PATH**
# Path to the file that stores passwords, for the TWiki::Users::HtPasswdUser
# password manager. You can use the <tt>htpasswd</tt> Apache program to create a new
# password file with the right encoding.
$TWiki::cfg{Htpasswd}{FileName} = '$TWiki::cfg{DataDir}/.htpasswd';

# **SELECT crypt,sha1,md5,plain,crypt-md5**
# Password encryption, for the TWiki::Users::HtPasswdUser password manager.
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
$TWiki::cfg{Htpasswd}{Encoding} = 'crypt';

#---++ Miscellaneous

# **STRING 20 EXPERT**
# {OS} and {DetailedOS} are calculated in the TWiki code. <b>You
# should only need to override if there is something badly wrong with
# those calculations.</b><br />
# {OS} may be one of UNIX WINDOWS VMS DOS MACINTOSH OS2
# $TWiki::cfg{OS} =
# **STRING 20 EXPERT**
# The value of Perl $OS
# $TWiki::cfg{DetailedOS} =

# **BOOLEAN EXPERT**
# Remove .. from %INCLUDE{filename}%, to stop includes
# of relative paths.
$TWiki::cfg{DenyDotDotInclude} = $TRUE;

# **BOOLEAN EXPERT**
#
# Allow %INCLUDE of URLs. This is disabled by default, because it is possible
# to mount a denial-of-service (DoS) attack on a TWiki site using INCLUDE and
# URLs. Only enable it if you are in an environment where a DoS attack is not
# a high risk.
$TWiki::cfg{INCLUDE}{AllowURLs} = $FALSE;

# **BOOLEAN EXPERT**
# Allow the use of SCRIPT and LITERAL tags in content. If this is set false,
# all SCRIPT and LITERAL sections will be removed from the body of topics.
# SCRIPT can still be used in the HEAD section, though. Note that this may
# prevent some plugins from functioning correctly.
$TWiki::cfg{AllowInlineScript} = $TRUE;

# **REGEX EXPERT**
# Filter-in regex for uploaded (attached) file names. This is a filter
# <b>in</b>, so any files that match this filter will be renamed on upload
# to prevent upload of files with the same file extensions as executables.
# <p /> NOTE: Be sure to update
# this list with any configuration or script filetypes that are
# automatically run by your web server. 
$TWiki::cfg{UploadFilter} = qr/^(\.htaccess|.*\.(?i)(?:php[0-9s]?(\..*)?|[sp]htm[l]?(\..*)?|pl|py|cgi))$/;

# **REGEX EXPERT**
# Filter-out regex for webnames, topic names, usernames, include paths
# and skin names. This is a filter <b>out</b>, so if any of the
# characters matched by this expression are seen in names, they will be
# removed.
$TWiki::cfg{NameFilter} = qr/[\s\*?~^\$@%`"'&;|<>\[\]\x00-\x1f]/;

# **BOOLEAN EXPERT**
# If this is set, the the search module will use more relaxed
# rules governing regular expressions searches.
$TWiki::cfg{ForceUnsafeRegexes} = $FALSE;

# **BOOLEAN EXPERT**
# Build the path to /twiki/bin from the URL that was used to get this
# far. This can be useful when rewriting rules or redirection are used
# to shorten URLs. Note that displayed links are incorrect after failed
# authentication if this is set, so unless you really know what you are
# doing, leave it alone.
$TWiki::cfg{GetScriptUrlFromCgi} = $FALSE;

# **BOOLEAN EXPERT**
# Draining STDIN may be necessary if the script is called due to a 
# redirect and the original query was a POST. In this case the web 
# server is waiting to write the POST data to this script's STDIN, 
# but CGI.pm won't drain STDIN as it is seeing a GET because of the 
# redirect, not a POST. Enable this <b>only</b> in case a TWiki script 
# hangs.
$TWiki::cfg{DrainStdin} = $FALSE;

# **BOOLEAN EXPERT**
# Remove port number from URL. If set, and a URL is given with a port
# number e.g. http://my.server.com:8080/twiki/bin/view, this will strip
# off the port number before using the url in links.
$TWiki::cfg{RemovePortNumber}  = $FALSE;

# **BOOLEAN EXPERT**
# Allow the use of URLs in the <tt>redirectto</tt> parameter to the 
# <tt>save</tt> script, and in <tt>topic</tt> parameter to the 
# <tt>view</tt> script. <b>WARNING:</b> Enabling this feature makes it 
# very easy to build phishing pages using the wiki, so in general, 
# public sites should <b>not</b> enable it. Note: It is possible to 
# redirect to a topic regardless of this setting, such as 
# <tt>topic=OtherTopic</tt> or <tt>redirectto=Web.OtherTopic</tt>.
# To enable redirection to a just list of trusted URLs keep this setting
# disabled and add a list of trusted URL to the {PermittedRedirectHostUrls}
# setting in the General path settings section.
$TWiki::cfg{AllowRedirectUrl}  = $FALSE;

# **REGEX EXPERT**
# Defines the filter-in regexp that must match the names of environment
# variables that can be seen using the %ENV{}% TWiki variable. Set it to
# '^.*$' to allow all environment variables to be seen (not recommended).
$TWiki::cfg{AccessibleENV} = '^(HTTP_\w+|REMOTE_\w+|SERVER_\w+|REQUEST_\w+|MOD_PERL|TWIKI_ACTION)$';

#---+ Anti-spam measures

# Standard TWiki incorporates some simple anti-spam measures to protect
# e-mail addresses and control the activities of benign robots. These
# should be enough to handle intranet requirements. Administrators of
# public (internet) sites are strongly recommended to investigate the
# <a href="http://twiki.org/cgi-bin/view/Plugins/BlackListPlugin">
# BlackListPlugin </a>

# **STRING 50**
# Text added to email addresses to prevent spambots from grabbing
# addresses e.g. set to 'NOSPAM' to get fred@user.co.ru
# rendered as fred@user.co.NOSPAM.ru
$TWiki::cfg{AntiSpam}{EmailPadding} = '';

# **BOOLEAN**
# Normally TWiki stores the user's sensitive information (such as their e-mail
# address) in a database out of public view. It also obfuscates e-mail
# addresses displayed in the browser. This is to help prevent e-mail
# spam and identity fraud.<br />
# If that is not a risk for you (e.g. you are behind a firewall) and you
# are happy for e-mails to be made public to all TWiki users,
# then you can set this option.<br />
# Note that if this option is set, then the <code>user</code> parameter to
# <code>%USERINFO</code> is ignored.
$TWiki::cfg{AntiSpam}{HideUserDetails} = $TRUE;

# **BOOLEAN**
# By default, TWiki doesn't do anything to stop robots, such as those used
# by search engines, from visiting "normal view" pages.
# If you disable this option, TWiki will generate a META tag to tell robots
# not to index pages.<br />
# Inappropriate pages (like the raw and edit views) are always protected from
# being indexed.<br />
# Note that for full protection from robots you should also use robots.txt
# (there is an example in the root of your TWiki installation).
$TWiki::cfg{AntiSpam}{RobotsAreWelcome} = $TRUE;

#---+ Log files

# **BOOLEAN EXPERT**
# Whether or not to to log different actions in the Access log
# (in order of how frequently they occur in a typical installation).
# Information in the Access log is used in gathering web statistics,
# and is useful as an audit trail of TWiki activity.
$TWiki::cfg{Log}{view}     = $TRUE; # very frequent, every page view
# **BOOLEAN EXPERT**
$TWiki::cfg{Log}{search}   = $TRUE;
# **BOOLEAN EXPERT**
$TWiki::cfg{Log}{changes}  = $TRUE; # infrequent if you use WebChanges
# **BOOLEAN EXPERT**
$TWiki::cfg{Log}{rdiff}    = $TRUE; # whenever revisions are differenced
# **BOOLEAN EXPERT**
$TWiki::cfg{Log}{edit}     = $TRUE; # fairly frequent, every time a page is edited
# **BOOLEAN EXPERT**
$TWiki::cfg{Log}{save}     = $TRUE;
# **BOOLEAN EXPERT**
$TWiki::cfg{Log}{upload}   = $TRUE; # whenever a new attachment is created
# **BOOLEAN EXPERT**
$TWiki::cfg{Log}{attach}   = $TRUE;
# **BOOLEAN EXPERT**
$TWiki::cfg{Log}{rename}   = $TRUE; # when a topic or attachment is renamed
# **BOOLEAN EXPERT**
$TWiki::cfg{Log}{register} = $TRUE; # rare, when a new user registers

# Names of the various log files. You can use %DATE% (which gets expanded
# to YYYYMM e.g. 200501) in the pathnames to cause the file to be renewed
# every month e.g. /var/log/TWiki/log.%DATE%.
# It defaults to the data dir

# **PATH**
# File for configuration messages generated by the configure script.
# (usually very very low volume).
$TWiki::cfg{ConfigurationLogName} = '$TWiki::cfg{DataDir}/configurationlog.txt';

# **PATH**
# File for debug messages (usually very low volume). %DATE% gets expanded
# to YYYYMM (year, month), allowing you to rotate logs.
$TWiki::cfg{DebugFileName} = '$TWiki::cfg{DataDir}/debug.txt';

# **PATH**
# Warnings - low volume, hopefully! %DATE% gets expanded
# to YYYYMM (year, month), allowing you to rotate logs.
$TWiki::cfg{WarningFileName} = '$TWiki::cfg{DataDir}/warn%DATE%.txt';

# **PATH**
# Access log - high volume, depending on what you enabled in {Log} above.
# %DATE% gets expanded to YYYYMM (year, month), allowing you to rotate logs.
$TWiki::cfg{LogFileName} = '$TWiki::cfg{DataDir}/log%DATE%.txt';

#---+ Localisation

# <p>
# Configuration items in this section control two things: recognition of
# national (non-ascii) characters and the system locale used by TWiki, which
# influences how programs TWiki and external programa called by it behave
# regarding internationalization.
# </p>
# <p>
# <b>Note:</b> for user interface internationalization, the only settings that
# matter are {UserInterfaceInternationalisation}, which enables user interface
# internationalisation, and {Site}{CharSet}, which controls which charset TWiki
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
$TWiki::cfg{UserInterfaceInternationalisation} = $FALSE;

# *LANGUAGES* Marker used by bin/configure script - do not remove!
$TWiki::cfg{Languages}{bg}{Enabled} = 1;
$TWiki::cfg{Languages}{cs}{Enabled} = 1;
$TWiki::cfg{Languages}{da}{Enabled} = 1;
$TWiki::cfg{Languages}{de}{Enabled} = 1;
$TWiki::cfg{Languages}{es}{Enabled} = 1;
$TWiki::cfg{Languages}{fr}{Enabled} = 1;
$TWiki::cfg{Languages}{it}{Enabled} = 1;
$TWiki::cfg{Languages}{ja}{Enabled} = 1;
$TWiki::cfg{Languages}{nl}{Enabled} = 1;
$TWiki::cfg{Languages}{pl}{Enabled} = 1;
$TWiki::cfg{Languages}{pt}{Enabled} = 1;
$TWiki::cfg{Languages}{ru}{Enabled} = 1;
$TWiki::cfg{Languages}{sv}{Enabled} = 1;
$TWiki::cfg{Languages}{'zh-cn'}{Enabled} = 1;
$TWiki::cfg{Languages}{'zh-tw'}{Enabled} = 1;

# **SELECT gmtime,servertime**
# Set the timezone (this only effects the display of times,
# all internal storage is still in GMT). May be gmtime or servertime
$TWiki::cfg{DisplayTimeValues} = 'gmtime';

# **SELECT $day $month $year, $year-$mo-$day, $year/$mo/$day, $year.$mo.$day**
# Set the default format for dates. The traditional TWiki format is 
# '$day $month $year' (31 Dec 2007). The ISO format '$year-$mo-$day'
# (2007-12-31) is recommended for non English language TWikis. Note that $mo
# is the month as a two digit number. $month is the three first letters of
# English name of the month
$TWiki::cfg{DefaultDateFormat} = '$day $month $year';

# **BOOLEAN**
# Locale - set to enable operating system level locales and
# internationalisation support for 8-bit character sets
$TWiki::cfg{UseLocale} = $FALSE;

# **STRING 50**
# Site-wide locale - used by TWiki and external programs such as grep, and to
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
$TWiki::cfg{Site}{Locale} = 'en_US.ISO-8859-1';

# **BOOLEAN EXPERT**
# Disable to force explicit listing of national chars in
# regexes, rather than relying on locale-based regexes. Intended
# for Perl 5.6 or higher on platforms with broken locales: should
# only be disabled if you have locale problems.
$TWiki::cfg{Site}{LocaleRegexes} = $TRUE;

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
$TWiki::cfg{UpperNational} = '';
# **STRING EXPERT**
# 
$TWiki::cfg{LowerNational} = '';

# **STRING 50 **
# Set this to match your chosen {Site}{Locale} (from 'locale -a')
# whose character set is not supported by your available perl conversion module
# (i.e. Encode for Perl 5.8 or higher, or Unicode::MapUTF8 for other Perl
# versions).  For example, if the locale 'ja_JP.eucjp' exists on your system
# but only 'euc-jp' is supported by Unicode::MapUTF8, set this to 'euc-jp'.
# If you don't define it, it will automatically be defaulted to iso-8859-1<br />
# UTF-8 support is still considered experimental. Use the value 'utf-8' to try it.
$TWiki::cfg{Site}{CharSet} = undef;

# **BOOLEAN EXPERT**
# Change non-existant plural topic name to singular,
# e.g. TestPolicies to TestPolicy. Only works in English.
$TWiki::cfg{PluralToSingular} = $TRUE;

#---+ Store settings

# **SELECT RcsWrap,RcsLite**
# Default store implementation.
# <ul><li>RcsWrap uses normal RCS executables.</li>
# <li>RcsLite uses a 100% Perl simplified implementation of RCS.
# RcsLite is useful if you don't have, and can't install, RCS - for
# example, on a hosted platform. It will work, and is compatible with
# RCS, but is not quite as fast.</li></ul>
# You can manually add options to LocalSite.cfg to select a
# different store for each web. If $TWiki::cfg{Store}{Fred} is defined, it will
# be taken as the name of a perl class (which must implement the methods of
# TWiki::Store::RcsFile).
# The TWiki::Store::Subversive class is an example implementation using the
# Subversion version control system as a data store.
$TWiki::cfg{StoreImpl} = 'RcsWrap';

# **STRING 20 EXPERT**
# Specifies the extension to use on RCS files. Set to -x,v on windows, leave
# blank on other platforms.
$TWiki::cfg{RCS}{ExtOption} = "";

# **OCTAL**
# File security for new directories. You may have to adjust these
# permissions to allow (or deny) users other than the webserver user access
# to directories that TWiki creates. This is an *octal* number
# representing the standard UNIX permissions (e.g. 755 == rwxr-xr-x)
$TWiki::cfg{RCS}{dirPermission}= 0755;

# **OCTAL**
# File security for new files. You may have to adjust these
# permissions to allow (or deny) users other than the webserver user access
# to files that TWiki creates.  This is an *octal* number
# representing the standard UNIX permissions (e.g. 644 == rw-r--r--)
$TWiki::cfg{RCS}{filePermission}= 0644;

# **BOOLEAN EXPERT**
# Some file-based Store implementations (RcsWrap and RcsLite for
# example) store attachment meta-data separately from the actual attachments.
# This means that it is possible to have a file in an attachment directory
# that is not seen as an attachment by TWiki. Sometimes it is desirable to
# be able to simply copy files into a directory and have them appear as
# attachments, and that's what this feature allows you to do.
# Considered experimental.
$TWiki::cfg{AutoAttachPubFiles} = $FALSE;

# **NUMBER EXPERT**
# Number of seconds to remember changes for. This doesn't affect revision
# histories, which always remember the date a file change. It only affects
# the number of changes that are cached for fast access by the 'changes' and
# 'statistics' scripts, and for use by extensions such as the change
# notification mailer. It should be no shorter than the interval between runs
# of these scripts.
$TWiki::cfg{Store}{RememberChangesFor} = 31 * 24 * 60 * 60;

# **REGEX EXPERT**
# Perl regular expression matching suffixes valid on plain text files
# Defines which attachments will be treated as ASCII in RCS. This is a
# filter <b>in</b>, so any filenames that match this expression will
# be treated as ASCII.
$TWiki::cfg{RCS}{asciiFileSuffixes} = qr/\.(txt|html|xml|pl)$/;

# **BOOLEAN EXPERT**
# Set this if your RCS cannot check out using the -p option.
# May be needed in some windows installations (not required for cygwin)
$TWiki::cfg{RCS}{coMustCopy} = $FALSE;

# **COMMAND EXPERT**
# RcsWrap initialise a file as binary.
# %FILENAME|F% will be expanded to the filename.
$TWiki::cfg{RCS}{initBinaryCmd} = "/usr/bin/rcs $TWiki::cfg{RCS}{ExtOption} -i -t-none -kb %FILENAME|F%";
# **COMMAND EXPERT**
# RcsWrap initialise a topic file.
$TWiki::cfg{RCS}{initTextCmd} = "/usr/bin/rcs $TWiki::cfg{RCS}{ExtOption} -i -t-none -ko %FILENAME|F%";
# **COMMAND EXPERT**
# RcsWrap uses this on Windows to create temporary binary files during upload.
$TWiki::cfg{RCS}{tmpBinaryCmd}  = "/usr/bin/rcs $TWiki::cfg{RCS}{ExtOption} -kb %FILENAME|F%";
# **COMMAND EXPERT**
# RcsWrap check-in.
# %USERNAME|S% will be expanded to the username.
# %COMMENT|U% will be expanded to the comment.
$TWiki::cfg{RCS}{ciCmd} =
    "/usr/bin/ci $TWiki::cfg{RCS}{ExtOption} -m%COMMENT|U% -t-none -w%USERNAME|S% -u %FILENAME|F%";
# **COMMAND EXPERT**
# RcsWrap check in, forcing the date.
# %DATE|D% will be expanded to the date.
$TWiki::cfg{RCS}{ciDateCmd} =
    "/usr/bin/ci $TWiki::cfg{RCS}{ExtOption} -m%COMMENT|U% -t-none -d%DATE|D% -u -w%USERNAME|S% %FILENAME|F%";
# **COMMAND EXPERT**
# RcsWrap check out.
# %REVISION|N% will be expanded to the revision number
$TWiki::cfg{RCS}{coCmd} =
    "/usr/bin/co $TWiki::cfg{RCS}{ExtOption} -p%REVISION|N% -ko %FILENAME|F%";
# **COMMAND EXPERT**
# RcsWrap file history.
$TWiki::cfg{RCS}{histCmd} =
    "/usr/bin/rlog $TWiki::cfg{RCS}{ExtOption} -h %FILENAME|F%";
# **COMMAND EXPERT**
# RcsWrap revision info about the file.
$TWiki::cfg{RCS}{infoCmd} =
    "/usr/bin/rlog $TWiki::cfg{RCS}{ExtOption} -r%REVISION|N% %FILENAME|F%";
# **COMMAND EXPERT**
# RcsWrap revision info about the revision that existed at a given date.
# %REVISIONn|N% will be expanded to the revision number.
# %CONTEXT|N% will be expanded to the number of lines of context.
$TWiki::cfg{RCS}{rlogDateCmd} =
    "/usr/bin/rlog $TWiki::cfg{RCS}{ExtOption} -d%DATE|D% %FILENAME|F%";
# **COMMAND EXPERT**
# RcsWrap differences between two revisions.
$TWiki::cfg{RCS}{diffCmd} =
    "/usr/bin/rcsdiff $TWiki::cfg{RCS}{ExtOption} -q -w -B -r%REVISION1|N% -r%REVISION2|N% -ko --unified=%CONTEXT|N% %FILENAME|F%";
# **COMMAND EXPERT**
# RcsWrap lock a file.
$TWiki::cfg{RCS}{lockCmd} =
    "/usr/bin/rcs $TWiki::cfg{RCS}{ExtOption} -l %FILENAME|F%";
# **COMMAND EXPERT**
# RcsWrap unlock a file.
$TWiki::cfg{RCS}{unlockCmd} =
    "/usr/bin/rcs $TWiki::cfg{RCS}{ExtOption} -u %FILENAME|F%";
# **COMMAND EXPERT**
# RcsWrap break a file lock.
$TWiki::cfg{RCS}{breaklockCmd} =
    "/usr/bin/rcs $TWiki::cfg{RCS}{ExtOption} -u -M %FILENAME|F%";
# **COMMAND EXPERT**
# RcsWrap delete a specific revision.
$TWiki::cfg{RCS}{delRevCmd} =
    "/usr/bin/rcs $TWiki::cfg{RCS}{ExtOption} -o%REVISION|N% %FILENAME|F%";

# **SELECTCLASS TWiki::Store::SearchAlgorithms::* EXPERT**
# TWiki RCS has two built-in search algorithms
# <ol><li> The default 'Forking' algorithm, which forks a subprocess that
# runs a 'grep' command,
# </li><li> the 'PurePerl' implementation, which is written in Perl and
# usually only used as a last resort.</li></ol>
# Normally you will be just fine with the 'Forking' implementation. However
# if you find searches run very slowly, you may want to try a different
# algorithm, which may work better on your configuration.
# Note that there is an alternative algorithm available from
# http://twiki.org/cgi-bin/view/Plugins/NativeSearchContrib, that often
# gives better performance with mod_perl and Speedy CGI.
$TWiki::cfg{RCS}{SearchAlgorithm} = 'TWiki::Store::SearchAlgorithms::Forking';

# **SELECTCLASS TWiki::Store::QueryAlgorithms::* EXPERT**
# The standard TWiki algorithm for performing queries is not particularly
# fast (it is based on plain-text searching). You may be able to select
# a different algorithm here, depending on what alternative implementations
# may have been installed.
$TWiki::cfg{RCS}{QueryAlgorithm} = 'TWiki::Store::QueryAlgorithms::BruteForce';

# **COMMAND EXPERT**
# Full path to GNU-compatible egrep program. This is used for searching when
# {SearchAlgorithm} is 'TWiki::Store::SearchAlgorithms::Forking'.
# %CS{|-i}% will be expanded
# to -i for case-sensitive search or to the empty string otherwise.
# Similarly for %DET, which controls whether matching lines are required.
# (see the documentation on these options with GNU grep for details).
$TWiki::cfg{RCS}{EgrepCmd} = '/bin/grep -E %CS{|-i}% %DET{|-l}% -H -- %TOKEN|U% %FILES|F%';

# **COMMAND EXPERT**
# Full path to GNU-compatible fgrep program. This is used for searching when
# {SearchAlgorithm} is 'TWiki::Store::SearchAlgorithms::Forking'.
$TWiki::cfg{RCS}{FgrepCmd} = '/bin/grep -F %CS{|-i}% %DET{|-l}% -H -- %TOKEN|U% %FILES|F%';

# **BOOLEAN**
# Set to enable hierarchical webs. Without this setting, TWiki will only
# allow a single level of webs. If you set this, you can use
# multiple levels, like a directory tree, i.e. webs within webs. See
# TWiki.MultiLevelWikiWebs for more details.
$TWiki::cfg{EnableHierarchicalWebs} = 1;

# **STRING 20 EXPERT**
# Name of the web where documentation and default preferences are held. If you
# change this setting, you must make sure the web exists and contains
# appropriate content, and upgrade scripts may no longer work (i.e. don't
# change it unless you are certain that you know what you are doing!)
$TWiki::cfg{SystemWebName} = 'TWiki';

# **STRING 20 EXPERT**
# Name of the web used as a trashcan (where deleted topics are moved)
# If you change this setting, you must make sure the web exists.
$TWiki::cfg{TrashWebName} = 'Trash';

# **STRING 20 EXPERT**
# Name of the web where usertopics are stored. If you
# change this setting, you must make sure the web exists and contains
# appropriate content, and upgrade scripts may no longer work
# (i.e. don't change it unless you are <b>certain</b> that you know what
# you are doing!)
$TWiki::cfg{UsersWebName} = 'Main';

#---+ Mail and Proxies
# **BOOLEAN**
# Enable email globally.
$TWiki::cfg{EnableEmail} = $TRUE;

# **STRING 30**
# TWiki administrator's e-mail address e.g. <code>webmaster@example.com</code>
# (used in <code>%WIKIWEBMASTER%</code>)
# NOTE: must be a single valid email address
$TWiki::cfg{WebMasterEmail} = '';

# **STRING 30**
# TWiki administrator's name address, for use in mails (first name and
# last name, e.g. =Fred Smith=) (used in %WIKIWEBMASTERNAME%)
$TWiki::cfg{WebMasterName} = 'TWiki Administrator';

# **COMMAND**
# Mail program. If Net::SMTP is installed, it will be used in preference. 
# To force TWiki to use the {MailProgram}, unset both {SMTP}{MAILHOST} 
# below and all SMTPMAILHOST settings in your TWiki's Preferences topics.
# This needs to be a command-line program that accepts
# MIME format mail messages on standard input, and mails them.
# To disable all outgoing email from TWiki leave both this field and the
# MAILHOST field below blank.
$TWiki::cfg{MailProgram} = '/usr/sbin/sendmail -t -oi -oeq';

# **STRING 30**
# Mail host for outgoing mail. This is only used if Net::SMTP is installed.
# Examples: mail.your.company
# <b>CAUTION</b> This setting can be overridden by a setting of SMTPMAILHOST
# in TWikiPreferences. Make sure you delete that setting if you are using a
# TWikiPreferences topic from a previous release of TWiki. To disable all
# outgoing mail from TWiki leave both this field and the MailProgram field
# above blank.
$TWiki::cfg{SMTP}{MAILHOST} = '';

# **STRING 30**
# Mail domain sending mail, required if you are using Net::SMTP. SMTP
# requires that you identify the server sending mail. If not set, 
# Net::SMTP will guess it for you. Example: twiki.your.company.
# <b>CAUTION</b> This setting can be overridden by a setting of SMTPSENDERHOST
# in TWikiPreferences. Make sure you delete that setting if you are using a
# TWikiPreferences topic from a previous release of TWiki.
$TWiki::cfg{SMTP}{SENDERHOST} = '';

# **STRING 30**
# Username for SMTP. Only required if your server requires authentication. If
# this is left blank, TWiki will not attempt to authenticate the mail sender.
$TWiki::cfg{SMTP}{Username} = '';

# **PASSWORD 30**
# Password for your {SMTP}{Username}.
$TWiki::cfg{SMTP}{Password} = '';

# **BOOLEAN EXPERT**
# Remove IMG tags in notification mails.
$TWiki::cfg{RemoveImgInMailnotify} = $TRUE;

# **STRING 20 EXPERT**
# Name of topic in each web that has notification registrations.
# <b>If you change this setting you will have to
# use TWiki to manually rename the topic in all existing webs</b>
$TWiki::cfg{NotifyTopicName}     = 'WebNotify';

# **BOOLEAN EXPERT**
# Set this option on to enable debug
# mode in SMTP. Output will go to the webserver error log.
$TWiki::cfg{SMTP}{Debug} = 0;

# **STRING 30 EXPERT**
# Some environments require outbound HTTP traffic to go through a proxy
# server. (e.g. proxy.your.company).
# <b>CAUTION</b> This setting can be overridden by a PROXYHOST setting
# in TWikiPreferences. Make sure you delete the setting from there if
# you are using a TWikiPreferences topic from a previous release of TWiki.
$TWiki::cfg{PROXY}{HOST} = '';

# **STRING 30 EXPERT**
# Some environments require outbound HTTP traffic to go through a proxy
# server. Set the port number here (e.g: 8080).
# <b>CAUTION</b> This setting can be overridden by a PROXYPORT setting
# in TWikiPreferences. Make sure you delete the setting from there if you
# are using a TWikiPreferences topic from a previous release of TWiki.
$TWiki::cfg{PROXY}{PORT} = '';

#---+ Miscellaneous settings

# **NUMBER**
# Number of top viewed topics to show in statistics topic
$TWiki::cfg{Stats}{TopViews} = 10;

# **NUMBER**
# Number of top contributors to show in statistics topic
$TWiki::cfg{Stats}{TopContrib} = 10;

# **STRING 20 EXPERT**
# Name of statistics topic
$TWiki::cfg{Stats}{TopicName} = 'WebStatistics';

# **STRING 120 EXPERT**
# Template path. A comma-separated list of generic file names, containing
# variables standing for part of the file name. When a template $name in $web
# with $skin is requested, this path is instantiated into a sequence of file
# names. The first file on this list that is found considered to be the 
# requested template file. The file names can either be absolute file names
# ending in ".tmpl" or a topic file in a TWiki web.
$TWiki::cfg{TemplatePath} = '$TWiki::cfg{TemplateDir}/$web/$name.$skin.tmpl, $TWiki::cfg{TemplateDir}/$name.$skin.tmpl, $TWiki::cfg{TemplateDir}/$web/$name.tmpl, $TWiki::cfg{TemplateDir}/$name.tmpl, $web.$skinSkin$nameTemplate, $TWiki::cfg{SystemWebName}.$skinSkin$nameTemplate, $web.$nameTemplate, $TWiki::cfg{SystemWebName}.$nameTemplate';

# **STRING 120 EXPERT**
# List of protocols (URI schemes) that TWiki will 
# automatically recognize and activate if found in absolute links.
# Additions you might find useful in your environment could be 'imap' or 'pop'
# (if you are using shared mailboxes accessible through your browser), or 'tel'
# if you have a softphone setup that supports links using this URI scheme. A list of popular URI schemes can be
# found at <a href="http://en.wikipedia.org/wiki/URI_scheme">http://en.wikipedia.org/wiki/URI_scheme</a>.
$TWiki::cfg{LinkProtocolPattern} = '(file|ftp|gopher|https|http|irc|mailto|news|nntp|telnet)';

# **STRING 50 EXPERT**
# Set to enable experimental mirror-site support. If this name is
# different to MIRRORSITENAME, then this TWiki is assumed to be a
# mirror of another. You are <b>highly</b> recommended not
# to dabble with this experimental, undocumented, untested feature!
$TWiki::cfg{SiteWebTopicName} = '';

# **STRING 20 EXPERT**
# Name of site-level preferences topic in the {SystemWebName} web.
# <b>If you change this setting you will have to
# use TWiki and *manually* rename the existing topic.</b>
# (i.e. don't change it unless you are <b>certain</b> that you know what
# you are doing!)
$TWiki::cfg{SitePrefsTopicName} = 'TWikiPreferences';

# **STRING 40 EXPERT**
# Web.TopicName of the site-level local preferences topic. If this topic
# exists, any settings in it will <b>override</b> settings in
# {SitePrefsTopicName}.<br />
# You are <b>strongly</b> recommended to keep all your local changes in
# a {LocalSitePreferences} topic rather than changing TWikiPreferences,
# as it will make upgrading a lot easier.
$TWiki::cfg{LocalSitePreferences} = 'Main.TWikiPreferences';

# **STRING 20 EXPERT**
# Name of main topic in a web.
# <b>If you change this setting you will have to
# use TWiki to manually rename the topic in all existing webs</b>
# (i.e. don't change it unless you are <b>certain</b> that you know what
# you are doing!)
$TWiki::cfg{HomeTopicName} = 'WebHome';

# **STRING 20 EXPERT**
# Name of preferences topic in a web.
# <b>If you change this setting you will have to
# use TWiki to manually rename the topic in all existing webs</b>
# (i.e. don't change it unless you are <b>certain</b> that you know what
# you are doing!)
$TWiki::cfg{WebPrefsTopicName} = 'WebPreferences';

# **NUMBER EXPERT**
# How many links to other revisions to show in the bottom bar. 0 for all
$TWiki::cfg{NumberOfRevisions} = 4;

# **NUMBER EXPERT**
# If this is set to a > 0 value, and the revision control system
# supports it (RCS does), then if a second edit of the same topic
# is done by the same user within this number of seconds, a new
# revision of the topic will NOT be created (the top revision will
# be replaced). Set this to 0 if you want <b>all</b> topic changes to create
# a new revision (as required by most formal development processes).
$TWiki::cfg{ReplaceIfEditedAgainWithin} = 3600;

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
$TWiki::cfg{LeaseLength} = 3600;

# **NUMBER EXPERT**
# Even if the other users' lease has expired, then you can specify that
# they should still get a (less forceful) warning about the old lease for
# some additional time after the lease expired. You can set this to 0 to
# suppress these extra warnings completely, or to -1 so they are always
# issued, or to a number of seconds since the old lease expired.
$TWiki::cfg{LeaseLengthLessForceful} = 3600;

# **PATH EXPERT**
# Pathname to file that maps file suffixes to MIME types :
# For Apache server set this to Apache's mime.types file pathname,
# for example /etc/httpd/mime.types, or use the default shipped in
# the TWiki data directory.
$TWiki::cfg{MimeTypesFileName} = '$TWiki::cfg{DataDir}/mime.types';

# **BOOLEAN EXPERT**
# If set, this will cause TWiki to treat warnings as errors that will
# cause TWiki to die. Provided for use by Plugin and Skin developers,
# who should develop with it switched on.
$TWiki::cfg{WarningsAreErrors} = $FALSE;

# **PERL H**
# List of operators permitted in structured search queries.
# Each operator is implemented by a class. Not visible in the
# configure UI.
$TWiki::cfg{Operators}{Query} = [ 'TWiki::Query::OP_and', 'TWiki::Query::OP_eq', 'TWiki::Query::OP_lc', 'TWiki::Query::OP_lte', 'TWiki::Query::OP_not', 'TWiki::Query::OP_ref', 'TWiki::Query::OP_d2n', 'TWiki::Query::OP_gte', 'TWiki::Query::OP_length', 'TWiki::Query::OP_lt', 'TWiki::Query::OP_ob', 'TWiki::Query::OP_uc', 'TWiki::Query::OP_dot', 'TWiki::Query::OP_gt', 'TWiki::Query::OP_like', 'TWiki::Query::OP_ne', 'TWiki::Query::OP_or', 'TWiki::Query::OP_where' ];

# **PERL H**
# List of operators permitted in %IF statements.
# Each operator is implemented by a class. Not visible in the
# configure UI.
$TWiki::cfg{Operators}{If} = [ 'TWiki::If::OP_allows', 'TWiki::If::OP_defined', 'TWiki::If::OP_isempty','TWiki::If::OP_ingroup', 'TWiki::If::OP_isweb', 'TWiki::If::OP_context', 'TWiki::If::OP_dollar', 'TWiki::If::OP_istopic' ];

#---+ Plugins
# *PLUGINS* Marker used by bin/configure script - do not remove!
# The plugins listed below were discovered by searching the @INC path for
# modules that match the TWiki standard e.g. TWiki/Plugins/MyPlugin.pm.
$TWiki::cfg{Plugins}{PreferencesPlugin}{Enabled} = 1;
$TWiki::cfg{Plugins}{SmiliesPlugin}{Enabled} = 1;
$TWiki::cfg{Plugins}{CommentPlugin}{Enabled} = 1;
$TWiki::cfg{Plugins}{SpreadSheetPlugin}{Enabled} = 1;
$TWiki::cfg{Plugins}{InterwikiPlugin}{Enabled} = 1;
$TWiki::cfg{Plugins}{TablePlugin}{Enabled} = 1;
$TWiki::cfg{Plugins}{EditTablePlugin}{Enabled} = 1;
$TWiki::cfg{Plugins}{SlideShowPlugin}{Enabled} = 1;
$TWiki::cfg{Plugins}{TwistyPlugin}{Enabled} = 1;
$TWiki::cfg{Plugins}{TinyMCEPlugin}{Enabled} = 1;
$TWiki::cfg{Plugins}{WysiwygPlugin}{Enabled} = 1;
# **STRING 80**
# Plugins evaluation order. If set to a comma-separated list of plugin names,
# will change the execution order of plugins so the listed subset of plugins
# are executed first. The default execution order is alphabetical on plugin
# name.
$TWiki::cfg{PluginsOrder} = 'SpreadSheetPlugin';

#---+ Extensions
# *FINDEXTENSIONS*
# **STRING 80 EXPERT**
# <b>Extensions Repositories Search List</b><br />
# TWiki extension repositories are just TWiki webs that are organised in the
# same way as the Plugins web on TWiki.org. The 'Find more extensions' link
# above searches these repositories for installable extensions. To set up an
# extensions repository:
# <ol>
# <li>Create a TWiki web to contain the repository</li>
# <li>Copy the <tt>FastReport</tt> page from <a href="http://twiki.org/cgi-bin/view/Plugins/FastReport?raw=on">TWiki:Plugins.FastReport</a> to your new web</li>
# <li> Copy the <tt>PackageForm</tt> page from <a href="http://twiki.org/cgi-bin/view/Plugins/PackageForm?raw=on">TWiki:Plugins.PackageForm</a> to your new web</li>
# <li> Set the <tt>WEBFORMS</tt> variable in WebPreferences to <tt>PackageForm</tt></li>
# </ol>
# The page for each extension must have the TWiki form <tt>PackageForm</tt>,
# and should have the packaged extension attached as a <tt>zip</tt> and/or
# <tt>tgz</tt> file.
# <p />
# This setting is a semicolon-separated list of repository specifications, each in the format: <i>name=(listurl,puburl)</i>,
# where:
# <ul>
# <li><i>name</i> is the symbolic name of the repository e.g. TWiki.org</li>
# <li><i>listurl</i> is the root of a view URL
# <li><i>puburl</i> is the root of a download URL
# </ul>
# For example,<code>
# twiki.org=(http://twiki.org/cgi-bin/view/Plugins/,http://twiki.org/p/pub/Plugins/);
# wikiring.com=(http://wikiring.com/bin/view/Extensions/,http://wikiring.com/bin/viewfile/Extensions/)</code><p />
$TWiki::cfg{ExtensionsRepositories} = 'TWiki.org=(http://twiki.org/cgi-bin/view/Plugins/,http://twiki.org/p/pub/Plugins/)';

1;
