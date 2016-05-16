#! /usr/bin/env perl
#
# Use this script from the root of your foswiki "distro" clone, or an extension clone
# prior to committing changes.  It lists all modified .txt files, and will make the following changes
#  - Topic and attachment dates sete to the current timestamp
#  - Author set to ProjectContributor
#  - Version set to 1.
#  - Changes "auto-attached" attachments to hidden
#  - Removes autoattach flag
#  - Removes "path", "stream" and "tmpFilename" attributes
#
my @files = `git status -uno --porcelain`;

foreach my $f (@files) {
    chomp $f;
    $f = substr( $f, 3 );
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
            $l =~ s/comment=\"reprev\"//;
            $l =~ s/reprev=\"[^\"]+\"//;
            $l =~ s/[\s]+/ /;
            $l =~ s/ attr="" autoattached="1"/ attr="h"/;
            $l =~ s/ autoattached="[^"]*"//;
            $l =~ s/ path="[^"]*"//;
            $l =~ s/ stream="[^"]*"//;
            $l =~ s/ tmpFilename="[^"]*"//;
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
