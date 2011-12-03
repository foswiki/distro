#!/usr/bin/perl -w

BEGIN { unshift @INC, split( /:/, $ENV{FOSWIKI_LIBS} ); }

use Foswiki::Contrib::Build;

my $build = new Foswiki::Contrib::Build('SubscribePlugin');

$build->build( $build->{target} );
