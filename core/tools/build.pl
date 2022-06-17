#! /usr/bin/env perl 
#
# Build for Foswiki
# Crawford Currie, Sven Dowideit, Michael Daum
# Copyright (C) 2006-2022 ProjectContributors. All rights reserved.
# ProjectContributors are listed in the AUTHORS file in the root of
# the distribution.

use strict;
use warnings;

BEGIN {
    use File::Spec;

    unshift @INC, split( /:/, $ENV{FOSWIKI_LIBS} || '../lib' );

    # designed to be run within a GIT checkout area
    my @path = split( /\/+/, File::Spec->rel2abs($0) );
    pop(@path);    # the script name

    while ( scalar(@path) > 0 ) {
        last if -d join( '/', @path ) . '/../BuildContrib';
        pop(@path);
    }

    if ( scalar(@path) ) {
        unshift @INC, join( '/', @path ) . '/../BuildContrib/lib';
    }
}

use Foswiki::Contrib::Build;
use Foswiki::Contrib::BuildContrib::Targets::stage;
use Foswiki::Contrib::BuildContrib::Targets::archive;

# Declare our build package
package FoswikiBuild;

@FoswikiBuild::ISA = ("Foswiki::Contrib::Build");

sub new {
    my $class = shift;
    my ( $version, $release ) = _getReleaseInfo();
    my $name = "Foswiki-$version";

    while ( scalar(@ARGV) > 1 ) {
        my $arg = pop(@ARGV);
        if ( $arg eq '-auto' ) {

            #build a name from major.minor.patch.-auto.gitrev
            my $rev = `git rev-parse --short HEAD`;
            chomp $rev;
            $name .= '-auto' . $rev;
            $name =~ s/\s*$//g;
        }
    }

    print <<END;
You are about to build Foswiki.

Note: DO NOT ATTEMPT TO GENERATE A RELEASE UNLESS ALL UNIT TESTS PASS.
The unit tests are a critical part of the release process, as they
establish the correct baseline functionality. If a unit test fails,
any release package generated from that code is USELESS.

Current version of Foswiki.pm: $version, RELEASE: $release

END

    # make sure the project name (and hence the files we generate)
    # do not contain spaces
    $name =~ s/\s/_/g;

    my $this = $class->SUPER::new( $name, "Foswiki" );
    return $this;
}

# Override installer target; don't want an installer.
sub target_installer {
    my $this = shift;
}

sub target_stage {
    my $this = shift;

    # Create a Foswiki-* directory to hold everything, so the archive is safer
    $this->{rootTmpDir} = File::Temp::tempdir( CLEANUP => 1 );
    $this->{tmpDir} =
      File::Spec->catdir( $this->{rootTmpDir},
        $this->{name} || $this->{project} );
    $this->makepath( $this->{tmpDir} );
    $this->SUPER::target_stage();

    $this->stage_gendocs();

    # Reactivate this line if we want to build with ,v files
    # $this->stage_rcsfiles();
}

sub target_archive {
    my $this = shift;

    # Remove the hack for the Foswiki-* directory, so the archive contains it
    $this->{tmpDir} = $this->{rootTmpDir};
    $this->SUPER::target_archive();
}

# check in a single file to RCS
sub _checkInFile {
    my ( $this, $old, $new, $file ) = @_;

    return if ( shift =~ /\,v$/ );    #lets not check in ,v files

    my $currentRevision = 0;
    print "Checking in $new/$file\r";

    # Remember the permissions
    my @s     = stat("$new/$file");
    my $perms = $s[2];

    if ( -e $old . '/' . $file . ',v' ) {
        $this->cp( $old . '/' . $file . ',v', $new . '/' . $file . ',v' );

        #force unlock
        `rcs -u -M $new/$file,v 2>&1`;

        #lock to this user
        `rcs -l $new/$file 2>&1`;

        #try to get current revision number
        my $rcsInfo = `rlog -r $new/$file 2>&1`;
        if ( $rcsInfo =~ /revision \d+\.(\d+)/ ) {    #revision 1.2
            $currentRevision = $1;
        }
        else {

#it seems that you can have a ,v file with no commit, if you get here, you have an invalid ,v file. remove that file.
            die 'failed to get revision (make sure the ,v file is valid): '
              . $file . "\n";
        }
    }
    else {

        #set revision number #TODO: what about topics with no META DATA?
        my $cmd =
            'perl -pi -e \'s/^(%META:TOPICINFO{.*version=)\"[^\"]*\"(.*)$/$1\"'
          . ( $currentRevision + 1 )
          . '\"$2/\' '
          . $new . '/'
          . $file;
        `$cmd`;

        # create rcs file
`ci -u -mbuildrelease -wProjectContributor -t-buildrelease $new/$file 2>&1`;
    }

#only do a checkin, if the files are different (fake the rev number to be the same)
    my $cmd =
        'perl -pi -e \'s/^(%META:TOPICINFO{.*version=)\"[^\"]*\"(.*)$/$1\"'
      . ($currentRevision)
      . '\"$2/\' '
      . $new . '/'
      . $file;
    `$cmd`;
    my $different = `rcsdiff -q $new/$file`;
    chomp($different);

    if ( defined($different) && ( $different ne '' ) ) {

        #set revision number #TODO: what about topics with no META DATA?
        my $cmd =
            'perl -pi -e \'s/^(%META:TOPICINFO{.*version=)\"[^\"]*\"(.*)$/$1\"'
          . ( $currentRevision + 1 )
          . '\"$2/\' '
          . $new . '/'
          . $file;
        `$cmd`;

        #check in
        `ci -mbuildrelease -wProjectContributor -t-new-topic $new/$file 2>&1`;

        #get a copy of the latest revsion, no lock
        `co -u -M $new/$file 2>&1`;
        print "\n";
    }
    else {

        #force unlock
        `rcs -u -M $new/$file,v 2>&1`;
        print "nochange to $new/$file\n";
    }

    # restore the permissions
    chmod( $perms, "$new/$file" );
}

