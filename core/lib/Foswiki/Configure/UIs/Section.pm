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
    my $class = $section->isExpertsOnly() ? 'expert' : 'newbie';
    my $id = $this->_makeAnchor( $section->{headline} );
    my $guts = "<!-- $depth $section->{headline} -->\n";
    if ($depth == 2) {
        # Major section == a tab

        # A tab has no heading and is initially invisible
        $guts .= $root->{controls}->openTab($id, $section->{headline});
        $guts .= $section->{desc} if $section->{desc};

        my $mess = $this->collectMessages($section);
        if ($mess) {
            $guts .= "<div class='foswikiAlert'>$mess</div>\n";
        }
        # Open subtable
        $guts .= "<table class='foswikiTable' width='100%'>\n";
    } elsif ( $depth > 2 ) {
        # A running section has no tab, just a header row
        $guts .= "<tr><td colspan='2'><h$depth>$section->{headline}</h$depth></td>\n";
        # if subtables under running sections
        #   $guts .= "<table style='foswikiTable' width='100%'>"
        # fi
    }

    if ( $depth > 2 && $section->{desc} ) {
        # Put info text inside table row for visual consistency
        $guts .= CGI::Tr(
            CGI::td(
                { colspan => "2", class => 'docdata firstInfo' },
                $section->{desc}
            )
        );
    }

    return $guts;
}

sub close_html {
    my ( $this, $section ) = @_;
    my $depth = $section->getDepth();
    my $end   = '';
    # if subtables under running sections
    #    my $d = $depth;
    #    while ($d-- >= 2) {
    # else with no subtables under running sections
    if ($depth == 2) {
    # fi
        $end .= "</table>";
    }
    if ( $depth == 2 ) {
        $end .= "</div>"; # close the tab
    }
    return "$end<!-- /$depth $section->{headline} -->\n";
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
