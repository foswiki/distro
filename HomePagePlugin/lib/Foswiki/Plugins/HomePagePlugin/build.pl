#!/usr/bin/env perl
BEGIN { unshift @INC, split( /:/, $ENV{FOSWIKI_LIBS} ); }
use Foswiki::Contrib::Build;

# Create the build object
$build = new Foswiki::Contrib::Build('HomePagePlugin');

# Build the target on the command line, or the default target
$build->build( $build->{target} );

