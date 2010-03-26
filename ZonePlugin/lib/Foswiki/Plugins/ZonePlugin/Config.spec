# ---+ Extensions
# ---++ ZonePlugin
# ---+++ Backwards compatibility - EXPERT
# **BOOLEAN**
# This will help you to work around situatios where javascript files produce errors
# due to the different ordering of depending files being located in the BODY zone.
# If switched on, all content added to any zone will be gathered in the HEAD for.
# Note, that in backwards compatibility mode, the page layout will be suboptimal
# resulting in slower page rendering times by todays browsers. Alternatively, try
# to fix the cause for any javascript not being properly put into the BODY zone.
$Foswiki::cfg{OptimizePageLayout} = 0;

# ---+++ Warning messages - EXPERT
# **BOOLEAN**
# Enable this flag to log any use of legady APIs, that is topics that still use
# %ADDTOHEAD or perl code that uses Foswiki::Func::addToHEAD(). ZonePlugin will
# try to put posted content to the right place, that is any sign of text/javascript
# will move the content to the BODY zone while anything else is put into the HEAD
# zone.
$Foswiki::cfg{ZonePlugin}{Warnings} = 0;


