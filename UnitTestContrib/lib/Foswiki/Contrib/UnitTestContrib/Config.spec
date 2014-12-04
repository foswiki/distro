# ---+ Extensions
# ---++ UnitTestContrib
# Foswiki Unit-Test Framework
# ---+++ Selenium Remote Control
# For browser-in-the-loop testing
# **STRING 30**
# The UnitTestContrib needs a username to access (i.e. edit) the testcase web and topic from the browser opened by Selenium RC.
$Foswiki::cfg{UnitTestContrib}{SeleniumRc}{Username} = '';
# **PASSWORD 30**
# The password for the Selenium RC user
$Foswiki::cfg{UnitTestContrib}{SeleniumRc}{Password} = '';
# **PERL 40x10 CHECK='nullok'**
# List the browsers accessible via Selenium RC.
# It is keyed by browser identifier - you choose the identifiers as seems sensible. Browser identifiers may only consist of alphanumeric characters.
# Examples: <code>FF3 FF2dot1OnWindows IE6_1_345 w3m</code>
# <br />
# The values are hashes of arguments to <code>Test::WWW::Selenium->new()</code>. All fields have defaults, so <pre><code>{
#   FF => {}
#}</code></pre> is a valid configuration (defaulting to Firefox on the same machine running the unit tests).
# See <a href="http://search.cpan.org/perldoc?WWW%3A%3ASelenium">the WWW::Selenium documentation</a> for more information.
$Foswiki::cfg{UnitTestContrib}{SeleniumRc}{Browsers} = {};
# **NUMBER**
# The base timeout in milliseconds, used when waiting for the browser (and by implication, the server) to respond.
# You may have to increase this if your test setup is slow.
$Foswiki::cfg{UnitTestContrib}{SeleniumRc}{BaseTimeout} = 5000;

# ---+++ Configure
# The following key specs are only used in testing Configure
# and do nothing.
# **STRING FEEDBACK="label='Test one';wizard='Test';method='test1';auth=1" \
#          FEEDBACK="label='Test two';wizard='Test';method='test1'" \
#          CHECK="min:3 max:20"**
# When you press either of the test buttons, expect the value to change
# to "ROPE" and there to be one each of the different levels of report.
# Default: STRING
$Foswiki::cfg{UnitTestContrib}{Configure}{STRING} = 'STRING';
# **BOOLEAN**
# Default: 1
$Foswiki::cfg{UnitTestContrib}{Configure}{BOOLEAN} = 1;
# **COMMAND**
# Default: COMMAND
$Foswiki::cfg{UnitTestContrib}{Configure}{COMMAND} = 'COMMAND';
# **DATE**
# Default: 12 Feb 2012
$Foswiki::cfg{UnitTestContrib}{Configure}{DATE} = '12 Feb 2012';
# **EMAILADDRESS**
# Default: address@email.co
$Foswiki::cfg{UnitTestContrib}{Configure}{EMAILADDRESS} = 'address@email.co';
# **NUMBER**
# Default: 666
$Foswiki::cfg{UnitTestContrib}{Configure}{NUMBER} = 666;
# **OCTAL CHECK="min:30 max:70"**
# Default: 429
$Foswiki::cfg{UnitTestContrib}{Configure}{OCTAL} = 429;
# **PASSWORD**
# Default: PASSWORD
$Foswiki::cfg{UnitTestContrib}{Configure}{PASSWORD} = 'PASSWORD';
# **PATH**
# Default: PATH
$Foswiki::cfg{UnitTestContrib}{Configure}{PATH} = 'PATH';
# **PERL FEEDBACK="label='Format';wizard='Test';method='format'" **
# Default: 'PERL'
# The test button should come back with a prettified version of your value.
#$Foswiki::cfg{UnitTestContrib}{Configure}{PERL} = '\'PERL\';';
# **REGEX**
# Default: '^regex$'
$Foswiki::cfg{UnitTestContrib}{Configure}{REGEX} = '^regex$';
# **SELECTCLASS none,Foswiki::Configure::P* **
# Default: Foswiki::Configure::Package
$Foswiki::cfg{UnitTestContrib}{Configure}{SELECTCLASS} = 'Foswiki::Configure::Package';
# **SELECT choose,life**
# Default: life
$Foswiki::cfg{UnitTestContrib}{Configure}{SELECT} = 'life';
# **URLPATH**
# Default: /
$Foswiki::cfg{UnitTestContrib}{Configure}{URLPATH} = '/';
# **URL**
# Default: http://localhost
$Foswiki::cfg{UnitTestContrib}{Configure}{URL} = 'http://localhost';
# **STRING H**
# Default: H
$Foswiki::cfg{UnitTestContrib}{Configure}{H} = 'H';
# **STRING EXPERT CHECK="nullok"**
# Default: EXPERT
$Foswiki::cfg{UnitTestContrib}{Configure}{EXPERT} = 'EXPERT';
# **PATH CHECK='nullok'**
# Default: empty
# $Foswiki::cfg{UnitTestContrib}{Configure}{empty} = 'empty';
# **STRING**
# Should contain other items
$Foswiki::cfg{UnitTestContrib}{Configure}{DEP_STRING} = 'xxx$Foswiki::cfg{UnitTestContrib}{Configure}{H}xxx';
# **PERL**
# Should contain other items
$Foswiki::cfg{UnitTestContrib}{Configure}{DEP_PERL} = {
    'string' => 'xxx$Foswiki::cfg{UnitTestContrib}{Configure}{H}xxx',
    'hash' => { 'hash' => 'xxx$Foswiki::cfg{UnitTestContrib}{Configure}{H}xxx' },
    'array' => [ '$Foswiki::cfg{UnitTestContrib}{Configure}{H}' ]
};
# **PERL**
# Default: { a => 1, b => 2 }
$Foswiki::cfg{UnitTestContrib}{Configure}{PERL_HASH} = { a => 1, b => 2 };
# **PERL**
# Default: [ 1, 2 ]
$Foswiki::cfg{UnitTestContrib}{Configure}{PERL_ARRAY} = [ 1, 2 ];
1;
