#! /usr/bin/perl
# One day this will be twikishell config command script
# This script will install any topics from _default into the named web
# You need this because some of the Web* topics have changed from Cairo
# And others (like WebLeftBar, WebTopicCreator) have been added
# This adds those files

use strict;
use File::Copy;

# notably not WebStatistics.txt WebHome.txt WebNotify.txt WebPreferences.txt
#
# Keeps old copies in _junk_oldtopics
my $dataDir     = ".";
my $oldweb      = '_junk_oldtopics';
my $templateweb = "_default";
my $doit        = 1;

my @topics = qw(WebChanges WebLeftBar WebRss WebSearch WebTopicCreator
  WebIndex WebSearchAdvanced WebTopicList);

my @targetWebs = @ARGV;
unless ( $#targetWebs > -1 ) {
    die "You must supply a list of webs to install into. e.g. $0 Main\n";
}

if ( grep /^TWiki$/, @targetWebs ) {
    die
"Don't include the TWiki web as the list of webs to install topics from _default - it has special entries that must be preserved\n";
}

foreach my $web (@targetWebs) {
    installFilesIntoWeb($web);
}

sub installFilesIntoWeb {
    my ($web) = shift;

    print "Processing $web:\n";
    foreach my $topic (@topics) {
        installTopic( $web, $topic );
    }
}

sub installTopic {
    my ( $web, $topic ) = @_;
    print " - $web.$topic:\n";
    relockTopic( $web, $topic );
    moveTopicToBackup( $web, $topic );
    copyInTemplate( $web, $topic );
    checkInTopic( $web, $topic );
}

sub moveTopicToBackup {
    my ( $web, $topic ) = @_;
    checkInTopic( $web, $topic );
    my $oldfile    = fileForTopic( $web,    $topic );
    my $backupfile = fileForTopic( $oldweb, $web . '-' . $topic );
    print "   Backing up $web.$topic \n\t(copying $oldfile to $backupfile)\n";
    if ($doit) {
        rename( $oldfile, $backupfile );
    }

}

sub copyInTemplate {
    my ( $web, $topic ) = @_;
    my $templatefile = fileForTopic( $templateweb, $topic );
    my $destfile     = fileForTopic( $web,         $topic );
    print "   Copying $templatefile to $destfile\n";
    if ($doit) {
        copy( $templatefile, $destfile );
    }

}

sub fileForTopic {
    my ( $web, $topic ) = @_;
    return "$dataDir/$web/$topic.txt";
}

sub checkInTopic {
    my ( $web, $topic ) = @_;
    my $file = fileForTopic( $web, $topic );
    print "   Checking in $web.$topic ($file)\n";
    my $cmd = "ci -m'Commit Dakar files' -l $file < /dev/null";
    print "        ($cmd)\n";
    if ($doit) {
        print `$cmd`;
    }
}

# relocks as the current user
sub relockTopic {
    my ( $web, $topic ) = @_;
    my $file = fileForTopic( $web, $topic );
    my $cmd = "rcs -I -M -u $file < /dev/null";
    print $cmd. "\n";
    if ($doit) {
        print `$cmd`;
    }
    my $cmd = "ci -l -m'relock' $file  < /dev/null";
    print $cmd. "\n";
    if ($doit) {
        print `$cmd`;
    }
    my $cmd = "rcs -I -M -l $file < /dev/null";
    print $cmd. "\n";
    if ($doit) {
        print `$cmd`;
    }

}
