#! /usr/bin/env perl
#
# Build a Foswiki Release from branches in the Foswiki git repository - see https://foswiki.org/Development/BuildingARelease
#    * checkout Foswiki Branch
#    * run the unit tests
#    * run other tests
#    * build a release tarball & upload...
#
# Sven Dowideit Copyright (C) 2006-2011 All rights reserved.
# Florian Schlichting Copyright (C) 2013-2015
# gpl3 or later licensed.
#
# If you are running an automated nightly build system, call with ./autoBuildFoswiki.pl --autobuild
# to have output files copied to a webserver and a notification email sent
# everyone else, can just run perl autoBuildFoswiki.pl

use strict;
use warnings;

use Getopt::Long;

#use Data::Dump qw(dump);

# defaults
my $DefaultConfig = {
    mailFrom => "",
    mailTo   => "",

    stableBranch  => 'Release02x01',    # what branch to check out with --stable
    foswikiBranch => 'master',

    scpDestination => "",               # upload of release build
    url            => "",               # web location of the build

    checkoutDir       => undef, # directory that holds the git checkout
    localLibFile      => "",    # path to additional local config (LocalLib.cfg)
    logFile           => undef, # default logfile
    unitTestLogFile   => undef, # unit test output
    memoryTestLogFile => undef, # memory test output
    perlCriticsLogFile => undef,    # perlcritic output

    # some booleans
    doPrepairCheckout => 1,
    doCleanup         => 1,
    doUnitTests       => 1,
    doMemoryTests     => 0,
    doPerlCritics     => 0,
    doUpload          => 1,
    doEmail           => 1,
};

# options
my $configFile = $ENV{HOME} . "/.autoBuildFoswiki.cfg";
my $verbose    = 0;

GetOptions(
    "stable" =>
      sub { $DefaultConfig->{foswikiBranch} = $DefaultConfig->{stableBranch} },
    "verbose"  => \$verbose,
    "config:s" => \$configFile,
) or die "unknown option, use --stable, --verbose, --config <file>";

sub loadConfig {

    use vars qw($VAR1);

    if ($configFile) {
        require $configFile;
    }

    # local config
    my $cfg = { %$DefaultConfig, %$VAR1 };

    # sanitize config settings
    $cfg->{checkoutDir}        //= "/tmp/" . $cfg->{foswikiBranch};
    $cfg->{logFile}            //= "/tmp/autoBuildFoswiki.log";
    $cfg->{unitTestLogFile}    //= "/tmp/autoBuildFoswiki-unit-tests.log";
    $cfg->{memoryTestLogFile}  //= "/tmp/autoBuildFoswiki-memory-tests.log";
    $cfg->{perlCriticsLogFile} //= "/tmp/autoBuildFoswiki-perlcritics.log";

    return $cfg;
}

sub readFile {
    my ($name) = @_;

    my $data = '';
    my $IN_FILE;
    open( $IN_FILE, '<', $name ) || return '';

    local $/ = undef;    # set to read to EOF
    $data = <$IN_FILE>;
    close($IN_FILE);
    $data = '' unless $data;    # no undefined
    return $data;
}

sub writeDebug {
    return unless $verbose;
    print STDERR "### " . $_[0] . "\n";
}

sub sendEmail {
    my ( $cfg, $to, $subject, $body ) = @_;

    $to //= $cfg->{mailTo};
    return unless $to && $cfg->{mailFrom};

    writeDebug("sending email from $cfg->{mailFrom} to $to");

    # send mail
    my $MAIL;

    open( $MAIL,
        "|/usr/sbin/sendmail -t -oi -oem"
          || print STDERR "Error sending mail\n" );

    print $MAIL "From: $cfg->{mailFrom}\n";
    print $MAIL "To: $to\n";
    print $MAIL "Subject: $subject\n";
    print $MAIL "\n";
    print $MAIL "$body\n";
    close $MAIL;
}

