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

my @tidyFilters = ( { RE => qr/\.pl$/ }, { RE => qr/\.pm$/ }, );
my $collector;

=begin TML

---++++ target_tidy
Reformat .pm and .pl files using perltidy default options

=cut

sub target_tidy {
    my $this = shift;
    require Perl::Tidy;    # Will throw exception if not available

    # Can't use the MANIFEST list, otherwise we miss tests etc, so apply
    # to all files found under lib.
    require File::Find;
    my @files = ();
    $collector = \@files;
    File::Find::find( \&_isPerl, "$this->{basedir}" );

    foreach my $path (@files) {
        print "Tidying $path\n";
        local @ARGV = ($path);
        Perl::Tidy::perltidy(
            perltidyrc =>
              '/dev/null'    # SMELL: use the extension's TIDY file if present
        );
        File::Copy::move( "$path.tdy", $path );
    }
}

sub _isPerl {
    if ( $File::Find::name =~ /(CVS|\.svn|\.git|~)$/ ) {
        $File::Find::prune = 1;
    }
    elsif ( !-d $File::Find::name ) {
        if ( $File::Find::name =~ /\.p[lm]$/ ) {
            push( @$collector, $File::Find::name );
        }
        elsif ( $File::Find::name !~ m#\.[^/]+$#
            && open( F, '<', $File::Find::name ) )
        {
            local $/ = "\n";
            my $shebang = <F>;
            close(F);
            if ( $shebang && $shebang =~ /^#!.*perl/ ) {
                push( @$collector, $File::Find::name );
            }
        }
    }
}

1;
