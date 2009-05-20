
=pod

---+ package MailerConst

$ALWAYS - always send, even if there are no changes
$FULL_TOPIC - send the full topic rather than just changes

Note that this package is defined in a file with a name different to that
of the package. This is intentional (it's to keep the length of the constants
package name short).

=cut

package MailerConst;

use strict;

our $ALWAYS     = 1;    # Always send, even if there are no changes
our $FULL_TOPIC = 2;    # Send the full topic rather than just changes

# ? = FULL_TOPIC
# ! = FULL_TOPIC | ALWAYS

1;
