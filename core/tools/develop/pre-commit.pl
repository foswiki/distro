#!/usr/bin/perl
use strict;

# PRE-COMMIT HOOK for Foswiki Subversion
#
# The pre-commit hook tests that the item(s) listed in the checkin
# exist(s) in Tasks web, and is(are) in a state to receive checkins.
#
# STDERR ends up on the users' terminal

my $REPOS   = $ARGV[0];
my $TXN     = $ARGV[1];
my $dataDir = '/home/foswiki.org/public_html/data';

my $SNVLOOK = '/usr/local/bin/svnlook';
my $logmsg  = `$SVNLOOK log -t $TXN $REPOS`;

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

.pl and .pm files must have been run through perltidy
(perltidy must be run without any formatting options)
--------------------------------------------------------------
EOF
    exit 1;
}

fail("No Bug item in log message") unless ( $logmsg =~ /\bItem\d+\s*:/ );
local $/;

my @items;
$logmsg =~ s/\b(Item\d+)\s*:/push(@items, $1); '';/gem;
foreach my $item (@items) {
    fail "Bug item $item does not exist"
      unless ( -f "$dataDir/Tasks/$item.txt" );
    open( F, '<', "$dataDir/Tasks/$item.txt" ) || die "Cannot open $item";
    my $text  = <F>;
    my $state = "Closed";
    if ( $text =~ /^%META:FIELD{name="CurrentState".*value="(.*?)"/m ) {
        $state = $1;
    }
    close(F);
    if ( $state =~ /^(Waiting for Release|Closed|No Action Required)$/ ) {
        fail("$item is in $state state; cannot check in");
    }
}

# Verify that code is cleanly formatted
my $changed = `$SVNLOOK changed -t $TXN $REPOS`;
my @files = map { $_ =~ /^\S+\s+(.+?)$/; $1 } split( /\n/, $changed );
foreach my $file (@files) {
    if ( $file =~ /\.p[ml]$/ ) {
        perltidy($file);
    }
}

sub perltidy {
    my $file = shift;
    my $id   = "svn$TXN";

    my $mess = `$SVNLOOK cat -t $TXN $REPOS $file > /tmp/$id.pl`;
    fail "$?: $mess" if $?;
    $mess = `perltidy -b /tmp/$id.pl`;
    fail "$?: $mess" if $?;
    $mess = `diff -q /tmp/$id.pl.bak /tmp/$id.pl`;
    my $tidy = !$?;
    unlink '/tmp/$id.pl', '/tmp/$id.pl.bak';
    fail("$file is not tidy; cannot check in:\n$mess") unless ($tidy);
}

exit 0;
