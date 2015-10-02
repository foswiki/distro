# ---+ Extensions
# ---++ AutoViewTemplate settings
# This is the configuration used by the <b>AutoViewTemplatePlugin</b>.

# **BOOLEAN LABEL="Debug"**
# Turn on/off debugging in debug.txt
$Foswiki::cfg{Plugins}{AutoViewTemplatePlugin}{Debug} = 0;

# **BOOLEAN LABEL="Override"**
# Template defined by form overrides existing VIEW_TEMPLATE or EDIT_TEMPLATE settings
$Foswiki::cfg{Plugins}{AutoViewTemplatePlugin}{Override} = 0;

# **SELECT exist,section **
# How to find the view or edit template. 'exist' means the template name is derived from the name of the form definition topic. 'section' means the template name is defined in a section in the form definition topic.
$Foswiki::cfg{Plugins}{AutoViewTemplatePlugin}{Mode} = 'exist';

1;
