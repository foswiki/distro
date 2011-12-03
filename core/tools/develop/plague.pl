# Plague people who we are waiting for feedback from
# Analyses the Waiting for Feedback tasks, Waiting For field, extracts
# wikiname, maps to email address, sends mail.
use strict;
use warnings;

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

# Search for Waiting for Feedback, and load a struct with the results
my $details = '[' . Foswiki::Func::expandCommonVariables(<<'SEARCH') . ']';
%SEARCH{
 "name~'Item*' AND CurrentState='Waiting for Feedback'"
 type="query"
 nonoise="on"
 format="$percntFORMAT{\"$percntENCODE{\"$formfield(WaitingFor)\" 
old=\"Main.,Foswiki:,TWiki:\" new=\",,\"}$percnt\" type=\"string\" 
format=\"{topic=>'$topic',who=>'$dollaritem'}\" separator=\",\"}$percnt"
 separator=","}%
SEARCH
my $data = eval($details);

# Process the struct, collating items according to the recipient email
my %send;
foreach my $entry (@$data) {
    next unless $entry->{who};
    my @emails = Foswiki::Func::wikinameToEmails( $entry->{who} );
    unless ( scalar(@emails) ) {
        print STDERR
          "$0: $entry->{topic}: $entry->{who} has no email address\n";
        next;
    }
    foreach my $email (@emails) {
        push( @{ $send{$email} }, $entry->{topic} );
    }
}

# Send mails by expanding the template
$/ = undef;
my $template = <DATA>;
while ( my ( $email, $items ) = each %send ) {
    my $list = join( "\n", map { 'http://foswiki.org/Tasks/' . $_ } @$items );
    my $mail = $template;
    $mail =~ s/%EMAILTO%/$email/g;
    $mail =~ s/%TASK_LIST%/$list/g;
    $mail = Foswiki::Func::expandCommonVariables($mail);
    my $e = Foswiki::Func::sendEmail($mail);
    print STDERR "$0: error sending mail: $e\n" if $e;
}
1;
__DATA__
From: tasks
To: %EMAILTO%
Subject: Tasks are waiting for feedback from you
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
