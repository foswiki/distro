# ---+ Extensions
# ---++ UnitTestContrib
# Foswiki Unit-Test Framework
# ---+++ Selenium Remote Control
# For browser-in-the-loop testing

# **STRING 30 LABEL="Username" CHECK='emptyok' **
# The UnitTestContrib needs a username to access (i.e. edit) the testcase web and topic from the browser opened by Selenium RC.
$Foswiki::cfg{UnitTestContrib}{SeleniumRc}{Username} = '';

# **PASSWORD 30 LABEL="Password" CHECK="emptyok" **
# The password for the Selenium RC user
$Foswiki::cfg{UnitTestContrib}{SeleniumRc}{Password} = '';

# **PERL 40x10 LABEL="Browsers" CHECK='undefok'**
# List the browsers accessible via Selenium RC.
# It is keyed by browser identifier - you choose the identifiers as seems sensible. Browser identifiers may only consist of alphanumeric characters.
# Examples: <code>FF3 FF2dot1OnWindows IE6_1_345 w3m</code>
# <br />
# The values are hashes of arguments to <code>Test::WWW::Selenium->new()</code>. All fields have defaults, so <pre><code>{
#   FF => {}
#}</code></pre> is a valid configuration (defaulting to Firefox on the same machine running the unit tests).
# See <a href="http://search.cpan.org/perldoc?WWW%3A%3ASelenium">the WWW::Selenium documentation</a> for more information.
$Foswiki::cfg{UnitTestContrib}{SeleniumRc}{Browsers} = {};

# **NUMBER LABEL="Base Timeout"**
# The base timeout in milliseconds, used when waiting for the browser (and by implication, the server) to respond.
# You may have to increase this if your test setup is slow.
$Foswiki::cfg{UnitTestContrib}{SeleniumRc}{BaseTimeout} = 5000;

# ---+++ Configure
# The following key specs are only used in testing Configure
# and do nothing.
# **STRING LABEL="STRING" FEEDBACK="label='Test one';wizard='Test';method='test1';auth=1" \
#          FEEDBACK="label='Test two';wizard='Test';method='test1'" \
#          CHECK="min:3 max:20 undefok"**
# When you press either of the test buttons, expect the value to change
# to "ROPE" and there to be one each of the different levels of report.
# Default: STRING
$Foswiki::cfg{UnitTestContrib}{Configure}{STRING} = 'STRING';

# **BOOLEAN LABEL="BOOLEAN"**
# Default: 1
$Foswiki::cfg{UnitTestContrib}{Configure}{BOOLEAN} = 1;

# **COMMAND LABEL="COMMAND"**
# Default: COMMAND
$Foswiki::cfg{UnitTestContrib}{Configure}{COMMAND} = 'COMMAND';

# **DATE LABEL="DATE" CHECK="undefok"**
# Default: 12 Feb 2012
$Foswiki::cfg{UnitTestContrib}{Configure}{DATE} = '12 Feb 2012';

# **EMAILADDRESS LABEL="EMAILADDRESS" CHECK="undefok"**
# Default: address@email.co
$Foswiki::cfg{UnitTestContrib}{Configure}{EMAILADDRESS} = 'address@email.co';

# **NUMBER LABEL="NUMBER" CHECK="undefok"**
# Default: 666
$Foswiki::cfg{UnitTestContrib}{Configure}{NUMBER} = 666;

# **OCTAL LABEL="OCTAL" CHECK="min:30 max:70 undefok"**
# Default: 035
$Foswiki::cfg{UnitTestContrib}{Configure}{OCTAL} = 035;

# **PASSWORD LABEL="PASSWORD"**
# Default: PASSWORD
$Foswiki::cfg{UnitTestContrib}{Configure}{PASSWORD} = 'PASSWORD';

# **PATH LABEL="PATH" CHECK="undefok"**
# Default: PATH
$Foswiki::cfg{UnitTestContrib}{Configure}{PATH} = 'PATH';

# **PERL LABEL="PERL" FEEDBACK="label='Format';wizard='Test';method='format'" CHECK="undefok"**
# Default: 'PERL'
# The test button should come back with a prettified version of your value.
#$Foswiki::cfg{UnitTestContrib}{Configure}{PERL} = '\'PERL\';';

# **REGEX LABEL="REGEX" CHECK="undefok"**
# Default: '^regex$'
$Foswiki::cfg{UnitTestContrib}{Configure}{REGEX} = '^regex$';

# **SELECTCLASS none,Foswiki::Configure::P* LABEL="SELECTCLASS" **
# Default: Foswiki::Configure::Package
$Foswiki::cfg{UnitTestContrib}{Configure}{SELECTCLASS} = 'Foswiki::Configure::Package';

# **SELECT choose,life LABEL="SELECT"**
# Default: life
$Foswiki::cfg{UnitTestContrib}{Configure}{SELECT} = 'life';

# **URLPATH CHECK="undefok" LABEL="URLPATH"**
# Default: /
$Foswiki::cfg{UnitTestContrib}{Configure}{URLPATH} = '/';

# **URL CHECK="undefok" LABEL="URL"**
# Default: http://localhost
$Foswiki::cfg{UnitTestContrib}{Configure}{URL} = 'http://localhost';

# **STRING H LABEL="STRING H" CHECK="noemptyok noundefok"**
# Default: H
$Foswiki::cfg{UnitTestContrib}{Configure}{H} = 'H';

# **STRING LABEL="STRING EXPERT" EXPERT CHECK="undefok"**
# Default: EXPERT
$Foswiki::cfg{UnitTestContrib}{Configure}{EXPERT} = 'EXPERT';

# **PATH LABEL="PATH empty" CHECK='undefok'**
# Default: empty
# $Foswiki::cfg{UnitTestContrib}{Configure}{empty} = 'empty';

# **STRING LABEL="Undefok" CHECK='undefok'**
# Default: value
$Foswiki::cfg{UnitTestContrib}{Configure}{undefok} = 'value';

# **STRING LABEL="DEP_STRING" CHECK="undefok"**
# Should contain other items
$Foswiki::cfg{UnitTestContrib}{Configure}{DEP_STRING} = 'xxx$Foswiki::cfg{UnitTestContrib}{Configure}{H}xxx';

# **PERL LABEL="DEP_PERL" CHECK="undefok"**
# Should contain other items
$Foswiki::cfg{UnitTestContrib}{Configure}{DEP_PERL} = {
    'string' => 'xxx$Foswiki::cfg{UnitTestContrib}{Configure}{H}xxx',
    'hash' => { 'hash' => 'xxx$Foswiki::cfg{UnitTestContrib}{Configure}{H}xxx' },
    'array' => [ '$Foswiki::cfg{UnitTestContrib}{Configure}{H}' ]
};

# **PERL LABEL="PERL_HASH" CHECK="undefok"**
# Default: { a => 1, b => 2 }
$Foswiki::cfg{UnitTestContrib}{Configure}{PERL_HASH} = { a => 1, b => 2 };

# **PERL LABEL="PERL_ARRAY" CHECK="undefok"**
# Default: [ 1, 2 ]
$Foswiki::cfg{UnitTestContrib}{Configure}{PERL_ARRAY} = [ 1, 2 ];

1;
