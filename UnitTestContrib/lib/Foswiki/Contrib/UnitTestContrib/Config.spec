# ---+ Extensions
# ---++ UnitTestContrib
# Foswiki Unit-Test Framework
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
$Foswiki::cfg{UnitTestContrib}{SeleniumRc} = {};

