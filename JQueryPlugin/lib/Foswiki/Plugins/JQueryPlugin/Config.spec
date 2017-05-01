# ---+ Extensions
# ---++ JQueryPlugin
# ---+++ General settings 
# **BOOLEAN LABEL="Debug"**
# This flag enables the debug mode for JQueryPlugin and all of its sub-modules.
# Instead of loading jquery.myplugin.js, it will load jquery.myplugin.uncompressed.js.
$Foswiki::cfg{JQueryPlugin}{Debug} = 0;

# **BOOLEAN LABEL="Enable Memory Cache"**
# Enabling {MemoryCache} is an optimization flag useful when running Foswiki in a persistent perl
# environment (fast-cgi, mod_perl). If set, registration information of sub-modules are kept in memory
# between requests, thus speeding up the initialization phase.
$Foswiki::cfg{JQueryPlugin}{MemoryCache} = 1;

# **STRING LABEL="Icon Search Path" CHECK="undefok"**
# search path for JQICONs
$Foswiki::cfg{JQueryPlugin}{IconSearchPath} = 'FamFamFamSilkIcons, FamFamFamSilkCompanion1Icons, FamFamFamSilkCompanion2Icons, FamFamFamSilkGeoSilkIcons, FamFamFamFlagIcons, FamFamFamMiniIcons, FamFamFamMintIcons';

# **BOOLEAN LABEL="Enable No-Conflict Mode"**
# Enable this switch to prevent name conflicts with other javascript frameworks that
# use <code>$</code>. If enabled <code>$</code> will be renamed to <code>$j</code>.
# To jQuery plugin authors: you should always wrap your plugins in a
# <pre>(function($) { ... })(jQuery);</pre> construct to make use of <code>$</code> locally.
$Foswiki::cfg{JQueryPlugin}{NoConflict} = 0;

# **STRING LABEL="Default Plugins"**
# List of plugins loaded by default on any page. Note that you need at least the "migrate" plugin being loaded by default in case you are using 
# a newer jQuery library. Starting with jquery-1.9.1 all deprecated methods have been removed from it and put into the "migrate" plugin.
$Foswiki::cfg{JQueryPlugin}{DefaultPlugins} = '';

# **SELECT jquery-1.9.1, jquery-1.10.0, jquery-1.11.0, jquery-1.11.1, jquery-1.11.2, jquery-1.11.3, jquery-2.0.0, jquery-2.0.1, jquery-2.0.2, jquery-2.1.0, jquery-2.1.1, jquery-2.1.3, jquery-2.1.4, jquery-2.2.0, jquery-2.2.1, jquery-2.2.2, jquery-2.2.3, jquery-2.2.4**
# Note that starting with jQuery-1.9.1 deprecated features have been removed. If you are experiencing
# problems with plugins still using deprecated features then add the <code>migrate</code> plugin to the list
# of plugins loaded by default (see above). Further note that starting with jQuery-2.0 support for Internet Explorer 6/7/8
# has been dropped. Use jQuery-1.9 in case you still need to cover these browsers.
$Foswiki::cfg{JQueryPlugin}{JQueryVersion} = 'jquery-2.2.4';

# **SELECT , jquery-1.9.1, jquery-1.10.0, jquery-1.10.1, jquery-1.11.0, jquery-1.11.1, jquery-1.11.2, jquery-1.11.3, jquery-1.12.0, jquery-1.12.1, jquery-1.12.2, jquery-1.12.3, jquery-1.12.4**
# Use a different jQuery library for Internet Explorer 6/7/8. Since jQuery-2.0 these old browsers aren't suppored anymore.
# Use one of the jQuery-1.x libraries to still serve a compatible jQuery to these browsers. Or leave it empty to use the same 
# library version for all browsers.
$Foswiki::cfg{JQueryPlugin}{JQueryVersionForOldIEs} = 'jquery-1.12.4';

# **SELECT ,base, flickr, foswiki, lightness, redmond, smoothness **
$Foswiki::cfg{JQueryPlugin}{JQueryTheme} = 'foswiki';

# ---+++ JQuery UI Themes
# **BOOLEAN LABEL="Base"**
$Foswiki::cfg{JQueryPlugin}{Themes}{Base}{Enabled} = 1;

# **BOOLEAN LABEL="Flickr"**
$Foswiki::cfg{JQueryPlugin}{Themes}{Flickr}{Enabled} = 1;

