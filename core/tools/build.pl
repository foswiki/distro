#!/usr/bin/perl -w
#
# Build for TWiki
# Crawford Currie & Sven Dowideit
# Copyright (C) 2006-2008 ProjectContributors. All rights reserved.
# ProjectContributors are listed in the AUTHORS file in the root of
# the distribution.

use strict;

BEGIN {
    use File::Spec;

    unshift @INC, split(/:/, $ENV{TWIKI_LIBS} || '../lib' );

    # designed to be run within a SVN checkout area
    my @path = split( /\/+/, File::Spec->rel2abs($0) );
    pop(@path); # the script name

    while (scalar(@path) > 0) {
        last if -d join( '/', @path).'/../BuildContrib';
        pop( @path );
    }

    if(scalar(@path)) {
        unshift @INC, join( '/', @path ).'/../BuildContrib/lib';
    }
}

use TWiki::Contrib::Build;

# Declare our build package
package TWikiBuild;

@TWikiBuild::ISA = ( "TWiki::Contrib::Build" );

sub new {
    my $class = shift;
    my $autoBuild;	#set if this is an automatic build
    my $name;

    if( scalar(@ARGV) > 1) {
        $name = pop( @ARGV );
	if ( $name eq '-auto' ) {
		#build a name from major.minor.patch.-auto.svnrev
		my $rev=`svn info ..`;
		$rev =~ /Revision: (\d*)/m;
		$name = 'TWiki-'.getCurrentTWikiRELEASE().'-auto'.$1;
		$autoBuild = 1;
	}
    }

print <<END;

You are about to build TWiki. If you are not building a release, for
example you are building a package just for your own testing purposes,
then you can leave it unnamed.

Note: DO NOT ATTEMPT TO GENERATE A RELEASE UNLESS ALL UNIT TESTS PASS.
The unit tests are a critical part of the release process, as they
establish the correct baseline functionality. If a unit test fails,
any release package generated from that code is USELESS.

If you provide a release name, TWiki.pm will be automatically edited
to insert the new name of the release. The updated TWiki.pm will be
checked in before the build starts.

The release *must* be named according to the standard scheme i.e

major.minor.patch[-qualifier]

where -qualifier is optional (it usually somthing like -beta).

This will be translated to appropriate package and topic names.

(The release name can optionally be passed in a *second* parameter
to the script e.g. perl build.pl release 4.6.5)

I'm now looking in the tags for the designation of the *last* release....
END
    my @olds = sort grep { /^TWikiRelease\d+x\d+x\d+$/ }
      split('/\n', `svn ls http://svn.twiki.org/svn/twiki/tags`);
    my $lastName = pop(@olds);
    my $last = $lastName;
    $last =~ s/TWikiRelease//;
    $last =~ s/^0+//;
    $last =~ s/x0+(\d)/x$1/g;
    $last =~ s/x/./g;
    print <<END;

I have detected that the last release was $last. I will automatically
generate histories for any data or pub files that changed since then.

END

    unless ($autoBuild) {
    if( $name ||
          TWiki::Contrib::Build::ask("Do you want to name this release?",
                                     'n')) {
            while( $name !~ /^\d\.\d+\.\d+(-\w+)?$/ ) {
                $name =
                  TWiki::Contrib::Build::prompt(
                      "Enter name of this release: ", $name);
            }
            # SMELL: should really check that the name actually *follows* the
            # last name generated
            $name = 'TWiki-'.$name;
            open(PM, "<../lib/TWiki.pm") || die $!;
            local $/ = undef;
            my $content = <PM>;
            close(PM);
            $content =~ /\$RELEASE\s*=\s*'(.*?)'/;
            $content =~ s/(\$RELEASE\s*=\s*').*?(')/$1$name$2/;
            open(PM, ">../lib/TWiki.pm") || die $!;
            print PM $content;
            close(PM);
            # Note; the commit is unconditional, because we *must* update
            # TWiki.pm before building.
            my $tim = 'BUILD '.$name.' at '.gmtime().' GMT';
            my $cmd = "svn propset LASTBUILD '$tim' ../lib/TWiki.pm";
            print `$cmd`;
            #print "$cmd\n";
            die $@ if $@;
            $cmd = "svn commit -m 'Item000: $tim' ../lib/TWiki.pm";
            print `$cmd`;
            #print "$cmd\n";
            die $@ if $@;
        } else {
            $name = 'TWiki';
        }
    }

    my $this = $class->SUPER::new( $name, "TWiki" );
    $this->{last} = $last;
    $this->{lastName} = $lastName;
    return $this;
}

