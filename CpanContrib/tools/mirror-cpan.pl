#!/usr/bin/perl -w
use strict;

# mirror cpan (adapted from Randal Schwartz' program at ...)
# Copyright 2004 Will Norris.  All Rights Reserved.
# License: GPL

# TODO: just start using minicpan :)

use Getopt::Long;

my $optsConfig;    # forward declaration

sub Usage {
    print <<'__USAGE__';
Usage:
  mirror-cpan.pl [--mirror=[http://cpan.org]] [--local=[$FindBin::BIN/MIRROR/MINICPAN/]] [cpan modules list regex...]
      --status		shows variables
      --help | --?	usage info
      --debug
      --verbose

Examples:
Creates local mirror from CPAN containing only the latest version of each module (~795MB 07 May 2007)
  tools/mirror-cpan.pl
Creates a local mirror of everything related to WWW::Mechanize
  ./mirror-cpan.pl WWW::Mechanize
  ./mirror-cpan.pl \^WWW::Mechanize      # more selective; only WWW::Mechanize tree on down, but not, eg, Test::WWW::Mechanize
__USAGE__

    return 0;
}

$|++;
use FindBin;
use Data::Dumper qw( Dumper );

## warning: unknown files below the =local= dir are deleted!
$optsConfig = {
    mirror => 'http://cpan.org/',
    local  => "$FindBin::Bin/MIRROR/MINICPAN/",

    #
    status  => 0,
    verbose => 0,
    debug   => 0,
    help    => 0,
    man     => 0,
};

my $TRACE = 1;

### END CONFIG

GetOptions(
    $optsConfig,
    'mirror=s', 'local=s',
    'status',

    # miscellaneous/generic options
    'help|?', 'man', 'debug', 'verbose|v',
);
if ( $optsConfig->{help} || $optsConfig->{man} ) { exit Usage() }

#pod2usage( 1 ) if $optsConfig->{help};
#pod2usage({ -exitval => 1, -verbose => 2 }) if $optsConfig->{man};
print STDERR Dumper($optsConfig) if $optsConfig->{debug};

# pass module list on the command line
my @modules = @ARGV ? @ARGV : q(.+);
print Dumper( \@modules ) if $optsConfig->{debug};

if ( $optsConfig->{status} ) {
    print
      qq{Mirroring from "$optsConfig->{mirror}" to "$optsConfig->{local}"\n};
    exit 0;
}

################################################################################

my $REMOTE = $optsConfig->{mirror};
my $LOCAL  = $optsConfig->{local};

## core -
use File::Path qw(mkpath);
use File::Basename qw(dirname);
use File::Spec::Functions qw(catfile);
use File::Find qw(find);

## LWP -
use URI ();
use LWP::Simple qw(mirror RC_OK RC_NOT_MODIFIED);

## Compress::Zlib -
use Compress::Zlib qw(gzopen $gzerrno);

## first, get index files
my_mirror($_) for qw(
  authors/01mailrc.txt.gz
  modules/02packages.details.txt.gz
  modules/03modlist.data.gz
);

## now walk the packages list
my $details = catfile( $LOCAL, qw(modules 02packages.details.txt.gz) );
my $gz = gzopen( $details, "rb" ) or die "Cannot open details: $gzerrno";
my $inheader = 1;
while ( $gz->gzreadline($_) > 0 ) {
    if ($inheader) {
        $inheader = 0 unless /\S/;
        next;
    }

    my ( $module, $version, $path ) = split;
    next if $path   =~ m{/perl-5};    # skip Perl distributions
    next if $module =~ /^Acme::/;

    my $bMatch = 0;
    foreach my $modulePattern (@modules) {
        $bMatch = 1, last if $module =~ /$modulePattern/i;
    }

    if ($bMatch) {

        #      print "[$module] [v$version, $path]\n";
        my_mirror( "authors/id/$path", 1 );
    }
}

## finally, clean the files we didn't stick there
clean_unmirrored();

exit 0;

BEGIN {
    ## %mirrored tracks the already done, keyed by filename
    ## 1 = local-checked, 2 = remote-mirrored
    my %mirrored;

    sub my_mirror {
        my $path            = shift;    # partial URL
        my $skip_if_present = shift;    # true/false

        my $remote_uri = URI->new_abs( $path, $REMOTE )->as_string;   # full URL
        my $local_file =
          catfile( $LOCAL, split "/", $path );    # native absolute file
        my $checksum_might_be_up_to_date = 1;

        if ( $skip_if_present and -f $local_file ) {
            ## upgrade to checked if not already
            $mirrored{$local_file} = 1 unless $mirrored{$local_file};
        }
        elsif ( ( $mirrored{$local_file} || 0 ) < 2 ) {
            ## upgrade to full mirror
            $mirrored{$local_file} = 2;

            mkpath( dirname($local_file), $TRACE, 0711 );
            print $path if $TRACE;
            my $status = mirror( $remote_uri, $local_file );

            if ( $status == RC_OK ) {
                $checksum_might_be_up_to_date = 0;
                print " ... updated\n" if $TRACE;
            }
            elsif ( $status != RC_NOT_MODIFIED ) {
                warn "\n$remote_uri: $status\n";
                return;
            }
            else {
                print " ... up to date\n" if $TRACE;
            }
        }

        if ( $path =~ m{^authors/id} ) {    # maybe fetch CHECKSUMS
            my $checksum_path =
              URI->new_abs( "CHECKSUMS", $remote_uri )->rel($REMOTE);
            if ( $path ne $checksum_path ) {
                my_mirror( $checksum_path, $checksum_might_be_up_to_date );
            }
        }
    }

    sub clean_unmirrored {
        find sub {
            return unless -f and not $mirrored{$File::Find::name};
            print "$File::Find::name ... removed\n" if $TRACE;
            unlink $_ or warn "Cannot remove $File::Find::name: $!";
        }, $LOCAL;
    }
}
