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
    ($toolsDir) = Cwd::abs_path($toolsDir) =~ /(.*)/;
    @INC = ( $toolsDir, grep { $_ ne $toolsDir } @INC );
    my $binDir = Cwd::abs_path( File::Spec->catdir( $toolsDir, "..", "bin" ) );
    $distro = Cwd::abs_path( File::Spec->catdir( $toolsDir, "../..", "" ) );
    my ($setlib) =
      File::Spec->catpath( $volume, $binDir, 'setlib.cfg' ) =~ /(.*)/;
    require $setlib;
}

sub slurp {
    my $file = shift;
    return undef if !-e $file;
    open( my $fh, '<', $file ) or die "Failed to open $file";
    my @content = <$fh>;
    chomp(@content);
    close $fh;
    return \@content;
}

# It was tempting to use File::Next or File::Find::Object but that's another dependency
sub recurseDirectories {
    my ( $dirs, $nodeSub, $data, $exitSub, $depthLimit ) = @_;

    my $depth = scalar @{$dirs} - 1;

    return if $depthLimit && $depth > $depthLimit;
    my $thisDir = File::Spec->catdir( @{$dirs} );
    my @leaves  = ();

    $data->{leaves}[$depth] = {};
    opendir( my $DH, $thisDir ) or die "Error: failed to open $thisDir $!";
    while ( my $leaf = readdir $DH ) {
        $data->{leaves}[$depth]{$leaf} = 1 if File::Spec->no_upwards($leaf);
    }
    closedir($DH);

    for my $leaf ( sort keys %{ $data->{leaves}[$depth] } ) {
        if ( &$nodeSub( [ @{$dirs}, $leaf ], $data ) ) {
            recurseDirectories( [ @{$dirs}, $leaf ],
                $nodeSub, $data, $exitSub, $depthLimit );
        }
    }
    &$exitSub( $dirs, $data );
}

my $max_foswiki_directory_depth = 33
  ; # Recursion limit fail-safe, can be useful to set to a low-limit when debugging (less scanned)
my $dinfo = { extensions => [] };

print "Scanning for symlinks and extensions to exclude from git\n\n";
recurseDirectories( [$distro], \&checkNode, $dinfo, \&exitDir,
    $max_foswiki_directory_depth );

sub checkNode {
    my ( $dirs, $data ) = @_;

    my $depth = scalar @{$dirs} - 1;
    my $leaf  = $dirs->[$depth];

    return 0 if $dirs->[$depth] eq '.gitexcludes';
    my $node = File::Spec->catdir( @{$dirs} );

    if ( $leaf eq '.git' ) {
        push @{ $data->{extensions} }, $dirs->[1] if $depth == 2;
        return 0;
    }

    if ( -l $node ) {
        if ( $depth >= 1 && $data->{leaves}[1]{'.git'} )
        {    # Capture symlinks of Extension
            push @{ $data->{symlinks}[1] },
              File::Spec->catdir( @{$dirs}[ 2 .. $depth ] );
        }
        else {
            push @{ $data->{symlinks}[0] },
              File::Spec->catdir( @{$dirs}[ 1 .. $depth ] )
              ; # Capture all other symlinks as part of distro (core + coreExtensions)
        }
        return 0;
    }

    return -d $node;
}

sub exitDir {
    my ( $dirs, $data ) = @_;
    my $node  = File::Spec->catdir( @{$dirs} );
    my $depth = scalar @{$dirs} - 1;

    return if $depth > 1 || $depth == 1 && !$data->{leaves}[1]{'.git'};
    print "Exit: $node\n";

    my $location =
      File::Spec->catdir( @{$dirs}[ 0 .. $depth ] )
      ;    # either $distro or $distro/Extension

    my $developer_excludes = slurp("$location/.gitexclude");
    mkdir("$location/.git/info");
    open( my $FH, '>', "$location/.git/info/exclude" )
      or die "Cannot open $location/.git/info/exclude ($@)";

    if ($developer_excludes) {
        print $FH ".gitexclude\n";

        add_exclude( $FH, $location, 'developer',
            '# Developer specific copied from .gitexclude',
            \$developer_excludes );
    }

    if ( $depth == 0 ) {
        add_exclude(
            $FH, $location, 'extensions',
            '# Non-Core extensions to hide from distro',
            \$data->{extensions}
        );
    }

    add_exclude(
        $FH, $location, 'symlinks',
        '# Symlinks found at distro or distro/core level',
        \$data->{symlinks}[$depth]
    );
    close($FH);
}

sub add_exclude {
    my ( $fh, $location, $name, $header, $linkRefRef ) = @_;
    no strict 'refs';
    my @links = @{ ${$linkRefRef} };
    use strict 'refs';

    return unless @links;
    print "    excludes ( $location, $name, " . ( scalar @links ) . ")\n";

    my $slash = $name eq 'developer' ? '' : '/';

    print $fh "#\n";
    print $fh "$header\n";
    print $fh "#\n";
    for my $link (@links) {
        print $fh "$slash$link\n";
    }
    ${$linkRefRef} = [];
}
