# ---+ Extensions
# ---++ ZonePlugin
# This plugin is only required on legacy Foswiki engines.

# **BOOLEAN LABEL="Enable Warnings"**
# Enable this flag to log any use of legady APIs, that is topics that still use
# %ADDTOHEAD or perl code that uses Foswiki::Func::addToHEAD(). ZonePlugin will
# try to put posted content to the right place, that is any sign of text/javascript
# will move the content to the BODY zone while anything else is put into the HEAD
# zone.
$Foswiki::cfg{ZonePlugin}{Warnings} = 0;

1;
