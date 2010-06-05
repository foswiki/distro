
=pod

---+ package Foswiki::Contrib::MailerContrib::Constants

$ALWAYS - always send, even if there are no changes
$FULL_TOPIC - send the full topic rather than just changes

=cut

package Foswiki::Contrib::MailerContrib::Constants;

use strict;
use warnings;

our $ALWAYS     = 1;
our $FULL_TOPIC = 2;

# ? = FULL_TOPIC
# ! = FULL_TOPIC | ALWAYS

1;
