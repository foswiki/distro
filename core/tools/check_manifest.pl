#! /usr/bin/perl

use strict;

# cruise back up the tree until we find lib and data subdirs
require Cwd;
use File::Find;

my $manifest = 'MANIFEST';

#unless (-f $manifest) {
#    File::Find::find( sub { /^MANIFEST\z/ && ( $manifest = $File::Find::name )
#			  }, "$root/lib/TWiki" );
#}
die "No such MANIFEST $manifest" unless -e $manifest;

my %man;

open MAN, '<', $manifest or die "Can't open $manifest for reading: $!";
while (<MAN>) {
    next if /^!include/;
    $man{$1} = 1 if /^(\S+)\s+\d+.*$/;
}
close MAN;

my @cwd = split( /[\/\\]/, Cwd::getcwd() );
my $root;

while ( scalar(@cwd) > 1 ) {
    $root = join( '/', @cwd );
    if ( -d "$root/lib" && -d "$root/data" ) {
        last;
    }
    pop(@cwd);
}

die "Can't find root" unless ( -d "$root/lib" && -d "$root/data" );

my @skip = qw(tools test working logs);
print <<END;
Run this script from anywhere a directory with a MANIFEST file

The script will find and scan MANIFEST and compare the contents with
what is checked in under subversion. Any differences are reported.

END
print "The ", join( ',', @skip ), " directories are *not* scanned.\n";

my @lost;
my $sk = join( '|', @skip );
foreach my $dir (
    grep { -d "$root/$_" }
    split( /\n/, `svn ls $root` )
  )
{
    next if $dir =~ /^($sk)\/$/;
    print "Examining $root/$dir\n";
    push( @lost,
        grep { !$man{$_} && !/\/TestCases\// && !-d "$root/$_" }
          map { "$dir$_" }
          split( /\n/, `svn ls -R $root/$dir` ) );
}
print "The following files were found in subversion, but are not in MANIFEST\n";
print join( "\n", @lost ), "\n";
