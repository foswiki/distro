# ---+ Extensions
# ---++ ZonePlugin
# ---+++ Backwards compatibility
# **BOOLEAN**
# <p><code>{MergeHeadAndScriptZones}</code> is provided to maintain compatibility with legacy extensions that use <code>ADDTOHEAD</code> to add <code>&lt;script&gt;</code> markup and require content that is now in the <code>script</code> zone.</p>
# <p>Normally, dependencies between individual <code>ADDTOZONE</code> statements are resolved within each zone. However, if <code>{MergeHeadAndScriptZones}</code> is enabled, then <code>head</code> content which requires an <code>id</code> that only exists in <code>script</code> (and vice-versa) will be re-ordered to satisfy any dependency.</p>
# <p><strong><code>{MergeHeadAndScriptZones}</code> will be removed from a future version of Foswiki.</strong></p>
$Foswiki::cfg{MergeHeadAndScriptZones} = 0;

# ---+++ Warning messages - EXPERT
# **BOOLEAN**
# Enable this flag to log any use of legady APIs, that is topics that still use
# %ADDTOHEAD or perl code that uses Foswiki::Func::addToHEAD(). ZonePlugin will
# try to put posted content to the right place, that is any sign of text/javascript
# will move the content to the BODY zone while anything else is put into the HEAD
# zone.
$Foswiki::cfg{ZonePlugin}{Warnings} = 0;
1;
