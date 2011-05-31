#!/usr/bin/perl -wT
# --
# send latest Subversion commit to github, split per module
# --
# Ugly... should use some git perl module at least...

use strict;
use warnings;

my $repository = shift;
my $revision   = shift;

open( my $svnlook, '-|',
    "/usr/local/bin/svnlook dirs-changed -r $revision $repository" )
  or die "Can't open svn look pipe: $!";

my %modifiedPlugin;

while (<$svnlook>) {
    if ( m#^(trunk)/([^/]*)/# || m#^(?:branches|tags)/([^/]*)/([^/]*)/# ) {
        my $branch = $1;
        $modifiedPlugin{$2}++;
    }
}
close $svnlook;

chdir "/usr/home/git/_allDeveloper";
for my $module ( keys %modifiedPlugin ) {
    unless ( -d $module ) {
        system "git submodule add git\@github.com:foswiki/$module.git $module";
    }
    unless ( -d "$module/.git/svn" ) {
        open( my $gitconfig, '<', "$module/.git/config" )
          or die "Can't open $module .git/config";
        my $gitsvn = 0;
        while (<$gitconfig>) {
            $gitsvn++ if /svn-remote/;
        }
        unless ($gitsvn) {
            open( my $gitconfig, '>>', "$module/.git/config" )
              or die "Can't open $module .git/config";
            print $gitconfig <<"END_CONFIG";
[svn-remote "svn"]
	url = http://svn.foswiki.org
	fetch = trunk/$module:refs/remotes/trunk
	branches = branches/*/$module:refs/remotes/*
	tags = tags/*/$module:refs/remotes/tags/*
END_CONFIG
            system(
"cd $module && git update-ref refs/remotes/trunk origin/master && git svn fetch"
            );
        }
    }
    system("cd $module && git svn rebase && git push --all");
}

system("git commit -am 'Pushed latest revision' && git push --all");
