#! /usr/bin/perl -w
#
# Build a Foswiki Release from branches in the Foswiki  svn repository - see http://foswiki.org/Development/BuildingARelease
# checkout Foswiki Branch
# run the unit tests
# run other tests
# build a release tarball & upload...
# Sven Dowideit Copyright (C) 2006-2011 All rights reserved.
# gpl3 or later licensed.
#
# If you are Sven (used by Sven's automated nightly build system) - call with perl autoBuildFoswiki.pl -sven
# everyone else, can just run perl autoBuildFoswiki.pl
#
#

use strict;
use warnings;

use Getopt::Long;

# local config, should be moved to an external file in $ENV{HOME}?
my $mail_from =
  'fschlich@zedat.fu-berlin.de';    # also recipient in case of "nothing to say"
my $mail_to = 'foswiki-svn@lists.sourceforge.net';
my $stable_branch = 'Release01x01';    # what branch to check out with --stable
my $webspace_scp =
  '~/public_html/foswiki/';            # path to webspace as understood by scp
my $webspace_url = 'http://fschlich.userpage.fu-berlin.de/foswiki/'
  ;                                    # path to webspace for browsers

# options
my $SvensAutomatedBuilds = 0;
my $foswikiBranch        = 'trunk';
my $update               = 0;
my $verbose              = 0;

GetOptions(
    autobuild => \$SvensAutomatedBuilds,
    stable    => sub { $foswikiBranch = $stable_branch },
    update    => \$update,
    verbose   => \$verbose,
) or die "unknown option, use --autobuild, --stable, --verbose";

if ($update) {
`curl http://svn.foswiki.org/trunk/core/tools/autoBuildFoswiki.pl > autoBuildFoswiki.pl`;
    exit;
}

if ($verbose) {
    print STDERR "doing an automated Sven build\n" if $SvensAutomatedBuilds;
    print STDERR "building branch $foswikiBranch\n";
}

# SVN checkout / update
unless ( -e $foswikiBranch ) {
    print STDERR "doing a fresh checkout\n" if $verbose;
    if ( $foswikiBranch eq 'trunk' ) {
        `svn co http://svn.foswiki.org/$foswikiBranch > Foswiki-svn.log`;
    }
    else {
        # check out a branch
`svn co http://svn.foswiki.org/branches/$foswikiBranch > Foswiki-svn.log`;
    }
    die "SVN checkout failed" if $?;
    chdir( $foswikiBranch . '/core' );
}
else {

    #TODO: should really do an svn revert..
    print STDERR "using existing checkout, removing ? files" if $verbose;
    chdir($foswikiBranch);
    `svn status | grep ? | sed 's/?/rm -rv/' | sh > Foswiki-svn.log`;
    `svn up --accept 'theirs-full' >> Foswiki-svn.log`;
    chdir('core');
}

my $foswikihome = `pwd`;
chomp($foswikihome);

`mkdir -p working/tmp`;
`chmod 777 working/tmp`;
`chmod 777 lib`;

#TODO: add a trivial and correct LocalSite.cfg
`chmod -R 777 data pub`;

`perl -wT pseudo-install.pl -A developer`;

print "run unit tests\n" if $verbose;

#TODO: testrunner should exit == 0 if no errors?
chdir('test/unit');

# /usr/bin/time -v : -v print all stats, hopefully incl. max. res. memory usage
#                    /usr/bin/time to avoid bash (1) internal 'time' command
my $unitTests =
"export FOSWIKI_LIBS=$foswikihome/lib; export FOSWIKI_HOME=$foswikihome; /usr/bin/time -v perl ../bin/TestRunner.pl -tap -clean FoswikiSuite.pm 2>&1 > $foswikihome/Foswiki-UnitTests.log";
my $return    = `$unitTests`;
my $errorcode = $? >> 8;
unless ( $errorcode == 0 ) {
    open( UNIT, '<', "$foswikihome/Foswiki-UnitTests.log" );
    local $/ = undef;
    my $unittestErrors = <UNIT>;
    close(UNIT);

    #only output the summary
    unless ( $unittestErrors =~ s/^(.*)Unit test run Summary://s ) {
        my $lastTest = '';
        if ( $unittestErrors =~ /.*^(Running .*?\z)/sm ) {
            $lastTest = "Last test:\n$1\n";
        }
        $unittestErrors =
            "Unit tests ended abnormally. "
          . $lastTest
          . "Please check the unit test log.\n";
    }

    chdir($foswikihome);
    if ($SvensAutomatedBuilds) {
        `scp Foswiki* $webspace_scp$foswikiBranch/`;
        sendEmail(
            $mail_to,
            "[AUTOTEST] Foswiki $foswikiBranch has Unit test FAILURES",
            " see $webspace_url$foswikiBranch/ for output files.\n"
              . $unittestErrors
        );
    }
    die "\n\n$errorcode: unit test failures - need to fix them first\n";
}

