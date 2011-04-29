# ---+ Extensions
# ---++ JsonRpcContrib
# **PERL H** 
# This setting is required to enable executing jsonrpc from the bin directory
$Foswiki::cfg{SwitchBoard}{jsonrpc} = ['Foswiki::Contrib::JsonRpcContrib', 'dispatch', {jsonrpc => 1}];
# ---++ JQueryPlugin
# ---+++ Extra plugins
# **STRING**
$Foswiki::cfg{JQueryPlugin}{Plugins}{JsonRpc}{Module} = 'Foswiki::Contrib::JsonRpcContrib::JQueryPlugin';
# **BOOLEAN**
$Foswiki::cfg{JQueryPlugin}{Plugins}{JsonRpc}{Enabled} = 1;

1;
