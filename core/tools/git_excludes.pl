#!/usr/bin/perl
#
# Build for Foswiki
# Julian Levens
# Copyright (C) 2015 ProjectContributors. All rights reserved.
# ProjectContributors are listed in the AUTHORS file in the root of
# the distribution.

use strict;
use warnings;
use File::Spec;
use Cwd;

our $distro;

# Following is currently overkill no actual need to 'use Foswiki*',
# but we do locate distro directory cleanly
BEGIN {
    my ( $volume, $toolsDir, $action ) = File::Spec->splitpath(__FILE__);
    $toolsDir = '.' if $toolsDir eq '';
    ($toolsDir) = Cwd::abs_path( $toolsDir ) =~ /(.*)/;
    @INC = ($toolsDir, grep { $_ ne $toolsDir } @INC );
    my $binDir = Cwd::abs_path( File::Spec->catdir( $toolsDir, "..", "bin" ) );
    $distro = Cwd::abs_path( File::Spec->catdir( $toolsDir, "..//..", "" ) );
    my ($setlib) = File::Spec->catpath( $volume, $binDir, 'setlib.cfg' ) =~ /(.*)/;
    require $setlib;
}

sub slurp {
    my $file = shift;

    # OK to return '' if file does not exist,
    # but what if its another error? - probably OK as later write will fail anyway
    open my $fh, '<', $file or return '';

    local $/ = undef;
    my $cont = <$fh>;
    close $fh;
    return $cont;
}

sub mergeB {
    my ( $bRef, $tag, $desc, @ignores) = @_;

}
sub writeB {
    my ( $fh, $bRef );
}

sub recurseDirectories {
    my ($dir, $sub) = @_;

    my @dirs = ( glob("$dir/*") , glob("$dir/.*") );

    for my $f (sort @dirs) {
	next if $f =~ m{.*?/\.{1,2}$};
        &$sub( $f );
        recurseDirectories($f, $sub) if -d $f && !-l $f;
    }
}

chdir($distro);
my $excludes = slurp(".git/info/excludes");

my %block = ( $excludes =~ m/(?:\s*+\#\#Begin)\s*(\w+)\s+(.*?)(?:\n\#\#End)/gms );
my @dirs = glob('*');

my @symlinks;
#my @nonDistroExtensions;

#for my $d (sort @dirs) {
#    push @nonDistroExtensions, "/$d/" if -d $d;
#    push @symlinks, "/$d" if -l $d;
#}

recurseDirectories($distro, sub { push @symlinks, $_[0] if -l $_[0]; } );

{
    local $" = "\n";
    print "@symlinks";
}
exit 0;

# mergeB(\%block, "Extra-Extensions", "Non Default Foswiki Extensions (are independently git managed)", @nonDistroExtensions);
# mergeB(\%block, "Symlinks", "These are BuildContrib outputs and never part of a Foswiki repo", @symlinks);

writeB(\%block);

$excludes = <<'HERE';
##Begin Developer Your own local ignores
What
Ever
Whims
y like
yall
##End

##Begin Symlinks These are BuildContrib outputs and never part of a Foswiki repo
a
b
cv
d
##End

##Begin Extra_Extensions Pseudo-Installed extensions under their own .git control
1
2
3
##End

##Begin Symlinks These are logically build outputs and never part of a Foswiki repo
za
zb
zcv
zd
##End


HERE

# print "$excludes";


%block = ( $excludes =~ m/(?:\s*+\#\#Begin)\s*(\w+)\s+(.*?)(?:\n\#\#End)/gms );

for my $tag (sort keys %block) {
    print "(($tag))\n";
    print $block{$tag};
    print "\n-------\n";
}

exit 0;