######################################################
# go on if there are no unit test failures

chdir($foswikihome);

#TODO: add a performance BM & compare to something golden.
`perl tools/MemoryCycleTests.pl > $foswikihome/Foswiki-MemoryCycleTests.log 2>&1`;
`/usr/bin/perlcritic --severity 5 --statistics --top 20 --exclude=Variables::ProtectPrivateVars lib/  > $foswikihome/Foswiki-PerlCritic.log 2>&1`;
`/usr/bin/perlcritic --severity 5 --statistics --top 20 --exclude=Variables::ProtectPrivateVars bin/ >> $foswikihome/Foswiki-PerlCritic.log 2>&1`;

#`cd tools; perl check_manifest.pl`;
#`cd data; grep '%META:TOPICINFO{' */*.txt | grep -v TestCases | grep -v 'author="ProjectContributor".*version="\$Rev'`;

#TODO: #  fix up release notes with new changelogs - see
#
#    * http://foswiki.org/Tasks/ReleaseNotesTml?type=patch
#        * Note that the release note is edited by editing the topic data/Foswiki/FoswikiReleaseNotes04x00. The build script creates a file in the root of the zip called FoswikiReleaseNotes04x00? .html, and the build script needs your Twiki to be running to look up the release note topic and show it with the simple text skin.
#            * Note - from 4.1 we need to call this data/Foswiki/FoswikiReleaseNotes04x01
#
#

print "\n\n ready to build release\n" if $verbose;

#TODO: clean the setup again
#   1.  Install developer plugins (hard copy)
#      * perl pseudo-install.pl developer to install the plugins specified in MANIFEST
#   2. use the configure script to make your system basically functional
#      * ensure that your apache has sufficient file and directory permissions for data and pub
#   3. cd tools
#   4. perl build.pl release
#      * Note: if you specify a release name the script will attempt to commit to svn
chdir('lib');
`export FOSWIKI_LIBS=$foswikihome/lib; export FOSWIKI_HOME=$foswikihome; perl ../tools/build.pl release -auto > $foswikihome/Foswiki-build.log 2>&1`;

chdir($foswikihome);
if ($SvensAutomatedBuilds) {

    #push the files to the server
    `scp ../*/*.zip $webspace_scp$foswikiBranch/`;
    `scp ../*/*.tgz $webspace_scp$foswikiBranch/`;
    `scp ../*/*.md5 $webspace_scp$foswikiBranch/`;
    `scp Foswiki*   $webspace_scp$foswikiBranch/`;

    my $buildOutput      = `ls -alh *auto*`;
    my $emailDestination = $mail_from;
    if ( $buildOutput eq '' ) {

        #Raise the alarm, no files actually built
        $buildOutput .=
"\nERROR: Unit test did not fail, but no output files found, please consult build log.\n";
        $emailDestination = $mail_to;
    }
    $buildOutput .= "\n";
    $buildOutput .=
      `grep 'All tests passed' $foswikihome/Foswiki-UnitTests.log`;
    sendEmail(
        $emailDestination,
        "[AUTOBUILD] Foswiki $foswikiBranch built OK",
        " see $webspace_url$foswikiBranch/ for output files.\n" . $buildOutput
    );
}

sub sendEmail {
    my ( $to, $subject, $body ) = @_;

    # send mail
    open( MAIL,
        "|/usr/sbin/sendmail -t -oi -oem"
          || print STDERR "Error sending mail\n" );
    print MAIL "From: $mail_from\n";
    print MAIL "To: $to\n";
    print MAIL "Subject: $subject\n";
    print MAIL "\n";
    print MAIL "$body\n";
    close MAIL;
}
