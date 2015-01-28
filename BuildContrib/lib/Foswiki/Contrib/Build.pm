#
# Copyright (C) 2004-2014 C-Dot Consultants - All rights reserved
# Copyright (C) 2008-2014 Foswiki Contributors
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html
#
package Foswiki::Contrib::Build;

use Foswiki::Contrib::BuildContrib::BaseBuild;
use Error qw(:try);
use CGI qw(:any);

=begin TML

---++ Package Foswiki::Contrib::Build

This is a base class used for making build scripts for Foswiki packages.

---+++ Methods

=cut

use strict;
use Digest::MD5  ();
use File::Copy   ();
use File::Spec   ();
use FindBin      ();
use File::Find   ();
use File::Path   ();
use File::Temp   ();
use POSIX        ();
use Data::Dumper ();
use warnings;
use Foswiki::Time;
use Foswiki::Contrib::BuildContrib;

our $basedir;       # Calculated root i.e one above 'lib'
our $buildpldir;    # Calculated location of build.pl
our $libpath;       # $basedir/lib/

our $VERSION;       # Version of BuildContrib
our $RELEASE;       # Release of BuildContrib

my $UPLOADSITEPUB           = 'http://foswiki.org/pub';
my $UPLOADSITESCRIPT        = 'http://foswiki.org/bin';
my $UPLOADSITESUFFIX        = '';
my $UPLOADSITEBUGS          = 'http://foswiki.org/Tasks';
my $UPLOADSITEEXTENSIONSWEB = "Extensions";
my $DEFAULTCUSTOMERDB       = "$ENV{HOME}/customerDB";
my $FOSWIKIAUTHORSFILE      = 'core/AUTHORS';

my $targetProject;    # Foswiki or TWiki

# use diagnostics;
# use Carp ();
# $SIG{__DIE__} = sub { Carp::confess $_[0] };

$ENV{'LC_ALL'} = 'C';

# Find a file relative to a directory passed (function call) or
# the basedir (method call)
sub findRelative {
    my ( $this, $name ) = @_;

    my $startdir = ref($this) ? $this->{basedir} : $this;

    my @path = split( /[\/\\]+/, $startdir );

    while ( scalar(@path) > 0 ) {
        my $found = join( '/', @path ) . '/' . $name;
        return $found if -e $found;
        pop(@path);
    }

    #try legacy TWiki Contrib
    $startdir =~ s/\/Foswiki\//\/TWiki\//g;
    @path = split( /\/+/, $startdir );

    #try a legacy TWiki contrib path.
    while ( scalar(@path) > 0 ) {
        my $found = join( '/', @path ) . '/' . $name;
        return $found if -e $found;
        pop(@path);
    }
    return undef;
}

BEGIN {

    # Get the absolute dir we are executing in (where build.pl is)
    $buildpldir = $FindBin::RealBin;
    $buildpldir = File::Spec->rel2abs($buildpldir);

    $VERSION = $Foswiki::Contrib::BuildContrib::VERSION;
    $RELEASE = $Foswiki::Contrib::BuildContrib::RELEASE;
    print "Building with BuildContrib $VERSION - $RELEASE \n";

    # Let's see if we are sitting in a conventional checkout structure,
    # and it has a defined LocalLib.cfg. If so then that's the basis of
    # our libs.
    my $expect_core = "$buildpldir/../../../../../core";
    if (   -e "$expect_core/bin/LocalLib.cfg"
        && -e "$expect_core/lib/LocalSite.cfg" )
    {
        print "Using Foswiki libraries found on relative paths\n";
        do "$expect_core/bin/setlib.cfg";
    }
    else {

        # Otherwise we need FOSWIKI_LIBS

        my $env = $ENV{'FOSWIKI_LIBS'};
        die <<ARGH unless $env;
We don't seem to be building in a configured subversion checkout, and
FOSWIKI_LIBS is not defined. I cannot determine how to find the Foswiki
libraries required to support the build system.

BuildContrib must either be run within a full subversion checkout
that has both LocalLib.cfg and LocalSite.cfg, or the environment variable
FOSWIKI_LIBS must point to a configured Foswiki.

In either case, the BuildContrib extension must be installed.
ARGH

        print "Using Foswiki libraries from $env\n";

        # normally this will be a nop, as build.pl will have already
        # added FOSWIKI_LIBS to @INC. But just in case some other
        # route was used, add the missing libs.
        my %known;
        map { $known{$_} = 1 } split( /:/, @INC );
        foreach my $pc ( reverse split( /:/, $env ) ) {
            unless ( $known{$pc} ) {
                unshift( @INC, $pc );
            }
        }
    }
    print 'Build libraries: ' . join( ' ', @INC ) . "\n";

    # Make sure we have a LocalSite.cfg
    my $haveLSC = 0;
    foreach my $dir (@INC) {
        if ( -e "$dir/LocalSite.cfg" ) {
            $haveLSC = 1;
            last;
        }
    }
    warn 'Could not find LocalSite.cfg anywhere in @INC - build aborted'
      unless $haveLSC;

    # Find the project lib root

    if ( -e "$buildpldir/../../../Foswiki" || -e "$buildpldir/../lib/Foswiki" )
    {
        $libpath = findRelative( $buildpldir, 'lib/Foswiki' );
        $targetProject = 'Foswiki';
    }
    else {
        print STDERR "Assuming this is a TWiki project\n";
        $libpath = findRelative( $buildpldir, 'lib/TWiki' );
        $targetProject = 'TWiki';
    }
    die 'Could not find lib/Foswiki or lib/TWiki' unless $libpath;
    $libpath =~ s#/[^/]*$##;

    $basedir = $libpath;
    $basedir =~ s#/[^/]*$##;

    unless ( grep( /$basedir\/lib/, @INC ) ) {
        unshift( @INC, $basedir . '/lib' );
    }
}

