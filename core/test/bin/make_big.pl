#!/usr/bin/perl
# Copyright (C) WikiRing 2007
# Author: Crawford Currie
# Generate large test data. This script is primarily designed for running
# stand-alone to generate large test data. It requires /usr/lib/dict
# to be installed.

use strict;

sub usage {
    print STDERR <<USAGE;
Usage: $0 <options>
Options:
    -webs <w> - generate <w> webs (default 1)
    -topics <t> - generate <t> additional topics in
     each web (default 0)
    -size <s> - target number of words to put in
     each additional topic (default 501)
    -base <base> - base for new web and topic names
     (default IncredibleHulk)

This script must be run while cd'ed to the root directory
of a TWiki install. It checks for data and pub dirs and
refuses to run without them.

Using <base> as the base for new web names, generates
<w> new webs using _default as the basis. The standard
topics from _default are always included, and will
generate <t> additional topics in each generated web.
Additional topics are named using <base>, are plain text,
and are generated using words picked from
/usr/share/dict. Each new topic will contain <s> words
taken sequentially from the dictionary. Generated topics
have no histories and no meta-data, just text.

Web names are generated from <base> by appending decimal
numbers to generate unique web names. Topic names are
generated the same way. You are recommended to use unique
web names to make a later rm -r as safe as possible.

USAGE
    exit 1;
}

unless ( -w "data" && -w "pub" ) {
    usage();
}

my $dict = '/usr/share/dict/words';
my $dict_fh;

# Get $n words from the dictionary
sub getWords {
    my ($n) = @_;
    local $/ = "\n";
    my $words = '';
    my $word;
    if ( !$dict_fh ) {
        open( $dict_fh, '<', $dict ) || die $!;
    }
    while ($n) {
        while ( $n && ( $word = <$dict_fh> ) ) {
            $words .= $word;
            $n--;
        }
        last unless $n;
        close($dict_fh);
        open( $dict_fh, '<', $dict );
    }

    return $words;
}

my %opts = (
    webs   => 1,
    topics => 0,
    size   => 501,
    base   => 'IncredibleHulk',
);

while ( my $arg = shift @ARGV ) {
    if ( $arg =~ /^-(\w+)$/ ) {
        $opts{$1} = shift @ARGV;
    }
    else {
        print STDERR "Unrecognised option $arg";
        usage();
    }
}

my $newWebs = 0;
my $nextWeb = 0;
while ( $newWebs < $opts{webs} ) {
    while ( -e "data/$opts{base}$nextWeb" ) {
        $nextWeb++;
    }
    my $web = "$opts{base}$nextWeb";

    # Create the web
    mkdir("data/$web");
    `cp data/_default/*.txt data/$web`;
    my $newTopics = 0;
    my $nextTopic = 0;
    while ( $newTopics < $opts{topics} ) {
        while ( -e "data/$web/$opts{base}$nextTopic.txt" ) {
            $nextTopic++;
        }
        my $topic = "$opts{base}$nextTopic";
        open( TOPIC, '>', "data/$web/$topic.txt" ) || die $!;
        my $t = time();
        print TOPIC <<FLUFF;
%META:TOPICINFO{author="ProjectContributor" date="$t" format="1.1" version="1"}%
FLUFF
        print TOPIC getWords( $opts{size} );
        close(TOPIC);
        $newTopics++;
        print "Generated topic $topic                             \r";
    }
    print "Generated web $web                                     \n";
    $newWebs++;
}
