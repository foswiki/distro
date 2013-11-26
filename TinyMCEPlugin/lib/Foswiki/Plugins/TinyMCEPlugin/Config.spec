# ---+ Extensions
# ---++ JQueryPlugin
# ---+++ Extra plugins
# **STRING**
$Foswiki::cfg{JQueryPlugin}{Plugins}{TinyMCE}{Module} = 'Foswiki::Plugins::TinyMCEPlugin::TinyMCE';
# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{TinyMCE}{Enabled} = 1;
# ---++ TinyMCEPlugin
# **SELECT tinymce-3.5.10, tinymce-3.4.9, tinymce-4.0.11**
# Select the version of TinyMCE editor.
#<ul><li>Version 3.4.9,  used with Foswiki 1.1.9
#<li>Version 3.5.10,  Latest Version 3.5 version (recommended)
#<li>Verstion 4.0.11: Experimental, does not currently work</ul>
$Foswiki::cfg{Plugins}{TinyMCEPlugin}{TinyMCEVersion} = 'tinymce-3.5.10';
