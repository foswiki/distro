#!/usr/bin/perl -w
#
# Build for Foswiki
# Crawford Currie & Sven Dowideit
# Copyright (C) 2006-2008 ProjectContributors. All rights reserved.
# ProjectContributors are listed in the AUTHORS file in the root of
# the distribution.

use strict;

BEGIN {
    use File::Spec;

    unshift @INC, split( /:/, $ENV{FOSWIKI_LIBS} || '../lib' );

    # designed to be run within a SVN checkout area
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

# Declare our build package
package FoswikiBuild;

@FoswikiBuild::ISA = ("Foswiki::Contrib::Build");

my $cvs;
my $gitdir;

sub new {
    my $class = shift;
    my $autoBuild;    #set if this is an automatic build
    my $name;

    if ( my $gitdir = findPathToDir('.git') ) {
        $cvs = 'git';
        print
"detected git installation at $gitdir\n*Note: svn will still be used to query the Repository for the list of release tags.\n";

     # Verify that all files are committed and all commits are dcommmited to svn
        my $gitstatus = `git status -uno`;
        die
          "***\nuncommitted changes in tree - build aborted\n***\n$gitstatus\n"
          if ( $gitstatus =~ m/(modified:)|(new file:)|(deleted:)/ );
        my $gitlog = `git log -1`;
        die "***\n*** changes not yet dcommited - build aborted\n***\n$gitlog\n"
          if ( $gitlog !~ m/git-svn-id:/ );
    }
    else {
        print "detected svn installation\n\n";
        $cvs = 'svn';
    }

    if ( scalar(@ARGV) > 1 ) {
        $name = pop(@ARGV);
        if ( $name eq '-auto' ) {

            #build a name from major.minor.patch.-auto.svnrev
            my $rev = ( $cvs eq 'svn' ) ? `svn info ..` : `git svn info`;
            $rev =~ /Revision: (\d*)/m;
            $name      = 'Foswiki-' . getCurrentFoswikiRELEASE() . '-auto' . $1;
            $autoBuild = 1;
        }
    }

    print <<END;

You are about to build Foswiki. If you are not building a release, for
example you are building a package just for your own testing purposes,
then you can leave it unnamed.

Note: DO NOT ATTEMPT TO GENERATE A RELEASE UNLESS ALL UNIT TESTS PASS.
The unit tests are a critical part of the release process, as they
establish the correct baseline functionality. If a unit test fails,
any release package generated from that code is USELESS.

If you provide a release name, Foswiki.pm will be automatically edited
to insert the new name of the release. The updated Foswiki.pm will be
checked in before the build starts.

The release *must* be named according to the standard scheme i.e

major.minor.patch[-qualifier]

where -qualifier is optional (it usually somthing like -beta).

This will be translated to appropriate package and topic names.

(The release name can optionally be passed in a *second* parameter
to the script e.g. perl build.pl release 4.6.5)

I'm now looking in the tags for the designation of the *last* release....
END
    my @olds = sort grep { /^FoswikiRelease\d+x\d+x\d+$/ }
      split( '/\n', `svn ls http://svn.foswiki.org/tags` );

    unless ($autoBuild) {
        if (
            $name
            || Foswiki::Contrib::Build::ask(
                "Do you want to name this release?", 'n'
            )
          )
        {
            while ( $name !~ /^\d\.\d+\.\d+(-\w+)?$/ ) {
                $name = Foswiki::Contrib::Build::prompt(
                    "Enter name of this release: ", $name );
            }

            # SMELL: should really check that the name actually *follows* the
            # last name generated
            $name = 'Foswiki-' . $name;
            open( PM, '<', "../lib/Foswiki.pm" ) || die $!;
            local $/ = undef;
            my $content = <PM>;
            close(PM);
            $content =~ /\$RELEASE\s*=\s*'(.*?)'/;
            $content =~ s/(\$RELEASE\s*=\s*').*?(')/$1$name$2/;
            open( PM, '>', "../lib/Foswiki.pm" ) || die $!;
            print PM $content;
            close(PM);

            # Note; the commit is unconditional, because we *must* update
            # Foswiki.pm before building.
            my $tim = 'BUILD ' . $name . ' at ' . gmtime() . ' GMT';
            if ( $cvs eq 'svn' ) {
                my $cmd = "svn propset LASTBUILD '$tim' ../lib/Foswiki.pm";
                print `$cmd`;

                #print "$cmd\n";
                die $@ if $@;
                $cmd = "svn commit -m 'Item000: $tim' ../lib/Foswiki.pm";
                print `$cmd`;

                #print "$cmd\n";
                die $@ if $@;
            }
            else {
                my $cmd = "git commit -m 'Item000: $tim' ../lib/Foswiki.pm";
                print `$cmd`;
                die $@ if $@;
            }

        }
        else {
            $name = 'Foswiki';
        }
    }

    my $this = $class->SUPER::new( $name, "Foswiki" );
    return $this;
}

# Search the current working directory and its parents
# # for a directory called like the first parameter
sub findPathToDir {
    my $lookForDir = shift;

    my @dirlist = File::Spec->splitdir( Cwd::getcwd() );
    do {
        my $dir = File::Spec->catdir( @dirlist, $lookForDir );
        return File::Spec->catdir(@dirlist) if -d $dir;
    } while ( pop @dirlist );
    return;
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
    $this->cp( "$this->{tmpDir}/AUTHORS",
        "$this->{tmpDir}/pub/System/ProjectContributor/AUTHORS" );

#SMELL: these should probably abort the build if they return errors / oopies
#replaced by the simpler INSTALL.html
#    print `cd $this->{basedir}/bin ; ./view System.CompleteDocumentation skin plain | $this->{basedir}/tools/fix_local_links.pl > $this->{tmpDir}/CompleteDocumentation.html`;
    print
`cd $this->{basedir}/bin ; ./view -topic System.ReleaseHistory -skin plain | $this->{basedir}/tools/fix_local_links.pl > $this->{tmpDir}/ReleaseHistory.html`;
    print
`cd $this->{basedir}/bin ; ./view -topic System.ReleaseNotes01x01 -skin plain | $this->{basedir}/tools/fix_local_links.pl > $this->{tmpDir}/ReleaseNotes01x01.html`;
    print
`cd $this->{basedir}/bin ; ./view -topic System.UpgradeGuide -skin plain | $this->{basedir}/tools/fix_local_links.pl > $this->{tmpDir}/UpgradeGuide.html`;
    print
`cd $this->{basedir}/bin ; ./view -topic System.InstallationGuide -skin plain | $this->{basedir}/tools/fix_local_links.pl > $this->{tmpDir}/INSTALL.html`;
    $this->filter_txt(
        "$this->{tmpDir}/ReleaseNotes01x01.html",
        "$this->{tmpDir}/ReleaseNotes01x01.html"
    );
    print "Automatic documentation built\n";
}

sub stage_rcsfiles() {
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

#returns the version number portion in the $RELEASE line in Foswiki.pm
sub getCurrentFoswikiRELEASE {
    open( PM, '<', "../lib/Foswiki.pm" ) || die $!;
    local $/ = undef;
    my $content = <PM>;
    close(PM);
    $content =~ /\$RELEASE\s*=\s*'Foswiki-(.*?)'/;
    return $1;
}

