#! /usr/bin/env perl
#
# git-fix-meta.pl [path/to/file1] [path/to/file2]
#
# Run this script from the root of your checkout.  It lists all modified
# files, and makes the following fixups to the topic metadata
#  - Updates date to current timestamp
#  - Changes author & user to 'ProjectContributor'
#  - Changes version to 1
#  - Removes comment, reprev and path args
#  - Converts autoattached files to hidden attachments
#  - Adds a user= when missing from attachments.
#
# If run with one or more optional filenames, the git status command is omitted
# and the named files are updated.
#

use warnings;
use strict;

my $gitstatus;
my @files;

if (@ARGV) {
    @files     = @ARGV;
    $gitstatus = 0;
}
else {
    @files     = `git status -uno --porcelain`;
    $gitstatus = 1;
}

foreach my $f (@files) {
    if ($gitstatus) {
        chomp $f;
        $f = substr( $f, 3 );
    }
    next
      unless $f =~
/data\/(?:System|Sandbox|TestCases|Main|_empty|_default|Trash|TWiki)\/.*?\.txt$/;
    print "Fixing timestamp on: $f\n";
    my $date = time;
    open( F, "<", "$f" ) || die "Could not open $f for read";
    my @lines;
    while ( my $l = <F> ) {
        chomp($l);
        if ( $l =~ /^%META:(TOPICINFO|FILEATTACHMENT)\{(.*)\}%$/ ) {
            $l =~ s/date=\"\d+\"/date="$date"/;
            $l =~ s/author=\"[^\"]+\"/author="ProjectContributor"/;
            $l =~ s/user=\"[^\"]+\"/user="ProjectContributor"/;
            $l =~ s/version="\d*"/version="1"/;
            $l =~ s/comment=\"[^\"]+\"//;
            $l =~ s/reprev=\"[^\"]+\"//;
            $l =~ s/[\s]+/ /;
            $l =~ s/ attr="" autoattached="1"/ attr="h"/;
            $l =~ s/ path="[^"]*"//;
        }
        if ( $l =~ /^%META:FILEATTACHMENT\{(.*)\}%$/ && $l !~ m/user=/ ) {
            $l =~ s/date=/user="ProjectContributor" date=/;
        }
        push( @lines, $l );
    }
    close(F);
    open( F, ">", "$f" ) || die "Could not open $f for write";
    print F join( "\n", @lines ) . "\n";
    close(F);
}
