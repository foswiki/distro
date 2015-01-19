# ---+ Extensions
# ---++ SubscribePlugin
# Settings for the Subscribe Plugin.  This plugin adds a simple "Subscribe" link to topics. This allows
# single-click subscribing or unsubscribing from the WebNotify topic.

# **STRING 80 LABEL="Active Webs" CHECK="undefok emptyok"**
# Comma-separated list of webs that will get the subscribe button added.  Default is all webs. 
# Caution:  On webs with extremely large or complex WebNotify topics, the rendering of the Subscribe or Unsubscribe
# link can take an inordinate amount of time. 
$Foswiki::cfg{Plugins}{SubscribePlugin}{ActiveWebs} = undef;
1;
