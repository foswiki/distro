#!/usr/bin/env perl
#
# Build for SlideShowPlugin
#
use strict;

BEGIN {
    foreach my $pc ( split( /:/, $ENV{FOSWIKI_LIBS} ) ) {
        unshift @INC, $pc;
    }
}

use Foswiki::Contrib::Build;

# Create the build object
my $build = new Foswiki::Contrib::Build('SlideShowPlugin');

# Build the target on the command line, or the default target
$build->build( $build->{target} );

