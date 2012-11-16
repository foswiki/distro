# See bottom of file for license and copyright information

package Foswiki::Configure::Types::NULL;

use strict;
use warnings;

use Foswiki::Configure::Type ();
our @ISA = ('Foswiki::Configure::Type');

# This field is invisible, as it only exists to provide a hook for a provideFeedback button.
# It is disabled as there is no point in POSTing it.

sub prompt {
    my ( $this, $id, $opts, $value, $class ) = @_;

    return CGI::textfield(
        {
            -readonly => 'readonly',
            -default  => $value,
            -onchange => 'valueChanged(this)',
            -class    => "foswikiInputField foswikiNULLField",
            -style    => "display:none;",
            -disabled => 'disabled',
            -name     => $id,
            -value    => '',
            -size => '1',    #$Foswiki::DEFAULT_FIELD_WIDTH_NO_CSS,
        },
    );
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
