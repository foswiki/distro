#!/usr/bin/env perl
#
# Example build class. Copy this file to the equivalent place in your
# plugin or contrib and edit.
#
# Read the comments at the top of lib/Foswiki/Contrib/Build.pm for
# details of how the build process works, and what files you
# have to provide and where.
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

# Standard preamble
use strict;
use warnings;

BEGIN { unshift @INC, split( /:/, $ENV{FOSWIKI_LIBS} ); }

use Foswiki::Contrib::Build;

# Create the build object
my $build = new Foswiki::Contrib::Build('EmptyPlugin');

# Build the target on the command line, or the default target
$build->build( $build->{target} );

=begin TML

You can do a lot more with the build system if you want; for example, to add
a new target, or pre/post hooks for existing targets, you could do this:

<verbatim>
{
    package MyModuleBuild;
    our @ISA = qw( Foswiki::Contrib::Build );

    sub new {
        my $class = shift;
        return bless( $class->SUPER::new( "MyModule" ), $class );
    }

    sub target_mytarget {
        my $this = shift;
        # Do other build stuff here
    }

    sub pre_target_release {
        my $this = shift;
        $this->build( 'mytarget' );
    }

    sub post_target_build {
        my $this = shift;
        my ($error) = @_;
        # Do some cleanup or whatever else is necessary.
    }
}

# Create the build object
my $build = new MyModuleBuild();
</verbatim>

Note the =$error= parameter of =post_= hook. It will be undefined if the
target finished ok; otherwise it will contain error message.

You can also specify a different default target server for uploads.
This can be any web on any accessible Foswiki installation.
These defaults will be used when expanding tokens in .txt
files, but be warned, they can be overridden at upload time!

<verbatim>
# name of web to upload to
$build->{UPLOADTARGETWEB} = 'Extensions';
# Full URL of pub directory
$build->{UPLOADTARGETPUB} = 'http://foswiki.org/pub';
# Full URL of bin directory
$build->{UPLOADTARGETSCRIPT} = 'http://foswiki.org/bin';
# Script extension
$build->{UPLOADTARGETSUFFIX} = '';
</verbatim>

=cut

