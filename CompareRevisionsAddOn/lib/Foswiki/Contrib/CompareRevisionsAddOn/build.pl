#!/usr/bin/env perl
#
# Build for CompareRevisionsAddOn
#
use strict;
use warnings;

BEGIN {
    foreach my $pc ( split( /:/, $ENV{FOSWIKI_LIBS} ) ) {
        unshift @INC, $pc;
    }
}

use Foswiki::Contrib::Build;

# Create the build object
my $build = new Foswiki::Contrib::Build('CompareRevisionsAddOn');

# Build the target on the command line, or the default target
$build->build( $build->{target} );

