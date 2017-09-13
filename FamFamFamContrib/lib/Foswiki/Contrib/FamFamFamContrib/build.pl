#!/usr/bin/env perl
BEGIN {
    unshift @INC, split( /:/, $ENV{FOSWIKI_LIBS} );
}
use Foswiki::Contrib::Build;

$build = new Foswiki::Contrib::Build('FamFamFamContrib');

$build->build( $build->{target} );

