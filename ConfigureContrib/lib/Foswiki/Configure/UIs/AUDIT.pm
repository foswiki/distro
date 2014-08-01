# -*- mode: CPerl; -*-
# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Configure::UIs::AUDIT

Specialised UI for the AUDIT section.

renderValueBlock is used to attach a div that feedback can populate.

=cut

package Foswiki::Configure::UIs::AUDIT;

use strict;
use warnings;

use Foswiki::Configure::UIs::Section ();
our @ISA = ('Foswiki::Configure::UIs::Section');

# See Foswiki::Configure::UIs::Section

# Returns output - usually a table row
# The Configuration audit page is a mixture of standard table
# sections, and an undefined <div> for results.  We let the
# standard renderer handle the table sections; the div is done here.

sub renderHtml {
    my $this = shift;
    my ( $item, $root ) = @_;

    my $sectionType = $item->{auditType} || '';
    return $this->SUPER::renderHtml(@_) unless ( $sectionType eq 'results' );

    my $content  = qq{<div class="configureSubSection configureAuditResults">};
    my $depth    = $item->getDepth();
    my $headline = $item->{headline} || '';
    $content .= qq{<h$depth>$headline</h$depth>} if ($headline);

    my $desc = $item->{desc} || '';
    $content .= $desc if ($desc);

    return $content
      . qq{<div id="$item->{auditWindowId}" class="configureFeedback configureAuditResults"></div></div>};
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
