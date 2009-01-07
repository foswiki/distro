package TWiki::Sandbox;

# Bridge between TWiki::Sandbox and Foswiki::Sandbox

use strict;

use Foswiki::Sandbox;

# Required because TWiki sysCommand is invoked as an object method.
sub new {
    my $class = shift;
    return bless( {}, $class);
}

sub untaintUnchecked { Foswiki::Sandbox::untaintUnchecked(@_) }
sub normalizeFileName { Foswiki::Sandbox::normalizeFileName(@_) }
sub sanitizeAttachmentName { Foswiki::Sandbox::sanitizeAttachmentName(@_) }
sub sysCommand { return Foswiki::Sandbox::sysCommand(@_) }

1;