sub prepairCheckout {
    my $cfg = shift;

    unless ( $cfg->{doPrepairCheckout} ) {
        writeDebug("NOT preparing the checkout area");
        return;
    }

    # GIT checkout / update

    if ( -d $cfg->{checkoutDir} ) {
        writeDebug("using existing checkout '$cfg->{checkoutDir}'");
        chdir( $cfg->{checkoutDir} )
          or die "failed to chdir to $cfg->{checkoutDir}";

        if ( $cfg->{doCleanup} ) {
            writeDeug("removing extra files");

            system(<<HERE) == 0 or die "cleanup failed";
git clean -fdx > $cfg->{logFile}
git status -s | grep '^ M ' | cut -d' ' -f3 | xargs git checkout >> $cfg->{logFile}
git status -s | grep '??' | cut -f2 -d' ' | xargs rm -rfv >> $cfg->{logFile}
git pull >> $cfg->{logFile}
HERE

        }
    }
    else {
        writeDebug("doing a fresh checkout");

        system(<<HERE) == 0 or die "GIT clone failed";
git clone https://github.com/foswiki/distro $cfg->{checkoutDir} > $cfg->{logFile}
HERE

        chdir( $cfg->{checkoutDir} )
          or die "failed to chdir to $cfg->{checkoutDir}";

    }

    system("git checkout $cfg->{foswikiBranch} >> $cfg->{logFile}");

    if ( $cfg->{localLibFile} && -s $cfg->{localLibFile} ) {
        writeDebug("installing localLibFile $cfg->{localLibFile}");
        system(<<HERE);
cp -v $cfg->{localLibFile} $cfg->{checkoutDir}/core/bin/ >> $cfg->{logFile}
HERE

    }

    chdir('core') or die "failed to chdir to core";
    system(<<HERE);
./pseudo-install.pl developer >> $cfg->{logFile}
./pseudo-install.pl -A >> $cfg->{logFile}
HERE

}

sub runUnitTests {
    my $cfg = shift;

    unless ( $cfg->{doUnitTests} ) {
        writeDebug("NOT running unit tests");
        return;
    }

    writeDebug("running unit tests");

    chdir("$cfg->{checkoutDir}/core/test/unit");

    my $errorCode = system(<<HERE);
export FOSWIKI_LIBS=$cfg->{checkoutDir}/core/lib; 
export FOSWIKI_HOME=$cfg->{checkoutDir}/core; 
/usr/bin/time -v perl $cfg->{checkoutDir}/core/test/bin/TestRunner.pl -tap -clean FoswikiSuite.pm > $cfg->{unitTestLogFile} 2>&1
HERE

    $errorCode = $errorCode >> 8;
    writeDebug("errorCode=$errorCode");

    my $unitTestsErrors = readFile( $cfg->{unitTestLogFile} );
    writeDebug("unitTestsErrors=$unitTestsErrors");

    # only output the summary
    unless ( $unitTestsErrors =~ s/^(.*)Unit test run Summary://s ) {
        my $lastTest = '';

        if ( $unitTestsErrors =~ /.*^(Running .*?\z)/sm ) {
            $lastTest = "Last test:\n$1\n";
        }

        $unitTestsErrors =
            "Unit tests ended abnormally. "
          . $lastTest
          . "Please check the unit test log.\n";
    }

    if ($errorCode) {
        if ( $cfg->{doEmail} ) {
            sendEmail(
                $cfg,
                undef,
"[AUTOTEST] Foswiki $cfg->{foswikiBranch} has Unit test FAILURES",
                " see $cfg->{url}$cfg->{foswikiBranch}/ for output files.\n"
                  . $unitTestsErrors
            );
        }
    }
}

sub runMemoryTests {
    my $cfg = shift;

    unless ( $cfg->{doMemoryTests} ) {
        writeDebug("NOT running memory tests");
        return;
    }
    writeDebug("runing memory tests");

    system("perl MemoryCycleTests.pl > $cfg->{memoryTestLogFile} 2>&1");

    #TODO: add a performance BM & compare to something golden.
}

sub runPerlCritics {
    my $cfg = shift;

    unless ( $cfg->{doPerlCritics} ) {
        writeDebug("NOT running memory tests");
        return;
    }

    writeDebug("runing perlcritics");

    system(<<HERE);
perlcritic --severity 5 --statistics --top 20 --exclude=Variables::ProtectPrivateVars $cfg->{checkoutDir}/core/lib/ $cfg->{checkoutDir}/core/bin/ > $cfg->{perlCriticsLogFile} 2>&1
HERE

    #writeDebug(readFile($cfg->{perlCriticsLogFile})) if $verbose;
}

