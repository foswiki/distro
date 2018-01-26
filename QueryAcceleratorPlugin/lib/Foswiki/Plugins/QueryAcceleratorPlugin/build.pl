#!/usr/bin/env perl

use strict;
use warnings;

# Standard preamble
BEGIN {
    foreach my $pc ( split( /:/, $ENV{FOSWIKI_LIBS} ) ) {
        unshift @INC, $pc;
    }
}

use Foswiki::Contrib::Build;

my $build = new Foswiki::Contrib::Build("QueryAcceleratorPlugin");
$build->build( $build->{target} );
