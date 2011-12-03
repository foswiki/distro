#! /usr/bin/perl -w
use strict;
################################################################################
# rebuild-deploy-test-if-new.pl - crontab-compatible script used to perform the following:
#   * run the (unit) tests
#   * build a new twiki kernel
#   * build a new distribution
#   * publish the distribution
#   * install the distribution
#   * run the (golden html) tests
#   * post the test results to tinderbox.wbniv.wikihosting.com
#
# Copyright 2005,2006 Will Norris.  All Rights Reserved.
# License: GPL
################################################################################

my $TWIKIDEV;

BEGIN {
    if ( $TWIKIDEV = $ENV{TWIKIDEV} ) {
        my $cpan = "$TWIKIDEV/CPAN/";
        unshift @INC, ( "$cpan/lib", "$cpan/lib/arch" ) if -d $cpan;
    }
}

use FindBin;
use Cwd;
use Data::Dumper;
use Getopt::Long;
use Pod::Usage;
use LWP::Simple;
use Error qw( :try );

use constant BUILD_LOCK  => '.build';
use constant LAST_BUILD  => '.last_build';
use constant FREEZE_LOCK => '.freeze';

my $Config = {
    force => 0,

    #
    verbose => 0,
    debug   => 0,
    help    => 0,
    man     => 0,
};

my $result = GetOptions(
    $Config,

    #
    'force|f',

    # miscellaneous/generic options
    'help', 'man', 'debug', 'verbose|v',
);
pod2usage(1) if $Config->{help};
pod2usage( { -exitval => 1, -verbose => 2 } ) if $Config->{man};
print STDERR Dumper($Config) if $Config->{debug};

# make easy to work as a crontab job
chdir($FindBin::Bin);

################################################################################

# bail early (as early as possible) if we're already doing a build
exit 0 if -e BUILD_LOCK || -e FREEZE_LOCK;

chomp( my ( $rev, $author ) = `./latest-svn-checkin.pl` );

my $lastVersion = '';
if ( open( VERSION, '<', LAST_BUILD ) ) {
    chomp( $lastVersion = <VERSION> );
    close(VERSION);
}

my $newVersionAvailable = !$lastVersion || ( $rev > $lastVersion );
if ( $Config->{force} || $newVersionAvailable ) {
    try {

        # start new build
        open( LOCK, ">", BUILD_LOCK ) or die $!;
        print LOCK "$rev\n";
        close(LOCK);

        system('./tinderbox.pl');
        throw Error::Simple('build error') if $?;

        # SMELL
        my $wikiPage = LWP::Simple::get(
'http://tinderbox.wbniv.wikihosting.com/cgi-bin/twiki/view.cgi/Foswiki/WebHome'
        );
        throw Error::Simple('installation error')
          unless ( $wikiPage || '' ) =~ /build\s+$rev/i;

        # mark build complete
        rename BUILD_LOCK, LAST_BUILD;
    }
    catch Error::Simple with {    # try again next crontab iteration
        unlink BUILD_LOCK;
    };
}

exit 0;

################################################################################
################################################################################

__DATA__

=head1 NAME

rebuild-deploy-test-if-new.pl - 

=head1 SYNOPSIS

rebuild-deploy-test-if-new.pl [options]

crontab-compatible script used to perform the following:

   * run the (unit) tests
   * build a new twiki kernel
   * build a new distribution
   * publish the distribution
   * install the distribution
   * run the (golden html) tests
   * post the test results to tinderbox.wbniv.wikihosting.com

Copyright 2005 Will Norris.  All Rights Reserved.

 Options:
   -force                       force a new build, test, and install procedure even if current
   -verbose
   -debug
   -help			this documentation
   -man				full docs

=head1 OPTIONS

=over 8

=back

=head1 DESCRIPTION

The existence of a .freeze file prevents new checkins from being built and deployed.  This is 
handy when testing a given build, but new checkins are rolling in.

=head2 SEE ALSO

=cut