# Override installer target; don't want an installer.
sub target_installer {
    my $this = shift;
}

sub target_stage {
    my $this = shift;

    $this->SUPER::target_stage();

    #use a Cairo install to create new ,v files for the data, and pub
    #WARNING: I don't know how to get the 'last' release, so i'm hardcoding Cairo
    $this->stage_gendocs();
    $this->stage_rcsfiles();
}

# check in a single file to RCS
sub _checkInFile {
    my( $this, $old, $new, $file ) = @_;

    return if ( shift =~ /\,v$/ ); #lets not check in ,v files

    my $currentRevision = 0;
    print "Checking in $new/$file\r";

    # Remember the permissions
    my @s = stat("$new/$file");
    my $perms = $s[2];

    if ( -e $old.'/'.$file.',v' ) {
        $this->cp($old.'/'.$file.',v', $new.'/'.$file.',v');
        #force unlock
        `rcs -u -M $new/$file,v 2>&1`;
        #lock to this user
        `rcs -l $new/$file 2>&1`;

        #try to get current revision number
        my $rcsInfo = `rlog -r $new/$file 2>&1`;
        if ( $rcsInfo =~ /revision \d+\.(\d+)/ ) {     #revision 1.2
            $currentRevision = $1;
        } else {
            #it seems that you can have a ,v file with no commit, if you get here, you have an invalid ,v file. remove that file.
            die 'failed to get revision (make sure the ,v file is valid): '.$file."\n";
        }
    } else {
        #set revision number #TODO: what about topics with no META DATA?
        my $cmd = 'perl -pi -e \'s/^(%META:TOPICINFO{.*version=)\"[^\"]*\"(.*)$/$1\"'.($currentRevision+1).'\"$2/\' '.$new.'/'.$file;
        `$cmd`;
        # create rcs file
        `ci -u -mbuildrelease -wProjectContributor -t-buildrelease $new/$file 2>&1`;
    }

    #only do a checkin, if the files are different (fake the rev number to be the same)
    my $cmd = 'perl -pi -e \'s/^(%META:TOPICINFO{.*version=)\"[^\"]*\"(.*)$/$1\"'.($currentRevision).'\"$2/\' '.$new.'/'.$file;
    `$cmd`;
    my $different = `rcsdiff -q $new/$file`;
    chomp($different);
 
    if (defined($different) && ($different ne '')) {
	    #set revision number #TODO: what about topics with no META DATA?
	    my $cmd = 'perl -pi -e \'s/^(%META:TOPICINFO{.*version=)\"[^\"]*\"(.*)$/$1\"'.($currentRevision+1).'\"$2/\' '.$new.'/'.$file;
	    `$cmd`;
	    #check in
    	`ci -mbuildrelease -wProjectContributor -t-new-topic $new/$file 2>&1`;
    	#get a copy of the latest revsion, no lock
    	`co -u -M $new/$file 2>&1`;
    	print "\n";
    } else {
        #force unlock
        `rcs -u -M $new/$file,v 2>&1`;
    	print "nochange to $new/$file\n";
    }

    # restore the permissions
    chmod($perms, "$new/$file");
}

