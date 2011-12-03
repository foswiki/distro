# Support script for developers.
#
# Run this script when cd'ed to the lib directory to get an analysis of
# TWiki packages that are used without having a corresponding require
# in the module.
#
# $ cd lib
# $ perl ../tools/check_requires.pl
#
# The script will return a non-zero exist code if it thinks there are any
# problems.
#
use File::Find;
use strict;

my $trace = 0;
my ( @files, @modules );
File::Find::find(
    sub {
             /\.pm\z/
          && !m#/CPAN/#
          && push( @files,   $File::Find::name )
          && push( @modules, $File::Find::name );
    },
    './TWiki'
);
@modules = sort { length($a) < length($b) }
  map { s/\.pm$//; s#^\./##; s#/#::#g; $_ } @modules;
my $re = '(' . join( '|', @modules ) . ')';
my $suspicious = 0;
foreach my $file (@files) {

    #print "$file\n";
    my $hits = `egrep '$re(::|->)' $file`;
    if ($hits) {
        my $m = $file;
        my %required;
        my %satisfied;
        $m =~ s/\.pm$//;
        $m =~ s#^\./##;
        $m =~ s#/#::#g;
        local $/ = "\n";
        open( F, '<', $file );
        my $inpod = 0;
        my $base  = '';

        foreach my $line (<F>) {

            #print "$line" if $trace;
            if ( $inpod && $line =~ /^=cut/ ) {
                $inpod = 0;
                next;
            }
            if ( $line =~ /^=(begin|pod)/ ) {
                $inpod = 1;
                next;
            }
            if ($inpod) {
                next;
            }
            die "$file broken at $line" if ( $line =~ /^=/ );
            if ( $line =~ /^\s*package\s/ ) {
                next;
            }
            $line =~ s/\s*#.*$//;
            unless ( $line =~ /\S/ ) {
                next;
            }
            if ( $line =~ /\b(?:use|require)\s+$re;/ ) {
                print "- $1\n" if $trace;
                $satisfied{$1} = 1;
                next;
            }
            if ( $line =~ /\b(?:use|require)\s+base\s+'$re'/ ) {
                print "- $1\n" if $trace;
                $satisfied{$1} = 1;
                $base = $1;
                next;
            }
            if ( $line =~ /\b(?:use|require)\s+base\s+qw\($re\)/ ) {
                print "- $1\n" if $trace;
                $satisfied{$1} = 1;
                $base = $1;
                next;
            }
            if ( $line =~ /new\s+$re\(/ ) {
                if ( $1 eq $m ) {
                    next;
                }
                print "++ $1\n" if $trace;
                $required{$1} = 1;
                next;
            }
            if ( $line =~ /\b$re(((::|->)\w+[^:])|\()/ ) {
                if ( $1 eq $m ) {
                    print "~ $1\n" if $trace;
                    next;
                }
                print "+ $1\n" if $trace;
                $required{$1} = 1;
            }
        }
        foreach ( keys %required ) {
            next if $satisfied{$_};
            print $file, ' uses ', $_, " without a require\n";
            $suspicious++;
        }
        foreach ( keys %satisfied ) {
            next if $required{$_};
            next if $_ eq $base;
            print $file, ' requires ', $_, " but may not need it\n";
        }
    }
}
exit 1 if $suspicious;

sub derived {
    my ( $parent, $child ) = @_;
    my @dad = split( /::/, $parent );
    my @son = split( /::/, $child );
    return 0 if @dad > @son;
    for ( my $i = 0 ; $i < @dad ; $i++ ) {
        return 0 if ( $son[$i] ne $dad[$i] );
    }
    return 1;
}
