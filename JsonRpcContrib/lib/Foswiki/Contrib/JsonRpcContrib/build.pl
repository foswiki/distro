#!/usr/bin/env perl
use strict;
use warnings;
BEGIN { unshift @INC, split( /:/, $ENV{FOSWIKI_LIBS} ); }
use Foswiki::Contrib::Build;

# Create the build object
my $build = new Foswiki::Contrib::Build('JsonRpcContrib');
$build->build( $build->{target} );

