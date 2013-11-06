#! /usr/bin/perl -w

use strict;
use warnings;

my %rebase;
my $debug       = shift || 0;
my $fwhome      = "$ENV{HOME}/foswiki/core";
my $cleanScript = "git.sh";
my @pushTo      = qw( github gitorious );

sub debug {
    return unless $debug;
    for (@_) {
        local $_ = $_;
        chomp;
        print STDERR "[DEBUG] $_\n";
    }
}

debug "Using $fwhome as FOSWIKI_HOME";
my ($gitroot) = $fwhome =~ m#^(.*)/[^/]*$#;
die "$gitroot does not exist" unless -d $gitroot;
chdir $gitroot or die " Could not change to $gitroot: $!";
if ( !-x "core/pseudo-install.pl" ) {
    debug "No pseudo-install.pl. Trying to checkout master...";
    system("git checkout master");
}
$ENV{FOSWIKI_LIBS} = "$fwhome/lib:$fwhome/lib/CPAN/lib";
$ENV{FOSWIKI_HOME} = $fwhome;
if ( -x "./$cleanScript" ) {
    debug "$cleanScript is OK";
    unless ( my $rc = system("./$cleanScript >/dev/null") ) {
        $rc = $rc >> 8;
        debug "$cleanScript did not return OK [$rc] doing diff: $!";
        system("git diff");
        exit;
    }
}

debug "Starting fetching...";
open my $in, '-|', 'git svn fetch' or die "Cannot git svn fetch: $!";
while (<$in>) {

    #r7196 = 93dec3e1cd68a939ec01e2a412c7549094f97b76 (scratch)
    if (/^(r\d+) = (\S+) \((\S+)\)$/) {
        $rebase{$3} = $2;
    }
    print;
    debug $_;
}
close $in;

# Check if we have anything to do
unless ( scalar keys %rebase ) {
    debug "Nothing to do!";
    exit 0;
}

# Rebase local branches
for ( sort keys %rebase ) {
    my $origin = $_;
    s#^refs/remotes/##;    # Remove git 1.7 fully qualified remotes
    s/trunk/master/;       # Alias trunk (SVN) to master (git)
    print "Rebasing $origin to $_ ($rebase{$origin})\n";
    system("git rebase $rebase{$origin} $_");
}

# Push to remote repositories
system("git push $_") for @pushTo;