=begin TML

---++++ new($project)
| $project | Name of plugin, addon, contrib or skin |
| $rootModule | Optional, if defined gives the name of the root .pm module that carries the VERSION and dependencies. Defaults to $project |
Construct a new build object. Define the basic directory
paths to places in the build/release. Read the manifest topic
and build file and dependency lists. Parse command line to get
target and options.

=cut

sub new {
    my ( $class, $project, $rootModule ) = @_;
    my $this = bless(
        {

            # Constants with internet paths
            BUGSURL => $UPLOADSITEBUGS,

            project => $project,
            target  => 'test',
            basedir => $basedir,
        },
        $class
    );

    my $n    = 0;
    my $done = 0;
    while ( $n <= $#ARGV ) {
        if ( $ARGV[$n] =~ /^-/o ) {
            $this->{ $ARGV[$n] } = 1;
        }
        else {
            $this->{target} = $ARGV[$n];
        }
        $n++;
    }
    if ( $this->{-v} ) {
        print 'Building in ',      $buildpldir, "\n";
        print 'Root module is  ',  $rootModule, "\n" if $rootModule;
        print 'Basedir is ',       $basedir,    "\n";
        print 'Component dir is ', $libpath,    "\n";
        print 'Using path ' . join( ':', @INC ) . "\n";
    }

    # The following paths are all relative to the root of the
    # installation

    #SMELL: Hardcoded project classification
    # where the sub-modules live
    $this->{libdir} = $libpath;
    if ( $this->{project} =~ /Plugin$/ ) {
        $this->{libdir} .= "/$targetProject/Plugins";
    }
    elsif ( $this->{project} =~ /(Contrib|Skin|AddOn)$/ ) {
        $this->{libdir} .= "/$targetProject/Contrib";
    }

    # the .pm module
    $this->{ROOTMODULE} = $rootModule || $project;
    $this->{pm} = $this->{libdir} . '/' . $this->{ROOTMODULE} . '.pm';

    my $stubpath = $this->{pm};
    $stubpath =~ s/.*[\\\/]($targetProject[\\\/].*)\.pm/$1/;
    $stubpath =~ s/[\\\/]/::/g;

    my $badVersion;

    # Get $VERSION, $RELEASE and $SHORTDESCRIPTION
    if ( -e $this->{pm} ) {
        my $fh;
        if ( open( $fh, "<", $this->{pm} ) ) {
            local $/;
            my $text = <$fh>;
            close $fh;

            my $VERSION;
            my $RELEASE;
            my $SHORTDESCRIPTION;

            my ($version) = $text =~
              m/^\s*(?:use\ version.*?;)?\s*(?:our)?\s*(\$VERSION\s*=.*?);/sm;
            my ($release) = $text =~ m/^\s*(?:our)?\s*(\$RELEASE\s*=.*?);/sm;
            my ($description) =
              $text =~ m/^\s*(?:our)?\s*(\$SHORTDESCRIPTION\s*=.*?);/sm;

            $badVersion = 1 if ( $version =~ m/\$Date|\$Rev/ );

            substr( $version, 0, 0, 'use version 0.77; ' )
              if ( $version =~ /version/ );

            eval $version     if ($version);
            eval $release     if ($release);
            eval $description if ($description);

            $this->{files}[0]->{name} = $this->{pm};
            $this->{files}[0]->{name} =~ s/^$basedir\/(.*)/$1/;
            $this->{VERSION}          = $VERSION;
            $this->{RELEASE}          = $RELEASE;
            $this->{SHORTDESCRIPTION} = $SHORTDESCRIPTION || '';
        }
    }

    # where data files live
    $this->{data_systemdir} =
      'data/' . ( ( $targetProject eq 'TWiki' ) ? 'TWiki' : 'System' );

    # the root of the name of data files
    $this->{topic_root} = $this->{data_systemdir} . '/' . $this->{project};

    ##############################################################
    # Read the manifest

    my $manifest = findRelative( $buildpldir, 'MANIFEST' );
    if ( !defined($manifest) ) {

        #the core MANIFEST is in the lib dir, not the tools dir
        $manifest = findRelative( $libpath, 'MANIFEST' );
    }
    ( $this->{files}, $this->{other_modules}, $this->{options} ) =
      Foswiki::Contrib::BuildContrib::BaseBuild::readManifest( $this->{basedir},
        '', $manifest, sub { exit(1) } );

    # Generate a table representing the manifest contents
    # and a hash table representing the files
    my $mantable  = '';
    my $rawman    = '';
    my $hashtable = '';
    foreach my $file ( @{ $this->{files} } ) {
        $rawman .= join( ',',
            map { $file->{$_} || '' }
              qw{quotedName permissions md5 description} )
          . "\n";
        $mantable .=
            "   | =="
          . $file->{name} . '== | '
          . $file->{description} . ' |' . "\n";
        $hashtable .= "'$file->{name}'=>$file->{permissions},";
    }
    $this->{RAW_MANIFEST} = $rawman;
    $this->{MANIFEST}     = $mantable;
    $this->{FILES}        = $hashtable;

    ##############################################################
    # Work out the dependencies

    my $dependencies = findRelative( $buildpldir, 'DEPENDENCIES' );
    if ( !defined($dependencies) ) {

        #the core DEPENDENCIES is in the lib dir, not the tools dir
        $dependencies = findRelative( $libpath, 'DEPENDENCIES' );
    }
    $this->_loadDependenciesFrom($dependencies);

    # Pull in dependencies from other modules
    if ( $this->{other_modules} ) {
        foreach my $module ( @{ $this->{other_modules} } ) {
            try {
                my $depsfile =
                  findRelative( "$basedir/$module", 'DEPENDENCIES' );
                die 'Failed to find DEPENDENCIES for ' . $module
                  unless $depsfile && -f $depsfile;

                $this->_loadDependenciesFrom($depsfile);
            }
            catch Error with {
                warn "WARNING: no dependencies in $basedir/$module " . shift;
            };
        }
    }

    my $deptable = '';
    my $rawdeps  = '';
    my $a        = ' align="left"';
    foreach my $dep ( @{ $this->{dependencies} } ) {
        $rawdeps .=
"$dep->{name},$dep->{version},$dep->{trigger},$dep->{type},$dep->{description}\n";
        my $v = $dep->{version};
        $v =~ s/&/&amp;/go;
        $v =~ s/>/&gt;/go;
        $v =~ s/</&lt;/go;
        my $cells =
            CGI::td( { align => 'left' }, $dep->{name} )
          . CGI::td( { align => 'left' }, $v )
          . CGI::td( { align => 'left' }, $dep->{description} );
        $deptable .= CGI::Tr( {}, $cells );
    }
    $this->{RAW_DEPENDENCIES} = $rawdeps;
    $this->{DEPENDENCIES}     = 'None';
    if ($deptable) {
        my $cells =
            CGI::th( {}, 'Name' )
          . CGI::th( {}, 'Version' )
          . CGI::th( {}, 'Description' );
        $this->{DEPENDENCIES} = CGI::table(
            { border => 1, class => 'foswikiTable' },
            CGI::Tr( {}, $cells ) . $deptable
        );
    }

    # Get repo information.  If not in repo, returns today's date.
    #   $this->{DATE} is set to the full timestamp
    my $latestDate = $this->_get_repo_information();

    if ($badVersion) {
        my $proposed;
        if ( $this->{SVNREV} ) {
            use version 0.77;
            my $rev = sprintf( "%06d", $this->{SVNREV} );
            $proposed = version->parse("1.$rev")->normal()
              if $this->{SVNREV};
        }
        print STDERR <<ERROR;

\$VERSION string containing \$Date or \$Rev detected.
Keyword-based \$VERSION strings are no longer supported.
Please update to a real Perl version string.

ERROR
        print STDERR
"\n Suggested version: '$proposed' built from SVN Rev:$this->{SVNREV}\n"
          if $proposed;
        die "Build stopped:  SVN Rev's are not supported\n\n";
    }

    # If there is no RELEASE defined in the extension .pm
    # set the RELEASE = the date of last modification.
    if ( !$this->{RELEASE} ) {
        $this->{RELEASE} = $latestDate;
    }

    local $/ = undef;
    my $stage;
    foreach $stage ( 'PREINSTALL', 'POSTINSTALL', 'PREUNINSTALL',
        'POSTUNINSTALL' )
    {
        $this->{$stage} = '# No ' . $stage . ' script';
        my $file = findRelative( $buildpldir, $stage );
        if ( $file && open( PF, '<', $file ) ) {
            $this->{$stage} = "\n" . <PF>;
        }
    }

    $this->{MODULE} = $this->{project};

    local $/;
    $this->{INSTALL_INSTRUCTIONS} = <DATA>;

    # Item9416: Implements %$FOSWIKIAUTHORS%. Depends on $/ = undef
    $FOSWIKIAUTHORSFILE = $this->findRelative($FOSWIKIAUTHORSFILE);
    if ($FOSWIKIAUTHORSFILE) {
        open my $authorsfile, '<', $FOSWIKIAUTHORSFILE
          or die "Couldn't open $FOSWIKIAUTHORSFILE";
        $this->{FOSWIKIAUTHORS} = <$authorsfile>;
        close $authorsfile;
    }

    my $config = $this->_loadConfig();
    my $rep    = $config->{repositories}->{'default'};
    $rep = $config->{repositories}->{ $this->{project} }
      if defined $config->{repositories}->{ $this->{project} };
    if ($rep) {
        $this->{UPLOADTARGETPUB}    = $rep->{pub};
        $this->{UPLOADTARGETSCRIPT} = $rep->{script};
        $this->{UPLOADTARGETSUFFIX} = $rep->{suffix};
        $this->{UPLOADTARGETWEB}    = $rep->{web};
        $this->{DOWNTARGETSCRIPT}   = $rep->{downscript} || $rep->{script};
        $this->{DOWNTARGETSUFFIX}   = $rep->{downsuffix} || $rep->{suffix};
        $this->{DOWNTARGETWEB}      = $rep->{downweb} || $rep->{web};
    }
    else {
        $this->{UPLOADTARGETPUB} = $UPLOADSITEPUB
          unless defined $this->{UPLOADTARGETPUB};
        $this->{UPLOADTARGETSCRIPT} = $UPLOADSITESCRIPT
          unless defined $this->{UPLOADTARGETSCRIPT};
        $this->{UPLOADTARGETSUFFIX} = $UPLOADSITESUFFIX
          unless defined $this->{UPLOADTARGETSUFFIX};
        $this->{UPLOADTARGETWEB} = $UPLOADSITEEXTENSIONSWEB
          unless defined $this->{UPLOADTARGETWEB};

        $this->{DOWNTARGETSCRIPT} = $UPLOADSITESCRIPT
          unless defined $this->{DOWNTARGETSCRIPT};
        $this->{DOWNTARGETSUFFIX} = $UPLOADSITESUFFIX
          unless defined $this->{DOWNTARGETSUFFIX};
        $this->{DOWNTARGETWEB} = $UPLOADSITEEXTENSIONSWEB
          unless defined $this->{DOWNTARGETWEB};
    }

    return $this;
}

