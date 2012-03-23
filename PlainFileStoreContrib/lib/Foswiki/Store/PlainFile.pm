# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Store::PlainFile

Implementation of =Foswiki::Store= for stores that do not use any
revision control tools, but simply use naming to distinguish file
versions.

=cut

package Foswiki::Store::PlainFile;

use strict;
use warnings;

use Foswiki::Store::VC::Store ();
our @ISA = ('Foswiki::Store::VC::Store');

use Foswiki::Store::VC::PlainFileHandler ();

sub getHandler {
    my $this = shift;
    return new Foswiki::Store::VC::PlainFileHandler( $this, @_ );
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2012 Crawford Currie http://c-dot.co.uk

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
