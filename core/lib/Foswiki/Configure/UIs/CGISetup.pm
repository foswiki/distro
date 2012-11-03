# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Configure::UIs::CGISetup

Specialised UI for the CGI Setup section.

renderValueBlock is used to attach a div that feedback can populate.

=cut

package Foswiki::Configure::UIs::CGISetup;

use strict;
use warnings;

use Foswiki::Configure::UIs::Section ();
our @ISA = ('Foswiki::Configure::UIs::Section');

# See Foswiki::Configure::UIs::Section

sub renderValueBlock {
    my $self   = shift;
    my $values = shift;

    # Table of standard settings

    my $contents = $self->SUPER::renderValueBlock($values);

    # Append <div> for dynamic status

    return $contents
      . qq{<div id="{ConfigureGUI}{WebserverEnvironment}status"></div>};
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
