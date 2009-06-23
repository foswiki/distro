# ---+ JQueryPlugin

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Debug} = 0;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{MemoryCache} = 1;

# **BOOLEAN**
# Enable this switch to prevent name conflicts with other javascrit frameworks that
# use <code>$</code>. If enabled <code>$</code> will be renamed to <code>$j</code>.
# To jQuery plugin authors: in any case try to wrap your plugins into a
# <pre>(function($) { ... })(jQuery);</pre> construct to make use of <code>$</code> locally.
$Foswiki::cfg{JQueryPlugin}{NoConflict} = 1;

# **STRING**
$Foswiki::cfg{JQueryPlugin}{DefaultPlugins} = 'easing, metadata, bgiframe, foswiki';

# **SELECT jquery-1.2.6, jquery-1.3.2, jquery-1.3.2p1**
$Foswiki::cfg{JQueryPlugin}{JQueryVersion} = 'jquery-1.3.2';

# **SELECT base, lightness, redmond, smoothness**
$Foswiki::cfg{JQueryPlugin}{JQueryTheme} = 'redmond';

# ---++ jQuery plugins
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
$Foswiki::cfg{JQueryPlugin}{Plugins}{Gradient}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{HoverIntent}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{InnerFade}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{MaskedInput}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{Media}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{Metadata}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{Rating}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{Shake}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{ShrinkUrls}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{SimpleModal}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{Superfish}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{Tabpane}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{TextboxList}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{Toggle}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{Tooltip}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{Treeview}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{Validate}{Enabled} = 1;

# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{WikiWord}{Enabled} = 1;

1;
