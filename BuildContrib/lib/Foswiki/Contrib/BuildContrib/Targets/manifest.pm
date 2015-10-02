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

my $collector;

=begin TML

---++++ target_manifest
Generate and print to STDOUT a rough guess at the MANIFEST listing

=cut

sub target_manifest {
    my $this = shift;

    $collector = $this;
    my $manifest =
      findRelative( $Foswiki::Contrib::Build::buildpldir, 'MANIFEST' );
    if ( $manifest && -e $manifest ) {
        open( F, '<', $manifest )
          || die 'Could not open existing ' . $manifest;
        local $/ = undef;
        %{ $collector->{manilist} } =
          map { /^(.*?)(\s+.*)?$/; $1 => ( $2 || '' ) } split( /\r?\n/, <F> );
        close(F);
    }
    else {
        $manifest = $Foswiki::Contrib::Build::buildpldir . '/MANIFEST';
    }
    require File::Find;
    $collector->{manilist} = ();
    warn "Gathering from $this->{basedir}\n";

    File::Find::find( \&_manicollect, $this->{basedir} );
    print '# DRAFT ', $manifest, ' follows:', "\n";
    print '################################################', "\n";
    for ( sort keys %{ $collector->{manilist} } ) {
        print $_. ' ' . $collector->{manilist}{$_} . "\n";
    }
    print '################################################', "\n";
    print '# Copy and paste the text between the ###### lines into the file',
      "\n";
    print '# ' . $manifest, "\n";
    print '# to create an initial manifest. Remove any files',   "\n";
    print '# that should _not_ be released, and add a',          "\n";
    print '# description of each file at the end of each line.', "\n";
}

sub _manicollect {
    if (/^(CVS|\.svn|\.git)$/) {
        $File::Find::prune = 1;
    }
    elsif (
           !-d
        && /^\w.*\w$/
        && !/^(TIDY|DEPENDENCIES|MANIFEST|(PRE|POST)INSTALL|build\.pl)$/
        && !/\.bak$/
        && !/^$collector->{project}_installer(\.pl)?$/

# Item10188: Ignore build output, but still want data/System/Project.txt
# $Foswiki::Contrib::Build::basedir in \Q...\E makes it a literal string (ignore regex chars)
        && not $File::Find::name =~
/\Q$Foswiki::Contrib::Build::basedir\E\W$collector->{project}\.(md5|zip|tgz|txt|sha1)$/
      )
    {
        my $n     = $File::Find::name;
        my @a     = stat($n);
        my $perms = sprintf( "%04o", $a[2] & 0777 );
        $n =~ s/$collector->{basedir}\/?//;
        $collector->{manilist}{$n} = $perms
          unless exists $collector->{manilist}{$n};
    }
}

1;