sub DESTROY {
    my $self = shift;
    File::Path::rmtree( $self->{tmpDir} )
      if $self->{tmpDir} && -d $self->{tmpDir};
}

# Load the config memory (passwords, repository locations etc)
sub _loadConfig {
    my $this = shift;

    use vars qw($VAR1);

    if ( !defined $this->{config} ) {

        #TODO: this really should be abstracted
        my $configLocation = $this
          ->{libdir}; #default to leave one in each contrib - used for windows atm
        $configLocation = $ENV{HOME} if ( defined( $ENV{HOME} ) );
        if ( -r "$configLocation/.buildcontrib" ) {
            do "$configLocation/.buildcontrib";
            $this->{config} = $VAR1;
            print "Loaded config from $this->{config}->{file}\n";
        }
        else {
        }
        unless ( $this->{config} ) {
            $this->{config} = {
                file         => "$configLocation/.buildcontrib",
                passwords    => {},
                repositories => {},
            };
        }
    }
    return $this->{config};
}

# Save the config
sub saveConfig {
    my $this = shift;
    if ( open( F, '>', $this->{config}->{file} ) ) {
        print F Data::Dumper->Dump( [ $this->{config} ] );
        close(F);
        print "Config saved in $this->{config}->{file}\n";
    }
    else {
        warn "Could not write $this->{config}->{file}: $!";
    }
}

