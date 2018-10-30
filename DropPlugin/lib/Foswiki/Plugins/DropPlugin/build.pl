#!/usr/bin/env perl
#
use strict;
use warnings;

BEGIN {
    foreach my $pc ( split( /:/, $ENV{FOSWIKI_LIBS} ) ) {
        unshift @INC, $pc;
    }
}
use Foswiki::Contrib::Build;

my $build = new Foswiki::Contrib::Build("DropPlugin");
$build->build( $build->{target} );
