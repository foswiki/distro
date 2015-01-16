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
# settings that are commented out, and remove everything from __END__ onwards.
#
# See 'setlib.cfg' in the 'bin' directory for how to configure a non-standard
# include path for Perl modules.
#
#############################################################################
#
# NOTE FOR DEVELOPERS:
# The comments in this file are formatted so that the =configure= script
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
# *Security Note:* Only the URL paths listed should
# be browseable from the web - if you expose any other directories (such as
# lib or templates) you are opening up routes for possible hacking attempts.

# **URL CHECK="noemptyok \
#              parts:scheme,authority \
#              partsreq:scheme,authority \
#              schemes:http,https \
#              authtype:hostip" **
# This is the root of all Foswiki URLs.
# For example, =http://myhost.com:123=
# (do not include the trailing slash.)
# $Foswiki::cfg{DefaultUrlHost} = 'http://your.domain.com';

# **BOOLEAN EXPERT**
# Enable this parameter to force foswiki to ignore the hostname in the
# URL entered by the user.  Foswiki will generate all links using the
# {DefaultUrlHost}.
# 
# By default, foswiki will use whatever URL that was entered by the
# user to generate links. The only exception is the special =localhost=
# name, which will be automatically replaced by the {DefaultUrlHost}.
# In most installations this is the preferred behavior, however when
# using SSL Accelerators, Reverse Proxys, and load balancers, the URL
# entered by the user may have been altered, and foswiki should be forced
# to return the {DefaultUrlHost}.
$Foswiki::cfg{ForceDefaultUrlHost} = $FALSE;

# **URILIST EXPERT CHECK='undefok \
#              parts:scheme,authority \
#              authtype:hostip' **
# If your host has aliases (such as both =www.mywiki.net= and =mywiki.net=
# and some IP addresses) you need to tell Foswiki that redirecting to them
# is OK. Foswiki uses redirection as part of its normal mode of operation
# when it changes between editing and viewing.
# 
# To prevent Foswiki from being used in phishing attacks and to protect it
# from middleman exploits, the security setting {AllowRedirectUrl} is by
# default disabled, restricting redirection to other domains. If a redirection
# to a different host is attempted, the target URL is compared against this
# list of additional trusted sites, and only if it matches is the redirect
# permitted.
#
# Enter as a comma separated list of URLs (protocol, hostname and (optional)
# port), for example =http://your.domain.com:8080,https://other.domain.com=.
# (Omit the trailing slash.)
$Foswiki::cfg{PermittedRedirectHostUrls} = '';

# **URLPATH CHECK="emptyok notrail" **
# This is the 'cgi-bin' part of URLs used to access the Foswiki bin
# directory. For example =/foswiki/bin=.
# See [[http://foswiki.org/Support/ShorterUrlCookbook][ShorterUrlCookbook]]
# for more information on setting up Foswiki to use shorter script URLs.
# $Foswiki::cfg{ScriptUrlPath} = '/foswiki/bin';

# **PATH EXPERT FEEDBACK="label='Validate Permissions'; method='validate_permissions';title='Validate file permissions.'" CHECK="noemptyok perms:Dx,'(.txt|.cfg)$'" **
# This is the file system path used to access the Foswiki bin directory.
# $Foswiki::cfg{ScriptDir} = '/home/httpd/foswiki/bin';

# **STRING 10 CHECK="emptyok"**
# Suffix of Foswiki CGI scripts. For example, .cgi or .pl.
# You may need to set this if your webserver requires an extension.
#$Foswiki::cfg{ScriptSuffix} = '';

# **URLPATH CHECK='undefok emptyok notrail' FEEDBACK="label='Verify';wizard='ScriptHash';method='verify';auth=1" **
#! n.b. options should match Pluggables/SCRIPTHASH.pm for dynamic path items
# This is the complete path used to access the Foswiki view script,
# including any suffix.
# You should leave this as it is, unless your web server is configured
# for short URLs (for example using Foswiki's
# [[http://foswiki.org/Support/ApacheConfigGenerator][Apache Config Generator]]
# ). If it is, replace this with the base path of your wiki (the value of
# {ScriptUrlPath} with the =/bin= suffix removed, so you'll have to leave
# this field empty if your wiki lives at the top level).
# 
# More information:
# [[http://foswiki.org/Support/ShorterUrlCookbook][Shorter URL Cookbook]]
# $Foswiki::cfg{ScriptUrlPaths}{view} = '$Foswiki::cfg{ScriptUrlPath}/view$Foswiki::cfg{ScriptSuffix}';

#! The following plugin must follow all other {ScriptUrlPaths} items
# *SCRIPTHASH*

# **URLPATH CHECK='noemptyok notrail' **
# This is the URL path used to link to attachments. For stores where
# attachments are stored as files (such as PlainFile and RCSLite) then this
# will normally be the URL path to the =pub= directory.
# For example =/foswiki/pub=
#
# *Security Note:* files in the pub directory are *not*
# protected by Foswiki access controls. If you require access controls, you
# will have to use webserver controls (for example =.htaccess= on Apache).
# See the
# [[http://foswiki.org/Support/ApacheConfigGenerator][Apache Config Generator]]
# for more information.
# $Foswiki::cfg{PubUrlPath} = '/foswiki/pub';

# **PATH EXPERT FEEDBACK="label='Validate Permissions'; method='validate_permissions';title='Validate file permissions. WARNING: this may take a long time on a large system'" CHECK="noemptyok perms:r,'*',wD,'(,v|,pfv)$'" **
# Attachments store (file path, not URL), must match the attachments URL
# path =/foswiki/pub= - for example =/usr/local/foswiki/pub=  This directory is
# normally accessible from the web.
# $Foswiki::cfg{PubDir} = '/home/httpd/foswiki/pub';

# **PATH EXPERT FEEDBACK="label='Validate Permissions'; method='validate_permissions';title='Validate file permissions. WARNING: this may take a long time on a large system'" CHECK="noemptyok perms:rwDpd,'(,v|,pfv)$',r" **
# Topic files store (file path, not URL). For example =/usr/local/foswiki/data=.
# This directory must not be web accessible. 
# $Foswiki::cfg{DataDir} = '/home/httpd/foswiki/data';

# **PATH EXPERT FEEDBACK="label='Validate Permissions'; method='validate_permissions'" CHECK="noemptyok perms:rD" **
# File path to tools directory. For example =/usr/local/foswiki/tools=.
# This directory must not be web accessible.
# $Foswiki::cfg{ToolsDir} = '/home/httpd/foswiki/tools';

# **PATH EXPERT FEEDBACK="label='Validate Permissions'; method='validate_permissions'" CHECK="noemptyok perms:rD" **
# File path to templates directory. For example =/usr/local/foswiki/templates=.
# This directory must not be web accessible.
# $Foswiki::cfg{TemplateDir} = '/home/httpd/foswiki/templates';

# **PATH EXPERT FEEDBACK="label='Validate Permissions'; method='validate_permissions'" CHECK="noemptyok perms:rD" **
# File path to locale directory.
# For example =/usr/local/foswiki/locale=.
# This directory must not be web accessible.
# $Foswiki::cfg{LocalesDir} = '/home/httpd/foswiki/locale';

# **PATH EXPERT FEEDBACK="label='Validate Permissions'; method='validate_permissions'" CHECK="noemptyok perms:rw" **
# Directory where Foswiki stores files that are required for the management
# of Foswiki, but are not required to be accessed from the web.
# A number of subdirectories will be created automatically under this
# directory:
#    * ={WorkingDir}/tmp= - used for security-related temporary files
#     (these files can be deleted at any time without permanent damage).
#      _Passthrough files_ are used by Foswiki to work around the limitations
#      of HTTP when redirecting URLs.
#      _Session files_ are used to record information about active
#      users - for example, whether they are logged in or not.
#      For obvious reasons, these files must *not* be browseable from the web!
#      You are recommended to restrict filesystem permissions on this
#      directory so only the web server user can acess it.
#    * ={WorkingDir}/requestTmp= - used as an alternate location for the
#      system =/tmp= directory.  This is only used if {TempfileDir}
#      is configured.
#    * ={WorkingDir}/work_areas= - these are work areas used by
#      extensions that need to store persistent data across sessions.
#    * ={WorkingDir}/registration_approvals= - this is used by the
#      default Foswiki registration process to store registrations that
#      are pending verification.
# $Foswiki::cfg{WorkingDir} = '/home/httpd/foswiki/working';

# **PATH CHECK="undefok" EXPERT**
# This is used to override the default system temporary file location.
# Set this if you wish to have control over where working tmp files are
# created.  It is normally set automatically in the code.
# $Foswiki::cfg{TempfileDir} = '';

# **PATH EXPERT CHECK='undefok'**
# You can override the default PATH setting to control
# where Foswiki looks for external programs, such as grep.
# By restricting this path to just a few key
# directories, you increase the security of your installation.
#    * Unix or Linux - Path separator is ':'.  Make sure diff
#      and shell (Bourne or bash type) are found on path. Typical
#      path is =/bin:/usr/bin=
#    * Windows ActiveState Perl, using DOS shell. Path separator is ';'.
#      The Windows system directory is required on the path. Use '\' not
#      '/' in pathnames. Typical setting is =C:\windows\system32=
#    * Windows Cygwin Perl - Path separator is ':'. The Windows system
#      directory is required on the path. Use '/' not '\' in pathnames.
#      Typical setting is =/cygdrive/c/windows/system32=
# $Foswiki::cfg{SafeEnvPath} = undef;

#############################################################################
#---+ Security and Authentication
# Control most aspects of how Foswiki handles security related activities.

#---++ Sessions
# Sessions are how Foswiki tracks a user across multiple requests.

# **BOOLEAN**
# Control whether Foswiki will use persistent sessions.
# A user's session id is stored in a cookie, and this is used to identify
# the user for each request they make to the server.
# You can use sessions even if you are not using login.
# This allows you to have persistent session variables - for example, skins.
# Client sessions are not required for logins to work, but Foswiki will not
# be able to remember logged-in users consistently.
# See [[http://foswiki.org/System/UserAuthentication][User
# Authentication]] for a full discussion of the pros and
# cons of using persistent sessions.
$Foswiki::cfg{UseClientSessions} = 1;

# **NUMBER 20 DISPLAY_IF="{UseClientSessions}" CHECK="iff:'{UseClientSessions}'"**
# Set the session timeout, in seconds. The session will be cleared after this
# amount of time without the session being accessed. The default is 6 hours
# (21600 seconds).
#
# *Note* By default, session expiry is done "on the fly" by the same
# processes used to serve Foswiki requests. As such it imposes a load
# on the server. When there are very large numbers of session files,
# this load can become significant. For best performance, you can set
# {Sessions}{ExpireAfter} to a negative number, which will mean that
# Foswiki won't try to clean up expired sessions using CGI processes.
# Instead you should use a cron job to clean up expired sessions. The
# standard maintenance cron script =tools/tick_foswiki.pl= includes this
# function. Session files are stored in the ={WorkingDir}/tmp= directory.
#
# This setting is also used to set a lifetime for passthru redirect requests.
$Foswiki::cfg{Sessions}{ExpireAfter} = 21600;

# **NUMBER EXPERT DISPLAY_IF="{UseClientSessions} && {LoginManager}=='Foswiki::LoginManager::TemplateLogin'" CHECK="iff:'{UseClientSessions} && {LoginManager}=~/TemplateLogin$/'"**
# TemplateLogin only.
# Normally the cookie that remembers a user session is set to expire
# when the browser exits, but using this value you can make the cookie
# expire after a set number of seconds instead. If you set it then
# users will be able to tick a 'Remember me' box when logging in, and
# their session cookie will be remembered even if the browser exits.
#
# This should always be the same as, or longer than, {Sessions}{ExpireAfter},
# otherwise Foswiki may delete the session from its memory even though the
# cookie is still active.
#
# A value of 0 will cause the cookie to expire when the browser exits.
# One month is roughly equal to 2600000 seconds.
$Foswiki::cfg{Sessions}{ExpireCookiesAfter} = 0;

# **BOOLEAN EXPERT DISPLAY_IF="{UseClientSessions}" CHECK="iff:'{UseClientSessions}'"**
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

# **STRING 20 EXPERT DISPLAY_IF="{UseClientSessions}" CHECK="undefok emptyok iff:'{UseClientSessions}'"**
# By default the Foswiki session cookie is only accessible by the host which
# sets it. To change the scope of this cookie you can set this to any other
# value (ie. company.com). Make sure that Foswiki can access its own cookie.
#
# If empty, this defaults to the current host.
$Foswiki::cfg{Sessions}{CookieRealm} = '';

# **BOOLEAN DISPLAY_IF="{UseClientSessions}" CHECK="iff:'{UseClientSessions}'" EXPERT**
# Enable this option to prevent a session from being accessed by
# more than one IP Address. This gives some protection against session
# hijack attacks.
#
# This option may or may not be helpful, Public web sites can easily be
# accessed by different users from the same IP address when they access
# through the same proxy gateway, meaning that the protection is limited.
# Additionally, people get more and more mobile using a mix of LAN, WLAN,
# and 3G modems and they will often change IP address several times per day.
# For these users IP matching causes the need to re-authenticate whenever
# their IP Address changes and is quite inconvenient..
#
# Note that the =CGI::Session= tutorial strongly recommends use of
# IP Matching for security purposes, so it is now enabled by default.
$Foswiki::cfg{Sessions}{UseIPMatching} = 1;

