#!/usr/bin/perl -w
#
BEGIN {
    foreach my $pc ( split( /:/, $ENV{FOSWIKI_LIBS} ) ) {
        unshift @INC, $pc;
    }
}
use Foswiki::Contrib::Build;

my $build = new Foswiki::Contrib::Build("TWikiCompatibilityPlugin");
$build->build( $build->{target} );
