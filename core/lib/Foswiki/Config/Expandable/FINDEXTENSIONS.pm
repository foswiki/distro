# See bottom of file for license and copyright information

=begin TML

---+ package Foswiki::Config::Expandable::FINDEXTENSIONS
Pluggable for finding and downloading extensions. Implements 
<nop>*FINDEXTENSIONS* in Foswiki.spec.

=cut

package Foswiki::Config::Expandable::FINDEXTENSIONS;

use Foswiki::Class -app;
extends qw(Foswiki::Object);
with qw(Foswiki::Config::CfgObject);

sub compose {
    my $this = shift;

    # *FINDEXTENSIONS* is already placed in an appropriate section in
    # Foswiki.spec. There are no additional configuration items required.

    return ();
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2017 Foswiki Contributors. Foswiki Contributors
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
