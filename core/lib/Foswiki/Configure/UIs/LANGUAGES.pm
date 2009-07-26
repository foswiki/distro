package Foswiki::Configure::UIs::LANGUAGES;

use strict;

use Foswiki::Configure::UIs::Section ();
our @ISA = ('Foswiki::Configure::UIs::Section');

sub renderHtml {
    my ( $this, $section, $root, $contents ) = @_;

    return $contents;
}

1;
