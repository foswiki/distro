# Plague people who we are waiting for feedback from
# Analyses the Waiting for Feedback tasks, Waiting For field, extracts
# wikiname, maps to email address, sends mail.

# usage: plague.pl [--topics "Item123,Item456"]  [--nomail]
# with no arguments, searches thru Item*
use strict;
use warnings;

my $itemTopics = "Item*";
my $sendMail   = 1;

while (@ARGV) {
    my $arg = shift @ARGV;
    if ( $arg eq "--topics" ) {
        $itemTopics = shift @ARGV;
    }
    elsif ( $arg eq '--nomail' ) {
        $sendMail = undef;
    }
}

#print "Searching items $itemTopics\n";

BEGIN {
    require 'setlib.cfg';
}

use Foswiki          ();
use Foswiki::Request ();
use Foswiki::Meta    ();

# Create the session
my $request = new Foswiki::Request();
$request->path_info('/Tasks/WebHome');
my $session = new Foswiki( $Foswiki::cfg{AdminUserLogin}, $request );

my $sep  = "JENNY8675309xyzzy";
my $data = Foswiki::Func::expandCommonVariables(<<"SEARCH");
\%SEARCH{
 "CurrentState='Waiting for Feedback'"
 type="query"
 topic="$itemTopics"
 web="Tasks"
 nonoise="on"
 format="topic='\$topic' WaitingFor='\$formfield(WaitingFor)' Summary='\$formfield(Summary)'"
 separator="$sep"}\%
SEARCH

# collate search results into %send, keyed by mail address to be notified.
my %send;
for my $itemData ( split $sep, $data ) {
    my ( $topic, $waitingFor, $summary ) =
      $itemData =~ m/topic='(.*?)' WaitingFor='(.*?)' Summary='(.*)'/;
    next unless $waitingFor;
    $waitingFor =~ s/^\s+//;
    $waitingFor =~ s/\s+$//;
    my @emails;
    foreach my $waitname ( split( /[,\s]/, $waitingFor ) ) {
        $waitname =~ s/Foswiki://;
        my @waitemails = Foswiki::Func::wikinameToEmails($waitname);
        push @emails, @waitemails;
    }
    unless ( scalar(@emails) ) {
        print STDERR "$0: $topic: $waitingFor has no email address\n";
        next;
    }
    foreach my $email (@emails) {
        push( @{ $send{$email} }, { topic => $topic, summary => $summary } );
    }
}

# Send mails by expanding the template
$/ = undef;
my $template = <DATA>;
while ( my ( $email, $items ) = each %send ) {
    my $list = join( "\n\n",
        map { $_->{summary} . "\nhttp://foswiki.org/Tasks/" . $_->{topic} }
          @$items );
    my $mail = $template;
    $mail =~ s/%EMAILTO%/$email/g;
    $mail =~ s/%TASK_LIST%/$list/g;
    $mail = Foswiki::Func::expandCommonVariables($mail);
    if ($sendMail) {
        my $e = Foswiki::Func::sendEmail($mail);
        print STDERR "$0: error sending mail: $e\n" if $e;
    }
    else {
        print "$mail\n";
    }
}
1;
__DATA__
From: tasks
To: %EMAILTO%
Subject: Tasks are waiting for feedback from you
Auto-Submitted: auto-generated
MIME-Version: 1.0
Content-Type: text/plain
Content-Transfer-Encoding: 8bit


This is an automated e-mail from Foswiki.org

The following Tasks are waiting for feedback from you.

%TASK_LIST%

Please help keep development flowing by responding promptly to requests 
for feedback.

If you want to stop receiving these emails, please provide feedback
in each task, and change the task status to 'New'.

Thanks,

The Foswiki Development Team
