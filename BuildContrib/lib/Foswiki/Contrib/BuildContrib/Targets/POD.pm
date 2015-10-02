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

use strict;

# Build POD documentation. This target defines =%$POD%= - it
# does not generate any output. The target will be invoked
# automatically if =%$POD%= is used in a .txt file. POD documentation
# is intended for use by developers only.

# POD text in =.pm= files should use TML syntax or HTML. Packages should be
# introduced with a level 1 header, ---+, and each method in the package by
# a level 2 header, ---++. Make sure you document any global variables used
# by the module.

sub target_POD {
    my $this = shift;
    $this->{POD} = '';
    local $/ = "\n";
    foreach my $file ( @{ $this->{files} } ) {
        my $pmfile = $file->{name};
        if ( $pmfile =~ /\.p[ml]$/o ) {
            next if $pmfile =~ /^$this->{project}_installer(\.pl)?$/;
            $pmfile = $this->{basedir} . '/' . $pmfile;
            open( PMFILE, '<', $pmfile ) || die $!;
            my $inPod = 0;
            while ( my $line = <PMFILE> ) {
                if ( $line =~ /^=(begin|pod)/ ) {
                    $inPod = 1;
                }
                elsif ( $line =~ /^=cut/ ) {
                    $inPod = 0;
                }
                elsif ($inPod) {
                    $this->{POD} .= $line;
                }
            }
            close(PMFILE);
        }
    }
}

1;