# recursively check in files to RCS
sub _checkInDir {
    my ( $this, $old, $new, $root, $filterIn ) = @_;
    my $dir;

    opendir( $dir, "$new/$root" ) || die "Failed to open $root: $!";
    print "Scanning $new/$root...\r";
    foreach my $content ( grep { !/^\./ } readdir($dir) ) {
        my $sub = "$root/$content";
        if ( -d "$new/$sub" ) {
            $this->_checkInDir( $old, $new, $sub, $filterIn );
        }
        elsif ( -f "$new/$sub" && &$filterIn($sub) ) {
            $this->_checkInFile( $old, $new, $sub );
        }
    }
    close($dir);
}

sub stage_gendocs {
    my $this = shift;

    # Note: generated documentation files do *NOT* appear in MANIFEST

    # generate the POD documentation
    print "Building automatic documentation to $this->{tmpDir}...";
    $this->cp( "$this->{basedir}/AUTHORS",
        "$this->{tmpDir}/pub/System/ProjectContributor/AUTHORS" );
    $this->cp( "$this->{basedir}/pub/System/DocumentGraphics/viewtopic.png",
        "$this->{tmpDir}/viewtopic.png" );

#SMELL: these should probably abort the build if they return errors / oopies
#replaced by the simpler INSTALL.html
#    print `cd $this->{basedir}/bin ; ./view System.CompleteDocumentation skin plain | $this->{basedir}/tools/fix_local_links.pl > $this->{tmpDir}/CompleteDocumentation.html`;
    print
`cd $this->{basedir}/bin ; ./view -topic System.ReleaseHistory -skin plain | $this->{basedir}/tools/fix_local_links.pl > $this->{tmpDir}/ReleaseHistory.html`;
    print
`cd $this->{basedir}/bin ; ./view -topic System.ReleaseNotes02x01 -skin plain | $this->{basedir}/tools/fix_local_links.pl > $this->{tmpDir}/ReleaseNotes02x01.html`;
    print
`cd $this->{basedir}/bin ; ./view -topic System.UpgradeGuide -skin plain | $this->{basedir}/tools/fix_local_links.pl > $this->{tmpDir}/UpgradeGuide.html`;
    print
`cd $this->{basedir}/bin ; ./view -topic System.InstallationGuide -skin plain | $this->{basedir}/tools/fix_local_links.pl > $this->{tmpDir}/INSTALL.html`;
    $this->filter_txt(
        "$this->{tmpDir}/ReleaseNotes02x01.html",
        "$this->{tmpDir}/ReleaseNotes02x01.html"
    );
    print "Automatic documentation built\n";
}

sub stage_rcsfiles {
    my $this = shift;

    # Quick hack to force the old RCS code in this script
    # to just build a rev 1 ,v file for all files
    my $rcsCheckinDir = '/tmp/NoneExistingDir';

    $this->_checkInDir( $rcsCheckinDir, $this->{tmpDir}, 'data',
        sub { return shift =~ /\.txt$/ } );

    $this->_checkInDir( $rcsCheckinDir, $this->{tmpDir}, 'pub',
        sub { return -f shift; } );

    # Fix perms mangled by RCS
    $this->apply_perms( $this->{files}, $this->{tmpDir} );

    $this->rm($rcsCheckinDir);
}

# Create the build object
my $build = new FoswikiBuild();

# Build the target on the command line, or the default target
$build->build( $build->{target} );

#returns the version number and release portion as stored in Foswiki.pm
sub _getReleaseInfo {
    open( my $pm, '<', "../lib/Foswiki.pm" )
      or die "Cannot open Foswiki.pm: $!";

    my $version = 'UNKNOWN';
    my $release = 'UNKNOWN';

    while (<$pm>) {

        if (/\$VERSION\s*=\s*version\->declare\('v(.*?)'\)/) {
            $version = $1;
        }
        if (/\$RELEASE\s*=\s*'(.*?)'/) {
            $release = $1;
        }
    }
    close $pm;
    return ( $version, $release );
}

