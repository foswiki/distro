#!/usr/bin/perl -w
# --
# send latest Subversion commit to github, split per module

use strict;
use warnings;
use Git::Repository;

my $verbose    = 1;                               # 1 for debug
my $repository = shift || '/home/svn/nextwiki';
my $statefile  = '/home/git/last-git-split';
my $lastrev    = shift;
chomp( $lastrev = `/usr/local/bin/svnlook youngest $repository` )
  unless $lastrev;

# Read up to where has already been processed
sub getLastProcessedRev {
    my $firstrev = 11813;
    if ( -f $statefile ) {
        open( my $state, '<', $statefile ) or die "Can't open $statefile: $!";
        chomp( $firstrev = <$state> );
        close $state;
    }
    return $firstrev;
}

# Build modified plugins per branch
sub buildModifiedList {
    my $revision       = shift;
    my $modifiedPlugin = shift;    # hash ref built recursively
    return unless $revision;
    open( my $svnlook, '-|',
        "/usr/local/bin/svnlook dirs-changed -r $revision $repository" )
      or die "Can't open svn look pipe: $!";

    while (<$svnlook>) {
        if ( m#^(trunk)/([^/]*)/# || m#^(?:branches|tags)/([^/]*)/([^/]*)/# ) {
            my $plugin = $2;
            my $branch = $1 || 'master';
            for ($branch) {
                s/trunk/master/;
            }
            $modifiedPlugin->{$plugin}->{$branch}++;
        }
    }
    close $svnlook;
}

my %modifiedPlugin;
my $startrev = getLastProcessedRev() + 1;
warn "F:$startrev L:$lastrev" if $verbose;
for my $revision ( $startrev .. $lastrev ) {
    buildModifiedList( $revision, \%modifiedPlugin );
}

exit unless keys %modifiedPlugin;

for my $module ( sort keys %modifiedPlugin ) {
    for my $branch ( sort keys %{ $modifiedPlugin{$module} } ) {
        warn "Module $module, branch $branch needs updating" if $verbose;
    }
}
