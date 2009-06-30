package Foswiki::Configure::UIs::LANGUAGES;

use strict;

use Foswiki::Configure::UIs::Section ();
our @ISA = ('Foswiki::Configure::UIs::Section');

sub open_html {
    my ( $this, $section, $root ) = @_;
    my $id = $this->makeID( $section->{headline} );
    my $depth = $section->getDepth();

    # This is a running head

    my $guts = "<br class='foswikiClear' /><!-- $depth $id --><div class='foswikiHelp configureRow'>"
      .( $section->{desc} || '&nbsp;')
        ."</div>\n";

    return $guts;
}

1;
