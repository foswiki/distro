# See bottom of file for license and copyright information
#
# A UI for a collection object.
# The layout of a configuration page is depth-sensitive, so we have slightly
# different behaviours for each of level 0 (the root), level 1 (tab
# sections) and level > 1 (subsection).
package Foswiki::Configure::UIs::Section;

use strict;

use Foswiki::Configure::UI ();
our @ISA = ('Foswiki::Configure::UI');

# Sections are of two types; "plain" and "tabbed". A plain section formats
# all its subsections inline, in a table. A tabbed section formats all its
# subsections as tabs.
sub open_html {
    my ( $this, $section, $root ) = @_;

    my $depth = $section->getDepth();
    my $class = $section->isExpertsOnly() ? 'configureExpert' : '';
    my $id = $this->makeID( $section->{headline} );
    my $output = "<!-- $depth $id -->\n";
    my $headline = $section->{headline} || 'MISSING HEADLINE';
    if ($section->{parent}) {
        if ($section->{parent}->{opts} =~ /TABS/) {
            # this is a tab within a tabbed page

            # See what errors and warnings exist in the tab
            my $mess = $this->collectMessages($section);

            $section->{parent}->{controls} ||=
              new Foswiki::Configure::GlobalControls(
                  $this->makeID( $section->{parent}->{headline} || '' ));

            $output .= $section->{parent}->{controls}->openTab(
                $id, $depth, $section->{opts}, $section->{headline},
                $mess ? 1 : 0);

            $output .= "<h$depth class='firstHeader'>"
              . $headline
                . "</h$depth>\n";

            if ($mess) {
                $output .= "<div class='foswikiAlert'>"
                  .$mess
                    ."</div>\n";
            }

            if ($section->{desc}) {
                $output .= $section->{desc} . "\n";
            }
        } elsif ($section->{parent}->{opts} =~ /NOLAYOUT/) {
            $output .= "<h$depth>"
              . "NOLAYOUT ". $headline
                . "</h$depth>\n";
        } else {
            # This is a new sub section within a running head section.
            $output .= "</table>";
            $output .=
              "<h$depth class='configureInlineHeading'>"
                . $headline . "</h$depth>\n";

            if ($section->{desc}) {
                $output .= $section->{desc};
            }
        }
    }

    if ($section->{opts} =~ /TABS/) {
        ; # Start a new tabbed section
    } elsif ($section->{opts} =~ /NOLAYOUT/) {
        ; # Start a new tabbed section
    } else {
        # plain section; open values table
        $output .= "<table class='configureSectionContents'>";
    }

    return $output;
}

sub close_html {
    my ( $this, $section, $root, $output ) = @_;

    my $depth = $section->getDepth();
    my $id = $this->makeID( $section->{headline} ) || 'configureSections';

    if ($section->{opts} =~ /TABS/) {
        # Generate the tab controls at this level (the tabs themselves
        # have already been generated as hidden divs). We have to put the
        # generated tabs at the *top* of the section
        $output = "<div id='$id'>"
          . $section->{controls}->generateTabs($depth)
            . $output
              ."</div>";
    } elsif ($section->{opts} =~ /NOLAYOUT/) {
        ; # Nothing to do
    } else {
        # Close plain section
        $output .= "</table>";
    }

    return $output unless $section->{parent}; # root

    if ( $section->{parent}->{opts} =~ /TABS/ ) {
        # close a tab, ready for the next one
        $output .= $section->{parent}->{controls}->closeTab($id);
    } else {
        ; # nothing special to do if the parent was plain or NOLAYOUT
    }
    $output .= "<!-- /$depth $id -->\n";

    return $output;
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
