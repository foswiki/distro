#!/usr/bin/perl

use strict;
use warnings;

# cruise back up the tree until we find lib and data subdirs
use Cwd;
use File::Spec;
use File::Find;

my $manifest    = shift || 'MANIFEST';
my @skip        = qw(tools test working logs);
my $cvs         = 'subversion';
my $skipPattern = join( '|', @skip );
my @lost;    # Files on disk not in MANIFEST
my %man;     # Hash of MANIFEST content: file => perm
my %alt;     # Hash of alternate version of _src file

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

# Checks if a file is in the MANIFEST, and removes it
# otherwise, adds it to @lost
sub isFileInManifest {
    my ( $root, $file ) = @_;

    my $diskfile = "$root/$file";
    return if -d $diskfile;    # For Subversion
    if ( my $mode = delete $man{$file} ) {
        my $cmode = ( stat($diskfile) )[2] & 07777;
        printf "Permissions for $file differ"
          . " in MANIFEST ($mode) and on disk (%lo)\n", $cmode
          if oct( 0 + $mode ) != $cmode;
    }
    else {
        return if $file =~ m#^(?:$skipPattern)/#o;    # For git
        return if $file =~ m#/TestCases/#;
        push @lost, $file;
    }

    # Try to save file alternate versions, just in case
    $alt{"$file.gz"}++;
    if ( $file =~ /^(.*)_src(\..*)$/ ) {
        $alt{"$1$2"}++;
        $alt{"$1$2.gz"}++;
    }
}

# Prints some "helpful" messages
sub help {
    print <<"END";
Run this script from a directory with a MANIFEST file, or from a top level of
an extension, or from within an extension, passing the path of the MANIFEST as
first parameter.

The script will find and scan MANIFEST and compare the contents with what is
checked in under $cvs. Any differences are reported.

It will also compare permissions given in the MANIFEST with permissions which
are on disk.

END
    print "The " . join( ', ', @skip ) . " directories are *not* scanned.\n";
}

my $root = findPathToDir('lib');
die "Can't find root" unless ( -d "$root/lib" && -d "$root/data" );

unless ( -f $manifest ) {
    File::Find::find(
        sub {
            /^MANIFEST\z/ && ( $manifest = $File::Find::name );
        },
        File::Spec->catdir( $root, 'lib' )
    );
}
die "No such MANIFEST $manifest" unless -e $manifest;

open my $man, '<', $manifest or die "Can't open $manifest for reading: $!";
while (<$man>) {
    next if /^!include/;
    $man{$1} = $2 if /^(\S+)\s+(\d+)/;
}
close $man;

if ( my $gitdir = findPathToDir('.git') ) {
    $cvs = 'git';
    help($cvs);
    for my $file ( split /\n/, qx{cd $root && git ls-files} ) {
        $file =~ s#^$root/##;        # Should never happen, but safer
        $file =~ s#^(?:\.\./)*##;    # If checking not from top level
        isFileInManifest( $root => $file );
    }
}
else {
    help($cvs);
    foreach my $dir (
        grep { -d "$root/$_" }
        split( /\n/, `svn ls $root` )
      )
    {
        next if $dir =~ m#/(?:$skipPattern)/#o;
        print "Examining $root/$dir\n";
        for my $file (
            map { "$dir$_" }
            split( /\n/, `svn ls -R $root/$dir` )
          )
        {
            isFileInManifest( $root => $file );
        }
    }
}

if (@lost) {
    my $lost = scalar @lost;
    print "The following $lost file"
      . ( $lost > 1 ? 's' : '' )
      . " files were found in $cvs, but are not in MANIFEST:\n";
    print join( "\n", @lost, '' );
}
else {
    print "All files in MANIFEST are checked in.\n";
}
my @found = sort grep { !delete $alt{$_} } keys %man;
if (@found) {
    my $found = scalar @found;
    print "The following $found file"
      . ( $found > 1 ? 's' : '' )
      . " were found in MANIFEST, but not in $cvs:\n";
    print join( "\n", @found, '' );
}
else {
    print "All files in MANIFEST are in $cvs.\n";
}