# **BOOLEAN LABEL="Foswiki"**
$Foswiki::cfg{JQueryPlugin}{Themes}{Foswiki}{Enabled} = 1;

# **BOOLEAN LABEL="Lightness"**
$Foswiki::cfg{JQueryPlugin}{Themes}{Lightness}{Enabled} = 1;

# **BOOLEAN LABEL="Redmond"**
$Foswiki::cfg{JQueryPlugin}{Themes}{Redmond}{Enabled} = 1;

# **BOOLEAN LABEL="Smoothness"**
$Foswiki::cfg{JQueryPlugin}{Themes}{Smoothness}{Enabled} = 1;

# ---+++ JQuery Plugins
# **BOOLEAN LABEL="Animate"**
$Foswiki::cfg{JQueryPlugin}{Plugins}{Animate}{Enabled} = 1;

# **BOOLEAN LABEL="Button"**
$Foswiki::cfg{JQueryPlugin}{Plugins}{Button}{Enabled} = 1;

# **BOOLEAN LABEL="BlockUI"**
$Foswiki::cfg{JQueryPlugin}{Plugins}{BlockUI}{Enabled} = 1;

# **BOOLEAN LABEL="Chili"**
$Foswiki::cfg{JQueryPlugin}{Plugins}{Chili}{Enabled} = 1;

# **BOOLEAN LABEL="Cookie"**
$Foswiki::cfg{JQueryPlugin}{Plugins}{Cookie}{Enabled} = 1;

# **BOOLEAN LABEL="Cycle"**
$Foswiki::cfg{JQueryPlugin}{Plugins}{Cycle}{Enabled} = 1;

# **BOOLEAN LABEL="Debug"**
$Foswiki::cfg{JQueryPlugin}{Plugins}{Debug}{Enabled} = 1;

# **BOOLEAN LABEL="Easing"**
$Foswiki::cfg{JQueryPlugin}{Plugins}{Easing}{Enabled} = 1;

# **BOOLEAN LABEL="Farbtastic"**
$Foswiki::cfg{JQueryPlugin}{Plugins}{Farbtastic}{Enabled} = 1;

# **BOOLEAN LABEL="Focus"**
$Foswiki::cfg{JQueryPlugin}{Plugins}{Focus}{Enabled} = 1;

# **BOOLEAN LABEL="FontAwesome"**
$Foswiki::cfg{JQueryPlugin}{Plugins}{FontAwesome}{Enabled} = 1;

# **BOOLEAN LABEL="Form"**
$Foswiki::cfg{JQueryPlugin}{Plugins}{Form}{Enabled} = 1;

# **BOOLEAN LABEL="Foswiki"**
$Foswiki::cfg{JQueryPlugin}{Plugins}{Foswiki}{Enabled} = 1;

# **BOOLEAN LABEL="FluidFont"**
$Foswiki::cfg{JQueryPlugin}{Plugins}{FluidFont}{Enabled} = 1;

# **BOOLEAN LABEL="HoverIntent"**
$Foswiki::cfg{JQueryPlugin}{Plugins}{HoverIntent}{Enabled} = 1;

# **BOOLEAN LABEL="I18N"**
$Foswiki::cfg{JQueryPlugin}{Plugins}{I18N}{Enabled} = 1;

# **BOOLEAN LABEL="ImagesLoaded"**
$Foswiki::cfg{JQueryPlugin}{Plugins}{ImagesLoaded}{Enabled} = 1;

# **BOOLEAN LABEL="InnerFade"**
$Foswiki::cfg{JQueryPlugin}{Plugins}{InnerFade}{Enabled} = 1;

# **BOOLEAN LABEL="LiveQuery"**
$Foswiki::cfg{JQueryPlugin}{Plugins}{LiveQuery}{Enabled} = 1;

# **BOOLEAN LABEL="Loader"**
$Foswiki::cfg{JQueryPlugin}{Plugins}{Loader}{Enabled} = 1;

# **BOOLEAN LABEL="LocalScroll"**
$Foswiki::cfg{JQueryPlugin}{Plugins}{LocalScroll}{Enabled} = 1;

# **BOOLEAN LABEL="MaskedInput"**
$Foswiki::cfg{JQueryPlugin}{Plugins}{MaskedInput}{Enabled} = 1;

# **BOOLEAN LABEL="Masonry"**
$Foswiki::cfg{JQueryPlugin}{Plugins}{Masonry}{Enabled} = 1;

