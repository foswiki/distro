# ---+ Extensions
# ---++ HomePagePlugin
# **Text**
#the web or topic to when none is specified, or on login/logoff
$Foswiki::cfg{HomePagePlugin}{SiteDefaultTopic} = '';


# **BOOLEAN**
#Always show user's HomePage when they log in (makes sense if users have personalised home pages.) 
#but will mean that any URL's emailed to them will only be useful after login
$Foswiki::cfg{HomePagePlugin}{GotoHomePageOnLogin} = $FALSE;