sub _addDependency {
    my $this     = shift;
    my %dep      = @_;
    my @existing = grep { $_->{name} eq $dep{name} } @{ $this->{dependencies} };
    if ( scalar @existing ) {

        # SMELL: this is a crude merge of conditions, and probably not
        # correct in some cases, but it will have to do
        my $a = $existing[0]->{version};
        my $b = $dep{version};
        $a =~ s/[<>=]//g;
        $b =~ s/[<>=]//g;
        if ( $a =~ /^[0-9.]+$/ && $b =~ /^[0-9.]+$/ ) {
            if ( $a < $b ) {
                $existing[0]->{version} = $dep{version};
            }
            return;
        }
    }

    # New dependency
    push( @{ $this->{dependencies} }, \%dep );
}

sub _loadDependenciesFrom {
    my ( $this, $depsFile ) = @_;

    my $condition = 1;
    if ( -f $depsFile ) {
        open( PF, '<', $depsFile ) || die 'Failed to open ' . $depsFile;
        while ( my $line = <PF> ) {
            if ( $line =~ /^\s*$/ || $line =~ /^\s*#/ ) {
            }
            elsif ( $line =~ /^ONLYIF\s*(\(.*\))\s*$/ ) {
                $condition = $1;
            }
            elsif ( $line =~ m/^(\w+)\s+(\w*)\s*(.*)$/o ) {
                die "Badly formatted ONLYIF" if $1 eq 'ONLYIF';
                $this->_addDependency(
                    name        => $1,
                    type        => $2,
                    version     => '',
                    description => $3,
                    trigger     => $condition
                );
                $condition = 1;
            }
            elsif ( $line =~ m/^([^,]+),([^,]*),\s*(\w*)\s*,\s*(.+)$/o ) {
                $this->_addDependency(
                    name        => $1,
                    version     => $2,
                    type        => $3,
                    description => $4,
                    trigger     => $condition
                );
                $condition = 1;
            }
            else {
                warn 'WARNING: LINE ' . $line . ' IN ' . $depsFile . ' IGNORED';
            }
        }
    }
    else {
        warn 'WARNING: no '
          . $depsFile
          . '; dependencies will only be extracted from code';
    }
    close(PF);
}

