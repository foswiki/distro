# ---+ Extensions
# ---++ MailerContrib
# **REGEX**
# Define the regular expression that an email address entered in WebNotify
# must match to be identified as a legal email by the notifier. You can use
# this expression to - for example - filter email addresses on your company
# domain, or even block use of raw emails in WebNotify altogether (just make
# it something that will never match, e.g. <code>^notAnEmail$</code>).
# If this is not defined, then the default setting of
# <code>[A-Za-z0-9.+-_]+\@[A-Za-z0-9.-]+</code> is used.
$Foswiki::cfg{MailerContrib}{EmailFilterIn} = '';

# **STRING EXPERT**
# Plugin module path for handler registration
$Foswiki::cfg{Plugins}{MailerContrib}{Module} = 'Foswiki::Contrib::MailerContrib';
# **BOOLEAN**
# Enable plugin module for handler registration. You can disable the plugin
# if you don't want to invoke mail notification from the web.
$Foswiki::cfg{Plugins}{MailerContrib}{Enabled} = 1;
