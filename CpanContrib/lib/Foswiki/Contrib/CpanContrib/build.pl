#!/usr/bin/perl -w
use strict;

#
# Requires the environment variable FOSWIKI_LIBS (a colon-separated path
# list) to be set to point at the build system and any required dependencies.
# Usage: ./build.pl [-n] [-v] [target]
# where [target] is the optional build target (build, test,
# install, release, uninstall), test is the default.
# Two command-line options are supported:
# -n Don't actually do anything, just print commands
# -v Be verbose
#

# TODO:
# * add command line switch for cpan mirror directory

# Standard preamble
BEGIN {
    unshift @INC, split( /:/, $ENV{FOSWIKI_LIBS} || '' );
    unshift @INC, '../../../CPAN/lib';
}

use Foswiki::Contrib::Build;

# Declare our build package
package BuildBuild;
use Foswiki::Contrib::Build;
our @ISA = qw( Foswiki::Contrib::Build );

use File::Path qw( mkpath rmtree );
use FindBin;
use Data::Dumper qw( Dumper )
  ;    # not (just) for debugging, but for loading and saving the build cache

sub new {
    my $class = shift;
    my $this = bless( $class->SUPER::new("CpanContrib"), $class );

    $this->{DEBUG} = 0;
    $this->{throttle} =
      0;    # delay after each module build (to be nicer on shared hosts?)
    $this->{force} = 0;    # force rebuild even if newer than cache

    return $this;
}

sub target_stage {
    my $this = shift;

    $this->SUPER::target_stage();

    $this->stage_cpan();
}

sub stage_cpan {
    my $this = shift;

    # copy the generated files from CPAN build directory

    my $base_lib_dir = "$this->{basedir}/lib/CPAN";

    chdir $base_lib_dir;
    File::Find::find(
        {
            wanted   => sub { $this->cp( $_, "$this->{tmpDir}/lib/CPAN/$_" ) },
            no_chdir => 1
        },
        '.'
    );
}

sub target_build {
    my $this = shift;

    $this->SUPER::target_build();

    chdir $FindBin::Bin or die $!;

    {

        package CpanContrib::Modules;
        use vars qw( @CPAN );    # grrr, not sure why this is needed
        unless ( my $return = do "./CPAN" ) {
            die "unable to load CPAN module list to build: $!";
        }
    }

    # Do other build stuff here (?)
    # get cpan minimirror up-to-date
    # create foswiki mini-minicpan mirror (also publish this)

    use Cwd;
    my $base_lib_dir = getcwd . "/../../../CPAN";
    $this->{DEBUG} && print STDERR "base_lib_dir=[$base_lib_dir]\n";

# to keep "old" builds so that everything doesn't need to be built from scratch (for reasonable build times)
    -d $base_lib_dir || mkpath $base_lib_dir or die $!;
    ++$|;

    my $build_cache_filename = "$base_lib_dir/.build_cache";

    my $build_cache;
    if ( open( BUILD_CACHE, '<', $build_cache_filename ) )
    {    # read module build cache
        local $/ = undef;
        my $file = <BUILD_CACHE>;
        close BUILD_CACHE;
        $this->{DEBUG} && print STDERR $file;

        {
            no strict;
            $build_cache = eval $file;
            die $@ if $@;
        }
    }
    $this->{DEBUG} && print STDERR Dumper($build_cache);

    foreach my $module (@CpanContrib::Modules::CPAN) {

# clean out old build stuff (in particular, ExtUtils::MakeMaker leaves bad stuff lying around)
        my $dirCpanBuild = "$base_lib_dir/.cpan/build/";

        # SMELL: fix unix-specific chmod shell call
        system( chmod => '-R' => 'a+rwx' => $dirCpanBuild ),
          rmtree $dirCpanBuild
          if -d $dirCpanBuild;

        if ( $this->_upToDate( $build_cache, $module ) ) {
            print "Skipping $module (already built)\n";
            print "-" x 80, "\n";
        }
        else {
            print "Installing $module\n";
            print "-" x 80, "\n";
            my $mirror = '../../../../tools/MIRROR/MINICPAN/';
            -e $mirror or $mirror = 'http://cpan.perl.org';
            $build_cache->{$module}->{timebuilt} =
              time;    # earlier timestamp is better than later
            my $INSTALL_CPAN =
`perl ../../../../tools/install-cpan.pl --mirror=$mirror --baselibdir=$base_lib_dir $module </dev/null`;
            $this->{DEBUG} && print STDERR $INSTALL_CPAN;
            if ($@) {

                # TODO: also check for 'prerequisite' '::' lines?
                print STDERR "error installing $module: $@\n";
            }

            # fill in the cache information
            ( my $CPAN_FILE ) =
              $INSTALL_CPAN =~ /.*CPAN\.pm: Going to build (.*)/;
            $build_cache->{$module}->{CPAN_FILE} =
              "$mirror/authors/id/$CPAN_FILE";

            # save module build cache
            open( BUILD_CACHE, '>', $build_cache_filename );
            $Data::Dumper::Sortkeys =
              sub { [ sort lc keys %{ my $h = shift() } ] };
            print BUILD_CACHE Dumper($build_cache);
            close BUILD_CACHE;
        }
        sleep $this->{throttle};
    }

    # cleanup the intermediate CPAN build directories
    `chmod -R 777 $base_lib_dir/.cpan`;
    rmtree "$base_lib_dir/.cpan";
}

################################################################################

# SMELL: doesn't really handle modules that didn't build correctly
# (eg, XML::LibXML, XML::LibXSLT, SVG, etc.), but i don't have a way to build them now anyway...
# SMELL: also, doesn't handle if you manually delete the built library files without also deleting the cache
# (*maybe* i can check the return code, but i'm doing force installs, so that _might_ not work)
# (or maybe i can do more parsing of the output to see if it copied any files anywhere)
sub _upToDate {
    my $self  = shift;
    my $cache = shift;

    # no cache information; it "can't" be up-to-date
    return 0 unless $cache;

    my $module = shift or die "no module?";

    my $module_cache = $cache->{$module};
    $self->{DEBUG} && print STDERR "module_cache: ", Dumper($module_cache);

    # if cache doesn't know anything about it, we can't say it's up-to-date
    return 0 unless $module_cache->{timebuilt};

# newer versions of the module won't (quite) have the same name and therefore, won't be found
    return 0 unless -e $module_cache->{CPAN_FILE};

    # simply, if the source file is newer, rebuild
    my $cpan_file_timestamp = ( stat( $module_cache->{CPAN_FILE} ) )[9];
    $self->{DEBUG}
      && print STDERR "cpan_file_timestamp: [$cpan_file_timestamp]\n";
    return 0 if $cpan_file_timestamp > $module_cache->{timebuilt};

    return 1;
}

################################################################################

package main;

# Create the build object
my $build = new BuildBuild();

# Build the target on the command line, or the default target
$build->build( $build->{target} );
