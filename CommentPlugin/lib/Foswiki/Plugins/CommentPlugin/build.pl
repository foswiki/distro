#!/usr/bin/perl -w
#
package CommentPluginBuild;

BEGIN {
    foreach my $pc (split(/:/, $ENV{TWIKI_LIBS})) {
        unshift @INC, $pc;
    }
}
use Foswiki::Contrib::Build;

@CommentPluginBuild::ISA = ( "Foswiki::Contrib::Build" );

sub new {
    my $class = shift;
    return bless( $class->SUPER::new( "CommentPlugin" ), $class );
}

$build = new CommentPluginBuild();
$build->build($build->{target});
