# ---+ Extensions
# ---++ ConfigurePlugin
# ---+++ Testing
# The following key specs are only used in testing the ConfigurePlugin
# and do nothing.
# **STRING FEEDBACK="label='Test one';wizard='Test';method='test1';auth=1" \
#          FEEDBACK="label='Test two';wizard='Test';method='test1'" \
#          CHECK="min:3 max:20" **
# When you press either of the test buttons, expect the value to change
# to "ROPE" and there to be one each of the different levels of report.
$Foswiki::cfg{Plugins}{ConfigurePlugin}{Test}{STRING} = 'STRING';
# **BOOLEAN**
# Should be 1
$Foswiki::cfg{Plugins}{ConfigurePlugin}{Test}{BOOLEAN} = 1;
# **COMMAND**
# Should be COMMAND
$Foswiki::cfg{Plugins}{ConfigurePlugin}{Test}{COMMAND} = 'COMMAND';
# **DATE**
# Should be 12 Feb 2012
$Foswiki::cfg{Plugins}{ConfigurePlugin}{Test}{DATE} = '12 Feb 2012';
# **EMAILADDRESS**
# Should be address@email.co
$Foswiki::cfg{Plugins}{ConfigurePlugin}{Test}{EMAILADDRESS} = 'address@email.co';
# **NUMBER**
# Should be 666
$Foswiki::cfg{Plugins}{ConfigurePlugin}{Test}{NUMBER} = 666;
# **OCTAL**
# Should see 755
$Foswiki::cfg{Plugins}{ConfigurePlugin}{Test}{OCTAL} = 429;
# **PASSWORD**
# Shouldn't reflect
$Foswiki::cfg{Plugins}{ConfigurePlugin}{Test}{PASSWORD} = 'PASSWORD';
# **PATH**
# Should be PATH
$Foswiki::cfg{Plugins}{ConfigurePlugin}{Test}{PATH} = 'PATH';
# **PERL FEEDBACK="label='Format';wizard='Test';method='format'" **
# The test button should come back with a prettified version of your value.
#$Foswiki::cfg{Plugins}{ConfigurePlugin}{Test}{PERL} = '\'PERL\';';
# **REGEX**
# Should be '^regex$'
$Foswiki::cfg{Plugins}{ConfigurePlugin}{Test}{REGEX} = '^regex$';
# **SELECTCLASS none,Foswiki::Configure::P* **
# Should be Package; should offer Pluggables,Package
$Foswiki::cfg{Plugins}{ConfigurePlugin}{Test}{SELECTCLASS} = 'Foswiki::Configure::Package';
# **SELECT choose,life**
# Should be life
$Foswiki::cfg{Plugins}{ConfigurePlugin}{Test}{SELECT} = 'life';
# **URLPATH**
# Should be /
$Foswiki::cfg{Plugins}{ConfigurePlugin}{Test}{URLPATH} = '/';
# **URL**
$Foswiki::cfg{Plugins}{ConfigurePlugin}{Test}{URL} = 'http://localhost';
# **STRING H**
$Foswiki::cfg{Plugins}{ConfigurePlugin}{Test}{H} = 'H';
# **STRING EXPERT**
# Should be EXPERT
$Foswiki::cfg{Plugins}{ConfigurePlugin}{Test}{EXPERT} = 'EXPERT';
# **PATH CHECK='nullok'**
# Should be 'empty'
# $Foswiki::cfg{Plugins}{ConfigurePlugin}{Test}{empty} = 'empty';
# **STRING**
# Should be a list of other items
$Foswiki::cfg{Plugins}{ConfigurePlugin}{Test}{DEPENDS} = '$Foswiki::cfg{Plugins}{ConfigurePlugin}{Test}{H} and $Foswiki::cfg{Plugins}{ConfigurePlugin}{Test}{EXPERT} ans $$Foswiki::cfg{Plugins}{ConfigurePlugin}{Test}{NotPresent}';


