#!/usr/bin/perl -w
#
# Build class for WysiwygPlugin
#
BEGIN {
  foreach my $pc (split(/:/, $ENV{TWIKI_LIBS} || '')) {
    unshift @INC, $pc;
  }
}

use Foswiki::Contrib::Build;

# Declare our build package
{ package WysiwygPluginBuild;

  @WysiwygPluginBuild::ISA = ( "Foswiki::Contrib::Build" );

  sub new {
    my $class = shift;
    return bless( $class->SUPER::new( "WysiwygPlugin" ), $class );
  }
}

# Create the build object
$build = new WysiwygPluginBuild();

# Build the target on the command line, or the default target
$build->build($build->{target});

