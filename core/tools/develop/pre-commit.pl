#!/usr/bin/perl
use strict;

# PRE-COMMIT HOOK for Foswiki Subversion
#
# The pre-commit hook tests that the item(s) listed in the checkin
# exist(s) in Tasks web, and is(are) in a state to receive checkins.
#
# STDERR ends up on the users' terminal

my $REPOS = $ARGV[0];
my $TXN = $ARGV[1];
my $dataDir = '/home/foswiki.org/data';

my $logmsg = `/usr/local/bin/svnlook log -t $TXN $REPOS`;

sub fail {
    my $message = shift;
    print STDERR <<EOF;
--------------------------------------------------------------
Illegal checkin to $REPOS:
$logmsg
$message
Log message must start with one or more names of Item
topics in the Tasks web
eg. Item12345: Item12346: example commit log
The topics *must* exist.
--------------------------------------------------------------
EOF
    exit 1;
}

fail("No Bug item in log message") unless( $logmsg =~ /\bItem\d+:/ );
local $/;

my @items;
$logmsg =~ s/\b(Item\d+):/push(@items, $1); '';/gem;
foreach my $item ( @items ) {
    fail "Bug item $item does not exist"
      unless( -f "$dataDir/Tasks/$item.txt" );
    open(F, "<$dataDir/Tasks/$item.txt") || die "Cannot open $item";
    my $text = <F>;
    my $state = "Closed";
    if( $text =~ /^%META:FIELD{name="CurrentState".*value="(.*?)"/m ) {
        $state = $1;
    }
    close(F);
    if( $state =~ /^(Waiting for Release|Closed|No Action Required)$/ ) {
        fail("$item is in $state state; cannot check in");
    }
}

exit 0;
