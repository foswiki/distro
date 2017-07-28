#!/usr/bin/env perl

# Standard preamble
use strict;
use warnings;

BEGIN { unshift @INC, split( /:/, $ENV{FOSWIKI_LIBS} ); }

use Foswiki::Contrib::Build;

# Create the build object
my $build = new Foswiki::Contrib::Build('UpdatesPlugin');

# Build the target on the command line, or the default target
$build->build( $build->{target} );