sub checkManifest {
    my $cfg = shift;

    writeDebug("checking manifest");
    system(
"cd $cfg->{checkoutDir}/core/tools; perl check_manifest.pl >> $cfg->{logFile}"
    );
}

sub checkTopicInfo {
    my $cfg = shift;

    writeDebug("checking topicinfo");
    my $ret = system(<<HERE);
grep '%META:TOPICINFO{' $cfg->{checkoutDir}/core/data/*/*.txt | grep -v TestCases |grep -v Trash | grep -v 'author="ProjectContributor".*version="1"' >> $cfg->{logFile}
HERE

    $ret = $ret >> 8;

    #writeDebug("ret=$ret");

    die "invalid topicinfo found" unless $ret;

}

sub buildRelease {
    my $cfg = shift;

    writeDebug("building release $cfg->{foswikiBranch}");

#TODO: clean the setup again
#   1.  Install developer plugins (hard copy)
#      * perl pseudo-install.pl developer to install the plugins specified in MANIFEST
#   2. use the configure script to make your system basically functional
#      * ensure that your apache has sufficient file and directory permissions for data and pub
#   3. cd tools
#   4. perl build.pl release
#      * Note: if you specify a release name the script will attempt to commit to svn

   #  system(<<HERE);
   #cd $cfg->{checkoutDir}
   #git status -s | grep '^ M ' | cut -d' ' -f3 | xargs git checkout >> $logFile
   #HERE

    my $ret = system(<<HERE);
export FOSWIKI_LIBS=$cfg->{checkoutDir}/core/lib:$cfg->{checkoutDir}/lib/CPAN/lib; 
export FOSWIKI_HOME=$cfg->{checkoutDir}/core; 
cd $cfg->{checkoutDir}/core/lib
perl ../tools/build.pl release -auto -nocheck >> $cfg->{logFile} 2>&1
HERE

    $ret = $ret >> 8;

    #writeDebug("ret=$ret");

    die "build failed. see $cfg->{logFile}" if $ret;
}

sub uploadBuild {
    my $cfg = shift;

    return unless $cfg->{doUpload};

    writeDebug("uploading build");

    #create -latest links
    opendir( my $dh, "$cfg->{checkoutDir}/core" );
    foreach my $file ( grep /Foswiki-.*auto/, readdir $dh ) {
        my $link = $file;
        $link =~ s/-auto\w+/-latest/;
        symlink $file, $link;
    }

    #push the files to the server
    system(<<HERE);
scp ../*/*.zip $cfg->{scpDestination}$cfg->{foswikiBranch}/
scp ../*/*.tgz $cfg->{scpDestination}$cfg->{foswikiBranch}/
scp ../*/*.md5 $cfg->{scpDestination}$cfg->{foswikiBranch}/
scp Foswiki* $cfg->{scpDestination}$cfg->{foswikiBranch}/
HERE

}

sub sendBuildReport {
    my $cfg = shift;

    return unless $cfg->{doEmail};

    my $buildOutput      = `ls -alh *auto*`;
    my $emailDestination = $cfg->{mailFrom};
    if ( $buildOutput eq '' ) {

        #Raise the alarm, no files actually built
        $buildOutput .=
"\nERROR: Unit test did not fail, but no output files found, please consult build log.\n";
        $emailDestination = $cfg->{mailTo};
    }
    $buildOutput .= "\n";
    $buildOutput .= `grep 'All tests passed' $cfg->{unitTestLogFile}`;
    sendEmail(
        $cfg,
        $emailDestination,
        "[AUTOBUILD] Foswiki $cfg->{foswikiBranch} built OK",
        " see $cfg->{url}$cfg->{foswikiBranch}/ for output files.\n"
          . $buildOutput
    );
}

# load settings
my $Config = loadConfig();

# report config settings
writeDebug("configFile=$configFile");

#writeDebug("config=".dump($Config));

prepairCheckout($Config);
runUnitTests($Config);
runMemoryTests($Config);
runPerlCritics($Config);
checkManifest($Config);
checkTopicInfo($Config);
buildRelease($Config);
uploadBuild($Config);
sendBuildReport($Config);

1;
