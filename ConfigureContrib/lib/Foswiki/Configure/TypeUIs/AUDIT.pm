# See bottom of file for license and copyright information

use warnings;
use strict;

package Foswiki::Configure::TypeUIs::AUDIT;

our @ISA = (qw/Foswiki::Configure::TypeUIs::NULL/);

# There is no item, just output
# The return value must be true in order for the section builder to
# realize that there is content.  The content will be ignored by
# UIs/AUDIT, which is smarter about what's really going on.

sub prompt {
    my ( $this, $model, $value, $class ) = @_;

    return '**RESULTS**control';
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
