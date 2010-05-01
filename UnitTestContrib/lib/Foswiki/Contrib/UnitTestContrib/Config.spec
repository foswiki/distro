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
# **PERL 40x10**
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

