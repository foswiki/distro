#
# Copyright (C) 2004 C-Dot Consultants - All rights reserved
# Copyright (C) 2008-2010 Foswiki Contributors
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

our $basedir;
our $buildpldir;
our $libpath;

my $VERSION;
my $RELEASE;

my $UPLOADSITEPUB           = 'http://foswiki.org/pub';
my $UPLOADSITESCRIPT        = 'http://foswiki.org/bin';
my $UPLOADSITESUFFIX        = '';
my $UPLOADSITEBUGS          = 'http://foswiki.org/Tasks';
my $UPLOADSITEEXTENSIONSWEB = "Extensions";
my $DEFAULTCUSTOMERDB       = "$ENV{HOME}/customerDB";
my $FOSWIKIAUTHORSFILE      = 'core/AUTHORS';

my $GLACIERMELT = 10;    # number of seconds to sleep between uploads,
                         # to reduce average load on server
my $lastUpload  = 0;     # time of last upload (0 means none yet)

my $targetProject;       # Foswiki or TWiki

my $collector;           # general purpose handle for collecting stuff

my %minifiers;           # functions used to minify

# use diagnostics;
# use Carp ();
# $SIG{__DIE__} = sub { Carp::confess $_[0] };

my @stageFilters = (
    { RE => qr/\.txt$/, filter => 'filter_txt' },
    { RE => qr/\.pm$/,  filter => 'filter_pm' },
);

my @compressFilters = (
    { RE => qr/\.js$/,  filter => 'build_js' },
    { RE => qr/\.css$/, filter => 'build_css' },
    { RE => qr/\.gz$/,  filter => 'build_gz' },
);

my @tidyFilters = ( { RE => qr/\.pl$/ }, { RE => qr/\.pm$/ }, );

$ENV{'LC_ALL'} = 'C';

