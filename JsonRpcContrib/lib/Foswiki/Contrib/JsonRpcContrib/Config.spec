# ---+ Extensions
# ---++ JsonRpcContrib
# **PERL H LABEL="SwitchBoard - jsonrpc"** 
# This setting is required to enable executing jsonrpc from the bin directory
$Foswiki::cfg{SwitchBoard}{jsonrpc} = {
  package => 'Foswiki::Contrib::JsonRpcContrib', 
  function => 'dispatch', 
  context => {jsonrpc => 1}
};
# ---++ JQueryPlugin
# ---+++ Extra plugins
# **BOOLEAN LABEL="JsonRPC"**
$Foswiki::cfg{JQueryPlugin}{Plugins}{JsonRpc}{Enabled} = 1;
# **STRING LABEL="JsonRPC Module" EXPERT**
$Foswiki::cfg{JQueryPlugin}{Plugins}{JsonRpc}{Module} = 'Foswiki::Contrib::JsonRpcContrib::JQueryPlugin';

1;
