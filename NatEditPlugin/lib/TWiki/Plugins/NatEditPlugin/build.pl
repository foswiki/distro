#!/usr/bin/perl -w
BEGIN {
  foreach my $pc (split(/:/, $ENV{TWIKI_LIBS})) {
    unshift @INC, $pc;
  }
}

use TWiki::Contrib::Build;
$build = new TWiki::Contrib::Build( 'NatEditContrib' );
$build->build($build->{target});

