# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::URLPATH;

use strict;
use warnings;

require Foswiki::Configure::Checker;
our @ISA = ('Foswiki::Configure::Checker');

use Foswiki::Configure::Checkers::URL ();

sub check_current_value {
    my ( $this, $reporter ) = @_;

    my $value = $this->checkExpandedValue($reporter);
    return unless defined $value;

    my %check = %{ $this->{item}->{CHECK} };

    # Force the following 'options' to specialize URL to URLPATH.
    $check{parts} = [
        'path',
        $check{parts}
        ? ( grep /^(?:query|fragment)$/, @{ $check{parts} } )
        : ()
    ];
    $check{partsreq} = [
        'path',
        $check{partsreq}
        ? ( grep /^(?:query|fragment)$/, @{ $check{partsreq} } )
        : ()
    ];
    $check{schemes}  = [];
    $check{authtype} = [];

    Foswiki::Configure::Checkers::URL::checkURI( $reporter,
        $this->{item}->getExpandedValue(), %check );
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2014 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2000-2006 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root
of this distribution.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