# Search the current working directory and its parents
# for a directory called git
# Also checks if this directory contains a svn subdir
# which indicates the use of git-svn
sub _findPathToDotGitDir {
    my $this = shift;

    require File::Spec;
    require Cwd;
    my @dirlist = File::Spec->splitdir( Cwd::getcwd() );
    do {
        my $gitdir = File::Spec->catdir( @dirlist, ".git", "svn" );
        return wantarray ? ( $gitdir, 1 ) : $gitdir if -d $gitdir;
        $gitdir = File::Spec->catdir( @dirlist, ".git" );
        return $gitdir if -d $gitdir;
    } while ( pop @dirlist );
    return;
}

# SMELL: Would be good to change this to use SVN::Client, but Sven warns us
# that SVN::Client doesn't work in most places :-(. Maybe some day.
sub _get_repo_information {
    my $this = shift;

    my $max  = 0;    # max SVN rev no
    my $maxd = 0;    # max date

    #Shelling out with a large number of files dies, killing the build.
    my $idx = 0;
    while ( $idx < scalar( @{ $this->{files} } ) ) {
        my @files;
        my $limit = $idx + 1000;
        $limit = scalar( @{ $this->{files} } )
          if $limit > scalar( @{ $this->{files} } );
        while ( $idx < $limit ) {
            if ( ${ $this->{files} }[$idx]->{name} ) {
                my $file =
                  $this->{basedir} . '/' . ${ $this->{files} }[$idx]->{name};
                if ( -f $file ) {
                    push @files, $file;
                }
                elsif ( $file =~ /\/$/ )
                {    # Directory, create if it does not exist
                    File::Path::mkpath($file);
                }
                elsif ( !-d $file ) {    # Ignore directories
                    warn
                      "WARNING: $file is in MANIFEST, but it doesn't exist\n";
                }
            }
            $idx++;
        }

        # Get revision info all the files in the manifest
        # To find the latest one
        unless (
            eval {
                local $SIG{__DIE__};
                my @command;
                if ( -d ".svn" ) {
                    @command = qw(svn info);
                    my $log = $this->sys_action( @command, @files );
                    my $getDate = 0;
                    foreach my $line ( split( "\n", $log ) ) {
                        if ( $line =~ /^Last Changed Rev: (\d+)/ ) {
                            $getDate = 0;
                            if ( $1 > $max ) {
                                $max     = $1;
                                $getDate = 1;
                            }
                        }
                        elsif ($getDate
                            && $line =~
/(?:^Text Last Updated|Last Changed Date): ([\d-]+) ([\d:]+) ([-+\d]+)?/m
                          )
                        {
                            $maxd = Foswiki::Time::parseTime(
                                "$1T$2" . ( $3 || '' ) );
                            $getDate = 0;
                        }
                    }
                }
                elsif ( my ( $gitdir, $gitsvn ) =
                    $this->_findPathToDotGitDir() )
                {
                    @command = qw(git log -1 --pretty=medium --date=iso --);
                    my $log = $this->sys_action( @command, @files );
                    if ( $log =~ /^\s+git-svn-id: \S+\@(\d+)\s/m ) {
                        $max = $1 if $1 > $max;
                    }
                    else {
                        die 'You have un-published changes.'
                          . ' Please "git svn dcommit"';
                    }
                    if ( $log =~ /^Date:\s+([\d-]+) ([\d:]+) ([-+\d]+)?/m ) {
                        $maxd = Foswiki::Time::parseTime("$1T$2$3");
                    }
                }
                else {
                    die "Cannot find a proper command to search history.";
                }
                1;
            }
          )
        {

            # This is commented out because it's annoying
            # when auto-porting extensions
            # warn "WARNING: $@";
            $maxd = time() unless $maxd;
            $this->{SVNREV} = $max if defined $max;

            # People shouldn't test $@ for that reason, but they do...
            $@ = undef;
        }
    }

    $this->{DATE} = Foswiki::Time::formatTime( $maxd, '$iso', 'gmtime' );

    # If not checked in, or we can't get to SVN, use the current time.
    $this->{DATE} ||= Foswiki::Time::formatTime( time(), '$iso', 'gmtime' );

    my $day = $this->{DATE};
    $day =~ s/T.*//;

    return $day;
}

