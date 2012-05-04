# See bottom of file for license and copyright information
package Foswiki::Contrib::BehaviourContrib;

use strict;
use warnings;

our $VERSION = '$Rev$';
our $RELEASE = '1.6';
our $SHORTDESCRIPTION =
"'Behaviour' Javascript event library to create javascript based interactions that degrade well when javascript is not available";

=begin TML

---+++ Foswiki::Contrib::BehaviourContrib::addHEAD()

This function will automatically add the headers for the contrib to
the page being rendered. It is intended for use from Plugins and
other extensions. For example:

<verbatim>
sub commonTagsHandler {
  ....
  require Foswiki::Contrib::BehaviourContrib;
  Foswiki::Contrib::BehaviourContrib::addHEAD();
  ....
</verbatim>

=cut

sub addHEAD {
    Foswiki::Func::addToZone( 'script', 'BehaviourContrib/behaviour',
'<script type="text/javascript" src="%PUBURLPATH%/%SYSTEMWEB%/BehaviourContrib/behaviour%FWSRC%.js"></script>'
    );
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
