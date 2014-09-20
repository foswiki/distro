#! /usr/bin/env perl

use warnings;
use strict;
use Data::Dumper;
use Net::GitHub;
use Net::GitHub::V3;
use Time::Local;
use Data::Dumper;

=pod

---+ foswiki-github-mirror
This script will create a bare mirror of the github resident repositories.
It is intended to be run on http://foswiki.org in the github mirror directory.
It creates or refreshes a local mirro of the fosiwki account on github.com

It has no parameters.  It fetches the github list of repositories using
the GitHub API.  The last push date is compared to the date of the
local mirror and the mirror is updated if required.

It requires a password file for proper operation.
(Only the github access token is used by this script.)

$secrets = {  github_access_token  => '<access token for the github foswiki account>',
                'webhook_secret'      => '<secrete required to validate rest handler posts>',
                'mailman_secret'      => '<Used by hook to be able to send messages to the mailing list>',
                'GithubBot_password'  => '<password for GithubBot IRC account>;
           };
return $secrets;

=cut

# Set to 1 for basic information,  2 for dump of github responses
use constant VERBOSE => 0;

my $secrets = do '.github-secrets' or die "Unable to read secrets file";

my $gh = Net::GitHub::V3->new(
    version      => 3,
    access_token => $secrets->{'github_access_token'},
);

my $ghAccount = 'foswiki';
my $repos;
my @rp;

$repos = $gh->repos;

@rp = $repos->list_org($ghAccount);

while ( $gh->repos->has_next_page ) {
    push @rp, $gh->repos->next_page;
}

my $cloned  = 0;
my $updated = 0;
my $rpcount = scalar @rp;

foreach my $r (@rp) {
    my $rname = $r->{'name'};

    #    if (   $rname eq 'WillNorris' )
    #        || $rname eq 'TestBootstrapPlugin'
    #        || $rname eq 'ConfigurePlugin' )
    #    {
    print Data::Dumper::Dumper( \$r ) if ( VERBOSE == 2 );

    my $pushdate = $r->{'pushed_at'} || '';
    print "\n$rname:\n" if (VERBOSE);
    if ( -d "$rname.git" && $pushdate ) {
        my $update = check_times( $rname, $pushdate ) if $pushdate;
        if ($update) {
            print "    UPDATE REQUIRED for $rname\n" if $update;
            do_commands(<<"HERE");
git --git-dir $rname.git remote update 
HERE
            $updated++;
        }
        else {
            print "    $rname is up to date\n" if (VERBOSE);
        }
    }
    elsif ( !-d "$rname.git" ) {
        print "    CLONE REQUIRED for $rname\n";
        do_commands(<<"HERE");
git clone --mirror https://github.com/foswiki/$rname.git 
HERE
        $cloned++;
    }
    else {
        print "    Repository never pushed\n" if (VERBOSE);
    }

    #    }
}

print
"Mirror completed: $rpcount repositories processed:  cloned: $cloned,  updated: $updated\n"
  if ( $cloned || $updated );

sub check_times {
    my ( $gitdir, $pushdate ) = @_;

    my ( $date, $time ) = split( /T/, $pushdate );
    my ( $year, $mon, $mday ) = split( /-/, $date );
    chop $time;    #Remove the trailing Z
    my ( $hour, $min, $sec ) = split( /:/, $time );
    my $gh_timestamp = timegm( $sec, $min, $hour, $mday, $mon - 1, $year );
    my $ltime = scalar localtime $gh_timestamp;

    my $chkfile =
      ( -e "$gitdir.git/FETCH_HEAD" )
      ? "$gitdir.git/FETCH_HEAD"
      : "$gitdir.git/HEAD";
    open( my $fh, '<', "$chkfile" )
      or die "Unable to open $gitdir.git/$chkfile";
    my $epoch_timestamp = ( stat($fh) )[9];
    my $etime           = scalar localtime $epoch_timestamp;
    close $fh;

    print
"    Last fetch: $epoch_timestamp: $etime,\n    Last push:  $gh_timestamp: $ltime\n"
      if (VERBOSE);

    return ( $gh_timestamp > $epoch_timestamp );
}

sub do_commands {
    my ($commands) = @_;

    print $commands . "\n" if (VERBOSE);
    local $ENV{PATH} = untaint( $ENV{PATH} );

    return `$commands`;
}

sub untaint {
    no re 'taint';
    $_[0] =~ /^(.*)$/;
    use re 'taint';

    return $1;
}