# Filter a file from source to dest, calling $this->$sub on the text
sub filter_file {
    my ( $this, $from, $to, $sub ) = @_;
    my $fh;
    open( $fh, '<', $from ) || die 'No source topic ' . $from . ' for filter';
    local $/ = undef;
    my $text = <$fh>;
    $text = $this->$sub($text) unless $from =~ /Dependency.pm$/;
    close($fh);

    unless ( $this->{-n} ) {
        my ( $v, $d, $f ) = File::Spec->splitpath($to);
        $this->makepath( File::Spec->catpath( $v, $d, '' ) );
        open( $fh, '>', $to )
          || die 'Bad dest topic ' . $to . ' for filter:' . $!;
        print $fh $text;
        close($fh);
    }
}

sub ask {
    my ( $q, $default ) = @_;
    my $reply;
    local $/ = "\n";

    $q .= '?' unless $q =~ /\?\s*$/;

    my $yorn = 'y/n';
    if ( defined $default ) {
        if ( $default =~ /y/i ) {
            $default = 'yes';
            $yorn    = 'Y/n';
        }
        elsif ( $default =~ /n/i ) {
            $default = 'no';
            $yorn    = 'y/N';
        }
        else {
            $default = undef;
        }
    }
    print $q. ' [' . $yorn . '] ';

    while ( ( $reply = <STDIN> ) !~ /^[yn]/i ) {
        if ( $reply =~ /^\s*$/ && defined($default) ) {
            $reply = $default;
            last;
        }
        print "Please answer yes or no\n";
    }
    return ( $reply =~ /^y/i ) ? 1 : 0;
}

sub prompt {
    my ( $q, $default ) = @_;
    local $/ = "\n";
    my $reply = '';
    while ( !$reply ) {
        print $q;
        print " ($default)" if defined $default;
        print ': ';
        $reply = <STDIN>;
        chomp($reply);
        $reply ||= $default;
    }
    return $reply;
}

=begin TML

---++++ pushd($dir)
  Change to the given directory

=cut

sub pushd {
    my ( $this, $file ) = @_;

    if ( $this->{-v} || $this->{-n} ) {
        print 'pushd ' . $file . "\n";
    }
    if ( !$this->{-n} ) {
        push( @{ $this->{dirStack} }, Cwd::cwd() );
        chdir($file) || die 'Failed to pushd to ' . $file;
    }
}

