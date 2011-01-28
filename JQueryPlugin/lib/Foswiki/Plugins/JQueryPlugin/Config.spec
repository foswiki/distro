# ---+ Extensions
# ---++ JQueryPlugin
# ---+++ General settings 
# **BOOLEAN**
# This flag enables the debug mode for JQueryPlugin and all of its sub-modules.
# Instead of loading jquery.myplugin.js, it will load jquery.myplugin.uncompressed.js.
$Foswiki::cfg{JQueryPlugin}{Debug} = 0;

# **BOOLEAN**
# Enabling {MemoryCache} is an optimization flag useful when running Foswiki in a persistent perl
# environment (fast-cgi, mod_perl). If set, registration information of sub-modules are kept in memory
# between requests, thus speeding up the initialization phase.
$Foswiki::cfg{JQueryPlugin}{MemoryCache} = 1;

# **STRING**
# search path for JQICONs
$Foswiki::cfg{JQueryPlugin}{IconSearchPath} = 'FamFamFamSilkIcons, FamFamFamSilkCompanion1Icons, FamFamFamFlagIcons, FamFamFamMiniIcons, FamFamFamMintIcons';

# **BOOLEAN**
# Enable this switch to prevent name conflicts with other javascript frameworks that
# use <code>$</code>. If enabled <code>$</code> will be renamed to <code>$j</code>.
# To jQuery plugin authors: in any case try to wrap your plugins into a
# <pre>(function($) { ... })(jQuery);</pre> construct to make use of <code>$</code> locally.
$Foswiki::cfg{JQueryPlugin}{NoConflict} = 0;

# **STRING**
$Foswiki::cfg{JQueryPlugin}{DefaultPlugins} = '';

# **SELECT jquery-1.4.4, jquery-1.4.3**
$Foswiki::cfg{JQueryPlugin}{JQueryVersion} = 'jquery-1.4.3';

# **SELECT ,flickr, lightness, redmond, smoothness**
$Foswiki::cfg{JQueryPlugin}{JQueryTheme} = '';

# ---+++ jQuery plugins - EXPERT
# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{Autocomplete}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{Bgiframe}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{Button}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{BlockUI}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{Chili}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{Corner}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{Cookie}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{Cycle}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{Debug}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{Easing}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{Farbtastic}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{Focus}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{Form}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{Foswiki}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{FluidFont}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{Gradient}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{HoverIntent}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{InnerFade}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{LiveQuery}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{LocalScroll}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{MaskedInput}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{Masonry}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{Media}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{Metadata}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{PNotify}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{PopUpWindow}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{QueryObject}{Enabled} = 1;

# **BOOLEAN**
# This plugin is deprecated. Use Corner instead
# $Foswiki::cfg{JQueryPlugin}{Plugins}{Nifty}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{Rating}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{ScrollTo}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{SerialScroll}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{Shake}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{ShrinkUrls}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{SimpleModal}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{Slimbox}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{Superfish}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{Supersubs}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{Tabpane}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{TextboxList}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{Themeswitcher}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{Tooltip}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{Treeview}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{UI}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{Validate}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{WikiWord}{Enabled} = 1;

1;
