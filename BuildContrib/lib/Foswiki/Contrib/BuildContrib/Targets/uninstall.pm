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

---++++ target_uninstall
Uninstall target, uninstall from local twiki pointed at by FOSWIKI_HOME.

Uses the installer script written by target_installer

=cut

sub target_uninstall {
    my $this = shift;
    my $home = $ENV{FOSWIKI_HOME};
    die 'FOSWIKI_HOME not set' unless $home;
    $this->pushd($home);
    $this->sys_action( 'perl', $this->{project} . '_installer', 'uninstall' );
    $this->popd();
}

1;
