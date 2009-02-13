# ---+ Extensions
# ---++ HomePagePlugin
# **Text**
#the web or topic to when none is specified, or on login/logoff
$Foswiki::cfg{HomePagePlugin}{SiteDefaultTopic} = '%MAINWEB%.%HOMETOPIC%';


# **BOOLEAN**
#redirect to HomePage when the use logs in (makes sense if users have personalised home pages.)
$Foswiki::cfg{HomePagePlugin}{GotoHomePageOnLogin} = $FALSE;

# **BOOLEAN**
#redirect to HomePage when the use logs off
$Foswiki::cfg{HomePagePlugin}{GotoHomePageOnLogoff} = $TRUE;

