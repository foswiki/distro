#
# Copyright (C) 2004-2012 C-Dot Consultants - All rights reserved
# Copyright (C) 2008-2010 Foswiki Contributors
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html
#
package Foswiki::Contrib::Build;

=begin TML

---++++ target_pod

Print POD documentation. This target does not modify any files, it simply
prints the (TML format) POD.

POD text in =.pm= files should use TML syntax or HTML. Packages should be
introduced with a level 1 header, ---+, and each method in the package by
a level 2 header, ---++. Make sure you document any global variables used
by the module.

=cut

sub target_pod {
    my $this = shift;
    $this->target_POD();
    print $this->{POD} . "\n";
}

1;
