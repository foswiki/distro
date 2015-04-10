#
# Copyright (C) 2004-2012 C-Dot Consultants - All rights reserved
# Copyright (C) 2008-2014 Foswiki Contributors
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
Generate and print to STDOUT a rough guess at the .gitignore listing

=cut

sub target_gitignore {
    my $this = shift;

    # Gather up the git files list for generating a .gitignore
    my %gitfiles;
    if ( my $gitdir = findPathToDir('.git') ) {

        for my $file ( split /\n/, qx{cd $this->{basedir} && git ls-files} ) {
            $file =~ s#^$this->{basedir}/##;    # Should never happen, but safer
            $file =~ s#^(?:\.\./)*##;           # If checking not from top level
            $gitfiles{$file} = 1;
        }
    }

    $collector = $this;
    my $manifest =
      findRelative( $Foswiki::Contrib::Build::buildpldir, 'MANIFEST' );
    if ( $manifest && -e $manifest ) {
        open( F, '<', $manifest )
          || die 'Could not open existing '
          . $manifest . "\n"
          . 'Generate a valid MANIFEST file before generating .gitignore';
        local $/ = undef;
        %{ $collector->{manilist} } =
          map { /^(.*?)(\s+.*)?$/; $1 => ( $2 || '' ) } split( /\r?\n/, <F> );
        close(F);
    }
    else {
        $manifest = $Foswiki::Contrib::Build::buildpldir . '/MANIFEST';
    }
    require File::Find;
    $collector->{ignore} = ();

    for ( sort keys %{ $collector->{manilist} } ) {
        $collector->{ignore}{$_} = 1 unless ( $gitfiles{$_} );
    }

    print "\n\n" . '# DRAFT ', $this->{basedir} . '/.gitignore  follows:', "\n";
    print '################################################', "\n";
    print
      "*,v\n*,pfv\n*.gz\n"; # Ignore any store revision files and .gz compressed
    foreach my $suffix (qw(.md5 .sha1 .tgz .txt .zip _installer _installer.pl))
    {                       # Ignore the output of buildcontrib
        print "/$collector->{project}$suffix\n";
    }
    for ( sort keys %{ $collector->{ignore} } )
    {    # Ignore any file in MANIFEST that is not known to git.
        next if ( $_ =~ m/^#/ );       # Skip any comments in the MANIFEST
        next if ( $_ =~ m/\.gz$/ );    # .gz files covered by wildcard
        next if ( $_ eq '!noci' );     # Skip the !noci record
        print '/' . $_ . "\n";
    }
    print '################################################', "\n";
    print '# Copy and paste the text between the ###### lines into the file',
      "\n";
    print '# ' . $collector->{basedir} . "/.gitignore \n";
    print '# to create an initial .gitignore file.', "\n";
}

# Search the current working directory and its parents
# for a directory called like the first parameter
sub findPathToDir {
    my $lookForDir = shift;

    my @dirlist = File::Spec->splitdir( Cwd::getcwd() );
    do {
        my $dir = File::Spec->catdir( @dirlist, $lookForDir );
        return File::Spec->catdir(@dirlist) if -d $dir;
    } while ( pop @dirlist );
    return;
}

1;
