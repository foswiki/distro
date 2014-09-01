# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::FormTypes;

use strict;
use warnings;

use Foswiki::Configure::Checkers::PERL ();
our @ISA = ('Foswiki::Configure::Checkers::PERL');

sub check_current_value {
    my ( $this, $reporter ) = @_;

    my $val = $Foswiki::cfg{FormTypes};
    unless ( ref($val) eq 'ARRAY' ) {
        $reporter->ERROR("Was expecting this to be an array");
        return;
    }
    my $ec = 0;
    foreach my $e (@$val) {
        if ( ref($e) ne 'HASH' ) {
            $reporter->ERROR("Was expecting entry $ec to be a hash");
        }
        else {

            # Validate the keys
            while ( my ( $k, $v ) = each %$e ) {
                if ( ref($v) ) {
                    $reporter->ERROR(
"Was expecting entry $ec to be a hash containing only scalars, but $k is not a scalar."
                    );
                }
            }
        }
        $ec++;
    }
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2014 Foswiki Contributors. Foswiki Contributors
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
