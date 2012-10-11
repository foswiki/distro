# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::REGEX;

use strict;
use warnings;

use Foswiki::Configure::Checker ();
our @ISA = ('Foswiki::Configure::Checker');

=begin TML

---++ ObjectMethod check($valobj) -> $checkmsg

This is a generic (item-independent) checker for regular expressions.
As it's also the first generic checker in the standard distribution, it
also serves to document how to create one for other types.

This checker is the default for items of type REGEX.  It can be subclassed
if an individual item needs additional checks, but for most items, this is
all that is necessary.

This checker is normally instantiated by Types/REGEX (see =makeChecker=).

=cut

sub check {
    my $this   = shift;
    my $valobj = shift;

    my $keys = $valobj->getKeys() or die "No keys for value";

    # checkRE doesn't require the value, but we get it for showExpandedValue as
    # some regex items do expand.

    my $value = eval "\$Foswiki::cfg$keys";
    return $this->ERROR("Can't evaluate current value of $keys: $@") if ($@);

#<<<
#    my $cfgval = $value; # For showExpandedValue
#    Foswiki::Configure::Load::expandValue($value);
#>>>
    return $this->showExpandedValue($value) . $this->checkRE($keys);
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2000-2006 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root
of this distribution. NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
