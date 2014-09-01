# ---+ Extensions
# ---++ ConfigurePlugin
# ---+++ Testing
# The following key specs are only used in testing the ConfigurePlugin
# and do nothing.
# **STRING FEEDBACK="label='Test';wizard='Test';method='test';auth=1"**
# When you press the Test button, expect the value to change to "ROPE" and
# there to be one each of the different levels of report.
$Foswiki::cfg{Plugins}{ConfigurePlugin}{Test}{STRING} = 'STRING';
# **PASSWORD**
$Foswiki::cfg{Plugins}{ConfigurePlugin}{Test}{PASSWORD} = 'PASSWORD';
# **BOOLEAN**
$Foswiki::cfg{Plugins}{ConfigurePlugin}{Test}{BOOLEAN} = 1;
# **COMMAND**
$Foswiki::cfg{Plugins}{ConfigurePlugin}{Test}{COMMAND} = 'COMMAND';
# **DATE**
$Foswiki::cfg{Plugins}{ConfigurePlugin}{Test}{DATE} = '12 Feb 2012';
# **EMAILADDRESS**
$Foswiki::cfg{Plugins}{ConfigurePlugin}{Test}{EMAILADDRESS} = 'address@email.co';
# **LANGUAGE**
$Foswiki::cfg{Plugins}{ConfigurePlugin}{Test}{LANGUAGE} = 'LANGUAGE';
# **NUMBER**
$Foswiki::cfg{Plugins}{ConfigurePlugin}{Test}{NUMBER} = '666';
# **OCTAL**
$Foswiki::cfg{Plugins}{ConfigurePlugin}{Test}{OCTAL} = 'OCTAL';
# **PASSWORD**
$Foswiki::cfg{Plugins}{ConfigurePlugin}{Test}{PASSWORD} = 'PASSWORD';
# **PATH**
$Foswiki::cfg{Plugins}{ConfigurePlugin}{Test}{PATH} = 'PATH';
# **PERL**
$Foswiki::cfg{Plugins}{ConfigurePlugin}{Test}{PERL} = 'PERL';
# **REGEX**
$Foswiki::cfg{Plugins}{ConfigurePlugin}{Test}{REGEX} = qr/^regex$/;
# **SELECTCLASS none,Foswiki::Confi* **
$Foswiki::cfg{Plugins}{ConfigurePlugin}{Test}{SELECTCLASS} = 'Foswiki::Configure';
# **SELECT**
$Foswiki::cfg{Plugins}{ConfigurePlugin}{Test}{SELECT} = 'SELECT';
# **URLPATH**
$Foswiki::cfg{Plugins}{ConfigurePlugin}{Test}{URLPATH} = '/';
# **URL**
$Foswiki::cfg{Plugins}{ConfigurePlugin}{Test}{URL} = 'http://localhost';
# **STRING H**
$Foswiki::cfg{Plugins}{ConfigurePlugin}{Test}{H} = 'H';
# **STRING EXPERT**
$Foswiki::cfg{Plugins}{ConfigurePlugin}{Test}{EXPERT} = 'EXPERT';
# **PATH**
# $Foswiki::cfg{Plugins}{ConfigurePlugin}{Test}{empty} = 'empty';
# **STRING**
$Foswiki::cfg{Plugins}{ConfigurePlugin}{Test}{DEPENDS} = '$Foswiki::cfg{Plugins}{ConfigurePlugin}{Test}{H} and $Foswiki::cfg{Plugins}{ConfigurePlugin}{Test}{EXPERT} ans $$Foswiki::cfg{Plugins}{ConfigurePlugin}{Test}{NotPresent}';


