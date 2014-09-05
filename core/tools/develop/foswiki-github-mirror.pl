#! /usr/bin/env perl

use warnings;
use strict;
use Data::Dumper;
use Net::GitHub;
use Net::GitHub::V3;
use Time::Local;

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

my $foundit = 0;
use Data::Dumper;

foreach my $r (@rp) {
    my $rname = $r->{'name'};

    #    if (   $rname eq 'WillNorris' )
    #        || $rname eq 'TestBootstrapPlugin'
    #        || $rname eq 'ConfigurePlugin' )
    #    {
    #print Data::Dumper::Dumper( \$r );
    #dumpHooks( $repos, $r );
    my $pushdate = $r->{'pushed_at'} || '';
    print "\n$rname: $pushdate\n";
    if ( -d "$rname.git" && $pushdate ) {
        my $update = check_times( $rname, $pushdate ) if $pushdate;
        if ($update) {
            print STDERR "    UPDATE REQUIRED for $rname\n" if $update;
            do_commands(<<"HERE");
git --git-dir $rname.git remote update 
HERE
        }
        else {
            print STDERR "    $rname is up to date\n";
        }
    }
    elsif ( !-d "$rname.git" ) {
        print STDERR "    CLONE REQUIRED for $rname\n";
        do_commands(<<"HERE");
git clone --mirror https://github.com/foswiki/$rname.git 
HERE
    }
    else {
        print STDERR "    Repository never pushed\n";
    }

    #    }
}

sub dumpHooks {
    my $repos = shift;
    my $r     = shift;

    my @hooks = $repos->hooks( 'foswiki', $r->{'name'} );

    if ( scalar @hooks ) {
        foreach my $h (@hooks) {
            print Data::Dumper::Dumper( \$h );
        }
    }
}

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

    print STDERR
"    Last fetch: $epoch_timestamp: $etime,\n    Last push:  $gh_timestamp: $ltime\n";

    return ( $gh_timestamp > $epoch_timestamp );
}

sub do_commands {
    my ($commands) = @_;

    #print $commands . "\n";
    local $ENV{PATH} = untaint( $ENV{PATH} );

    return `$commands`;
}

sub untaint {
    no re 'taint';
    $_[0] =~ /^(.*)$/;
    use re 'taint';

    return $1;
}