# **BOOLEAN LABEL="Metadata"**
$Foswiki::cfg{JQueryPlugin}{Plugins}{Metadata}{Enabled} = 1;

# **BOOLEAN LABEL="Migrate"**
$Foswiki::cfg{JQueryPlugin}{Plugins}{Migrate}{Enabled} = 1;

# **BOOLEAN LABEL="MouseWheel"**
$Foswiki::cfg{JQueryPlugin}{Plugins}{MouseWheel}{Enabled} = 1;

# **BOOLEAN LABEL="Placeholder"**
$Foswiki::cfg{JQueryPlugin}{Plugins}{Placeholder}{Enabled} = 1;

# **BOOLEAN LABEL="PNotify"**
$Foswiki::cfg{JQueryPlugin}{Plugins}{PNotify}{Enabled} = 1;

# **BOOLEAN LABEL="PopUpWindow"**
$Foswiki::cfg{JQueryPlugin}{Plugins}{PopUpWindow}{Enabled} = 1;

# **BOOLEAN LABEL="QueryObject"**
$Foswiki::cfg{JQueryPlugin}{Plugins}{QueryObject}{Enabled} = 1;

# **BOOLEAN LABEL="Render"**
$Foswiki::cfg{JQueryPlugin}{Plugins}{Render}{Enabled} = 1;

# **BOOLEAN LABEL="ScrollTo"**
$Foswiki::cfg{JQueryPlugin}{Plugins}{ScrollTo}{Enabled} = 1;

# **BOOLEAN LABEL="SerialScroll"**
$Foswiki::cfg{JQueryPlugin}{Plugins}{SerialScroll}{Enabled} = 1;

# **BOOLEAN LABEL="ShrinkUrls"**
$Foswiki::cfg{JQueryPlugin}{Plugins}{ShrinkUrls}{Enabled} = 1;

# **BOOLEAN LABEL="Slimbox"**
$Foswiki::cfg{JQueryPlugin}{Plugins}{Slimbox}{Enabled} = 1;

# **BOOLEAN LABEL="Sprintf"**
$Foswiki::cfg{JQueryPlugin}{Plugins}{Sprintf}{Enabled} = 1;

# **BOOLEAN LABEL="Stars"**
$Foswiki::cfg{JQueryPlugin}{Plugins}{Stars}{Enabled} = 1;

# **BOOLEAN LABEL="Superfish"**
$Foswiki::cfg{JQueryPlugin}{Plugins}{Superfish}{Enabled} = 1;

# **BOOLEAN LABEL="Tabpane"**
$Foswiki::cfg{JQueryPlugin}{Plugins}{Tabpane}{Enabled} = 1;

# **BOOLEAN LABEL="TextboxList"**
$Foswiki::cfg{JQueryPlugin}{Plugins}{TextboxList}{Enabled} = 1;

# **BOOLEAN LABEL="Treeview"**
$Foswiki::cfg{JQueryPlugin}{Plugins}{Treeview}{Enabled} = 1;

# **BOOLEAN LABEL="UI"**
$Foswiki::cfg{JQueryPlugin}{Plugins}{UI}{Enabled} = 1;

# **BOOLEAN LABEL="UI::Accordion"**
$Foswiki::cfg{JQueryPlugin}{Plugins}{'UI::Accordion'}{Enabled} = 1;

# **BOOLEAN LABEL="UI::Autocomplete"**
$Foswiki::cfg{JQueryPlugin}{Plugins}{'UI::Autocomplete'}{Enabled} = 1;

# **BOOLEAN LABEL="UI::Button"**
$Foswiki::cfg{JQueryPlugin}{Plugins}{'UI::Button'}{Enabled} = 1;

# **BOOLEAN LABEL="UI::Datepicker"**
$Foswiki::cfg{JQueryPlugin}{Plugins}{'UI::Datepicker'}{Enabled} = 1;

# **BOOLEAN LABEL="UI::Dialog"**
$Foswiki::cfg{JQueryPlugin}{Plugins}{'UI::Dialog'}{Enabled} = 1;

# **BOOLEAN LABEL="UI::Draggable"**
$Foswiki::cfg{JQueryPlugin}{Plugins}{'UI::Draggable'}{Enabled} = 1;

# **BOOLEAN LABEL="UI::Progressbar"**
$Foswiki::cfg{JQueryPlugin}{Plugins}{'UI::Progressbar'}{Enabled} = 1;

