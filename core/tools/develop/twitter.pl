#!/usr/bin/perl -wT
#
$ENV{PATH} = '/usr/bin';
use Net::Twitter;

my $twit = Net::Twitter->new(
		username=>"nextwiki", 
		password=>"yo?udidwh#at",
		clientname=>'Nextwiki'
	);

my $cmd = '/usr/local/bin/svn log -r HEAD http://svn.nextwiki.org';

my $svnOutput = `$cmd`;
my ($header, $info, $empty, $data) = split(/\n/, $svnOutput);
exit unless (defined($data));
my ($rev, $who, $when, $howMuch) = split(/\|/, $info);

my $message = "$who commited $rev - $data";
#print $message;
$result = $twit->update($message);

