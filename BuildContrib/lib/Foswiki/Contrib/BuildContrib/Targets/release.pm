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

---++++ target_release
Release target, builds release zip by creating a full release directory
structure in /tmp and then zipping it in one go. Only files explicitly listed
in the MANIFEST are released. Automatically runs =filter= on all =.txt= files
in the MANIFEST.

=cut

sub target_release {
    my $this = shift;

    print <<GUNK;

Building release $this->{RELEASE} of $this->{project}, from version $this->{VERSION}
GUNK
    if ( $this->{-v} ) {
        print 'Package name will be ', $this->{project}, "\n";
        print 'Topic name will be ', $this->getTopicName(), "\n";
    }

    $this->build('compress');
    $this->build('build');
    $this->build('installer');
    $this->build('stage');
    $this->build('archive');
}

1;