# recursively check in files to RCS
sub _checkInDir {
    my( $this, $old, $new, $root, $filterIn ) = @_;
    my $dir;

    opendir( $dir, "$new/$root" ) || die "Failed to open $root: $!";
    print "Scanning $new/$root...\r";
    foreach my $content ( grep { !/^\./ } readdir($dir)) {
        my $sub = "$root/$content";
        if( -d "$new/$sub" ) {
            $this->_checkInDir( $old, $new, $sub, $filterIn );
        } elsif( -f "$new/$sub" && &$filterIn( $sub )) {
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
    print `perl $this->{basedir}/tools/gendocs.pl -debug -root $this->{tmpDir}`;
    $this->cp( "$this->{tmpDir}/AUTHORS",
               "$this->{tmpDir}/pub/TWiki/ProjectContributor/AUTHORS" );

    for my $script qw( view rdiff ) {
        $this->cp( "$this->{tmpDir}/bin/$script",
                   "$this->{tmpDir}/bin/${script}auth" );
        $this->prot( "0555", "$this->{tmpDir}/bin/${script}auth");
    }

    #SMELL: these should probably abort the build if they return errors / oopies
#replaced by the simpler INSTALL.html
#    print `cd $this->{basedir}/bin ; ./view TWiki.CompleteDocumentation skin plain | $this->{basedir}/tools/fix_local_links.pl > $this->{tmpDir}/CompleteDocumentation.html`;
    print `cd $this->{basedir}/bin ; ./view TWiki.ReleaseHistory skin plain | $this->{basedir}/tools/fix_local_links.pl > $this->{tmpDir}/ReleaseHistory.html`;
    print `cd $this->{basedir}/bin ; ./view TWiki.TWikiReleaseNotes04x02 skin plain | $this->{basedir}/tools/fix_local_links.pl > $this->{tmpDir}/TWikiReleaseNotes04x02.html`;
    print `cd $this->{basedir}/bin ; ./view TWiki.TWikiUpgradeGuide skin plain | $this->{basedir}/tools/fix_local_links.pl > $this->{tmpDir}/TWikiUpgradeGuide.html`;
    print `cd $this->{basedir}/bin ; ./view TWiki.InstallationGuide skin plain | $this->{basedir}/tools/fix_local_links.pl > $this->{tmpDir}/INSTALL.html`;
    $this->filter_txt("$this->{tmpDir}/TWikiReleaseNotes04x02.html", "$this->{tmpDir}/TWikiReleaseNotes04x02.html");
    print "Automatic documentation built\n";
}

sub stage_rcsfiles() {
    my $this = shift;

    # svn co cairo to a new dir
    #foreach file in data|pub in tmpDir, cp ,v file from svnCo 
    #do a ci
    #if there was no existing ,v file, make one and ci
    #my $lastReleaseDir = $this->{tmpDir}.'/lastRel'.($$ +1);
    #TODO: too unixy - but I'd like to stop checking out the entire release every nightly build
    #TODO: verify that this is an unadulterated version of the checkout
    my $lastReleaseDir = '/tmp/'.$this->{lastName};

    $this->makepath($lastReleaseDir);
    $this->pushd($lastReleaseDir);
    print "Checking out release $this->{last} to $lastReleaseDir\n";
    `svn co http://svn.twiki.org/svn/twiki/tags/$this->{lastName}/ .`;
    $this->popd();
    print "Creating ,v files.\n";
    $this->_checkInDir( $lastReleaseDir, $this->{tmpDir}, 'data',
                       sub { return shift =~ /\.txt$/ } );

    $this->_checkInDir( $lastReleaseDir, $this->{tmpDir}, 'pub',
                       sub { return -f shift; } );

    # Fix perms mangled by RCS
    $this->apply_perms($this->{files}, $this->{tmpDir} );

    $this->rm( $lastReleaseDir );
}

# Create the build object
my $build = new TWikiBuild();

# Build the target on the command line, or the default target
$build->build($build->{target});


#returns the version number portion in the $RELEASE line in TWiki.pm
sub getCurrentTWikiRELEASE {
        open(PM, "<../lib/TWiki.pm") || die $!;
        local $/ = undef;
        my $content = <PM>;
        close(PM);
        $content =~ /\$RELEASE\s*=\s*'TWiki-(.*?)'/;
	return $1;
}

