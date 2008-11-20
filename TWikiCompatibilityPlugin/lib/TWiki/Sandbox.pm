package TWiki::Sandbox;

# Bridge between TWiki::Sandbox and Foswiki::Sandbox

use strict;

use Foswiki::Sandbox;

sub TRACE { 0 }
sub new { Foswiki::Sandbox::new(@_) }
sub finish { Foswiki::Sandbox::finish(@_) }
sub untaintUnchecked { Foswiki::Sandbox::untaintUnchecked(@_) }
sub normalizeFileName { Foswiki::Sandbox::normalizeFileName(@_) }
sub sanitizeAttachmentName { Foswiki::Sandbox::sanitizeAttachmentName(@_) }
sub sysCommand { Foswiki::Sandbox::sysCommand(@_) }

1;