# **BOOLEAN LABEL="UI::Resizable"**
$Foswiki::cfg{JQueryPlugin}{Plugins}{'UI::Resizable'}{Enabled} = 1;

# **BOOLEAN LABEL="UI::Slider"**
$Foswiki::cfg{JQueryPlugin}{Plugins}{'UI::Slider'}{Enabled} = 1;

# **BOOLEAN LABEL="UI::Spinner"**
$Foswiki::cfg{JQueryPlugin}{Plugins}{'UI::Spinner'}{Enabled} = 1;

# **BOOLEAN LABEL="UI::Tabs"**
$Foswiki::cfg{JQueryPlugin}{Plugins}{'UI::Tabs'}{Enabled} = 1;

# **BOOLEAN LABEL="UI::Tooltip"**
$Foswiki::cfg{JQueryPlugin}{Plugins}{'UI::Tooltip'}{Enabled} = 1;

# **BOOLEAN LABEL="UI::Validate"**
$Foswiki::cfg{JQueryPlugin}{Plugins}{Validate}{Enabled} = 1;

# **BOOLEAN LABEL="WikiWord"**
$Foswiki::cfg{JQueryPlugin}{Plugins}{WikiWord}{Enabled} = 1;

# ---+++ Deprecated JQuery Plugins
# Any plugins listed here should be disabled.  They will be removed in a future release of Foswiki.
# If enabled, they will be generate a Warning if deprecated, and an Error if the module has been removed from
# the Foswiki distribution.

# **BOOLEAN LABEL="Autocomplete" EXPERT**
# Warning: this plugin is deprecated. Please use the autocomplete plugin part of the jQuery-ui package.
$Foswiki::cfg{JQueryPlugin}{Plugins}{Autocomplete}{Enabled} = 0;

# **BOOLEAN LABEL="Bgiframe" EXPERT**
# Warning: this plugin is deprecated. 
$Foswiki::cfg{JQueryPlugin}{Plugins}{Bgiframe}{Enabled} = 0;

# **BOOLEAN LABEL="Corner" EXPERT**
# Warning: this plugin is deprecated. 
$Foswiki::cfg{JQueryPlugin}{Plugins}{Corner}{Enabled} = 0;

# **BOOLEAN LABEL="Gradient" EXPERT**
# Warning: this plugin is deprecated. Please use CSS. See http://colorzilla.com/gradient-editor/.
$Foswiki::cfg{JQueryPlugin}{Plugins}{Gradient}{Enabled} = 0;

# **BOOLEAN LABEL="Media" EXPERT**
# Warning: This plugin is deprecated. Use MediaElementPlugin instead.
$Foswiki::cfg{JQueryPlugin}{Plugins}{Media}{Enabled} = 0;

# **BOOLEAN LABEL="Nifty" EXPERT**
# Warning: This plugin is deprecated. Use Corner instead.
$Foswiki::cfg{JQueryPlugin}{Plugins}{Nifty}{Enabled} = 0;

# **BOOLEAN LABEL="Rating" EXPERT**
# Warning: This plugin is deprecated. Use Stars instead.
$Foswiki::cfg{JQueryPlugin}{Plugins}{Rating}{Enabled} = 0;

# **BOOLEAN LABEL="Shake" EXPERT**
# Warning: This plugin is deprecated. The shake effect is now part of the latest jQuery-ui package.
$Foswiki::cfg{JQueryPlugin}{Plugins}{Shake}{Enabled} = 0;

# **BOOLEAN LABEL="SimpleModal" EXPERT**
# Warning: This plugin is deprecated. Please use ui::dialog, the jquery-ui dialog widget.
$Foswiki::cfg{JQueryPlugin}{Plugins}{SimpleModal}{Enabled} = 0;

# **BOOLEAN LABEL="Supersubs" EXPERT**
# Warning: This plugin is deprecated. The latest superfish module supersedes it.
$Foswiki::cfg{JQueryPlugin}{Plugins}{Supersubs}{Enabled} = 0;

# **BOOLEAN LABEL="Tmpl" EXPERT**
# Warning: This plugin is deprecated. Please use jsrender.
$Foswiki::cfg{JQueryPlugin}{Plugins}{Tmpl}{Enabled} = 0;

# **BOOLEAN LABEL="Tooltip" EXPERT**
# Warning: this plugin is deprecated. Please use the tooltip plugin part of the jQuery-ui package.
$Foswiki::cfg{JQueryPlugin}{Plugins}{Tooltip}{Enabled} = 0;

1;