# **BOOLEAN DISPLAY_IF="{UseClientSessions}" CHECK="iff:'{UseClientSessions}'" EXPERT**
# On prior versions of Foswiki, every user is given their own CGI Session.
# Disable this setting to block creation of session for guest users.
#
# This is EXPERIMENTAL.  Some parts of Foswiki will not function without a
# CGI Session.  This includes scripts that update, and any wiki applications
# that make use of session variables.
$Foswiki::cfg{Sessions}{EnableGuestSessions} = 1;

# **BOOLEAN EXPERT DISPLAY_IF="{UseClientSessions}" CHECK="iff:'{UseClientSessions}'" EXPERT**
# For compatibility with older versions, Foswiki supports the mapping of the
# clients IP address to a session ID. You can only use this if all
# client IP addresses are known to be unique.
# If this option is enabled, Foswiki will *not* store cookies in the
# browser.
# The mapping is held in the file =$Foswiki::cfg{WorkingDir}/tmp/ip2sid=.
# If you turn this option on, you can safely turn {Sessions}{IDsInURLs}
# _off_.
$Foswiki::cfg{Sessions}{MapIP2SID} = 0;

# **OCTAL CHECK="min:000 max:777" EXPERT**
# File security for new session objects created by the login manager.
# You may have to adjust these permissions to allow (or deny) users other
# than the webserver user access session objects that Foswiki creates in
# the filesystem. This is an *octal* number representing the standard
# UNIX permissions
# (for example 0640 == rw-r-----)
$Foswiki::cfg{Session}{filePermission} = 0600;

#---++ Validation
# Validation is the process by which Foswiki validates that a request is
# allowed by the site, and is not part of an attack on the site.

# **SELECT strikeone,embedded,none **
# By default Foswiki uses Javascript to perform "double submission" validation
# of browser requests. This technique, called "strikeone", is highly
# recommended for the prevention of cross-site request forgery (CSRF). See also
# [[http://foswiki.org/Support/WhyYouAreAskedToConfirm][Why am I being asked to confirm?]].
#
# If Javascript is known not to be available in browsers that use the site,
# or cookies are disabled, but you still want validation of submissions,
# then you can fall back on a embedded-key validation technique that
# is less secure, but still offers some protection against CSRF. Both
# validation techniques rely on user verification of "suspicious"
# transactions.
#
# This option allows you to select which validation technique will be
# used.
#   * If it is set to "strikeone", or is undefined, 0, or the empty string,
#     then double-submission using Javascript will be used.
#   * If it is set to "embedded", then embedded validation keys will be used.
#   * If it is set to "none", then no validation of posted requests will
#     be performed.
$Foswiki::cfg{Validation}{Method} = 'strikeone';

# **NUMBER EXPERT DISPLAY_IF="{Validation}{Method}!='none'" CHECK="min:1 iff:'{Validation}{Method} ne q<none>'"**
# Validation keys are stored for a maximum of this amount of time before
# they are invalidated. Time in seconds. A shorter time reduces the risk
# of a hacker finding and re-using one of the keys, at the cost of more
# frequent confirmation prompts for users.
$Foswiki::cfg{Validation}{ValidForTime} = 3600;

# **NUMBER EXPERT DISPLAY_IF="{Validation}{Method}!='none'" CHECK="min:10 iff:'{Validation}{Method} ne q<none>'"**
# The maximum number of validation keys to store in a session. There is one
# key stored for each page rendered. If the number of keys exceeds this
# number, the oldest keys will be force-expired to bring the number down.
# This is a simple tradeoff between space on the server, and the number of
# keys a single user might use (usually dictated by the number of wiki pages
# they have open simultaneously)
$Foswiki::cfg{Validation}{MaxKeysPerSession} = 1000;

# **BOOLEAN EXPERT DISPLAY_IF="{Validation}{Method}!='none'" CHECK="iff:'{Validation}{Method} ne q<none>'"**
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
# Foswiki supports different ways of handling how a user asks, or is asked,
# to log in.

# **SELECTCLASS none,Foswiki::LoginManager::*Login* CHECK="also:{AuthScripts}"**
# Select the login manager to use.
#    * none - Don't support logging in, all users have access to everything.
#    * Foswiki::LoginManager::TemplateLogin - Redirect to the login template,
#      which asks for a username and password in a form. Does not cache the
#      ID in the browser, so requires client sessions to work.
#    * Foswiki::LoginManager::ApacheLogin - Redirect to an '...auth' script
#      for which Apache can be configured to ask for authorization information.
#      Does not require client sessions, but works best with them enabled.
# It is important to ensure that the chosen LoginManager is consistent with
# the Web Server configuration.
$Foswiki::cfg{LoginManager} = 'Foswiki::LoginManager::TemplateLogin';

# **BOOLEAN EXPERT**
# Write debugging output to the webserver error log.
$Foswiki::cfg{Trace}{LoginManager} = 0;

# **STRING 100 DISPLAY_IF="{LoginManager}=='Foswiki::LoginManager::TemplateLogin'" CHECK="iff:'{LoginManager} =~ /TemplateLogin$/'" CHECK_ON_CHANGE="{LoginManager}" **
# Comma-separated list of scripts in the bin directory that require the user to
# authenticate. This setting is used with TemplateLogin; any time an
# unauthenticated user attempts to access one of these scripts, they will be
# required to authenticate. With ApacheLogin, the web server must be configured
# to require a valid user for access to these scripts.  =edit= and
# =save= should be removed from this list if the guest user is permitted to
# edit topics without authentication.
$Foswiki::cfg{AuthScripts} =
'attach,compareauth,edit,manage,previewauth,rdiffauth,rename,restauth,save,statistics,upload,viewauth,viewfileauth';

# **BOOLEAN EXPERT**
# Foswiki 1.2 has removed the =rest= script from the list of {AuthScripts}.
# Instead of providing blanket security for =rest=, each handler is now
# responsible to set its individual requirements for 3 options:
# _authentication_, _validation_ and _http_allow_ methods (POST vs. GET).
# The defaults for these 3 options have been changed to default to be secure,
# and handlers can exempt these checks based upon their specific requirements.
# Enable this setting to restore the original insecure defaults.
$Foswiki::cfg{LegacyRESTSecurity} = $FALSE;

# **REGEX EXPERT**
# Regular expression matching the scripts that should be allowed to accept the 
# =username= and =password= parameters other than the login script. Older
# versions of Foswiki would accept the username and password parameter on any
# script. The =login= and =logon= script will always accept the username and
# password, but only from POST requests. In order to add support for the
# =rest= and =restauth>> scripts, specify =/^(view|rest)(auth)?$/=
$Foswiki::cfg{Session}{AcceptUserPwParam} = '^view(auth)?$';

# **BOOLEAN EXPERT**
# For backwards compatibility, enable this setting if you want
# =username= and =password= parameters to be accepted on a GET request when
# provided as part of the query string.  It is more secure to restrict login
#  operations to POST requests only.
$Foswiki::cfg{Session}{AcceptUserPwParamOnGET} = $FALSE;

# **BOOLEAN EXPERT DISPLAY_IF="{LoginManager}=='Foswiki::LoginManager::TemplateLogin'" CHECK="iff:'{LoginManager} =~ /TemplateLogin$/'"**
# Browsers typically remember your login and passwords to make authentication
# more convenient for users. If your Foswiki is used on public terminals,
# you can prevent this, forcing the user to enter the login and password
# every time.
$Foswiki::cfg{TemplateLogin}{PreventBrowserRememberingPassword} = 0;

# **BOOLEAN EXPERT DISPLAY_IF="{LoginManager}=='Foswiki::LoginManager::TemplateLogin'" CHECK="iff:'{LoginManager} =~ /TemplateLogin$/'"**
# Allow a user to log in to foswiki using the email addresses known to the
# password system (in addition to their username).
$Foswiki::cfg{TemplateLogin}{AllowLoginUsingEmailAddress} = 0;

