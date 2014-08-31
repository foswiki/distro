# See bottom of file for license and copyright information
package Foswiki::Configure::Checkers::Log::Action;

use strict;
use warnings;

use Foswiki::Configure::Checkers::PERL ();
our @ISA = ('Foswiki::Configure::Checkers::PERL');

sub check_current_value {
    my ( $this, $reporter ) = @_;

    my $val = $Foswiki::cfg{Log}{Action};
    unless ( ref($val) eq 'HASH' ) {
        $reporter->ERROR("Was expecting this to be an hash");
        return;
    }
    while ( my ( $k, $v ) = each %$val ) {
        if ( $k !~ /^[a-zA-Z]+$/ ) {
            $reporter->ERROR("Was expecting entry $k to be a script name");
        }
        if ( ref($v) ) {
            $reporter->ERROR("Was expecting $k to be a scalar");
        }
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
