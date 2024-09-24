# See bottom of file for license and copyright information

package Foswiki::Logger::PlainFile::EventIterator;

use strict;
use warnings;
use Assert;

use Foswiki::Iterator::EventIterator ();
use Fcntl qw(:flock);

BEGIN {
    if ( $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

# Internal class for Logfile iterators.
# So we don't break encapsulation of file handles.  Open / Close in same file.
our @ISA = qw/Foswiki::Iterator::EventIterator/;

# # Object destruction
# # Release locks and file
sub DESTROY {
    my $this = shift;
    flock( $this->{handle}, LOCK_UN )
      if ( defined $this->{logLocked} );
    close( delete $this->{handle} ) if ( defined $this->{handle} );
}

1;
__END__
Module of Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2024 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
