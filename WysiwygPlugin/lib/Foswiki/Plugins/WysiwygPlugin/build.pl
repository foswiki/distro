#!/usr/bin/perl -w
#
# Build class for WysiwygPlugin
#
use strict;

BEGIN {
    unshift @INC, split( /:/, $ENV{FOSWIKI_LIBS} );
}

use Foswiki::Contrib::Build;

# Create the build object
my $build = new Foswiki::Contrib::Build('WysiwygPlugin');

# Build the target on the command line, or the default target
$build->build($build->{target});

