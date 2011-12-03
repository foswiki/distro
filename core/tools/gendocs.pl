#!/usr/bin/perl -w
# Copyright (C) 2005 Crawford Currie - all rights reserved
# Generate TWiki code documentation topics in the current
# checkout area
# This script must be run from the 'tools' directory.
# !!! is that still true?  i changed the path chomping code to use FindBin instead
# !!! are there other places that are affected?  (dunno, still haven't got it working for me :( )
use strict;
use File::Find;
use Cwd;
use FindBin;
use Getopt::Long;
use Pod::Usage;

my $Config;

BEGIN {

    $Config = {

        #
        smells => 1,
        root   => Cwd::abs_path("$FindBin::Bin/../"),

        #
        verbose => 0,
        debug   => 0,
        help    => 0,
        man     => 0,
    };

    my $result = GetOptions(
        $Config,
        'smells!',

        # miscellaneous/generic options
        'root=s', 'agent=s', 'help', 'man', 'debug', 'verbose|v',
    );
    pod2usage(1) if $Config->{help};
    pod2usage( { -exitval => 1, -verbose => 2 } ) if $Config->{man};

    unshift @INC, "$Config->{root}/bin";
    do 'setlib.cfg';
}

my @index;
my $smells = 0;
print "Building in $Config->{root}\n" if $Config->{debug};

find( \&eachfile, ( $Config->{root} . '/lib' ) );

open( F, '>', "$Config->{root}/data/System/SourceCode.txt" ) or die $!;
print F <<__TOPIC__;
---+!! Foswiki Source Code Packages

%X% This documentation is automatically generated from the =pod=, so it always matches the running code

%TOC%

__TOPIC__
print F join( "\n", sort @index );
if ( $Config->{smells} ) {
    print F "\n\n There were a total of *$smells* smells\n";
}
close(F);

1;

sub eachfile {
    print "Looking at $_\n" if ( $Config->{debug} && $Config->{verbose} );

    my $dir = $File::Find::dir;
    if (   $dir =~ m!/\.!
        || $dir =~ m!/Plugins!
        || $dir =~ m!/Upgrade!
        || $dir =~ m!/Contrib! )
    {
        ( $File::Find::prune = 1 );
        return;
    }

    my $file = $_;

    my $pmfile = $File::Find::name;

    $pmfile =~ s/\0//g;
    return unless -f $pmfile;

    return unless ( $file =~ /\.pm$/ );

    # Babar: Removed optimisation on =pod as this parses the file twice

    my $package = $dir;
    $package =~ s!.*/lib/?!!;
    $package =~ s!/!::!g;
    $package .= "::$file";
    $package =~ s/\.pm$//;
    $package =~ s/^:://;

    $file =~ s/^(.)/uc($1)/e;
    my $topic = "$dir$file";
    $topic =~ s!.*/lib/?!!;
    $topic =~ s/\.(.)/"Dot".uc($1)/ge;
    $topic =~ s!/(.)!uc($1)!ge;
    $topic =~ s/^(.)/uc($1)/e;

    open( PMFILE, '<', $pmfile ) or die "Failed to open $pmfile";
    my $text        = "";
    my $inPod       = 0;
    my $extends     = "";
    my $addTo       = \$text;
    my $packageSpec = "";
    my $packageName = "";
    my %spec;
    my $line;
    my $howSmelly = 0;

    while ( $line = <PMFILE> ) {
        $howSmelly++ if $Config->{smells} && $line =~ /(SMELL|FIXME|TODO)/;
        if ( $line =~ /^=(begin|pod)/ ) {
            $inPod = 1;
        }
        elsif ( $line =~ /^=cut/ ) {
            $addTo = \$text;
            $inPod = 0;
        }
        elsif ($inPod) {
            return if ( !$Config->{smells} && $line =~ /^---\+\s+UNPUBLISHED/ );
            if ( $line =~ /---\++\s*(?:UNPUBLISHED\s*)?package\s*(.*)$/ ) {
                $packageName = $1;
                $packageName =~ s/\s+//g;
                $packageSpec = "";
                $addTo       = \$packageSpec;
            }
            elsif (
                $line =~ /---\++\s+(Object|Class|Static)Method\s*(\w+)(.*)$/ )
            {
                my $type   = $1;
                my $name   = $2;
                my $params = $3;
                $params =~ s/\s+//g;
                $params =~ s/->/ -> /g;
                $spec{$name} = "---++ ${type}Method *$name* <tt>$params</tt>\n";
                $addTo = \$spec{$name};
                $text .= "!!!$name!!!\n";
            }
            else {
                $$addTo .= $line;
            }
        }
        else {
            if ( $line =~ /\@($package\:\:)?ISA\s*=\s*qw\(\s*(.*)\s*\)/ ) {
                my $e = $2;
                if ( $e =~ /^TWiki/ ) {
                    my $p = $e;
                    $p =~ s/:://g;
                    $p .= "DotPm";
                    $e = "[[$p][$e]]";
                }
                $extends = "\n*extends* <tt>$e</tt>\n";
            }
        }
    }
    close(PMFILE);

    if ( $Config->{smells} ) {
        $smells += $howSmelly;
        if ($howSmelly) {
            $howSmelly = "\n\nThis package has smell factor of *$howSmelly*\n";
        }
        else {
            $howSmelly = "\n\nThis package doesn't smell\n";
        }
    }
    $Config->{debug}
      && print STDERR "$pmfile -> $Config->{root}/data/System/$topic.txt\n";
    push( @index, "---++ [[$topic][$packageName]] \n$packageSpec$howSmelly" );
    $text = "---+ Package =$packageName=$extends\n$packageSpec\n%TOC%$text";
    foreach my $method ( sort keys %spec ) {
        $text =~ s/!!!$method!!!/$spec{$method}/;
    }

    open( F, '>', "$Config->{root}/data/System/$topic.txt" )
      || die "$! : $Config->{root}/data/System/$topic.txt \n";
    print F $text;
    close F;
}

__DATA__

=head1 NAME

gendocs.pl - 

=head1 SYNOPSIS

gendocs.pl [options] 

Copyright (C) 2005 Crawford Currie.  All Rights Reserved.

 Options:
   -smells
   -root
   -verbose
   -debug
   -help			this documentation
   -man				full docs

=head1 OPTIONS

=over 8

=item B<-smells>

=back

=head1 DESCRIPTION

B<gendocs.pl> ...

=head2 SEE ALSO

	http://twiki.org/cgi-bin/view/Codev/...

=cut
