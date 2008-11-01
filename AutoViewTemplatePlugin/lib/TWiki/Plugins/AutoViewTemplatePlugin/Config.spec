# ---+ AutoViewTemplate settings
# This is the configuration used by the <b>AutoViewTemplatePlugin</b>.

# **BOOLEAN**
# Turn on/off debugging in debug.txt
$TWiki::cfg{Plugins}{AutoViewTemplatePlugin}{Debug} = 0;

# **BOOLEAN**
# Override existing VIEW_TEMPLATE settings in doubt.
$TWiki::cfg{Plugins}{AutoViewTemplatePlugin}{Override} = 0;

# **SELECT exist,section**
# Where to find the template to be used.
$TWiki::cfg{Plugins}{AutoViewTemplatePlugin}{Mode} = 'exist';