#!/usr/bin/perl -wT
# --
# send latest Subversion commit to twitter

use strict;

$ENV{PATH} = '/usr/bin';
use Net::Twitter;

my $twit = Net::Twitter->new(
    username   => "Foswiki",
    password   => "yo?udidwh#at",
    clientname => 'Foswiki'
);

open my $svnlog, '-|', '/usr/local/bin/svn log -r HEAD http://svn.foswiki.org'
  or die "Can't open svn log pipe: $!";

my ( $rev, $who, $when, $howMuch, $data );

while (<$svnlog>) {
    next if /^-*$/;    # Skip empty and first + last line which are only ---
    if (/^(r\d+)\s+\|\s+(\S+)\s+\|\s+([^\|]+)\s+\|\s+(.*)$/) {

# r1996 | KennethLavrsen | 2009-01-16 02:18:38 +0000 (Fri, 16 Jan 2009) | 5 lines
        ( $rev, $who, $when, $howMuch ) = ( $1, $2, $3, $4 );
        next;
    }
    $data .= $_;
}
close $svnlog;

exit unless $data;

my $message = "$who commited $rev - $data";

# Twitter is limited to 140 characters
$message =~ s/^(.{137}).*$/$1.../s if length($message) > 140;

unless ( $twit->update($message) ) {

    # update returns undef if it fails => warn
    die "Couldn't update Twitter with $message";
}
