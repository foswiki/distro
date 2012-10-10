# See bottom of file for license and copyright information

package Foswiki::Configure::Checkers::Email::SmimeKeyPassword;

use strict;
use warnings;

use base 'Foswiki::Configure::Checker';

sub check {
    my $this   = shift;
    my $valobj = shift;

    my $value = $Foswiki::cfg{SmimeKeyPassword};

    # Expand any references to other variables

    Foswiki::Configure::Load::expandValue($value);

    # Unused passwords should not be hanging around.

    unless ( $Foswiki::cfg{Email}{EnableSMIME} ) {
        return $this->WARN(
            "Unused password field is not empty, please clear it")
          if ( defined $value && length $value );
        return '';
    }

    # I'm not going to nag about length or complexity, though I could..

    return '';
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

