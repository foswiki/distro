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
sub checkFileInManifest {
    my ( $root, $file ) = @_;

    my $diskfile = "$root/$file";
    return if -d $diskfile;    # For Subversion
    if ( my $mode = delete $man{$file} ) {
        my $cmode = ( stat($diskfile) )[2] & 07777;
        print "Permissions for $file differ"
          . " in MANIFEST ($mode) and on disk ($cmode)\n"
          if $cmode != $mode;
    }
    else {
        return if $file =~ m#^(?:$skipPattern)/#o;    # For git
        return if $file =~ m#/TestCases/#;
        push @lost, $file;
    }
}

# Prints some "helpful" messages
sub help {
    print <<"END";
Run this script from a directory with a MANIFEST file.

The script will find and scan MANIFEST and compare the contents with
what is checked in under $cvs. Any differences are reported.

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
    for my $file ( split /\n/, qx{git ls-files $root} ) {
        $file =~ s#^$root/##;    # Should never happen, but safer
        checkFileInManifest( $root => $file );
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
            checkFileInManifest( $root => $file );
        }
    }
}
if (@lost) {
    print "The following "
      . ( scalar @lost )
      . " files were found in $cvs, but are not in MANIFEST:\n";
    print join( "\n", @lost, '' );
}
else {
    print "All files in MANIFEST are checked in.\n";
}
my @found = sort keys %man;
if (@found) {
    print "The following "
      . ( scalar @found )
      . " files were found in MANIFEST, but not in $cvs:\n";
    print join( "\n", @found, '' );
}
