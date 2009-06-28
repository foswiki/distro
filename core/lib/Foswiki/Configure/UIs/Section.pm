# See bottom of file for license and copyright information
#
# A UI for a collection object, designed so the objects can be twisted.
# The UI is implemented by visiting the nodes of the configuration and
# invoking the open-html and close_html methods for each node. The
# layout of a configuration page is depth-sensitive, so we have slightly
# different behaviours for each of level 0 (the root), level 1 (twisty
# sections) and level > 1 (subsection).
package Foswiki::Configure::UIs::Section;

use strict;

use Foswiki::Configure::UI ();
our @ISA = ('Foswiki::Configure::UI');

# depth == 1 is the root
# depth == 2 are twisty sections
# depth > 2 are subsections
sub open_html {
    my ( $this, $section, $root ) = @_;

    my $depth = $section->getDepth();
    my $class = $section->isExpertsOnly() ? 'configureExpert' : '';
    my $id = $this->makeID( $section->{headline} );
    my $guts = "<!-- $depth $section->{headline} -->\n";
    if ($depth == 2) {
        # Major section == a tab
        my $mess = $this->collectMessages($section);

        # This opens a div
        $guts .= $root->{controls}->openTab(
            $id, $section->{headline}, $mess ? 1 : 0);

        $guts .= $section->{desc} if $section->{desc};
        if ($mess) {
            $guts .= "<div class='foswikiAlert configureRow'>$mess</div>\n";
        }
    } elsif ( $depth > 2 ) {
        # A running section has no tab, just a header row
        $guts .= "<h$depth class='configureRow configureInlineHeading'>$section->{headline}</h$depth>\n";
    }

    if ( $depth > 2 && $section->{desc} ) {
        # Put info text inside table row for visual consistency
        $guts .= "<div class='docdata foswikiHelp configureRow'>$section->{desc}</div>";
    }

    return $guts;
}

sub close_html {
    my ( $this, $section, $root ) = @_;
    my $depth = $section->getDepth();
    my $end;
    if ( $depth == 2 ) {
        my $id = $this->makeID( $section->{headline} );
        $end = $root->{controls}->closeTab($id);
    } else {
        $end = "<!-- /$depth $section->{headline} -->\n";
    }
    return $end;
}

1;

__DATA__
#
# Foswiki - The Free and Open Source Wiki, http://foswiki.org/
#
# Copyright (C) 2008 Foswiki Contributors. All Rights Reserved.
# Foswiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
#
# Copyright (C) 2000-2006 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.
