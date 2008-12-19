# See bottom of file for license and copyright information
#
# A UI for a collection object, designed so the objects can be twisted.
# The UI is implemented by visiting the nodes of the configuration and
# invoking the open-html and close_html methods for each node. The
# layout of a configuration page is depth-sensitive, so we have slightly
# different behaviours for each of level 0 (the root), level 1 (twisty
# sections) and level > 1 (subsection).
package Foswiki::Configure::UIs::Section;
use base 'Foswiki::Configure::UI';

use strict;

# depth == 1 is the root
# depth == 2 are twisty sections
# depth > 2 are subsections
sub open_html {
    my ( $this, $section, $valuer, $expert ) = @_;

    my $depth = $section->getDepth();

    if ( $depth > 2 ) {

        # A running section has no subtable, just a header row
        if ( !$expert && $section->isExpertsOnly() ) {
            return '';
        }
        else {
            my $fn = 'CGI::h' . $depth;
            no strict 'refs';
            my $head = &$fn( $section->{headline} );
            use strict 'refs';
            $head .= $section->{desc} if $section->{desc};
            return '<tr><td colspan="2">' . $head . '</td></tr>';
        }
    }

    my $id         = $this->_makeAnchor( $section->{headline} );
    my $linkId     = 'blockLink' . $id;
    my $linkAnchor = $id . 'link';

    my $mess = $this->collectMessages($section);

    my $guts = "<!-- $depth $section->{headline} -->";
    if ( $depth == 2 ) {

        # Open row
        $guts .= '<tr><td colspan="2">';
        $guts .= CGI::a( { name => $linkAnchor } );

        # Open twisty div
        $guts .= CGI::a(
            {
                id      => $linkId,
                class   => 'blockLink blockLinkOff',
                href    => '#' . $linkAnchor,
                rel     => 'nofollow',
                onclick => 'foldBlock("' . $id . '"); return false;'
            },
            '<span class="blockLinkIndicator"></span>' . $section->{headline} . $mess
        );

        $guts .= "<div id='$id' class='foldableBlock foldableBlockClosed'>";
    }

    # Open subtable
    $guts .= CGI::start_table(
        {
            width        => '100%',
            -border      => 0,
            -cellspacing => 0,
            -cellpadding => 0,
        }
    ) . "\n";

    # Put info text inside table row for visual consistency
    if ( $depth == 2 ) {
        $guts .= CGI::Tr(
            CGI::td(
                { colspan => "2", class => 'docdata firstInfo' },
                $section->{desc}
            )
        ) if $section->{desc};
    }

    return $guts;
}

sub close_html {
    my ( $this, $section, $expert ) = @_;
    my $depth = $section->getDepth();
    my $end   = '';
    if ( $depth <= 2 ) {

        # Close subtable
        $end = "</table>";
        if ( $depth == 2 ) {

            # Close twisty div
            $end .= '</div>';

            # Close row
            $end .= '</td></tr>';
        }
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
