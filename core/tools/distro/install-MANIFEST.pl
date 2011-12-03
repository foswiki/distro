#! /usr/bin/perl -w
# Copyright 2005 Will Norris.  All Rights Reserved.
# License: GPL
use strict;
use Data::Dumper qw( Dumper );

BEGIN {
    my $dirHome = $ENV{HOME} || $ENV{LOGDIR} || ( getpwuid($>) )[7];
    $ENV{TWIKIDEV} ||= "$dirHome/twiki";
    eval
qq{ use lib( "$ENV{TWIKIDEV}/CPAN/lib/", "$ENV{TWIKIDEV}/CPAN/lib/arch/" ) };
}

use Cwd qw( cwd );
use Getopt::Long;
use Pod::Usage;
use File::Slurp qw( read_file );
use ManifestEntry;

#my @manifestEntries;

my $Config = {
    manifest => undef,
    basedir  => '',

    #
    templates => undef,
    lib       => undef,
    bin       => undef,
    pub       => undef,
    data      => undef,

    #
    verbose => 0,
    debug   => 0,
    help    => 0,
    man     => 0,
};

my $result = GetOptions(
    $Config,
    'MANIFEST=s', 'basedir=s',
    'templates=s', 'lib=s', 'bin=s', 'pub=s', 'data=s',

    # miscellaneous/generic options
    'agent=s', 'help', 'man', 'debug', 'verbose|v',
);
pod2usage(1) if $Config->{help};
pod2usage( { -exitval => 1, -verbose => 2 } ) if $Config->{man};
print STDERR Dumper($Config) if $Config->{debug};

chomp( my @manifest = read_file( $Config->{MANIFEST} ) );
foreach my $line (@manifest) {
    my $entry = ManifestEntry->new($line);
    $entry->install(
        {
            basedir => $Config->{basedir},
            paths =>
              { map { $_ => $Config->{$_} } qw( templates lib bin pub data ) }
        }
    );
}
