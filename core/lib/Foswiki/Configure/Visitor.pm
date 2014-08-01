# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Configure::Visitor
Node visitor interface for traversing a .spec tree

=cut

package Foswiki::Configure::Visitor;

=begin TML

--++ ObjectMethod startVisit($node) -> $boolean

Called on each node in the tree as a visit starts.

Return 1 to continue the visit, or 0 to terminate it.

=cut

sub startVisit { die 'Pure virtual method' }

=begin TML

--++ ObjectMethod endVisit($node) -> $boolean

Called on each node in the tree as a visit finishes.

Return 1 to continue the visit, or 0 to terminate it.

=cut

sub endVisit { die 'Pure virtual method' }

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2010 Foswiki Contributors. Foswiki Contributors
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
