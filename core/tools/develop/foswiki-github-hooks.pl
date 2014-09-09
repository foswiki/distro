#! /usr/bin/env perl

=pod

---+ foswiki-github-hooks
This is a maintenance script for the foswiki gihub account.
It is intended to be run on http://foswiki.org in the github mirror directory.
It examines and sets the hooks for each repository.

It requires a password file for proper operation

$secrets = {  github_access_token  => '<access token for the github foswiki account>',
                'webhook_secret'      => '<secrete required to validate rest handler posts>',
                'mailman_secret'      => '<Used by hook to be able to send messages to the mailing list>',
                'GithubBot_password'  => '<password for GithubBot IRC account>;
           };
return $secrets;

=cut

use warnings;
use strict;
use Data::Dumper;
use Net::GitHub;
use Net::GitHub::V3;
use Time::Local;
use Data::Dumper;

# Set to 1 for basic information,  2 for dump of github responses
use constant VERBOSE => 0;

my $secrets = do '.github-secrets' or die "Unable to read secrets file";

my $gh = Net::GitHub::V3->new(
    version      => 3,
    access_token => $secrets->{'github_access_token'},
);

my $ghaccount = 'foswiki';

my %HOOKS = (
    email => {
        'name'   => 'email',
        'active' => '1',
        'config' => {
            'address'          => 'foswiki-svn@lists.sourceforge.net',
            'secret'           => $secrets->{'mailman_secret'},
            'send_from_author' => '0',
        }
    },
    irc => {
        'name'   => 'irc',
        'active' => '1',
        'config' => {
            'server'   => 'chat.freenode.net',
            'port'     => '6667',
            'room'     => 'foswiki',
            'nick'     => 'GithubBot',
            'password' => $secrets->{'GithubBot_password'},
        }
    },
    web => {
        'name'   => 'web',
        'active' => '1',
        'config' => {
            'url' =>
              'http://trunk.foswiki.org/bin/rest/FoswikiOrgPlugin/githubpush',
            'content_type' => 'json',
            'secret'       => $secrets->{'webhook_secret'},
        }
    }
);

my $ghAccount = 'foswiki';
my $repos;
my @rp;

$repos = $gh->repos;

@rp = $repos->list_org($ghAccount);

while ( $gh->repos->has_next_page ) {
    push @rp, $gh->repos->next_page;
}

my $created = 0;
my $updated = 0;
my $rpcount = scalar @rp;

foreach my $r (@rp) {
    my $rname = $r->{'name'};

    #    if (  $rname eq 'TestBootstrapPlugin')
    #    {
    print
      "\n============================== $r->{name} ======================\n"
      if (VERBOSE);
    print Data::Dumper::Dumper( \$r ) if ( VERBOSE == 2 );

    checkHooks( $repos, $r );

    #    }

}

print
"Hooks check completed: $rpcount repositories processed:  hooks created: $created,  hooks updated: $updated\n";

sub checkHooks {
    my $repos = shift;
    my $r     = shift;

    my @hooks = $repos->hooks( 'foswiki', $r->{'name'} );

    foreach my $h ( keys %HOOKS ) {
        $HOOKS{$h}{installed} = '0';
    }

    if ( scalar @hooks ) {
        foreach my $h (@hooks) {
            if ( defined $HOOKS{ $h->{name} } ) {
                $HOOKS{ $h->{name} }{installed} = '1';
                my $valid =
                  checkHook( $repos, $h, $HOOKS{ $h->{name} }, $r->{'name'} );
                updatehook( $repos, $r->{name}, $h->{id}, $HOOKS{ $h->{name} } )
                  unless ($valid);
            }
            else {
                print " Repo $r->{'name'} unknown HOOK $h->{name}\n";
            }
        }
    }

    foreach my $h ( keys %HOOKS ) {
        unless ( $HOOKS{$h}{installed} ) {
            print " Repo $r->{'name'} HOOK $h MISSING\n";
            createhook( $repos, $r->{name}, $HOOKS{$h} );
        }
    }
}

sub checkHook {
    my $repos    = shift;
    my $hook     = shift;
    my $hookdef  = shift;
    my $reponame = shift;
    my $valid    = 1;

    unless ( $hook->{active} ) {
        $valid = 0;
        print "Repo $reponame, HOOK $hook->{'name'} is not active\n";
    }

    if ( $hook->{config} ) {
        foreach my $cfg ( keys %{ $hookdef->{config} } ) {
            next if ( $cfg eq 'secret' || $cfg eq 'password' );
            my $current = $hook->{config}{$cfg} || '0';
            my $desired = $hookdef->{config}{$cfg};
            if ( "$current" eq "$desired" ) {
                print "$cfg: $current matches $desired\n" if (VERBOSE);
            }
            else {
                print
                  "Repo $reponame, Key mismatch $cfg: $current ne $desired\n";
                $valid = 0;
            }
        }
    }
    else {
        $valid = 0;
    }

    return $valid;
}

sub updatehook {
    my $repos   = shift;
    my $rname   = shift;
    my $hookid  = shift;
    my $hookdef = shift;

    my $hook = $repos->update_hook( $ghaccount, $rname, $hookid, $hookdef, );
    $updated++;
    print "$rname $hookid updated\n";
    return;
}

sub createhook {
    my $repos   = shift;
    my $rname   = shift;
    my $hookdef = shift;

    my $hook = $repos->create_hook( $ghAccount, $rname, $hookdef, );
    $created++;
    print "$rname Hook created\n";
    return;
}

