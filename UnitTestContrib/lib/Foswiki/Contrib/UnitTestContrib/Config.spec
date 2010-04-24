# ---+ Extensions
# ---++ UnitTestContrib
# Foswiki Unit-Test Framework
# ---+++ Selenium Remote Control
# For browser-in-the-loop testing
# **STRING 30**
# The UnitTestContrib needs a username to access the testcase web and topic from the browser opened by Selenium RC.
$Foswiki::cfg{UnitTestContrib}{SeleniumRc}{Username} = '';
# **PASSWORD 30**
# The password for the Selenium RC user
$Foswiki::cfg{UnitTestContrib}{SeleniumRc}{Password} = '';
# **PERL 40x10**
# List the browsers accessible via Selenium RC.
# It is keyed by browser identifier - you choose the identifiers as seems sensible. Browser identifiers must be valid perl identifiers.
# Examples: <code>FF3 FF2dot1OnWindows IE6_1_345 w3m</code>
# <br />
# The values are hashes of arguments to <code>WWW::Selenium->new()</code>. All fields have defaults, so <pre><code>{
#   FF => {}
#}</code></pre> is a valid configuration. 
# See the <a href="http://search.cpan.org/perldoc?WWW%3A%3ASelenium">WWW::Selenium documentation</a> for more information.
# <ul>
#   <li> <code>host</code> - defaults to <code>"localhost"</code> </li>
#   <li> <code>port</code> - defaults to <code>4444</code> </li>
#   <li> <code>browser</code> - defaults to <code>"*firefox"</code> </li>
#   <li> <code>browser_url</code> - defaults to <code>$Foswiki::cfg{DefaultUrlHost}</code> </li>
# </ul>
# <p />
# <em><strong>You</strong> are responsible for starting the Selenium RC server on the specified host(s).</em>
$Foswiki::cfg{UnitTestContrib}{SeleniumRc}{Browsers} = {};
# **NUMBER**
# The base timeout in milliseconds, used when waiting for the browser (and by implication, the server) to respond.
# You may have to increase this if your test setup is slow.
$Foswiki::cfg{UnitTestContrib}{SeleniumRc}{BaseTimeout} = 5000;