=begin TML

---++++ popd()
  Pop a dir level, previously pushed by pushd

=cut

sub popd {
    my $this = shift;

    die unless scalar( @{ $this->{dirStack} } );

    my $dir = pop( @{ $this->{dirStack} } );
    if ( $this->{-v} || $this->{-n} ) {
        print 'popd ' . $dir . "\n";
    }
    if ( !$this->{-n} ) {
        chdir($dir) || die 'Failed to popd to ' . $dir;
    }
}

=begin TML

---++++ rm($file)
Remove the given file (or directory)

=cut

sub rm {
    my ( $this, $file ) = @_;

    if ( $this->{-v} || $this->{-n} ) {
        print 'rm ' . $file . "\n";
    }
    if ( -e $file && !$this->{-n} ) {
        if ( -d $file ) {
            File::Path::rmtree($file);
        }
        else {
            unlink($file) || warn 'WARNING: Failed to delete ' . $file;
        }
    }
}

=begin TML

---++++ makepath($to)
Make a directory and all directories leading to it.

=cut

sub makepath {
    my ( $this, $to ) = @_;

    File::Path::mkpath( $to, { verbose => $this->{-v} } );
}

=begin TML

---++++ cp($from, $to)
Copy a single file from - to. Will automatically make intervening
directories in the target. Also works for target directories.

=cut

sub cp {
    my ( $this, $from, $to ) = @_;

    die 'Source file ' . $from . ' does not exist '
      unless ( $this->{-n} || -e $from );

    my $mum = $to;
    my ( $v, $d, $f ) = File::Spec->splitpath($to);
    $this->makepath( File::Spec->catpath( $v, $d, '' ) );

    if ( $this->{-v} || $this->{-n} ) {
        print 'cp ' . $from . ' ' . $to . "\n";
    }
    unless ( $this->{-n} ) {
        if ( -l $from ) {
            my $link = readlink($from);
            symlink( $link, $to )
              || warn "Warning: Failed to create link from $to to $link: $!";
        }
        elsif ( -d $from ) {
            unless ( -e $to ) {
                mkdir($to) || warn 'Warning: Failed to make ' . $to . ': ' . $!;
            }
        }
        else {
            File::Copy::copy( $from, $to )
              || warn 'Warning: Failed to copy '
              . $from . ' to '
              . $to . ': '
              . $!;
        }
    }
}

=begin TML

---++++ prot($perms, $file)
Set permissions on a file. Permissions should be expressed using POSIX
chmod notation.

=cut

sub prot {
    my ( $this, $perms, $file ) = @_;
    if ( !-d $file ) {    #skip directories
        $this->perl_action("chmod($perms,'$file')");
    }
}

=begin TML

---++++ sys_action(@params)
Perform a "system" command.

=cut

sub sys_action {
    my $this = shift;

    # use double-quotes to protect string with spaces, because they
    # work in both bash and DOS. Other shell metacharacters are fed
    # to the shell.
    my $cmd = join( ' ', map { /\s/ ? "\"$_\"" : $_ } @_ );

    if ( $this->{-v} || $this->{-n} ) {
        print "Running: $cmd\n";
    }
    return '' if ( $this->{-n} );
    my $output = `$cmd`;
    die 'Failed to ' . $cmd . ': ' . ( $? >> 8 ) if $? >> 8;
    return $output;
}

=begin TML

---++++ perl_action($cmd)
Perform a "perl" command.

=cut

sub perl_action {
    my ( $this, $cmd ) = @_;

    if ( $this->{-v} || $this->{-n} ) {
        print $cmd. "\n";
    }
    unless ( $this->{-n} ) {
        eval $cmd;
        die 'Failed to ' . $cmd . ': ' . $@ if ($@);
    }
}

=begin TML

---++++ filter_txt
Expands tokens.

The filter is used in the generation of documentation topics and the installer

=cut

sub filter_txt {
    my ( $this, $from, $to ) = @_;

    $this->filter_file(
        $from, $to,
        sub {
            my ( $this, $text ) = @_;

# Replace the version (SVN Rev or wrongly saved number) with rev 1.
# Item10629: Must preserve version for CompareRevisionAddOnDemoTopic, or nothing to demo
            $text =~ s/^(%META:TOPICINFO{.*version=").*?(".*}%)$/${1}1$2/m
              unless $from =~ m/CompareRevisionsAddOnDemoTopic.txt$/;
            $text =~ s/%\$(\w+)%/&_expand($this,$1)/geo;
            return $text;
        }
    );
}

