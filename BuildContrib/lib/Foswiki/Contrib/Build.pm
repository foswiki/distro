#
# Copyright (C) 2004 C-Dot Consultants - All rights reserved
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
use Digest::MD5 ();
use File::Copy ();
use File::Spec ();
use FindBin    ();
use File::Find ();
use File::Path ();
use File::Temp ();
use POSIX      ();
use warnings;
use Foswiki::Time;

our $basedir;
our $buildpldir;
our $libpath;

our $RELEASE = "29 Jul 2009";
our $VERSION = '$Rev$';

our $SHORTDESCRIPTION = 'Automates build and packaging process, including installer generation, for extension modules.';

my $UPLOADSITEPUB           = 'http://foswiki.org/pub';
my $UPLOADSITESCRIPT        = 'http://foswiki.org/bin';
my $UPLOADSITESUFFIX        = '';
my $UPLOADSITEBUGS          = 'http://foswiki.org/Tasks';
my $UPLOADSITEEXTENSIONSWEB = "Extensions";
my $DEFAULTCUSTOMERDB       = "$ENV{HOME}/customerDB";

my $GLACIERMELT = 10;    # number of seconds to sleep between uploads,
                         # to reduce average load on server

my $targetProject;       # Foswiki or TWiki

my $collector;           # general purpose handle for collecting stuff

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

    my @path = split( /\/+/, $startdir );

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
    $buildpldir = $FindBin::RealBin;
    $buildpldir = File::Spec->rel2abs($buildpldir);

    # Find the lib root
    if ( -e "$buildpldir/../../../Foswiki" ) {
        $libpath = _findRelativeTo( $buildpldir, 'lib/Foswiki' );
        $targetProject = 'Foswiki';
    }
    else {
        print STDERR "Assuming this is a TWiki project\n";
        $libpath = _findRelativeTo( $buildpldir, 'lib/TWiki' );
        $targetProject = 'TWiki';
    }
    die 'Could not find lib/Foswiki or lib/TWiki' unless $libpath;
    $libpath =~ s#/[^/]*$##;

    $basedir = $libpath;
    $basedir =~ s#/[^/]*$##;

    my $env = $ENV{ uc($targetProject) . '_LIBS' };
    if ($env) {
        my %known;
        map { $known{$_} = 1 } split( /:/, @INC );
        foreach my $pc ( reverse split( /:/, $env ) ) {
            unless ( $known{$pc} ) {
                unshift( @INC, $pc );
            }
        }
    }
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
    elsif ( $this->{project} =~ /(Contrib|Skin)$/ ) {
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
        $deptable .= CGI::Tr($cells);
    }
    $this->{RAW_DEPENDENCIES} = $rawdeps;
    $this->{DEPENDENCIES}     = 'None';
    if ($deptable) {
        my $cells =
          CGI::th('Name') . CGI::th('Version') . CGI::th('Description');
        $this->{DEPENDENCIES} =
          CGI::table( { border => 1, class => 'foswikiTable' },
            CGI::Tr($cells) . $deptable );
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

    my $config = $this->_loadConfig();
    my $rep    = $config->{repositories}->{ $this->{project} };
    if ($rep) {
        $this->{UPLOADTARGETPUB}    = $rep->{pub};
        $this->{UPLOADTARGETSCRIPT} = $rep->{script};
        $this->{UPLOADTARGETSUFFIX} = $rep->{suffix};
        $this->{UPLOADTARGETWEB}    = $rep->{web};
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
        if ( -r "$ENV{HOME}/.buildcontrib" ) {
            do "$ENV{HOME}/.buildcontrib";
            $this->{config} = $VAR1;
            print "Loaded config from $this->{config}->{file}\n";
        }
        else {
        }
        unless ( $this->{config} ) {
            $this->{config} = {
                file         => "$ENV{HOME}/.buildcontrib",
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
    require Data::Dumper;
    if ( open( F, '>', $this->{config}->{file} ) ) {
        print F Data::Dumper->Dump( [ $this->{config} ] );
        close(F);
        print "Config saved in $this->{config}->{file}\n";
    }
    else {
        print STDERR "Could not write $this->{config}->{file}: $!";
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
                  $this->{basedir} . '/'
                  . ${ $this->{files} }[$idx]->{name};
                if ( -f $file ) {
                    push @files, $file;
                }
                elsif ( $file =~ /\/$/ )
                {    # Directory, create if it does not exist
                    File::Path::mkpath($file);
                }
                elsif ( !-d $file ) {    # Ignore directories
                    print STDERR
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
                    if ( $log =~ /^Date:\s+([\d-]+) ([\d:]+) ([-+\d]+)?/m )
                    {
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
            # print STDERR "WARNING: $@";
            $maxd = time() unless $maxd;
            $max =
              Foswiki::Time::formatTime( $maxd, '$year$mo$day', 'gmtime' )
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
                $file_ok{$file} = $this->$fn( $this->{basedir} . '/' . $file->{name} );
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
    if ( $File::Find::name =~ /(CVS|\.svn|~)$/ ) {
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

            # Replace the SVN revision with rev 1.
            # In release builds this gets replaced by latest revision later.
            $text =~ s/^(%META:TOPICINFO{.*)\$Rev:.*\$(.*}%)$/${1}1$2/m;
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

    if ($to =~ /^(.*)\.compressed\.$ext$/ ) {
        if ( -e "$1.uncompressed.$ext") {
            $from = "$1.uncompressed.$ext";
        } elsif (-e "$1_src\.$ext") {
            $from = "$1_src.$ext";
        } else {
            $from = "$1.$ext";
        }
    } elsif ($to =~ /^(.*)\.$ext$/) {
        if (-e "$1.uncompressed.$ext") {
            $from = "$1.uncompressed.$ext";
        } else {
            $from = "$1_src.$ext";
        }
    }
    return $from;
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

    my $minifier;
    if ( eval { require JavaScript::Minifier::XS } ) {
        $minifier = \&JavaScript::Minifier::XS::minify;
    }
    elsif ( eval { require JavaScript::Minifier } ) {
        $minifier = \&JavaScript::Minifier::minify;
    }
    else {
        print STDERR "Cannot squish $to: $@\n";
    }

    my $from = $this->_deduceCompressibleSrc($to, 'js');
    return 0 unless -e $from;

    open( IF, '<', $from ) || die $!;
    local $/ = undef;
    my $text = <IF>;
    close(IF);

    $text = &{$minifier}( input => $text );

    unless ( $this->{-n} ) {
        if ( open( IF, '<', $to ) ) {
            my $ot = <IF>;
            close($ot);
            if ($text eq $ot) {
                #print STDERR "$to is up to date w.r.t $from\n";
                return 1; # no changes
            }
        }

        open( OF, '>', $to ) || die "$to: $!";
        print OF $text;
        close(OF);
        print STDERR "Generated $to from $from\n";
    }
    return 1;
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

    my $minifier;
    if ( eval { require CSS::Minifier::XS } ) {
        $minifier = \&CSS::Minifier::XS::minify;
    }
    elsif ( eval { require CSS::Minifier } ) {
        $minifier = \&CSS::Minifier::minify;
    }
    else {
        print STDERR "Cannot squish $to: $@\n";
    }

    my $from = $this->_deduceCompressibleSrc($to, 'css');
    return 0 unless -e $from;

    open( IF, '<', $from ) || die $!;
    local $/ = undef;
    my $text = <IF>;
    close(IF);

    $text = &{$minifier}( input => $text );

    unless ( $this->{-n} ) {
        if ( open( IF, '<', $to ) ) {
            my $ot = <IF>;
            close($ot);
            return 1 if $text eq $ot;    # no changes?
        }
        open( OF, '>', $to ) || die "$to: $!";
        print OF $text;
        close(OF);
        print STDERR "Generated $to from $from\n";
    }
    return 1;
}

=begin TML

---++++ build_gz
Uses Compress::Zlib to gzip files

   * xxx.yyy -> xxx.yyy.gz

=cut

sub build_gz {
    my ( $this, $to ) = @_;

    unless ( eval { require Compress::Zlib } ) {
        print STDERR "Cannot gzip $to: $@\n";
        return 0;
    }

    my $from = $to;
    $from =~ s/\.gz$// or return 0;
    return 0 unless -e $from;

    open( IF, '<', $from ) || die $!;
    local $/ = undef;
    my $text = <IF>;
    close(IF);

    $text = Compress::Zlib::memGzip( $text );

    unless ( $this->{-n} ) {
        if ( open( IF, '<', $to ) ) {
            binmode IF;
            my $ot = <IF>;
            close($ot);
            return 1 if $text eq $ot;    # no changes?
        }
        open( OF, '>', $to ) || die "$to: $!";
        binmode OF;
        print OF $text;
        close(OF);
        print STDERR "Generated $to from $from\n";
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
    my $db = prompt("Location of customer database", $DEFAULTCUSTOMERDB);
    if (open(F, '<', $db)) {
        while (my $customer = <F>) {
            chomp($customer);
            if ($customer =~ /^(.+)\s(\S+)\s*$/) {
                $customers{$1} = $2;
            }
        }
        close(F);
        @cuss = sort keys %customers;
        my $i = 0;
        print join("\n", map { $i++; "$i. $_" } @cuss)."\n";
    } else {
        print "$db not found: $@\n";
        print "Creating new customer DB\n";
    }

    my $customer = prompt("Number (or name) of customer");
    if ($customer =~ /^\d+$/ && $customer < scalar(@cuss)) {
        $customer = $cuss[$customer];
    }

    if ($customers{$customer}) {
        $this->{TRACKINGCODE} = $customers{$customer};
    } else {
        print "Customer '$customer' not known\n";
        exit 0 unless ask("Would you like to add a new customer?");

        $this->{TRACKINGCODE} = crypt($customer, $db);
        $this->{TRACKINGCODE} =
          join('', map { sprintf('%02X', $_) }
                 unpack('c*', $this->{TRACKINGCODE}));
        print "New cypher is $this->{TRACKINGCODE}\n";
        $customers{$customer} = $this->{TRACKINGCODE};

        open(F, '>', $db) || die $@;
        print F join("\n", )."\n";
        close(F);
    }

    print STDERR "Tracking code is $this->{TRACKINGCODE}\n";

    push(@stageFilters,
         { RE => qr/\.pm$/, filter => 'filter_tracked_pm' });

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

            print STDERR "Installing $module in $this->{tmpDir}\n";

            #SMELL: uses legacy TWIKI_ exports
            my $cmd =
"export FOSWIKI_HOME=$this->{tmpDir}; export FOSWIKI_LIBS=$libs; export TWIKI_HOME=$this->{tmpDir}; export TWIKI_LIBS=$libs; cd $basedir/$module; perl build.pl handsoff_install";

            #print STDERR "***** running $cmd \n";
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

    $this->sys_action( 'tar', 'czpf', $project . '.tgz', '*' );
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
    foreach my $f qw(.tgz _installer .zip) {
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
        print STDERR
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
        print STDERR
          "WARNING: Digest::SHA not installed; cannot generate SHA1 checksum\n";
    }

    $this->popd();
    $this->popd();

    my $warn = 0;
    foreach my $f qw(.tgz .zip .txt _installer) {
        if ( -e "$this->{basedir}/$target$f" ) {
            print "$f in $this->{basedir}/$target$f\n";
        }
        else {
            print STDERR "WARNING: no $target$f was generated\n";
            $warn++;
        }
    }
    if ($warn) {
        print STDERR <<HERE;
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
    use base qw(LWP::UserAgent);

    sub new {
        my ( $class, $id, $bldr ) = @_;
        my $this = $class->SUPER::new( keep_alive => 1 );
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
        print STDERR 'LWP is not installed; cannot upload', "\n";
        return 0;
    }

    my $to = $this->{project};

    my $topicText;
    local $/ = undef;    # set to read to EOF
    if ( open( IN_FILE, '<', $this->{basedir} . '/' . $to . '.txt' ) ) {
        print "Basing new topic on "
          . $this->{basedir} . '/'
          . $to . '.txt' . "\n";
        $topicText = <IN_FILE>;
        close(IN_FILE);
    }
    else {
        print STDERR 'Failed to open base topic: ' . $!;
        $topicText = <<END;
Release $to
END
        print "Basing new topic on some default text:\n$topicText\n";
    }
    my @attachments;
    $topicText =~ s/%META:FILEATTACHMENT(.*)%/
      push(@attachments, $1);''/ge;

    while (1) {
        print <<END;
Preparing to upload to:
Web:     $this->{UPLOADTARGETWEB}
PubDir:  $this->{UPLOADTARGETPUB}
Scripts: $this->{UPLOADTARGETSCRIPT}
Suffix:  $this->{UPLOADTARGETSUFFIX}
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
        my $rep = $this->{config}->{repositories}->{ $this->{project} } || {};
        $rep->{pub}    = $this->{UPLOADTARGETPUB};
        $rep->{script} = $this->{UPLOADTARGETSCRIPT};
        $rep->{suffix} = $this->{UPLOADTARGETSUFFIX};
        $rep->{web}    = $this->{UPLOADTARGETWEB};
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
    my $doUploadArchivesAndInstallers = ask( "Do you want to upload the archives and installers?", 1 );

    my $doUploadAttachments = scalar(@attachments)
      && ask( "Do you want to upload the attachments?", 1 );

    # No more questions after this point

    $this->build('release');

    $this->_login($userAgent, $user, $pass);

    my $url =
"$this->{UPLOADTARGETSCRIPT}/view$this->{UPLOADTARGETSUFFIX}/$this->{UPLOADTARGETWEB}/$topic";

    # Get the old form data and attach it to the update
    print "Downloading $topic to recover form\n";
    my $response = $userAgent->get("$url?raw=debug");

    my %newform;
    my $formExists = 0;
    unless ( $response->is_success ) {
        print 'Failed to GET old topic ', $response->request->uri,
          ' -- ', $response->status_line, "\n";
        $newform{formtemplate} = 'PackageForm';
        if ( $this->{project} =~ /(Plugin|Skin|Contrib|AddOn)$/ ) {
            $newform{TopicClassification} = $1 . 'Package';
        }
    }
    else {
        foreach my $line ( split( /\n/, $response->content() ) ) {
            if ( $line =~ m/META:FIELD{name="(.*?)".*?value="(.*?)"}/ ) {
                my $val = $2;

                # Trim null values or we end up damaging the form
                if ( defined $val && length($val) ) {
                    $newform{$1} = $val;
                }
            }
            elsif ( $line =~ /META:FORM{name=/ ) {
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
    foreach my $ext qw(.zip .tgz _installer .md5 .sha1) {
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
    my $response = $userAgent->get("$this->{UPLOADTARGETSCRIPT}/login$this->{UPLOADTARGETSUFFIX}");
    unless ( $response->code == 400 
             and $response->header('title') =~ /\(Foswiki login\)/ ) {
        die 'Failed to GET login form '. $response->request->uri.
          ' -- '. $response->status_line. "\n";
    }

    my $validationKey = $this->_strikeone($userAgent, $response);

    $response = $userAgent->post(
        "$this->{UPLOADTARGETSCRIPT}/login$this->{UPLOADTARGETSUFFIX}",
        { username => $user, password => $pass, validation_key => $validationKey }
    );

    die 'Login failed '. $response->request->uri.
      ' -- '. $response->status_line. "\n". 'Aborting'. "\n"
      unless $response->is_redirect
          && $response->headers->header('Location') !~ m{/oops};
}

sub _strikeone {
    my ( $this, $userAgent, $response ) = @_;

    my $f = $response->content();
    $f =~ s/<\/form>.*//sm;
    $f =~ s/.*<form.*?>//sm;
    my $validationKey;
    while ($f =~ /<input([^>]*)>/g) {
        my $attrs = $1;
        if ($attrs =~ /\bname=["']validation_key["']/
                and $attrs =~ /\bvalue=["'](.*?)["']/) {
            $validationKey = $1;
            last;
        }
    }
    if (not defined $validationKey) {
        warn "WARNING: The form does not have a validation_key field\n";
        return '';
    }

    my $cookie;
    $userAgent->cookie_jar()->scan(sub {
        my ($version, $key, $value) = @_;
        $cookie = $value if $key eq 'FOSWIKISTRIKEONE';
    });
    if (not defined $cookie) {
        warn "WARNING: Could not find strikeone cookie in cookiejar - disabling strikeone\n";
        return $validationKey;
    }

    $validationKey =~ s/^\?//;

    return Digest::MD5::md5_hex( $validationKey.$cookie );
}

sub _uploadTopic {
    my ( $this, $userAgent, $user, $pass, $topic, $form ) = @_;
    
    # send an edit request to get a validation key
    my $response = $userAgent->get("$this->{UPLOADTARGETSCRIPT}/edit$this->{UPLOADTARGETSUFFIX}/$this->{UPLOADTARGETWEB}/$topic");
    unless ( $response->is_success ) {
        die 'Request to edit '.$this->{UPLOADTARGETWEB}.'/'.$topic.' failed '. $response->request->uri.
          ' -- '. $response->status_line. "\n";
    }

    $form->{validation_key} = $this->_strikeone($userAgent, $response);

    my $url =
"$this->{UPLOADTARGETSCRIPT}/save$this->{UPLOADTARGETSUFFIX}/$this->{UPLOADTARGETWEB}/$topic";
    $form->{text} = <<EXTRA. $form->{text};
<!--
This topic is part of the documentation for $this->{project} and is
automatically generated from Subversion. Do not edit it! Your edits
will be lost the next time the topic is uploaded!

If you want to report an error in the topic, please raise a report at
http://foswiki.org/view/Tasks/$this->{project}
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
    my $response = $userAgent->get("$this->{UPLOADTARGETSCRIPT}/edit$this->{UPLOADTARGETSUFFIX}/$this->{UPLOADTARGETWEB}/$this->{project}");
    unless ( $response->is_success ) {
        die 'Request to edit '.$this->{UPLOADTARGETWEB}.'/'.$this->{project}.' failed '. $response->request->uri.
          ' -- '. $response->status_line. "\n";
    }

    my $url =
"$this->{UPLOADTARGETSCRIPT}/upload$this->{UPLOADTARGETSUFFIX}/$this->{UPLOADTARGETWEB}/$this->{project}";
    my $form = [
        'filename'    => $filename,
        'filepath'    => [$filepath],
        'filecomment' => $filecomment,
        'hidefile'    => $hide || 0,
        'validation_key' => $this->_strikeone($userAgent, $response),
    ];

    print "Uploading $this->{UPLOADTARGETWEB}/$this->{project}/$filename\n";
    $this->_postForm( $userAgent, $user, $pass, $url, $form );
}

sub _postForm {
    my ( $this, $userAgent, $user, $pass, $url, $form ) = @_;
    my $response =
      $userAgent->post( $url, $form, 'Content_Type' => 'form-data' );

    die 'Upload failed ', $response->request->uri,
      ' -- ', $response->status_line, "\n", 'Aborting', "\n",
      $response->as_string
      unless $response->is_redirect
          && $response->headers->header('Location') !~ m{/oops|/login/};

    my $sleep = $GLACIERMELT;
    if ( $sleep > 0 ) {
        local $| = 1;
        print "Taking a deep breath after the upload";
        while ( $sleep > 0 ) {
            print '.';
            sleep(2);
            $sleep -= 2;
        }
        print "\n";
    }
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
        print STDERR 'Auto-adding install script to manifest', "\n"
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
    print STDERR "Gathering from $this->{basedir}\n";

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
    if (/^(CVS|\.svn)$/) {
        $File::Find::prune = 1;
    }
    elsif (!-d 
        && /^\w.*\w$/
        && !/^(DEPENDENCIES|MANIFEST|(PRE|POST)INSTALL|build\.pl)$/
        && !/$collector->{project}\.(md5|zip|tgz|txt|sha1)/ )
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
    print STDERR "Checking status using $cmd\n";
    my $log = join( "\n", grep { !/^\?/ } split( /\n/, `$cmd` ) );
    print STDERR "WARNING:\n$log\n" if $log;

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
    print STDERR "Refreshing history since $base\n";
    $cmd = "cd $this->{basedir} && svn info -R";
    print STDERR "Recovering version info using $cmd...\n";
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
                print STDERR "$curpath $1 > $base\n";
                push( @revs, $curpath );
            }
            $curpath = undef;
        }
    }

    unless ( scalar(@revs) ) {
        print STDERR "History is up to date with svn log\n";
        return;
    }

    # Update the history
    $cmd = "cd $this->{basedir} && svn log " . join( ' && svn log ', @revs );
    print STDERR "Updating history using $cmd...\n";
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
    { RE => qr#/Config.spec$#,  filter => '_twikify_perl' },
    { RE => qr#/MANIFEST$#,     filter => '_twikify_manifest' },
    { RE => qr#/DEPENDENCIES$#, filter => '_twikify_perl' },
);

# Create a TWiki version of the extension by simple transformation of files.
# Useless for processing CSS, JS or anything else complex.
sub target_twiki {
    my $this = shift;
    my $r    = "$this->{libdir}/$this->{project}";
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
            $text =~ s/foswikiNewLink/twikiNewLink/g;          # CSS
            $text =~ s/foswikiAlert/twikiAlert/g;
            $text =~ s/new Foswiki/new TWiki/g;
            return $text;
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
!option archive_prefix TWiki_
!option installers none
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