sub _findRelativeTo {
    my ( $startdir, $name ) = @_;

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

    if ( -e "$buildpldir/../../../Foswiki" ) {
        $libpath = _findRelativeTo( $buildpldir, 'lib/Foswiki' );
        $targetProject = 'Foswiki';
    }
    else {
        warn "Assuming this is a TWiki project\n";
        $libpath = _findRelativeTo( $buildpldir, 'lib/TWiki' );
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

    # Get $VERSION, $RELEASE and $SHORTDESCRIPTION
    if ( -e $this->{pm} ) {
        my $fh;
        if ( open( $fh, "<", $this->{pm} ) ) {
            local $/;
            my $text = <$fh>;
            close $fh;
            if ( $text =~ /\$RELEASE\s*=\s*(['"])(.*?)\1/s ) {
                $this->{RELEASE} = $2;
            }

            # If an extension has a .pm file with same name as
            # the extension we will set the VERSION to be
            # the SVN checkin number and date of this checkin
            # For this we populate $this->{files} with this one filename
            # Note we do not actually use the VERSION text from the .pm file
            # Instead you update the RELEASE text which will cause SVN
            # to update the SVN number and check in date when you commit
            # The commit then updates the RELEASE in the .pm file
            $this->{files}[0]->{name} = $this->{pm};
            $this->{files}[0]->{name} =~ s/^$basedir\/(.*)/$1/;
            $this->{VERSION} = $this->_get_svn_version();

            if ( $text =~ /\$SHORTDESCRIPTION\s*=\s*(['"])(.*?)\1/s ) {
                $this->{SHORTDESCRIPTION} = $2;
            }
        }
    }

    # where data files live
    $this->{data_systemdir} =
      'data/' . ( ( $targetProject eq 'TWiki' ) ? 'TWiki' : 'System' );

    # the root of the name of data files
    $this->{topic_root} = $this->{data_systemdir} . '/' . $this->{project};

    ##############################################################
    # Read the manifest

    my $manifest = _findRelativeTo( $buildpldir, 'MANIFEST' );
    if ( !defined($manifest) ) {

        #the core MANIFEST is in the lib dir, not the tools dir
        $manifest = _findRelativeTo( $libpath, 'MANIFEST' );
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
        $rawman .= "$file->{name},$file->{permissions},$file->{description}\n";
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

    my $dependancies = _findRelativeTo( $buildpldir, 'DEPENDENCIES' );
    if ( !defined($dependancies) ) {

        #the core DEPENDENCIES is in the lib dir, not the tools dir
        $dependancies = _findRelativeTo( $libpath, 'DEPENDENCIES' );
    }
    $this->_loadDependenciesFrom($dependancies);

    # Pull in dependencies from other modules
    if ( $this->{other_modules} ) {
        foreach my $module ( @{ $this->{other_modules} } ) {
            try {
                my $depsfile =
                  _findRelativeTo( "$basedir/$module", 'DEPENDENCIES' );
                die 'Failed to find DEPENDENCIES for ' . $module
                  unless $depsfile && -f $depsfile;

                $this->_loadDependenciesFrom($depsfile);
            }
            catch Error::Simple with {
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

    $this->{VERSION} = $this->_get_svn_version() unless $this->{VERSION};

    # If there is no RELEASE defined in the extension .pm
    # set the RELEASE = the date part of VERSION
    if ( !$this->{RELEASE} && $this->{VERSION} ) {
        $this->{VERSION} =~ /^(\d+)\s*\((.*?)\)\s*$/;
        $this->{RELEASE} = $2;
    }

    # If not checked in, or we can't get to SVN, use the current time.
    $this->{DATE} ||= Foswiki::Time::formatTime( time(), '$iso', 'gmtime' );

    local $/ = undef;
    my $stage;
    foreach $stage ( 'PREINSTALL', 'POSTINSTALL', 'PREUNINSTALL',
        'POSTUNINSTALL' )
    {
        $this->{$stage} = '# No ' . $stage . ' script';
        my $file = _findRelativeTo( $buildpldir, $stage );
        if ( $file && open( PF, '<', $file ) ) {
            $this->{$stage} = "\n" . <PF>;
        }
    }

    $this->{MODULE} = $this->{project};

    local $/;
    $this->{INSTALL_INSTRUCTIONS} = <DATA>;

    # Item9416: Implements %$FOSWIKIAUTHORS%. Depends on $/ = undef
    $FOSWIKIAUTHORSFILE =
      _findRelativeTo( $this->{basedir}, $FOSWIKIAUTHORSFILE );
    if ($FOSWIKIAUTHORSFILE) {
        open my $authorsfile, '<', $FOSWIKIAUTHORSFILE
          or die "Couldn't open $FOSWIKIAUTHORSFILE";
        $this->{FOSWIKIAUTHORS} = <$authorsfile>;
        close $authorsfile;
    }

    my $config = $this->_loadConfig();
    my $rep    = $config->{repositories}->{ $this->{project} };
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
sub _saveConfig {
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
sub _get_svn_version {
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
            $max = Foswiki::Time::formatTime( $maxd, '$year$mo$day', 'gmtime' )
              unless $max;

            # People shouldn't test $@ for that reason, but they do...
            $@ = undef;
        }
    }

    $this->{DATE} = Foswiki::Time::formatTime( $maxd, '$iso', 'gmtime' );
    my $day = $this->{DATE};
    $day =~ s/T.*//;
    $this->{VERSION} = "$max ($day)";

    return $this->{VERSION};
}

# Filter a file from source to dest, calling $this->$sub on the text
sub _filter_file {
    my ( $this, $from, $to, $sub ) = @_;
    my $fh;
    open( $fh, '<', $from ) || die 'No source topic ' . $from . ' for filter';
    local $/ = undef;
    my $text = <$fh>;
    $text = $this->$sub($text);
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
        if ( -d $from ) {
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

---++++ target_build
Basic build target.

=cut

sub target_build {
    my $this = shift;
}

=begin TML

---++++ target_compress
Compress Javascript and CSS files. This target is "best efforts" - the build
won't fail if a source or target isn't missing.

=cut

sub target_compress {
    my $this = shift;
    my %file_ok;
    foreach my $filter (@compressFilters) {
      FILE:
        foreach my $file ( @{ $this->{files} } ) {
            next FILE if $file_ok{$file};

            # Find files that match the build filter and try to update
            # them
            if ( $file->{name} =~ /$filter->{RE}/ ) {
                my $fn = $filter->{filter};
                $file_ok{$file} =
                  $this->$fn( $this->{basedir} . '/' . $file->{name} );
            }
        }
    }
}

=begin TML

---++++ target_tidy
Reformat .pm and .pl files using perltidy default options

=cut

sub target_tidy {
    my $this = shift;
    require Perl::Tidy;    # Will throw exception if not available

    # Can't use the MANIFEST list, otherwise we miss tests etc, so apply
    # to all files found under lib.
    require File::Find;
    my @files = ();
    $collector = \@files;
    File::Find::find( \&_isPerl, "$this->{basedir}" );

    foreach my $path (@files) {
        print "Tidying $path\n";
        local @ARGV = ($path);
        Perl::Tidy::perltidy();
        File::Copy::move( "$path.tdy", $path );
    }
}

sub _isPerl {
    if ( $File::Find::name =~ /(CVS|\.svn|\.git|~)$/ ) {
        $File::Find::prune = 1;
    }
    elsif ( !-d $File::Find::name ) {
        if ( $File::Find::name =~ /\.p[lm]$/ ) {
            push( @$collector, $File::Find::name );
        }
        elsif ( $File::Find::name !~ m#\.[^/]+$#
            && open( F, '<', $File::Find::name ) )
        {
            local $/ = "\n";
            my $shebang = <F>;
            close(F);
            if ( $shebang && $shebang =~ /^#!.*perl/ ) {
                push( @$collector, $File::Find::name );
            }
        }
    }
}

=begin TML

---++++ target_test
Basic CPAN:Test::Unit test target, runs <project>Suite.

=cut

sub target_test {
    my $this = shift;
    $this->build('build');

    # find testrunner
    my $testrunner =
         _findRelativeTo( $this->{basedir}, 'core/test/bin/TestRunner.pl' )
      || _findRelativeTo( $this->{basedir}, 'test/bin/TestRunner.pl' );

    my $tests =
      _findRelativeTo( $this->{basedir},
        'test/unit/' . $this->{project} . '/' . $this->{project} . 'Suite.pm' );
    unless ($tests) {
        $tests =
          _findRelativeTo( $this->{basedir},
            '/core/test/unit/' . $this->{project} . 'Suite.pm' )
          || _findRelativeTo( $this->{basedir},
            '/test/unit/' . $this->{project} . 'Suite.pm' );
        unless ($tests) {
            warn 'WARNING: COULD NOT FIND ANY UNIT TESTS FOR '
              . $this->{project};
            return;
        }
    }
    unless ($testrunner) {
        warn <<MESSY;
WARNING: CANNOT RUN TESTS; TestRunner.pl not found.
Did you remember to install UnitTestContrib?
MESSY
        return;
    }
    my @inc = map { ( '-I', $_ ) } @INC;
    my $testdir = $tests;
    $testdir =~ s/\/[^\/]*$//;
    print "Running tests in $tests\n";
    $this->pushd($testdir);
    $this->{-v} = 1;    # to get the command printed
    $this->sys_action( 'perl', '-w', @inc, $testrunner, $tests );
    $this->popd();
}

=begin TML

---++++ filter_txt
Expands tokens.

The filter is used in the generation of documentation topics and the installer

=cut

sub filter_txt {
    my ( $this, $from, $to ) = @_;

    $this->_filter_file(
        $from, $to,
        sub {
            my ( $this, $text ) = @_;

            # Replace the version (SVN Rev or wrongly saved number) with rev 1.
            $text =~ s/^(%META:TOPICINFO{.*version=").*?(".*}%)$/${1}1$2/m;
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

# Guess the name mapping for .js or .css
sub _deduceCompressibleSrc {
    my ( $this, $to, $ext ) = @_;
    my $from;

    if ( $to =~ /^(.*)\.compressed\.$ext$/ ) {
        if ( -e "$1.uncompressed.$ext" ) {
            $from = "$1.uncompressed.$ext";
        }
        elsif ( -e "$1_src\.$ext" ) {
            $from = "$1_src.$ext";
        }
        else {
            $from = "$1.$ext";
        }
    }
    elsif ( $to =~ /^(.*)\.$ext$/ ) {
        if ( -e "$1.uncompressed.$ext" ) {
            $from = "$1.uncompressed.$ext";
        }
        else {
            $from = "$1_src.$ext";
        }
    }
    return $from;
}

# helper functions for calling minifiers
sub _cpanMinify {
    my ( $this, $from, $to, $fn ) = @_;
    my $f;
    open( $f, '<', $from ) || die $!;
    local $/ = undef;
    my $text = <$f>;
    close($f);

    $text = &$fn($text);

    if ( open( $f, '<', $to ) ) {
        my $ot = <$f>;
        close($f);
        if ( $text eq $ot ) {

            #warn "$to is up to date w.r.t $from\n";
            return 1;    # no changes
        }
    }

    open( $f, '>', $to ) || die "$to: $!";
    print $f $text;
    close($f);
}

sub _yuiMinify {
    my ( $this, $from, $to, $type, $cmdtype ) = @_;
    my $lcall = $ENV{'LC_ALL'};
    my $cmd;

    if ( $cmdtype == 2 ) {
        $cmd = "java -jar $basedir/tools/yuicompressor.jar --type $type $from";
    }
    else {
        $cmd = "yui-compressor --type $type $from";
    }
    unless ( $this->{-n} ) {
        $cmd .= " -o $to";
    }

    #warn "$cmd\n";
    my $out = `$cmd`;
    $ENV{'LC_ALL'} = $lcall;
    return $out;
}

=begin TML

---++++ _haveYUI
return 1 if we have YUI as a command yui-compressor
return 2 if we have YUI as a jar file in tools

=cut

sub _haveYUI {
    my $info   = `yui-compressor -h 2>&1`;
    my $result = 0;

    if ( not $? ) {
        $result = 1;
    }
    elsif ( -e "$basedir/tools/yuicompressor.jar" ) {

        # Do we have java?
        $info = `java -version 2>&1` || '';
        if ( not $? ) {
            $result = 2;
        }
    }

    return $result;
}

=begin TML

---++++ build_js
Uses JavaScript::Minifier to optimise javascripts

Several different name mappings are supported:
   * XXX.uncompressed.js -> XXX.js
   * XXX_src.js -> XXX.js
   * XXX.uncompressed.js -> XXX.compressed.js

These are selected between depending on which exist on disk.

=cut

sub build_js {
    my ( $this, $to ) = @_;

    if ( !$minifiers{js} ) {
        my $yui = _haveYUI();

        if ($yui) {
            $minifiers{js} = sub {
                return $this->_yuiMinify( @_, 'js', $yui );
            };
        }
    }

    # If no good, try the CPAN minifiers
    if ( !$minifiers{js} && eval { require JavaScript::Minifier::XS; 1 } ) {
        $minifiers{js} = sub {
            return $this->_cpanMinify( @_, \&JavaScript::Minifier::XS::minify );
        };
    }
    if ( !$minifiers{js} && eval { require JavaScript::Minifier; 1 } ) {
        $minifiers{js} = sub {
            return $this->_cpanMinify(
                @_,
                sub {
                    JavaScript::Minifier::minify( input => $_[0] );
                }
            );
        };
    }
    if ( !$minifiers{js} ) {
        warn "Cannot squish $to: no minifier found\n";
        return;
    }

    return $this->_build_compress( 'js', $to );
}

=begin TML

---++++ build_css
Uses CSS::Minifier to optimise CSS files

Several different name mappings are supported:
   * XXX.uncompressed.css -> XXX.css
   * XXX_src.css -> XXX.css
   * XXX.uncompressed.css -> XXX.compressed.css

=cut

sub build_css {
    my ( $this, $to ) = @_;

    if ( !$minifiers{css} ) {
        my $yui = _haveYUI();

        if ($yui) {
            $minifiers{css} = sub {
                return $this->_yuiMinify( @_, 'css', $yui );
            };
        }
    }
    if ( !$minifiers{css} && eval { require CSS::Minifier::XS; 1 } ) {
        $minifiers{css} = sub {
            return $this->_cpanMinify( @_, \&CSS::Minifier::XS::minify );
        };
    }
    if ( !$minifiers{css} && eval { require CSS::Minifier; 1 } ) {
        $minifiers{css} = sub {
            $this->_cpanMinify(
                @_,
                sub {
                    CSS::Minifier::minify( input => $_[0] );
                }
            );
        };
    }

    return $this->_build_compress( 'css', $to );
}

sub _needsBuilding {
    my ( $from, $to ) = @_;

    if ( -e $to ) {
        my @fstat = stat($from);
        my @tstat = stat($to);
        return 0 if ( $tstat[9] >= $fstat[9] );
    }
    return 1;
}

sub _build_compress {
    my ( $this, $type, $to ) = @_;

    if ( !$minifiers{$type} ) {
        warn "Cannot squish $to: no minifier found for $type\n";
        return;
    }

    my $from = $this->_deduceCompressibleSrc( $to, $type );
    unless ( -e $from ) {

        # There may be a good reason there is no minification source;
        # for example, it might not be a derived object.
        #warn "Minification source for $to not found\n";
        return;
    }
    if ( -l $to ) {

        # BuildContrib will always override links created by pseudo-install
        unlink($to);
    }
    unless ( _needsBuilding( $from, $to ) ) {
        if ( $this->{-v} || $this->{-n} ) {
            warn "$to is up-to-date\n";
        }
        return;
    }

    if ( !$this->{-n} ) {
        &{ $minifiers{$type} }( $from, $to );
        warn "Generated $to from $from\n";
    }
    else {
        warn "Minify $from to $to\n";
    }
}

=begin TML

---++++ build_gz
Uses Compress::Zlib to gzip files

   * xxx.yyy -> xxx.yyy.gz

=cut

sub build_gz {
    my ( $this, $to ) = @_;

    unless ( eval { require Compress::Zlib } ) {
        warn "Cannot gzip: $@\n";
        return 0;
    }

    my $from = $to;
    $from =~ s/\.gz$// or return 0;
    return 0 unless -e $from && _needsBuilding( $from, $to );

    if ( -l $to ) {

        # BuildContrib will always override links created by pseudo-install
        unlink($to);
    }

    my $f;
    open( $f, '<', $from ) || die $!;
    local $/ = undef;
    my $text = <$f>;
    close($f);

    $text = Compress::Zlib::memGzip($text);

    unless ( $this->{-n} ) {
        my $f;
        open( $f, '>', $to ) || die "$to: $!";
        binmode $f;
        print $f $text;
        close($f);
        warn "Generated $to from $from\n";
    }
    return 1;
}

=begin TML

---++++ filter_pm($from, $to)
Filters expanding SVN rev number with correct version from repository
Note: unlike subversion, this puts in the version number of the whole
repository, not just this file.

=cut

sub filter_pm {
    my ( $this, $from, $to ) = @_;
    $this->_filter_file(
        $from, $to,
        sub {
            my ( $this, $text ) = @_;
            $text =~ s/\$Rev(:\s*\d+)?\s*\$/\$Rev\: $this->{VERSION} \$/gso;
            return $text;
        }
    );
}

=begin TML

---++++ target_release
Release target, builds release zip by creating a full release directory
structure in /tmp and then zipping it in one go. Only files explicitly listed
in the MANIFEST are released. Automatically runs =filter= on all =.txt= files
in the MANIFEST.

=cut

sub target_release {
    my $this = shift;

    print <<GUNK;

Building release $this->{RELEASE} of $this->{project}, from version $this->{VERSION}
GUNK
    if ( $this->{-v} ) {
        print 'Package name will be ', $this->{project}, "\n";
        print 'Topic name will be ', $this->_getTopicName(), "\n";
    }

    $this->build('compress');
    $this->build('build');
    $this->build('installer');
    $this->build('stage');
    $this->build('archive');
}

sub filter_tracked_pm {
    my ( $this, $from, $to ) = @_;
    $this->_filter_file(
        $from, $to,
        sub {
            my ( $this, $text ) = @_;
            $text =~ s/%\$TRACKINGCODE%/$this->{TRACKINGCODE}/gm;
            return $text;
        }
    );
}

sub target_tracked {
    my $this = shift;
    local $/ = "\n";
    my %customers;
    my @cuss;
    my $db = prompt( "Location of customer database", $DEFAULTCUSTOMERDB );
    if ( open( F, '<', $db ) ) {
        while ( my $customer = <F> ) {
            chomp($customer);
            if ( $customer =~ /^(.+)\s(\S+)\s*$/ ) {
                $customers{$1} = $2;
            }
        }
        close(F);
        @cuss = sort keys %customers;
        my $i = 0;
        print join( "\n", map { $i++; "$i. $_" } @cuss ) . "\n";
    }
    else {
        print "$db not found: $@\n";
        print "Creating new customer DB\n";
    }

    my $customer = prompt("Number (or name) of customer");
    if ( $customer =~ /^\d+$/ && $customer < scalar(@cuss) ) {
        $customer = $cuss[$customer];
    }

    if ( $customers{$customer} ) {
        $this->{TRACKINGCODE} = $customers{$customer};
    }
    else {
        print "Customer '$customer' not known\n";
        exit 0 unless ask("Would you like to add a new customer?");

        $this->{TRACKINGCODE} = crypt( $customer, $db );
        $this->{TRACKINGCODE} = join( '',
            map { sprintf( '%02X', $_ ) }
              unpack( 'c*', $this->{TRACKINGCODE} ) );
        print "New cypher is $this->{TRACKINGCODE}\n";
        $customers{$customer} = $this->{TRACKINGCODE};

        open( F, '>', $db ) || die $@;
        print F join( "\n", ) . "\n";
        close(F);
    }

    warn "Tracking code is $this->{TRACKINGCODE}\n";

    push( @stageFilters, { RE => qr/\.pm$/, filter => 'filter_tracked_pm' } );

    $this->build('release');
}

=begin TML

---++++ target_stage
stages all the files to be in the release in a tmpDir, ready for target_archive

=cut

sub target_stage {
    my $this    = shift;
    my $project = $this->{project};

    $this->{tmpDir} ||= File::Temp::tempdir( CLEANUP => 1 );
    File::Path::mkpath( $this->{tmpDir} );

    $this->copy_fileset( $this->{files}, $this->{basedir}, $this->{tmpDir} );

    foreach my $file ( @{ $this->{files} } ) {
        foreach my $filter (@stageFilters) {
            if ( $file->{name} =~ /$filter->{RE}/ ) {
                my $fn = $filter->{filter};
                $this->$fn(
                    $this->{basedir} . '/' . $file->{name},
                    $this->{tmpDir} . '/' . $file->{name}
                );
            }
        }
    }
    if ( -e $this->{tmpDir} . '/' . $this->{topic_root} . '.txt' ) {
        $this->cp(
            $this->{tmpDir} . '/' . $this->{topic_root} . '.txt',
            $this->{basedir} . '/' . $project . '.txt'
        );
    }
    $this->apply_perms( $this->{files}, $this->{tmpDir} );

    if ( $this->{other_modules} ) {
        my $libs = join( ':', @INC );
        foreach my $module ( @{ $this->{other_modules} } ) {

            die "$basedir / $module does not exist, cannot build $module\n"
              unless ( -e "$basedir/$module" );

            warn "Installing $module in $this->{tmpDir}\n";

            #SMELL: uses legacy TWIKI_ exports
            my $cmd =
"export FOSWIKI_HOME=$this->{tmpDir}; export FOSWIKI_LIBS=$libs; export TWIKI_HOME=$this->{tmpDir}; export TWIKI_LIBS=$libs; cd $basedir/$module; perl build.pl handsoff_install";

            #warn "***** running $cmd \n";
            print `$cmd`;
        }
    }
}

=begin TML

---++++ target_archive
Makes zip and tgz archives of the files in tmpDir. Also copies the installer.

=cut

sub target_archive {
    my $this    = shift;
    my $project = $this->{project};
    my $target  = $project;
    if ( defined $this->{options}->{archive_prefix} ) {

        # optional archive name prefix
        $target = "$this->{options}->{archive_prefix}$target";
    }

    die 'no tmpDir set'  unless defined( $this->{tmpDir} );
    die 'no project set' unless defined($project);
    die 'tmpDir (' . $this->{tmpDir} . ') not found'
      unless ( -e $this->{tmpDir} );

    $this->pushd( $this->{tmpDir} );

    $this->apply_perms( $this->{files}, $this->{tmpDir} );

    $this->sys_action( 'zip', '-r', '-q', $project . '.zip', '*' );
    $this->perl_action( 'File::Copy::move("' 
          . $project
          . '.zip", "'
          . $this->{basedir} . '/'
          . $target
          . '.zip");' );

# SMELL: sys_action will auto quote any parameter containing a space.  So the parameter
# and argument for group and user must be passed in as separate parameters.
    $this->sys_action( 'tar', '--owner', '0', '--group', '0', '-czhpf',
        $project . '.tgz', '*' );
    $this->perl_action( 'File::Copy::move("' 
          . $project
          . '.tgz", "'
          . $this->{basedir} . '/'
          . $target
          . '.tgz")' );

    $this->perl_action( 'File::Copy::move("'
          . $this->{tmpDir} . '/'
          . $project
          . '_installer","'
          . $this->{basedir} . '/'
          . $target
          . '_installer")' );

    $this->pushd( $this->{basedir} );
    my @fs;
    foreach my $f (qw(.tgz _installer .zip)) {
        push( @fs, "$target$f" ) if ( -e "$target$f" );
    }

    if ( eval { require Digest::MD5 } ) {
        open( CS, '>', "$target.md5" ) || die $!;
        foreach my $file (@fs) {
            open( F, '<', $file );
            local $/;
            my $data = <F>;
            close(F);
            my $cs = Digest::MD5::md5_hex($data);
            print CS "$cs  $file\n";
        }
        close(CS);
        print "MD5 checksums in $this->{basedir}/$target.md5\n";
    }
    else {
        warn
          "WARNING: Digest::MD5 not installed; cannot generate MD5 checksum\n";
    }

    if ( eval { require Digest::SHA } ) {
        open( CS, '>', "$target.sha1" ) || die $!;
        foreach my $file (@fs) {
            open( F, '<', $file );
            local $/;
            my $data = <F>;
            close(F);
            my $cs = Digest::SHA::sha1_hex($data);
            print CS "$cs  $file\n";
        }
        close(CS);
        print "SHA1 checksums in $this->{basedir}/$target.sha1\n";
    }
    else {
        warn
          "WARNING: Digest::SHA not installed; cannot generate SHA1 checksum\n";
    }

    $this->popd();
    $this->popd();

    my $warn = 0;
    foreach my $f (qw(.tgz .zip .txt _installer)) {
        if ( -e "$this->{basedir}/$target$f" ) {
            print "$f in $this->{basedir}/$target$f\n";
        }
        else {
            warn "WARNING: no $target$f was generated\n";
            $warn++;
        }
    }
    if ($warn) {
        warn <<HERE;
Some release files were not generated, either because there was
no matching source file, or because they were disabled by !option.
HERE
    }
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

=begin TML

---++++ target_handsoff_install
Install target, installs to local install pointed at by FOSWIKI_HOME.

Does not run the installer script.

=cut

sub target_handsoff_install {
    my $this = shift;
    $this->build('release');

    my $home = $ENV{FOSWIKI_HOME};
    die 'FOSWIKI_HOME not set' unless $home;
    $this->pushd($home);
    $this->sys_action( 'tar', 'zxpf',
        $this->{basedir} . '/' . $this->{project} . '.tgz' );

    # kill off the module installer
    $this->rm( $home . '/' . $this->{project} . '_installer' );
    $this->popd();
}

=begin TML

---++++ target_install
Install target, installs to local twiki pointed at by FOSWIKI_HOME.

Uses the installer script written by target_installer

=cut

sub target_install {
    my $this = shift;
    $this->build('handsoff_install');
    $this->sys_action( 'perl', $this->{project} . '_installer', 'install' );
}

=begin TML

---++++ target_uninstall
Uninstall target, uninstall from local twiki pointed at by FOSWIKI_HOME.

Uses the installer script written by target_installer

=cut

sub target_uninstall {
    my $this = shift;
    my $home = $ENV{FOSWIKI_HOME};
    die 'FOSWIKI_HOME not set' unless $home;
    $this->pushd($home);
    $this->sys_action( 'perl', $this->{project} . '_installer', 'uninstall' );
    $this->popd();
}

{

    package Foswiki::Contrib::Build::UserAgent;
    use LWP::UserAgent;
    our @ISA = qw( LWP::UserAgent );

    sub new {
        my ( $class, $id, $bldr ) = @_;
        my $this = $class->SUPER::new(
            keep_alive => 1,

            # Item721: Get proxy settings from environment variables
            env_proxy => 1
        );
        $this->{domain}  = $id;
        $this->{builder} = $bldr;
        require HTTP::Cookies;
        $this->cookie_jar(
            new HTTP::Cookies(
                file           => "$ENV{HOME}/.lwpcookies",
                autosave       => 1,
                ignore_discard => 1
            )
        );

        return $this;
    }

    sub get_basic_credentials {
        my ( $this, $realm, $uri ) = @_;
        return $this->{builder}->getCredentials( $uri->host() );
    }
}

sub getCredentials {
    my ( $this, $host ) = @_;
    my $config = $this->_loadConfig();
    my $pws    = $config->{passwords}->{$host};
    if ($pws) {
        print "Using credentials for $host saved in $config->{file}\n";
    }
    else {
        local $/ = "\n";
        print 'Enter username for ', $host, ': ';
        my $knownUser = <STDIN>;
        chomp($knownUser);
        die "Inadequate user" unless length $knownUser;
        print 'Password: ';
        system('stty -echo');
        my $knownPass = <STDIN>;
        system('stty echo');
        print "\n";    # because we disabled echo
        chomp($knownPass);
        $pws = { user => $knownUser, pass => $knownPass };
        $config->{passwords}->{$host} = $pws;
        $this->_saveConfig();
    }
    return ( $pws->{user}, $pws->{pass} );
}

sub _getTopicName {
    my $this      = shift;
    my $topicname = $this->{project};

    # Example input:  TWiki-4.0.0-beta6
    # Example output: TWikiRelease04x00x00beta06

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

---++++ target_upload
Upload to a repository. Prompts for username and password. Uploads the zip and
the text topic to the appropriate places. Creates the topic if
necessary.

=cut

sub target_upload {
    my $this = shift;

    unless ( eval { require LWP } ) {
        warn 'LWP is not installed; cannot upload', "\n";
        return 0;
    }

    my $to = $this->{project};

    while (1) {
        print <<END;
Preparing to upload to:
Web:     $this->{UPLOADTARGETWEB}
PubDir:  $this->{UPLOADTARGETPUB}
Scripts: $this->{UPLOADTARGETSCRIPT}
Suffix:  $this->{UPLOADTARGETSUFFIX}
 
If upload target does not exist, recover package form from:
Web:     $this->{DOWNTARGETWEB}
Scripts: $this->{DOWNTARGETSCRIPT}
Suffix:  $this->{DOWNTARGETSUFFIX}
END

        last if ask( "Is that correct? Answer 'n' to change", 1 );
        print "Enter the name of the web that contains the target repository\n";
        $this->{UPLOADTARGETWEB} = prompt( "Web", $this->{UPLOADTARGETWEB} );
        print "Enter the full URL path to the pub directory\n";
        $this->{UPLOADTARGETPUB} = prompt( "PubDir", $this->{UPLOADTARGETPUB} );
        print "Enter the full URL path to the bin directory\n";
        $this->{UPLOADTARGETSCRIPT} =
          prompt( "Scripts", $this->{UPLOADTARGETSCRIPT} );
        print
"Enter the file suffix used on scripts in the bin directory (enter 'none' for none)\n";
        $this->{UPLOADTARGETSUFFIX} =
          prompt( "Suffix", $this->{UPLOADTARGETSUFFIX} );
        $this->{UPLOADTARGETSUFFIX} = ''
          if $this->{UPLOADTARGETSUFFIX} eq 'none';
        print
"\nEnter the alternate name of the web that contains the package form\n";
        $this->{DOWNTARGETWEB} = prompt( "Web", $this->{DOWNTARGETWEB} );

        print "Enter the full URL path to the alternate bin directory\n";
        $this->{DOWNTARGETSCRIPT} =
          prompt( "Scripts", $this->{DOWNTARGETSCRIPT} );
        print
"Enter the file suffix used on scripts in the alternate bin directory (enter 'none' for none)\n";
        $this->{DOWNTARGETSUFFIX} =
          prompt( "Suffix", $this->{DOWNTARGETSUFFIX} );
        $this->{DOWNTARGETSUFFIX} = ''
          if $this->{DOWNTARGETSUFFIX} eq 'none';

        my $rep = $this->{config}->{repositories}->{ $this->{project} } || {};
        $rep->{pub}        = $this->{UPLOADTARGETPUB};
        $rep->{script}     = $this->{UPLOADTARGETSCRIPT};
        $rep->{suffix}     = $this->{UPLOADTARGETSUFFIX};
        $rep->{web}        = $this->{UPLOADTARGETWEB};
        $rep->{downscript} = $this->{DOWNTARGETSCRIPT};
        $rep->{downsuffix} = $this->{DOWNTARGETSUFFIX};
        $rep->{downweb}    = $this->{DOWNTARGETWEB};
        $this->{config}->{repositories}->{ $this->{project} } = $rep;
        $this->_saveConfig();
    }

    my $userAgent =
      new Foswiki::Contrib::Build::UserAgent( $this->{UPLOADTARGETSCRIPT},
        $this );
    $userAgent->agent( 'ContribBuild/' . $VERSION . ' ' );
    $userAgent->cookie_jar( {} );

    my $topic = $this->_getTopicName();

    # Ask for username and password
    my ( $user, $pass ) = $this->getCredentials( $this->{UPLOADTARGETSCRIPT} );

    # Ask what the user wants to upload
    my $doUploadArchivesAndInstallers =
      ask( "Do you want to upload the archives and installers?", 1 );

    #need the topic at this point.
    $this->build('release');
    my $topicText;
    my $baseTopic = $this->{basedir} . '/' . $to . '.txt';
    local $/ = undef;    # set to read to EOF
    if ( open( IN_FILE, '<', $baseTopic ) ) {
        print "Basing new topic on " . $baseTopic . "\n";
        $topicText = <IN_FILE>;
        close(IN_FILE);
    }
    else {
        warn 'Failed to open base topic(' . $baseTopic . '): ' . $!;
        $topicText = <<END;
Release $to
END
        print "Basing new topic on some default text:\n$topicText\n";
    }
    my @attachments;
    $topicText =~ s/%META:FILEATTACHMENT(.*)%/
      push(@attachments, $1);''/ge;

    my $doUploadAttachments = scalar(@attachments)
      && ask( "Do you want to upload the attachments?", 1 );

    # No more questions after this point

    $this->_login( $userAgent, $user, $pass );

    my $url =
"$this->{UPLOADTARGETSCRIPT}/view$this->{UPLOADTARGETSUFFIX}/$this->{UPLOADTARGETWEB}/$topic";
    my $alturl =
"$this->{DOWNTARGETSCRIPT}/view$this->{DOWNTARGETSUFFIX}/$this->{DOWNTARGETWEB}/$topic";

    # Get the old form data and attach it to the update
    print "Downloading $topic to recover form\n";
    my $response = $userAgent->get("$url?raw=all");

    my %newform;
    my $formExists = 0;

    # SMELL: There appears to be no way to distinguish if Foswiki didn't
    # find the topic and returns the topic creator form, or if the GET
    # was successful.  Foswiki always returns 200 for the status
    # We need a better way of handling the not-found condition.
    # For now, look to see if there is a newtopicform present. If found,
    # it means that the get should be treated as a NOT FOUND.

    unless ( $response->is_success()
        && !( $response->content() =~ m/<form name="newtopicform"/s ) )
    {
        if ( !$response->is_success ) {
            print 'Failed to GET old topic ', $response->request->uri,
              ' -- ', $response->status_line, "\n";
        }

        if (   ( $this->{DOWNTARGETSCRIPT} ne $this->{UPLOADTARGETSCRIPT} )
            || ( $this->{DOWNTARGETWEB} ne $this->{UPLOADTARGETWEB} ) )
        {
            print "Downloading $topic from $alturl to recover form\n";
            $response = $userAgent->get("$alturl?raw=all");
            unless ( $response->is_success ) {
                print 'Failed to GET old topic from Alternate location',
                  $response->request->uri,
                  $newform{formtemplate} = 'PackageForm';
                if ( $this->{project} =~ /(Plugin|Skin|Contrib|AddOn)$/ ) {
                    $newform{TopicClassification} = $1 . 'Package';
                }
            }
        }
    }
    if ( $response->is_success()
        && !( $response->content() =~ m/<form name="newtopicform"/s ) )
    {
        print "Recovering form from $topic\n";

        # SMELL: would be better to use Foswiki::Meta to do this
        foreach my $line ( split( /\n/, $response->content() ) ) {

            if ( $line =~ m/%META:FIELD{name="(.*?)".*?value="(.*?)"/ ) {
                my $name = $1;
                my $val  = $2;

                # URL-decode the value
                $val =~ s/%([\da-f]{2})/chr(hex($1))/gei;

                # Trim null values or we end up damaging the form
                if ( defined $val && length($val) ) {
                    $newform{$name} = $val;
                }
            }
            elsif ( $line =~ /META:FORM{name="PackageForm/ ) {
                $newform{formtemplate} = 'PackageForm';
                $formExists = 1;
            }
        }

        if ( !$formExists ) {
            $newform{formtemplate} ||= 'PackageForm';
        }
        if ( $this->{project} =~ /(Plugin|Skin|Contrib|AddOn)$/ ) {
            $newform{TopicClassification} ||= $1 . 'Package';
        }
    }

    $newform{text} = $topicText;

    $this->_uploadTopic( $userAgent, $user, $pass, $topic, \%newform );

    # Upload any 'Var*.txt' topics published by the extension
    my $dataDir = $this->{basedir} . '/data/System';
    if ( opendir( DIR, $dataDir ) ) {
        foreach my $f ( grep( /^Var\w+\.txt$/, readdir DIR ) ) {
            if ( open( IN_FILE, '<', $this->{basedir} . '/data/System/' . $f ) )
            {
                %newform = ( text => <IN_FILE> );
                close(IN_FILE);
                $f =~ s/\.txt$//;
                $this->_uploadTopic( $userAgent, $user, $pass, $f, \%newform );
            }
        }
    }

    return if ( $this->{-topiconly} );

    # upload any attachments to the developer's version of the topic. Any other
    # attachments to the topic on t.o. will still be there.
    my %uploaded;    # flag already uploaded

    if ($doUploadAttachments) {
        foreach my $a (@attachments) {
            $a =~ /name="([^"]*)"/;
            my $name = $1;
            next if $uploaded{$name};
            next if $name =~ /^$to(\.zip|\.tgz|_installer|\.md5|\.sha1)$/;
            $a =~ /comment="([^"]*)"/;
            my $comment = $1;
            $a =~ /attr="([^"]*)"/;
            my $attrs = $1 || '';

            $this->_uploadAttachment(
                $userAgent,
                $user,
                $pass,
                $name,
                $this->{basedir}
                  . '/pub/System/'
                  . $this->{project} . '/'
                  . $name,
                $comment,
                $attrs =~ /h/ ? 1 : 0
            );
            $uploaded{$name} = 1;
        }
    }

    return unless $doUploadArchivesAndInstallers;

    # Upload the standard files
    foreach my $ext (qw(.zip .tgz _installer .md5 .sha1)) {
        my $name = $to . $ext;
        next if $uploaded{$name};
        $this->_uploadAttachment( $userAgent, $user, $pass, $to . $ext,
            $this->{basedir} . '/' . $to . $ext, '' );
        $uploaded{$name} = 1;
    }
}

sub _login {
    my ( $this, $userAgent, $user, $pass ) = @_;

    #Send a login request - to get a validation key for strikeone
    my $response = $userAgent->get(
        "$this->{UPLOADTARGETSCRIPT}/login$this->{UPLOADTARGETSUFFIX}");

    # "(Foswiki login)" or "Login - Foswiki"
    unless ( ( $response->code == 200 || $response->code == 400 )
        and $response->header('title') =~ /login/i )
    {
        die 'Failed to GET login form '
          . $response->request->uri . ' -- '
          . $response->status_line . "\n";
    }

    my $validationKey = $this->_strikeone( $userAgent, $response );

    $response = $userAgent->post(
        "$this->{UPLOADTARGETSCRIPT}/login$this->{UPLOADTARGETSUFFIX}",
        {
            username       => $user,
            password       => $pass,
            validation_key => $validationKey
        }
    );

    die 'Login failed '
      . $response->request->uri . ' -- '
      . $response->status_line . "\n"
      . 'Aborting' . "\n"
      unless $response->is_redirect
          && $response->headers->header('Location') !~ m{/oops};
}

sub _strikeone {
    my ( $this, $userAgent, $response ) = @_;

    my $f = $response->content();
    $f =~ s/<\/form>.*//sm;
    $f =~ s/.*<form.*?>//sm;
    my $validationKey;
    while ( $f =~ /<input([^>]*)>/g ) {
        my $attrs = $1;
        if (    $attrs =~ /\bname=["']validation_key["']/
            and $attrs =~ /\bvalue=["'](.*?)["']/ )
        {
            $validationKey = $1;
            last;
        }
    }
    if ( not defined $validationKey ) {
        warn "WARNING: The form does not have a validation_key field\n";
        return '';
    }

    my $cookie;
    $userAgent->cookie_jar()->scan(
        sub {
            my ( $version, $key, $value ) = @_;
            $cookie = $value if $key eq 'FOSWIKISTRIKEONE';
        }
    );
    if ( not defined $cookie ) {
        warn
"WARNING: Could not find strikeone cookie in cookiejar - disabling strikeone\n";
        return $validationKey;
    }

    $validationKey =~ s/^\?//;

    return Digest::MD5::md5_hex( $validationKey . $cookie );
}

sub _uploadTopic {
    my ( $this, $userAgent, $user, $pass, $topic, $form ) = @_;

    # send an edit request to get a validation key
    my $response = $userAgent->get(
"$this->{UPLOADTARGETSCRIPT}/edit$this->{UPLOADTARGETSUFFIX}/$this->{UPLOADTARGETWEB}/$topic"
    );
    unless ( $response->is_success ) {
        die 'Request to edit '
          . $this->{UPLOADTARGETWEB} . '/'
          . $topic
          . ' failed '
          . $response->request->uri . ' -- '
          . $response->status_line . "\n";
    }

    $form->{validation_key} = $this->_strikeone( $userAgent, $response );

    my $url =
"$this->{UPLOADTARGETSCRIPT}/save$this->{UPLOADTARGETSUFFIX}/$this->{UPLOADTARGETWEB}/$topic";
    $form->{text} = <<EXTRA. $form->{text};
<!--
This topic is part of the documentation for $this->{project} and is
automatically generated from Subversion. You can edit it, but if you do,
please make sure the maintainer of the extension knows about your changes,
otherwise your edits might be lost the next time the topic is uploaded.

If you want to report an error in the topic, please raise a report at
http://foswiki.org/Tasks/$this->{project}
-->
EXTRA
    print "Saving $topic\n";
    $this->_postForm( $userAgent, $user, $pass, $url, $form );
}

sub _uploadAttachment {
    my ( $this, $userAgent, $user, $pass, $filename, $filepath, $filecomment,
        $hide )
      = @_;

    # send an edit request to get a validation key
    my $response = $userAgent->get(
"$this->{UPLOADTARGETSCRIPT}/edit$this->{UPLOADTARGETSUFFIX}/$this->{UPLOADTARGETWEB}/$this->{project}"
    );
    unless ( $response->is_success ) {
        die 'Request to edit '
          . $this->{UPLOADTARGETWEB} . '/'
          . $this->{project}
          . ' failed '
          . $response->request->uri . ' -- '
          . $response->status_line . "\n";
    }

    my $url =
"$this->{UPLOADTARGETSCRIPT}/upload$this->{UPLOADTARGETSUFFIX}/$this->{UPLOADTARGETWEB}/$this->{project}";
    my $form = [
        'filename'       => $filename,
        'filepath'       => [$filepath],
        'filecomment'    => $filecomment,
        'hidefile'       => $hide || 0,
        'validation_key' => $this->_strikeone( $userAgent, $response ),
    ];

    print "Uploading $this->{UPLOADTARGETWEB}/$this->{project}/$filename\n";
    $this->_postForm( $userAgent, $user, $pass, $url, $form );
}

sub _postForm {
    my ( $this, $userAgent, $user, $pass, $url, $form ) = @_;

    my $pause = $GLACIERMELT - ( time - $lastUpload );
    if ( $pause > 0 ) {
        print "Taking a ${pause}s breather after the last upload...\n";
        sleep($pause);
    }
    $lastUpload = time();

    my $response =
      $userAgent->post( $url, $form, 'Content_Type' => 'form-data' );

    die 'Upload failed ', $response->request->uri,
      ' -- ', $response->status_line, "\n", 'Aborting', "\n",
      $response->as_string
      unless $response->is_redirect
          && $response->headers->header('Location') !~ m{/oops|/log.n/};
}

sub _unhtml {
    my $html = shift;

    $html =~ s/<[^<>]*>//og;
    $html =~ s/&#?\w+;//go;
    $html =~ s/\s//go;

    return $html;
}

# Build POD documentation. This target defines =%$POD%= - it
# does not generate any output. The target will be invoked
# automatically if =%$POD%= is used in a .txt file. POD documentation
# is intended for use by developers only.

# POD text in =.pm= files should use TML syntax or HTML. Packages should be
# introduced with a level 1 header, ---+, and each method in the package by
# a level 2 header, ---++. Make sure you document any global variables used
# by the module.

sub target_POD {
    my $this = shift;
    $this->{POD} = '';
    local $/ = "\n";
    foreach my $file ( @{ $this->{files} } ) {
        my $pmfile = $file->{name};
        if ( $pmfile =~ /\.p[ml]$/o ) {
            next if $pmfile =~ /^$this->{project}_installer(\.pl)?$/;
            $pmfile = $this->{basedir} . '/' . $pmfile;
            open( PMFILE, '<', $pmfile ) || die $!;
            my $inPod = 0;
            while ( my $line = <PMFILE> ) {
                if ( $line =~ /^=(begin|pod)/ ) {
                    $inPod = 1;
                }
                elsif ( $line =~ /^=cut/ ) {
                    $inPod = 0;
                }
                elsif ($inPod) {
                    $this->{POD} .= $line;
                }
            }
            close(PMFILE);
        }
    }
}

=begin TML

---++++ target_POD

Print POD documentation. This target does not modify any files, it simply
prints the (TML format) POD.

POD text in =.pm= files should use TML syntax or HTML. Packages should be
introduced with a level 1 header, ---+, and each method in the package by
a level 2 header, ---++. Make sure you document any global variables used
by the module.

=cut

sub target_pod {
    my $this = shift;
    $this->target_POD();
    print $this->{POD} . "\n";
}

=begin TML

---++++ target_installer

Write an install/uninstall script that checks dependencies, and optionally
downloads and installs required zips from foswiki.org.

The install script is templated from =contrib/TEMPLATE_installer= and
is always named =module_installer= (where module is your module). It is
added to the release zip and is always shipped in the root directory.
It will automatically be added to the manifest if it doesn't appear in
MANIFEST.

The install script works using the dependency type and version fields.
It will try to download from foswiki.org to satisfy any missing dependencies.
Downloaded modules are automatically installed.

Note that the dependencies will only work if the module depended on follows
the naming standards for zips i.e. it must be attached to the topic in
foswiki.org and have the same name as the topic, and must be a zip file.

Dependencies on CPAN modules are also checked (type perl) but no attempt
is made to install them.

The install script also acts as an uninstaller and upgrade script.

__Note__ that =target_install= builds and invokes this install script.

At present there is no support for a caller-provided post-install script, but
this would be straightforward to do if it were required.

=cut

sub target_installer {
    my $this = shift;

    return
      if defined $this->{options}->{installers}
          && $this->{options}->{installers} =~ /none/;

    # Add the install script to the manifest, unless it is already there
    unless (
        grep( /^$this->{project}_installer$/,
            map { $_->{name} } @{ $this->{files} } )
      )
    {
        push(
            @{ $this->{files} },
            {
                name        => $this->{project} . '_installer',
                description => 'Install script',
                permissions => 0770
            }
        );
        warn 'Auto-adding install script to manifest', "\n"
          if ( $this->{-v} );
    }

    # Find the template on @INC
    my $template;
    foreach my $d (@INC) {
        my $dir = `dirname $d`;
        chop($dir);
        my $file =
          $dir . '/lib/Foswiki/Contrib/BuildContrib/TEMPLATE_installer.pl';
        if ( -f $file ) {
            $template = $file;
            last;
        }
        $dir .= '/contrib';
        if ( -f $dir . '/TEMPLATE_installer.pl' ) {
            $template = $dir . '/TEMPLATE_installer.pl';
            last;
        }
    }
    unless ($template) {
        die
'COULD NOT LOCATE TEMPLATE_installer.pl - required for install script generation';
    }

    my @sats;
    foreach my $dep ( @{ $this->{dependencies} } ) {
        my $descr = $dep->{description};
        $descr =~ s/"/\\\"/g;
        $descr =~ s/\$/\\\$/g;
        $descr =~ s/\@/\\\@/g;
        $descr =~ s/\%/\\\%/g;
        my $trig = $dep->{trigger};
        $trig = 1 unless ($trig);
        push( @sats,
"{ name=>'$dep->{name}', type=>'$dep->{type}',version=>'$dep->{version}',description=>'$descr', trigger=>$trig }"
        );
    }
    my $satisfies = join( ",", @sats );
    $this->{SATISFIES} = $satisfies;

    my $installScript =
      $this->{basedir} . '/' . $this->{project} . '_installer';
    if ( $this->{-v} || $this->{-n} ) {
        print 'Generating installer in ', $installScript, "\n";
    }

    $this->filter_txt( $template, $installScript );

    # Copy it to .pl
    $this->cp( $installScript, "$installScript.pl" );
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
    my $fn = 'target_' . $target;
    no strict "refs";
    $this->$fn();
    use strict "refs";
    if ($@) {
        die 'Failed to build ', $target, ': ', $@;
    }
    if ( $this->{-v} ) {
        print 'Built ', $target, "\n";
    }
}

=begin TML

---++++ target_manifest
Generate and print to STDOUT a rough guess at the MANIFEST listing

=cut

sub target_manifest {
    my $this = shift;

    $collector = $this;
    my $manifest = _findRelativeTo( $buildpldir, 'MANIFEST' );
    if ( $manifest && -e $manifest ) {
        open( F, '<', $manifest )
          || die 'Could not open existing ' . $manifest;
        local $/ = undef;
        %{ $collector->{manilist} } =
          map { /^(.*?)(\s+.*)?$/; $1 => ( $2 || '' ) } split( /\r?\n/, <F> );
        close(F);
    }
    else {
        $manifest = $buildpldir . '/MANIFEST';
    }
    require File::Find;
    $collector->{manilist} = ();
    warn "Gathering from $this->{basedir}\n";

    File::Find::find( \&_manicollect, $this->{basedir} );
    print '# DRAFT ', $manifest, ' follows:', "\n";
    print '################################################', "\n";
    for ( sort keys %{ $collector->{manilist} } ) {
        print $_. ' ' . $collector->{manilist}{$_} . "\n";
    }
    print '################################################', "\n";
    print '# Copy and paste the text between the ###### lines into the file',
      "\n";
    print '# ' . $manifest, "\n";
    print '# to create an initial manifest. Remove any files',   "\n";
    print '# that should _not_ be released, and add a',          "\n";
    print '# description of each file at the end of each line.', "\n";
}

sub _manicollect {
    if (/^(CVS|\.svn|\.git)$/) {
        $File::Find::prune = 1;
    }
    elsif (
           !-d 
        && /^\w.*\w$/
        && !/^(DEPENDENCIES|MANIFEST|(PRE|POST)INSTALL|build\.pl)$/
        && !/\.bak$/
        && !/^$collector->{project}_installer(\.pl)?$/

        # Item10188: Ignore build output, but still want data/System/Project.txt
        # $basedir in \Q...\E makes it a literal string (ignore regex chars)
        && not $File::Find::name =~
        /\Q$basedir\E\W$collector->{project}\.(md5|zip|tgz|txt|sha1)$/
      )
    {
        my $n     = $File::Find::name;
        my @a     = stat($n);
        my $perms = sprintf( "%04o", $a[2] & 0777 );
        $n =~ s/$collector->{basedir}\/?//;
        $collector->{manilist}{$n} = $perms
          unless exists $collector->{manilist}{$n};
    }
}

=begin TML

#HistoryTarget
Updates the history in the plugin/contrib topic from the subversion checkin history.
   * Requires a line like | Change History:| NNNN: descr | in the topic, where NNN is an SVN rev no and descr is the description of the checkin.
   * Automatically changes ItemNNNN references to links to the bugs web.
   * Must be run in a subversion checkout area!
This target works in the current checkout area; it still requires a checkin of the updated plugin. Note that history items checked in against Item000 are *ignored* (not included in the history).

=cut

sub target_history {
    my $this = shift;

    my $f = $this->{basedir} . '/' . $this->{topic_root} . '.txt';

    my $cmd = "cd $this->{basedir} && svn status";
    warn "Checking status using $cmd\n";
    my $log = join( "\n", grep { !/^\?/ } split( /\n/, `$cmd` ) );
    warn "WARNING:\n$log\n" if $log;

    open( IN, '<', $f ) or die "Could not open $f: $!";

    # find the table
    my $in_history = 0;
    my @history;
    my $pre = '';
    my $post;
    local $/ = "\n";
    while ( my $line = <IN> ) {
        if ( $line =~
            /^\s*\|\s*Change(?:\s+|&nbsp;)History:.*?\|\s*(.*?)\s*\|\s*$/i )
        {
            $in_history = 1;
            push( @history, [ "?1'$1'", $1 ] ) if ( $1 && $1 !~ /^\s*$/ );
        }
        elsif ($in_history) {

            # | NNNN | desc |
            if ( $line =~ /^\s*\|\s*(\d+)\s*\|\s*(.*?)\s*\|\s*$/ ) {
                push( @history, [ $1, $2 ] );
            }

            # | date | desc |
            elsif ( $line =~
                /^\s*\|\s*(\d+[-\s\/]+\w+[-\s+\/]\d+)\s*\|\s*(.*?)\s*\|\s*$/ )
            {
                push( @history, [ $1, $2 ] );
            }

            # | verno | desc |
            elsif ( $line =~ /^\s*\|\s*([\d.]+)\s*\|\s*(.*?)\s*\|\s*$/ ) {
                push( @history, [ $1, $2 ] );
            }

            # | | date: desc |
            elsif (
                $line =~ /^\s*\|\s*\|\s*(\d+\s+\w+\s+\d+):\s*(.*?)\s*\|\s*$/ )
            {
                push( @history, [ $1 . $2 ] );
            }

            # | | verno: desc |
            elsif ( $line =~ /^\s*\|\s*\|\s*([\d.]+):\s*(.*?)\s*\|\s*$/ ) {
                push( @history, [ $1, $2 ] );
            }

            # | | desc |
            elsif ( $line =~ /^\s*\|\s*\|\s*(.*?)\s*\|\s*$/ ) {
                push( @history, [ "?" . $1 ] );
            }

            else {
                $post = $line;
                last;
            }
        }
        else {
            $pre .= $line;
        }
    }
    die "No | Change History: | ... | found" unless $in_history;
    $/ = undef;
    $post .= <IN>;
    close(IN);

    # Determine the most recent history item
    my $base = 0;
    if ( scalar(@history) && $history[0]->[0] =~ /^(\d+)$/ ) {
        $base = $1;
    }
    warn "Refreshing history since $base\n";
    $cmd = "cd $this->{basedir} && svn info -R";
    warn "Recovering version info using $cmd...\n";
    $log = `$cmd`;

    # find files with revs more recent than $base
    my $curpath;
    my @revs;
    foreach my $line ( split( /\n/, $log ) ) {
        if ( $line =~ /^Path: (.*)$/ ) {
            $curpath = $1;
        }
        elsif ( $line =~ /^Last Changed Rev: (.*)$/ ) {
            die unless $curpath;
            if ( $1 > $base ) {
                warn "$curpath $1 > $base\n";
                push( @revs, $curpath );
            }
            $curpath = undef;
        }
    }

    unless ( scalar(@revs) ) {
        warn "History is up to date with svn log\n";
        return;
    }

    # Update the history
    $cmd = "cd $this->{basedir} && svn log " . join( ' && svn log ', @revs );
    warn "Updating history using $cmd...\n";
    $log = `$cmd`;
    my %new;
    foreach my $line ( split( /^----+\s*/m, $log ) ) {
        if ( $line =~
            /^r(\d+)\s*\|\s*(\w+)\s*\|\s*.*?\((.+?)\)\s*\|.*?\n\s*(.+?)\s*$/ )
        {

            # Ignore the history item we already have
            next if $1 == $base;
            my $rev = $1;
            next if $rev <= $base;
            my $when = "$2 $3 ";
            my $mess = $4;

            # Ignore Item000: checkins
            next if $mess =~ /^Item0+:/;
            $mess =~ s/</&lt;/g;
            $mess =~ s/\|/!/g;
            $mess =~ s#(?<!Foswikitask:)\bItem(\d+):#Foswikitask:Item$1:#gm;
            $mess =~ s/\r?\n/ /g;
            $new{$rev} = [ $rev, $mess ];
        }
    }
    unshift( @history, map { $new{$_} } sort { $b <=> $a } keys(%new) );
    print "| Change&nbsp;History: | |\n";
    print join( "\n", map { "|  $_->[0] | $_->[1] |" } @history );
}

=begin TML

---++++ target_dependencies

Extract and print all dependencies, in standard DEPENDENCIES syntax.
Requires B::PerlReq. Analyses perl sources in !includes as well.

All dependencies except those on pragmas (strict, integer etc) are
extracted.

=cut

sub target_dependencies {
    my $this = shift;
    local $/ = "\n";

    die "B::PerlReq is required for 'dependencies': $@"
      unless eval "use B::PerlReq; 1";

    foreach my $m (
        'strict',   'vars',     'diagnostics', 'base',
        'bytes',    'constant', 'integer',     'locale',
        'overload', 'warnings', 'Assert',      'TWiki',
        'Foswiki'
      )
    {
        $this->{satisfied}{$m} = 1;
    }

    # See if we already know about it
    foreach my $dep ( @{ $this->{dependencies} } ) {
        $this->{satisfied}{ $dep->{name} } = 1;
    }

    $this->{extracted_deps} = undef;
    my @queue;
    my %tainted;
    foreach my $file ( @{ $this->{files} } ) {
        my $is_perl = 0;
        my $pmfile  = $file->{name};
        if (   $pmfile =~ /\.p[ml]$/o
            && $pmfile !~ /build.pl/
            && $pmfile !~ /TEMPLATE_installer.pl/ )
        {
            $is_perl = 1;
        }
        else {
            my $testfile = $this->{basedir} . '/' . $pmfile;
            if ( -e $testfile ) {
                open( PMFILE, '<', $testfile ) || die "$testfile: $!";
                my $fline = <PMFILE>;
                if ( $fline && $fline =~ m.#!/usr/bin/perl. ) {
                    $is_perl = 1;
                    $tainted{$pmfile} = '-T' if $fline =~ /-T/;
                }
                close(PMFILE);
            }
        }
        if ( $pmfile =~ /^lib\/(.*)\.pm$/ ) {
            my $f = $1;
            $f =~ s.CPAN/lib/..;
            $f =~ s./.::.g;
            $this->{satisfied}{$f} = 1;
        }
        if ($is_perl) {
            $tainted{$pmfile} = '' unless defined $tainted{$pmfile};
            push( @queue, $pmfile );
        }
    }

    my $inc = '-I' . join( ' -I', @INC );
    foreach my $pmfile (@queue) {
        die         unless defined $basedir;
        die         unless defined $inc;
        die         unless defined $pmfile;
        die $pmfile unless defined $tainted{$pmfile};
        my $deps =
`cd $basedir && perl $inc $tainted{$pmfile} -MO=PerlReq,-strict $pmfile 2>/dev/null`;
        $deps =~ s/perl\((.*?)\)/$this->_addDep($pmfile, $1)/ge if $deps;
    }

    print "MISSING DEPENDENCIES:\n";
    my $depcount = 0;
    foreach my $module ( sort keys %{ $this->{extracted_deps} } ) {
        print "$module,>=0,cpan,May be required for "
          . join( ', ', @{ $this->{extracted_deps}{$module} } ) . "\n";
        $depcount++;
    }
    print $depcount
      . ' missing dependenc'
      . ( $depcount == 1 ? 'y' : 'ies' ) . "\n";
}

sub _addDep {
    my ( $this, $from, $file ) = @_;

    $file =~ s./.::.g;
    $file =~ s/\.pm$//;
    return '' if $this->{satisfied}{$file};
    push( @{ $this->{extracted_deps}{$file} }, $from );
    return '';
}

our @twikiFilters = (
    { RE => qr/\.pm$/,          filter => '_twikify_perl' },
    { RE => qr/\.pm$/,          filter => '_twikify_txt' },
    { RE => qr#/Config.spec$#,  filter => '_twikify_perl' },
    { RE => qr#/MANIFEST$#,     filter => '_twikify_manifest' },
    { RE => qr#/DEPENDENCIES$#, filter => '_twikify_perl' },
);

# Create a TWiki version of the extension by simple transformation of files.
# Useless for processing CSS, JS or anything else complex.
sub target_twiki {
    my $this = shift;

    print STDERR <<CAVEAT;
WARNING: This convertor targets TWiki 4.2.3. Not all Foswiki APIs are
supported by TWiki, or TWiki may have changed since 4.2.3. You should
take great care to test the TWiki version. You cannot expect the
maintainer of this extension to support the TWiki version. Caveat emptor.
CAVEAT
    my $r = "$this->{libdir}/$this->{project}";
    $r =~ s#^$this->{basedir}/##;
    push( @{ $this->{files} }, { name => "$r/MANIFEST" } );
    push( @{ $this->{files} }, { name => "$r/DEPENDENCIES" } );
    push( @{ $this->{files} }, { name => "$r/build.pl" } );

    foreach my $file ( @{ $this->{files} } ) {
        my $nf = $file->{name};
        if ( $file->{name} =~ m#^(data|pub)/System/(.*)$# ) {
            $nf = "$1/TWiki/$2";
        }
        elsif ( $file->{name} =~ m#^lib/Foswiki/(.*)$# ) {
            $nf = "lib/TWiki/$1";
        }
        if ( $nf ne $file->{name} ) {
            my $filtered = 0;
            foreach my $filter (@twikiFilters) {
                if ( $file->{name} =~ /$filter->{RE}/ ) {
                    my $fn = $filter->{filter};
                    $this->$fn( $this->{basedir} . '/' . $file->{name},
                        $this->{basedir} . '/' . $nf );
                    $filtered = 1;
                    last;
                }
            }
            unless ($filtered) {
                $this->cp( $this->{basedir} . '/' . $file->{name},
                    $this->{basedir} . '/' . $nf );
            }
            $file->{name} = $nf;
            print "Created $file->{name}\n";
        }
    }
}

sub _twikify_perl {
    my ( $this, $from, $to ) = @_;

    $this->_filter_file(
        $from, $to,
        sub {
            my ( $this, $text ) = @_;
            $text =~ s/Foswiki::/TWiki::/g;
            $text =~ s/new Foswiki\s*\(\s*\);/new TWiki();/g;
            $text =~ s/\b(use|require)\s+Foswiki/$1 TWiki/g;
            $text =~ s/foswiki\([A-Z][A-Za-z]\+\)/twiki$1/g;
            $text =~ s/'foswiki'/'twiki'/g;
            $text =~ s/FOSWIKI_/TWIKI_/g;
            $text =~ s/foswikiNewLink/twikiNewLink/g;           # CSS
            $text =~ s/foswikiAlert/twikiAlert/g;
            $text =~ s/new Foswiki/new TWiki/g;
            return <<'CAVEAT' . $text;
# This TWiki version was auto-generated from Foswiki sources by BuildContrib.
# Copyright (C) 2008-2010 Foswiki Contributors

CAVEAT

            # Note: the last blank line is to avoid mangling =pod
        }
    );
}

sub _twikify_manifest {
    my ( $this, $from, $to ) = @_;

    $this->_filter_file(
        $from, $to,
        sub {
            my ( $this, $text ) = @_;
            $text =~ s#^data/System#data/TWiki#gm;
            $text =~ s#^pub/System#pub/TWiki#gm;
            $text =~ s#^lib/Foswiki#lib/TWiki#gm;
            return <<HERE;
# This TWiki version was auto-generated from Foswiki sources by BuildContrib.
# Copyright (C) 2008-2010 Foswiki Contributors
!option archive_prefix TWiki_
!option installers none
$text
HERE
        }
    );
}

sub _twikiify_txt {
    my ( $this, $from, $to ) = @_;

    $this->_filter_file(
        $from, $to,
        sub {
            my ( $this, $text ) = @_;
            return <<HERE;
<blockquote>
This TWiki version was auto-generated from Foswiki sources by BuildContrib.
<br />
Copyright (C) 2008-2010 Foswiki Contributors
</blockquote>
$text
HERE
        }
    );
}

1;
__DATA__
You do not need to install anything in the browser to use this extension. The following instructions are for the administrator who installs the extension on the server.

Open configure, and open the "Extensions" section. Use "Find More Extensions" to get a list of available extensions. Select "Install".

If you have any problems, or if the extension isn't available in =configure=, then you can still install manually from the command-line. See http://foswiki.org/Support/ManuallyInstallingExtensions for more help.