sub _expand {
    my ( $this, $tok ) = @_;
    if ( !$this->{$tok} && $tok eq 'POD' ) {
        $this->build('POD');
    }
    if ( defined( $this->{$tok} ) ) {
        if ( $this->{-v} || $this->{-n} ) {
            print 'expand %$' . $tok . '% to ' . $this->{$tok} . "\n";
        }
        return $this->{$tok};
    }
    else {
        return '%$' . $tok . '%';
    }
}

=begin TML

---++++ filter_pm($from, $to)
Filters expanding SVN rev number with correct version from repository
Note: unlike subversion, this puts in the version number of the whole
repository, not just this file.

=cut

sub filter_pm {
    my ( $this, $from, $to ) = @_;
    $this->filter_file(
        $from, $to,
        sub {
            my ( $this, $text ) = @_;
            $text =~ s/\$Rev(:\s*\d+)?\s*\$/\$Rev\: $this->{VERSION} \$/gso;
            return $text;
        }
    );
}

=begin TML

---++++ copy_fileset
Copy all files in a file set from on directory root to another.

=cut

sub copy_fileset {
    my ( $this, $set, $from, $to ) = @_;

    my $uncopied = scalar(@$set);
    if ( $this->{-v} || $this->{-n} ) {
        print 'Copying ' . $uncopied . ' files to ' . $to . "\n";
    }
    foreach my $file (@$set) {
        my $name = $file->{name};
        if ( !-e $from . '/' . $name ) {
            die $from . '/' . $name . ' does not exist';
        }
        else {
            $this->cp( $from . '/' . $name, $to . '/' . $name );
            $uncopied--;
        }
    }
    die 'Files left uncopied' if ($uncopied);
}

=begin TML

---++++ apply_perms
Apply perms to a fileset

=cut

sub apply_perms {
    my ( $this, $set, $to ) = @_;

    foreach my $file (@$set) {
        my $name = $file->{name};
        if ( defined $file->{permissions} ) {
            $this->prot( $file->{permissions}, $to . '/' . $name );
        }
    }
}

sub getTopicName {
    my $this      = shift;
    my $topicname = $this->{project};

    # Example input:  Foswiki-4.0.0-beta6
    # Example output: FoswikiRelease04x00x00beta06

    if ( $topicname =~ m{\d+\.\d+\.\d+} ) {

        # Append 'Release' to first (word) part of name if followed by -
        $topicname =~ s/^(\w+)\-/${1}Release/;

        # Zero-pad numbers to two digits
        $topicname =~ s/(\d+)/sprintf("%0.2i",$1)/ge;

        # replace . with x
        $topicname =~ s/\./x/g;
    }

    # remove dashes
    $topicname =~ s/\-//g;
    return $topicname;
}

=begin TML

---++++ target_build
Basic build target. All other build targets are implemented in the
'Targets' subdirectory in individual modules.

=cut

sub target_build {
    my $this = shift;
}

=begin TML

---++++ target_pod

Print POD documentation. This target does not modify any files, it simply
prints the (TML format) POD.

POD text in =.pm= files should use TML syntax or HTML. Packages should be
introduced with a level 1 header, ---+, and each method in the package by
a level 2 header, ---++. Make sure you document any global variables used
by the module.

=cut

# Defined here to work around naming clash on case-insensitive file systems
sub target_pod {
    my $this = shift;
    $this->build('POD');
    print $this->{POD} . "\n";
}

=begin TML

---++++ build($target)
Build the given target

=cut

sub build {
    my $this   = shift;
    my $target = shift;

    if ( $this->{-v} ) {
        print 'Building ', $target, "\n";
    }
    my $fn = "target_$target";
    unless ( $this->can($fn) ) {
        my $file = 'Foswiki/Contrib/BuildContrib/Targets/' . $target . '.pm';
        unless ( do $file ) {
            if ($@) {
                die 'Failed to compile target ', $target, ': ', $@;
            }
            else {
                die 'Failed to load target ', $target, ': ', $!;
            }
        }
    }
    $this->$fn();
    if ($@) {
        die 'Failed to build ', $target, ': ', $@;
    }
    if ( $this->{-v} ) {
        print 'Built ', $target, "\n";
    }
}

1;
__DATA__
You do not need to install anything in the browser to use this extension. The following instructions are for the administrator who installs the extension on the server.

Open configure, and open the "Extensions" section. Use "Find More Extensions" to get a list of available extensions. Select "Install".

If you have any problems, or if the extension isn't available in =configure=, then you can still install manually from the command-line. See http://foswiki.org/Support/ManuallyInstallingExtensions for more help.
