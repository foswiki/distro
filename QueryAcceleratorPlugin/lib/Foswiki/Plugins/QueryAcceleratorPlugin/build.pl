#!/usr/bin/perl -w

# Standard preamble
BEGIN {
    foreach my $pc ( split( /:/, $ENV{FOSWIKI_LIBS} ) ) {
        unshift @INC, $pc;
    }
}

use Foswiki::Contrib::Build;

$build = new Foswiki::Contrib::Build("QueryAcceleratorPlugin");
$build->build( $build->{target} );
