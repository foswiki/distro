#!/usr/bin/env perl
#
# Build for SpreadsheetPlugin
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
my $build = new Foswiki::Contrib::Build('SpreadSheetPlugin');

# Build the target on the command line, or the default target
$build->build( $build->{target} );

