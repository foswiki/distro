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

---++++ target_handsoff_install
Install target, installs to local install pointed at by FOSWIKI_HOME.

Does not run the installer script.

=cut

sub target_handsoff_install {
    my $this = shift;
    $this->build('release');

    my $home = $ENV{FOSWIKI_HOME};
    die 'FOSWIKI_HOME not set' unless $home;
    $this->pushd($home);
    $this->sys_action( 'tar', 'zxpf',
        $this->{basedir} . '/' . $this->{project} . '.tgz' );

    # kill off the module installer
    $this->rm( $home . '/' . $this->{project} . '_installer' );
    $this->popd();
}

1;