# **REGEX EXPERT**
# The perl regular expression used to constrain user login names. Some
# environments may require funny characters in login names, such as \.
# This is a filter *in* expression, so a login name must match this
# expression or an error will be thrown and the login denied.
$Foswiki::cfg{LoginNameFilterIn} = qr/^[^\s\*?~^\$@%`"'&;|<>\x00-\x1f]+$/;

# **STRING 20 EXPERT**
# Guest user's login name. You are recommended not to change this.
$Foswiki::cfg{DefaultUserLogin} = 'guest';

# **STRING 20 EXPERT**
# Guest user's wiki name. You are recommended not to change this.
$Foswiki::cfg{DefaultUserWikiName} = 'WikiGuest';

# **STRING 20 EXPERT**
# An internal admin user login name (matched with the configure password,
# if set) which can be used as a temporary Admin login (see: Main.AdminUser).
# This login name is additionally required by the install script for some addons
# and plugins, usually to gain write access to the Foswiki web.
# If you change this you risk making topics uneditable.
$Foswiki::cfg{AdminUserLogin} = 'admin';

# **STRING 20 EXPERT**
# An admin user WikiName that is displayed for actions done by the
# {AdminUserLogin}.
# This is a special WikiName and should never be directly authenticated.
# It is accessed by logging in using the AdminUserLogin either directly
# or with the sudo login.
# You should normally not need to change this (if you do,
# you will need to move the %USERSWEB%.AdminUser topic to match. Do not
# register a user with this name!)
$Foswiki::cfg{AdminUserWikiName} = 'AdminUser';

# **STRING 20 EXPERT**
# Group of users that can use special =?action=repRev= and =?action=delRev=
# on =save= and ALWAYS have edit powers. See %SYSTEMWEB%.CompleteDocumentation
# for an explanation of wiki groups. The default value "AdminGroup" is used
# everywhere in Foswiki to protect important settings so you would need
# a really special reason to change this setting.
$Foswiki::cfg{SuperAdminGroup} = 'AdminGroup';

# **STRING 20 EXPERT**
# Name of topic in the {UsersWebName} web where registered users are listed.
# Automatically maintained by the standard registration scripts.
# *If you change this setting you will have to use Foswiki to*
# *manually rename the existing topic*
$Foswiki::cfg{UsersTopicName} = 'WikiUsers';

#---++ User mapping
# This section contains only expert options.
# The user mapping is used to map login names used with external
# authentication systems to Foswiki user identities.

# **SELECTCLASS Foswiki::Users::*UserMapping EXPERT**
# By default only two mappings are available, though other mappings *may*
# be installed to support other authentication providers.
#    * Foswiki::Users::TopicUserMapping - uses Foswiki user and group topics to
#      determine user information, and group memberships.
#    * Foswiki::Users::BaseUserMapping - has only pseudo users such as
#      {AdminUser} and {DefaultUserWikiName}, with the Admins login and
#      password being set from configure.
#      *Does not support User registration*, and only works with TemplateLogin.
$Foswiki::cfg{UserMappingManager} = 'Foswiki::Users::TopicUserMapping';

# **BOOLEAN EXPERT DISPLAY_IF="{UserMappingManager}=='Foswiki::Users::TopicUserMapping'" CHECK="iff:'{UserMappingManager} =~ /:TopicUserMapping$/'"**
# Enable this parameter to force the TopicUserMapping manager to directly
# manage email addresses, and not pass management over to the PasswordManager.
# When enabled, TopicUserMapping will store addresses in the user topics.
#
# Default is disabled.  The PasswordManager will determine what is
# responsible for storing email addresses.
#
# *Note:* Foswiki provides a utility to migrate emails from user topic to the
# password file, but does not provide any way to migrate emails from the
# password file back to user topics.
$Foswiki::cfg{TopicUserMapping}{ForceManageEmails} = $FALSE;

#---++ Access Control
# Control some features of how Foswiki handles access control settings.

# **SELECTCLASS Foswiki::Access::*Access**
# Choose who can access the wiki.
#    * =TopicACLAccess= is the normal foswiki ACL system, as documented
#      in the setup guides.
#    * =AdminOnlyAccess= denies all non-admins (not in the AdminGroup)
#      any access to the wiki - useful for site maintainence.
#    * =TopicACLReadOnlyAccess= denies all non-admins any update access
#      to the wiki, and falls back to =TopicACLAccess= for VIEW access
#      checks  - also useful for site maintenance.
# Note:  The AdminOnly and ReadOnly access controls do not necessarly
# provide absolute control.  Some extensions (non-default) have been
# written to allow anonymous updates.  If an operation does not check
# for access permission, then it will not get blocked by these controls.
$Foswiki::cfg{AccessControl} = 'Foswiki::Access::TopicACLAccess';

# **BOOLEAN EXPERT**
# Optionally restore the deprecated empty =DENY= ACL behavior.
# If this setting is enabled, the "Empty" =DENY= ACL is interpreted as 
# "Deny nobody", which is equivalent to "Allow all".
# It is recommended that this setting remain disabled,  and that
# these rules be replaced with the  * wildcard on the =ALLOW= setting:
# <verbatim>
#    * Set DENYTOPICVIEW =        Should be replaced with:
#    * Set ALLOWTOPICVIEW = *
# </verbatim>
$Foswiki::cfg{AccessControlACL}{EnableDeprecatedEmptyDeny} = $FALSE;

# **SELECT authenticated,acl,all EXPERT**
# Choose which users will have access to the "raw" topic views.
# Default is "authenticated",  so that guest users can not view the raw
# topic contents.  This avoids indexing of raw topic context by bots and
# crawlers.
# If set to =acl=, then access is controlled by setting =ALLOW= or =DENY=
# =WEB= or =TOPIC RAW=, for example:
# <verbatim>
#   * Set ALLOWTOPICRAW = DevelopersGroup
# </verbatim>
$Foswiki::cfg{FeatureAccess}{AllowRaw} = 'authenticated';

# **SELECT authenticated,acl,all EXPERT**
# Choose which users will have access to the topic history.
# Default is "authenticated",  so that guest users can not view the topic
# history. This can also reduce bot workload by denying web crawlers access
# to topic history. If set to =acl=, then access is controlled on a topic
# or web basis by setting =ALLOW= or =DENY= =WEB= or =TOPIC HISTORY=.
# For example:
# <verbatim>
#   * Set DENYTOPICHISTORY = WikiGuest
# </verbatim>
# Note that this setting also controls access to the =rdiff= and =compare=
#  scripts.
$Foswiki::cfg{FeatureAccess}{AllowHistory} = 'authenticated';

# **STRING 80**
# A list of users permitted to use the =bin/configure= configuration tool
# If this is configured, then users attempting to access
# configure are validated against this list. (The user must still first
# login using the normal Foswiki authentication). If configured, it is
# applied as a replacement for testing the isAdmin status of the user.
# This can be used to:
#    * Allow configure to be used only by a subset of Admins
#    * Allow configure to be used by non-admin users.
#    * Allow configure to run by anyone
# Because users with access to configure can install software on the server
# and make changes that are potentially difficult to recover from, it is
# strongly recommended that configure access be limited.   Examples:
#    * Restrict configure to "JoeAdmin" and "BobAdmin": =JoeAdmin BobAdmin=
#    * Restrict to the sudo admin user:  =BaseUserMapping_333=
#       * (Also set the expert Password setting under the Passwords tab)
$Foswiki::cfg{FeatureAccess}{Configure} = '';

#---++ Passwords
# Control how passwords are handled.

# **SELECTCLASS none,Foswiki::Users::*User**
# The password manager handles the passwords database, and provides
# password lookup, and optionally password change, services to the rest of
# Foswiki.
# Foswiki ships with two alternative password manager implementations:
#    * =Foswiki::Users::HtPasswdUser= - handles 'htpasswd' format files, with
#      passwords encoded as per the HtpasswdEncoding
#    * =Foswiki::Users::ApacheHtpasswdUser= - should behave identically to
#      HtpasswdUser for crypt encoding, but uses the CPAN:Apache::Htpasswd
#      package to interact with Apache. It is shipped mainly as a
#      demonstration of how to write a new password manager.
#      *It is not recommended for production use*
# You can provide your own alternative by implementing a new subclass of
# Foswiki::Users::Password, and pointing {PasswordManager} at it in
# lib/LocalSite.cfg.
#
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

# **PATH DISPLAY_IF="/htpasswd/i.test({PasswordManager})" CHECK="iff:'{PasswordManager}=~/htpasswd/'"**
# Path to the file that stores passwords, for the Foswiki::Users::HtPasswdUser
# password manager. You can use the =htpasswd= Apache program to create a new
# password file with the right encoding, however use caution, as it will remove
# email addresses from an existing file.
$Foswiki::cfg{Htpasswd}{FileName} = '$Foswiki::cfg{DataDir}/.htpasswd';

# **PATH EXPERT DISPLAY_IF="/htpasswd/i.test({PasswordManager})" CHECK="iff:'{PasswordManager}=~/htpasswd/'"**
# Path to the lockfile for the password file.  This normally does not need
# to be changed; however if two Foswiki installations share and update a
# common password file it is critical that both use the same lockfile.
# For example, change it to the location of the password file,
# =$Foswiki::cfg{DataDir}/htpasswd.lock=.  Foswiki must have rights to
# create the lock file in this location. Only applicable to =HtPasswdUser=.
$Foswiki::cfg{Htpasswd}{LockFileName} =
  '$Foswiki::cfg{WorkingDir}/htpasswd.lock';

# **BOOLEAN EXPERT DISPLAY_IF="{PasswordManager}=='Foswiki::Users::HtPasswdUser'" CHECK="iff:'{PasswordManager} =~ /:HtPasswdUser/'"**
# Enable this option on systems using =FastCGI, FCGID, or Mod_Perl= in
# order to avoid reading the password file for every transaction.
# It will cause the =HtPasswdUser= module to globally cache the password
# file, reading it only once on initization.
$Foswiki::cfg{Htpasswd}{GlobalCache} = $FALSE;

# **BOOLEAN EXPERT DISPLAY_IF="{PasswordManager}=='Foswiki::Users::HtPasswdUser'" CHECK="iff:'{PasswordManager} =~ /:HtPasswdUser$/'"**
# Enable this option if the .htpasswd file can be updated either external to Foswiki
# or by another Foswiki instance, and =GlobalCache= is enabled.  When enabled, Foswiki will verify the timestamp of
# the file and will invalidate the cache if the file has been changed. This is only useful
# if Foswiki is running in a =mod_perl= or =fcgi= envinroment.
$Foswiki::cfg{Htpasswd}{DetectModification} = $FALSE;

# **SELECT bcrypt,'htdigest-md5','apache-md5',sha1,'crypt-md5',crypt,plain DISPLAY_IF="/htpasswd/i.test({PasswordManager})" CHECK="iff:'{PasswordManager}=~/htpasswd/'"**
# Password encryption, for the =Foswiki::Users::HtPasswdUser= password
# manager. This specifies the type of password hash to generate when
# writing entries to =.htpasswd=. It is also used when reading password
# entries unless {Htpasswd}{AutoDetect} is enabled.
# 
# The choices in order of strongest to lowest strength:
#    * =(HTTPS)= - Any encoding over an HTTPS SSL connection.
#      (Not an option here.)
#    * =htdigest-md5= - Strongest only when combined with the
#      =Foswiki::LoginManager::ApacheLogin=. Useful on sites where
#      password files are required to be portable. The {AuthRealm}
#      value is used with the username and password to generate the
#      hashed form of the password, thus: =user:{AuthRealm}:hash=.
#      This encoding is generated by the Apache =htdigest= command.
#    * =bcrypt= - Hash based upon blowfish algorithm, strength of hash
#      controlled by a cost parameter.
#      *Not compatible with Apache Authentication*
#    * =apache-md5= - Enable an Apache-specific algorithm using an iterated
#      (1,000 times) MD5 digest of various combinations of a random
#      32-bit salt and the password (=userid:$apr1$salt$hash=).
#      This is the default, and is the encoding generated by the
#      =htpasswd -m= command.
#    * =sha1= - has the strongest hash, however does not use a salt
#      and is therefore more vulnerable to dictionary attacks.  This
#      is the encoding generated by the =htpasswd -s= command
#      (=userid:{SHA}hash=).
#    * =crypt-md5= -  Enable use of standard libc (/etc/shadow)
#      crypt-md5 password (like =user:$1$salt$hash:email=).  Unlike
#      =crypt= encoding, it does not suffer from password truncation.
#      Passwords are salted, and the salt is stored in the encrypted
#      password string as in normal crypt passwords. This encoding is
#      understood by Apache but cannot be generated by the =htpasswd=
#      command.
#    * =crypt= - encoding uses the first 8 characters of the password.
#      This is the default generated by the Apache =htpasswd= command
#      (=user:hash:email=).  *Not Recommended.*
#    * =plain= - stores passwords as plain text (no encryption). Useful
#      for testing
# If you need to create entries in =.htpasswd= before Foswiki is operational,
# you can use the =htpasswd= or =htdigest= Apache programs to create a new
# password file with the correct encoding. Use caution however as these
# programs do not support the email addresses stored by Foswiki in
# the =.htpasswd= file.
$Foswiki::cfg{Htpasswd}{Encoding} = 'apache-md5';

# **STRING 80 DISPLAY_IF="/htpasswd/i.test({PasswordManager}) && /md5$/.test({Htpasswd}{Encoding})"**
# Authentication realm. You may need to change it
# if you are sharing a password file with another application.
$Foswiki::cfg{AuthRealm} =
'Enter your WikiName. (First name and last name, no space, no dots, capitalized, e.g. JohnSmith). Cancel to register if you do not have one.';

# **BOOLEAN DISPLAY_IF="{PasswordManager}=='Foswiki::Users::HtPasswdUser' && {Htpasswd}{Encoding}!='plain'" CHECK="iff:'{PasswordManager} =~ /:HtPasswdUser$/ && {Htpasswd}{Encoding} ne q<plain>'"**
# Auto-detect the stored password encoding type.  Enable
# this to allow migration from one encoding format to another format.
# Note that this does add a small overhead to the parsing of the =.htpasswd=
# file.  Tests show approximately 1ms per 1000 entries.  It should be used
# with caution unless you are using CGI acceleration such as FastCGI or
# mod_perl. This option is not compatible with =plain= text passwords.
$Foswiki::cfg{Htpasswd}{AutoDetect} = $TRUE;

# **NUMBER DISPLAY_IF="{PasswordManager}=='Foswiki::Users::HtPasswdUser' && {Htpasswd}{Encoding}=='bcrypt'" CHECK="min:0 iff:'{PasswordManager}=~/:HtPasswdUser/ && {Htpasswd}{Encoding} eq q<bcrypt>'"**
# Specify the cost that should be incured when computing the hash of a
# password.  This number should be increased as CPU speeds increase.
# The iterations of the hash is roughly 2^cost - default is 8, or 256
# iterations.
$Foswiki::cfg{Htpasswd}{BCryptCost} = 8;

# **PASSWORD EXPERT**
# SuperAdmin password. (Legacy configuration).  If set, this password
# permits use of the "sudo" facility.  *As it is a "shared password",
# this is no longer recommended per good security practices and is not
# set by default.*  If you want to restore sudo access, set this field
# to a valid hashed password generated by the apache =htpasswd= command
# Example: Set the sudo password to 'password'
# <verbatim>
# htpasswd -nb admin password
# admin:$apr1$3xBPRZAV$iqaC9QyWdzC/93os7A9np1
# </verbatim>
# Paste the everything following the ="admin:"= into this field.
# Do not include the =admin:=
$Foswiki::cfg{Password} = '';

#---++ Registration
# Registration is the process by which new users register themselves with
# Foswiki.

# **BOOLEAN**
# If you want users to be able to use a login ID other than their
# wikiname, you need to turn this on. It controls whether the 'LoginName'
# box appears during the user registration process, and is used to tell
# the User Mapping module whether to map login names to wikinames or not
# (if it supports mappings, that is).
# 
# Note: TopicUserMapping stores the login name in the WikiUsers topic.
# Changing this value on a system with established users can cause login
# issues.
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

# **STRING 40 CHECK="undefok emptyok"**
# Comma-separated list of WikiNames of users who are able to approve
# new registrations. These referees will be sent an email when a new
# user verifies their registration. The referee must click a link in
# the email to approve (or deny) the registration.
# If the approver list is empty, the email will be sent to the wiki
# administrator.
$Foswiki::cfg{Register}{Approvers} = '';

# **NUMBER 20 DISPLAY_IF="{Register}{NeedVerification} || {Register}{NeedApproval}"**
# Set the pending registration timeout, in seconds. The pending registration
# will be cleared after this amount of time. The default is 6 hours
# (21600 seconds).
#
# *Note:* By default, registration expiry is done "on the fly" 
# during the registration process.  For best performance, you can
# set {Register}{ExpireAfter} to a negative number, which will mean
# that Foswiki won't try to clean up expired registrations during
# registration. Instead you should use a cron job to clean up expired
# sessions. The standard maintenance cron script =tools/tick_foswiki.pl=
# includes this function.
#
# *Note:* that if you are using registration approval by 3rd party reviewers,
# this timer should most likely be significantly increased.
#  24 hours = 86400, 3 days = 259200.
#
# Pending registration requests are stored in the
# ={WorkingDir}/registration_approvals= directory.
$Foswiki::cfg{Register}{ExpireAfter} = 21600;

# **BOOLEAN EXPERT**
# Controls whether the user password has to be entered twice on the
# registration page or not. The default is to require confirmation, in which
# case the same password must be provided in the confirmation input.
$Foswiki::cfg{Register}{DisablePasswordConfirmation} = $FALSE;

# **BOOLEAN EXPERT**
# Hide password in registration email to the _user_.
# Note that Foswiki sends administrators a separate confirmation.
$Foswiki::cfg{Register}{HidePasswd} = $TRUE;

# **STRING 20 EXPERT**
# The internal user that creates user topics on new registrations.
# You are recommended not to change this.  Note that if the default
# protection of the users web (Main) is changed, this user must have
# write access to that web.
$Foswiki::cfg{Register}{RegistrationAgentWikiName} = 'RegistrationAgent';

# **BOOLEAN**
# Normally users can register multiple WikiNames using the same email address.
# Enable this parameter to prevent multiple registrations using the same
# email address.
$Foswiki::cfg{Register}{UniqueEmail} = $FALSE;

# **REGEX 80 CHECK="emptyok" EXPERT**
# This regular expression can be used to block certain email addresses
# from being used for registering users.  It can be used to block some
# of the more common wikispam bots. If this regex matches the entered
# address, the registration is rejected.  For example:
# =^.*@(lease-a-seo\.com|paydayloans).*$=
#
# To block all domains and list only the permitted domains, use an
# expression of the format:
# =@(?!(example\.com|example\.net)$)=
$Foswiki::cfg{Register}{EmailFilter} = '';

#---++ Environment
# Control some aspects of the environment Foswiki runs within.

# **PERL**
# Array of the names of configuration items that are available when using
# %IF, %SEARCH and %QUERY{}%. Extensions can push into this array to extend
# the set. This is done as a filter in because while the bulk of configuration
# items are quite innocent, it's better to be a bit paranoid.
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
    '{FormTypes}',
    '{AccessControlACL}{EnableDeprecatedEmptyDeny}'
];

# **BOOLEAN**
# Allow %INCLUDE of URLs. This is disabled by default, because it is possible
# to mount a denial-of-service (DoS) attack on a Foswiki site using INCLUDE and
# URLs. Only enable it if you are in an environment where a DoS attack is not
# a high risk.
#
# You may also need to configure the proxy settings ({PROXY}{HOST} and
# {PROXY}{PORT}) if your server is behind a firewall and you allow %INCLUDE of
# external webpages (see Proxies).
$Foswiki::cfg{INCLUDE}{AllowURLs} = $FALSE;

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
# Regex used to detect illegal names for uploaded (attached) files.
#
# Normally your web server should be configured to control what can be
# done with files in the =pub= directory (see
# [[http://foswiki.org/Support/FaqSecureFoswikiAgainstAttacks#Configure_the_web_server_to_protect_attachments][Support.FaqSecureFoswikiAgainstAttacks]]
# for help doing this. In this case, this configuration item can be set to
# the null string.
#
# On some hosted installations, you don't have access to the web server
# configuration in order to secure it. In this case, you can use this option
# to detect filenames that present a security threat (e.g. that the webserver
# might interpret as executables).
# 
# *Note:* Make sure you update this list with any configuration or script
# filetypes that are automatically run by your web server.
#
# *Note:* this will only filter files during upload. It won't affect
# files that were already uploaded, or files that were created directly
# on the server.
#
$Foswiki::cfg{UploadFilter} = '^(\.htaccess|.*\.(?i)(?:php[0-9s]?(\..*)?|[sp]htm[l]?(\..*)?|pl|py|cgi))$';

# **REGEX EXPERT**
# Filter-out regex for webnames, topic names, file attachment names, usernames,
# include paths and skin names. This is a filter *out*, so if any of the
# characters matched by this expression are seen in names, they will be
# removed.
$Foswiki::cfg{NameFilter} = qr/[\s\*?~^\$@%`"'\x26;|\x3c>\[\]#\x00-\x1f]/;

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
# redirect, not a POST. Enable this *only* in case a Foswiki script
# hangs.
$Foswiki::cfg{DrainStdin} = $FALSE;

# **BOOLEAN EXPERT**
# Remove port number from URL. If set, and a URL is given with a port
# number for example http://my.server.com:8080/foswiki/bin/view, this will strip
# off the port number before using the url in links.
$Foswiki::cfg{RemovePortNumber} = $FALSE;

# **BOOLEAN EXPERT**
# Allow the use of URLs in the =redirectto= parameter to the
# =save= script, and in =topic= parameter to the
# =view= script. *WARNING:* Enabling this feature makes it
# very easy to build phishing pages using the wiki, so in general,
# public sites should *not* enable it. Note: It is possible to
# redirect to a topic regardless of this setting, such as
# =topic=OtherTopic= or =redirectto=Web.OtherTopic=.
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
# server (for example http://proxy.your.company).

# **URL 30 CHECK='undefok emptyok parts:scheme,authority,path,user,pass  \
#              partsreq:scheme,authority \
#              schemes:http,https \
#              authtype:hostip' **
# Hostname or address of the proxy server.
# If your proxy requires authentication, simply put it in the URL, as in:
# http://username:password@proxy.your.company.
$Foswiki::cfg{PROXY}{HOST} = undef;

# **STRING 30 CHECK='undefok emptyok'**
# Some environments require outbound HTTP traffic to go through a proxy
# server. Set the port number here (e.g: 8080).
$Foswiki::cfg{PROXY}{PORT} = undef;

#---++ Anti-spam
# Foswiki incorporates some simple anti-spam measures to protect
# e-mail addresses and control the activities of benign robots, which
# should be enough to handle intranet requirements. Administrators of
# public (internet) sites are strongly recommended to install
# [[http://foswiki.org/Extensions/AntiWikiSpamPlugin][AntiWikiSpamPlugin]]

# **STRING 50 CHECK="undefok emptyok"**
# Text added to e-mail addresses to prevent spambots from grabbing
# addresses. For example set to 'NOSPAM' to get fred@user.co.ru
# rendered as fred@user.coNOSPAM.ru
$Foswiki::cfg{AntiSpam}{EmailPadding} = '';

# **BOOLEAN**
# Normally Foswiki stores the user's sensitive information (such as their e-mail
# address) in a database out of public view. This is to help prevent e-mail
# spam and identity fraud.
#
# This setting controls whether or not the =%USERINFO%= macro will reveal
# details about users other than the current logged in user. It does not
# control how Foswiki actually stores email addresses. If disclosure of
# emails is not a risk for you (for example, you are behind a firewall) and you
# are happy for e-mails to be made public to all Foswiki users, then you
# can disable this option. If you prefer to store email addresses directly
# in user topics, see the TopicUserMapping expert settings under the
# UserMapping tab.
# 
# Note that if this option is set, then the =%USERINFO= macro will only expand
# the =$wikiname=, =$wikiusername= and =$isgroup= tokens.
# All other tokens are ignored for non-admin users.
$Foswiki::cfg{AntiSpam}{HideUserDetails} = $TRUE;

# **BOOLEAN**
# By default Foswiki will also manipulate e-mail addresses to reduce the
#  harvesting of e-mail addresses. Foswiki will encode all non-alphanumeric
# characters to their HTML entity equivalent. for example @ becomes &&lt;nop&gt;#64; 
# This is not completely effective, however it can prevent some primitive
# spambots from seeing the addresses.
$Foswiki::cfg{AntiSpam}{EntityEncode} = $TRUE;

# **BOOLEAN**
# By default, Foswiki doesn't do anything to stop robots, such as those used
# by search engines, from visiting "normal view" pages.
# If you disable this option, Foswiki will generate a META tag to tell robots
# not to index pages. Inappropriate pages (like the raw and edit views) are
# always protected from being indexed.
# Note that for full protection from robots you should also use robots.txt
# (there is an example in the root of your Foswiki installation).
$Foswiki::cfg{AntiSpam}{RobotsAreWelcome} = $TRUE;

#---+ Logging and Statistics
#---++ Logging
# Control how Foswiki handles logging, including location of logfiles.

# **SELECTCLASS none,Foswiki::Logger::*,Foswiki::Logger::PlainFile::* **
# Foswiki supports different implementations of log files. It can be
# useful to be able to plug in a database implementation, for example,
# for a large site, or even provide your own custom logger. Select the
# implementation to be used here. Most sites should be OK with the
# PlainFile logger, which automatically rotates the logs every month.
#
# Note that on very busy systems, this logfile rotation can be disruptive
# and the =Compatibility= logger might perform better.
#
# The =PlainFile::Obfuscating= logger is identical to the =PlainFile=
# logger except that IP addresses are either obfuscated by replacing the
# IP Address with a MD5 Hash, or by completely masking it to x.x.x.x.
# If your regulatory domain prohibits tracking of IP Addresses, use the
# Obfuscating logger. Note that Authentication Errors are never obfuscated.
#
# Note: the Foswiki 1.0 implementation of logfiles is still supported,
# through use of the =Foswiki::Logger::Compatibility= logger.
# Foswiki will automatically select the Compatibility logger if it detects
# a setting for ={WarningFileName}= in your LocalSite.cfg.
$Foswiki::cfg{Log}{Implementation} = 'Foswiki::Logger::PlainFile';

# **PATH**
# Directory where log files will be written.  Note that the Compatibility
# Logger does not use this setting by default.
$Foswiki::cfg{Log}{Dir} = '$Foswiki::cfg{WorkingDir}/logs';

# **BOOLEAN DISPLAY_IF="/PlainFile::Obfuscating/i.test({Log}{Implementation})" CHECK="iff:'{Log}{Implementation} =~ /PlainFile::Obfuscating/'"**
# The Obfuscating logger can either replace IP addresses with a hashed address
# that cannot be easily reversed to the original IP,  or the IP address can
# be completely masked as =x.x.x.x=.  Enable this parameter to replace
# The IP address with the literal string =x.x.x.x=.
$Foswiki::cfg{Log}{Obfuscating}{MaskIP} = $FALSE;

# **PERL EXPERT**
# Whether or not to log different actions in the events log.
# Information in the events log is used in gathering web statistics,
# and is useful as an audit trail of Foswiki activity. Actions
# not listed here will be logged by default.  To disable logging of an action,
# add it to this list if not already present, and set value to 0.
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

# **PATH DISPLAY_IF="/Compatibility/i.test({Log}{Implementation}) || {DebugFileName}"**
# Log file for debug messages when using the Compatibility logger.
# (Usually very low volume.) If =%DATE%= is included in the file name, it gets expanded
# to YYYYMM (year, month), causing a new log to be written each month.
#
# To use the Compatibility logger, set this to a valid file path and name.
#
# Foswiki 1.0.x default: =$Foswiki::cfg{DataDir}/debug.txt=
# or Foswiki 1.1 logging directory =$Foswiki::cfg{Log}{Dir}/debug%DATE%.txt=
$Foswiki::cfg{DebugFileName} = '';

# **PATH DISPLAY_IF="/Compatibility/i.test({Log}{Implementation}) || {WarningFileName}"**
# Log file for Warnings when using the Compatibility logger.
# (Usually low volume) If =%DATE%= is included in the file name, it gets
# expanded to YYYYMM (year, month), causing a new log to be written each month.
#
# To use the Compatibility logger, set this to a valid file path and name.
#
# Foswiki 1.0.x default: =$Foswiki::cfg{DataDir}/warn%DATE%.txt=
# or Foswiki 1.1 logging directory =$Foswiki::cfg{Log}{Dir}/warn%DATE%.txt=
$Foswiki::cfg{WarningFileName} = '';

# **PATH DISPLAY_IF="/Compatibility/i.test({Log}{Implementation}) || {LogFileName}"**
# Log file recording web activity when using the Compatibility logger
# (High volume). If =%DATE%= is included in the file name, it gets expanded
# to YYYYMM (year, month), causing a new log to be written each month.
#
# To use the Compatibility logger, set this to a valid file path and name.
#
# Foswiki 1.0.x default: =$Foswiki::cfg{DataDir}/log%DATE%.txt=
# or Foswiki 1.1 logging directory =$Foswiki::cfg{Log}{Dir}/log%DATE%.txt=
$Foswiki::cfg{LogFileName} = '';

# **PATH DISPLAY_IF="/Compatibility/i.test({Log}{Implementation}) || {ConfigureLogFileName}" CHECK="undefok"**
# Log file recording configuration changes when using the Compatibility logger
# If =%DATE%= is included in the file name, it gets expanded
# to YYYYMM (year, month), causing a new log to be written each month.
#
# To use the Compatibility logger, set this to a valid file path and name.
#
$Foswiki::cfg{ConfigureLogFileName} = undef;

#---++ Statistics
# Statistics are usually assembled by a cron script

# **NUMBER CHECK="min:0" **
# Number of top viewed topics to show in statistics topic
$Foswiki::cfg{Stats}{TopViews} = 10;

# **NUMBER CHECK="min:0" **
# Number of top contributors to show in statistics topic
$Foswiki::cfg{Stats}{TopContrib} = 10;

# **SELECT Prohibited, Allowed, Always**
# Set this parameter to =Allowed= if you want the statistics script to create a
# missing WebStatistics topic only when the parameter =autocreate=1= is
# supplied.
# Set it to =Always= if a missing WebStatistics topic should be created unless
# overridden by URL parameter ='autocreate=0'=.  =Prohibited= is
# the previous behavior and is the default.
$Foswiki::cfg{Stats}{AutoCreateTopic} = 'Prohibited';

# **STRING 20 CHECK="undefok emptyok"**
# If this is set to the name of a Group, then the statistics script will only
# run for members of the specified  and the AdminGroup.  Example:
# Set to =AdminGroup= to restrict statistics to  administrators.
# Default is un-set (anyone can run statistics).
$Foswiki::cfg{Stats}{StatisticsGroup} = '';

# **STRING 20 EXPERT**
# Name of statistics topic.  Note:  If you change the name of the
# statistics topic you must also rename the WebStatistics topic in each web,
# and the DefaultWebStatistics topic in the System web (and possibly in
# the %USERSWEB%).
$Foswiki::cfg{Stats}{TopicName} = 'WebStatistics';

#############################################################################
#---+ Internationalisation
# Foswiki includes powerful features for internationalisation.

#---++ Languages
# **BOOLEAN**
# Enable user interface internationalisation to present the user
# interface in the users own language(s).
# When  enabled, the following settings control the languages that are
# available in the user interface. Check every language that you want
# your site to support.
#
# Allowing all languages is the best for *really* international
# sites, but for best performance you should enable only the languages you
# really need. English is the default language, and is always enabled.
#
# {LocalesDir} is used to find the languages supported in your installation,
# so if the list of available languages is empty, it's probably because
# {LocalesDir} is pointing to the wrong place.
$Foswiki::cfg{UserInterfaceInternationalisation} = $FALSE;

# **BOOLEAN EXPERT DISPLAY_IF="{UserInterfaceInternationalisation}" CHECK="iff:'{UserInterfaceInternationalisation}'"**
# Enable compilation of =.po= string files into compressed =.mo= files.
# This can result in a significant performance improvement for I18N,
# but has also been reported to cause issues on some systems.  So for
# now this is considered experimental.
# 
# Note that if string files are edited, you must re-run configure to recompile
# modified files.  Disable this option to prevent compiling of string files. 
#
# Configure automatically detects out-of-date =.mo= files and recompiles
# them whenever it is run.  Configure removes =.mo= files when this option
# is disabled.
$Foswiki::cfg{LanguageFileCompression} = $FALSE;

# *LANGUAGES* Marker used by bin/configure script - do not remove!

#---++ Locale
# Enable operating system level locales and internationalisation support
# for 8-bit character sets. This may be required for correct functioning
# of the programs that Foswiki calls when your wiki content uses
# international character sets.

# **BOOLEAN EXPERT**
# Enable the use of {Site}{Locale}. WARNING: Perl locales are badly broken
# in some versions of perl. For this reason locales are disabled in Foswiki.
# If you enable them they can be made to work, but you will have to disable
# taint checks, and collation will only work with single-byte character
# sets.
$Foswiki::cfg{UseLocale} = $FALSE;

# **STRING 50 DISPLAY_IF="{UseLocale}" CHECK="iff:'{UseLocale}'"**
# Site-wide locale - used by Foswiki and external programs such as grep, and to
# specify the character set and language in which content must be presented
# for the user's web browser.
# 
# Note that {Site}{Locale} is ignored unless {UseLocale} is set.
# 
# Locale names are not standardised. On Unix/Linux check 'locale -a' on
# your system to see which locales are supported by your system.
# You may also need to check what charsets your browsers accept - the
# 'preferred MIME names' at http://www.iana.org/assignments/character-sets
# are a good starting point.
# 
# WARNING: Topics are stored in site character set format, so data
# conversion of file names and contents will be needed if you change
# locales after creating topics whose names or contents include 8-bit
# characters.
# 
# Examples:
#    * =en.utf8= - English encoded using UTF8
#    * =en_US.ISO-8859-1= - US english with ISO-8859-1 encoding
#    * =de_AT.ISO-8859-15= - Austria with ISO-8859-15 for Euro
#    * =ru_RU.KOI8-R= - Russian encoded using KOI8-R
#    * =ja_JP.eucjp= - Japan
#    * =C= - English only; no I18N features regarding character encodings
#      and external programs.
$Foswiki::cfg{Site}{Locale} = 'en.utf8';

# **STRING 50 **
# Set this to match your site locale (from 'locale -a')
# whose character set is not supported by your available perl conversion module
# (Encode for Perl 5.8 or higher, or Unicode::MapUTF8 for other Perl
# versions).  For example, if the locale 'ja_JP.eucjp' exists on your system
# but only 'euc-jp' is supported by Unicode::MapUTF8, set this to 'euc-jp'.
# If you don't define it, it will automatically be defaulted to iso-8859-1
# $Foswiki::cfg{Site}{CharSet} = undef;

# **SELECT gmtime,servertime**
# Set the timezone (this only effects the display of times,
# all internal storage is still in GMT). May be gmtime or servertimeA
# 
# This item is also used by configure to test if your perl supports early dates.
# Foswiki will still work fine on older versions of perl, but wiki
# applications that use dates somewhere prior to 1970 might encounter issues.
# =configure= tests if 1901-01-01 is handled by the perl localtime function.
$Foswiki::cfg{DisplayTimeValues} = 'gmtime';

# **SELECT '$day $month $year', '$year-$mo-$day', '$year/$mo/$day', '$year.$mo.$day'**
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

# **STRING DISPLAY_IF="! {UseLocale} || ! {Site}{LocaleRegexes}"  CHECK="iff:'! {UseLocale} || ! {Site}{LocaleRegexes}'"**
# If a suitable working locale is not available ({UseLocale}
# is disabled), OR  you are using Perl 5.005 (with or without working
# locales), OR {Site}{LocaleRegexes} is disabled, you can use WikiWords with
# accented national characters by putting any '8-bit' accented
# national characters within these strings . {UpperNational}
# should contain upper case non-ASCII letters.  This is termed
# 'non-locale regexes' mode.
# If 'non-locale regexes' is in effect, WikiWord linking will work,
# but  some features such as sorting of WikiWords in search results
# may not. These features depend on {UseLocale}, which can be set
# independently of {Site}{{LocaleRegexes}, so they will work with Perl
# 5.005 as long as {UseLocale} is set and you have working
# locales.
$Foswiki::cfg{UpperNational} = '';

# **STRING DISPLAY_IF=" ! {UseLocale}" CHECK="iff:'!{UseLocale}'"**
#
$Foswiki::cfg{LowerNational} = '';

# **BOOLEAN**
# Change non-existent plural topic name to singular.
# For example, =TestPolicies= to =TestPolicy=. Only works in English.
$Foswiki::cfg{PluralToSingular} = $TRUE;

#############################################################################
#---+ Store
#---++ Store Implementation
# Foswiki supports different back-end store implementations.

# **SELECTCLASS Foswiki::Store::* **
# Store implementation.
# $Foswiki::cfg{Store}{Implementation} = 'Foswiki::Store::PlainFile';

# **PERL EXPERT**
# Customisation of the Foswiki Store implementation. This allows
# extension modules to hook into the store implementation at a very low level.
# Full class names of customisations must be added to the list, in the order in
# which they will appear in the inheritance hierarchy of the final store
# implementation.
$Foswiki::cfg{Store}{ImplementationClasses} = [];

# **BOOLEAN EXPERT**
# Set to enable (hierarchical) sub-webs. Without this setting, Foswiki will only
# allow a single level of webs. If you set this, you can use
# multiple levels, like a directory tree, webs within webs.
$Foswiki::cfg{EnableHierarchicalWebs} = 1;

# **NUMBER CHECK="min:60" EXPERT**
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
#    * The default 'Forking' algorithm, which forks a subprocess that
#      runs a 'grep' command, is recommended for Linux/Unix.
#      Forking may also work OK on Windows if you keep the directory path
#      to Foswiki very short.
#    * The 'PurePerl' algorithm, which is written in Perl and
#      usually only used for native Windows installations where forking
#      is not stable, due to limitations in the length of command lines.
# On Linux/Unix you will be just fine with the 'Forking' implementation.
# However if you find searches run very slowly, you may want to try a
# different algorithm, which may work better on your configuration.
# For example, there is an alternative algorithm available from
# [[http://foswiki.org/Extensions/NativeSearchContrib][NativeSearchContrib]],
# that usually gives better performance with mod_perl and Speedy CGI, but
# requires root access to install.
#
# Other store implementations and indexing search engines (for example,
# [[http://foswiki.org/Extensions/KinoSearchContrib][KinoSearchContrib]])
# may come with their own search algorithms.
# $Foswiki::cfg{Store}{SearchAlgorithm} = 'Foswiki::Store::SearchAlgorithms::Forking';

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

# **COMMAND EXPERT DISPLAY_IF="{Store}{SearchAlgorithm}=='Foswiki::Store::SearchAlgorithms::Forking'"  CHECK="iff:'{Store}{SearchAlgorithm} =~ /:Forking$/'"**
# Full path to GNU-compatible egrep program. This is used for searching when
# {SearchAlgorithm} is 'Foswiki::Store::SearchAlgorithms::Forking'.
# %CS{|-i}% will be expanded
# to -i for case-sensitive search or to the empty string otherwise.
# Similarly for %DET, which controls whether matching lines are required.
# (see the documentation on these options with GNU grep for details).
$Foswiki::cfg{Store}{EgrepCmd} =
  'grep -E %CS{|-i}% %DET{|-l}% -H -- %TOKEN|U% %FILES|F%';

# **COMMAND EXPERT DISPLAY_IF="{Store}{SearchAlgorithm}=='Foswiki::Store::SearchAlgorithms::Forking'" CHECK="iff:'{Store}{SearchAlgorithm} =~ /:Forking$/'"**
# Full path to GNU-compatible fgrep program. This is used for searching when
# {SearchAlgorithm} is 'Foswiki::Store::SearchAlgorithms::Forking'.
$Foswiki::cfg{Store}{FgrepCmd} =
  'grep -F %CS{|-i}% %DET{|-l}% -H -- %TOKEN|U% %FILES|F%';

#---++ File system settings
# Generic settings

# **BOOLEAN EXPERT DISPLAY_IF="/Foswiki::Store::(Plain|Rcs)/.test({Store}{Implementation})" CHECK="iff:'{Store}{Implementation}=~/Foswiki::Store::(Plain|Rcs)/'"**
# Some systems will override the default umask to a highly restricted setting,
# which will block the application of the file and directory permissions.
# If mod_suexec is enabled, the Apache umask directive will also be ignored.
# Enable this setting if the checker reports that the umask is in conflict with
# the permissions, or adust the expert settings {Store}{dirPermission} and
# {Store}{filePermission} to be consistent with the system umask.
$Foswiki::cfg{Store}{overrideUmask} = $FALSE;

# **OCTAL CHECK="min:000 max:7777" EXPERT**
# File security for new directories created by stores.
# Only used by store implementations that create plain files. You may have
# to adjust these permissions to allow (or deny) users other than the
# webserver user access to directories that Foswiki creates. This is an
# *octal* number representing the standard UNIX permissions
# (for example 755 == rwxr-xr-x)
$Foswiki::cfg{Store}{dirPermission} = 0755;

# **OCTAL CHECK="min:000 max:7777" EXPERT **
# File security for new directories.
# You may have
# to adjust these permissions to allow (or deny) users other than the
# webserver user access to files that Foswiki creates.  This is an
# *octal* number representing the standard UNIX permissions
# (for example 644 == rw-r--r--)
$Foswiki::cfg{Store}{filePermission} = 0644;

#---++ DataForm settings
# Settings that control the available form fields types. Extensions may extend
# the set of available types.

# **PERL**
# This setting is automatically updated by configure to list all the installed
# FormField types. If you install an extension that adds new Form Field types,
# you need to run configure for them to be registered.
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

#############################################################################
#---+ Tuning

#---++ Browser Cache
# Settings for the browser cache are for experts only.

# **PERL EXPERT**
# Disable or change the HTTP Cache-Control header. Foswiki defaults to
# =Cache-Control: max-age=0= which recomends to the browser that it should
# ask foswiki if the topic has changed. If you have a web that does not change
# (like System), you can get the browser to use its cache by setting
# ={'System' => ''}=.
# You can also set =max-age=28800= (for 8 hours), or any other of the
# =Cache-Control= directives.
# 
# Setting the CacheControl to '' also allows you to manage this from your web
# server (which will not over-ride the setting provided by the application),
# thus enabling web server based caching policies. When the user receives a
# browser-cache topic, they can force a refresh using ctrl-r
# 
# This hash must be explicitly set per web or sub-web.
$Foswiki::cfg{BrowserCacheControl} = {};

#---++ HTTP Compression
# Settings controlling compression of the generated HTML, for experts only.

# **BOOLEAN EXPERT**
# Enable gzip/deflate page compression. Modern browsers can uncompress content
# encoded using gzip compression. You will save a lot of bandwidth by
# compressing pages. This makes most sense when enabling page caching as well
# as these are stored in compressed format by default when {HttpCompress} is
# enabled. Note that only pages without any 'dirty areas' will be compressed.
# Any other page will be transmitted uncompressed.
$Foswiki::cfg{HttpCompress} = $FALSE;

#---++ HTML Page Layout
# Settings controlling the layout of the generated HTML, for experts only.

# **BOOLEAN EXPERT**
# {MergeHeadAndScriptZones} is provided to maintain compatibility with
# legacy extensions that use =ADDTOHEAD= to add =script= markup and require
# content that is now in the =script= zone.
# 
# Normally, dependencies between individual =ADDTOZONE= statements are
# resolved within each zone. However, if {MergeHeadAndScriptZones} is
# enabled, then =head= content which requires an =id= that only exists
# in =script= (and vice-versa) will be re-ordered to satisfy any dependency.
#
# WARNING: {MergeHeadAndScriptZones} will be removed from a future version
# of Foswiki.
$Foswiki::cfg{MergeHeadAndScriptZones} = $FALSE;

#---++ Cache
# Foswiki includes built-in support for caching HTML pages. This can
# dramatically increase performance, especially if there are a lot more page
# views than changes.
# The cache has a number of setup and tuning parameters. You should read
# [[http://foswiki.org/System/PageCaching][Page Caching]] on
# foswiki.org (or your local copy of this page in the System web) before
# enabling the cache. It is important that you read this topic carefully
# as the cache also has some major disadvantages with respect to formatted
# searches.

# **BOOLEAN**
# This setting will switch on/off caching.
$Foswiki::cfg{Cache}{Enabled} = $FALSE;

# **BOOLEAN EXPERT DISPLAY_IF="{Cache}{Enabled}" CHECK="iff:'{Cache}{Enabled}'"**
# Enable cache debug - UI::View and UI::Rest record debug messages.
$Foswiki::cfg{Cache}{Debug} = $FALSE;

# **PATH DISPLAY_IF="{Cache}{Enabled}" CHECK="iff:'{Cache}{Enabled}'"**
# Specify the directory where binary large objects will be stored.
$Foswiki::cfg{Cache}{RootDir} = '$Foswiki::cfg{WorkingDir}/cache';

# **STRING 80 DISPLAY_IF="{Cache}{Enabled}" CHECK="iff:'{Cache}{Enabled}'"**
# List of those topics that have a manual dependency on every topic
# in a web. Web dependencies can also be specified using the WEBDEPENDENCIES
# preference, which overrides this setting.
$Foswiki::cfg{Cache}{WebDependencies} =
  'WebRss, WebAtom, WebTopicList, WebIndex, WebSearch, WebSearchAdvanced';

# **REGEX DISPLAY_IF="{Cache}{Enabled}" CHECK="iff:'{Cache}{Enabled}'"**
# Exclude topics that match this regular expression from the dependency
# tracker.
$Foswiki::cfg{Cache}{DependencyFilter} =
  '$Foswiki::cfg{SystemWebName}\..*|$Foswiki::cfg{TrashWebName}\..*|TWiki\..*';

# **SELECTCLASS Foswiki::PageCache::DBI::* DISPLAY_IF="{Cache}{Enabled}" CHECK="iff:'{Cache}{Enabled}'"**
# Select the cache implementation. The default page cache implementation
# is based on DBI (http://dbi.perl.org) which requires a working DBI driver to
# connect to a database. This database will hold all cached data as well as the
# maintenance data to keep the cache correct while content changes in the wiki.
# Recommended drivers are DBD::mysql, DBD::Pg, DBD::SQLite or any other
# database driver connecting to a real SQL engine.
$Foswiki::cfg{Cache}{Implementation} = 'Foswiki::PageCache::DBI::Generic';

# **STRING 80 DISPLAY_IF="{Cache}{Enabled} && /Foswiki::PageCache::DBI.*/.test({Cache}{Implementation}) " CHECK="iff:'{Cache}{Enabled} && {Cache}{Implementation}=~/PageCache::DBI.*/'"**
# Prefix used naming tables and indexes generated in the database.
$Foswiki::cfg{Cache}{DBI}{TablePrefix} = 'foswiki_cache';

# **STRING 80 DISPLAY_IF="{Cache}{Enabled} && {Cache}{Implementation} == 'Foswiki::PageCache::DBI::Generic' " CHECK="iff:'{Cache}{Enabled} && {Cache}{Implementation} =~ /Generic$/'"**
# Generic database driver. See the docu of your DBI driver for the exact syntax of the DSN parameter string.
$Foswiki::cfg{Cache}{DBI}{DSN} = '';

# **STRING 80 DISPLAY_IF="{Cache}{Enabled} && {Cache}{Implementation} == 'Foswiki::PageCache::DBI::Generic' " CHECK="iff:'{Cache}{Enabled} && {Cache}{Implementation} =~ /DBI::Generic$/ '"**
# Database user name. Add a value if your database needs authentication
$Foswiki::cfg{Cache}{DBI}{Username} = '';

# **PASSWORD 80 DISPLAY_IF="{Cache}{Enabled} && {Cache}{Implementation} == 'Foswiki::PageCache::DBI::Generic' " CHECK="iff:'{Cache}{Enabled} && {Cache}{Implementation} =~ /DBI::Generic$/'"**
# Database user password. Add a value if your database needs authentication
$Foswiki::cfg{Cache}{DBI}{Password} = '';

# **STRING 80 DISPLAY_IF="{Cache}{Enabled} && {Cache}{Implementation} == 'Foswiki::PageCache::DBI::SQLite'" CHECK="iff:'{Cache}{Enabled} && {Cache}{Implementation} =~ /DBI::SQLite$/'"**
# Name of the SQL
$Foswiki::cfg{Cache}{DBI}{SQLite}{Filename} =
  '$Foswiki::cfg{WorkingDir}/sqlite.db';

# **STRING 80 DISPLAY_IF="{Cache}{Enabled} && {Cache}{Implementation} == 'Foswiki::PageCache::DBI::MySQL' " CHECK="iff:'{Cache}{Enabled} && {Cache}{Implementation} =~ /DBI::MySQL$/'"**
# Name or IP address of the database server
$Foswiki::cfg{Cache}{DBI}{MySQL}{Host} = 'localhost';

# **STRING 80 DISPLAY_IF="{Cache}{Enabled} && {Cache}{Implementation} == 'Foswiki::PageCache::DBI::MySQL' " CHECK="iff:'{Cache}{Enabled} && {Cache}{Implementation} =~ /DBI::MySQL$/ '"**
# Port on the database server to connect to
$Foswiki::cfg{Cache}{DBI}{MySQL}{Port} = '';

# **STRING 80 DISPLAY_IF="{Cache}{Enabled} && {Cache}{Implementation} == 'Foswiki::PageCache::DBI::MySQL' " CHECK="iff:'{Cache}{Enabled} && {Cache}{Implementation} =~ /DBI::MySQL$/ '"**
# Name of the database on the server host.
$Foswiki::cfg{Cache}{DBI}{MySQL}{Database} = '';

# **STRING 80 DISPLAY_IF="{Cache}{Enabled} && {Cache}{Implementation} == 'Foswiki::PageCache::DBI::MySQL' " CHECK="iff:'{Cache}{Enabled} && {Cache}{Implementation} =~ /DBI::MySQL$/ '"**
# Database user name. Add a value if your database needs authentication
$Foswiki::cfg{Cache}{DBI}{MySQL}{Username} = '';

# **PASSWORD 80 DISPLAY_IF="{Cache}{Enabled} && {Cache}{Implementation} == 'Foswiki::PageCache::DBI::MySQL' " CHECK="iff:'{Cache}{Enabled} && {Cache}{Implementation} =~ /DBI::MySQL/ '"**
# Database user password. Add a value if your database needs authentication
$Foswiki::cfg{Cache}{DBI}{MySQL}{Password} = '';

# **STRING 80 DISPLAY_IF="{Cache}{Enabled} && {Cache}{Implementation} == 'Foswiki::PageCache::DBI::PostgreSQL' " CHECK="iff:'{Cache}{Enabled} && {Cache}{Implementation} =~ /DBI::PostgreSQL$/ '"**
# Name or IP address of the database server
$Foswiki::cfg{Cache}{DBI}{MySQL}{Host} = 'localhost';

# **STRING 80 DISPLAY_IF="{Cache}{Enabled} && {Cache}{Implementation} == 'Foswiki::PageCache::DBI::PostgreSQL' " CHECK="iff:'{Cache}{Enabled} && {Cache}{Implementation} =~ /DBI::PostgreSQL$/ '"**
# Port on the database server to connect to
$Foswiki::cfg{Cache}{DBI}{PostgreSQL}{Port} = '';

# **STRING 80 DISPLAY_IF="{Cache}{Enabled} && {Cache}{Implementation} == 'Foswiki::PageCache::DBI::PostgreSQL' " CHECK="iff:'{Cache}{Enabled} && {Cache}{Implementation} =~ /DBI::PostgreSQL$/ '"**
# Name of the database on the server host.
$Foswiki::cfg{Cache}{DBI}{PostgreSQL}{Database} = '';

# **STRING 80 DISPLAY_IF="{Cache}{Enabled} && {Cache}{Implementation} == 'Foswiki::PageCache::DBI::PostgreSQL' " CHECK="iff:'{Cache}{Enabled} && {Cache}{Implementation} =~ /DBI::PostgreSQL$/ '"**
# Database user name. Add a value if your database needs authentication
$Foswiki::cfg{Cache}{DBI}{PostgreSQL}{Username} = '';

# **PASSWORD 80 DISPLAY_IF="{Cache}{Enabled} && {Cache}{Implementation} == 'Foswiki::PageCache::DBI::PostgreSQL' " CHECK="iff:'{Cache}{Enabled} && {Cache}{Implementation} =~ /DBI::PostgreSQL$/ '"**
# Database user password. Add a value if your database needs authentication
$Foswiki::cfg{Cache}{DBI}{PostgreSQL}{Password} = '';

#############################################################################
#---+ Mail
# Settings controlling if and how Foswiki sends email. Mail is used by Foswiki
# to send out notifications of events, such as topic changes.
# Foswiki can send mail using a SMTP server, or using a local mail program
# such as =sendmail=. Mail can be sent in plain text or over SSL. You can
# set up S/MIME certificates to sign mails sent by Foswiki.

#---++ Basic Setup
# Basic settings controlling if and how Foswiki handles email including the
# identity of the sender.
# <br/><br/>
# <ul><li>If your server is already able to send email, with a local agent like =sendmail=
# or =ssmtp=, <br/>you can fill in ={WebMasterEmail}= and click the Auto-configure button.
# It might just work.</li>
# <li>If you want to send email directly from perl, you must provide
# an ={SMTP}{MAILHOST}=. <br/>If your mail server requires authentication, you must also
# supply ={SMTP}{Username}= and ={SMTP}{Password}= </li></ul>
# <br/>
# Auto-configure Email may change configuration settings (it will tell you
# what it changed.) These settings will only be made permanent when you save
# the configuration.

# **EMAILADDRESS 30**
# Wiki administrator's e-mail address. For example =webmaster@example.com=
# Must be a single valid email address.  This value is displayed using the =<nop>%WIKIWEBMASTER%= macro.
$Foswiki::cfg{WebMasterEmail} = '';

# **STRING 30**
# Wiki administrator's name address.
# For use in mails (first name and last name, for example =Fred Smith=).
#  This value is displayed using the =<nop>%WIKIWEBMASTERNAME%= macro.
$Foswiki::cfg{WebMasterName} = 'Wiki Administrator';

# **STRING 30 **
# Optional mail host for outgoing mail, required if Net::SMTP is being used.
# Examples: =mail.your.company= If the smtp server uses a different port
# than the default 25, use the syntax =mail.your.company:portnumber=,
# or omit it to allow autoconfiguration to attempt to discover it for you.
#
# Although not recommended, you can also specify an IP address using
# the syntax =192.0.2.11= or =[2001:db8::beef]=.  If necessary,
# a port number may be added to either form =:587=.
#
# For Gmail, set {SMTP}{MAILHOST} to =smtp.gmail.com=,
# provide your gmail email address and password for authentication, and use
# auto-configuration.
$Foswiki::cfg{SMTP}{MAILHOST} = '';

# **STRING 30 DISPLAY_IF="{SMTP}{MAILHOST}!=''"**
# Username for SMTP. Only required if your mail server requires authentication.
# If this is left blank, Foswiki will not attempt to authenticate the mail
# sender.
$Foswiki::cfg{SMTP}{Username} = '';

# **PASSWORD 30 DISPLAY_IF="{SMTP}{MAILHOST}!=''"**
# Password for your {SMTP}{Username}.
$Foswiki::cfg{SMTP}{Password} = '';

# **BOOLEAN FEEDBACK="label='Auto-configure Email'; wizard='AutoConfigureEmail'; method='autoconfigure'" FEEDBACK="label='Send Test Email';wizard='SendTestEmail'; method='send'" DISPLAY_IF="{WebMasterEmail}!=''"**
# Enable email globally.  Un-check this option to disable all outgoing
# email from Foswiki. If this option is enabled, email must be functional
# for registration to be functional.
#
#
# If you press the Auto-configure button, email will be automatically enabled if
# autoconfiguration works. After Auto-configure finishes, press the "Send Test Email" button to send a test message.

$Foswiki::cfg{EnableEmail} = $FALSE;

#
#---++ Signed Email (S/MIME)
# Settings for S/MIME-signed email.
# Configure signing of outgoing email. (Secure/Multipurpose Internet
# Mail Extensions) is a standard for public key encryption and signing
# of MIME encoded email messages. Messages generated by the server will
# be signed using an X.509 certificate.
#
# Certificates for Secure Email may be obtained from a vendor or private
# certificate authority.  You can also use the action buttons to generate
# certificates or certificate requests if OpenSSL is installed.
# The buttons are used to generate certificates for S/MIME
# signed Secure Email.  There are two ways to use this:
#
# *Self signed certificates:*
# The =Generate S/MIME Certificate= button will generate a self-signed
# S/MIME certificate and install it. If you use this option, you will
# have to arrange for your users' e-mail clients to trust this certificate.
# This type of certificate is adequate for a small user base and for testing.
# 
# *Certificate Authority signed certificates:*
# The =Generate S/MIME CSR= button is used to create private key and
# a _Certificate Signing Request_ (CSR) for use by your private Certificate
# Authority or by a trusted commercial Certificate authority.
# The =Cancel CSR= button is used to delete a pending request.
# The S/MIME Certificate information in the *Certificate Management*
# section must be completed for CSR's to work correctly.
#
# **BOOLEAN \
#   FEEDBACK="label='Generate S/MIME Certificate';span=2; \
#             title='Generate a self-signed certficate for the WebMaster.  \
#                    This allows immediate use of signed email.'; \
#             wizard='SMIMECertificate'; method='generate_cert'"\
#   FEEDBACK="label='Generate S/MIME CSR';col=1;\
#             title='Generate a Certificate Signing Request for the \
#                    WebMaster. This request must be signed by a \
#                    Certificate Authority to create a certificate, \
#                    then installed.';\
#             wizard='SMIMECertificate'; method='request_cert'"\
#   FEEDBACK="label='Cancel CSR';\
#             title='Cancel a pending Certificate Signing request. \
#                    This destroys the private key associated with \
#                    the request.';\
#             wizard='SMIMECertificate'; method='cancel_cert'" **
# Enable to sign all e-mails sent by Foswiki using S/MIME.
$Foswiki::cfg{Email}{EnableSMIME} = $FALSE;

# **PATH DISPLAY_IF="{Email}{EnableSMIME}" CHECK="iff:'{Email}{EnableSMIME}'"**
# Specify the file containing the administrator's X.509 certificate.  It
# must be in PEM format.
#
# If your issuer requires an intermediate CA certificate(s), include them
# in this file after the sender's certificate in order from least to most
# authoritative CA.
#
# Leave blank if you are using a Foswiki-generated Self-signed certificate
# or a certificate installed from a Foswiki-generated CSR.
$Foswiki::cfg{Email}{SmimeCertificateFile} = '';

# **PATH DISPLAY_IF="{Email}{EnableSMIME}" CHECK="iff:'{Email}{EnableSMIME}'"**
# Specify the file containing the private key corresponding to the
# administrator's X.509 certificate. It must be in PEM format.
#
# *Make sure that this file is only readable by the Foswiki software;*
# *it must NOT be readable by users!*
#
# Leave blank if you are using a Foswiki-generated Self-signed certificate
# or a certificate installed from a Foswiki-generated CSR.
$Foswiki::cfg{Email}{SmimeKeyFile} = '';

# **PASSWORD 30 DISPLAY_IF="{Email}{EnableSMIME}" CHECK="iff:'{Email}{EnableSMIME}'"**
# If the file containing the certificate's private key is encrypted, specify
# the password. Otherwise leave blank.
#
# Currently only DES3 encryption is supported, but you can convert
# other files with *openssl* as follows:
# <verbatim>
# openssl rsa -in keyfile.pem -out keyfile.pem -des3
# </verbatim>
# If you are using a Foswiki-generated Self-signed certificate
# or a certificate installed from a Foswiki-generated CSR, this field
# is automatically generated and must not be changed.
$Foswiki::cfg{Email}{SmimeKeyPassword} = '';

#---++ Certificate Management
# The following parameters can be used to specify commonly used components
# of the subject name for Certificate Signing Requests.

# **STRING DISPLAY_IF="{Email}{EnableSMIME}" CHECK="iff:'{Email}{EnableSMIME}'"**
# ISO country code (2 letters)
$Foswiki::cfg{Email}{SmimeCertC} = '';

# **STRING DISPLAY_IF="{Email}{EnableSMIME}" CHECK="iff:'{Email}{EnableSMIME}'"**
# State or Province
$Foswiki::cfg{Email}{SmimeCertST} = '';

# **STRING DISPLAY_IF="{Email}{EnableSMIME}" CHECK="iff:'{Email}{EnableSMIME}'"**
# Locality (city or town)
$Foswiki::cfg{Email}{SmimeCertL} = '';

# **STRING DISPLAY_IF="{Email}{EnableSMIME}" CHECK="iff:'{Email}{EnableSMIME}'"**
# Organization
$Foswiki::cfg{Email}{SmimeCertO} = '';

# **STRING DISPLAY_IF="{Email}{EnableSMIME}" CHECK="iff:'{Email}{EnableSMIME}'"**
# Organizational unit. For example Department.
$Foswiki::cfg{Email}{SmimeCertOU} = '';

#---++ Advanced Setup
# These are settings for advanced or uncommon configurations, and for debugging.

# **SELECT 'Net::SMTP',\
#          'Net::SMTP (SSL)',\
#          'Net::SMTP (TLS)',\
#          'Net::SMTP (STARTTLS)',\
#          MailProgram \
#          DISPLAY_IF="{EnableEmail}"  CHECK="iff:'{EnableEmail}'"**
# Select the method Foswiki will use for sending email.  On Unix/Linux hosts
# "MailProgram" is generally acceptable, although Net::SMTP provides better
# diagnostics when things go amiss.  Otherwise choose one of the Email
# methods required by your ISP or Email server.
# You can select a method manually,  or use the "Auto-configure" button to
# determine the best connection type for your ISP or Email server.
# Auto-configure requires {SMTP}{MAILHOST}, but you can leave everything else
# blank.  You'll be told if the server requires a username and password.
$Foswiki::cfg{Email}{MailMethod} = 'Net::SMTP';

# **COMMAND DISPLAY_IF="{EnableEmail} && {Email}{MailMethod} == 'MailProgram'" CHECK="iff:'{EnableEmail} && {Email}{MailMethod} eq q<MailProgram>'"**
# This needs to be a command-line program that accepts
# MIME format mail messages on standard input, and mails them.
$Foswiki::cfg{MailProgram} = '/usr/sbin/sendmail -t -oi -oeq';

# **BOOLEAN DISPLAY_IF="{EnableEmail}" CHECK="iff:'{EnableEmail}'"**
# Set this option on to enable email debugging.
# Output will go to the webserver error log.
$Foswiki::cfg{SMTP}{Debug} = 0;

# **STRING 30 DISPLAY_IF="{EnableEmail} && {Email}{MailMethod} == 'MailProgram'" CHECK="iff:'{EnableEmail} && {Email}{MailMethod} eq q<MailProgram>'"**
# Flags passed to the mail program.
# Used when a {MailProgram} is selected and {SMTP}{Debug} is enabled.
# Flags are in addition to any specified with
# the program.  These flags should enable tracing of the SMTP
# transactions to debug configuration issues.
#
# The default flags are correct for the =sendmail= program
# on many Unix/Linux systems.  Note, however that =sendmail=
# will drop its privileges when running with -X.  You must arrange
# for the client queue files (. =/var/spool/clientmqueue/=)
# to be read and writable by the webserver for the duration of any
# testing.

$Foswiki::cfg{SMTP}{DebugFlags} = '';

# **STRING 30 \
#           DISPLAY_IF="{EnableEmail} && /^Net::SMTP/.test({Email}{MailMethod})" CHECK="iff:'{EnableEmail} && {Email}{MailMethod} =~ /^Net::SMTP/'"**
# Mail domain sending mail. SMTP requires that you identify yourself.
# This option specifies a string to pass to the mail host as your mail
# domain. If not given, then EHLO/HELO will not be sent to the mail host,
# which may result in your connection being rejected.
# Example: foswiki.your.company.
$Foswiki::cfg{SMTP}{SENDERHOST} = '';

# **BOOLEAN \
#           DISPLAY_IF="{EnableEmail} && /^Net::SMTP/.test({Email}{MailMethod})" CHECK="iff:'{EnableEmail} && {Email}{MailMethod} =~ /^Net::SMTP/'"**
# Verify that server's certificate contains the expected hostname when using 
# an SSL (or STARTTLS) connection.
# This verifies the identity of the server to which mail is sent.
$Foswiki::cfg{Email}{SSLVerifyServer} = $FALSE;

# **PATH EXPERT \
#               FEEDBACK="label='Guess certificate locations'; wizard='SSLCertificates'; method='guess_locations'"\
#               DISPLAY_IF="{EnableEmail} && /^Net::SMTP/.test({Email}{MailMethod}) && {Email}{SSLVerifyServer}"**
# Specify the file used to verify the server certificate trust chain.
# This is the list of root Certificate authorities that you trust to issue
# certificates. You do not need to include intermedite CAs in this file.
# If you do not specify this or {Email}{SSLCaPath}, system defaults will
# be used.
$Foswiki::cfg{Email}{SSLCaFile} = '';

# **PATH EXPERT \
#               FEEDBACK="label='Guess certificate locations'; wizard='SSLCertificates'; method='guess_locations'"\
#               FEEDBACK='label="Validate Contents"; wizard="SSLCertificates"; method="validate";\
#               title="Examines every file in the directory and verifies \
#               that the contents look like certificates/and/or CRLs"' \
#               DISPLAY_IF="{EnableEmail} && /^Net::SMTP/.test({Email}{MailMethod}) && {Email}{SSLVerifyServer}"**
# Specify the directory used to verify the server certificate trust chain.
# This is the list of root Certificate authorities that you trust to issue
# certificates. You do not need to include intermedite CAs in this directory.
# If you do not specify this or {Email}{SSLCaFile}, system defaults will be used.
# Refer to the openssl documentation for the format of this directory.
# Note that it can also contain Certificate Revocation Lists.
$Foswiki::cfg{Email}{SSLCaPath} = '';

# **BOOLEAN EXPERT \
#           DISPLAY_IF="{EnableEmail} && /^Net::SMTP/.test({Email}{MailMethod}) && {Email}{SSLVerifyServer}"**
# Enable this option to verify that the server's certificate has not been
# revoked by the issuing authority.  If you enable this option, you should
# ensure that you have a mechanism established to periodically obtain
# updated CRLs from the CAs that you trust.  The CRLs may be specified in
# a separate file {Email}{SSLCrlFile}, or in {Email}{SSLCaPath}.
$Foswiki::cfg{Email}{SSLCheckCRL} = $FALSE;

# **PATH EXPERT \
#               DISPLAY_IF="/^Net::SMTP/.test({Email}{MailMethod}) && {Email}{SSLCheckCRL}"**
# Specify a file containing all the revoked certificates (CRLs) from all
# your CAs. If you trust more than a few CAs, it's probably better to use
# {Email}{SSLCaPath}. Be sure to establish a periodic update mechanism.
$Foswiki::cfg{Email}{SSLCrlFile} = '';

# **PATH EXPERT \
#             DISPLAY_IF="{EnableEmail} && /^Net::SMTP/.test({Email}{MailMethod})"**
# If your email server requires a X.509 client certificate, specify the path
# to the file that contains it.
# (This is unusual.)
# It must be in PEM format.
$Foswiki::cfg{Email}{SSLClientCertFile} = '';

# **PATH EXPERT \
#             DISPLAY_IF="{EnableEmail} && /^Net::SMTP/.test({Email}{MailMethod}) && {Email}{SSLClientCertFile}.length"**
# Specify the file containing the private key corresponding to the X.509
# certificate used to connect to the server. It must be in PEM format.
#
# *Make sure that this file is only readable by the Foswiki software;*
# *it must NOT be readable by users!*
$Foswiki::cfg{Email}{SSLClientKeyFile} = '';

# **PASSWORD 30 EXPERT \
#            DISPLAY_IF="{EnableEmail} && /^Net::SMTP/.test({Email}{MailMethod}) && {Email}{SSLClientKeyFile}.length"**
# If the file containing the certificate's private key is encrypted, specify
# the password. Otherwise leave blank.
$Foswiki::cfg{Email}{SSLClientKeyPassword} = '';

# **BOOLEAN EXPERT DISPLAY_IF="{EnableEmail}" CHECK="iff:'{EnableEmail}'"**
# Send email Date header using local "server time" instead of GMT
$Foswiki::cfg{Email}{Servertime} = $FALSE;

# **REGEX 80 EXPERT DISPLAY_IF="{EnableEmail}" CHECK="iff:'{EnableEmail}'"**
# This parameter is used to determine which Top Level domains are valid
# when auto-linking email addresses.  It is also used by UserRegistration to
# validate email addresses.  Note, this parameter _only_ controls
# matching of 3 character and longer TLDs.   2-character country codes and
# IP Address domains always permitted.  See:
# Valid TLD's at http://data.iana.org/TLD/tlds-alpha-by-domain.txt
# Version 2012022300, Last Updated Thu Feb 23 15:07:02 2012 UTC
$Foswiki::cfg{Email}{ValidTLD} =
qr(AERO|ARPA|ASIA|BIZ|CAT|COM|COOP|EDU|GOV|INFO|INT|JOBS|MIL|MOBI|MUSEUM|NAME|NET|ORG|PRO|TEL|TRAVEL|XXX)i;

#---+ Miscellaneous
# Miscellaneous expert options.

# **STRING 20 CHECK='undefok' EXPERT**
# The name of the host operating system. This is automatically calculated
# in the code. You should only need to override if your Perl doesn't provide
# the value of $^O or $Config::Config{'osname'} (an exceptional
# situtation never yet encountered)
# $Foswiki::cfg{DetailedOS} = '';

# **STRING 20 CHECK='undefok' EXPERT**
# One of UNIX WINDOWS VMS DOS MACINTOSH OS2
# This is automatically calculated in the code based on the value of
# {DetailedOS}. It is used to group OS's into generic groups based on their
# behaviours - for example, 
#
# $Foswiki::cfg{OS} = '';

# **NUMBER CHECK="min:-1 undefok" EXPERT**
# Maximum number of backup versions of LocalSite.cfg to retain when changes
# are saved.  Enables you to recover quickly from accidental changes.
# 0 does not save any backup versions.  -1 does not limit the number of
# versions retained. Caution: If the directory is not writable and this
# parameter is non-zero, you will be unable to save the configuration.
$Foswiki::cfg{MaxLSCBackups} = 10;

# **STRING 20 EXPERT**
# Name of the web where documentation and default preferences are held. If you
# change this setting, you must make sure the web exists and contains
# appropriate content, and upgrade scripts may no longer work (don't
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
# *If you change this setting you will have to
# use Foswiki and *manually* rename the existing topic.*
# (don't change it unless you are *certain* that you know what
# you are doing!)
$Foswiki::cfg{SitePrefsTopicName} = 'DefaultPreferences';

# **STRING 70 EXPERT**
# Web.TopicName of the site-level local preferences topic. If this topic
# exists, any settings in it will *override* settings in
# {SitePrefsTopicName}.
#
# You are *strongly* recommended to keep all your local changes in
# a {LocalSitePreferences} topic rather than changing DefaultPreferences,
# as it will make upgrading a lot easier.
$Foswiki::cfg{LocalSitePreferences} =
  '$Foswiki::cfg{UsersWebName}.SitePreferences';

# **STRING 20 EXPERT**
# Name of main topic in a web.
# *If you change this setting you will have to
# use Foswiki to manually rename the topic in all existing webs*
# (don't change it unless you are *certain* that you know what
# you are doing!)
$Foswiki::cfg{HomeTopicName} = 'WebHome';

# **STRING 20 EXPERT**
# Name of preferences topic in a web.
# *If you change this setting you will have to
# use Foswiki to manually rename the topic in all existing webs*
# (don't change it unless you are *certain* that you know what
# you are doing!)
$Foswiki::cfg{WebPrefsTopicName} = 'WebPreferences';

# **STRING 20 EXPERT**
# Name of topic in each web that has notification registrations.
# *If you change this setting you will have to
# use Foswiki to manually rename the topic in all existing webs*
$Foswiki::cfg{NotifyTopicName} = 'WebNotify';

# **STRING 20 EXPERT**
# Name of the web where user and group topics are stored. If you
# change this setting, you must make sure the web exists and contains
# appropriate content including all user and group templates.  Note that
# this web also houses the SitePreferences topic.
# (don't change it unless you are *certain* that you know what
# you are doing!)
$Foswiki::cfg{UsersWebName} = 'Main';

# **STRING 70x10 NOSPELLCHECK EXPERT**
# A comma-separated list of generic file name templates that defines the order
# in which templates are assigned to skin path components.
# The file name templates can either be absolute file names ending in ".tmpl"
# or a topic name in a Foswiki web. The file names may contain
# these placeholders: =$name= (the template name), =$web=
# (the web), and =$skin= (the skin).
# Finding the right template file is done by following the skin path, and for
# each skin path component following the template path.
# The first file on the skin path + template path that is found is taken to be
# the requested template file.
# See 'Security and usability' in System.SkinTemplates for advice on
# setting this path for increased security.
$Foswiki::cfg{TemplatePath} =
'$Foswiki::cfg{TemplateDir}/$web/$name.$skin.tmpl, $Foswiki::cfg{TemplateDir}/$name.$skin.tmpl, $web.$skinSkin$nameTemplate, $Foswiki::cfg{SystemWebName}.$skinSkin$nameTemplate, $Foswiki::cfg{TemplateDir}/$web/$name.tmpl, $Foswiki::cfg{TemplateDir}/$name.tmpl, $web.$nameTemplate, $Foswiki::cfg{SystemWebName}.$nameTemplate';

# **STRING 120 EXPERT**
# List of protocols (URI schemes) that Foswiki will
# automatically recognize in absolute links.
# Add any extra protocols specific to your environment (for example, you might
# add 'imap' or 'pop' if you are using shared mailboxes accessible through
# your browser, or 'tel' if you have a softphone setup that supports links
# using this URI scheme). A list of popular URI schemes can be
# found in [[http://en.wikipedia.org/wiki/URI_scheme][Wikipedia]].
$Foswiki::cfg{LinkProtocolPattern} =
  '(file|ftp|gopher|https|http|irc|mailto|news|nntp|telnet)';

# **NUMBER CHECK="min:2" EXPERT**
# Length of linking acronyms.  Minumum number of consecutive upper case
# characters required to be linked as an acronym.
$Foswiki::cfg{AcronymLength} = 3;

# **BOOLEAN EXPERT**
# 'Anchors' are positions within a Foswiki page that can be targeted in
# a URL using the =#anchor= syntax. The format of these anchors has
# changed several times. If this option is set, Foswiki will generate extra
# redundant anchors that are compatible with the old formats. If it is not
# set, the links will still work but will go to the head of the target page.
# There is a small performance cost for enabling this option. Set it if
# your site has been around for a long time, and you want existing external
# links to the internals of pages to continue to work.
$Foswiki::cfg{RequireCompatibleAnchors} = 0;

# **NUMBER CHECK="min:0" **
# How many links to other revisions to show in the bottom bar. 0 for all
$Foswiki::cfg{NumberOfRevisions} = 4;

# **NUMBER CHECK="min:1" EXPERT**
# Set the upper limit of the maximum number of difference that will be
# displayed when viewing the entire history of a page. The compared revisions
# will be evenly spaced across the history of the page, for example if the
# page has 100 revisions and we have set this option to 10, we will see
# differences between r100 and r90, r90 and r80, r80 and r70 and so on.
#
# This is only active for the =bin/rdiff= command.  It is not used by the
# CompareRevisionsAddOn.
$Foswiki::cfg{MaxRevisionsInADiff} = 25;

# **NUMBER CHECK="min:0" EXPERT**
# If this is set to a > 0 value, and the revision control system
# supports it, then if a second edit of the same topic
# is done by the same user within this number of seconds, a new
# revision of the topic will NOT be created (the top revision will
# be replaced). Set this to 0 if you want *all* topic changes to create
# a new revision (as required by most formal development processes).
$Foswiki::cfg{ReplaceIfEditedAgainWithin} = 3600;

# **NUMBER CHECK="min:60" EXPERT **
# When a topic is edited, the user takes a "lease" on that topic.
# If another user tries to also edit the topic while the lease
# is still active, they will get a warning. Leases are released
# automatically when the topic is saved; otherwise they remain active
# for {LeaseLength} seconds from when the edit started (or was checkpointed).
# 
# Note: Leases are *not* locks; they are purely advisory. Leases
# can always be broken, but they are valuable if you want to avoid merge
# conflicts (for example you use highly structured data in your topic text and
# want to avoid ever having to deal with conflicts)
# 
# Since Foswiki 1.0.6, Foswiki pages that can be used to POST to the
# server have a validation key, that must be sent to the server for the
# post to succeed. These validation keys can only be used once, and expire
# at the same time as the lease expires.
$Foswiki::cfg{LeaseLength} = 3600;

# **NUMBER CHECK="min:-1" EXPERT **
# Even if the other users' lease has expired, then you can specify that
# they should still get a (less forceful) warning about the old lease for
# some additional time after the lease expired. You can set this to 0 to
# suppress these extra warnings completely, or to -1 so they are always
# issued, or to a number of seconds since the old lease expired.
$Foswiki::cfg{LeaseLengthLessForceful} = 3600;

# **PATH CHECK='perms:Fr' EXPERT**
# Pathname to file that maps file suffixes to MIME types :
# For Apache server set this to Apache's mime.types file pathname,
# for example /etc/httpd/mime.types, or use the default shipped in
# the Foswiki data directory.
$Foswiki::cfg{MimeTypesFileName} = '$Foswiki::cfg{DataDir}/mime.types';

# **BOOLEAN EXPERT**
# Enable tracebacks in error messages.  Used for debugging.
# $Foswiki::cfg{DebugTracebacks} = '';

#############################################################################
#---+ Extensions

#---++ Extension operation and maintenance
#    * Specify the plugin load order
#    * Use the Extensions Repository to add, update or remove plugins
#    * Enable and disable installed plugins

#---+++ Enable or disable installed extensions

# *PLUGINS* Marker used by bin/configure script - do not remove!
# The plugins were discovered by searching the =@INC=
# path for modules that match the Foswiki standard. For example
# =Foswiki/Plugins/MyPlugin.pm= or the TWiki standard
# =TWiki/Plugins/YourPlugin.pm=. Note that this list
# is only for Plugins. You cannot Enable/Disable Contribs, AddOns or Skins.
#
# Any plugins enabled in the configuration but not found in the =@INC=
# path are listed at the end and are flagged as errors in the
# {PluginsOrder} check.

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

$Foswiki::cfg{Plugins}{ConfigurePlugin}{Enabled} = 1;
$Foswiki::cfg{Plugins}{ConfigurePlugin}{Module} =
  'Foswiki::Plugins::ConfigurePlugin';

#---+++ Install, Update or Remove extensions
# **STRING 80 FEEDBACK="label='Review installed extensions';wizard='ExploreExtensions';method='get_installed_extensions'"  FEEDBACK="label='Search for extension';wizard='ExploreExtensions';method='find_extension_1'" FEEDBACK="label='All available extensions';wizard='ExploreExtensions';method='get_other_extensions'"**
# Extensions Repositories Search List.
# Foswiki extension repositories are just Foswiki webs that are organised in the
# same way as the Extensions web on Foswiki.org. The 'Search for extensions'
# button searches these repositories for installable extensions. To set up an
# extensions repository:
#    1 Create a Foswiki web to contain the repository
#    2 Copy the =FastReport= page from [[http://foswiki.org/Extensions/FastReport?raw=on][Foswiki:Extensions.FastReport]] to your new web
#    3 Set the =WEBFORMS= preference in WebPreferences to =PackageForm=
# The page for each extension must have the =PackageForm= (copy from
# Foswiki.org), and should have the packaged extension attached as a
# =zip= and/or =tgz= file.
#
# The search list is a semicolon-separated list of repository
# specifications, each in the format: =name=(listurl,puburl,username,password)=
# where:
#    * =name= is the symbolic name of the repository, for example Foswiki.org
#    * =listurl= is the root of a view URL
#    * =puburl= is the root of a download URL
#    * =username= is the username if TemplateAuth is required on the
#      repository (optional)
#    * =password= is the password if TemplateAuth is required on the
#      repository (optional)
# Note: if your Repository uses ApacheAuth, embed the username and password
# into the listurl as =?username=x;password=y=
#
# For example,=
# twiki.org=(http://twiki.org/cgi-bin/viewlugins/,http://twiki.org/p/pub/Plugins/); foswiki.org=(http://foswiki.org/Extensions/,http://foswiki.org/pub/Extensions/);=
#
# For Extensions with the same name in more than one repository, the *last*
# matching repository in the list will be chosen, so Foswiki.org should
# always be last in the list for maximum compatibility.
$Foswiki::cfg{ExtensionsRepositories} =
'Foswiki.org=(http://foswiki.org/Extensions/,http://foswiki.org/pub/Extensions/)';

# *FINDEXTENSIONS* Marker used by bin/configure script - do not remove!

#---+++ Configure how plugins are loaded by Foswiki
# **STRING 80**
# Plugins evaluation order. If set to a comma-separated list of plugin names,
# will change the execution order of plugins so the listed subset of plugins
# are executed first. The default execution order is alphabetical on plugin
# name.
#
# If TWiki compatibility is required, TWikiCompatibilityPlugin should be
# the first Plugin in the list.  SpreadSheetPlugin should typically be next
# in the list for proper operation.
#
# Note that some other general extension environment checks are made and
# reported here.  Plugins that are enabled but not installed and duplicate
# plugins in the TWiki and Foswiki libraries are reported here.  Also if a
# TWiki plugin is enabled and the Foswik version is installed, this will
# also be reported here.
$Foswiki::cfg{PluginsOrder} = 'TWikiCompatibilityPlugin,SpreadSheetPlugin,SlideShowPlugin';

# **STRING 80 EXPERT**
# Search path (web names) for plugin topics. Note that the current web
# is searched last, after this list.   Most modern foswiki plugins do not
# use the plugin topic for settings, and this setting is ignored. It is
# recommended that this setting not be changed.
$Foswiki::cfg{Plugins}{WebSearchPath} = '$Foswiki::cfg{SystemWebName},TWiki';

1;
__END__
#
# Copyright (C) 2008-2014 Foswiki Contributors. Foswiki Contributors
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
