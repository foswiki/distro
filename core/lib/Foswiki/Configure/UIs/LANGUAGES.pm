package Foswiki::Configure::UIs::LANGUAGES;

use strict;

use Foswiki::Configure::UIs::Section ();
our @ISA = ('Foswiki::Configure::UIs::Section');

sub open_html {
    my ( $this, $section, $root ) = @_;
    my $id = $this->makeID( $section->{headline} );
    my $depth = $section->getDepth();

    # This is a running head

    my $guts = "<!-- $depth $id --><p>"
      .( $section->{desc} || '&nbsp;')
        ."</p>\n";

    return $guts;
}

1;
