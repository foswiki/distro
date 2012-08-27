#!/usr/bin/perl -w
# --
# send latest Subversion commit to github, split per module

use strict;
use warnings;
use Git::Repository;

my $verbose    = 0;                               # 1 for debug
my $repository = shift || '/home/svn/nextwiki';
my $statefile  = '/home/git/last-git-split';
my $lastrev    = shift;
chomp( $lastrev = `/usr/local/bin/svnlook youngest $repository` )
  unless $lastrev;

# Read up to where has already been processed
sub getLastProcessedRev {
    my $firstrev = 11813;
    if ( -f $statefile ) {
        open( my $state, '<', $statefile ) or die "Can't open $statefile: $!";
        chomp( $firstrev = <$state> );
        close $state;
    }
    return $firstrev;
}

# Update the state file with the latest processed revision
sub setLastProcessedRev {
    my $lastrev = shift or return;
    open( my $state, '>', $statefile ) or die "Can't open $statefile: $!";
    print $state $lastrev . "\n";
    close $state;
}

# Build modified plugins per branch
sub buildModifiedList {
    my $revision       = shift;
    my $modifiedPlugin = shift;    # hash ref built recursively
    return unless $revision;
    open( my $svnlook, '-|',
        "/usr/local/bin/svnlook dirs-changed -r $revision $repository" )
      or die "Can't open svn look pipe: $!";

    while (<$svnlook>) {
        if ( m#^(trunk)/([^/]*)/# || m#^(?:branches|tags)/([^/]*)/([^/]*)/# ) {
            my $plugin = $2;
            my $branch = $1 || 'master';
            for ($branch) {
                s/trunk/master/;
            }
            $modifiedPlugin->{$plugin}->{$branch}++;
        }
    }
    close $svnlook;
}

sub getGitHubToken {
    my $secfile = '/home/git/.token';
    open( my $tokenfh, '<', $secfile )
      or die "Cannot get GitHub token from $secfile: $!";
    chomp( my $token = <$tokenfh> );
    die "Invalid token: $token" unless $token =~ /[0-9a-f]/i;
    return $token;
}

# Create the submodule on GitHub, and add it in the master repo
sub createSubModule {
    my $masterRepo = shift;
    my $module     = shift;

    warn "Creating github module $module...";
    require Net::GitHub;
    my $token = getGitHubToken;
    my $github = Net::GitHub->new( login => 'FoswikiBot', pass => $token, );
    $github->repos->create(
        {
            org         => 'foswiki',
            name        => $module,
            description => "Foswiki module $module",
            homepage    => "http://foswiki.org/Extensions/$module"
        }
    );
    warn
      "\tAdding: git submodule add git\@github.com:foswiki/$module.git $module"
      if $verbose;

# Cannot use Git::Repository here because submodule add doesn't like overriding GIT_WORK_TREE
# BooK provided a fix, which I will test tomorrow:
# https://github.com/book/System-Command/commit/1aa35fef43a2178e36d2f46cc3385d5b345ab237
    system( 'cd '
          . $masterRepo->work_tree()
          . " && git submodule add git\@github.com:foswiki/$module.git $module"
    );
}

# Create the subversion links from one submodule to foswiki.org
sub getSubModule {
    my $masterRepo = shift;
    my $module     = shift;

    my $moduleDir = $masterRepo->work_tree() . '/' . $module;
    my $submodule = eval { Git::Repository->new( work_tree => $moduleDir ) };
    createSubModule( $masterRepo, $module ) unless $submodule;
    $submodule ||= Git::Repository->new( work_tree => $moduleDir );

    # Ensute subversion configuration is consistent
    unless ( eval { $submodule->run( svn => "log" ) } ) {
        my $gitconfig = $submodule->git_dir() . '/config';
        open( my $config, '<', $gitconfig )
          or die "Can't open $module .git/config ($gitconfig): $!";
        my $gitsvn = 0;
        while (<$config>) {
            $gitsvn++ if /svn-remote/;
        }
        close $config;
        unless ($gitsvn) {
            open( my $config, '>>', $gitconfig )
              or die "Can't open $module .git/config ($gitconfig): $!";
            print $config <<"END_CONFIG";
[svn-remote "svn"]
	url = http://svn.foswiki.org
	fetch = trunk/$module:refs/remotes/trunk
	branches = branches/*/$module:refs/remotes/*
	tags = tags/*/$module:refs/remotes/tags/*
END_CONFIG
            $submodule->run( svn => 'fetch' );
        }
    }
    return $submodule;
}

my %modifiedPlugin;
my $startrev = getLastProcessedRev() + 1;
warn "F:$startrev L:$lastrev" if $verbose;
for my $revision ( $startrev .. $lastrev ) {
    buildModifiedList( $revision, \%modifiedPlugin );
}

exit unless keys %modifiedPlugin;

#my $masterRepo = Git::Repository->new( work_tree => "/usr/home/git/_allDeveloper" );
my $masterRepo =
  Git::Repository->new( git_dir => "/usr/home/git/_allDeveloper/.git" );
for my $module ( sort keys %modifiedPlugin ) {
    my $submodule = getSubModule( $masterRepo, $module );
    for my $branch ( sort keys %{ $modifiedPlugin{$module} } ) {
        warn "Updating module $module, branch $branch" if $verbose;
        $submodule->run( checkout => $branch );

        # Create local branch if it doesn't exist
        unless ( eval { $submodule->run( 'symbolic-ref' => 'HEAD' ) } ) {
            $submodule->run( checkout => '-b' => $branch );
            $submodule->run( push => '-f', origin => $branch );
        }
        $submodule->run( svn => 'rebase' );
    }
    $submodule->run( push => '--all' );
}

$masterRepo->run( commit => '-am', "Pushed latest revision $lastrev" );
$masterRepo->run( push => '--all' );

setLastProcessedRev($lastrev);
