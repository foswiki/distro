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
# To jQuery plugin authors: you should always wrap your plugins in a
# <pre>(function($) { ... })(jQuery);</pre> construct to make use of <code>$</code> locally.
$Foswiki::cfg{JQueryPlugin}{NoConflict} = 0;

# **STRING**
$Foswiki::cfg{JQueryPlugin}{DefaultPlugins} = '';

# **SELECT jquery-1.4.3, jquery-1.4.4, jquery-1.5, jquery-1.5.1, jquery-1.5.2, jquery-1.6.1, jquery-1.6.2, jquery-1.6.3, jquery-1.6.4**
$Foswiki::cfg{JQueryPlugin}{JQueryVersion} = 'jquery-1.6.4';

# **SELECT ,base, flickr, foswiki, lightness, redmond, smoothness**
$Foswiki::cfg{JQueryPlugin}{JQueryTheme} = 'foswiki';

# ---+++ Default themes
# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Themes}{Base}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Themes}{Flickr}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Themes}{Lightness}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Themes}{Redmond}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Themes}{Smoothness}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Themes}{Foswiki}{Enabled} = 1;

# ---+++ Default plugins
# **BOOLEAN**
# Warning: this plugin is deprecated. Please use the autocomplete plugin part of the jQuery-ui package.
$Foswiki::cfg{JQueryPlugin}{Plugins}{Autocomplete}{Enabled} = 0;

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
$Foswiki::cfg{JQueryPlugin}{Plugins}{Placeholder}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{PNotify}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{PopUpWindow}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{QueryObject}{Enabled} = 1;

# **BOOLEAN**
# Warning: This plugin is deprecated. Use Corner instead
$Foswiki::cfg{JQueryPlugin}{Plugins}{Nifty}{Enabled} = 0;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{Rating}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{ScrollTo}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{SerialScroll}{Enabled} = 1;

# **BOOLEAN**
# Warning: This plugin is deprecated. The shake effect is now part of the latest jQuery-ui package.
$Foswiki::cfg{JQueryPlugin}{Plugins}{Shake}{Enabled} = 0;

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
$Foswiki::cfg{JQueryPlugin}{Plugins}{Tmpl}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{Tooltip}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{Treeview}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{UI}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{'UI::Autocomplete'}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{'UI::Resizable'}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{'UI::Draggable'}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{'UI::Accordion'}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{'UI::Tabs'}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{'UI::Slider'}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{'UI::Dialog'}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{'UI::Button'}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{'UI::Datepicker'}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{'UI::Progressbar'}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{Validate}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{WikiWord}{Enabled} = 1;

1;
