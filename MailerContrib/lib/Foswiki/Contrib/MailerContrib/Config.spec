# ---+ Extensions
# ---++ MailerContrib
# **REGEX LABEL="Email Filter" CHECK="undefok emptyok"**
# Define the regular expression that an email address entered in WebNotify
# must match to be identified as a legal email by the notifier. You can use
# this expression to - for example - filter email addresses on your company
# domain, or even block use of raw emails in WebNotify altogether (just make
# it something that will never match, e.g. <code>^@@notAnEmail</code>).
# If this is not defined, then the default setting of
# <code>[A-Za-z0-9.+-_]+\@[A-Za-z0-9.-]+</code> is used.
$Foswiki::cfg{MailerContrib}{EmailFilterIn} = '';

# **BOOLEAN EXPERT LABEL="Remove Images"**
# Remove IMG tags in notification mails.
$Foswiki::cfg{MailerContrib}{RemoveImgInMailnotify} = $TRUE;

# **STRING 80 LABEL="Respect User Preferences" CHECK="undefok emptyok"**
# A comma-separated list of user preference names that will be respected
# when sending out emails.
$Foswiki::cfg{MailerContrib}{RespectUserPrefs} = 'LANGUAGE';
1;
